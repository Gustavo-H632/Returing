class_name GuideLaser
extends GuideAttack
## Projétil de pontas redondas que atravessa a sala inteira: só o dash (invulnerável) escapa dele.

enum Phase { WARNING, SWEEP }

const COLOR_WARNING: Color = Color(1.0, 0.15, 0.15, 0.3)
const COLOR_SWEEP: Color = Color(1.0, 0.25, 0.25, 0.95)
const COLOR_CORE: Color = Color(1.0, 0.85, 0.85, 0.95)
## Largura do traço de aviso em relação à do projétil.
const WARNING_WIDTH_FACTOR: float = 0.6
## Velocidade do pisca do aviso.
const WARNING_PULSE_SPEED: float = 14.0
## Brilho do núcleo em relação à largura.
const CORE_WIDTH_FACTOR: float = 0.4

var _phase: Phase = Phase.WARNING
var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 520.0
var _length: float = 0.0
var _thickness: float = 10.0
var _wait_left: float = 0.0
var _travel_left: float = 0.0
var _damage: int = 0
var _elapsed: float = 0.0


## Prepara o raio: avisa na borda de saída, espera `wait_time` e varre `travel_distance` px.
func launch(start: Vector2, direction: Vector2, length: float, thickness: float, speed: float,
		travel_distance: float, wait_time: float, damage: int, from_source: Node) -> void:
	global_position = start
	source = from_source
	_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	# O eixo local Y é o comprimento do raio: ele fica perpendicular ao sentido da varredura.
	global_rotation = _direction.angle()
	_length = maxf(length, thickness)
	_thickness = maxf(thickness, 1.0)
	_speed = maxf(speed, 1.0)
	_travel_left = maxf(travel_distance, 0.0)
	_wait_left = maxf(wait_time, 0.0)
	_damage = damage
	_phase = Phase.WARNING
	_elapsed = 0.0
	var capsule := hit_shape.shape as CapsuleShape2D
	if capsule != null:
		capsule.radius = _thickness * 0.5
		capsule.height = _length
	queue_redraw()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	match _phase:
		Phase.WARNING:
			_wait_left -= delta
			if _wait_left <= 0.0:
				_phase = Phase.SWEEP
				arm(_damage)
			queue_redraw()
		Phase.SWEEP:
			var step: float = minf(_speed * delta, _travel_left)
			global_position += _direction * step
			_travel_left -= step
			if _travel_left <= 0.0:
				recycle()


func _draw() -> void:
	var half: float = _length * 0.5
	var from := Vector2(0.0, -half)
	var to := Vector2(0.0, half)
	if _phase == Phase.WARNING:
		var pulse: float = 0.5 + 0.5 * sin(_elapsed * WARNING_PULSE_SPEED)
		var color := COLOR_WARNING
		color.a *= 0.5 + 0.5 * pulse
		draw_line(from, to, color, _thickness * WARNING_WIDTH_FACTOR)
		return
	draw_line(from, to, COLOR_SWEEP, _thickness)
	draw_circle(from, _thickness * 0.5, COLOR_SWEEP)
	draw_circle(to, _thickness * 0.5, COLOR_SWEEP)
	draw_line(from, to, COLOR_CORE, _thickness * CORE_WIDTH_FACTOR)
