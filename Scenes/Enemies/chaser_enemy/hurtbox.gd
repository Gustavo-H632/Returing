class_name ChaserHurtbox
extends Area2D

#hurtbox
signal damaged(amount: int)

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("hitbox") and area.has_method("get_damage"):
		damaged.emit(area.get_damage())
