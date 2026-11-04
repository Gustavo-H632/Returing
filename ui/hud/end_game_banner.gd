class_name EndGameBanner
extends TextureRect
## Letreiro animado "FIM DE JOGO" (spritesheet Fim_sprite, 3 x 3 quadros).

const SHEET_PATH: String = "res://sprites/HUD/Fim_sprite.png"
const COLUMNS: int = 3
const ROWS: int = 3
const TOTAL_FRAMES: int = COLUMNS * ROWS

@export_range(1.0, 30.0, 0.5) var frames_per_second: float = 6.0

var _sheet: Texture2D = null
var _atlas: AtlasTexture = AtlasTexture.new()
var _frame_size: Vector2 = Vector2.ZERO
var _frame: int = -1
var _elapsed: float = 0.0


func _ready() -> void:
	if not ResourceLoader.exists(SHEET_PATH):
		push_warning("EndGameBanner: '%s' não existe; o letreiro não será desenhado." % SHEET_PATH)
		set_process(false)
		return
	_sheet = load(SHEET_PATH) as Texture2D
	_frame_size = Vector2(_sheet.get_width() / float(COLUMNS), _sheet.get_height() / float(ROWS))
	_atlas.atlas = _sheet
	texture = _atlas
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visibility_changed.connect(_on_visibility_changed)
	_show_frame(0)
	_on_visibility_changed()


## Liga o relógio só quando o letreiro aparece e reinicia a animação.
func _on_visibility_changed() -> void:
	var showing: bool = is_visible_in_tree()
	set_process(showing)
	if showing:
		_elapsed = 0.0
		_show_frame(0)


func _process(delta: float) -> void:
	_elapsed += delta
	_show_frame(int(_elapsed * frames_per_second) % TOTAL_FRAMES)


## Troca a região do atlas (só quando o quadro muda).
func _show_frame(frame: int) -> void:
	if frame == _frame:
		return
	_frame = frame
	@warning_ignore("integer_division")
	var row: int = frame / COLUMNS
	_atlas.region = Rect2(Vector2(frame % COLUMNS, row) * _frame_size, _frame_size)
