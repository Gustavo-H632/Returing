class_name EnemyDeadState
extends EnemyState
## Estado final do StateWarden (canônico DEAD): o inimigo para de se mover.


func _on_enter() -> void:
	enemy.velocity = Vector2.ZERO
