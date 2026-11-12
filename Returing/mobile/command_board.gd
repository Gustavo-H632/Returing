class_name CommandBoard
extends Control
## Quadro de comandos do celular (canto superior direito, região do print `mobile_layout_zonas.png`).
## Só aparece com o modo comando aberto. Mostra: a sequência de setas digitada, o indicador de
## inclinação em tempo real (a bolinha acompanha o celular e a seta detectada acende), as habilidades
## com suas sequências e, sem acelerômetro, o aviso e o D-pad de fallback (toques tratados pelo MobileControls).
##
## Tamanho base fixo (`BASE_SIZE`); o layout só muda posição e escala (`MobileLayout.BOARD`).

## Tamanho do quadro com escala 1 (px lógicos).
const BASE_SIZE: Vector2 = Vector2(299.0, 361.0)
## Centro do D-pad de fallback e tamanho de cada botão (px locais).
const DPAD_CENTER: Vector2 = Vector2(149.5, 156.0)
const DPAD_CELL: float = 56.0
## Centro e diâmetro do indicador de inclinação (px locais).
const RING_CENTER: Vector2 = Vector2(78.0, 150.0)
const RING_SIZE: float = 116.0
## Quanto a bolinha anda (px) para uma inclinação de 0,5 (seno do ângulo).
const DOT_RANGE: float = 46.0
const SLOT_SIZE: float = 30.0  # Tamanho de cada seta digitada.
const SLOTS: int = 6  # Máximo de setas de uma sequência.
const ROWS_TOP: float = 248.0  # Onde começa a lista de habilidades.
const ROW_HEIGHT: float = 34.0
const MAX_ROWS: int = 3  # linhas que cabem no quadro (o resto vira "+N")
const FLASH_TIME: float = 0.4  # Quanto tempo a seta detectada fica acesa.
const FONT_TITLE: int = 20
const FONT_BODY: int = 16
const COLOR_TEXT: Color = Color("#ebddba")
const COLOR_MUTED: Color = Color("#a8957a")
const COLOR_WARN: Color = Color("#f2a93b")
const NAMES: Dictionary = {
	AbilityData.Dir.UP: "up", AbilityData.Dir.DOWN: "down", AbilityData.Dir.LEFT: "left", AbilityData.Dir.RIGHT: "right",
}

var _abilities: AbilityComponent = null
var _typed: Array[int] = []  # Setas digitadas na sequência atual.
var _flash_dir: int = -1  # Seta que acabou de ser digitada (acende por FLASH_TIME).
var _flash_left: float = 0.0
var _rows: Dictionary = {}  # id -> {"row": Control, "arrows": ArrowSequenceView}
var _rows_box: Control = null
var _notice: String = ""  # Aviso (ex.: sem habilidades).
var _overflow: int = 0  # Habilidades que não cabem nas linhas.


func _ready() -> void:
	add_to_group(&"mobile_layout_listeners")
	theme = UiPalette.load_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = BASE_SIZE
	custom_minimum_size = BASE_SIZE
	visible = false
	_rows_box = Control.new()
	_rows_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rows_box)
	TiltInput.tilt_changed.connect(_on_tilt_changed)
	TiltInput.sensor_state_changed.connect(_on_sensor_changed)
	get_viewport().size_changed.connect(apply_layout)
	apply_layout()


## Liga o quadro ao componente de habilidades do jogador.
func setup(abilities: AbilityComponent) -> void:
	_abilities = abilities
	CombatUtils.connect_once(abilities.command_mode_changed, _on_command_mode_changed)
	CombatUtils.connect_once(abilities.abilities_changed, _rebuild)
	CombatUtils.connect_once(abilities.input_progress, _on_input_progress)
	CombatUtils.connect_once(abilities.arrow_input, _on_arrow_input)
	CombatUtils.connect_once(abilities.input_failed, _on_input_failed)
	CombatUtils.connect_once(abilities.command_unavailable, _on_unavailable)
	_rebuild()


func _exit_tree() -> void:
	if not is_instance_valid(_abilities):
		return
	CombatUtils.disconnect_if_connected(_abilities.command_mode_changed, _on_command_mode_changed)
	CombatUtils.disconnect_if_connected(_abilities.abilities_changed, _rebuild)
	CombatUtils.disconnect_if_connected(_abilities.input_progress, _on_input_progress)
	CombatUtils.disconnect_if_connected(_abilities.arrow_input, _on_arrow_input)
	CombatUtils.disconnect_if_connected(_abilities.input_failed, _on_input_failed)
	CombatUtils.disconnect_if_connected(_abilities.command_unavailable, _on_unavailable)


