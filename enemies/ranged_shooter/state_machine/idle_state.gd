class_name ShooterIdleState
extends ShooterState
#State Idle

func enter() -> void:
	enemy.velocity = Vector2.ZERO


func physics_update(_delta: float) -> void:
	enemy.move_and_slide()

	if enemy.has_aggro:
		transition_requested.emit("Chase")
