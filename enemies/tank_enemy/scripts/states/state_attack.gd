extends TankState
## ATTACK: pisoteio em área a cada `stomp_pulse_interval` enquanto o player estiver perto.

## Margem para não alternar Chase/Attack na borda
const RANGE_HYSTERESIS: float = 1.1


## Para e liga a hitbox do pisoteio.
func enter() -> void:
	tank.velocity = Vector2.ZERO
	if tank.stomp_hitbox != null:
		tank.stomp_hitbox.damage = tank.stomp_damage
		# Sem contato: o dano vem dos pulsos
		tank.stomp_hitbox.damage_on_contact = false
		tank.stomp_hitbox.set_active(true)


## Desliga a hitbox.
func exit() -> void:
	if tank.stomp_hitbox != null:
		tank.stomp_hitbox.set_active(false)


## Sai se o player foge; senão pulsa o pisoteio.
func physics_update(delta: float) -> void:
	tank.brake(delta)
	tank.move_and_slide()

	if not tank.has_target():
		request_transition(&"idle")
		return

	var leave_radius := tank.attack_range_radius * RANGE_HYSTERESIS
	if tank.distance_sq_to_player() > leave_radius * leave_radius:
		request_transition(&"chase")
		return

	# Pulso com a recarga pronta; o acerto reinicia a recarga
	var hitbox := tank.stomp_hitbox
	if hitbox != null and tank.can_stomp() and hitbox.monitoring:
		hitbox.pulse()
