class_name RoboAttackRangedState
extends RoboState
## Carrega (windup) e dispara.

var _cooldown: float = 0.0
var _windup: float = -1.0  # < 0 = sem disparo em preparação


func _on_enter() -> void:
	robo.velocity = Vector2.ZERO
	_cooldown = 0.0
	_windup = -1.0


func physics_update(delta: float) -> void:
	if not robo.has_target():
		robo.drop_target()
		request_no_target_state()
		return
	if robo.target_in_melee_range:
		request_transition(&"AttackMelee")
		return
	if not robo.is_target_in_ranged_distance(RANGE_HYSTERESIS):
		request_transition(&"Chase")
		return

	robo.stop_moving()
	robo.face_target()
	if _windup >= 0.0:
		_windup -= delta
		if _windup < 0.0:
			_fire_projectile()
			report_progress()
			_cooldown = robo.ranged_attack_cooldown
			robo.play_anim(&"idle")
		return
	_cooldown -= delta
	if _cooldown <= 0.0:
		_windup = robo.ranged_windup_time
		robo.play_anim(animation, true)


func _fire_projectile() -> void:
	if robo.projectile_scene == null:
		push_warning("RoboAttackRanged: projectile_scene não configurada.")
		return
	var origin: Vector2 = robo.get_projectile_origin()
	var projectile := PoolHub.acquire(robo.projectile_scene, robo, EnemyProjectile) as EnemyProjectile
	if projectile != null:
		projectile.launch(origin, origin.direction_to(robo.target.global_position), robo)
