class_name TankHitbox
extends Area2D

## TankHitbox:

@export var damage: int = 10

## Evita que o mesmo alvo tome diversos hits em um so contato
@export var one_shot_per_activation: bool = true

## Se verdadeira  causa dano ao tocar na hurtbox
@export var deal_damage_on_contact: bool = true

var _already_hit: Array[Area2D] = []


func _ready() -> void:
	if deal_damage_on_contact:
		area_entered.connect(_on_area_entered)
	set_active(false) # hitboxes começam desligadas 


func set_active(value: bool) -> void:

	set_deferred("monitoring", value)
	set_deferred("monitorable", value)
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", not value)
	if value:
		_already_hit.clear()

func deal_pulse_damage() -> void:
	_already_hit.clear()
	for area in get_overlapping_areas():
		_try_damage(area)


func _on_area_entered(area: Area2D) -> void:
	_try_damage(area)


func _try_damage(area: Area2D) -> void:
	if not (area.is_in_group("hurtbox") and area.has_method("take_damage")):
		return
	if one_shot_per_activation and area in _already_hit:
		return

	area.take_damage(damage, global_position)
	_already_hit.append(area)
