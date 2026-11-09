class_name RoboState
extends EnemyState
## Base dos estados do Robo (expõe o RoboEnemy tipado).

var robo: RoboEnemy = null  # Robô dono do estado (já convertido).


## Converte o inimigo para RoboEnemy.
func _on_enemy_setup() -> void:
	robo = enemy as RoboEnemy  # Cast para o tipo concreto.
	if robo == null:  # Sem RoboEnemy não funciona.
		push_error("%s: a máquina precisa ser filha de um RoboEnemy." % name)  # Avisa o erro.
