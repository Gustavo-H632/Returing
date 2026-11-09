class_name GuideLaser
extends GuideAttack
## Projétil de pontas redondas que atravessa a sala inteira: só o dash (invulnerável) escapa dele.

enum Phase { WARNING, SWEEP }  # Fases do raio: aviso e varredura.

const COLOR_WARNING: Color = Color(1.0, 0.15, 0.15, 0.3)  # Cor do aviso.
const COLOR_SWEEP: Color = Color(1.0, 0.25, 0.25, 0.95)  # Cor da varredura.
const COLOR_CORE: Color = Color(1.0, 0.85, 0.85, 0.95)  # Cor do núcleo brilhante.
## Largura do traço de aviso em relação à do projétil.
const WARNING_WIDTH_FACTOR: float = 0.6
## Velocidade do pisca do aviso.
const WARNING_PULSE_SPEED: float = 14.0
## Brilho do núcleo em relação à largura.
const CORE_WIDTH_FACTOR: float = 0.4

var _phase: Phase = Phase.WARNING  # Fase atual.
var _direction: Vector2 = Vector2.RIGHT  # Direção da varredura.
var _speed: float = 520.0  # Velocidade da varredura.
var _length: float = 0.0  # Comprimento do raio.
var _thickness: float = 10.0  # Espessura do raio.
var _wait_left: float = 0.0  # Tempo de aviso restante.
var _travel_left: float = 0.0  # Distância que ainda falta percorrer.
var _damage: int = 0  # Dano.
var _elapsed: float = 0.0  # Tempo desde o lançamento.


## Prepara o raio: avisa na borda de saída, espera `wait_time` e varre `travel_distance` px.
func launch(start: Vector2, direction: Vector2, length: float, thickness: float, speed: float,
		travel_distance: float, wait_time: float, damage: int, from_source: Node) -> void:
	global_position = start  # Posição inicial.
	source = from_source  # Quem lançou.
	# Direção normalizada (zero vira direita).
	_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	# O eixo local Y é o comprimento do raio: ele fica perpendicular ao sentido da varredura.
	global_rotation = _direction.angle()  # Gira o raio para ficar perpendicular à varredura.
	_length = maxf(length, thickness)  # Comprimento mínimo.
	_thickness = maxf(thickness, 1.0)  # Espessura mínima.
	_speed = maxf(speed, 1.0)  # Velocidade mínima.
	_travel_left = maxf(travel_distance, 0.0)  # Distância restante.
	_wait_left = maxf(wait_time, 0.0)  # Tempo de aviso.
	_damage = damage  # Guarda o dano.
	_phase = Phase.WARNING  # Começa avisando.
	_elapsed = 0.0  # Zera o tempo.
	var capsule := hit_shape.shape as CapsuleShape2D  # Forma de cápsula.
	if capsule != null:  # Ajusta a cápsula ao raio.
		capsule.radius = _thickness * 0.5  # Raio da cápsula.
		capsule.height = _length  # Comprimento da cápsula.
	queue_redraw()  # Redesenha.


## A cada quadro: no aviso conta o tempo e liga o dano; na varredura anda até o fim e volta ao pool.
func _physics_process(delta: float) -> void:
	_elapsed += delta  # Soma o tempo.
	match _phase:
		Phase.WARNING:  # Fase de aviso.
			_wait_left -= delta  # Desconta o aviso.
			if _wait_left <= 0.0:  # Acabou o aviso: começa a varredura.
				_phase = Phase.SWEEP  # Entra na varredura.
				arm(_damage)  # Liga a hitbox.
			queue_redraw()  # Redesenha o pisca.
		Phase.SWEEP:  # Fase de varredura.
			var step: float = minf(_speed * delta, _travel_left)  # Passo do quadro (o último é encurtado).
			global_position += _direction * step  # Anda na direção da varredura.
			_travel_left -= step  # Desconta a distância.
			if _travel_left <= 0.0:  # Percorreu tudo: volta ao pool.
				recycle()


## Desenha o aviso piscando (fino) ou o raio sólido com pontas redondas e núcleo claro.
func _draw() -> void:
	var half: float = _length * 0.5  # Metade do comprimento.
	var from := Vector2(0.0, -half)  # Ponta de cima.
	var to := Vector2(0.0, half)  # Ponta de baixo.
	if _phase == Phase.WARNING:  # Fase de aviso.
		var pulse: float = 0.5 + 0.5 * sin(_elapsed * WARNING_PULSE_SPEED)  # Valor do pisca (0 a 1).
		var color := COLOR_WARNING  # Cor do aviso.
		color.a *= 0.5 + 0.5 * pulse  # Pisca a transparência.
		draw_line(from, to, color, _thickness * WARNING_WIDTH_FACTOR)  # Linha fina de aviso.
		return  # Termina o desenho do aviso.
	draw_line(from, to, COLOR_SWEEP, _thickness)  # Corpo do raio.
	draw_circle(from, _thickness * 0.5, COLOR_SWEEP)  # Ponta de cima arredondada.
	draw_circle(to, _thickness * 0.5, COLOR_SWEEP)  # Ponta de baixo arredondada.
	draw_line(from, to, COLOR_CORE, _thickness * CORE_WIDTH_FACTOR)  # Núcleo brilhante.