## O layout mudou (editor de HUD, rotação da tela): reposiciona e reescala.
func on_mobile_layout_changed() -> void:
	apply_layout()


## Posição e escala vêm do layout (`MobileLayout.BOARD`).
func apply_layout() -> void:
	if not Platform.is_mobile():
		return
	var rect: Rect2 = MobileControls.control_rect(MobileLayout.BOARD)
	position = rect.position
	scale = Vector2.ONE * MobileControls.control_scale(MobileLayout.BOARD)
	size = BASE_SIZE


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		queue_redraw()


func _on_tilt_changed(_tilt: Vector2) -> void:
	if visible:
		queue_redraw()


func _on_sensor_changed(_available: bool) -> void:
	queue_redraw()


func _on_command_mode_changed(active: bool) -> void:
	visible = active and Platform.is_mobile()
	_typed.clear()
	_flash_left = 0.0
	if active:
		apply_layout()
		_notice = ""
	queue_redraw()


func _on_input_progress(sequence: Array[int], candidates: Array[AbilityData]) -> void:
	_typed = sequence.duplicate()
	for id: StringName in _rows:
		var entry: Dictionary = _rows[id]
		var data: AbilityData = entry["data"] as AbilityData
		var matches: bool = candidates.has(data)
		(entry["row"] as Control).modulate.a = 1.0 if matches else 0.35
		var arrows: ArrowSequenceView = entry["arrows"] as ArrowSequenceView
		arrows.set_progress(sequence.size() if matches else 0)
	queue_redraw()


func _on_arrow_input(dir: int) -> void:
	_flash_dir = dir
	_flash_left = FLASH_TIME
	queue_redraw()


func _on_input_failed() -> void:
	for entry: Dictionary in _rows.values():
		(entry["arrows"] as ArrowSequenceView).shake()


func _on_unavailable(_reason: StringName) -> void:
	_notice = "Sem habilidades ainda"
	queue_redraw()


## Recria as linhas de habilidades.
func _rebuild() -> void:
	for child: Node in _rows_box.get_children():
		child.queue_free()
	_rows.clear()
	if _abilities == null:
		return
	var y: float = ROWS_TOP
	_overflow = maxi(_abilities.abilities.size() - MAX_ROWS, 0)
	for data: AbilityData in _abilities.abilities.slice(0, MAX_ROWS):
		var row: Control = Control.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.position = Vector2(14.0, y)
		row.size = Vector2(BASE_SIZE.x - 28.0, ROW_HEIGHT)
		_rows_box.add_child(row)
		var amulet: AmuletIcon = AmuletIcon.new()
		amulet.custom_minimum_size = Vector2(32.0, 32.0)
		amulet.size = Vector2(32.0, 32.0)
		amulet.position = Vector2(0.0, 1.0)
		amulet.set_ability(data)
		row.add_child(amulet)
		var label: Label = Label.new()
		label.text = data.display_name
		label.position = Vector2(38.0, 0.0)
		label.size = Vector2(112.0, ROW_HEIGHT)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.clip_text = true
		label.add_theme_font_size_override(&"font_size", 14)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
		var arrows: ArrowSequenceView = ArrowSequenceView.new()
		arrows.arrow_size = 13.0
		arrows.arrow_gap = 2.0
		arrows.set_sequence(data.sequence)
		arrows.position = Vector2(155.0, (ROW_HEIGHT - 13.0) * 0.5)
		row.add_child(arrows)
		_rows[data.id] = {"data": data, "row": row, "arrows": arrows}
		y += ROW_HEIGHT
	queue_redraw()


func _sensor_missing() -> bool:
	return TiltInput.sensor_missing or bool(MobileSettings.get_value(MobileSettings.SECTION_TILT, "force_dpad", false))


func _draw() -> void:
	MobileDraw.frame(self, Rect2(Vector2.ZERO, BASE_SIZE))
	var font: Font = get_theme_default_font()
	draw_string(font, Vector2(16.0, 28.0), "MODO COMANDO", HORIZONTAL_ALIGNMENT_LEFT, 180.0, FONT_TITLE, COLOR_WARN)
	_draw_typed(font)
	if _sensor_missing():
		_draw_dpad(font)
	else:
		_draw_tilt(font)
	if _overflow > 0:
		draw_string(font, Vector2(16.0, BASE_SIZE.y - 6.0), "+%d habilidade(s)" % _overflow, HORIZONTAL_ALIGNMENT_LEFT, 200.0, 13, COLOR_MUTED)
	if _abilities != null and _abilities.abilities.is_empty():
		var text: String = _notice if _notice != "" else ("Treino: sem habilidades" if _abilities.practice else "Sem habilidades ainda")
		draw_string(font, Vector2(16.0, ROWS_TOP + 22.0), text, HORIZONTAL_ALIGNMENT_LEFT, BASE_SIZE.x - 32.0, FONT_BODY, COLOR_MUTED)


