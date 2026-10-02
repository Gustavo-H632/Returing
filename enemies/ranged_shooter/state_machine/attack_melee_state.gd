class_name ShooterAttackMeleeState
extends ShooterState
## Ataque em área: cria o telegraph, espera a carga e a recarga.

enum Phase { CHARGING, COOLDOWN }

var _phase: Phase = Phase.COOLDOWN
var _timer: float = 0.0


## Para e cria o telegraph.
func enter() -> void:
	enemy.velocity = Vector2.ZERO
	_start_telegraph()


## Carga, recarga e próximo ataque.
func physics_update(delta: float) -> void:
	if not enemy.has_target():
		enemy.drop_target()
		request_transition(&"Idle")
		return

	enemy.stop_moving()
	_timer -= delta
	if _timer > 0.0:
		return

	match _phase:
		Phase.CHARGING:
			# O dano é do MeleeTelegraph
			_phase = Phase.COOLDOWN
			_timer = enemy.melee_attack_cooldown
		Phase.COOLDOWN:
			if enemy.is_player_in_melee_range:
				_start_telegraph()
			elif enemy.is_target_in_ranged_distance():
				request_transition(&"AttackRanged")
			else:
				request_transition(&"Chase")


## Cria o círculo de aviso.
func _start_telegraph() -> void:
	_phase = Phase.CHARGING
	_timer = enemy.melee_telegraph_time

	if enemy.melee_telegraph_scene == null:
		push_warning("AttackMeleeState: melee_telegraph_scene não foi configurada no RangedEnemy.")
		return
	var telegraph := CombatUtils.spawn(enemy.melee_telegraph_scene, enemy,
		enemy.global_position, MeleeTelegraph) as MeleeTelegraph
	if telegraph != null:
		telegraph.setup(enemy.melee_telegraph_time, enemy.melee_damage)
