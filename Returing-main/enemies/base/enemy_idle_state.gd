class_name EnemyIdleState
extends EnemyState
## Sentinela: o inimigo freia e espera parado até enxergar o player.

## Segundos parado antes de voltar a patrulhar (só vale se houver nó Patrol).
@export_range(0.0, 10.0, 0.1, "or_greater") var patrol_delay: float = 0.6

var _patrol_left: float = 0.0


func _on_enter() -> void:
	enemy.velocity = Vector2.ZERO
	_patrol_left = patrol_delay


func physics_update(delta: float) -> void:
	enemy.brake(delta)
	if enemy.has_target():
		request_transition(&"Chase")
		return
	if not state_machine.has_state(&"Patrol"):
		return
	_patrol_left -= delta
	if _patrol_left <= 0.0:
		request_transition(&"Patrol")
