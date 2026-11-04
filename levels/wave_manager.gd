class_name WaveManager
extends Node
## Ondas de inimigos da Fase 1 e da transição de fase de um chefão (ver `boss_kind`).

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

var _waves: Array[Array] = []
var _spawn_points: Array[Marker2D] = []
var _wave_points: Array[Marker2D] = []  # ordem de spawn da onda atual
var _alive: Dictionary[int, bool] = {}  # id dos inimigos vivos da onda
var _current_wave: int = -1  # índice da onda atual
var _wave_active: bool = false
var _next_spawn: int = 0
var _stopped: bool = false
## Player anunciado pelo EventBus.
var _player: Node2D = null
## Área em volta do chefão onde nenhum inimigo nasce (centro e raio; raio 0 = sem restrição).
var _clear_center: Vector2 = Vector2.ZERO
var _clear_radius: float = 0.0


## Lê as ondas e os marcadores e agenda a primeira.
func _ready() -> void:
	for wave: Array[PackedScene] in [wave_1_enemies, wave_2_enemies, wave_3_enemies]:
		if wave.is_empty():
			# Um chefão usa só a primeira onda; na fase normal, onda vazia é descuido do Inspector.
			if boss_kind.is_empty():
				push_warning("WaveManager: a onda %d está vazia no Inspector." % (_waves.size() + 1))
			continue
		_waves.append(wave)
	if not _collect_spawn_points():
		return

	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.player_died.connect(_on_player_died)
	if boss_kind.is_empty():
		_schedule_wave(0, first_wave_delay)
	else:
		EventBus.boss_transition_started.connect(_on_boss_transition_started)


## Conecta antes dos _ready: o Player anuncia a si mesmo no próprio _ready.
func _enter_tree() -> void:
	EventBus.player_registered.connect(_on_player_registered)


## Para tudo e desconecta.
func _exit_tree() -> void:
	_stopped = true
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


## Cria os inimigos da onda e avisa o EventBus.
func _start_wave(index: int) -> void:
	if _stopped or index >= _waves.size():
		return

	_current_wave = index
	_wave_active = true
	_alive.clear()
	_order_spawn_points()
	_next_spawn = 0

	for scene: PackedScene in _waves[index]:
		# Spawn deferido: a posição vale antes do _ready do inimigo
		var enemy := CombatUtils.spawn(scene, self, _next_spawn_position())
		if enemy == null:
			continue
		var id := enemy.get_instance_id()
		_alive[id] = true
		# Inimigo que some sem morrer não trava a onda
		enemy.tree_exited.connect(_on_enemy_tree_exited.bind(id))

	if boss_kind.is_empty():
		EventBus.wave_started.emit(index + 1, _waves.size(), _alive.size())

	if _alive.is_empty():
		push_warning("WaveManager: a onda %d não gerou nenhum inimigo; avançando." % (index + 1))
		_finish_wave()


## Onda limpa: cura e agenda a próxima.
func _finish_wave() -> void:
	_wave_active = false
	if boss_kind.is_empty():
		EventBus.wave_cleared.emit(_current_wave + 1, _waves.size())
	_reward_player()

	var next_index := _current_wave + 1
	if next_index < _waves.size():
		_schedule_wave(next_index, between_waves_delay)
	elif boss_kind.is_empty():
		EventBus.all_waves_cleared.emit()
	else:
		EventBus.boss_wave_cleared.emit(boss_kind)


## Agenda uma onda com timer de jogo (respeita a pausa).
func _schedule_wave(index: int, delay: float) -> void:
	var timer := CombatUtils.game_timer(self, delay)
	if timer != null:
		timer.timeout.connect(_start_wave.bind(index))


## Guarda o Player anunciado pelo EventBus.
func _on_player_registered(player: Node2D) -> void:
	_player = player


## O chefão desta wave ficou invulnerável: começa a onda longe das paredes dele.
func _on_boss_transition_started(kind: StringName, boss_position: Vector2, clear_radius: float) -> void:
	if kind != boss_kind or _stopped or _wave_active:
		return
	_clear_center = boss_position
	_clear_radius = clear_radius
	_schedule_wave(0, first_wave_delay)


