class_name TankHealthComponent
extends HealthComponent
## Vida do Tank (lógica em HealthComponent).


## Valor padrão do Tank.
func _init() -> void:
	max_health = 500  # padrão; o TankEnemy usa o próprio max_health
