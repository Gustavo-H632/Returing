class_name DefenseLevel
extends Node2D
## Fase de defesa. O portal carrega por 30 s enquanto waves de inimigos ORIGINAIS do jogo (Drone, Atirador, Tank)
## tentam destruí-lo. Com o portal READY a fase NÃO acaba: o jogador precisa entrar nele. Portal sem vida ou
## jogador morto = game over (a HUD do projeto oferece "Tentar de novo").
##
## Waves (dados em `wave_table.tres`): wave 1 só Drones; wave 2 Drones + Atiradores; da 3 em diante os três tipos,
## crescendo a cada wave. Cada wave só começa quando todos os inimigos da anterior morreram. Posição de nascimento e
## ordem dos tipos são sorteadas; ninguém nasce perto do jogador nem dentro de parede.
##
## Saída: o jogador é sugado -> distorção de teletransporte -> diálogo do ser misterioso -> próxima cena (o quiz).

signal state_changed(new_state: int)  # O estado da fase mudou (valor do enum State).
signal wave_started(wave_number: int, counts: Dictionary)  # Uma wave foi anunciada (número e quantidades).
signal wave_cleared(wave_number: int)  # Todos os inimigos da wave morreram.

## Estados da fase.
enum State { DEFENDING, EXITING, GAME_OVER }
## Etapas da wave dentro de DEFENDING.
enum WavePhase { BREAK, ANNOUNCE, SPAWNING, FIGHTING }

# ===== BALANCEAMENTO (valores editáveis) =====
const START_DELAY: float = 1.5  # Pausa (s) antes da primeira wave.
const WAVE_BREAK: float = 3.0  # Pausa (s) entre o fim de uma wave e o aviso da próxima.
const ANNOUNCE_TIME: float = 1.8  # Tempo (s) do aviso na tela antes de nascer o primeiro inimigo.
const SPAWN_STAGGER: float = 0.35  # Intervalo (s) entre os inimigos de uma mesma wave.
const SPAWN_JITTER: float = 10.0  # Variação (px) da posição de nascimento.
const MIN_SPAWN_PLAYER_DISTANCE: float = 280.0  # Ninguém nasce mais perto do jogador que isso (px).
const PLAYER_AGGRO_RADIUS: float = 150.0  # Jogador a menos disso de um inimigo = "no caminho": vira o alvo dele.
const RETARGET_INTERVAL: float = 0.25  # De quanto em quanto tempo os inimigos reavaliam o alvo (s).
const GAME_OVER_DELAY: float = 1.2  # Pausa (s) entre a derrota e a tela de game over.
const EXIT_SUCK_TIME: float = 0.5  # Tempo (s) do jogador sendo sugado pelo portal.
const TELEPORT_TIME: float = 1.6  # Duração (s) da distorção de teletransporte.
const WALL_MASK: int = 1  # Camada física das paredes.
const INTRO_HINT: String = "Defenda o portal até ele carregar!"
const DENIED_HINT: String = "O portal ainda está carregando..."
const EXIT_LINES: PackedStringArray = ["Não esperava por essa...", "Mas agora estamos cada vez mais perto de Aegis."]

@export_file("*.tscn") var next_scene: String = "res://Scenes/Fase2/Fase2.tscn"  # Depois da defesa: o quiz.
@export var wave_table: DefenseWaveTable  # Quantidades por wave (wave_table.tres).

@export_group("Inimigos originais (as cenas do jogo)")
@export var drone_scene: PackedScene
@export var robo_scene: PackedScene  # O Atirador.
@export var tank_scene: PackedScene

@export_group("Nós da cena")
@export var player: Player
@export var portal: DefensePortal
@export var hud: DefenseHud
@export var spawn_points_root: Node2D  # Pai dos Marker2D de nascimento (nas escotilhas das bordas).
@export var wave_timer: Timer  # Pausa/aviso entre etapas da wave (uma vez por disparo).
@export var stagger_timer: Timer  # Solta os inimigos da wave um a um (repete).
@export var retarget_timer: Timer  # Reavalia o alvo dos inimigos (repete).

