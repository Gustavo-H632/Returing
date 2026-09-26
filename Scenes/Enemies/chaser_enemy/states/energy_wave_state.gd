class_name ChaserEnergyWaveState
extends ChaserState

#State de ataque player saiu da area de visao

@export var recovery_time: float = 0.4


func enter() -> void:
	actor.velocity = Vector2.ZERO
	actor.player_ref = null
	actor.fire_energy_wave()
	_recover()


func physics_update(_delta: float) -> void:
	actor.velocity = Vector2.ZERO
	actor.move_and_slide()


func _recover() -> void:
	if not is_instance_valid(actor):
		return
	await actor.get_tree().create_timer(recovery_time).timeout
	if not is_instance_valid(actor) or actor.state_machine.current_state != self:
		return
	transitioned.emit(self, "IdleState")
