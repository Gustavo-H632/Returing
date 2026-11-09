class_name DroneState
extends EnemyState
## Base dos estados do Drone (expõe o DroneEnemy tipado).

var drone: DroneEnemy = null  # Drone dono do estado (já convertido).


## Converte o inimigo para DroneEnemy.
func _on_enemy_setup() -> void:
	drone = enemy as DroneEnemy  # Cast para o tipo concreto.
	if drone == null:  # Sem DroneEnemy não funciona.
		push_error("%s: a máquina precisa ser filha de um DroneEnemy." % name)  # Avisa o erro.
