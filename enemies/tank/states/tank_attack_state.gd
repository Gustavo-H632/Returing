class_name TankAttackState
extends TankState
## Pisoteio: prepara (windup) e então pulsa dano em área a cada stomp_pulse_interval.

## Margem para não alternar Chase/Attack na borda do raio.
const RANGE_HYSTERESIS: float = 1.1

var _windup_left: float = 0.0


func _on_enter() -> void:
	tank.velocity = Vector2.ZERO
	_windup_left = tank.stomp_windup_time
	if tank.stomp_hitbox != null:
		tank.stomp_hitbox.set_active(true)  # ligada, mas só causa dano via pulse()


func exit() -> void:
	if tank.stomp_hitbox != null:
		tank.stomp_hitbox.set_active(false)


func physics_update(delta: float) -> void:
	tank.brake(delta)
	if not tank.has_target():
		request_transition(&"Idle")
		return
	var leave_radius: float = tank.stomp_radius * RANGE_HYSTERESIS
	if tank.distance_sq_to_target() > leave_radius * leave_radius:
		request_transition(&"Chase")
		return
	tank.face_target()
	_windup_left -= delta
	if _windup_left > 0.0:
		return
	var hitbox: Hitbox = tank.stomp_hitbox
	if hitbox != null and tank.can_stomp() and hitbox.monitoring:
		tank.play_anim(animation, true)
		hitbox.pulse()
		tank.start_stomp_cooldown()
