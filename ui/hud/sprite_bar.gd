class_name SpriteBar
extends TextureRect
## Barra da HUD desenhada com uma spritesheet. Dois formatos:
## - Tira horizontal (`frame_count` > 0): N quadros lado a lado, cada um já recortado na barra
##   (ex.: Barra-Vida_pixel.png = 12 quadros, Barra-Carga_pixel.png = 44 quadros).
## - Grade 8 x 7 de 54 quadros (`frame_count` = 0, formato antigo).

const COLUMNS: int = 8  # Colunas da grade antiga.
const ROWS: int = 7  # Linhas da grade antiga.
const TOTAL_FRAMES: int = 54  # Total de quadros da grade antiga.
## Faixa vertical do quadro que contém a barra (o resto é margem transparente).
const BAR_TOP_RATIO: float = 0.38
const BAR_HEIGHT_RATIO: float = 0.30

## Sheet padrão (barra de vida) quando a cena não atribui outra.
const DEFAULT_SHEET_PATH: String = "res://sprites/HUD/Barra-Vida_pixel.png"
## Quadros do DEFAULT_SHEET_PATH (tira horizontal).
const DEFAULT_FRAME_COUNT: int = 12

@export var sheet: Texture2D  # Spritesheet da barra.
## Quadros da tira horizontal (0 = grade antiga 8 x 7). O primeiro quadro é a barra cheia e o
## último, a vazia.
@export_range(0, 256) var frame_count: int = 0

@export_group("Nitidez (pixel art)")
## Ajusta o controle a um múltiplo inteiro do quadro: cada pixel do asset vira N x N pixels na
## tela (sem escala fracionária, que borra). Pede que a sheet tenha largura múltipla de 8 e
## altura múltipla de 7; senão os quadros ficam desalinhados e o aviso mostra o tamanho ideal.
@export var snap_to_integer_scale: bool = true

@export_group("Feedback de dano")
@export var flash_color: Color = Color(1.0, 0.3, 0.3)  # Cor do pisca de dano.
@export_range(0.05, 1.0, 0.05) var flash_duration: float = 0.25  # Duração do pisca.

var _atlas: AtlasTexture = AtlasTexture.new()  # Textura recortada.
var _columns: int = COLUMNS  # Colunas em uso.
var _rows: int = ROWS  # Linhas em uso.
var _last_frame: int = TOTAL_FRAMES - 1  # Último quadro (barra vazia).
var _frame_size: Vector2 = Vector2.ZERO  # Tamanho de cada quadro.
## Tamanho da faixa da barra em pixels inteiros (igual em todos os quadros).
var _strip_size: Vector2 = Vector2.ZERO
var _frame: int = -1  # Quadro atual.
var _flash_tween: Tween = null  # Animação do pisca.
## Último valor recebido.
var _current: int = 1
var _maximum: int = 1  # Valor máximo recebido.


## Prepara a barra: carrega a sheet, calcula o tamanho dos quadros e mostra o quadro do valor atual.
func _ready() -> void:
	if sheet == null and ResourceLoader.exists(DEFAULT_SHEET_PATH):  # Sem sheet atribuída usa a padrão.
		sheet = load(DEFAULT_SHEET_PATH) as Texture2D  # Carrega a sheet padrão.
		frame_count = DEFAULT_FRAME_COUNT  # Quadros da sheet padrão.
	if sheet == null:  # Sem sheet não há como desenhar.
		# Avisa o erro.
		push_error("SpriteBar '%s': 'sheet' não foi atribuída; a barra não será desenhada." % name)
		return
	if frame_count > 0:  # tira horizontal: o quadro inteiro já é a barra
		_columns = frame_count  # Colunas.
		_rows = 1  # Uma linha.
		_frame_size = Vector2(sheet.get_width() / float(frame_count), sheet.get_height())  # Tamanho do quadro.
		_strip_size = _frame_size.floor()  # Faixa da barra.
	else:  # Grade antiga.
		_columns = COLUMNS  # Colunas.
		_rows = ROWS  # Linhas.
		# Tamanho do quadro.
		_frame_size = Vector2(sheet.get_width() / float(COLUMNS), sheet.get_height() / float(ROWS))
		# Faixa da barra.
		_strip_size = Vector2(floorf(_frame_size.x), roundf(_frame_size.y * BAR_HEIGHT_RATIO))
	_last_frame = _columns * _rows - 1  # Último quadro.
	_warn_if_misaligned()  # Avisa se a sheet não divide em quadros inteiros.
	_atlas.atlas = sheet  # Atlas sobre a sheet.
	_atlas.filter_clip = true  # o quadro vizinho não vaza para dentro da barra
	texture = _atlas  # Usa o atlas como textura.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art nítida em qualquer escala
	if snap_to_integer_scale:  # Ajusta à escala inteira.
		_snap_to_integer_scale()  # Ajusta.
	_frame = -1  # força o desenho, mesmo que set_health tenha rodado antes do _ready
	_show_frame(_frame_for(_current, _maximum))  # Mostra o quadro do valor.


