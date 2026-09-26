class_name TankHurtbox
extends Area2D

## TankHurtbox
@export var health_component_path: NodePath

var health_component: TankHealthComponent


func _ready() -> void:
	add_to_group("hurtbox")
	if health_component_path:
		health_component = get_node(health_component_path)
	else:
		push_warning("TankHurtbox sem health_component_path configurado em: " + str(get_path()))



func take_damage(amount: int, _source_position: Vector2 = Vector2.ZERO) -> void:
	if health_component:
		health_component.take_damage(amount)


## Liga/desliga esta hurtbox
func set_active(value: bool) -> void:
	
	set_deferred("monitorable", value)
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", not value)