var state: State = State.DEFENDING
var wave_phase: WavePhase = WavePhase.BREAK
var wave_number: int = 0  # Wave atual (0 antes da primeira).

var _spawn_points: Array[Marker2D] = []  # Marker2D de nascimento (coletados uma vez).
var _queue: Array[PackedScene] = []  # Inimigos da wave que ainda vão nascer (já sorteados).
var _enemies: Array[EnemyBase] = []  # Inimigos vivos da wave.
var _fx: ScreenGlitch = null  # Efeitos de tela (criado na saída).


func _ready() -> void:
	if not _validate_references():
		return
	for child: Node in spawn_points_root.get_children():
		if child is Marker2D:
			_spawn_points.append(child as Marker2D)
	portal.hp_changed.connect(hud.set_portal_hp)
	portal.charge_changed.connect(hud.set_charge)
	portal.became_ready.connect(_on_portal_ready)
	portal.destroyed.connect(_on_portal_destroyed)
	portal.entered.connect(_on_portal_entered)
	portal.entry_denied.connect(_on_entry_denied)
	hud.set_portal_hp(portal.hp, DefensePortal.MAX_HP)
	hud.set_charge(portal.charge)
	hud.set_wave(0)
	hud.show_hint(INTRO_HINT)

	wave_timer.one_shot = true
	wave_timer.timeout.connect(_on_wave_timer)
	stagger_timer.one_shot = false
	stagger_timer.wait_time = SPAWN_STAGGER
	stagger_timer.timeout.connect(_spawn_next)
	retarget_timer.one_shot = false
	retarget_timer.wait_time = RETARGET_INTERVAL
	retarget_timer.timeout.connect(_retarget_enemies)

	CombatUtils.connect_once(EventBus.player_died, _on_player_died)
	EventBus.level_started.emit()
	wave_phase = WavePhase.BREAK
	wave_timer.start(START_DELAY)
	retarget_timer.start()


func _exit_tree() -> void:
	CombatUtils.disconnect_if_connected(EventBus.player_died, _on_player_died)


## Inimigos vivos agora.
func alive_count() -> int:
	return _enemies.size()


## Pontos de nascimento válidos AGORA: longe do jogador (e o mais distante, se todos estiverem perto).
func valid_spawn_points() -> Array[Marker2D]:
	var result: Array[Marker2D] = []
	var farthest: Marker2D = null
	var farthest_d2: float = -1.0
	var min_d2: float = MIN_SPAWN_PLAYER_DISTANCE * MIN_SPAWN_PLAYER_DISTANCE
	for point: Marker2D in _spawn_points:
		var d2: float = point.global_position.distance_squared_to(player.global_position)
		if d2 >= min_d2:
			result.append(point)
		if d2 > farthest_d2:
			farthest_d2 = d2
			farthest = point
	if result.is_empty() and farthest != null:
		result.append(farthest)
	return result


## True se o ponto está livre de parede (consulta de física).
func is_point_free(point: Vector2) -> bool:
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = WALL_MASK
	return get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()


# --- Waves ---

## Etapas da wave por um único Timer: pausa -> aviso -> nascimento (stagger_timer) -> luta -> pausa...
func _on_wave_timer() -> void:
	if state != State.DEFENDING:
		return
	match wave_phase:
		WavePhase.BREAK:
			_announce_wave()
		WavePhase.ANNOUNCE:
			wave_phase = WavePhase.SPAWNING
			_spawn_next()
			if not _queue.is_empty():
				stagger_timer.start()


