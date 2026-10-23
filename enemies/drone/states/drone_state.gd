class_name DroneState
extends EnemyState
## Base dos estados do Drone (expõe o DroneEnemy tipado).

var drone: DroneEnemy = null


func _on_enemy_setup() -> void:
	drone = enemy as DroneEnemy
	if drone == null:
		push_error("%s: a máquina precisa ser filha de um DroneEnemy." % name)
