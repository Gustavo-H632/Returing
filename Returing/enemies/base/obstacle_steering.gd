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
# Fração do deslocamento esperado abaixo da qual conta como travado.
const STUCK_PROGRESS_RATIO: float = 0.25
## Duração e ângulo (em relação ao objetivo) da saída forçada.
const ESCAPE_TIME: float = 0.6
const ESCAPE_ANGLE: float = PI * 0.55  # Ângulo da saída forçada em relação ao objetivo.
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

# Consulta de raio reaproveitada (evita criar uma por raio).
var _query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.new()
# Direções dos raios (círculo dividido em partes iguais).
var _dirs: PackedVector2Array = PackedVector2Array()
var _raw: PackedFloat32Array = PackedFloat32Array()  # Perigo bruto de cada raio.
var _danger: PackedFloat32Array = PackedFloat32Array()  # Perigo após vazar para os vizinhos.
var _angle_step: float = TAU / 16.0  # Ângulo entre dois raios vizinhos.

var _heading: Vector2 = Vector2.ZERO  # Rumo suavizado devolvido por steer().
var _target_dir: Vector2 = Vector2.ZERO  # Rumo escolhido na última varredura.
var _last_goal: Vector2 = Vector2.RIGHT  # Último objetivo recebido.
var _scan_left: float = 0.0  # Tempo até a próxima varredura.
var _scan_elapsed: float = 0.0  # Tempo desde a última varredura.
var _last_call_msec: int = -1000000  # Hora da última chamada de steer().

var _side: float = 1.0  # Lado comprometido: +1 ou -1 (sinal do cross com o objetivo).
var _committed: bool = false  # True se já escolheu um lado para contornar a parede.
var _free_time: float = 0.0  # Tempo seguido com o objetivo livre.

var _escape_dir: Vector2 = Vector2.ZERO  # Direção da saída forçada.
var _escape_left: float = 0.0  # Tempo restante da saída forçada.
var _stuck_flag: bool = false  # True quando o travamento foi detectado (lido uma vez).
var _progress_origin: Vector2 = Vector2.ZERO  # Onde o inimigo estava na última conferência de progresso.
var _progress_time: float = 0.0  # Tempo desde a última conferência.


## Prepara as 16 direções padrão dos raios.
func _init() -> void:
	_build_directions(16)


## Aplica a configuração do inimigo: máscara de colisão, quantidade de raios, alcance, raio do corpo e giro.
## Aplica a configuração.
func configure(mask: int, rays: int, probe: float, radius: float, interval: float,
		turn_deg: float, exclude_bodies: Array[RID]) -> void:
	probe_distance = maxf(probe, 1.0)  # Alcance nunca menor que 1 px.
	body_radius = maxf(radius, 0.0)  # Raio do corpo nunca negativo.
	update_interval = maxf(interval, 0.0)  # Intervalo nunca negativo.
	turn_rate_deg = maxf(turn_deg, 1.0)  # Giro nunca menor que 1 grau por segundo.
	_query.collision_mask = mask  # Só colide com as camadas de parede.
	_query.exclude = exclude_bodies  # O próprio inimigo não conta como parede.
	_build_directions(rays)  # Recria a lista de direções.


## Reinicia tudo: rumo, compromisso de lado, tempos e detecção de travamento.
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
## Devolve true uma única vez depois que o travamento foi detectado (depois zera o aviso).
func consume_stuck() -> bool:
	var was_stuck: bool = _stuck_flag  # Guarda o valor.
	_stuck_flag = false  # Zera o aviso.
	return was_stuck


## Calcula a direção de movimento do inimigo rumo ao player. Avalia o caminho a cada intervalo e gira a direção aos poucos, para o movimento ficar suave.
## Também tem uma fuga para quando o inimigo trava: se andar muito menos que o esperado, vai para o lado mais livre por um instante.
## Rumo (vetor unitário) para andar em direção a `desired`, contornando paredes.
func steer(space: PhysicsDirectSpaceState2D, origin: Vector2, desired: Vector2,
		speed: float, delta: float) -> Vector2:
	var now: int = Time.get_ticks_msec()  # Hora atual em milissegundos.
	if now - _last_call_msec > IDLE_RESET_MSEC:  # Faz tempo que ninguém chama: estado velho, recomeça.
		reset(origin)
	_last_call_msec = now
	_last_goal = desired  # Guarda o objetivo (a fuga usa).
	_track_progress(origin, speed, delta)  # Confere se o inimigo está saindo do lugar.

	var goal: Vector2 = desired  # Objetivo do quadro: o desejado ou, na fuga, a direção forçada.
	if _escape_left > 0.0:  # Fuga em andamento.
		_escape_left -= delta  # Desconta o tempo da fuga.
		goal = _escape_dir

	_scan_left -= delta  # Conta o tempo até a próxima varredura.
	_scan_elapsed += delta  # Acumula o tempo desde a última.
	if _scan_left <= 0.0 or _heading == Vector2.ZERO:  # Hora de varrer (ou ainda não há rumo).
		_scan_left = update_interval
		_target_dir = _choose_direction(space, origin, goal, _scan_elapsed)  # Escolhe o melhor rumo agora.
		_scan_elapsed = 0.0
		if _heading == Vector2.ZERO:  # Primeira vez: começa já no rumo escolhido.
			_heading = _target_dir

	var max_step: float = deg_to_rad(turn_rate_deg) * delta  # Quanto o rumo pode girar neste quadro.
	# Gira o rumo aos poucos até o rumo desejado (movimento suave).
	_heading = _heading.rotated(clampf(_heading.angle_to(_target_dir), -max_step, max_step))
	return _heading  # Devolve o rumo atual.


