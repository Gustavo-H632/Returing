class_name WarningCircle
extends GuideAttack
## Círculo de aviso no chão: vermelho enquanto carrega e amarelo (com dano) quando dispara.

enum Phase { WARNING, ACTIVE }

## Cor do aviso (vermelho).
const COLOR_WARNING: Color = Color(1.0, 0.15, 0.15, 0.35)
## Cor do preenchimento que mostra quanto falta para disparar.
const COLOR_FILL: Color = Color(1.0, 0.15, 0.15, 0.35)
## Cor do círculo que causa dano (amarelo).
const COLOR_ACTIVE: Color = Color(1.0, 0.9, 0.15, 0.6)
## Cor do contorno.
const COLOR_OUTLINE: Color = Color(0.1, 0.0, 0.0, 0.8)
const OUTLINE_WIDTH: float = 2.0
const ARC_POINTS: int = 48

var _radius: float = 56.0
var _phase: Phase = Phase.WARNING
var _warning_time: float = 2.0
var _active_time: float = 0.3
var _time_left: float = 0.0
var _damage: int = 0


## Posiciona o círculo e começa a contagem do aviso.
func launch(center: Vector2, radius: float, warning_time: float, active_time: float, damage: int,
		from_source: Node) -> void:
	global_position = center
	source = from_source
	_radius = maxf(radius, 1.0)
	_warning_time = maxf(warning_time, 0.01)
	_active_time = maxf(active_time, 0.01)
	_damage = damage
	_phase = Phase.WARNING
	_time_left = _warning_time
	set_hit_radius(_radius)
	queue_redraw()


## Conta o aviso, liga o dano e devolve o círculo ao pool.
func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left > 0.0:
		if _phase == Phase.WARNING:
			queue_redraw()  # o preenchimento cresce com o tempo
		return
	match _phase:
		Phase.WARNING:
			_phase = Phase.ACTIVE
			_time_left = _active_time
			arm(_damage)
			queue_redraw()
		Phase.ACTIVE:
			recycle()


## Vermelho com preenchimento crescente; amarelo no disparo.
func _draw() -> void:
	if _phase == Phase.ACTIVE:
		draw_circle(Vector2.ZERO, _radius, COLOR_ACTIVE)
	else:
		draw_circle(Vector2.ZERO, _radius, COLOR_WARNING)
		var progress: float = clampf(1.0 - _time_left / _warning_time, 0.0, 1.0)
		draw_circle(Vector2.ZERO, _radius * progress, COLOR_FILL)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, ARC_POINTS, COLOR_OUTLINE, OUTLINE_WIDTH)
