class_name PlayerHurtbox
extends Area2D

func _ready() -> void:
	add_to_group("hurtbox")


## Chamado pelas Hitboxes dos inimigos. 
func take_damage(amount: int, _source = null) -> void:
	var player := get_parent()
	if player != null and player.has_method("tomar_dano"):
		player.tomar_dano(amount)
