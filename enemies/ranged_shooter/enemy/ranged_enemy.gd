class_name RangedEnemy
extends CharacterBody2D
#base inimigo atirador

@export_group("Movimento")
@export var move_speed: float = 120.0

@export_group("Ataque à Distância")
@export var projectile_scene: PackedScene
@export var ranged_attack_distance: float = 350.0
@export var ranged_attack_cooldown: float = 1.4

@export_group("Ataque Corpo a Corpo")
@export var melee_telegraph_scene: PackedScene
@export var melee_telegraph_time: float = 1.0
@export var melee_damage: int = 25
@export var melee_attack_cooldown: float = 1.8

@export_group("Morte")
@export var electric_trap_scene: PackedScene

@onready var state_machine: ShooterStateMachine = $ShooterStateMachine
@onready var detection_area: Area2D = $DetectionArea
@onready var melee_range_area: Area2D = $MeleeRangeArea
@onready var hurtbox: ShooterHurtbox = $ShooterHurtbox
@onready var health: ShooterHealthComponent = $ShooterHealthComponent
@onready var projectile_spawn_point: Marker2D = $ProjectileSpawnPoint
@onready var body_collision: CollisionShape2D = $CollisionShape2D

#Não esquece se o player saiu da área de procura
var target: Node2D = null
var has_aggro: bool = false
var is_player_in_melee_range: bool = false


func _ready() -> void:
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	melee_range_area.body_entered.connect(_on_melee_range_body_entered)
	melee_range_area.body_exited.connect(_on_melee_range_body_exited)
	hurtbox.damage_received.connect(_on_hurtbox_damage_received)
	health.died.connect(_on_health_died)


func _on_detection_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		target = body
		has_aggro = true  # Aggro permanente


func _on_melee_range_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		is_player_in_melee_range = true


func _on_melee_range_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		is_player_in_melee_range = false


func _on_hurtbox_damage_received(amount: int, source: Node) -> void:
	health.apply_damage(amount, source)


func _on_health_died() -> void:
	state_machine.change_state("Death")
