class_name ElectricTrap
extends Node2D
#dano da morte do shooter

@export var damage_per_tick: int = 10
@export var tick_interval: float = 0.5
@export var duration: float = 6.0
@export var radius: float = 70.0

@onready var hitbox: ShooterHitbox = $ShooterHitbox
@onready var collision_shape: CollisionShape2D = $ShooterHitbox/CollisionShape2D
@onready var lifetime_timer: Timer = $LifetimeTimer


func _ready() -> void:
	if collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = radius

	
	hitbox.configure(damage_per_tick, false, tick_interval)
	hitbox.set_active(true)
	# eVITAR O
	hitbox.apply_burst_damage()

	lifetime_timer.wait_time = duration
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(queue_free)
	lifetime_timer.start()
