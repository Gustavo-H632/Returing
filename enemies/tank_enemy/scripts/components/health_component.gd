class_name TankHealthComponent
extends Node

#Vida do Tank

@export var max_health: int = 500

var current_health: int

signal health_changed(current: int, max: int)
signal damaged(amount: int)
signal died


func _ready() -> void:
	current_health = max_health


func take_damage(amount: int) -> void:
	if current_health <= 0 or amount <= 0:
		return

	current_health = max(current_health - amount, 0)
	damaged.emit(amount)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		died.emit()


func heal(amount: int) -> void:
	if current_health <= 0:
		return # já está morto, não devolve à vida sozinho

	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


func is_dead() -> bool:
	return current_health <= 0
