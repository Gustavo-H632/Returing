class_name ShooterAttackRangedState
extends ShooterState
## Atira de tempos em tempos enquanto o alvo estiver no alcance.

## Margem para não alternar na borda do alcance
const RANGE_HYSTERESIS: float = 1.15

var _cooldown: float = 0.0


## Para e prepara o primeiro tiro.
func enter() -> void:
	enemy.velocity = Vector2.ZERO
	_cooldown = 0.0  # atira ao entrar


## Troca de estado ou atira.
func physics_update(delta: float) -> void:
	if not enemy.has_target():
		enemy.drop_target()
		request_transition(&"Idle")
		return
	if enemy.is_player_in_melee_range:
		request_transition(&"AttackMelee")
		return
	if not enemy.is_target_in_ranged_distance(RANGE_HYSTERESIS):
		request_transition(&"Chase")
		return

	enemy.stop_moving()
	_cooldown -= delta
	if _cooldown <= 0.0:
		_fire_projectile()
		_cooldown = enemy.ranged_attack_cooldown


## Cria o projétil na direção do alvo.
func _fire_projectile() -> void:
	if enemy.projectile_scene == null:
		push_warning("AttackRangedState: projectile_scene não foi configurada no RangedEnemy.")
		return
	var origin := enemy.get_projectile_origin()
	var projectile := CombatUtils.spawn(enemy.projectile_scene, enemy, origin, EnemyProjectile) as EnemyProjectile
	if projectile != null:
		projectile.launch(origin.direction_to(enemy.target.global_position), enemy)
