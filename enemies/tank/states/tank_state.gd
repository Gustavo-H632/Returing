class_name TankState
extends EnemyState
## Base dos estados do Tank (expõe o TankEnemy tipado).

var tank: TankEnemy = null


func _on_enemy_setup() -> void:
	tank = enemy as TankEnemy
	if tank == null:
		push_error("%s: a máquina precisa ser filha de um TankEnemy." % name)