## Faixa com as setas já digitadas (6 casas).
func _draw_typed(_font: Font) -> void:
	var start_x: float = 16.0  # alinhado à esquerda: o botão de pausa fica por cima do canto direito do quadro
	for i: int in SLOTS:
		var slot: Rect2 = Rect2(Vector2(start_x + float(i) * (SLOT_SIZE + 4.0), 40.0), Vector2(SLOT_SIZE, SLOT_SIZE))
		draw_rect(slot, Color(0.0, 0.0, 0.0, 0.45))
		draw_rect(slot, Color("#5a4326"), false, 1.0)
		if i < _typed.size():
			draw_texture_rect(MobileDraw.tex("arrow_%s.png" % NAMES[_typed[i]]), slot.grow(-3.0), false)


## Indicador de inclinação: anel, bolinha e as quatro setas (a detectada acende).
func _draw_tilt(font: Font) -> void:
	var ring_rect: Rect2 = Rect2(RING_CENTER - Vector2(RING_SIZE, RING_SIZE) * 0.5, Vector2(RING_SIZE, RING_SIZE))
	draw_texture_rect(MobileDraw.tex("tilt_ring.png"), ring_rect, false)
	var lit: int = TiltInput.last_direction
	if _flash_left > 0.0:
		lit = _flash_dir
	var arrow_gap: float = RING_SIZE * 0.5 + 12.0
	var offsets: Dictionary = {
		AbilityData.Dir.UP: Vector2(0.0, -arrow_gap), AbilityData.Dir.DOWN: Vector2(0.0, arrow_gap),
		AbilityData.Dir.LEFT: Vector2(-arrow_gap, 0.0), AbilityData.Dir.RIGHT: Vector2(arrow_gap, 0.0),
	}
	for dir: int in offsets:
		var suffix: String = "_lit" if dir == lit else ""
		var arrow_rect: Rect2 = Rect2(RING_CENTER + (offsets[dir] as Vector2) - Vector2(11.0, 11.0), Vector2(22.0, 22.0))
		draw_texture_rect(MobileDraw.tex("arrow_%s%s.png" % [NAMES[dir], suffix]), arrow_rect, false)
	var offset: Vector2 = (TiltInput.current_tilt * (DOT_RANGE / 0.5)).limit_length(DOT_RANGE)
	var dot_center: Vector2 = RING_CENTER + offset
	draw_texture_rect(MobileDraw.tex("tilt_dot.png"), Rect2(dot_center - Vector2(9.0, 9.0), Vector2(18.0, 18.0)), false)
	var label: String = "Incline o celular"
	draw_multiline_string(font, Vector2(150.0, 118.0), label, HORIZONTAL_ALIGNMENT_LEFT, 138.0, FONT_BODY, 3, COLOR_TEXT)
	draw_multiline_string(font, Vector2(150.0, 170.0), "Volte ao centro entre uma seta e a próxima", HORIZONTAL_ALIGNMENT_LEFT, 138.0, 13, 4, COLOR_MUTED)


## Sem sensor: aviso e D-pad (os toques são do MobileControls, que usa `DPAD_CENTER` e `DPAD_CELL`).
func _draw_dpad(font: Font) -> void:
	var plate: float = DPAD_CELL * 3.0
	draw_texture_rect(MobileDraw.tex("dpad_base.png"), Rect2(DPAD_CENTER - Vector2(plate, plate) * 0.5, Vector2(plate, plate)), false)
	var offsets: Dictionary = {
		AbilityData.Dir.UP: Vector2(0.0, -DPAD_CELL), AbilityData.Dir.DOWN: Vector2(0.0, DPAD_CELL),
		AbilityData.Dir.LEFT: Vector2(-DPAD_CELL, 0.0), AbilityData.Dir.RIGHT: Vector2(DPAD_CELL, 0.0),
	}
	for dir: int in offsets:
		var suffix: String = "_lit" if (_flash_left > 0.0 and dir == _flash_dir) else ""
		var arrow_rect: Rect2 = Rect2(DPAD_CENTER + (offsets[dir] as Vector2) - Vector2(20.0, 20.0), Vector2(40.0, 40.0))
		draw_texture_rect(MobileDraw.tex("arrow_%s%s.png" % [NAMES[dir], suffix]), arrow_rect, false)
	draw_multiline_string(font, Vector2(10.0, 96.0), "Sem
sensor:
use as
setas", HORIZONTAL_ALIGNMENT_LEFT, 54.0, 13, 4, COLOR_WARN)
