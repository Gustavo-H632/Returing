class_name WaveManager
extends Node
## Ondas de inimigos da Fase 1 e da transição de fase de um chefão (ver `boss_kind`).

const WORLD_MASK: int = 1  # Camada física do mundo (paredes, carros, cercas).
const SPAWN_ATTEMPTS: int = 6  # Tentativas de desvio por marcador antes de passar ao próximo.

@export_group("Ondas (arraste as cenas dos inimigos)")
## Onda 1: 2 Drones + 2 Robos.
@export var wave_1_enemies: Array[PackedScene] = []
## Onda 2: 2 Tanks + 2 Robos.
@export var wave_2_enemies: Array[PackedScene] = []
## Onda 3: 2 Tanks + 2 Robos + 3 Drones.
@export var wave_3_enemies: Array[PackedScene] = []

@export_group("Spawn")
## Nó cujos Marker2D filhos são os pontos de spawn.
@export var spawn_points_root: Node2D
## Desvio aleatório em volta do marcador (px)
@export_range(0.0, 128.0, 1.0, "or_greater") var spawn_jitter: float = 16.0
## Distância mínima do Player para nascer (0 = desliga)
@export_range(0.0, 1024.0, 1.0, "or_greater") var min_player_distance: float = 200.0
## Raio (px) livre de colisão do mundo (carros, paredes, cercas) exigido para um inimigo nascer. Se o ponto sorteado
## estiver bloqueado, tenta outro desvio e depois o próximo marcador. 0 = desliga.
@export_range(0.0, 64.0, 1.0, "or_greater") var spawn_clearance: float = 24.0

@export_group("Ritmo")
## Pausa antes da primeira onda.
@export_range(0.0, 10.0, 0.1, "or_greater") var first_wave_delay: float = 1.0
## Pausa entre ondas.
@export_range(0.0, 10.0, 0.1, "or_greater") var between_waves_delay: float = 2.0

@export_group("Recompensa")
## Cura dada ao limpar uma onda.
@export_range(0, 999) var clear_heal_amount: int = 30

@export_group("Chefão")
## Vazio = ondas normais da fase (começam sozinhas e avisam o EventBus). Preenchido (ex.: "guide"),
## as ondas só começam quando esse chefão pede a transição e o fim delas é avisado por
## boss_wave_cleared, sem mexer na contagem da fase.
@export var boss_kind: StringName = &""

var _waves: Array[Array] = []  # Lista das ondas configuradas.
var _spawn_points: Array[Marker2D] = []  # Todos os pontos de nascimento.
var _wave_points: Array[Marker2D] = []  # ordem de spawn da onda atual
var _alive: Dictionary[int, bool] = {}  # id dos inimigos vivos da onda
var _current_wave: int = -1  # índice da onda atual
var _wave_active: bool = false  # True durante uma onda.
var _next_spawn: int = 0  # Próximo ponto a usar.
var _stopped: bool = false  # True depois que o jogador morre ou a fase sai.
## Player anunciado pelo EventBus.
var _player: Node2D = null
## Área em volta do chefão onde nenhum inimigo nasce (centro e raio; raio 0 = sem restrição).
var _clear_center: Vector2 = Vector2.ZERO
var _clear_radius: float = 0.0  # Raio da área protegida (0 = sem restrição).


## Lê as ondas e os marcadores e agenda a primeira.
## Lê as ondas e os pontos de nascimento, liga os sinais e agenda a primeira onda (ou espera o chefão).
func _ready() -> void:
	# Para cada onda configurada.
	for wave: Array[PackedScene] in [wave_1_enemies, wave_2_enemies, wave_3_enemies]:
		if wave.is_empty():  # Onda vazia.
			# Um chefão usa só a primeira onda; na fase normal, onda vazia é descuido do Inspector.
			if boss_kind.is_empty():  # Fase normal: onda vazia é descuido do Inspector.
				# Avisa no console.
				push_warning("WaveManager: a onda %d está vazia no Inspector." % (_waves.size() + 1))
			continue
		_waves.append(Ondas.escalar_cenas(wave))  # Guarda a onda, já com o multiplicador de inimigos (autoload Ondas).
	if not _collect_spawn_points():  # Sem pontos de nascimento não há como começar.
		return

	EventBus.enemy_died.connect(_on_enemy_died)  # Inimigo morreu.
	EventBus.player_died.connect(_on_player_died)  # Jogador morreu: para tudo.
	if boss_kind.is_empty():  # Fase normal: a primeira onda começa sozinha.
		_schedule_wave(0, first_wave_delay)
	else:
		# Chefão: espera o pedido de transição.
		EventBus.boss_transition_started.connect(_on_boss_transition_started)


