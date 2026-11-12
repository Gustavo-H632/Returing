class_name EnemyPatrolState
extends EnemyState
## Patrulha autônoma (wander), genérica para qualquer EnemyBase (Drone, Robo...).

enum Phase { REST, WALK }  # Fases da patrulha: descansa ou caminha.

## Ponto em torno do qual o inimigo vaga.
enum Anchor {
	## Onde ele estava ao entrar na patrulha.
	ENTRY_POINT,
	## Onde ele nasceu (pode exigir contornar paredes para voltar).
	SPAWN_POINT,
}

## Quantas vezes tenta sortear um destino antes de desistir.
const PICK_ATTEMPTS: int = 8
## Tempo máximo de um trajeto = tempo ideal * fator + folga.
const LEG_TIME_FACTOR: float = 2.0
const LEG_TIME_SLACK: float = 1.0  # Folga somada ao tempo máximo do trajeto.

@export_group("Patrulha")
@export var anchor: Anchor = Anchor.ENTRY_POINT  # Âncora da patrulha (onde entrou ou onde nasceu).
## Raio do círculo (em torno da âncora) onde os destinos são sorteados.
@export_range(20.0, 600.0, 1.0) var patrol_radius: float = 140.0
## Distância mínima de cada trajeto (evita micropassos).
@export_range(8.0, 300.0, 1.0) var min_leg_distance: float = 40.0
## Fração da move_speed usada ao patrulhar.
@export_range(0.05, 1.0, 0.05) var speed_multiplier: float = 0.4
## Distância do destino que já conta como "chegou".
@export_range(2.0, 40.0, 1.0) var arrive_distance: float = 8.0

@export_group("Descanso")
@export_range(0.0, 10.0, 0.1) var rest_time_min: float = 0.6  # Descanso mínimo entre trajetos.
@export_range(0.0, 10.0, 0.1) var rest_time_max: float = 1.8  # Descanso máximo entre trajetos.
## Animação tocada durante o descanso (a de caminhada é a `animation` do estado).
@export var rest_animation: StringName = &"idle"

var _phase: Phase = Phase.REST  # Fase atual.
var _anchor_point: Vector2 = Vector2.ZERO  # Ponto central onde o inimigo vaga.
var _destination: Vector2 = Vector2.ZERO  # Destino do trajeto atual.
var _rest_left: float = 0.0  # Tempo restante de descanso.
var _leg_time_left: float = 0.0  # Tempo restante do trajeto.


## Ao entrar: zera o desvio, escolhe a âncora e começa com um descanso aleatório (para vários inimigos não andarem juntos).
func _on_enter() -> void:
	enemy.reset_navigation()  # Limpa o estado do desvio de paredes.
	# Âncora: ponto de nascimento ou posição atual.
	_anchor_point = enemy.spawn_position if anchor == Anchor.SPAWN_POINT else enemy.global_position
	# Descanso inicial aleatório.
	_begin_rest(randf_range(0.0, rest_time_max))  # Começa descansando por um tempo aleatório.


## Ao sair: para o corpo.
func exit() -> void:
	enemy.velocity = Vector2.ZERO


## Vê o jogador: persegue. Senão alterna descanso e caminhada.
func physics_update(delta: float) -> void:
	if enemy.has_target():  # Achou um alvo: persegue.
		request_transition(&"Chase")
		return
	match _phase:  # Executa a fase atual.
		Phase.REST:
			_update_rest(delta)
		Phase.WALK:
			_update_walk(delta)


## Fase de descanso: freia e, acabado o tempo, sorteia um destino e anda.
func _update_rest(delta: float) -> void:
	enemy.brake(delta)  # Desacelera.
	_rest_left -= delta  # Desconta o tempo.
	if _rest_left <= 0.0:  # Acabou o descanso: caminha.
		_begin_walk()


## Fase de caminhada: anda até o destino contornando paredes; chegou, esgotou o tempo ou travou: troca.
func _update_walk(delta: float) -> void:
	_leg_time_left -= delta  # Desconta o tempo do trajeto.
	# Comparação ao quadrado.
	var arrived: bool = enemy.global_position.distance_squared_to(_destination) \
			<= arrive_distance * arrive_distance
	if arrived or _leg_time_left <= 0.0:  # Chegou ou o tempo do trajeto acabou: descansa.
		_begin_rest(randf_range(rest_time_min, rest_time_max))
		return
	if enemy.consume_navigation_stuck():  # Travou em algo: sorteia outro destino.
		_begin_walk()  # Travou: sorteia outro destino na hora.
		return
	# Anda para o destino (com desvio) devagar.
	enemy.navigate_towards(_destination, enemy.move_speed * speed_multiplier, delta)


## Começa um descanso do tamanho pedido e toca a animação de descanso.
func _begin_rest(duration: float) -> void:
	_phase = Phase.REST  # Fase de descanso.
	_rest_left = duration  # Guarda a duração.
	enemy.play_anim(rest_animation)  # Toca a animação parada.


## Sorteia um destino alcançável em linha reta e começa a caminhar.
func _begin_walk() -> void:  # Distância mínima ao quadrado (comparação sem raiz).
	var min_leg_sq: float = min_leg_distance * min_leg_distance
	for _attempt: int in PICK_ATTEMPTS:  # Tenta alguns sorteios antes de desistir.
		# Distância sorteada entre o mínimo e o raio.
		var distance: float = randf_range(min_leg_distance, maxf(patrol_radius, min_leg_distance))
		# Ponto sorteado em volta da âncora.
		var wanted: Vector2 = _anchor_point + Vector2.from_angle(randf() * TAU) * distance
		var reachable: Vector2 = enemy.trim_to_free_space(wanted)  # Encurta se houver parede no caminho.
		# Só serve se o trajeto tiver o tamanho mínimo.
		if enemy.global_position.distance_squared_to(reachable) >= min_leg_sq:
			_destination = reachable  # Guarda o destino.
			_phase = Phase.WALK  # Passa a caminhar.
			_leg_time_left = _estimate_leg_time()  # Calcula o tempo máximo do trajeto.
			enemy.play_anim(animation)  # Toca a animação de caminhada.
			return
	# Cercado por paredes: descansa e tenta de novo depois.
	_begin_rest(randf_range(rest_time_min, rest_time_max))


## Estima o tempo do trajeto: tempo ideal vezes o fator mais a folga (para nunca travar caminhando).
func _estimate_leg_time() -> float:
	# Velocidade de patrulha (nunca menor que 1).
	var speed: float = maxf(enemy.move_speed * speed_multiplier, 1.0)
	# Distância dividida pela velocidade, com margem.
	return enemy.global_position.distance_to(_destination) / speed * LEG_TIME_FACTOR + LEG_TIME_SLACK
