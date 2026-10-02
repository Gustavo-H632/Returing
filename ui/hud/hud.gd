class_name GameHUD
extends CanvasLayer
## HUD da fase. Só usa o EventBus (sem referência ao Player, inimigos ou LevelManager).

## Nome exibido por tipo de inimigo
## Inimigo novo = uma linha aqui no Inspector
@export var kind_names: Dictionary[StringName, String] = {
	&"tank": "Tank",
	&"chaser": "Perseguidor",
	&"shooter": "Atirador",
}

## Tempo que a barra do inimigo atingido fica na tela
@export_range(0.5, 10.0, 0.1, "or_greater") var enemy_bar_duration: float = 3.0

@export_group("Jogador (arraste os nós)")
@export var player_hp_bar: ProgressBar
@export var player_hp_label: Label
@export var charge_bar: ProgressBar
@export var enemies_label: Label
## Mostra "Onda N / M" (oculto em fase sem ondas)
@export var wave_label: Label

@export_group("Inimigo atingido (arraste os nós)")
@export var enemy_panel: Control
@export var enemy_name_label: Label
@export var enemy_health_bar: ProgressBar

@export_group("Fim de fase (arraste os nós)")
@export var game_over_panel: Control
@export var retry_button: Button
@export var game_over_menu_button: Button
@export var complete_panel: Control
@export var continue_button: Button
@export var complete_menu_button: Button

var _tracked_enemy_id: int = 0
var _enemy_bar_left: float = 0.0
var _next_scene: String = ""
var _flash_tween: Tween = null


## Conecta nos sinais do EventBus.
func _enter_tree() -> void:
	# Conecta antes para não perder o primeiro hp_changed
	EventBus.player_hp_changed.connect(_on_player_hp_changed)
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.player_charge_changed.connect(_on_player_charge_changed)
	EventBus.enemy_damaged.connect(_on_enemy_damaged)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.enemies_remaining_changed.connect(_on_enemies_remaining_changed)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.all_waves_cleared.connect(_on_all_waves_cleared)
	EventBus.level_completed.connect(_on_level_completed)
	EventBus.game_over.connect(_on_game_over)


## Esconde os painéis e liga os botões.
func _ready() -> void:
	_validar_referencias()
	set_process(false)

	if enemy_panel != null: enemy_panel.hide()
	if game_over_panel != null: game_over_panel.hide()
	if complete_panel != null: complete_panel.hide()
	if charge_bar != null: charge_bar.hide()
	if wave_label != null: wave_label.hide()

	# Botões viram pedidos no EventBus
	if retry_button != null:
		retry_button.pressed.connect(func() -> void: EventBus.level_restart_requested.emit())
	if game_over_menu_button != null:
		game_over_menu_button.pressed.connect(func() -> void: EventBus.main_menu_requested.emit())
	if complete_menu_button != null:
		complete_menu_button.pressed.connect(func() -> void: EventBus.main_menu_requested.emit())
	if continue_button != null:
		continue_button.pressed.connect(_on_continue_pressed)

	# Pede o estado atual do Player
	EventBus.hud_refresh_requested.emit()


## Desconecta do EventBus.
func _exit_tree() -> void:
	_desconectar(EventBus.player_hp_changed, _on_player_hp_changed)
	_desconectar(EventBus.player_damaged, _on_player_damaged)
	_desconectar(EventBus.player_charge_changed, _on_player_charge_changed)
	_desconectar(EventBus.enemy_damaged, _on_enemy_damaged)
	_desconectar(EventBus.enemy_died, _on_enemy_died)
	_desconectar(EventBus.enemies_remaining_changed, _on_enemies_remaining_changed)
	_desconectar(EventBus.wave_started, _on_wave_started)
	_desconectar(EventBus.wave_cleared, _on_wave_cleared)
	_desconectar(EventBus.all_waves_cleared, _on_all_waves_cleared)
	_desconectar(EventBus.level_completed, _on_level_completed)
	_desconectar(EventBus.game_over, _on_game_over)


## Conta o tempo da barra do inimigo.
func _process(delta: float) -> void:
	_enemy_bar_left -= delta
	if _enemy_bar_left <= 0.0:
		if enemy_panel != null:
			enemy_panel.hide()
		_tracked_enemy_id = 0
		set_process(false)


