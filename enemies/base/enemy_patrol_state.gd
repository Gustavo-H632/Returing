class_name EnemyPatrolState
extends EnemyState
## Patrulha autônoma (wander), genérica para qualquer EnemyBase (Drone, Robo...).

enum Phase { REST, WALK }

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
const LEG_TIME_SLACK: float = 1.0

@export_group("Patrulha")
@export var anchor: Anchor = Anchor.ENTRY_POINT
## Raio do círculo (em torno da âncora) onde os destinos são sorteados.
@export_range(20.0, 600.0, 1.0) var patrol_radius: float = 140.0
## Distância mínima de cada trajeto (evita micropassos).
@export_range(8.0, 300.0, 1.0) var min_leg_distance: float = 40.0
## Fração da move_speed usada ao patrulhar.
@export_range(0.05, 1.0, 0.05) var speed_multiplier: float = 0.4
## Distância do destino que já conta como "chegou".
@export_range(2.0, 40.0, 1.0) var arrive_distance: float = 8.0

@export_group("Descanso")
@export_range(0.0, 10.0, 0.1) var rest_time_min: float = 0.6
@export_range(0.0, 10.0, 0.1) var rest_time_max: float = 1.8
## Animação tocada durante o descanso (a de caminhada é a `animation` do estado).
@export var rest_animation: StringName = &"idle"

var _phase: Phase = Phase.REST
var _anchor_point: Vector2 = Vector2.ZERO
var _destination: Vector2 = Vector2.ZERO
var _rest_left: float = 0.0
var _leg_time_left: float = 0.0


func _on_enter() -> void:
	enemy.reset_navigation()
	_anchor_point = enemy.spawn_position if anchor == Anchor.SPAWN_POINT else enemy.global_position
	# Descanso inicial aleatório.
	_begin_rest(randf_range(0.0, rest_time_max))


func exit() -> void:
	enemy.velocity = Vector2.ZERO


func physics_update(delta: float) -> void:
	if enemy.has_target():
		request_transition(&"Chase")
		return
	match _phase:
		Phase.REST:
			_update_rest(delta)
		Phase.WALK:
			_update_walk(delta)


func _update_rest(delta: float) -> void:
	enemy.brake(delta)
	_rest_left -= delta
	if _rest_left <= 0.0:
		_begin_walk()


func _update_walk(delta: float) -> void:
	_leg_time_left -= delta
	# Comparação ao quadrado.
	var arrived: bool = enemy.global_position.distance_squared_to(_destination) \
			<= arrive_distance * arrive_distance
	if arrived or _leg_time_left <= 0.0:
		_begin_rest(randf_range(rest_time_min, rest_time_max))
		return
	if enemy.consume_navigation_stuck():
		_begin_walk()  # Travou: sorteia outro destino na hora.
		return
	enemy.navigate_towards(_destination, enemy.move_speed * speed_multiplier, delta)


func _begin_rest(duration: float) -> void:
	_phase = Phase.REST
	_rest_left = duration
	enemy.play_anim(rest_animation)


## Sorteia um destino alcançável em linha reta e começa a caminhar.
func _begin_walk() -> void:
	var min_leg_sq: float = min_leg_distance * min_leg_distance
	for _attempt: int in PICK_ATTEMPTS:
		var distance: float = randf_range(min_leg_distance, maxf(patrol_radius, min_leg_distance))
		var wanted: Vector2 = _anchor_point + Vector2.from_angle(randf() * TAU) * distance
		var reachable: Vector2 = enemy.trim_to_free_space(wanted)
		if enemy.global_position.distance_squared_to(reachable) >= min_leg_sq:
			_destination = reachable
			_phase = Phase.WALK
			_leg_time_left = _estimate_leg_time()
			enemy.play_anim(animation)
			return
	# Cercado por paredes: descansa e tenta de novo depois.
	_begin_rest(randf_range(rest_time_min, rest_time_max))


func _estimate_leg_time() -> float:
	var speed: float = maxf(enemy.move_speed * speed_multiplier, 1.0)
	return enemy.global_position.distance_to(_destination) / speed * LEG_TIME_FACTOR + LEG_TIME_SLACK
