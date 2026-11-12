class_name EndGameBanner
extends TextureRect
## Letreiro animado "FIM DE JOGO" (spritesheet Fim_sprite, 3 x 3 quadros).

const SHEET_PATH: String = "res://sprites/HUD/Fim_sprite.png"  # Caminho da spritesheet.
const COLUMNS: int = 3  # Colunas da spritesheet.
const ROWS: int = 3  # Linhas da spritesheet.
const TOTAL_FRAMES: int = COLUMNS * ROWS  # Total de quadros.

@export_range(1.0, 30.0, 0.5) var frames_per_second: float = 6.0  # Velocidade da animação.

var _sheet: Texture2D = null  # Spritesheet carregada.
var _atlas: AtlasTexture = AtlasTexture.new()  # Textura recortada que mostra um quadro por vez.
var _frame_size: Vector2 = Vector2.ZERO  # Tamanho de cada quadro.
var _frame: int = -1  # Quadro atual.
var _elapsed: float = 0.0  # Tempo acumulado.


## Carrega a spritesheet e monta a textura recortada; sem a imagem, desliga o letreiro.
func _ready() -> void:
	if not ResourceLoader.exists(SHEET_PATH):  # Sem a imagem não há como desenhar.
		# Avisa no console.
		push_warning("EndGameBanner: '%s' não existe; o letreiro não será desenhado." % SHEET_PATH)
		set_process(false)  # Desliga a animação.
		return
	_sheet = load(SHEET_PATH) as Texture2D  # Carrega a imagem.
	# Tamanho de cada quadro.
	_frame_size = Vector2(_sheet.get_width() / float(COLUMNS), _sheet.get_height() / float(ROWS))
	_atlas.atlas = _sheet  # Atlas sobre a imagem.
	texture = _atlas  # Usa o atlas como textura.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # Pixel art nítida.
	visibility_changed.connect(_on_visibility_changed)  # Liga o relógio só quando visível.
	_show_frame(0)  # Começa no primeiro quadro.
	_on_visibility_changed()  # Ajusta o estado inicial.


## Liga o relógio só quando o letreiro aparece e reinicia a animação.
func _on_visibility_changed() -> void:
	var showing: bool = is_visible_in_tree()
	set_process(showing)
	if showing:
		_elapsed = 0.0
		_show_frame(0)


## A cada quadro avança a animação em loop.
func _process(delta: float) -> void:
	_elapsed += delta  # Soma o tempo.
	_show_frame(int(_elapsed * frames_per_second) % TOTAL_FRAMES)  # Quadro atual em loop.


## Troca a região do atlas (só quando o quadro muda).
## Troca o quadro mostrado (só quando muda).
func _show_frame(frame: int) -> void:
	if frame == _frame:  # Mesmo quadro: nada a fazer.
		return
	_frame = frame  # Guarda o quadro.
	@warning_ignore("integer_division")
	var row: int = frame / COLUMNS  # Linha do quadro.
	# Recorta a região do quadro.
	_atlas.region = Rect2(Vector2(frame % COLUMNS, row) * _frame_size, _frame_size)
