class_name GuideSlash
extends GuideAttack
## Golpe de espada em área ao redor do Guide: avisa, corta uma vez e some.

enum Phase { WINDUP, ACTIVE }

const COLOR_WINDUP: Color = Color(1.0, 0.15, 0.15, 0.3)
const COLOR_FILL: Color = Color(1.0, 0.15, 0.15, 0.3)
const COLOR_ACTIVE: Color = Color(0.9, 0.95, 1.0, 0.7)
const COLOR_OUTLINE: Color = Color(0.1, 0.0, 0.0, 0.8)
const OUTLINE_WIDTH: float = 3.0
const ARC_POINTS: int = 64
## Riscos radiais desenhados no golpe (efeito de lâminas).
const BLADE_COUNT: int = 8
const BLADE_WIDTH: float = 3.0

var _radius: float = 84.0
var _phase: Phase = Phase.WINDUP
var _windup_time: float = 0.6
var _active_time: float = 0.15
var _time_left: float = 0.0
var _damage: int = 0
## Nó que o círculo acompanha durante o aviso (o corpo do chefão).
var _anchor: Node2D = null


## Prepara o golpe: o círculo acompanha `anchor` até o impacto.
func launch(anchor: Node2D, radius: float, windup_time: float, active_time: float, damage: int,
		from_source: Node) -> void:
	_anchor = anchor
	global_position = anchor.global_position
	source = from_source
	_radius = maxf(radius, 1.0)
	_windup_time = maxf(windup_time, 0.01)
	_active_time = maxf(active_time, 0.01)
	_damage = damage
	_phase = Phase.WINDUP
	_time_left = _windup_time
	set_hit_radius(_radius)
	queue_redraw()


## Duração total do golpe (aviso + janela de dano).
func get_total_time() -> float:
	return _windup_time + _active_time


func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _phase == Phase.WINDUP and CombatUtils.is_alive(_anchor):
		global_position = _anchor.global_position
	if _time_left > 0.0:
		if _phase == Phase.WINDUP:
			queue_redraw()
		return
	match _phase:
		Phase.WINDUP:
			_phase = Phase.ACTIVE
			_time_left = _active_time
			arm(_damage)
			queue_redraw()
		Phase.ACTIVE:
			recycle()


func _draw() -> void:
	if _phase == Phase.ACTIVE:
		draw_circle(Vector2.ZERO, _radius, COLOR_ACTIVE)
		for i: int in BLADE_COUNT:
			draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(TAU * float(i) / float(BLADE_COUNT)) * _radius,
					COLOR_OUTLINE, BLADE_WIDTH)
	else:
		draw_circle(Vector2.ZERO, _radius, COLOR_WINDUP)
		var progress: float = clampf(1.0 - _time_left / _windup_time, 0.0, 1.0)
		draw_circle(Vector2.ZERO, _radius * progress, COLOR_FILL)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, ARC_POINTS, COLOR_OUTLINE, OUTLINE_WIDTH)
