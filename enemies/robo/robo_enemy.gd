class_name RoboEnemy
extends EnemyBase
## Projétil (Ranged) — sprite robo.png.

@export_group("Ataque à Distância")
@export var projectile_scene: PackedScene
@export var ranged_attack_distance: float = 350.0
@export var ranged_attack_cooldown: float = 1.4
## Tempo de carga antes de cada disparo (animação "attack_ranged").
@export var ranged_windup_time: float = 0.3

@export_group("Ataque em Área")
@export var melee_telegraph_scene: PackedScene
@export var melee_telegraph_time: float = 1.0
@export var melee_damage: int = 25
@export var melee_attack_cooldown: float = 1.8

@export_group("Percepção")
## True = aggro permanente: depois de ver o player, o Robo nunca mais o esquece.
@export var permanent_aggro: bool = false

@export_group("Morte")
@export var electric_trap_scene: PackedScene

@export_group("Referências (já ligadas na cena)")
@export var melee_range_area: Area2D
@export var projectile_spawn_point: Marker2D

var target_in_melee_range: bool = false


func _on_enemy_ready() -> void:
	if melee_range_area != null:
		CombatUtils.connect_once(melee_range_area.body_entered, _on_melee_range_body_entered)
		CombatUtils.connect_once(melee_range_area.body_exited, _on_melee_range_body_exited)


## Com aggro permanente, o Robo não esquece o player.
func _on_detection_body_exited(body: Node2D) -> void:
	if not permanent_aggro:
		super._on_detection_body_exited(body)


func drop_target() -> void:
	super.drop_target()
	target_in_melee_range = false


func is_target_in_ranged_distance(multiplier: float = 1.0) -> bool:
	var max_dist: float = ranged_attack_distance * multiplier
	return distance_sq_to_target() <= max_dist * max_dist


func get_projectile_origin() -> Vector2:
	return projectile_spawn_point.global_position if projectile_spawn_point != null else global_position


func _on_melee_range_body_entered(body: Node2D) -> void:
	if CombatUtils.is_player(body):
		target_in_melee_range = true


func _on_melee_range_body_exited(body: Node2D) -> void:
	if CombatUtils.is_player(body):
		target_in_melee_range = false


func _on_death() -> void:
	if melee_range_area != null:
		melee_range_area.set_deferred(&"monitoring", false)
	if electric_trap_scene == null:
		push_warning("RoboEnemy: electric_trap_scene não configurada.")
		return
	CombatUtils.spawn(electric_trap_scene, self, global_position)
