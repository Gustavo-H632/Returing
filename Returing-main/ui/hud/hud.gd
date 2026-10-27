class_name GameHUD
extends CanvasLayer
## HUD da fase. Só usa o EventBus.

@export_group("Jogador (arraste os nós)")
## Barra de vida em sprite, ancorada no canto inferior esquerdo pela cena.
@export var player_health_bar: SpriteBar
## Barra de ataque carregado (sprite azul), logo abaixo da barra de vida.
@export var charge_bar: SpriteBar

@export_group("Fim de jogo (arraste os nós)")
## Espera exata (s) entre o Game Over e o aparecimento do botão "Tentar de novo".
@export_range(0.0, 30.0, 0.5, "or_greater") var retry_delay: float = 5.0
@export var game_over_panel: Control
@export var retry_button: Button
@export var game_over_menu_button: Button

@export_group("Fim de fase (arraste os nós)")
@export var complete_panel: Control
## Título "Fase concluída!" (escondido quando a fase é a última).
@export var complete_label: Label
## Letreiro "Fim de jogo" (só aparece quando não há próxima fase).
@export var complete_banner: EndGameBanner
@export var continue_button: Button
@export var complete_menu_button: Button

var _next_scene: String = ""
var _bus_links: Array[Array] = []
var _valid: bool = false


## Conecta antes dos _ready para não perder o primeiro hp_changed.
func _enter_tree() -> void:
	_valid = _validate_references()
	if not _valid:
		return
	_bus_links = [
		[EventBus.player_hp_changed, _on_player_hp_changed],
		[EventBus.player_damaged, _on_player_damaged],
		[EventBus.player_charge_changed, _on_player_charge_changed],
		[EventBus.level_completed, _on_level_completed],
		[EventBus.game_over, _on_game_over],
	]
	for link: Array in _bus_links:
		CombatUtils.connect_once(link[0], link[1])


## Esconde os painéis, liga os botões e pede o estado atual do Player.
func _ready() -> void:
	if not _valid:
		return

	game_over_panel.hide()
	complete_panel.hide()
	if charge_bar != null:
		charge_bar.set_ratio(0.0)

	# Botões viram pedidos no EventBus.
	retry_button.pressed.connect(func() -> void: EventBus.level_restart_requested.emit())
	game_over_menu_button.pressed.connect(func() -> void: EventBus.main_menu_requested.emit())
	complete_menu_button.pressed.connect(func() -> void: EventBus.main_menu_requested.emit())
	continue_button.pressed.connect(_on_continue_pressed)

	EventBus.hud_refresh_requested.emit()


func _exit_tree() -> void:
	for link: Array in _bus_links:
		CombatUtils.disconnect_if_connected(link[0], link[1])


# --- Jogador ---

func _on_player_hp_changed(hp: int, hp_max: int) -> void:
	player_health_bar.set_health(hp, hp_max)


func _on_player_damaged(_amount: int) -> void:
	player_health_bar.flash()


## Barra de carga do tiro: enche de 0.0 a 1.0 enquanto o botão está pressionado.
func _on_player_charge_changed(ratio: float) -> void:
	if charge_bar != null:
		charge_bar.set_ratio(ratio)


# --- Fim de fase / fim de jogo ---

## Fase concluída: com próxima fase mostra "Continuar".
func _on_level_completed(next_scene: String) -> void:
	_next_scene = next_scene
	var has_next: bool = not next_scene.is_empty()
	continue_button.visible = has_next
	if complete_label != null:
		complete_label.visible = has_next
	if complete_banner != null:
		complete_banner.visible = not has_next
	complete_panel.show()
	(continue_button if has_next else complete_menu_button).grab_focus()


## Game Over em tela cheia (o painel cobre a HUD).
func _on_game_over() -> void:
	retry_button.hide()
	game_over_panel.show()
	game_over_menu_button.grab_focus()
	await get_tree().create_timer(retry_delay).timeout
	if not is_inside_tree() or not game_over_panel.visible:
		return  # A cena mudou durante a espera.
	retry_button.show()
	retry_button.grab_focus()


func _on_continue_pressed() -> void:
	if not _next_scene.is_empty():
		EventBus.scene_change_requested.emit(_next_scene)


## True se todos os nós obrigatórios foram arrastados no Inspector.
func _validate_references() -> bool:
	var missing: PackedStringArray = []
	if player_health_bar == null: missing.append("player_health_bar")
	if game_over_panel == null: missing.append("game_over_panel")
	if retry_button == null: missing.append("retry_button")
	if game_over_menu_button == null: missing.append("game_over_menu_button")
	if complete_panel == null: missing.append("complete_panel")
	if continue_button == null: missing.append("continue_button")
	if complete_menu_button == null: missing.append("complete_menu_button")
	if missing.is_empty():
		return true
	push_error("GameHUD: referências não atribuídas no Inspector: %s" % ", ".join(missing))
	return false
