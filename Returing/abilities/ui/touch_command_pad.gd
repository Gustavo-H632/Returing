class_name TouchCommandPad
extends Control
## Toque nos amuletos da faixa de habilidades (só no celular): abre o menu "SUA BUILD". O botão do modo
## comando e as setas agora são do `MobileControls` + `CommandBoard` (as setas vêm da inclinação do celular).
## Trata o toque por conta própria porque o `MobileControls` consome os cliques emulados do toque.

## Toque no amuleto de uma habilidade da faixa compacta (abre o menu de build).
signal build_requested(ability: AbilityData)

var _hud: CommandHud = null  # HUD de comando (fornece as áreas dos slots).
var _abilities: AbilityComponent = null  # Componente de habilidades.


## Cobre a tela inteira sem capturar cliques; no PC (sem `--mobile`) fica escondido.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Não bloqueia cliques do jogo.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # Ocupa a tela toda.
	if not Platform.is_mobile():  # Fora do celular não aparece nem escuta toques.
		visible = false
		set_process_input(false)


## Liga ao componente de habilidades e à HUD (que fornece as áreas dos slots).
func setup(abilities: AbilityComponent, hud: CommandHud = null) -> void:
	_abilities = abilities
	_hud = hud


## Recebe os toques (ou o clique do mouse na simulação) e consome o que cair num amuleto.
func _input(event: InputEvent) -> void:
	if _hud == null or (_abilities != null and _abilities.command_active) or get_tree().paused:
		return
	var pos: Vector2 = Vector2.ZERO
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	var click: InputEventMouseButton = event as InputEventMouseButton
	if touch != null and touch.pressed:
		pos = touch.position
	elif click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT \
			and Platform.mouse_as_finger and click.device != InputEvent.DEVICE_ID_EMULATION:
		pos = click.position  # PC com `--mobile`: o mouse faz o papel do dedo
	else:
		return
	for entry: Dictionary in _hud.get_slot_hit_rects():  # Passa pelas áreas dos slots.
		if (entry["rect"] as Rect2).has_point(pos):
			build_requested.emit(entry["ability"] as AbilityData)
			get_viewport().set_input_as_handled()
			return
