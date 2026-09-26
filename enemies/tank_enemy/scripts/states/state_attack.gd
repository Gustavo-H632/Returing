extends TankState

## Estado ATTACK investida

var _tank: TankEnemy
var _first_pulse: bool = false


func enter() -> void:
	_tank = actor as TankEnemy
	_tank.velocity = Vector2.ZERO

	_tank.stomp_hitbox.damage = _tank.stomp_damage
	_tank.stomp_hitbox.set_active(true)

	if not _tank.attack_pulse_timer.timeout.is_connected(_on_pulse_timeout):
		_tank.attack_pulse_timer.timeout.connect(_on_pulse_timeout)

	_first_pulse = true
	_tank.attack_pulse_timer.start(0.05)


func exit() -> void:
	_tank.stomp_hitbox.set_active(false)
	_tank.attack_pulse_timer.stop()
	_first_pulse = false


func physics_update(delta: float) -> void:

	_tank.velocity = _tank.velocity.move_toward(Vector2.ZERO, _tank.move_speed * delta)
	_tank.move_and_slide()

	if not _tank.player:
		state_machine.transition_to("idle")
		return

	#Volta para o chase automaticamente
	var distance := _tank.global_position.distance_to(_tank.player.global_position)
	if distance > _tank.attack_range_radius * 1.1:
		state_machine.transition_to("chase")


func _on_pulse_timeout() -> void:
	_tank.stomp_hitbox.deal_pulse_damage()

	if _first_pulse:
		_first_pulse = false
		_tank.attack_pulse_timer.start(_tank.stomp_pulse_interval)