## Conecta antes dos _ready: o Player anuncia a si mesmo no próprio _ready.
## Liga o anúncio do jogador antes do _ready (o jogador se anuncia no próprio _ready).
func _enter_tree() -> void:
	EventBus.player_registered.connect(_on_player_registered)  # Guarda o jogador.


## Para tudo e desconecta.
func _exit_tree() -> void:
	_stopped = true  # Impede novos nascimentos.
	CombatUtils.disconnect_if_connected(EventBus.player_registered, _on_player_registered)
	CombatUtils.disconnect_if_connected(EventBus.enemy_died, _on_enemy_died)
	CombatUtils.disconnect_if_connected(EventBus.player_died, _on_player_died)
	CombatUtils.disconnect_if_connected(EventBus.boss_transition_started, _on_boss_transition_started)


## Onda atual (começa em 1; 0 = não começou).
func get_current_wave_number() -> int:
	return _current_wave + 1


## Total de ondas.
func get_total_waves() -> int:
	return _waves.size()


## Inimigos vivos da onda.
func get_alive_count() -> int:
	return _alive.size()


## Inicia a onda: embaralha os pontos de spawn e cria cada inimigo da lista, registrando-os como vivos.
## Depois emite wave_started no EventBus. Se nenhum inimigo nascer, encerra a onda para não travar a fase.
## Cria os inimigos da onda e avisa o EventBus.
func _start_wave(index: int) -> void:
	if _stopped or index >= _waves.size():  # Parou ou índice inválido: não inicia.
		return

	_current_wave = index  # Guarda o índice da onda.
	_wave_active = true  # Onda em andamento.
	_alive.clear()  # Esquece os inimigos da onda anterior.
	_order_spawn_points()  # Escolhe a ordem dos pontos.
	_next_spawn = 0  # Começa pelo primeiro ponto.

	for scene: PackedScene in _waves[index]:  # Para cada inimigo da onda.
		# Spawn deferido: a posição vale antes do _ready do inimigo
		var enemy := CombatUtils.spawn(scene, self, _next_spawn_position())
		if enemy == null:  # Falhou: pula este inimigo.
			continue
		var id := enemy.get_instance_id()  # Identificador do inimigo.
		_alive[id] = true  # Marca como vivo.
		# Inimigo que some sem morrer não trava a onda
		enemy.tree_exited.connect(_on_enemy_tree_exited.bind(id))  # Se sumir sem morrer, não trava a onda.

	if boss_kind.is_empty():  # Só fases normais avisam o EventBus.
		# Avisa onda, total e quantidade de inimigos.
		EventBus.wave_started.emit(index + 1, _waves.size(), _alive.size())

	if _alive.is_empty():  # Nenhum inimigo nasceu.
		# Avisa no console.
		push_warning("WaveManager: a onda %d não gerou nenhum inimigo; avançando." % (index + 1))
		_finish_wave()  # Encerra a onda para não travar.


## Onda limpa: cura e agenda a próxima.
## Onda limpa: avisa, cura o jogador e agenda a próxima onda (ou termina a fase/transição do chefão).
func _finish_wave() -> void:
	_wave_active = false  # Onda terminou.
	if boss_kind.is_empty():  # Fase normal avisa o EventBus.
		EventBus.wave_cleared.emit(_current_wave + 1, _waves.size())  # Avisa a onda e o total.
	_reward_player()  # Cura o jogador.

	var next_index := _current_wave + 1  # Índice da próxima onda.
	if next_index < _waves.size():  # Ainda há ondas.
		_schedule_wave(next_index, between_waves_delay)  # Agenda a próxima.
	elif boss_kind.is_empty():  # Era a última onda de uma fase normal.
		EventBus.all_waves_cleared.emit()  # Avisa que todas foram eliminadas.
	else:
		EventBus.boss_wave_cleared.emit(boss_kind)  # Chefão: avisa que a wave dele acabou.


