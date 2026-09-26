class_name ShooterAttackMeleeState
extends ShooterState
## Ataque de choque

enum Phase { CHARGING, COOLDOWN }

var _phase: Phase = Phase.COOLDOWN
var _timer: float = 0.0


func enter() -> void:
	_start_telegraph()


func physics_update(delta: float) -> void:
	if enemy.target == null or not is_instance_valid(enemy.target):
		return

	# Inimigo fica parado
	enemy.velocity = Vector2.ZERO
	enemy.move_and_slide()

	_timer -= delta
	if _timer > 0.0:
		return

	match _phase:
		Phase.CHARGING:
			# O dano em área é aplicado pela própria cena 
			_phase = Phase.COOLDOWN
			_timer = enemy.melee_attack_cooldown

		Phase.COOLDOWN:
			if enemy.is_player_in_melee_range:
				_start_telegraph()
			else:
				var distance := enemy.global_position.distance_to(enemy.target.global_position)
				if distance <= enemy.ranged_attack_distance:
					transition_requested.emit("AttackRanged")
				else:
					transition_requested.emit("Chase")


func _start_telegraph() -> void:
	_phase = Phase.CHARGING
	_timer = enemy.melee_telegraph_time

	if enemy.melee_telegraph_scene == null:
		push_warning("AttackMeleeState: melee_telegraph_scene não foi configurada no RangedEnemy.")
		return

	var telegraph: Node2D = enemy.melee_telegraph_scene.instantiate()
	
	enemy.get_tree().current_scene.add_child(telegraph)
	telegraph.global_position = enemy.global_position
	telegraph.setup(enemy.melee_telegraph_time, enemy.melee_damage)
