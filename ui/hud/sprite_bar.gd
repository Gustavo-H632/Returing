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

## Sheet padrão (barra de vida) quando a cena não atribui outra.
const DEFAULT_SHEET_PATH: String = "res://sprites/HUD/Barra-Vida_sprite.png"

@export var sheet: Texture2D

@export_group("Nitidez (pixel art)")
## Ajusta o controle a um múltiplo inteiro do quadro: cada pixel do asset vira N x N pixels na
## tela (sem escala fracionária, que borra). Pede que a sheet tenha largura múltipla de 8 e
## altura múltipla de 7; senão os quadros ficam desalinhados e o aviso mostra o tamanho ideal.
@export var snap_to_integer_scale: bool = true

@export_group("Feedback de dano")
@export var flash_color: Color = Color(1.0, 0.3, 0.3)
@export_range(0.05, 1.0, 0.05) var flash_duration: float = 0.25

var _atlas: AtlasTexture = AtlasTexture.new()
var _frame_size: Vector2 = Vector2.ZERO
## Tamanho da faixa da barra em pixels inteiros (igual em todos os quadros).
var _strip_size: Vector2 = Vector2.ZERO
var _frame: int = -1
var _flash_tween: Tween = null
## Último valor recebido.
var _current: int = 1
var _maximum: int = 1


func _ready() -> void:
	if sheet == null and ResourceLoader.exists(DEFAULT_SHEET_PATH):
		sheet = load(DEFAULT_SHEET_PATH) as Texture2D
	if sheet == null:
		push_error("SpriteBar '%s': 'sheet' não foi atribuída; a barra não será desenhada." % name)
		return
	_frame_size = Vector2(sheet.get_width() / float(COLUMNS), sheet.get_height() / float(ROWS))
	_strip_size = Vector2(floorf(_frame_size.x), roundf(_frame_size.y * BAR_HEIGHT_RATIO))
	_warn_if_misaligned()
	_atlas.atlas = sheet
	_atlas.filter_clip = true  # o quadro vizinho não vaza para dentro da barra
	texture = _atlas
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art nítida em qualquer escala
	if snap_to_integer_scale:
		_snap_to_integer_scale()
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
	var column: int = frame % COLUMNS
	# Origem arredondada para pixels inteiros; o tamanho é o mesmo em todos os quadros.
	var origin := Vector2(
		roundf(float(column) * _frame_size.x),
		roundf(float(row) * _frame_size.y + _frame_size.y * BAR_TOP_RATIO)
	)
	_atlas.region = Rect2(origin, _strip_size)


## Reduz o controle ao maior múltiplo inteiro da faixa que cabe nos offsets da cena
## (a barra fica ancorada pela borda inferior esquerda). Se a faixa for maior que o controle,
## não há escala inteira possível e o tamanho da cena é mantido.
func _snap_to_integer_scale() -> void:
	if _strip_size.x <= 0.0 or _strip_size.y <= 0.0:
		return
	var available := Vector2(offset_right - offset_left, offset_bottom - offset_top)
	var fit: float = minf(available.x / _strip_size.x, available.y / _strip_size.y)
	if fit < 1.0:
		return
	var snapped_size: Vector2 = _strip_size * float(floori(fit))
	offset_right = offset_left + snapped_size.x
	offset_top = offset_bottom - snapped_size.y


## Avisa se a sheet não divide em quadros de tamanho inteiro (causa do borrão e do desalinhamento).
func _warn_if_misaligned() -> void:
	var width: int = sheet.get_width()
	var height: int = sheet.get_height()
	if width % COLUMNS == 0 and height % ROWS == 0:
		return
	push_warning("SpriteBar '%s': a sheet de %dx%d não divide em %dx%d quadros inteiros. Reexporte com %dx%d (quadros de %dx%d)." % [
		name, width, height, COLUMNS, ROWS,
		ceili(width / float(COLUMNS)) * COLUMNS, ceili(height / float(ROWS)) * ROWS,
		ceili(width / float(COLUMNS)), ceili(height / float(ROWS))])
