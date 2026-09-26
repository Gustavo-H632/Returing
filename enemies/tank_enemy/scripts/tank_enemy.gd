class_name TankEnemy
extends CharacterBody2D

#Tank Enemy states


@export_group("Status")
@export var max_health: int = 500          
@export var move_speed: float = 45.0       

@export_group("Detecção")
@export var detection_radius: float = 420.0     ## Raio da área de busca 
@export var attack_range_radius: float = 90.0   ## Raio da área de aatque

@export_group("Ataque de Área (Pisoteio)")
@export var stomp_damage: int = 15
@export var stomp_pulse_interval: float = 1.0  

@export_group("Investida (Special Attack / Bull Dash)")
@export var min_distance_for_dash: float = 260.0 ## Distância mínima p/  o dash.
@export var dash_prepare_time: float = 0.8        
@export var dash_duration: float = 0.5            
@export var dash_speed: float = 520.0             ## Velocidade durante a investida.
@export var dash_damage: int = 40

@export_group("Vagar (Idle Ativo)")
@export var wander_radius: float = 110.0        
@export var wander_speed_multiplier: float = 0.35



@onready var state_machine: TankStateMachine = $TankStateMachine
@onready var health_component: TankHealthComponent = $TankHealthComponent

@onready var detection_area: Area2D = $DetectionArea
@onready var attack_range_area: Area2D = $AttackRangeArea

@onready var hurtbox: TankHurtbox = $TankHurtbox
@onready var stomp_hitbox: TankHitbox = $StompHitbox
@onready var dash_hitbox: TankHitbox = $DashHitbox

@onready var sprite: Sprite2D = $VisualSprite

@onready var idle_wander_timer: Timer = $Timers/IdleWanderTimer
@onready var attack_pulse_timer: Timer = $Timers/AttackPulseTimer
@onready var dash_prepare_timer: Timer = $Timers/DashPrepareTimer
@onready var dash_duration_timer: Timer = $Timers/DashDurationTimer


var player: Node2D = null         
var spawn_position: Vector2        
var dash_direction: Vector2 = Vector2.ZERO ## Direção travada da investida.

var _flash_tween: Tween 

signal died


func _ready() -> void:
	spawn_position = global_position

	health_component.max_health = max_health
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)

	_setup_detection_shapes()

	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	attack_range_area.body_entered.connect(_on_attack_range_body_entered)
	attack_range_area.body_exited.connect(_on_attack_range_body_exited)

	
	state_machine.setup(self)



func _setup_detection_shapes() -> void:
	var detection_shape := CircleShape2D.new()
	detection_shape.radius = detection_radius
	$DetectionArea/CollisionShape2D.shape = detection_shape

	var attack_shape := CircleShape2D.new()
	attack_shape.radius = attack_range_radius
	$AttackRangeArea/CollisionShape2D.shape = attack_shape
	
	$StompHitbox/CollisionShape2D.shape = attack_shape.duplicate()

func _on_detection_area_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	player = body

	
	if state_machine.current_state.name.to_lower() == "idle":
		state_machine.transition_to("chase")


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body != player:
		return
	player = null

	
	if state_machine.current_state.name.to_lower() == "chase":
		state_machine.transition_to("idle")


func _on_attack_range_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	if state_machine.current_state.name.to_lower() == "chase":
		state_machine.transition_to("attack")


func _on_attack_range_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if state_machine.current_state.name.to_lower() == "attack":
		state_machine.transition_to("chase")


# take damage method
func _on_damaged(_amount: int) -> void:
	_flash_white()


func _flash_white() -> void:
	if not sprite:
		return

	
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()

	var current_alpha := sprite.modulate.a
	sprite.modulate = Color(3.0, 3.0, 3.0, current_alpha)
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, current_alpha), 0.15)


func _on_died() -> void:
	died.emit()

	state_machine.set_physics_process(false)
	state_machine.set_process(false)
	detection_area.set_deferred("monitoring", false)
	attack_range_area.set_deferred("monitoring", false)
	hurtbox.set_active(false)
	stomp_hitbox.set_active(false)
	dash_hitbox.set_active(false)

	if not sprite:
		queue_free()
		return

	
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()

	var death_tween := create_tween()
	death_tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	death_tween.tween_callback(queue_free)
