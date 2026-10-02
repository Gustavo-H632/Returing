class_name HealthComponent
extends Node
## Vida reutilizável 

signal health_changed(current_health: int, max_health: int)
signal damaged(amount: int)
signal healed(amount: int)
signal died

@export var max_health: int = 100

var current_health: int = 0
var _initialized: bool = false


## Inicia a vida se ninguém chamou setup().
func _ready() -> void:
	if not _initialized:
		setup(max_health)


## Define a vida máxima.
func setup(new_max_health: int, refill: bool = true) -> void:
	max_health = maxi(new_max_health, 1)
	current_health = max_health if refill else clampi(current_health, 0, max_health)
	_initialized = true
	health_changed.emit(current_health, max_health)


## Retorna o dano aplicado.
func take_damage(amount: int, _source: Variant = null) -> int:
	if not _initialized:
		setup(max_health)
	if is_dead() or amount <= 0:
		return 0
	var applied := mini(amount, current_health)
	current_health -= applied
	damaged.emit(applied)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		died.emit()
	return applied

## Mesmo que take_damage.
func apply_damage(amount: int, source: Variant = null) -> int:
	return take_damage(amount, source)


## Retorna o quanto foi curado 
func heal(amount: int) -> int:
	if is_dead() or amount <= 0 or current_health >= max_health:
		return 0
	var before := current_health
	current_health = mini(current_health + amount, max_health)
	var applied := current_health - before
	healed.emit(applied)
	health_changed.emit(current_health, max_health)
	return applied


## true com vida zerada.
func is_dead() -> bool:
	return _initialized and current_health <= 0


## Vida de 0 a 1.
func get_ratio() -> float:
	return float(current_health) / float(maxi(max_health, 1))
