class_name ShooterAttackRangedState
extends ShooterState
## Dispara projéteis periodicamente enquanto o jogador dentro do alcance

const RANGE_HYSTERESIS: float = 1.15

var _cooldown: float = 0.0


func enter() -> void:
	enemy.velocity = Vector2.ZERO
	_cooldown = 0.0  # Atira imediatamente ao entrar no estado.


func physics_update(delta: float) -> void:
	if enemy.target == null or not is_instance_valid(enemy.target):
		return

	if enemy.is_player_in_melee_range:
		transition_requested.emit("AttackMelee")
		return

	var distance := enemy.global_position.distance_to(enemy.target.global_position)
	if distance > enemy.ranged_attack_distance * RANGE_HYSTERESIS:
		transition_requested.emit("Chase")
		return

	# Atirador fica parado enquanto atira 
	enemy.velocity = Vector2.ZERO
	enemy.move_and_slide()

	_cooldown -= delta
	if _cooldown <= 0.0:
		_fire_projectile()
		_cooldown = enemy.ranged_attack_cooldown


func _fire_projectile() -> void:
	if enemy.projectile_scene == null:
		push_warning("AttackRangedState: projectile_scene não foi configurada no RangedEnemy.")
		return

	var projectile: Node2D = enemy.projectile_scene.instantiate()

	enemy.get_tree().current_scene.add_child(projectile)
	projectile.global_position = enemy.projectile_spawn_point.global_position

	var direction := projectile.global_position.direction_to(enemy.target.global_position)
	projectile.launch(direction)
