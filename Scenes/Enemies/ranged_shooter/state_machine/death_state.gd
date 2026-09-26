class_name ShooterDeathState
extends ShooterState
#State do dano de morte

func enter() -> void:
	enemy.velocity = Vector2.ZERO


	enemy.body_collision.set_deferred("disabled", true)
	enemy.hurtbox.set_deferred("monitorable", false)
	enemy.detection_area.set_deferred("monitoring", false)
	enemy.melee_range_area.set_deferred("monitoring", false)

	_spawn_death_trap()

	if enemy.has_node("AnimationPlayer"):
		var anim: AnimationPlayer = enemy.get_node("AnimationPlayer")
		if anim.has_animation("death"):
			anim.play("death")
			await anim.animation_finished

	enemy.queue_free()


func _spawn_death_trap() -> void:
	if enemy.electric_trap_scene == null:
		push_warning("DeathState: electric_trap_scene não foi configurada no RangedEnemy.")
		return

	var trap: Node2D = enemy.electric_trap_scene.instantiate()
	
	enemy.get_tree().current_scene.add_child(trap)
	trap.global_position = enemy.global_position