## Sorteia a mistura da wave, mostra o aviso e espera o tempo dele.
func _announce_wave() -> void:
	wave_number += 1
	var counts: Dictionary = wave_table.get_counts(wave_number)
	_queue.clear()
	for kind: Variant in counts:
		var scene: PackedScene = _scene_for(String(kind))
		for i: int in int(counts[kind]):
			_queue.append(scene)
	_queue.shuffle()  # Ordem dos tipos sorteada.
	wave_phase = WavePhase.ANNOUNCE
	hud.show_wave_banner(wave_number, counts)
	hud.set_wave(wave_number, _queue.size())
	wave_started.emit(wave_number, counts)
	wave_timer.start(ANNOUNCE_TIME)


## Solta o próximo inimigo da fila (espera se já há `max_active` vivos).
func _spawn_next() -> void:
	if state != State.DEFENDING or _queue.is_empty():
		stagger_timer.stop()
		return
	if _enemies.size() >= wave_table.max_active:
		return
	var scene: PackedScene = _queue.pop_back()
	var points: Array[Marker2D] = valid_spawn_points()
	var point: Marker2D = points[randi() % points.size()]
	var jitter: Vector2 = Vector2(randf_range(-SPAWN_JITTER, SPAWN_JITTER), randf_range(-SPAWN_JITTER, SPAWN_JITTER))
	var enemy: EnemyBase = scene.instantiate() as EnemyBase
	if enemy == null:
		push_error("DefenseLevel: a cena do inimigo não herda de EnemyBase.")
		return
	enemy.position = point.global_position + jitter
	add_child(enemy)
	enemy.target = portal
	enemy.died.connect(_on_enemy_died)
	CombatUtils.connect_once(enemy.tree_exited, _on_enemy_gone.bind(enemy))
	_enemies.append(enemy)
	hud.set_wave(wave_number, _enemies.size() + _queue.size())
	if _queue.is_empty():
		stagger_timer.stop()
		wave_phase = WavePhase.FIGHTING
		_check_wave_cleared()


func _on_enemy_died(enemy: EnemyBase) -> void:
	_forget(enemy)


## O inimigo saiu da árvore sem passar por died (rede de segurança).
func _on_enemy_gone(enemy: EnemyBase) -> void:
	_forget(enemy)


func _forget(enemy: EnemyBase) -> void:
	var index: int = _enemies.find(enemy)
	if index == -1:
		return
	_enemies.remove_at(index)
	hud.set_wave(wave_number, _enemies.size() + _queue.size())
	_check_wave_cleared()


## Wave acabou: nada na fila e nenhum inimigo vivo.
func _check_wave_cleared() -> void:
	if not is_inside_tree() or state != State.DEFENDING or wave_phase != WavePhase.FIGHTING 			or not _enemies.is_empty() or not _queue.is_empty():
		return
	wave_phase = WavePhase.BREAK
	wave_cleared.emit(wave_number)
	wave_timer.start(WAVE_BREAK)


## Por Timer: o inimigo ataca o portal, mas o jogador "no caminho" vira o alvo.
func _retarget_enemies() -> void:
	if state != State.DEFENDING:
		return
	var player_ok: bool = CombatUtils.is_targetable(player)
	var aggro_d2: float = PLAYER_AGGRO_RADIUS * PLAYER_AGGRO_RADIUS
	for enemy: EnemyBase in _enemies:
		if not CombatUtils.is_valid(enemy) or enemy.is_dead():
			continue
		var wanted: Node2D = portal
		if player_ok and enemy.global_position.distance_squared_to(player.global_position) <= aggro_d2:
			wanted = player
		if enemy.target != wanted:
			enemy.target = wanted


func _scene_for(kind: String) -> PackedScene:
	match kind:
		"drone":
			return drone_scene
		"robo":
			return robo_scene
		"tank":
			return tank_scene
	push_error("DefenseLevel: tipo de inimigo desconhecido na tabela: '%s'." % kind)
	return drone_scene


# --- Portal e jogador ---

func _on_portal_ready() -> void:
	hud.set_ready()


func _on_entry_denied() -> void:
	hud.show_hint(DENIED_HINT, 2.0)


func _on_portal_destroyed() -> void:
	_game_over()


func _on_player_died() -> void:
	_game_over()


