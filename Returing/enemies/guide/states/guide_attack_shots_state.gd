class_name GuideAttackShotsState
extends GuideAttackState
## Ataques 2 e 6: tiros largos na direção do player (3 na fase 1; 5 na fase 2, que se dividem em 8).

var _remaining: int = 0  # Tiros que ainda faltam.
var _interval_left: float = 0.0  # Tempo até o próximo tiro.


## Prepara o ataque: lê a quantidade de tiros da fase atual.
func _begin_attack() -> void:
	_remaining = guide.get_shot_count()  # Quantidade conforme a fase.
	_interval_left = 0.0  # O primeiro sai já.


## A cada quadro atira quando o intervalo acaba; ao atirar o último, termina o ataque.
func _update_attack(delta: float) -> void:
	_interval_left -= delta  # Desconta o intervalo.
	if _interval_left > 0.0:  # Ainda não é hora.
		return
	guide.fire_shot()  # mira no player na hora do disparo
	_remaining -= 1  # Um a menos.
	_interval_left = guide.shot_interval  # Reinicia o intervalo.
	if _remaining <= 0:  # Era o último: termina.
		finish_attack()  # Libera o próximo ataque.
