class_name GuideState
extends EnemyState
## Base dos estados do Guide (expõe o GuideEnemy tipado).

var guide: GuideEnemy = null


func _on_enemy_setup() -> void:
	guide = enemy as GuideEnemy
	if guide == null:
		push_error("%s: a máquina precisa ser filha de um GuideEnemy." % name)