## Encurta o trajeto na primeira parede.
## Encurta um trajeto no primeiro obstáculo (deixa uma folga), para o destino nunca ficar dentro da parede.
func trim_segment(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2) -> Vector2:
	_query.from = from  # Início do raio.
	_query.to = to  # Fim do raio.
	var hit: Dictionary = space.intersect_ray(_query)  # Procura parede no caminho.
	if hit.is_empty():  # Livre: mantém o destino.
		return to
	var length: float = from.distance_to(hit["position"] as Vector2)  # Distância até a parede.
	# Para antes da parede (raio do corpo mais folga).
	var keep: float = maxf(length - (body_radius + TRIM_MARGIN), 0.0)
	return from + from.direction_to(to) * keep  # Novo destino.


## Desenha os raios (verde = livre, vermelho = parede) e o rumo atual.
## Desenha os raios (verde = livre, vermelho = parede) e o rumo atual, para depurar.
func draw_debug(canvas: Node2D, origin: Vector2) -> void:
	var from: Vector2 = canvas.to_local(origin)  # Origem em coordenadas locais do nó que desenha.
	var reach: float = body_radius + probe_distance  # Comprimento dos raios.
	for i: int in _dirs.size():  # Um traço por direção.
		# A cor vai do verde ao vermelho conforme o perigo.
		canvas.draw_line(from, from + _dirs[i] * reach, Color.GREEN.lerp(Color.RED, _danger[i]), 1.0)
	if _heading != Vector2.ZERO:  # Rumo atual em branco.
		canvas.draw_line(from, from + _heading * reach, Color.WHITE, 2.0)


# --- Escolha de direção ---

## Cria a lista de direções (círculo dividido em `count` partes, entre 4 e 64).
func _build_directions(count: int) -> void:
	var n: int = clampi(count, 4, 64)  # Limita a quantidade.
	_angle_step = TAU / float(n)  # Ângulo entre direções.
	_dirs.resize(n)  # Prepara os vetores.
	_raw.resize(n)  # Prepara o perigo bruto.
	_danger.resize(n)  # Prepara o perigo suavizado.
	for i: int in n:
		_dirs[i] = Vector2.from_angle(_angle_step * float(i))  # Direção i: ângulo vezes i.
		_raw[i] = 0.0
		_danger[i] = 0.0


## Lança raios em várias direções para medir onde há parede. Se o caminho até o player está livre, segue em frente.
## Se não, dá uma nota a cada direção (interesse no objetivo menos perigo) e escolhe a melhor, mantendo o lado escolhido para não ficar oscilando.
func _choose_direction(space: PhysicsDirectSpaceState2D, origin: Vector2, goal: Vector2,
		elapsed: float) -> Vector2:
	_scan_danger(space, origin)  # Mede o perigo em todas as direções.

	# Caminho livre na direção do objetivo.
	if _danger[_index_of(goal)] < FREE_EPSILON:  # O objetivo está livre?
		_free_time += elapsed  # Soma o tempo com caminho livre.
		if _free_time >= COMMIT_RELEASE_TIME:  # Livre por tempo suficiente: solta o lado.
			_committed = false
		return goal  # Segue em frente.
	_free_time = 0.0  # Havia parede: zera o tempo livre.

	# Entrou em desvio.
	if not _committed:  # Primeira vez em desvio: escolhe o lado mais livre.
		_side = _freer_side(goal)  # Lado com menos perigo.
		_committed = true  # Marca o compromisso.

	var best_index: int = 0  # Índice da melhor direção.
	var best_score: float = -INF  # Melhor nota (começa muito baixa).
	for i: int in _dirs.size():  # Dá uma nota para cada direção.
		var cross: float = goal.cross(_dirs[i])  # Produto vetorial: de que lado do objetivo a direção está.
		# Interesse: 1 se aponta para o objetivo, 0 se é contrária.
		var interest: float = _dirs[i].dot(goal) * 0.5 + 0.5
		# Nota: interesse menos perigo, mais um empurrão para o lado escolhido.
		var score: float = interest - DANGER_WEIGHT * _danger[i] + signf(cross) * _side * SIDE_BIAS
		if cross * _side < -SIDE_MIN_SIN:  # Direção do lado oposto: penalizada.
			score -= OPPOSITE_SIDE_PENALTY
		if score > best_score:  # Fica com a maior nota.
			best_score = score
			best_index = i
	return _dirs[best_index]  # Devolve a melhor direção.


