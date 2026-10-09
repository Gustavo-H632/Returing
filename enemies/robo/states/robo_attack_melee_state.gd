class_name RoboAttackMeleeState
extends RoboState
## Ataque em área: cria o telegraph (que aplica o dano) e espera carga + recarga.

enum Phase { CHARGING, COOLDOWN }

var _phase: Phase = Phase.COOLDOWN
var _timer: float = 0.0


func _on_enter() -> void:
	robo.velocity = Vector2.ZERO
	_start_telegraph()


func physics_update(delta: float) -> void:
	if not robo.has_target():
		robo.drop_target()
		request_transition(&"Idle")
		return
	robo.stop_moving()
	_timer -= delta
	if _timer > 0.0:
		return
	match _phase:
		Phase.CHARGING:
			_phase = Phase.COOLDOWN
			_timer = robo.melee_attack_cooldown
			robo.play_anim(&"idle")
		Phase.COOLDOWN:
			if robo.target_in_melee_range:
				_start_telegraph()
			elif robo.is_target_in_ranged_distance():
				request_transition(&"AttackRanged")
			else:
				request_transition(&"Chase")


func _start_telegraph() -> void:
	_phase = Phase.CHARGING
	_timer = robo.melee_telegraph_time
	robo.play_anim(animation, true)
	if robo.melee_telegraph_scene == null:
		push_warning("RoboAttackMelee: melee_telegraph_scene não configurada.")
		return
	var telegraph := CombatUtils.spawn(robo.melee_telegraph_scene, robo, robo.global_position, MeleeTelegraph) as MeleeTelegraph
	if telegraph != null:
		telegraph.setup(robo.melee_telegraph_time, robo.melee_damage)
		telegraph.source = robo
