class_name RoboState
extends EnemyState
## Base dos estados do Robo (expõe o RoboEnemy tipado).

var robo: RoboEnemy = null


func _on_enemy_setup() -> void:
	robo = enemy as RoboEnemy
	if robo == null:
		push_error("%s: a máquina precisa ser filha de um RoboEnemy." % name)
