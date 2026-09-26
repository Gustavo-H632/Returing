class_name ShooterHitbox
extends Area2D
#Hit box shooter
@export var damage: int = 10
@export var one_shot: bool = true
@export var tick_interval: float = 0.5

@export var start_active: bool = true

signal hit_landed(target: Node, damage_dealt: int)

var _active: bool = true
var _already_hit: Array[Node] = []
var _bodies_inside: Array[Node] = []
@onready var _tick_timer: Timer = Timer.new()


func _ready() -> void:
	add_to_group("hitbox")
	_active = start_active

	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	add_child(_tick_timer)
	_tick_timer.wait_time = tick_interval
	_tick_timer.timeout.connect(_on_tick_timeout)
	_tick_timer.start()


func _on_area_entered(area: Area2D) -> void:
	if area not in _bodies_inside:
		_bodies_inside.append(area)

	if not _active or not area.is_in_group("hurtbox"):
		return

	_apply_damage(area)


func _on_area_exited(area: Area2D) -> void:
	_bodies_inside.erase(area)
	_already_hit.erase(area)  # Permite ser atingido de novo


func _on_tick_timeout() -> void:
	if not _active or one_shot:
		return

	for area in _bodies_inside:
		if is_instance_valid(area) and area.is_in_group("hurtbox"):
			_apply_damage(area)


func _apply_damage(area: Area2D) -> void:
	if one_shot:
		if area in _already_hit:
			return
		_already_hit.append(area)

	if area.has_method("take_damage"):
		area.take_damage(damage, self)
		hit_landed.emit(area, damage)


## Aplica dano imediatamente a tudo 
func apply_burst_damage() -> void:
	for area in get_overlapping_areas():
		if area.is_in_group("hurtbox"):
			_apply_damage(area)


func set_active(is_active: bool) -> void:
	_active = is_active


func configure(new_damage: int, new_one_shot: bool, new_tick_interval: float = 0.5) -> void:
	damage = new_damage
	one_shot = new_one_shot
	tick_interval = new_tick_interval
	_tick_timer.wait_time = tick_interval
