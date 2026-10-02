class_name ShooterState
extends BaseState
## Base dos estados do Shooter (expõe o Shooter tipado).

var enemy: RangedEnemy = null


## Guarda o Shooter tipado.
func _on_setup() -> void:
	enemy = actor as RangedEnemy
	if enemy == null:
		push_error("%s: a ShooterStateMachine precisa ser filha de um RangedEnemy." % name)