## Atualiza o quadro a partir de um valor atual e um máximo (ex.: HP).
## Atualiza a barra a partir de um valor atual e um máximo (ex.: vida).
func set_health(current: int, maximum: int) -> void:
	_current = current  # Guarda o valor.
	_maximum = maximum  # Guarda o máximo.
	if _frame_size != Vector2.ZERO:  # antes do _ready só guarda o valor
		_show_frame(_frame_for(current, maximum))  # Mostra o quadro.


## Atualiza o quadro a partir de uma proporção de 0.0 a 1.0 (ex.: carga do tiro).
## Atualiza a barra a partir de uma proporção de 0.0 a 1.0 (ex.: carga do tiro).
func set_ratio(ratio: float) -> void:
	set_health(roundi(clampf(ratio, 0.0, 1.0) * 1000.0), 1000)  # Converte a proporção em valor inteiro.


## Pisca na cor de dano e volta à cor normal.
## Pisca na cor de dano e volta suavemente à cor normal.
func flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():  # Cancela o pisca anterior.
		_flash_tween.kill()
	modulate = flash_color  # Pinta de vermelho.
	_flash_tween = create_tween()  # Animação do pisca.
	# O dano do quiz chega com o jogo pausado.
	_flash_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # Roda mesmo com o jogo pausado.
	_flash_tween.tween_property(self, ^"modulate", Color.WHITE, flash_duration)  # Volta à cor normal.


## Quadro do valor.
## Escolhe o quadro do valor: zero = último (vazia); cheia = primeiro; senão proporcional, sem mostrar vazio ou cheio por engano.
func _frame_for(current: int, maximum: int) -> int:
	if current <= 0:  # Sem vida: barra vazia.
		return _last_frame  # Barra vazia.
	if current >= maximum:  # Vida cheia.
		return 0  # Barra cheia.
	var ratio: float = float(current) / float(maxi(maximum, 1))  # Fração de vida.
	# Quadro proporcional (nunca o primeiro nem o último).
	return clampi(roundi((1.0 - ratio) * _last_frame), 1, _last_frame - 1)


## Troca a região do atlas (só quando o quadro muda).
## Troca a região do atlas (só quando o quadro muda).
func _show_frame(frame: int) -> void:
	if frame == _frame:  # Mesmo quadro: nada a fazer.
		return
	_frame = frame  # Guarda o quadro.
	@warning_ignore("integer_division")
	var row: int = frame / _columns  # Linha do quadro.
	var column: int = frame % _columns  # Coluna do quadro.
	# Origem arredondada para pixels inteiros; o tamanho é o mesmo em todos os quadros.
	# Margem de cima (a tira horizontal não tem).
	var top_margin: float = 0.0 if frame_count > 0 else _frame_size.y * BAR_TOP_RATIO
	var origin := Vector2(  # Origem arredondada para pixels inteiros.
		roundf(float(column) * _frame_size.x),
		roundf(float(row) * _frame_size.y + top_margin)
	)
	_atlas.region = Rect2(origin, _strip_size)  # Recorta a região.


## Reduz o controle ao maior múltiplo inteiro da faixa que cabe nos offsets da cena
## (a barra fica ancorada pela borda inferior esquerda). Se a faixa for maior que o controle,
## não há escala inteira possível e o tamanho da cena é mantido.
func _snap_to_integer_scale() -> void:
	if _strip_size.x <= 0.0 or _strip_size.y <= 0.0:  # Faixa inválida.
		return
	# Tamanho disponível na cena.
	var available := Vector2(offset_right - offset_left, offset_bottom - offset_top)
	# Quantas vezes a faixa cabe.
	var fit: float = minf(available.x / _strip_size.x, available.y / _strip_size.y)
	if fit < 1.0:  # Não cabe nem uma vez: mantém o tamanho.
		return
	var snapped_size: Vector2 = _strip_size * float(floori(fit))  # Maior múltiplo inteiro.
	offset_right = offset_left + snapped_size.x  # Ajusta a largura.
	offset_top = offset_bottom - snapped_size.y  # Ajusta a altura (ancorada embaixo).


## Avisa se a sheet não divide em quadros de tamanho inteiro (causa do borrão e do desalinhamento).
func _warn_if_misaligned() -> void:
	var width: int = sheet.get_width()  # Largura da sheet.
	var height: int = sheet.get_height()  # Altura da sheet.
	if width % _columns == 0 and height % _rows == 0:  # Divide certinho: sem problema.
		return
	push_warning("SpriteBar '%s': a sheet de %dx%d não divide em %dx%d quadros inteiros. Reexporte com %dx%d (quadros de %dx%d)." % [
		name, width, height, _columns, _rows,
		ceili(width / float(_columns)) * _columns, ceili(height / float(_rows)) * _rows,
		ceili(width / float(_columns)), ceili(height / float(_rows))])
