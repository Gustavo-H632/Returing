class_name Hitbox
extends Area2D
## Área que CAUSA dano.
##Hitbox monitora e a Hurtbox é apenas monitorável. 

signal hit_landed(target: Node, damage_dealt: int)

@export var damage: int = 10
@export var active_on_start: bool = true
## Causa dano assim que uma Hurtbox entra na área.
@export var damage_on_contact: bool = true
## Impede que o mesmo alvo seja atingido mais de uma vez
@export var one_hit_per_target: bool = true
## > 0 ativa dano contínuo: cada alvo recebe dano a cada `tick_interval` 
@export_range(0.0, 10.0, 0.05, "or_greater") var tick_interval: float = 0.0
## Ignora Hurtboxes que pertencem ao mesmo ator .
@export var ignore_same_actor: bool = true
## Mostra a origem do dano e ignora a mesma entidade.
@export var source: Node = null

var _active: bool = false
var _already_hit: Array[Area2D] = []
var _tick_cooldowns: Dictionary = {}  # Area2D 


## Grupo hitbox, nunca monitorável, liga os sinais.
func _ready() -> void:
	add_to_group(CombatUtils.GROUP_HITBOX)
	monitorable = false
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	if source == null:
		source = CombatUtils.get_actor(self)
	set_active(active_on_start)


## Dano contínuo por alvo.
func _physics_process(delta: float) -> void:
	if not _active or tick_interval <= 0.0 or _tick_cooldowns.is_empty():
		set_physics_process(false)
		return

	for area: Variant in _tick_cooldowns.keys():
		if not CombatUtils.is_alive(area):
			_tick_cooldowns.erase(area)
			continue
		var remaining: float = _tick_cooldowns[area] - delta
		if remaining <= 0.0:
			var target: Area2D = area
			_try_hit(target, true)
		
			if not _active:
				return
			remaining += tick_interval
		_tick_cooldowns[area] = remaining

## true se ligada.
func is_active() -> bool:
	return _active


## Liga e desliga a hitbox
func set_active(value: bool) -> void:
	_active = value
	if value:
		_already_hit.clear()
	else:
		_tick_cooldowns.clear()
	set_deferred(&"monitoring", value)
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred(&"disabled", not value)
	set_physics_process(value and tick_interval > 0.0)


## Liga.
func activate() -> void:
	set_active(true)


## Desliga.
func deactivate() -> void:
	set_active(false)


## Dano atual.
func get_damage() -> int:
	return damage


## Aplica dano imediatamente a tudo que está sobreposto.
func pulse(reset_hit_list: bool = true) -> void:
	
	if not _active or not monitoring:
		return
	if reset_hit_list:
		_already_hit.clear()
	for area in get_overlapping_areas():
		_try_hit(area, false)

## Hurtbox entrou.
func _on_area_entered(area: Area2D) -> void:
	if not _active or not _is_valid_target(area):
		return
	if tick_interval > 0.0:
		if damage_on_contact:
			_try_hit(area, true)
		_tick_cooldowns[area] = tick_interval
		set_physics_process(true)
	elif damage_on_contact:
		_try_hit(area, false)


## Hurtbox saiu.
func _on_area_exited(area: Area2D) -> void:
	_tick_cooldowns.erase(area)


## Só hurtboxes de outro ator.
func _is_valid_target(area: Area2D) -> bool:
	if not CombatUtils.is_alive(area) or not area.is_in_group(CombatUtils.GROUP_HURTBOX):
		return false
	if ignore_same_actor and source != null and CombatUtils.get_actor(area) == source:
		return false
	return true


## Aplica o dano. true se o alvo aceitou.
func _try_hit(area: Area2D, is_tick: bool) -> bool:
	if not _active or not _is_valid_target(area):
		return false
	if not is_tick and one_hit_per_target and area in _already_hit:
		return false
	if not CombatUtils.apply_damage(area, damage, source):
		return false
	if not is_tick:
		_already_hit.append(area)
	hit_landed.emit(area, damage)
	return true
