class_name ShooterHurtbox
extends Area2D
#hurtbox

signal damage_received(amount: int, source: Node)


func _ready() -> void:
	add_to_group("hurtbox")
	#detectar hurtbox
	monitoring = false
	monitorable = true


#colisão de hitbox com hurtbox
func take_damage(amount: int, source: Node = null) -> void:
	damage_received.emit(amount, source)
