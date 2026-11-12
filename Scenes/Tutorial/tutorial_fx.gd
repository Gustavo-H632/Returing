class_name TutorialFx
extends Node2D
## Efeitos visuais leves do tutorial, todos desenhados por código: faíscas, fumaça, peças do droide,
## poeira, vento, anéis de energia, clarões e o arco do corte. Sem texturas nem nós por partícula.

## Tipos de partícula.
enum Kind { SPARK, SMOKE, DEBRIS, DUST, WIND, RING, FLASH, ARC }

## Limite de partículas vivas (evita acúmulo se algo gerar demais).
const MAX_PARTICLES: int = 600
## Gravidade das peças do droide (px/s²).
const DEBRIS_GRAVITY: float = 520.0

const COLOR_SPARK: Color = Color("#ffd37a")  # Faísca quente.
const COLOR_SPARK_HOT: Color = Color("#fff4c8")  # Centro da faísca.
const COLOR_SMOKE: Color = Color("#2b2f38")  # Fumaça.
const COLOR_DEBRIS: Color = Color("#6b7380")  # Peças do droide.
const COLOR_DUST: Color = Color("#8d98a8")  # Poeira dos passos.
const COLOR_WIND: Color = Color("#bfe9ff")  # Linhas de vento do dash.
const COLOR_ENERGY: Color = Color("#3ad6ff")  # Anéis de energia.

## Uma partícula. Os campos servem a todos os tipos (alguns só usam parte deles).
class Particle:
	var kind: int = Kind.SPARK
	var position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var life: float = 0.5  # Tempo restante.
	var life_max: float = 0.5  # Tempo total.
	var size: float = 2.0  # Raio/espessura inicial.
	var size_end: float = 2.0  # Raio/espessura final.
	var color: Color = Color.WHITE
	var angle: float = 0.0  # Rotação (peças e arco).
	var spin: float = 0.0  # Giro por segundo.
	var gravity: float = 0.0  # Aceleração para baixo.
	var drag: float = 0.0  # Perda de velocidade por segundo.


var _particles: Array[Particle] = []  # Partículas vivas.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()  # Sorteio dos efeitos.


## Fica acima do chão e dos personagens.
func _ready() -> void:
	z_index = 40
	_rng.randomize()
	set_process(false)  # Só roda enquanto há partículas.


## Quantas partículas estão vivas (usado nos testes).
func count() -> int:
	return _particles.size()


## Atualiza e redesenha enquanto houver partículas.
func _process(delta: float) -> void:
	var i: int = _particles.size() - 1
	while i >= 0:  # De trás para frente para poder remover.
		var p: Particle = _particles[i]
		p.life -= delta
		if p.life <= 0.0:
			_particles.remove_at(i)
		else:
			p.velocity.y += p.gravity * delta
			if p.drag > 0.0:
				p.velocity = p.velocity.move_toward(Vector2.ZERO, p.drag * delta)
			p.position += p.velocity * delta
			p.angle += p.spin * delta
		i -= 1
	queue_redraw()
	if _particles.is_empty():
		set_process(false)


## Desenha todas as partículas.
func _draw() -> void:
	for p: Particle in _particles:
		var t: float = 1.0 - p.life / p.life_max  # 0 = nasceu, 1 = vai sumir.
		var radius: float = lerpf(p.size, p.size_end, t)
		var color: Color = p.color
		color.a = p.color.a * (1.0 - t)
		match p.kind:
			Kind.SPARK:
				var tail: Vector2 = p.velocity.normalized() * radius * 3.0  # Rastro curto.
				draw_line(p.position - tail, p.position, color, maxf(radius * 0.8, 1.0))
				draw_circle(p.position, maxf(radius * 0.5, 0.8), COLOR_SPARK_HOT * Color(1, 1, 1, color.a))
			Kind.SMOKE:
				draw_circle(p.position, radius, color)
			Kind.DEBRIS:
				draw_set_transform(p.position, p.angle)
				draw_rect(Rect2(Vector2(-radius, -radius * 0.6), Vector2(radius * 2.0, radius * 1.2)), color)
				draw_set_transform(Vector2.ZERO, 0.0)
			Kind.DUST:
				draw_circle(p.position, radius, color)
			Kind.WIND:
				var tail: Vector2 = p.velocity.normalized() * radius
				draw_line(p.position - tail, p.position, color, 1.5)
			Kind.RING:
				draw_arc(p.position, radius, 0.0, TAU, 40, color, 3.0 * (1.0 - t) + 1.0)
			Kind.FLASH:
				draw_circle(p.position, radius, color)
				draw_circle(p.position, radius * 0.5, Color(1, 1, 1, color.a))
			Kind.ARC:
				# Arco de corte: gomo fino que se abre e some. `angle` é a direção do golpe.
				var half: float = deg_to_rad(62.0)
				var thickness: float = lerpf(9.0, 2.0, t)
				draw_arc(p.position, radius, p.angle - half, p.angle + half, 24, color, thickness, true)
				draw_arc(p.position, radius - 5.0, p.angle - half * 0.8, p.angle + half * 0.8, 20,
						Color(1, 1, 1, color.a * 0.7), thickness * 0.4, true)


# --- Efeitos prontos ---

