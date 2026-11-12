class_name TankState
extends EnemyState
## Base dos estados do Tank (expõe o TankEnemy tipado).

var tank: TankEnemy = null  # Tank dono do estado (já convertido).


## Converte o inimigo para TankEnemy.
func _on_enemy_setup() -> void:
	tank = enemy as TankEnemy  # Cast para o tipo concreto.
	if tank == null:  # Sem TankEnemy não funciona.
		push_error("%s: a máquina precisa ser filha de um TankEnemy." % name)  # Avisa o erro.
