extends CanvasLayer
## Overlay de depuração do acelerômetro (flag `--debug-tilt`): valores brutos, calibrados e a direção
## detectada. Criado pelo autoload TiltInput.

var _label: Label = null


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.position = Vector2(300.0, 8.0)
	_label.add_theme_font_size_override(&"font_size", 14)
	_label.add_theme_color_override(&"font_color", Color("#d6fefe"))
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 4)
	add_child(_label)


func _process(_delta: float) -> void:
	var tilt: Node = get_parent()
	var names: PackedStringArray = ["nenhuma", "CIMA", "BAIXO", "ESQUERDA", "DIREITA"]
	var dir: int = int(tilt.last_direction)
	_label.text = "tilt ativo=%s sensor=%s ausente=%s frame=%d\nbruto=%s\ncalib=%s\ninclin=%s\nseta=%s  plat=%s" % [
		tilt.is_active(), tilt.sensor_available, tilt.sensor_missing, tilt.resolved_frame,
		tilt.raw, tilt.calibration, tilt.current_tilt, names[dir + 1], Platform.platform_name()]
