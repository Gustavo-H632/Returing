extends ProgressBar
## Barra de vida do player desenhada com a spritesheet Barra-Vida (8 x 7, 54 quadros).

const COLUMNS: int = 8
const ROWS: int = 7
const TOTAL_FRAMES: int = 54
const SHEET: Texture2D = preload("res://sprites/HUD/Barra-Vida_sprite.png")

@onready var sprite: TextureRect = $Sprite

var _atlas: AtlasTexture = AtlasTexture.new()
var _frame_w: float = 0.0
var _frame_h: float = 0.0


func _ready() -> void:
	_atlas.atlas = SHEET
	_frame_w = float(SHEET.get_width()) / COLUMNS
	_frame_h = float(SHEET.get_height()) / ROWS
	sprite.texture = _atlas
	changed.connect(_atualizar_sprite)
	value_changed.connect(func(_v: float) -> void: _atualizar_sprite())
	_atualizar_sprite()


func _atualizar_sprite() -> void:
	var frame: int = roundi((1.0 - ratio) * (TOTAL_FRAMES - 1))
	var col: int = frame % COLUMNS
	var row: int = frame / COLUMNS
	_atlas.region = Rect2(col * _frame_w, row * _frame_h + _frame_h * 0.38, _frame_w, _frame_h * 0.30)
