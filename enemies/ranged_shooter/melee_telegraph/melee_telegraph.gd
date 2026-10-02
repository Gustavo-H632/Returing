class_name MeleeTelegraph
extends Node2D
## Aviso de ataque em área: depois de `charge_time` acerta quem está no círculo e some.

enum Phase { CHARGING, IMPACT }

@export var radius: float = 80.0
@export var warning_color: Color = Color(1.0, 0.2, 0.2, 0.35)
@export var impact_color: Color = Color(1.0, 1.0, 0.6, 0.6)
@export var impact_duration: float = 0.15
@export var pulse_amount: float = 0.06

## ShooterHitbox filha e a forma dela
@export var hitbox: ShooterHitbox
@export var hitbox_shape: CollisionShape2D

var _charge_time: float = 1.0
var _damage: int = 25
var _phase: Phase = Phase.CHARGING
var _time_left: float = 1.0
var _visual_scale: float = 1.0


## Raio próprio e hitbox desligada.
func _ready() -> void:
	if hitbox == null:
		push_error("MeleeTelegraph: 'hitbox' não foi atribuído no Inspector.")
		set_process(false)
		queue_free()
		return
	CombatUtils.set_unique_circle_radius(hitbox_shape, radius)
	hitbox.configure(_damage, true)
	hitbox.damage_on_contact = true
	hitbox.set_active(false)  # só avisa
	_time_left = _charge_time
	queue_redraw()


## Tempo de carga e dano (chamado pelo AttackMelee).
func setup(charge_time: float, damage: int) -> void:
	_charge_time = maxf(charge_time, 0.0)
	_damage = damage
	_time_left = _charge_time
	if hitbox != null:
		hitbox.configure(_damage, true)


## Carga com pulso visual e depois o impacto.
func _process(delta: float) -> void:
	_time_left -= delta
	match _phase:
		Phase.CHARGING:
			# Pulso só no desenho
			_visual_scale = 1.0 + sin(Time.get_ticks_msec() / 100.0) * pulse_amount
			queue_redraw()
			if _time_left <= 0.0:
				_impact()
		Phase.IMPACT:
			if _time_left <= 0.0:
				# Garante o dano em quem ficou dentro
				hitbox.pulse(false)
				set_process(false)
				queue_free()


## Desenha o círculo.
func _draw() -> void:
	var color := warning_color if _phase == Phase.CHARGING else impact_color
	draw_circle(Vector2.ZERO, radius * _visual_scale, color)


## Liga a hitbox no impacto.
func _impact() -> void:
	_phase = Phase.IMPACT
	_time_left = impact_duration
	_visual_scale = 1.0
	# Liga a hitbox: acerta quem está dentro
	hitbox.set_active(true)
	queue_redraw()