## Pede a cura do Player pelo EventBus.
func _reward_player() -> void:
	if clear_heal_amount > 0:
		EventBus.player_heal_requested.emit(clear_heal_amount)


## Lê os Marker2D filhos.
func _collect_spawn_points() -> bool:
	if spawn_points_root == null:
		push_error("WaveManager: 'spawn_points_root' não foi atribuído no Inspector.")
		return false
	for child: Node in spawn_points_root.get_children():
		if child is Marker2D:
			_spawn_points.append(child as Marker2D)
	if _spawn_points.is_empty():
		push_error("WaveManager: '%s' não tem nenhum Marker2D filho." % spawn_points_root.name)
		return false
	return true


## Ordem dos marcadores da onda: longe do Player primeiro.
func _order_spawn_points() -> void:
	# Descarta marcadores removidos da cena entre uma onda e outra: ler
	# global_position de um nó liberado quebraria o spawn da onda inteira.
	_wave_points.assign(_spawn_points.filter(func(m: Marker2D) -> bool:
		return CombatUtils.is_valid(m) and not _is_in_clear_area(m.global_position)))
	_wave_points.shuffle()
	if _wave_points.is_empty():
		push_error("WaveManager: nenhum ponto de spawn válido; a onda não vai nascer.")
		return
	if min_player_distance <= 0.0 or not CombatUtils.is_targetable(_player):
		return
	var player_pos := _player.global_position
	var min_sq := min_player_distance * min_player_distance
	var far: Array[Marker2D] = []
	far.assign(_wave_points.filter(func(m: Marker2D) -> bool:
		return m.global_position.distance_squared_to(player_pos) >= min_sq))
	if not far.is_empty():
		_wave_points = far
		return
	_wave_points.sort_custom(func(a: Marker2D, b: Marker2D) -> bool:
		return a.global_position.distance_squared_to(player_pos) > b.global_position.distance_squared_to(player_pos))


## True se o ponto cai dentro da área protegida em volta do chefão.
func _is_in_clear_area(point: Vector2) -> bool:
	return _clear_radius > 0.0 and point.distance_squared_to(_clear_center) < _clear_radius * _clear_radius


## Próximo ponto de spawn (repete se faltar marcador).
func _next_spawn_position() -> Vector2:
	if _wave_points.is_empty():
		return Vector2.ZERO  # sem marcador válido (já reportado em _order_spawn_points)
	var marker: Marker2D = _wave_points[_next_spawn % _wave_points.size()]
	_next_spawn += 1
	var offset: Vector2 = Vector2.ZERO
	if spawn_jitter > 0.0:
		offset = Vector2.from_angle(randf() * TAU) * randf_range(0.0, spawn_jitter)
	return marker.global_position + offset


## Desconta o inimigo da onda.
func _on_enemy_died(enemy: Node2D, _kind: StringName, _world_position: Vector2) -> void:
	# Player morto ou fase saindo: ignora
	if _stopped or not _wave_active or not CombatUtils.is_valid(enemy):
		return
	# Só conta inimigos desta onda
	if not _alive.erase(enemy.get_instance_id()):
		return
	if _alive.is_empty():
		_finish_wave()


## Player morreu: nenhuma onda nova, nenhuma cura.
func _on_player_died() -> void:
	_stopped = true


## Inimigo saiu da árvore: confere no fim do frame.
func _on_enemy_tree_exited(id: int) -> void:
	_check_vanished_enemy.call_deferred(id)


## Remove da contagem o inimigo que sumiu sem morrer.
func _check_vanished_enemy(id: int) -> void:
	if _stopped or not _wave_active or not is_inside_tree():
		return
	var node := instance_from_id(id) as Node
	if node != null and node.is_inside_tree():
		return  # só mudou de pai
	if _alive.erase(id) and _alive.is_empty():
		_finish_wave()
