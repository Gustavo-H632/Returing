class_name LevelManager
extends Node
## Regras da fase: conta inimigos vivos e decide vitória e derrota.
## Com WaveManager na cena, a vitória vem de all_waves_cleared.

## Próxima cena (vazio = só volta ao menu)
@export_file("*.tscn") var next_scene: String = ""
@export_range(0.0, 10.0, 0.1, "or_greater") var complete_delay: float = 1.0
@export_range(0.0, 10.0, 0.1, "or_greater") var game_over_delay: float = 1.5

var _alive: Dictionary[int, bool] = {}  # id dos inimigos vivos
var _had_enemies: bool = false
var _ended: bool = false
var _wave_mode: bool = false  # ligado no primeiro wave_started


## Conecta no EventBus.
func _enter_tree() -> void:
	# Conecta antes dos _ready dos inimigos
	EventBus.enemy_registered.connect(_on_enemy_registered)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.player_died.connect(_on_player_died)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.all_waves_cleared.connect(_on_all_waves_cleared)


## Anuncia o início da fase.
func _ready() -> void:
	# Conta inimigos já presentes
	for node in get_tree().get_nodes_in_group(CombatUtils.GROUP_ENEMY):
		_track(node)
	EventBus.level_started.emit()
	_emit_remaining()


## Desconecta do EventBus.
func _exit_tree() -> void:
	if EventBus.enemy_registered.is_connected(_on_enemy_registered):
		EventBus.enemy_registered.disconnect(_on_enemy_registered)
	if EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.disconnect(_on_enemy_died)
	if EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.disconnect(_on_player_died)
	if EventBus.wave_started.is_connected(_on_wave_started):
		EventBus.wave_started.disconnect(_on_wave_started)
	if EventBus.all_waves_cleared.is_connected(_on_all_waves_cleared):
		EventBus.all_waves_cleared.disconnect(_on_all_waves_cleared)


## Inimigos vivos.
func get_remaining() -> int:
	return _alive.size()


## Novo inimigo na fase.
func _on_enemy_registered(enemy: Node2D, _kind: StringName, _max_health: int) -> void:
	_track(enemy)
	_emit_remaining()


## Desconta e vence se acabou (fase sem ondas).
func _on_enemy_died(enemy: Node2D, _kind: StringName, _world_position: Vector2) -> void:
	if not _alive.erase(enemy.get_instance_id()):
		return
	_emit_remaining()
	# Com ondas quem decide é all_waves_cleared
	if _wave_mode:
		return
	if _alive.is_empty() and _had_enemies:
		_finish_level()


## Liga o modo ondas.
func _on_wave_started(_wave: int, _total_waves: int, _enemy_count: int) -> void:
	_wave_mode = true


## Vitória da fase com ondas.
func _on_all_waves_cleared() -> void:
	_finish_level()


## Game Over após o atraso.
func _on_player_died() -> void:
	if _ended:
		return
	_ended = true
	_after(game_over_delay, _trigger_game_over)


## Fase concluída (uma vez).
func _finish_level() -> void:
	if _ended:
		return
	_ended = true
	EventBus.enemies_cleared.emit()
	_after(complete_delay, _complete_level)


## Registra um inimigo vivo.
func _track(enemy: Node) -> void:
	if not CombatUtils.is_valid(enemy):
		return
	var id := enemy.get_instance_id()
	if _alive.has(id):
		return  # já contado
	_alive[id] = true
	_had_enemies = true
	# Inimigo removido sem morrer também sai da contagem
	if not enemy.tree_exited.is_connected(_on_enemy_tree_exited):
		enemy.tree_exited.connect(_on_enemy_tree_exited.bind(id))


## Inimigo saiu da árvore.
func _on_enemy_tree_exited(id: int) -> void:
	_check_vanished_enemy.call_deferred(id)


## Deferido: confere se o inimigo sumiu sem morrer.
func _check_vanished_enemy(id: int) -> void:
	if not is_inside_tree():
		return
	var node := instance_from_id(id) as Node
	if node != null and node.is_inside_tree():
		return
	if not _alive.erase(id):
		return
	_emit_remaining()
	if not _wave_mode and _alive.is_empty() and _had_enemies:
		_finish_level()


## Timer de jogo (respeita a pausa).
func _after(seconds: float, callback: Callable) -> void:
	var timer := CombatUtils.game_timer(self, seconds)
	if timer != null:
		timer.timeout.connect(callback)


## Envia o contador.
func _emit_remaining() -> void:
	EventBus.enemies_remaining_changed.emit(_alive.size())


## Avisa a HUD da vitória.
func _complete_level() -> void:
	EventBus.level_completed.emit(next_scene)


## Avisa a HUD da derrota.
func _trigger_game_over() -> void:
	EventBus.game_over.emit()
