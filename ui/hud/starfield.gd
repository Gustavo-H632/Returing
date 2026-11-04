class_name Starfield
extends Control
## Céu de estrelas em pixel art que preenche a tela inteira atrás do letreiro "FIM DE JOGO".
## Usa a paleta do letreiro e o mesmo tamanho de pixel, então as laterais emendam com a arte.

const PALETTE: Array[Color] = [
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
const TWINKLE_FPS: float = 8.0
const SEED: int = 1945

## Faixa embaixo da tela que o letreiro não usa (espaço dos botões); precisa bater com o
## `offset_bottom` do GameOverBanner.
@export_range(0.0, 400.0, 1.0) var banner_bottom_margin: float = 110.0

var _pixel: float = 8.0
var _stars: Array[Dictionary] = []
var _elapsed: float = 0.0
var _last_step: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_rebuild)
	visibility_changed.connect(_on_visibility_changed)
	_rebuild()
	_on_visibility_changed()


func _on_visibility_changed() -> void:
	set_process(is_visible_in_tree())


## Sorteia as estrelas de novo quando o tamanho da tela muda (sempre com a mesma semente).
func _rebuild() -> void:
	_stars.clear()
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_pixel = maxf((size.y - banner_bottom_margin) / ART_PIXELS, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for y: int in ceili(size.y / _pixel):
		for x: int in ceili(size.x / _pixel):
			var roll: float = rng.randf()
			if roll < SPARKLE_CHANCE:
				_stars.append(_make_star(x, y, true, rng))
			elif roll < SPARKLE_CHANCE + DOT_CHANCE:
				_stars.append(_make_star(x, y, false, rng))
	queue_redraw()


func _make_star(x: int, y: int, sparkle: bool, rng: RandomNumberGenerator) -> Dictionary:
	var color: Color = PALETTE[rng.randi_range(0, 1)] if sparkle else PALETTE[rng.randi_range(0, PALETTE.size() - 1)]
	return {"cell": Vector2(x, y), "sparkle": sparkle, "color": color, "phase": rng.randf() * TAU}


func _process(delta: float) -> void:
	_elapsed += delta
	var step: int = int(_elapsed * TWINKLE_FPS)
	if step != _last_step:
		_last_step = step
		queue_redraw()


func _draw() -> void:
	for star: Dictionary in _stars:
		var color: Color = star["color"]
		# Pisca em degraus (pixel art): só liga/desliga, sem meio-termo borrado.
		var on: bool = sin(_elapsed * 2.4 + float(star["phase"])) > -0.55
		if not on:
			continue
		var origin: Vector2 = (star["cell"] as Vector2) * _pixel
		draw_rect(Rect2(origin, Vector2.ONE * _pixel), color)
		if star["sparkle"]:
			for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				draw_rect(Rect2(origin + dir * _pixel, Vector2.ONE * _pixel), color)
