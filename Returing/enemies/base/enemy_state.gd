class_name EnemyState
extends BaseState
## Estado base dos inimigos.

## Margem de alcance para o inimigo não ficar trocando de estado na borda.
const RANGE_HYSTERESIS: float = 1.15

## Animação tocada ao entrar no estado (vazio = não troca).
@export var animation: StringName = &""

var enemy: EnemyBase = null  # Inimigo dono do estado (já convertido para EnemyBase).


## Registra o inimigo (convertido para EnemyBase) e roda o gancho das subclasses.
func _on_setup() -> void:
	enemy = actor as EnemyBase  # Converte o ator.
	if enemy == null:  # Sem EnemyBase não funciona.
		# Avisa o erro no console.
		push_error("%s: o ator da máquina de estados precisa herdar de EnemyBase." % name)
		return
	_on_enemy_setup()  # Gancho para as subclasses.


## Gancho para subclasses fazerem o cast para o tipo concreto.
func _on_enemy_setup() -> void:
	pass


## Ao entrar: toca a animação do estado (se houver) e roda o gancho das subclasses.
func enter() -> void:
	if animation != &"":  # Só troca animação se o estado tiver uma.
		enemy.play_anim(animation)
	_on_enter()  # Gancho.


## Gancho vazio: as subclasses sobrescrevem para o que acontece ao entrar.
func _on_enter() -> void:
	pass


## Avisa a rede de segurança do StateWarden que o ataque em loop ainda está progredindo.
func report_progress() -> void:  # Avisa a rede de segurança que o ataque ainda progride.
	if state_machine is StateWarden:  # Só a StateWarden tem esse recurso.
		(state_machine as StateWarden).report_progress()  # Zera o cronômetro dela.


## Sem alvo: volta a patrulhar (ou ao Idle, se a cena não tiver o estado Patrol).
func request_no_target_state() -> void:  # Sem estado Patrol na cena, volta ao Idle.
	request_transition(&"Patrol" if state_machine.has_state(&"Patrol") else &"Idle")  # Pede a troca.
