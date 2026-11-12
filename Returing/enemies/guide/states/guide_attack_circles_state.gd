class_name GuideAttackCirclesState
extends GuideAttackState
## Ataque 1: solta os círculos de aviso um a um (6 na fase 1, 9 na fase 2).

var _remaining: int = 0  # Círculos que ainda faltam soltar.
var _index: int = 0  # Número do próximo círculo (o primeiro cai no jogador).
var _interval_left: float = 0.0  # Tempo até o próximo círculo.


## Prepara o ataque: lê a quantidade de círculos da fase atual e zera os contadores.
func _begin_attack() -> void:
	_remaining = guide.get_circle_count()  # Quantidade conforme a fase.
	_index = 0  # Começa pelo círculo 0.
	_interval_left = 0.0  # O primeiro sai já.


## A cada quadro solta um círculo quando o intervalo acaba; ao soltar o último, termina o ataque.
func _update_attack(delta: float) -> void:
	_interval_left -= delta  # Desconta o intervalo.
	if _interval_left > 0.0:  # Ainda não é hora.
		return
	guide.spawn_circle(_index)  # Solta o círculo.
	_index += 1  # Próximo número.
	_remaining -= 1  # Um a menos.
	_interval_left = guide.circle_spawn_interval  # Reinicia o intervalo.
	if _remaining <= 0:  # Era o último: termina.
		finish_attack()  # Libera o próximo ataque.
