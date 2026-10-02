class_name ShooterIdleState
extends ShooterState
## Parado até ganhar aggro.


## Para.
func enter() -> void:
	enemy.velocity = Vector2.ZERO


## Começa a perseguir com aggro.
func physics_update(_delta: float) -> void:
	enemy.stop_moving()
	if enemy.has_aggro and enemy.has_target():
		request_transition(&"Chase")