## Atualiza barra e texto de HP.
func _on_player_hp_changed(hp: int, hp_max: int) -> void:
	if player_hp_bar != null:
		player_hp_bar.max_value = maxi(hp_max, 1)
		player_hp_bar.value = hp
	if player_hp_label != null:
		player_hp_label.text = "HP %d / %d" % [hp, hp_max]


## Pisca a barra de HP.
func _on_player_damaged(_amount: int) -> void:
	if player_hp_bar == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	player_hp_bar.modulate = Color(1.0, 0.3, 0.3)
	_flash_tween = create_tween()
	_flash_tween.tween_property(player_hp_bar, ^"modulate", Color.WHITE, 0.25)


## Barra de carga do tiro.
func _on_player_charge_changed(ratio: float) -> void:
	if charge_bar == null:
		return
	charge_bar.visible = ratio > 0.0
	charge_bar.max_value = 1.0
	charge_bar.value = ratio


## Mostra a barra do inimigo atingido.
func _on_enemy_damaged(enemy: Node2D, kind: StringName, _amount: int, current_health: int, max_health: int) -> void:
	if enemy_panel == null:
		return
	_tracked_enemy_id = enemy.get_instance_id() if CombatUtils.is_valid(enemy) else 0
	if enemy_name_label != null:
		enemy_name_label.text = str(kind_names.get(kind, kind))
	if enemy_health_bar != null:
		enemy_health_bar.max_value = maxi(max_health, 1)
		enemy_health_bar.value = current_health
	enemy_panel.show()
	_enemy_bar_left = enemy_bar_duration
	set_process(true)


## Zera a barra se o inimigo morto era o mostrado.
func _on_enemy_died(enemy: Node2D, _kind: StringName, _world_position: Vector2) -> void:
	if enemy_panel == null or not enemy_panel.visible:
		return
	if enemy.get_instance_id() != _tracked_enemy_id:
		return
	if enemy_health_bar != null:
		enemy_health_bar.value = 0
	_enemy_bar_left = minf(_enemy_bar_left, 0.6)


## Contador de inimigos.
func _on_enemies_remaining_changed(remaining: int) -> void:
	if enemies_label != null:
		enemies_label.text = "Inimigos: %d" % remaining


## Texto da onda atual.
func _on_wave_started(wave: int, total_waves: int, _enemy_count: int) -> void:
	_set_wave_text("Onda %d / %d" % [wave, total_waves])


## Texto de onda concluída.
func _on_wave_cleared(wave: int, total_waves: int) -> void:
	_set_wave_text("Onda %d / %d concluída!" % [wave, total_waves])


## Texto final das ondas.
func _on_all_waves_cleared() -> void:
	_set_wave_text("Todas as ondas concluídas!")


## Escreve e mostra o rótulo da onda.
func _set_wave_text(text: String) -> void:
	if wave_label == null:
		return
	wave_label.text = text
	wave_label.show()


## Painel de fase concluída.
func _on_level_completed(next_scene: String) -> void:
	_next_scene = next_scene
	if continue_button != null:
		continue_button.visible = not next_scene.is_empty()
	if complete_panel != null:
		complete_panel.show()
	var focus_target: Button = continue_button if not next_scene.is_empty() else complete_menu_button
	if focus_target != null:
		focus_target.grab_focus()


## Painel de Game Over.
func _on_game_over() -> void:
	if game_over_panel != null:
		game_over_panel.show()
	if retry_button != null:
		retry_button.grab_focus()


## Pede a próxima fase.
func _on_continue_pressed() -> void:
	if not _next_scene.is_empty():
		EventBus.scene_change_requested.emit(_next_scene)


## Avisa slots vazios.
func _validar_referencias() -> void:
	var faltando: PackedStringArray = []
	if player_hp_bar == null: faltando.append("player_hp_bar")
	if enemy_panel == null: faltando.append("enemy_panel")
	if game_over_panel == null: faltando.append("game_over_panel")
	if retry_button == null: faltando.append("retry_button")
	if not faltando.is_empty():
		push_warning("GameHUD: referências não atribuídas no Inspector: %s" % ", ".join(faltando))


## Desconecta se estiver conectado.
func _desconectar(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)
