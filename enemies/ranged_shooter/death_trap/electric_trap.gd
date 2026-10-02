class_name ElectricTrap
extends Node2D
## Armadilha elétrica deixada na morte: dano por tick durante `duration`.

@export var damage_per_tick: int = 10
@export var tick_interval: float = 0.5
@export var duration: float = 6.0
@export var radius: float = 70.0


@export var hitbox: ShooterHitbox
@export var hitbox_shape: CollisionShape2D

var _time_left: float = 0.0


## Raio próprio e hitbox em modo contínuo.
func _ready() -> void:
	if hitbox == null:
		push_error("ElectricTrap: 'hitbox' não foi atribuído no Inspector.")
		set_physics_process(false)
		queue_free()
		return
	CombatUtils.set_unique_circle_radius(hitbox_shape, radius)

	# Dano ao entrar e a cada tick
	hitbox.damage_on_contact = true
	hitbox.configure(damage_per_tick, false, tick_interval)
	hitbox.set_active(true)
	_time_left = duration


## Some quando o tempo acaba.
func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		set_physics_process(false)
		hitbox.set_active(false)
		queue_free()