## Lança os raios e preenche `_danger`.
## Lança um raio por direção e guarda o perigo de cada uma (0 = livre, 1 = parede encostada).
func _scan_danger(space: PhysicsDirectSpaceState2D, origin: Vector2) -> void:
	var count: int = _dirs.size()  # Quantidade de raios.
	var reach: float = body_radius + probe_distance  # Comprimento de cada raio.
	_query.from = origin  # Todos os raios partem da mesma origem.
	for i: int in count:
		_query.to = origin + _dirs[i] * reach  # Fim do raio nesta direção.
		var hit: Dictionary = space.intersect_ray(_query)  # Resultado do raio.
		var danger: float = 0.0  # Sem parede, sem perigo.
		if not hit.is_empty():  # Achou parede.
			var dist: float = origin.distance_to(hit["position"] as Vector2)  # Distância até ela.
			# Mais perto da parede, mais perigo (0 a 1).
			danger = clampf(1.0 - (dist - body_radius) / probe_distance, 0.0, 1.0)
		_raw[i] = danger  # Guarda o perigo bruto.
	# O perigo vaza para as direções vizinhas.
	for i: int in count:  # Passa o perigo para os vizinhos, para o inimigo não rasgar a quina da parede.
		# Maior perigo entre os dois vizinhos.
		var neighbors: float = maxf(_raw[posmod(i - 1, count)], _raw[posmod(i + 1, count)])
		# Perigo final: o próprio ou o do vizinho atenuado.
		_danger[i] = maxf(_raw[i], neighbors * NEIGHBOR_SPREAD)


## Índice da direção discreta mais próxima de `dir`.
## Converte uma direção no índice do raio mais próximo.
func _index_of(dir: Vector2) -> int:
	# Ângulo dividido pelo passo, arredondado e ajustado ao círculo.
	return posmod(roundi(dir.angle() / _angle_step), _dirs.size())


## Lado (+1/-1) com menos perigo acumulado em relação ao objetivo.
## Escolhe o lado (+1 ou -1) com menos perigo acumulado em relação ao objetivo.
func _freer_side(goal: Vector2) -> float:
	var positive: float = 0.0  # Perigo acumulado de um lado.
	var negative: float = 0.0  # Perigo acumulado do outro lado.
	for i: int in _dirs.size():  # Soma o perigo de cada lado.
		var cross: float = goal.cross(_dirs[i])
		if cross > 0.2:  # Direções de um lado do objetivo.
			positive += _danger[i]
		elif cross < -0.2:  # Direções do outro lado.
			negative += _danger[i]
	if absf(positive - negative) <= 0.05:  # Empate: mantém o lado atual.
		return _side
	return 1.0 if positive < negative else -1.0  # Escolhe o lado com menos perigo.


# --- Rede de segurança contra travamento ---

## Compara o deslocamento real com o esperado.
## Compara quanto o inimigo andou com quanto deveria ter andado; se andou muito menos, ele travou.
func _track_progress(origin: Vector2, speed: float, delta: float) -> void:
	_progress_time += delta  # Conta o tempo.
	if _progress_time < STUCK_CHECK_TIME:  # Ainda não é hora de conferir.
		return
	var moved: float = origin.distance_to(_progress_origin)  # Distância andada desde a última conferência.
	var expected: float = speed * _progress_time  # Distância esperada (velocidade vezes tempo).
	_progress_origin = origin  # Recomeça a contagem.
	_progress_time = 0.0  # Zera o tempo.
	if _escape_left > 0.0:  # Já em fuga: não conferir.
		return
	if moved < expected * STUCK_PROGRESS_RATIO:  # Andou menos que a fração mínima: travou.
		_begin_escape()  # Começa a fuga.


## Força alguns instantes de movimento lateral pelo lado mais livre.
## Força alguns instantes de movimento lateral pelo lado mais livre, para sair de um canto ou de outro inimigo.
func _begin_escape() -> void:
	_stuck_flag = true  # Avisa que travou (os estados de patrulha sorteiam outro destino).
	_side = _freer_side(_last_goal)  # Escolhe o lado mais livre.
	# Direção da fuga: o objetivo girado para o lado.
	_escape_dir = _last_goal.rotated(_side * ESCAPE_ANGLE)
	_escape_left = ESCAPE_TIME  # Duração da fuga.
	_scan_left = 0.0  # Varre de novo no próximo quadro.
