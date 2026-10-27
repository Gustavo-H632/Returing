class_name GuideAttackLaserState
extends GuideAttackState
## Ataque 3: raio que cruza a sala (1 na fase 1; 3 espaçados na fase 2). Só o dash escapa.

var _duration: float = 0.0


func _begin_attack() -> void:
	_duration = guide.spawn_lasers()


## Espera o último raio sair da sala antes de liberar outro ataque.
func _update_attack(_delta: float) -> void:
	if _elapsed >= _duration:
		finish_attack()
