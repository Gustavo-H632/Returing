class_name Starfield
extends Control
## Céu de estrelas em pixel art que preenche a tela inteira atrás do letreiro "FIM DE JOGO".
## Usa a paleta do letreiro e o mesmo tamanho de pixel, então as laterais emendam com a arte.

const PALETTE: Array[Color] = [  # Paleta das estrelas (a mesma do letreiro).
	Color(1.0, 1.0, 1.0),
	Color(0.0, 0.72, 1.0),
	Color(0.70, 0.30, 1.0),
	Color(0.85, 0.66, 1.0),
	Color(0.0, 0.22, 0.62),
]
## Pixels do letreiro na altura dele (a arte é 64 x 64).
const ART_PIXELS: float = 64.0
## Chance de uma célula ter uma estrela de 1 pixel.
const DOT_CHANCE: float = 0.014
## Chance de uma célula ter uma estrela de brilho (cruz de 5 pixels).
const SPARKLE_CHANCE: float = 0.0016
const TWINKLE_FPS: float = 8.0  # Velocidade do piscar.
const SEED: int = 1945  # Semente fixa: o céu é sempre o mesmo.

## Faixa embaixo da tela que o letreiro não usa (espaço dos botões); precisa bater com o
## `offset_bottom` do GameOverBanner.
@export_range(0.0, 400.0, 1.0) var banner_bottom_margin: float = 110.0

var _pixel: float = 8.0  # Tamanho de cada "pixel" do céu.
var _stars: Array[Dictionary] = []  # Estrelas sorteadas.
var _elapsed: float = 0.0  # Tempo acumulado.
var _last_step: int = -1  # Último passo de piscar desenhado.


## Não captura cliques, refaz o céu quando a tela muda de tamanho e só processa quando visível.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Só desenha.
	resized.connect(_rebuild)  # Refaz o céu ao mudar de tamanho.
	visibility_changed.connect(_on_visibility_changed)  # Liga ou desliga o processamento.
	_rebuild()  # Cria o céu.
	_on_visibility_changed()  # Ajusta o processamento.


## Só processa (pisca) enquanto está visível.
func _on_visibility_changed() -> void:
	set_process(is_visible_in_tree())  # Liga ou desliga.


## Sorteia as estrelas de novo quando o tamanho da tela muda (sempre com a mesma semente).
## Sorteia as estrelas sempre com a mesma semente (o céu não muda ao redimensionar).
func _rebuild() -> void:
	_stars.clear()  # Apaga as antigas.
	if size.x <= 0.0 or size.y <= 0.0:  # Sem tamanho: nada a criar.
		return
	_pixel = maxf((size.y - banner_bottom_margin) / ART_PIXELS, 1.0)  # Tamanho do pixel.
	var rng := RandomNumberGenerator.new()  # Gerador com semente fixa.
	rng.seed = SEED  # Semente.
	for y: int in ceili(size.y / _pixel):  # Cada linha de células.
		for x: int in ceili(size.x / _pixel):  # Cada coluna.
			var roll: float = rng.randf()  # Sorteio da célula.
			if roll < SPARKLE_CHANCE:  # Estrela de brilho.
				_stars.append(_make_star(x, y, true, rng))
			elif roll < SPARKLE_CHANCE + DOT_CHANCE:  # Estrela comum.
				_stars.append(_make_star(x, y, false, rng))
	queue_redraw()  # Pede o desenho.


## Cria os dados de uma estrela: posição, tipo, cor e fase do piscar.
func _make_star(x: int, y: int, sparkle: bool, rng: RandomNumberGenerator) -> Dictionary:
	# Cor (as de brilho usam só as duas primeiras).
	var color: Color = PALETTE[rng.randi_range(0, 1)] if sparkle else PALETTE[rng.randi_range(0, PALETTE.size() - 1)]
	# Dados da estrela.
	return {"cell": Vector2(x, y), "sparkle": sparkle, "color": color, "phase": rng.randf() * TAU}


## A cada quadro avança o tempo e só redesenha quando o passo do piscar muda.
func _process(delta: float) -> void:
	_elapsed += delta  # Soma o tempo.
	var step: int = int(_elapsed * TWINKLE_FPS)  # Passo do piscar.
	if step != _last_step:  # Mudou.
		_last_step = step  # Guarda.
		queue_redraw()  # Redesenha.


## Desenha as estrelas piscando em degraus (liga/desliga, sem meio-termo).
func _draw() -> void:
	for star: Dictionary in _stars:  # Cada estrela.
		var color: Color = star["color"]  # Cor.
		# Pisca em degraus (pixel art): só liga/desliga, sem meio-termo borrado.
		var on: bool = sin(_elapsed * 2.4 + float(star["phase"])) > -0.55  # Aceso ou apagado.
		if not on:  # Apagada: pula.
			continue
		var origin: Vector2 = (star["cell"] as Vector2) * _pixel  # Posição em pixels.
		draw_rect(Rect2(origin, Vector2.ONE * _pixel), color)  # Desenha o pixel.
		if star["sparkle"]:  # Brilho: cruz de 5 pixels.
			# Um pixel em cada direção.
			for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				draw_rect(Rect2(origin + dir * _pixel, Vector2.ONE * _pixel), color)  # Desenha.
