class_name LevelManager
extends Node
## Regras da fase: conta inimigos vivos e decide vitória e derrota.

## Próxima cena (vazio = só volta ao menu)
@export_file("*.tscn") var next_scene: String = ""
# Espera entre vencer e mostrar a vitória.
@export_range(0.0, 10.0, 0.1, "or_greater") var complete_delay: float = 1.0
# Espera entre morrer e mostrar o game over.
@export_range(0.0, 10.0, 0.1, "or_greater") var game_over_delay: float = 1.5
## Depois de concluída, avança sozinha para `next_scene` após este tempo.
@export_range(0.0, 20.0, 0.1, "or_greater") var auto_advance_delay: float = 3.0

var _alive: Dictionary[int, bool] = {}  # id dos inimigos vivos
var _had_enemies: bool = false  # True se algum inimigo já apareceu na fase.
# True depois que a fase terminou (vitória ou derrota), para não terminar duas vezes.
var _ended: bool = false
## True depois que o Player morreu (mesmo que a fase já tenha sido concluída).
var _player_dead: bool = false
var _wave_mode: bool = false  # ligado no primeiro wave_started


## Conecta no EventBus.
## Liga os sinais do EventBus antes do _ready dos inimigos, para não perder nenhum registro.
func _enter_tree() -> void:
	# Conecta antes dos _ready dos inimigos
	EventBus.enemy_registered.connect(_on_enemy_registered)  # Novo inimigo na fase.
	EventBus.enemy_died.connect(_on_enemy_died)  # Inimigo morreu.
	EventBus.player_died.connect(_on_player_died)  # Jogador morreu.
	EventBus.wave_started.connect(_on_wave_started)  # Uma onda começou (liga o modo ondas).
	EventBus.all_waves_cleared.connect(_on_all_waves_cleared)  # Todas as ondas foram eliminadas.


## Anuncia o início da fase.
## Conta os inimigos que já estavam na fase e avisa que a fase começou.
func _ready() -> void:
	# Conta inimigos já presentes
	for node: Node in get_tree().get_nodes_in_group(CombatUtils.GROUP_ENEMY):
		_track(node)  # Passa a contar cada um.
	EventBus.level_started.emit()  # Avisa a HUD e os controles.
	_emit_remaining()  # Envia o contador inicial.


## Desconecta do EventBus.
func _exit_tree() -> void:
	CombatUtils.disconnect_if_connected(EventBus.enemy_registered, _on_enemy_registered)
	CombatUtils.disconnect_if_connected(EventBus.enemy_died, _on_enemy_died)
	CombatUtils.disconnect_if_connected(EventBus.player_died, _on_player_died)
	CombatUtils.disconnect_if_connected(EventBus.wave_started, _on_wave_started)
	CombatUtils.disconnect_if_connected(EventBus.all_waves_cleared, _on_all_waves_cleared)


## Inimigos vivos.
func get_remaining() -> int:
	return _alive.size()


## Novo inimigo na fase.
func _on_enemy_registered(enemy: Node2D, _kind: StringName, _max_health: int) -> void:
	_track(enemy)  # Registra.
	_emit_remaining()  # Atualiza o contador.


## Desconta e vence se acabou (fase sem ondas).
## Um inimigo morreu: tira da contagem e, em fase sem ondas, vence quando o último morre.
func _on_enemy_died(enemy: Node2D, _kind: StringName, _world_position: Vector2) -> void:
	if not CombatUtils.is_valid(enemy):  # Inimigo já liberado: ignora.
		return
	if not _alive.erase(enemy.get_instance_id()):  # Só continua se o inimigo estava na contagem.
		return
	_emit_remaining()  # Atualiza o contador.
	# Com ondas quem decide é all_waves_cleared
	if _wave_mode:  # Com ondas, quem decide a vitória é all_waves_cleared.
		return
	if _alive.is_empty() and _had_enemies:  # Sem ondas: acabaram os inimigos.
		_finish_level()  # Conclui a fase.


## Liga o modo ondas.
func _on_wave_started(_wave: int, _total_waves: int, _enemy_count: int) -> void:
	_wave_mode = true  # Marca o modo.


