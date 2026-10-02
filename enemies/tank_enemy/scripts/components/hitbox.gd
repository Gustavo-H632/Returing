class_name TankHitbox
extends Hitbox
## Hitbox do Tank (pisoteio e investida). Começa desligada.


## Começa desligada.
func _init() -> void:
	active_on_start = false


## Atalho: dano em tudo que está sobreposto.
func deal_pulse_damage() -> void:
	pulse()
