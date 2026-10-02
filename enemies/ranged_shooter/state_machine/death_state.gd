class_name ShooterDeathState
extends ShooterState
## Morte: desliga colisões, cria a armadilha e some (com limite de tempo).

const DEATH_ANIMATION: StringName = &"death"
const EXTRA_WAIT: float = 0.1


## Desliga tudo, cria a armadilha e agenda a remoção.
func enter() -> void:
	state_machine.locked = true  # nada sai deste estado
	enemy.velocity = Vector2.ZERO

	if enemy.body_collision != null:
		enemy.body_collision.set_deferred(&"disabled", true)
	if enemy.hurtbox != null:
		enemy.hurtbox.set_active(false)
	if enemy.detection_area != null:
		enemy.detection_area.set_deferred(&"monitoring", false)
	if enemy.melee_range_area != null:
		enemy.melee_range_area.set_deferred(&"monitoring", false)

	_spawn_death_trap()

	var anim := enemy.animation_player
	if anim != null and anim.has_animation(DEATH_ANIMATION):
		anim.play(DEATH_ANIMATION)
		var wait := anim.get_animation(DEATH_ANIMATION).length + EXTRA_WAIT
		# Timer some junto se o inimigo sumir antes
		enemy.get_tree().create_timer(wait, false).timeout.connect(enemy.queue_free)
	else:
		enemy.queue_free()


## Cria a armadilha elétrica.
func _spawn_death_trap() -> void:
	if enemy.electric_trap_scene == null:
		push_warning("DeathState: electric_trap_scene não foi configurada no RangedEnemy.")
		return
	CombatUtils.spawn(enemy.electric_trap_scene, enemy, enemy.global_position)
