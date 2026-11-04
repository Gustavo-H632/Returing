class_name Hitbox
extends Area2D
## Área que CAUSA dano.

signal hit_landed(target: Area2D, damage_dealt: int)

@export var damage: int = 10
@export var active_on_start: bool = true
## Causa dano assim que uma Hurtbox entra na área.
@export var damage_on_contact: bool = true
## Impede que o mesmo alvo seja atingido mais de uma vez por ativação.
@export var one_hit_per_target: bool = true
## > 0 ativa dano contínuo.
@export_range(0.0, 10.0, 0.05, "or_greater") var tick_interval: float = 0.0
## Ignora Hurtboxes que pertencem ao mesmo ator.
@export var ignore_same_actor: bool = true
## Origem do dano (quem ataca).
@export var source: Node = null

var _active: bool = false
## Alvos já atingidos nesta ativação.
var _already_hit: Dictionary[int, bool] = {}
var _tick_cooldowns: Dictionary[Area2D, float] = {}  # Area2D -> segundos até o próximo tick
## Alvos cujo cooldown venceu neste frame.
var _expired: Array[Area2D] = []
## pulse() pedido antes de `monitoring` entrar em vigor.
var _pending_pulse: bool = false
var _pending_pulse_reset: bool = false


func _ready() -> void:
	add_to_group(CombatUtils.GROUP_HITBOX)
	monitorable = false
	CombatUtils.connect_once(area_entered, _on_area_entered)
	CombatUtils.connect_once(area_exited, _on_area_exited)
	if source == null:
		source = CombatUtils.get_actor(self)
	set_active(active_on_start)


## Dano contínuo por alvo e pulsos adiados.
func _physics_process(delta: float) -> void:
	if _pending_pulse:
		_flush_pending_pulse()
	if not _active or tick_interval <= 0.0 or _tick_cooldowns.is_empty():
		_update_physics_process()
		return
	_advance_tick_cooldowns(delta)


func is_active() -> bool:
	return _active


## Liga/desliga a hitbox.
func set_active(value: bool) -> void:
	_active = value
	if value:
		_already_hit.clear()
	else:
		_tick_cooldowns.clear()
		_pending_pulse = false
	set_deferred(&"monitoring", value)
	for child: Node in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred(&"disabled", not value)
	_update_physics_process()


func activate() -> void:
	set_active(true)


func deactivate() -> void:
	set_active(false)


## One_shot true = um acerto por alvo; false = dano a cada tick.
func configure(new_damage: int, new_one_shot: bool, new_tick_interval: float = 0.5) -> void:
	damage = new_damage
	one_hit_per_target = new_one_shot
	tick_interval = 0.0 if new_one_shot else maxf(new_tick_interval, 0.05)
	if is_node_ready():
		_update_physics_process()


## Aplica dano imediatamente a tudo que está sobreposto.
func pulse(reset_hit_list: bool = true) -> void:
	if not _active:
		return
	if not monitoring:
		_pending_pulse = true
		_pending_pulse_reset = reset_hit_list
		_update_physics_process()
		return
	_do_pulse(reset_hit_list)


func _do_pulse(reset_hit_list: bool) -> void:
	if reset_hit_list:
		_already_hit.clear()
	for area: Area2D in get_overlapping_areas():
		_try_hit(area, false)


func _flush_pending_pulse() -> void:
	_pending_pulse = false
	if _active and monitoring:
		_do_pulse(_pending_pulse_reset)


## Desconta o tempo de cada alvo dentro da área e aplica o dano dos que venceram.
func _advance_tick_cooldowns(delta: float) -> void:
	_expired.clear()
	for area: Area2D in _tick_cooldowns:
		if not CombatUtils.is_alive(area):
			_expired.append(area)
			continue
		var remaining: float = _tick_cooldowns[area] - delta
		_tick_cooldowns[area] = remaining
		if remaining <= 0.0:
			_expired.append(area)

	for area: Area2D in _expired:
		if not CombatUtils.is_alive(area):
			_tick_cooldowns.erase(area)
			continue
		_try_hit(area, true)
		if not _active:
			return
		# O acerto pode ter matado o alvo (e disparado area_exited): só re-arma
		# quem ainda está na lista. O intervalo é somado (não zerado), assim
		# um frame longo não "come" ticks.
		if _tick_cooldowns.has(area):
			_tick_cooldowns[area] = _tick_cooldowns[area] + tick_interval


## _physics_process só roda quando há dano contínuo ou um pulso adiado.
func _update_physics_process() -> void:
	set_physics_process(_pending_pulse or (_active and tick_interval > 0.0))


func _on_area_entered(area: Area2D) -> void:
	if not _active or not _is_valid_target(area):
		return
	if tick_interval > 0.0:
		if damage_on_contact:
			_try_hit(area, true)
		_tick_cooldowns[area] = tick_interval
		_update_physics_process()
	elif damage_on_contact:
		_try_hit(area, false)


func _on_area_exited(area: Area2D) -> void:
	_tick_cooldowns.erase(area)


## Só Hurtboxes ativas de outro ator.
func _is_valid_target(area: Area2D) -> bool:
	if not CombatUtils.is_alive(area) or not area.is_in_group(CombatUtils.GROUP_HURTBOX):
		return false
	if ignore_same_actor and source != null and CombatUtils.get_actor(area) == source:
		return false
	return true


## Aplica o dano.
func _try_hit(area: Area2D, is_tick: bool) -> bool:
	if not _active or not _is_valid_target(area):
		return false
	var target_id: int = area.get_instance_id()
	if not is_tick and one_hit_per_target and _already_hit.has(target_id):
		return false
	if not CombatUtils.apply_damage(area, damage, source):
		return false
	if not is_tick:
		_already_hit[target_id] = true
	hit_landed.emit(area, damage)
	return true
