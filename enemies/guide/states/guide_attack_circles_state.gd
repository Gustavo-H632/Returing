class_name GuideAttackCirclesState
extends GuideAttackState
## Ataque 1: solta os círculos de aviso um a um (6 na fase 1, 9 na fase 2).

var _remaining: int = 0
var _index: int = 0
var _interval_left: float = 0.0


func _begin_attack() -> void:
	_remaining = guide.get_circle_count()
	_index = 0
	_interval_left = 0.0


func _update_attack(delta: float) -> void:
	_interval_left -= delta
	if _interval_left > 0.0:
		return
	guide.spawn_circle(_index)
	_index += 1
	_remaining -= 1
	_interval_left = guide.circle_spawn_interval
	if _remaining <= 0:
		finish_attack()