## Agenda uma onda com timer de jogo (respeita a pausa).
func _schedule_wave(index: int, delay: float) -> void:
	var timer := CombatUtils.game_timer(self, delay)  # Timer de jogo.
	if timer != null:  # Só se foi criado.
		timer.timeout.connect(_start_wave.bind(index))  # Inicia a onda ao fim do timer.


## Guarda o Player anunciado pelo EventBus.
func _on_player_registered(player: Node2D) -> void:
	_player = player  # Guarda a referência.


## O chefão desta wave ficou invulnerável: começa a onda longe das paredes dele.
## O chefão ficou invulnerável: guarda a área protegida em volta dele e agenda a onda.
func _on_boss_transition_started(kind: StringName, boss_position: Vector2, clear_radius: float) -> void:
	# Só o chefão certo, com o WaveManager ativo e sem onda em andamento.
	if kind != boss_kind or _stopped or _wave_active:
		return
	_clear_center = boss_position  # Centro protegido.
	_clear_radius = clear_radius  # Raio protegido.
	_schedule_wave(0, first_wave_delay)  # Agenda a primeira onda.


## Pede a cura do Player pelo EventBus.
func _reward_player() -> void:
	if clear_heal_amount > 0:  # Só se há cura configurada.
		EventBus.player_heal_requested.emit(clear_heal_amount)  # Pede a cura.


## Lê os Marker2D filhos.
## Lê os Marker2D filhos do nó de pontos de nascimento. Devolve false se não houver nenhum.
func _collect_spawn_points() -> bool:
	if spawn_points_root == null:  # Sem nó configurado: erro.
		push_error("WaveManager: 'spawn_points_root' não foi atribuído no Inspector.")  # Avisa o erro.
		return false  # Falha.
	for child: Node in spawn_points_root.get_children():  # Passa por cada filho.
		if child is Marker2D:  # Só marcadores.
			_spawn_points.append(child as Marker2D)  # Guarda.
	if _spawn_points.is_empty():  # Sem nenhum marcador: erro.
		# Avisa o erro.
		push_error("WaveManager: '%s' não tem nenhum Marker2D filho." % spawn_points_root.name)
		return false  # Falha.
	return true  # Deu certo.


## Ordem dos marcadores da onda: longe do Player primeiro.
## Define a ordem dos pontos da onda: embaralha, descarta os que ficam na área do chefão e prefere os longe do jogador.
func _order_spawn_points() -> void:
	# Descarta marcadores removidos da cena entre uma onda e outra: ler
	# global_position de um nó liberado quebraria o spawn da onda inteira.
	_wave_points.assign(_spawn_points.filter(func(m: Marker2D) -> bool:
		return CombatUtils.is_valid(m) and not _is_in_clear_area(m.global_position)))
	_wave_points.shuffle()  # Embaralha.
	if _wave_points.is_empty():  # Nenhum ponto válido.
		push_error("WaveManager: nenhum ponto de spawn válido; a onda não vai nascer.")  # Avisa o erro.
		return
	# Sem distância mínima ou sem jogador: mantém a ordem embaralhada.
	if min_player_distance <= 0.0 or not CombatUtils.is_targetable(_player):
		return
	var player_pos := _player.global_position  # Posição do jogador.
	var min_sq := min_player_distance * min_player_distance  # Distância mínima ao quadrado.
	var far: Array[Marker2D] = []  # Pontos longe o suficiente.
	far.assign(_wave_points.filter(func(m: Marker2D) -> bool:  # Filtra os longe.
		return m.global_position.distance_squared_to(player_pos) >= min_sq))
	if not far.is_empty():  # Se há pontos longe, usa só esses.
		_wave_points = far  # Usa os longe.
		return
	# Senão ordena do mais distante para o mais próximo.
	_wave_points.sort_custom(func(a: Marker2D, b: Marker2D) -> bool:
		return a.global_position.distance_squared_to(player_pos) > b.global_position.distance_squared_to(player_pos))


