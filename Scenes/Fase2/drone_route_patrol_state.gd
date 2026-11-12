class_name DroneRoutePatrolState
extends EnemyPatrolState
## Patrulha por ROTA: em vez de vagar em volta de um ponto, o drone vai e volta entre os Marker2D
## filhos do nó `route_path`, andando pelos corredores (MazeGraph) para nunca empurrar contra parede.
## Substitui o script do estado "Patrol" do DroneEnemy SOMENTE nas instâncias do labirinto (o
## DroneEnemy.tscn e os scripts originais não foram alterados). Ao ver o jogador persegue como sempre;
## ao perdê-lo volta para a rota, começando pelo ponto mais próximo (pelo caminho dos corredores).

## Caminho (relativo a este nó) até um Node2D cujos filhos Marker2D são os pontos da rota.
@export var route_path: NodePath

var _points: Array[Vector2] = []  # Posições globais dos pontos (lidas uma vez).
var _index: int = 0  # Ponto de destino atual.
var _step: int = 1  # Sentido da rota (+1 ida, -1 volta).
var _go_to_current: bool = false  # True no primeiro trecho: vai ao ponto atual sem avançar.
var _graph: MazeGraph = null  # Mapa de corredores da fase (null = anda em linha reta como o original).


## Lê os pontos da rota (os Marker2D já estão posicionados na cena) e acha o mapa de corredores.
func _on_enemy_setup() -> void:
	_graph = get_tree().get_first_node_in_group(MazeGraph.GROUP) as MazeGraph
	var route: Node = get_node_or_null(route_path)
	if route == null:
		push_warning("%s: rota '%s' não encontrada; patrulha normal." % [name, route_path])
		return
	for child: Node in route.get_children():
		var marker := child as Marker2D
		if marker != null:
			_points.append(marker.global_position)


## Ao entrar (nascer ou voltar da perseguição): o primeiro destino é o ponto mais próximo.
func _on_enter() -> void:
	super._on_enter()
	if _points.size() < 2:
		return
	var best: int = 0
	for i: int in _points.size():
		if _distance_to(_points[i]) < _distance_to(_points[best]):
			best = i
	_index = best
	_go_to_current = true


## Escolhe o próximo ponto da rota (ida e volta) em vez de sortear um destino.
func _begin_walk() -> void:
	if _points.size() < 2:
		super._begin_walk()  # Sem rota válida: vaga como o resto do jogo.
		return
	if _go_to_current:
		_go_to_current = false
	else:
		_index += _step
		if _index < 0 or _index >= _points.size():
			_step = -_step
			_index += 2 * _step
	_destination = _points[_index]
	_phase = Phase.WALK
	_leg_time_left = _estimate_leg_time()
	enemy.play_anim(animation)


## Caminhada: segue o caminho dos corredores até o ponto da rota (sem mapa, usa o desvio original).
func _update_walk(delta: float) -> void:
	if _graph == null or _points.size() < 2:
		super._update_walk(delta)
		return
	_leg_time_left -= delta
	var arrived: bool = enemy.global_position.distance_squared_to(_destination) <= arrive_distance * arrive_distance
	if arrived or _leg_time_left <= 0.0:
		_begin_rest(randf_range(rest_time_min, rest_time_max))
		return
	if enemy.consume_navigation_stuck():  # Travou de leve num canto: limpa o desvio e segue.
		enemy.reset_navigation()
	var step_point: Vector2 = _graph.next_step(enemy.global_position, _destination)
	enemy.navigate_towards(step_point, enemy.move_speed * speed_multiplier, delta)


## Tempo máximo do trajeto, contando o caminho pelos corredores (não a linha reta).
func _estimate_leg_time() -> float:
	if _graph == null:
		return super._estimate_leg_time()
	var speed: float = maxf(enemy.move_speed * speed_multiplier, 1.0)
	return _graph.path_length(enemy.global_position, _destination) / speed * LEG_TIME_FACTOR + LEG_TIME_SLACK


## Distância até `point`: pelos corredores quando há mapa, senão em linha reta.
func _distance_to(point: Vector2) -> float:
	if _graph != null:
		return _graph.path_length(enemy.global_position, point)
	return enemy.global_position.distance_to(point)
