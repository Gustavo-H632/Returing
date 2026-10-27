class_name GuideShot
extends GuideAttack
## Tiro do Guide: anda reto e some na parede ou ao acabar a vida; com `child` ele se divide em 8.

## Direções da divisão: 4 ortogonais + 4 diagonais (passo de 45 graus).
const SPLIT_DIRECTIONS: int = 8
## Teto da recursão da divisão, mesmo que a receita tenha mais filhos encadeados.
const MAX_SPLIT_GENERATIONS: int = 3
const COLOR_MAIN: Color = Color(1.0, 0.45, 0.1, 0.95)
const COLOR_SMALL: Color = Color(1.0, 0.85, 0.2, 0.95)
const COLOR_OUTLINE: Color = Color(0.15, 0.0, 0.0, 0.9)
const OUTLINE_WIDTH: float = 2.0

## Camadas tratadas como parede (1 = Mundo).
@export_flags_2d_physics var wall_mask: int = 1

var _spec: GuideShotSpec = null
var _direction: Vector2 = Vector2.RIGHT
var _generation: int = 0
var _life_left: float = 0.0
var _split_left: float = 0.0


## Dispara o tiro em `direction` (vetor de mundo) a partir de `origin`.
func launch(origin: Vector2, direction: Vector2, spec: GuideShotSpec, generation: int,
		from_source: Node) -> void:
	global_position = origin
	source = from_source
	_spec = spec
	_generation = generation
	_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	_life_left = spec.lifetime
	_split_left = spec.split_delay
	set_hit_radius(spec.radius)
	arm(spec.damage)
	queue_redraw()


## Anda, confere parede e vida; o tiro com filhos divide no tempo certo.
func _physics_process(delta: float) -> void:
	if CombatUtils.move_until_wall(self, _direction * _spec.speed * delta, wall_mask, _spec.radius):
		_end_of_life()
		return
	_life_left -= delta
	_split_left -= delta
	if _life_left <= 0.0 or (_can_split() and _split_left <= 0.0):
		_end_of_life()


## Acertou o player: some sem dividir.
func _on_hitbox_hit_landed(_target: Area2D, _damage_dealt: int) -> void:
	recycle()


## Divide (se puder) e volta ao pool.
func _end_of_life() -> void:
	if _can_split():
		_split()
	recycle()


func _can_split() -> bool:
	return _spec != null and _spec.child != null and _generation < MAX_SPLIT_GENERATIONS


## Recursão da divisão: cada filho carrega a receita `child` e a geração seguinte,
## então pode dividir de novo até o teto MAX_SPLIT_GENERATIONS ou até o pool esgotar.
func _split() -> void:
	if not CombatUtils.is_valid(pool):
		return
	for i: int in SPLIT_DIRECTIONS:
		var piece := pool.acquire() as GuideShot
		if piece == null:
			return  # pool esgotado: a recursão para aqui
		piece.launch(global_position, Vector2.RIGHT.rotated(TAU * float(i) / float(SPLIT_DIRECTIONS)),
				_spec.child, _generation + 1, source)


func _draw() -> void:
	if _spec == null:
		return
	draw_circle(Vector2.ZERO, _spec.radius, COLOR_MAIN if _spec.child != null else COLOR_SMALL)
	draw_arc(Vector2.ZERO, _spec.radius, 0.0, TAU, 32, COLOR_OUTLINE, OUTLINE_WIDTH)
