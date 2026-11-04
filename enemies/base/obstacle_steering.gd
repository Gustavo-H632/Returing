class_name ObstacleSteering
extends RefCounted
## Desvio de paredes por "context steering" com raycasts.

# --- Ajuste fino (valores calibrados por simulação) ---

## Peso do perigo contra o interesse no objetivo.
const DANGER_WEIGHT: float = 2.5
## Fração do perigo de uma direção que "vaza" para as vizinhas.
const NEIGHBOR_SPREAD: float = 0.6
## Desempate pequeno a favor do lado comprometido.
const SIDE_BIAS: float = 0.08
## Penalidade das direções do lado oposto ao comprometido.
const OPPOSITE_SIDE_PENALTY: float = 1.0
## Seno mínimo do ângulo para uma direção contar como "de um lado".
const SIDE_MIN_SIN: float = 0.15
## Perigo abaixo disto = direção livre.
const FREE_EPSILON: float = 0.001
## Tempo contínuo com o objetivo livre para soltar o compromisso de lado.
const COMMIT_RELEASE_TIME: float = 0.35
## De quanto em quanto tempo confere se o inimigo saiu do lugar.
const STUCK_CHECK_TIME: float = 0.2
const STUCK_PROGRESS_RATIO: float = 0.25
## Duração e ângulo (em relação ao objetivo) da saída forçada.
const ESCAPE_TIME: float = 0.6
const ESCAPE_ANGLE: float = PI * 0.55
## Sem chamadas de steer() por este tempo, o estado interno é reiniciado.
const IDLE_RESET_MSEC: int = 150
## Folga extra (px) deixada ao encurtar um trajeto no primeiro obstáculo.
const TRIM_MARGIN: float = 4.0

# --- Configuração (preenchida por configure()) ---

## Alcance dos raios, medido a partir da borda do corpo.
var probe_distance: float = 56.0
## Raio do corpo do inimigo.
var body_radius: float = 12.0
## Intervalo entre varreduras (0 = todo frame).
var update_interval: float = 0.05
## Velocidade máxima de giro do rumo, em graus por segundo.
var turn_rate_deg: float = 540.0

# --- Estado interno ---

var _query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.new()
var _dirs: PackedVector2Array = PackedVector2Array()
var _raw: PackedFloat32Array = PackedFloat32Array()  # Perigo bruto de cada raio.
var _danger: PackedFloat32Array = PackedFloat32Array()  # Perigo após vazar para os vizinhos.
var _angle_step: float = TAU / 16.0

var _heading: Vector2 = Vector2.ZERO  # Rumo suavizado devolvido por steer().
var _target_dir: Vector2 = Vector2.ZERO  # Rumo escolhido na última varredura.
var _last_goal: Vector2 = Vector2.RIGHT
var _scan_left: float = 0.0
var _scan_elapsed: float = 0.0
var _last_call_msec: int = -1000000

var _side: float = 1.0  # Lado comprometido: +1 ou -1 (sinal do cross com o objetivo).
var _committed: bool = false
var _free_time: float = 0.0

var _escape_dir: Vector2 = Vector2.ZERO
var _escape_left: float = 0.0
var _stuck_flag: bool = false
var _progress_origin: Vector2 = Vector2.ZERO
var _progress_time: float = 0.0


func _init() -> void:
	_build_directions(16)


## Aplica a configuração.
func configure(mask: int, rays: int, probe: float, radius: float, interval: float,
		turn_deg: float, exclude_bodies: Array[RID]) -> void:
	probe_distance = maxf(probe, 1.0)
	body_radius = maxf(radius, 0.0)
	update_interval = maxf(interval, 0.0)
	turn_rate_deg = maxf(turn_deg, 1.0)
	_query.collision_mask = mask
	_query.exclude = exclude_bodies
	_build_directions(rays)


## Zera o estado (rumo, compromisso de lado, detecção de travamento).
func reset(origin: Vector2 = Vector2.ZERO) -> void:
	_heading = Vector2.ZERO
	_target_dir = Vector2.ZERO
	_scan_left = 0.0
	_scan_elapsed = 0.0
	_committed = false
	_free_time = 0.0
	_escape_left = 0.0
	_stuck_flag = false
	_progress_origin = origin
	_progress_time = 0.0


## True uma única vez depois que o travamento foi detectado.
func consume_stuck() -> bool:
	var was_stuck: bool = _stuck_flag
	_stuck_flag = false
	return was_stuck


## Rumo (vetor unitário) para andar em direção a `desired`, contornando paredes.
func steer(space: PhysicsDirectSpaceState2D, origin: Vector2, desired: Vector2,
		speed: float, delta: float) -> Vector2:
	var now: int = Time.get_ticks_msec()
	if now - _last_call_msec > IDLE_RESET_MSEC:
		reset(origin)
	_last_call_msec = now
	_last_goal = desired
	_track_progress(origin, speed, delta)

	var goal: Vector2 = desired
	if _escape_left > 0.0:
		_escape_left -= delta
		goal = _escape_dir

	_scan_left -= delta
	_scan_elapsed += delta
	if _scan_left <= 0.0 or _heading == Vector2.ZERO:
		_scan_left = update_interval
		_target_dir = _choose_direction(space, origin, goal, _scan_elapsed)
		_scan_elapsed = 0.0
		if _heading == Vector2.ZERO:
			_heading = _target_dir

	var max_step: float = deg_to_rad(turn_rate_deg) * delta
	_heading = _heading.rotated(clampf(_heading.angle_to(_target_dir), -max_step, max_step))
	return _heading


