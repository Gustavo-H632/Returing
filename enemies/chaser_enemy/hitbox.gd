class_name ChaserHitbox
extends Hitbox
## Hitbox do golpe do Chaser. Começa desligada.


## Começa desligada.
func _init() -> void:
	# O Inspector ainda tem prioridade
	active_on_start = false
