class_name GuideAttackSlashState
extends GuideAttackState
## Ataque 4: golpe de espada em área ao redor do chefão (hitbox 3x a da espada do player).

var _duration: float = 0.0  # Duração total do golpe.


## Prepara o golpe: para o chefão, encara o jogador, cria o golpe e toca a animação.
func _begin_attack() -> void:
	enemy.velocity = Vector2.ZERO  # Para o corpo.
	enemy.face_target()  # Encara o jogador.
	_duration = guide.spawn_slash()  # Cria o golpe e guarda a duração.
	enemy.play_anim(animation, true)  # Toca a animação do golpe.


## Espera o golpe acabar antes de liberar outro ataque.
func _update_attack(_delta: float) -> void:
	if _elapsed >= _duration:  # Passou a duração do golpe.
		finish_attack()  # Termina o ataque.
