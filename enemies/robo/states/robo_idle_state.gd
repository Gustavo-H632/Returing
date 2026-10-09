class_name RoboIdleState
extends RoboState
## Parado até ganhar aggro.


func _on_enter() -> void:
	robo.velocity = Vector2.ZERO


func physics_update(_delta: float) -> void:
	robo.stop_moving()
	if robo.has_target():
		request_transition(&"Chase")
