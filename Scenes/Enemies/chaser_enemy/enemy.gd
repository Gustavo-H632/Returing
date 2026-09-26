class_name ChaserEnemy
extends CharacterBody2D



signal health_changed(current_health: int, max_health: int)
signal died(enemy: ChaserEnemy)

@export_group("Movimento")
@export var move_speed: float = 120.0
@export var chase_speed_multiplier: float = 1.0

@export_group("Vida e Dano")
@export var max_health: int = 30
@export var base_damage: int = 10 # aplicado a hitbox do chaser

@export_group("Onda de Energia")
@export var energy_wave_scene: PackedScene
@export var energy_wave_damage: int = 15
@export var energy_wave_expand_time: float = 0.6

var current_health: int
var player_ref: Node2D = null

var _detection_radius: float = 150.0 # range de detecção

@onready var state_machine: ChaserStateMachine = $ChaserStateMachine
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_range: Area2D = $AttackRange
@onready var hurtbox: ChaserHurtbox = $ChaserHurtbox
@onready var hitbox: ChaserHitbox = $ChaserHitbox
@onready var attack_windup_timer: Timer = $AttackWindupTimer
@onready var attack_cooldown_timer: Timer = $AttackCooldownTimer
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	current_health = max_health
	_detection_radius = _read_detection_radius()

	attack_windup_timer.one_shot = true
	attack_cooldown_timer.one_shot = true
	attack_windup_timer.stop()
	attack_cooldown_timer.stop()

	hitbox.damage = base_damage
	hurtbox.damaged.connect(take_damage)

	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)
	attack_range.body_entered.connect(_on_attack_range_body_entered)
	attack_range.body_exited.connect(_on_attack_range_body_exited)

	state_machine.start()


func _read_detection_radius() -> float:
	var shape_node := detection_area.get_node("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is CircleShape2D:
		return (shape_node.shape as CircleShape2D).radius
	push_warning("DetectionArea sem CircleShape2D válido; usando raio padrão (%.0f)." % _detection_radius)
	return _detection_radius


#Vida 

func take_damage(amount: int) -> void:
	if current_health <= 0:
		return
	current_health = max(current_health - amount, 0)
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		die()


func die() -> void:
	died.emit(self)
	set_physics_process(false)
	# set_deferred evita problemas de flag
	hurtbox.set_deferred("monitoring", false)
	hitbox.deactivate()
	collision_layer = 0
	collision_mask = 0
	queue_free()



## Vira o sprite conforme a direção do movimento
func face_direction(direction: Vector2) -> void:
	if sprite and abs(direction.x) > 0.01:
		sprite.flip_h = direction.x < 0.0


# Onda de energia

func fire_energy_wave() -> void:
	if energy_wave_scene == null:
		push_warning("[%s] energy_wave_scene não configurado no Inspector." % name)
		return

	var wave := energy_wave_scene.instantiate() as EnergyWave
	if wave == null:
		push_error("energy_wave_scene precisa ter EnergyWave (energy_wave.gd) na raiz da cena.")
		return

	var parent_node: Node = get_tree().current_scene
	if parent_node == null:
		parent_node = get_parent()
	parent_node.add_child(wave)
	wave.global_position = global_position

	wave.setup(_detection_radius, energy_wave_damage, energy_wave_expand_time)



func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_ref = body
		state_machine.notify_player_spotted(body)

func _on_detection_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		state_machine.notify_player_lost(body)

func _on_attack_range_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		state_machine.notify_player_in_attack_range(body)

func _on_attack_range_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		state_machine.notify_player_left_attack_range(body)
