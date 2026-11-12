class_name GuideState
extends EnemyState
## Base dos estados do Guide (expõe o GuideEnemy tipado).

var guide: GuideEnemy = null  # Chefão dono do estado (já convertido).


## Converte o inimigo para GuideEnemy.
func _on_enemy_setup() -> void:
	guide = enemy as GuideEnemy  # Cast para o tipo concreto.
	if guide == null:  # Sem GuideEnemy não funciona.
		push_error("%s: a máquina precisa ser filha de um GuideEnemy." % name)  # Avisa o erro.
