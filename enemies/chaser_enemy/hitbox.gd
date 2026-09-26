class_name ChaserHitbox
extends Area2D
#hitbox

@export var damage: int = 10

func _ready() -> void:
	add_to_group("hitbox")
	monitorable = false

func get_damage() -> int:
	return damage

## Torna este hitbox detectável por Hurtboxes.
func activate() -> void:
	set_deferred("monitorable", true)

## Esconde este hitbox de novo
func deactivate() -> void:
	set_deferred("monitorable", false)
