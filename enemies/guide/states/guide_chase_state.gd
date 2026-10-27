class_name GuideChaseState
extends GuideState
## Perseguição constante: o Guide sempre vai atrás do player e escolhe o próximo ataque.


func _on_enter() -> void:
	guide.reset_navigation()


func physics_update(delta: float) -> void:
	if not guide.has_target():
		request_no_target_state()
		return
	guide.chase_target(delta)
	# O golpe de espada tem prioridade quando o player chega perto.
	if guide.can_slash():
		request_transition(GuideEnemy.ATTACK_SLASH)
	elif guide.attack_ready():
		request_transition(guide.pick_attack())