## Vitória da fase com ondas.
func _on_all_waves_cleared() -> void:
	_finish_level()


## Game Over após o atraso.
## O jogador morreu: marca e agenda o game over (se a fase ainda não tinha terminado).
func _on_player_died() -> void:
	_player_dead = true  # Guarda que o jogador morreu.
	if _ended:  # Fase já terminada: não agenda de novo.
		return
	_ended = true  # Marca como terminada.
	_after(game_over_delay, _trigger_game_over)  # Game over depois de uma pequena espera.


## Fase concluída (uma vez).
## Conclui a fase uma única vez e agenda a mensagem de vitória.
func _finish_level() -> void:
	if _ended:  # Já terminou: ignora.
		return
	_ended = true  # Marca como terminada.
	EventBus.enemies_cleared.emit()  # Avisa que não há mais inimigos.
	_after(complete_delay, _complete_level)  # Vitória depois de uma pequena espera.


## Registra um inimigo vivo.
## Passa a contar o inimigo e escuta a saída dele da cena (para tirar da conta se sumir sem morrer).
func _track(enemy: Node) -> void:
	if not CombatUtils.is_valid(enemy):  # Inimigo inválido: ignora.
		return
	var id := enemy.get_instance_id()  # Identificador do inimigo.
	if _alive.has(id):  # Já contado.
		return  # já contado
	_alive[id] = true  # Marca como vivo.
	_had_enemies = true  # Alguém apareceu na fase.
	# Inimigo removido sem morrer também sai da contagem.
	# A conexão precisa ser testada COM o argumento preso: o método
	# sozinho é outro Callable, e o teste nunca encontraria a conexão existente.
	# Se o inimigo sair da cena sem morrer, também sai da conta.
	CombatUtils.connect_once(enemy.tree_exited, _on_enemy_tree_exited.bind(id))


## Inimigo saiu da árvore.
func _on_enemy_tree_exited(id: int) -> void:
	## Um inimigo saiu da cena: confere no fim do quadro se ele sumiu de verdade.
	_check_vanished_enemy.call_deferred(id)


## Deferido: confere se o inimigo sumiu sem morrer.
## Confere se o inimigo realmente sumiu (e não só mudou de pai) e, se sim, tira da contagem.
func _check_vanished_enemy(id: int) -> void:
	if not is_inside_tree():  # Fase saindo: nada a fazer.
		return
	var node := instance_from_id(id) as Node  # Procura o nó pelo id.
	if node != null and node.is_inside_tree():  # Ainda está na cena (só mudou de pai).
		return
	if not _alive.erase(id):  # Tira da conta.
		return
	_emit_remaining()  # Atualiza o contador.
	# Sem ondas, o último inimigo que sumiu conclui a fase.
	if not _wave_mode and _alive.is_empty() and _had_enemies:
		_finish_level()


## Timer de jogo (respeita a pausa).
func _after(seconds: float, callback: Callable) -> void:
	var timer := CombatUtils.game_timer(self, seconds)  # Timer de jogo.
	if timer != null:  # Só se foi criado.
		timer.timeout.connect(callback)  # Chama a função ao terminar.


## Envia o contador.
func _emit_remaining() -> void:
	EventBus.enemies_remaining_changed.emit(_alive.size())


## Avisa a HUD da vitória.
## Mostra a vitória (se o jogador não morreu no intervalo) e agenda o avanço automático para a próxima cena.
func _complete_level() -> void:
	# O Player morreu no intervalo entre vencer e concluir: não mostra a vitória.
	if _player_dead:  # O jogador morreu entre vencer e concluir: mostra game over.
		_trigger_game_over()  # Mostra game over.
		return
	EventBus.level_completed.emit(next_scene)  # Avisa a HUD da vitória.
	# Transição Waves -> Quiz.
	# Há próxima cena e avanço automático ligado.
	if not next_scene.is_empty() and auto_advance_delay > 0.0:
		# Pede a troca de cena depois do tempo.
		_after(auto_advance_delay, func() -> void: EventBus.scene_change_requested.emit(next_scene))


## Avisa a HUD da derrota.
func _trigger_game_over() -> void:
	EventBus.game_over.emit()
