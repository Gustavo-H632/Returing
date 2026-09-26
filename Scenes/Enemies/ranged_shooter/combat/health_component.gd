class_name ShooterHealthComponent
extends Node
# Hp do inimigo shooter

signal health_changed(current: int, max: int)
signal died

@export var max_health: int = 120

var current_health: int


func _ready() -> void:
	current_health = max_health


func apply_damage(amount: int, _source: Node = null) -> void:
	if current_health <= 0:
		return

	current_health = max(current_health - amount, 0)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		died.emit()


func heal(amount: int) -> void:
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)
