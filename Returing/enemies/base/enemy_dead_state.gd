class_name EnemyDeadState
extends EnemyState
## Estado final do StateWarden (canônico DEAD): o inimigo para de se mover.


## Ao entrar no estado de morte o inimigo para de se mover (a máquina fica travada pelo StateWarden).
func _on_enter() -> void:
	enemy.velocity = Vector2.ZERO  # Zera a velocidade.
