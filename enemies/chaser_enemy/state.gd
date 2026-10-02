class_name ChaserState
extends BaseState
## Base dos estados do Chaser (expõe o Chaser tipado).

var enemy: ChaserEnemy = null


## Guarda o Chaser tipado.
func _on_setup() -> void:
	enemy = actor as ChaserEnemy
	if enemy == null:
		push_error("%s: a ChaserStateMachine precisa ser filha de um ChaserEnemy." % name)
