class_name Hurtbox
extends Area2D
## Área que recebe dano detectada pela Hitbox.


signal damage_received(amount: int, source: Variant)

## Raiz da cena a quem esta Hurtbox pertence 
@export var actor: Node = null
@export var health_component: HealthComponent
@export var active_on_start: bool = true

var _active: bool = true


## Grupo hurtbox, só monitorável.
func _ready() -> void:
	add_to_group(CombatUtils.GROUP_HURTBOX)
	monitoring = false
	if health_component == null:
		health_component = _find_sibling_health_component()
	set_active(active_on_start)


## api única de dano do projeto
func take_damage(amount: int, source: Variant = null) -> bool:
	if not _active or amount <= 0:
		return false
	if not _deliver_damage(amount, source):
		return false
	damage_received.emit(amount, source)
	return true


## Liga/desliga o recebimento de dano.
func set_active(value: bool) -> void:
	_active = value
	set_deferred(&"monitorable", value)


## true se recebe dano.
func is_active() -> bool:
	return _active


## Dono desta hurtbox.
func get_actor() -> Node:
	return CombatUtils.get_actor(self)  # respeita o export `actor`


## ubclasses podem redirecionar o dano para outro destino
func _deliver_damage(amount: int, source: Variant) -> bool:
	if CombatUtils.is_valid(health_component):
		return health_component.take_damage(amount, source) > 0
	return true


## Procura a vida entre os irmãos.
func _find_sibling_health_component() -> HealthComponent:
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is HealthComponent:
			return child as HealthComponent
	return null
