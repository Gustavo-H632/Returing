class_name TankState
extends BaseState
## Base dos estados do Tank (expõe o Tank tipado).

var tank: TankEnemy = null


## Guarda o Tank tipado.
func _on_setup() -> void:
	tank = actor as TankEnemy
	if tank == null:
		push_error("%s: a TankStateMachine precisa ser filha de um TankEnemy." % name)
