class_name GuideAttackShotsState
extends GuideAttackState
## Ataques 2 e 6: tiros largos na direção do player (3 na fase 1; 5 na fase 2, que se dividem em 8).

var _remaining: int = 0
var _interval_left: float = 0.0


func _begin_attack() -> void:
	_remaining = guide.get_shot_count()
	_interval_left = 0.0


func _update_attack(delta: float) -> void:
	_interval_left -= delta
	if _interval_left > 0.0:
		return
	guide.fire_shot()  # mira no player na hora do disparo
	_remaining -= 1
	_interval_left = guide.shot_interval
	if _remaining <= 0:
		finish_attack()
