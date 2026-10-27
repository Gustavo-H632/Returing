class_name GuideAttackSlashState
extends GuideAttackState
## Ataque 4: golpe de espada em área ao redor do chefão (hitbox 3x a da espada do player).

var _duration: float = 0.0


func _begin_attack() -> void:
	enemy.velocity = Vector2.ZERO
	enemy.face_target()
	_duration = guide.spawn_slash()
	enemy.play_anim(animation, true)


func _update_attack(_delta: float) -> void:
	if _elapsed >= _duration:
		finish_attack()