## Encurta o trajeto na primeira parede.
func trim_segment(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2) -> Vector2:
	_query.from = from
	_query.to = to
	var hit: Dictionary = space.intersect_ray(_query)
	if hit.is_empty():
		return to
	var length: float = from.distance_to(hit["position"] as Vector2)
	var keep: float = maxf(length - (body_radius + TRIM_MARGIN), 0.0)
	return from + from.direction_to(to) * keep


## Desenha os raios (verde = livre, vermelho = parede) e o rumo atual.
func draw_debug(canvas: Node2D, origin: Vector2) -> void:
	var from: Vector2 = canvas.to_local(origin)
	var reach: float = body_radius + probe_distance
	for i: int in _dirs.size():
		canvas.draw_line(from, from + _dirs[i] * reach, Color.GREEN.lerp(Color.RED, _danger[i]), 1.0)
	if _heading != Vector2.ZERO:
		canvas.draw_line(from, from + _heading * reach, Color.WHITE, 2.0)


# --- Escolha de direção ---

func _build_directions(count: int) -> void:
	var n: int = clampi(count, 4, 64)
	_angle_step = TAU / float(n)
	_dirs.resize(n)
	_raw.resize(n)
	_danger.resize(n)
	for i: int in n:
		_dirs[i] = Vector2.from_angle(_angle_step * float(i))
		_raw[i] = 0.0
		_danger[i] = 0.0


func _choose_direction(space: PhysicsDirectSpaceState2D, origin: Vector2, goal: Vector2,
		elapsed: float) -> Vector2:
	_scan_danger(space, origin)

	# Caminho livre na direção do objetivo.
	if _danger[_index_of(goal)] < FREE_EPSILON:
		_free_time += elapsed
		if _free_time >= COMMIT_RELEASE_TIME:
			_committed = false
		return goal
	_free_time = 0.0

	# Entrou em desvio.
	if not _committed:
		_side = _freer_side(goal)
		_committed = true

	var best_index: int = 0
	var best_score: float = -INF
	for i: int in _dirs.size():
		var cross: float = goal.cross(_dirs[i])
		var interest: float = _dirs[i].dot(goal) * 0.5 + 0.5
		var score: float = interest - DANGER_WEIGHT * _danger[i] + signf(cross) * _side * SIDE_BIAS
		if cross * _side < -SIDE_MIN_SIN:
			score -= OPPOSITE_SIDE_PENALTY
		if score > best_score:
			best_score = score
			best_index = i
	return _dirs[best_index]


## Lança os raios e preenche `_danger`.
func _scan_danger(space: PhysicsDirectSpaceState2D, origin: Vector2) -> void:
	var count: int = _dirs.size()
	var reach: float = body_radius + probe_distance
	_query.from = origin
	for i: int in count:
		_query.to = origin + _dirs[i] * reach
		var hit: Dictionary = space.intersect_ray(_query)
		var danger: float = 0.0
		if not hit.is_empty():
			var dist: float = origin.distance_to(hit["position"] as Vector2)
			danger = clampf(1.0 - (dist - body_radius) / probe_distance, 0.0, 1.0)
		_raw[i] = danger
	# O perigo vaza para as direções vizinhas.
	for i: int in count:
		var neighbors: float = maxf(_raw[posmod(i - 1, count)], _raw[posmod(i + 1, count)])
		_danger[i] = maxf(_raw[i], neighbors * NEIGHBOR_SPREAD)


## Índice da direção discreta mais próxima de `dir`.
func _index_of(dir: Vector2) -> int:
	return posmod(roundi(dir.angle() / _angle_step), _dirs.size())


## Lado (+1/-1) com menos perigo acumulado em relação ao objetivo.
func _freer_side(goal: Vector2) -> float:
	var positive: float = 0.0
	var negative: float = 0.0
	for i: int in _dirs.size():
		var cross: float = goal.cross(_dirs[i])
		if cross > 0.2:
			positive += _danger[i]
		elif cross < -0.2:
			negative += _danger[i]
	if absf(positive - negative) <= 0.05:
		return _side
	return 1.0 if positive < negative else -1.0


# --- Rede de segurança contra travamento ---

## Compara o deslocamento real com o esperado.
func _track_progress(origin: Vector2, speed: float, delta: float) -> void:
	_progress_time += delta
	if _progress_time < STUCK_CHECK_TIME:
		return
	var moved: float = origin.distance_to(_progress_origin)
	var expected: float = speed * _progress_time
	_progress_origin = origin
	_progress_time = 0.0
	if _escape_left > 0.0:
		return
	if moved < expected * STUCK_PROGRESS_RATIO:
		_begin_escape()


## Força alguns instantes de movimento lateral pelo lado mais livre.
func _begin_escape() -> void:
	_stuck_flag = true
	_side = _freer_side(_last_goal)
	_escape_dir = _last_goal.rotated(_side * ESCAPE_ANGLE)
	_escape_left = ESCAPE_TIME
	_scan_left = 0.0
