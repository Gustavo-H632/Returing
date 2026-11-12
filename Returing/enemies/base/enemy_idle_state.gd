class_name EnemyIdleState
extends EnemyState
## Sentinela: o inimigo freia e espera parado até enxergar o player.

## Segundos parado antes de voltar a patrulhar (só vale se houver nó Patrol).
@export_range(0.0, 10.0, 0.1, "or_greater") var patrol_delay: float = 0.6

var _patrol_left: float = 0.0  # Tempo restante antes de patrulhar.


## Ao entrar: para o inimigo e reinicia a contagem para voltar a patrulhar.
func _on_enter() -> void:
	enemy.velocity = Vector2.ZERO  # Para o corpo.
	_patrol_left = patrol_delay  # Reinicia a espera.


## Parado: freia, vai perseguir se vê o jogador e, passado o tempo, volta a patrulhar (se existir esse estado).
func physics_update(delta: float) -> void:
	enemy.brake(delta)  # Desacelera até parar.
	if enemy.has_target():  # Viu o jogador: persegue.
		request_transition(&"Chase")  # Pede a troca para Chase.
		return
	if not state_machine.has_state(&"Patrol"):  # Cena sem estado Patrol: fica parado.
		return
	_patrol_left -= delta  # Desconta a espera.
	if _patrol_left <= 0.0:  # Acabou a espera: volta a patrulhar.
		request_transition(&"Patrol")
