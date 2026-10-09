class_name Hurtbox
extends Area2D
## Área que RECEBE dano (detectada por uma Hitbox).
## Rota do dano: `health_component` (se definido) ou o `take_damage()` do ator.
## O ator decide se aceita (i-frames, morto etc.), então ele é o destino preferido.

signal damage_received(amount: int, source: Variant)

## Raiz da cena a quem esta Hurtbox pertence.
@export var actor: Node = null
## Opcional: entrega direto na vida, ignorando o ator.
@export var health_component: HealthComponent
@export var active_on_start: bool = true

var _active: bool = true


func _ready() -> void:
	add_to_group(CombatUtils.GROUP_HURTBOX)
	monitoring = false
	set_active(active_on_start)


## API única de dano do projeto. true se o dano foi aceito.
func take_damage(amount: int, source: Variant = null) -> bool:
	if not _active or amount <= 0:
		return false
	if not _deliver_damage(amount, source):
		return false
	damage_received.emit(amount, source)
	return true


func set_active(value: bool) -> void:
	_active = value
	set_deferred(&"monitorable", value)


func is_active() -> bool:
	return _active


func get_actor() -> Node:
	return CombatUtils.get_actor(self)


func _deliver_damage(amount: int, source: Variant) -> bool:
	if CombatUtils.is_valid(health_component):
		return health_component.take_damage(amount, source) > 0
	var owner_actor: Node = get_actor()
	if owner_actor == null or owner_actor == self:
		return false
	return CombatUtils.apply_damage(owner_actor, amount, source)