## True se o ponto cai dentro da área protegida em volta do chefão.
## Diz se o ponto cai dentro da área protegida em volta do chefão.
func _is_in_clear_area(point: Vector2) -> bool:
	return _clear_radius > 0.0 and point.distance_squared_to(_clear_center) < _clear_radius * _clear_radius


## Próximo ponto de spawn (repete se faltar marcador).
## Devolve o próximo ponto de nascimento com um pequeno desvio aleatório (repete os pontos se faltarem).
func _next_spawn_position() -> Vector2:
	if _wave_points.is_empty():  # Sem ponto válido (já avisado antes).
		return Vector2.ZERO  # sem marcador válido (já reportado em _order_spawn_points)
	# Começa pelo ponto da vez e só aceita lugar livre de colisão (inimigo nascido dentro de um carro ou parede
	# fica preso). Cada ponto tem algumas tentativas de desvio; se um ponto inteiro estiver bloqueado, vai ao próximo.
	var count: int = _wave_points.size()
	var attempts: int = SPAWN_ATTEMPTS if spawn_jitter > 0.0 else 1
	for step: int in count:
		var marker: Marker2D = _wave_points[(_next_spawn + step) % count]
		for attempt: int in attempts:
			var offset: Vector2 = Vector2.ZERO  # Desvio padrão zero.
			if spawn_jitter > 0.0 and attempt < attempts - 1:  # A última tentativa usa o marcador exato.
				# Desvio aleatório dentro do raio.
				offset = Vector2.from_angle(randf() * TAU) * randf_range(0.0, spawn_jitter)
			var candidate: Vector2 = marker.global_position + offset
			if _is_spawn_free(candidate):
				_next_spawn += step + 1  # Avança para depois do ponto usado.
				return candidate
	# Nenhum ponto livre (cena mal configurada): nasce no ponto da vez e avisa.
	push_warning("WaveManager: nenhum ponto de spawn livre de colisão; o inimigo nasce em um ponto bloqueado.")
	var fallback: Marker2D = _wave_points[_next_spawn % count]
	_next_spawn += 1
	return fallback.global_position


## True se um círculo de `spawn_clearance` px em `point` não toca nenhuma colisão do mundo.
func _is_spawn_free(point: Vector2) -> bool:
	if spawn_clearance <= 0.0 or not is_inside_tree():
		return true
	var world: World2D = get_viewport().find_world_2d()
	if world == null:
		return true
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = spawn_clearance
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, point)
	query.collision_mask = WORLD_MASK
	return world.direct_space_state.intersect_shape(query, 1).is_empty()


## Desconta o inimigo da onda.
## Um inimigo morreu: tira da onda e, se foi o último, a encerra.
func _on_enemy_died(enemy: Node2D, _kind: StringName, _world_position: Vector2) -> void:
	# Player morto ou fase saindo: ignora
	# Ignora se parou, a onda não está ativa ou o inimigo já foi liberado.
	if _stopped or not _wave_active or not CombatUtils.is_valid(enemy):
		return
	# Só conta inimigos desta onda
	if not _alive.erase(enemy.get_instance_id()):
		return
	if _alive.is_empty():  # Era o último: onda limpa.
		_finish_wave()


## Player morreu: nenhuma onda nova, nenhuma cura.
func _on_player_died() -> void:
	_stopped = true  # Para tudo.


## Inimigo saiu da árvore: confere no fim do frame.
func _on_enemy_tree_exited(id: int) -> void:
	_check_vanished_enemy.call_deferred(id)  # Adiado para não confundir com mudança de pai.


## Remove da contagem o inimigo que sumiu sem morrer.
## Tira da onda o inimigo que sumiu sem morrer, para a onda não travar.
func _check_vanished_enemy(id: int) -> void:
	# Parado, sem onda ativa ou fora da cena: nada a fazer.
	if _stopped or not _wave_active or not is_inside_tree():
		return
	var node := instance_from_id(id) as Node  # Procura o nó pelo id.
	if node != null and node.is_inside_tree():  # Só mudou de pai.
		return  # só mudou de pai
	if _alive.erase(id) and _alive.is_empty():  # Tira da conta e, se era o último, encerra a onda.
		_finish_wave()
