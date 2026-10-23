class_name SpriteBar
extends TextureRect
## Barra da HUD desenhada com uma spritesheet de 8 x 7 (54 quadros).

const COLUMNS: int = 8
const ROWS: int = 7
const TOTAL_FRAMES: int = 54
const LAST_FRAME: int = TOTAL_FRAMES - 1
## Faixa vertical do quadro que contém a barra (o resto é margem transparente).
const BAR_TOP_RATIO: float = 0.38
const BAR_HEIGHT_RATIO: float = 0.30

@export var sheet: Texture2D = preload("res://sprites/HUD/Barra-Vida_sprite.png")

@export_group("Feedback de dano")
@export var flash_color: Color = Color(1.0, 0.3, 0.3)
@export_range(0.05, 1.0, 0.05) var flash_duration: float = 0.25

var _atlas: AtlasTexture = AtlasTexture.new()
var _frame_size: Vector2 = Vector2.ZERO
var _frame: int = -1
var _flash_tween: Tween = null
## Último valor recebido.
var _current: int = 1
var _maximum: int = 1


func _ready() -> void:
	if sheet == null:
		push_error("SpriteBar '%s': 'sheet' não foi atribuída; a barra não será desenhada." % name)
		return
	_frame_size = Vector2(sheet.get_width() / float(COLUMNS), sheet.get_height() / float(ROWS))
	_atlas.atlas = sheet
	texture = _atlas
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art nítida em qualquer escala
	_frame = -1  # força o desenho, mesmo que set_health tenha rodado antes do _ready
	_show_frame(_frame_for(_current, _maximum))


## Atualiza o quadro a partir de um valor atual e um máximo (ex.: HP).
func set_health(current: int, maximum: int) -> void:
	_current = current
	_maximum = maximum
	if _frame_size != Vector2.ZERO:  # antes do _ready só guarda o valor
		_show_frame(_frame_for(current, maximum))


## Atualiza o quadro a partir de uma proporção de 0.0 a 1.0 (ex.: carga do tiro).
func set_ratio(ratio: float) -> void:
	set_health(roundi(clampf(ratio, 0.0, 1.0) * 1000.0), 1000)


## Pisca na cor de dano e volta à cor normal.
func flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	modulate = flash_color
	_flash_tween = create_tween()
	# O dano do quiz chega com o jogo pausado.
	_flash_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_flash_tween.tween_property(self, ^"modulate", Color.WHITE, flash_duration)


## Quadro do valor.
func _frame_for(current: int, maximum: int) -> int:
	if current <= 0:
		return LAST_FRAME
	if current >= maximum:
		return 0
	var ratio: float = float(current) / float(maxi(maximum, 1))
	return clampi(roundi((1.0 - ratio) * LAST_FRAME), 1, LAST_FRAME - 1)


## Troca a região do atlas (só quando o quadro muda).
func _show_frame(frame: int) -> void:
	if frame == _frame:
		return
	_frame = frame
	@warning_ignore("integer_division")
	var row: int = frame / COLUMNS
	var origin := Vector2(frame % COLUMNS, row) * _frame_size
	# Arredonda para pixels inteiros.
	_atlas.region = Rect2(
		floorf(origin.x),
		floorf(origin.y + _frame_size.y * BAR_TOP_RATIO),
		floorf(_frame_size.x),
		floorf(_frame_size.y * BAR_HEIGHT_RATIO)
	)
