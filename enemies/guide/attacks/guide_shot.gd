class_name GuideShot
extends GuideAttack
## Tiro do Guide: anda reto e some na parede ou ao acabar a vida; com `child` ele se divide em 8.

## Direções da divisão: 4 ortogonais + 4 diagonais (passo de 45 graus).
const SPLIT_DIRECTIONS: int = 8
## Teto da recursão da divisão, mesmo que a receita tenha mais filhos encadeados.
const MAX_SPLIT_GENERATIONS: int = 3
## Largura do orbe no sprite (guide_beam.png, quadro 0), em pixels do asset.
const ORB_WIDTH_PX: float = 15.0
## Centro do orbe no quadro de 64 x 64, relativo ao centro do quadro (para o orbe cair no nó).
const ORB_OFFSET: Vector2 = Vector2(3.5, -4.5)

## Quadros da animação do projétil (guide_shot.png: 8 quadros de 64 x 64 em uma linha).
const BEAM_FRAMES: int = 8
## Tamanho do quadro do projétil, em pixels do asset.
const BEAM_FRAME_SIZE: float = 64.0
## Largura do corpo do projétil (cabeça + haste), em pixels do asset.
const BEAM_WIDTH_PX: float = 22.0
## Eixo vertical do projétil no quadro (x do centro da cabeça), em pixels do asset.
const BEAM_AXIS_X: float = 29.5
## Linha em que a cabeça do projétil começa no quadro (a ponta que aponta para o alvo).
const BEAM_HEAD_TOP_Y: float = 27.0

## Camadas tratadas como parede (1 = Mundo).
@export_flags_2d_physics var wall_mask: int = 1
## Velocidade da animação do projétil, em quadros por segundo.
@export_range(1.0, 60.0, 0.5) var beam_fps: float = 12.0

@export_group("Referências (já ligadas na cena)")
## Sprite do orbe (quadro 0 da sheet guide_beam.png): tiros em que o principal se divide.
@export var sprite: Sprite2D
## Sprite animado do projétil do chefão (guide_shot.png, 8 quadros): tiro principal.
@export var beam_sprite: Sprite2D

var _spec: GuideShotSpec = null
var _direction: Vector2 = Vector2.RIGHT
var _generation: int = 0
var _life_left: float = 0.0
var _split_left: float = 0.0
var _anim_time: float = 0.0


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
	_anim_time = 0.0
	set_hit_radius(spec.radius)
	_apply_style(spec)
	arm(spec.damage)


## Anda, confere parede e vida; o tiro com filhos divide no tempo certo.
func _physics_process(delta: float) -> void:
	_animate_beam(delta)
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


## Mostra só o sprite do estilo pedido (projétil animado ou orbe) e o ajusta ao raio do tiro.
func _apply_style(spec: GuideShotSpec) -> void:
	var is_beam: bool = spec.style == GuideShotSpec.Style.BEAM
	if beam_sprite != null:
		beam_sprite.visible = is_beam
	if sprite != null:
		sprite.visible = not is_beam
	if is_beam:
		_fit_beam(spec.radius)
	else:
		_fit_orb(spec.radius)


## Ajusta o orbe ao tamanho do tiro com escala inteira (pixel art nítida): o diâmetro do
## sprite fica o mais perto possível do diâmetro da hitbox.
func _fit_orb(radius: float) -> void:
	if sprite == null:
		return
	var factor: float = maxf(roundf(radius * 2.0 / ORB_WIDTH_PX), 1.0)
	sprite.scale = Vector2.ONE * factor
	sprite.offset = ORB_OFFSET


## Ajusta o projétil animado: escala inteira (corpo ~ diâmetro da hitbox), ponta voltada para o
## voo e o nó (centro da hitbox) uma `radius` atrás da ponta, para a cabeça tocar o alvo primeiro.
func _fit_beam(radius: float) -> void:
	if beam_sprite == null:
		return
	var factor: float = maxf(roundf(radius * 2.0 / BEAM_WIDTH_PX), 1.0)
	var center_y: float = BEAM_HEAD_TOP_Y + radius / factor
	var half: float = BEAM_FRAME_SIZE * 0.5
	beam_sprite.scale = Vector2.ONE * factor
	beam_sprite.offset = Vector2(half - BEAM_AXIS_X, half - center_y)
	# O quadro aponta para cima (-Y); o voo é em `_direction`.
	beam_sprite.rotation = _direction.angle() + PI * 0.5
	beam_sprite.frame = 0


## Toca os quadros do projétil em loop.
func _animate_beam(delta: float) -> void:
	if beam_sprite == null or not beam_sprite.visible:
		return
	_anim_time += delta
	beam_sprite.frame = int(_anim_time * beam_fps) % BEAM_FRAMES