## Derrota: para as waves, congela os inimigos e (depois de uma pausa) mostra o game over.
func _game_over() -> void:
	if state != State.DEFENDING:
		return
	_set_state(State.GAME_OVER)
	_stop_waves()
	portal.halt()
	for enemy: EnemyBase in _enemies:
		if CombatUtils.is_valid(enemy):
			enemy.drop_target()
			enemy.set_physics_process(false)
	var timer: SceneTreeTimer = CombatUtils.game_timer(self, GAME_OVER_DELAY)
	if timer != null:
		timer.timeout.connect(_emit_game_over)


func _emit_game_over() -> void:
	if state == State.GAME_OVER:
		EventBus.game_over.emit()


## O jogador entrou no portal READY (adiado: veio de um callback de física).
func _on_portal_entered() -> void:
	_begin_exit.call_deferred()


## Saída: remove os inimigos, suga o jogador, distorce a tela, mostra o diálogo e troca de cena.
func _begin_exit() -> void:
	if state != State.DEFENDING:
		return
	_set_state(State.EXITING)
	_stop_waves()
	for enemy: EnemyBase in _enemies:
		if CombatUtils.is_valid(enemy):
			enemy.queue_free()
	_enemies.clear()
	RunStats.registrar_fim_de_fase()  # Mesmo registro de tempo que o level_completed faria.
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	var project_hud: CanvasLayer = get_node_or_null("HUD") as CanvasLayer
	if project_hud != null:
		project_hud.visible = false
	var pause_menu: Node = get_node_or_null("Pause")  # ESC (segurar) pula o diálogo: a pausa não pode abrir junto.
	if pause_menu != null:
		pause_menu.process_mode = Node.PROCESS_MODE_DISABLED
	hud.visible = false

	var suck: Tween = create_tween().set_parallel(true)
	suck.tween_property(player, "global_position", portal.global_position, EXIT_SUCK_TIME)
	suck.tween_property(player, "scale", player.scale * 0.05, EXIT_SUCK_TIME)
	await suck.finished

	_fx = ScreenGlitch.new()
	add_child(_fx)
	await _fx.teleport(_portal_screen_uv(), TELEPORT_TIME)
	await _fx.cover(1.0, 0.2)
	_fx.hide_effects()
	# Estilo do tutorial: tela preta (a cortina fica) e as falas em azul, sem caixa nem ilustração.
	var dialogue: Dialogue = Dialogue.show_lines(self, EXIT_LINES, Dialogue.Style.VOICE)
	await dialogue.finished
	EventBus.scene_change_requested.emit(next_scene)


## Posição do portal na tela (0..1), para centrar a distorção.
func _portal_screen_uv() -> Vector2:
	var viewport: Viewport = get_viewport()
	var on_screen: Vector2 = viewport.get_canvas_transform() * portal.global_position
	var size: Vector2 = viewport.get_visible_rect().size
	return Vector2(on_screen.x / size.x, on_screen.y / size.y)


func _stop_waves() -> void:
	wave_timer.stop()
	stagger_timer.stop()
	retarget_timer.stop()
	_queue.clear()


func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(int(new_state))


func _validate_references() -> bool:
	var missing: PackedStringArray = []
	if wave_table == null: missing.append("wave_table")
	if drone_scene == null: missing.append("drone_scene")
	if robo_scene == null: missing.append("robo_scene")
	if tank_scene == null: missing.append("tank_scene")
	if player == null: missing.append("player")
	if portal == null: missing.append("portal")
	if hud == null: missing.append("hud")
	if spawn_points_root == null: missing.append("spawn_points_root")
	if wave_timer == null: missing.append("wave_timer")
	if stagger_timer == null: missing.append("stagger_timer")
	if retarget_timer == null: missing.append("retarget_timer")
	if missing.is_empty():
		return true
	push_error("DefenseLevel: referências não atribuídas no Inspector: %s" % ", ".join(missing))
	return false