## Faíscas saindo de `at`. `direction` (ou todas as direções se for zero) e `spread` em radianos.
func sparks(at: Vector2, amount: int, direction: Vector2 = Vector2.ZERO, spread: float = TAU,
		speed: float = 220.0) -> void:
	for n: int in amount:
		var base: float = direction.angle() if direction != Vector2.ZERO else _rng.randf() * TAU
		var angle: float = base + _rng.randf_range(-spread * 0.5, spread * 0.5)
		var p: Particle = _spawn(Kind.SPARK, at)
		p.velocity = Vector2.from_angle(angle) * _rng.randf_range(speed * 0.4, speed)
		p.life = _rng.randf_range(0.2, 0.5)
		p.life_max = p.life
		p.size = _rng.randf_range(1.6, 3.0)
		p.size_end = 0.8
		p.color = COLOR_SPARK
		p.gravity = 320.0
		p.drag = 120.0


## Nuvem de fumaça escura que sobe e se espalha.
func smoke(at: Vector2, amount: int, radius: float = 10.0) -> void:
	for n: int in amount:
		var p: Particle = _spawn(Kind.SMOKE, at + Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-8.0, 8.0)))
		p.velocity = Vector2(_rng.randf_range(-30.0, 30.0), _rng.randf_range(-60.0, -15.0))
		p.life = _rng.randf_range(0.6, 1.2)
		p.life_max = p.life
		p.size = radius * _rng.randf_range(0.5, 0.9)
		p.size_end = radius * _rng.randf_range(1.6, 2.4)
		p.color = COLOR_SMOKE
		p.color.a = 0.75
		p.drag = 40.0


## Peças do droide voando e caindo.
func debris(at: Vector2, amount: int) -> void:
	for n: int in amount:
		var p: Particle = _spawn(Kind.DEBRIS, at)
		p.velocity = Vector2(_rng.randf_range(-190.0, 190.0), _rng.randf_range(-320.0, -90.0))
		p.life = _rng.randf_range(0.7, 1.2)
		p.life_max = p.life
		p.size = _rng.randf_range(2.5, 5.5)
		p.size_end = p.size
		p.color = COLOR_DEBRIS.lerp(Color.WHITE, _rng.randf() * 0.3)
		p.angle = _rng.randf() * TAU
		p.spin = _rng.randf_range(-12.0, 12.0)
		p.gravity = DEBRIS_GRAVITY
		p.drag = 20.0


## Poeirinha nos pés ao andar.
func dust(at: Vector2, direction: Vector2 = Vector2.ZERO) -> void:
	var p: Particle = _spawn(Kind.DUST, at)
	p.velocity = -direction * _rng.randf_range(10.0, 30.0) + Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-12.0, -2.0))
	p.life = _rng.randf_range(0.3, 0.5)
	p.life_max = p.life
	p.size = _rng.randf_range(2.0, 3.0)
	p.size_end = 5.5
	p.color = COLOR_DUST
	p.color.a = 0.45
	p.drag = 60.0


## Linhas de vento atrás do dash (`direction` é para onde o dash vai).
func wind(at: Vector2, direction: Vector2, amount: int = 3) -> void:
	var side: Vector2 = direction.orthogonal()
	for n: int in amount:
		var p: Particle = _spawn(Kind.WIND, at + side * _rng.randf_range(-16.0, 16.0))
		p.velocity = -direction * _rng.randf_range(160.0, 320.0)
		p.life = _rng.randf_range(0.15, 0.3)
		p.life_max = p.life
		p.size = _rng.randf_range(14.0, 30.0)
		p.size_end = p.size * 0.4
		p.color = COLOR_WIND
		p.color.a = 0.8


## Anel de energia que se expande.
func ring(at: Vector2, end_radius: float = 70.0, time: float = 0.45, color: Color = COLOR_ENERGY) -> void:
	var p: Particle = _spawn(Kind.RING, at)
	p.life = time
	p.life_max = time
	p.size = 4.0
	p.size_end = end_radius
	p.color = color


## Clarão rápido (impacto, boca da arma, aparição).
func flash(at: Vector2, radius: float = 22.0, time: float = 0.12, color: Color = Color(1, 0.95, 0.75, 0.9)) -> void:
	var p: Particle = _spawn(Kind.FLASH, at)
	p.life = time
	p.life_max = time
	p.size = radius
	p.size_end = radius * 0.3
	p.color = color


## Arco de corte da espada em `at`, apontando para `direction`.
func slash_arc(at: Vector2, direction: Vector2, radius: float = 54.0) -> void:
	var p: Particle = _spawn(Kind.ARC, at)
	p.angle = direction.angle()
	p.life = 0.16
	p.life_max = 0.16
	p.size = radius * 0.75
	p.size_end = radius
	p.color = Color(0.85, 0.95, 1.0, 0.95)


## Clarão e faíscas na boca da arma (`direction` é a direção do tiro).
func muzzle_flash(at: Vector2, direction: Vector2) -> void:
	flash(at, 16.0, 0.09, Color(0.6, 0.9, 1.0, 0.95))
	sparks(at, 5, direction, deg_to_rad(40.0), 260.0)


## Explosão do droide: clarão, anel, faíscas, fumaça e peças.
func explosion(at: Vector2) -> void:
	flash(at, 46.0, 0.2, Color(1.0, 0.8, 0.4, 0.95))
	ring(at, 90.0, 0.5, Color(1.0, 0.7, 0.3, 0.9))
	sparks(at, 30, Vector2.ZERO, TAU, 380.0)
	smoke(at, 10, 16.0)
	debris(at, 14)


## Cria uma partícula na lista (descarta a mais antiga se passar do limite) e liga o processamento.
func _spawn(kind: int, at: Vector2) -> Particle:
	if _particles.size() >= MAX_PARTICLES:
		_particles.remove_at(0)
	var p: Particle = Particle.new()
	p.kind = kind
	p.position = at
	_particles.append(p)
	set_process(true)
	return p
