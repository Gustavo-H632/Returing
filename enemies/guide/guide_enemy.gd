class_name GuideEnemy
extends EnemyBase
## Chefão "Guide": 1000 HP, 2 fases. Persegue o player sem parar e ataca na direção dele.

## Emitido ao entrar numa nova fase.
signal phase_changed(phase: Phase)
## Emitido uma única vez, quando o chefão morre.
signal defeated(boss: GuideEnemy)

enum Phase { ONE, TWO }

## Nomes dos nós de estado da StateMachine (um por ataque).
const STATE_CHASE: StringName = &"Chase"
const STATE_TRANSITION: StringName = &"Transition"
const ATTACK_CIRCLES: StringName = &"AttackCircles"
const ATTACK_SHOTS: StringName = &"AttackShots"
const ATTACK_LASER: StringName = &"AttackLaser"
const ATTACK_SLASH: StringName = &"AttackSlash"
## Ataques sorteados à distância (o golpe de espada só entra por proximidade).
const RANGED_ATTACKS: Array[StringName] = [ATTACK_CIRCLES, ATTACK_SHOTS, ATTACK_LASER]
## Sentidos em que o raio pode varrer a sala.
const SWEEP_DIRECTIONS: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
## Tentativas máximas de sortear um ataque diferente do anterior (parada da recursão).
const MAX_PICK_DEPTH: int = 4
## Fração do raio do golpe de espada em que o chefão já considera o player ao alcance.
const SLASH_TRIGGER_FACTOR: float = 1.1
## Cores do corpo: normal, invulnerável (transição) e enfurecido (fase 2).
const TINT_NORMAL: Color = Color(1.0, 1.0, 1.0, 1.0)
const TINT_INVULNERABLE: Color = Color(0.5, 0.9, 1.0, 0.55)
const TINT_PHASE_TWO: Color = Color(1.0, 0.55, 0.55, 1.0)
## Folga (px) ao empurrar o player para fora da gaiola.
const EJECT_MARGIN: float = 24.0
## Espessura das paredes se a cena não gravar outra.
const DEFAULT_WALL_THICKNESS: float = 32.0

@export_group("Fases")
## Fração da vida em que a fase 1 termina e começa a transição.
@export_range(0.05, 0.95, 0.05) var phase_two_health_ratio: float = 0.5
## Multiplicador do dano recebido (1.0 = dano cheio).
@export_range(0.1, 2.0, 0.05) var damage_taken_multiplier: float = 1.0

@export_group("Movimento")
## Cena do Tank: o Guide anda na mesma velocidade que ele.
@export var speed_reference_scene: PackedScene
## Distância em que o chefão para de se aproximar.
@export_range(0.0, 300.0, 1.0, "or_greater") var chase_stop_distance: float = 60.0

@export_group("Ritmo dos ataques (F1 / F2)")
## Pausa entre o fim de um ataque e o seguinte (segundos).
@export var attack_interval: Vector2 = Vector2(2.0, 1.4)

@export_group("1. Círculos de aviso (F1 / F2)")
## Quantidade de círculos por ataque.
@export var circle_counts: Vector2i = Vector2i(6, 9)
@export_range(8.0, 200.0, 1.0) var circle_radius: float = 56.0
## Tempo vermelho até ficar amarelo e causar dano.
@export_range(0.1, 5.0, 0.1) var circle_warning_time: float = 2.0
## Tempo que o círculo amarelo causa dano.
@export_range(0.05, 2.0, 0.05) var circle_active_time: float = 0.3
@export var circle_damage: int = 20
## Intervalo entre um círculo e o seguinte.
@export_range(0.05, 2.0, 0.01) var circle_spawn_interval: float = 0.18
## Os círculos nascem espalhados neste raio em volta do player (o 1º cai nele).
@export_range(0.0, 600.0, 1.0, "or_greater") var circle_scatter_radius: float = 150.0

@export_group("2. Tiros no player (F1 / F2)")
## Quantidade de tiros por ataque.
@export var shot_counts: Vector2i = Vector2i(3, 5)
## Largura do tiro = este fator x a largura do tiro do player.
@export_range(1.0, 10.0, 0.5) var shot_width_multiplier: float = 5.0
@export var shot_damage: int = 15
@export var shot_speed: float = 260.0
@export_range(0.05, 3.0, 0.05) var shot_interval: float = 0.35
@export_range(0.5, 10.0, 0.1) var shot_lifetime: float = 4.0
@export_group("6. Divisão dos tiros (fase 2)")
## Segundos até o tiro principal se dividir em 8.
@export_range(0.1, 5.0, 0.1) var split_delay: float = 0.9
@export var split_shot_damage: int = 8
@export var split_shot_speed: float = 220.0
@export_range(0.5, 10.0, 0.1) var split_shot_lifetime: float = 3.0

@export_group("3. Raio que cruza a sala (F1 / F2)")
## Quantidade de raios por ataque.
@export var laser_counts: Vector2i = Vector2i(1, 3)
## Distância entre um raio e o seguinte.
@export_range(40.0, 600.0, 1.0, "or_greater") var laser_spacing: float = 280.0
@export var laser_speed: float = 520.0
## Aviso antes de o primeiro raio sair.
@export_range(0.2, 5.0, 0.1) var laser_warning_time: float = 1.0
@export var laser_damage: int = 30

@export_group("4. Golpe de espada em área")
## Raio do golpe = este fator x o raio da hitbox da espada do player.
@export_range(1.0, 10.0, 0.5) var slash_radius_multiplier: float = 3.0
@export var slash_damage: int = 25
@export_range(0.1, 3.0, 0.05) var slash_windup_time: float = 0.6
@export_range(0.05, 1.0, 0.05) var slash_active_time: float = 0.15
@export_range(0.0, 10.0, 0.1) var slash_cooldown: float = 4.0

@export_group("5. Transição de fase")
## Velocidade com que o chefão volta para o meio da sala antes de levantar as paredes.
@export_range(50.0, 1000.0, 10.0, "or_greater") var transition_return_speed: float = 320.0
## Cena das paredes que prendem o chefão durante a transição.
@export var walls_scene: PackedScene
## Metade do lado da gaiola em volta do chefão.
@export var cage_half_size: Vector2 = Vector2(120.0, 120.0)
## Tempo máximo esperando a wave (se estourar, a fase 2 começa mesmo assim).
@export_range(5.0, 600.0, 1.0, "or_greater") var transition_wave_timeout: float = 180.0

@export_group("Arena")
## Retângulo da sala em coordenadas de mundo (limita círculos e raios).
@export var arena_rect: Rect2 = Rect2(65.0, 75.0, 1028.0, 521.0)

@export_group("Visual")
## Nó que recebe a cor do corpo (normal, invulnerável, fase 2); as animações mexem só no sprite.
@export var body_visual: CanvasItem

@export_group("Pools (já ligados na cena)")
@export var circle_pool: ObjectPool
@export var shot_pool: ObjectPool
@export var laser_pool: ObjectPool
@export var slash_pool: ObjectPool

var phase: Phase = Phase.ONE

var _invulnerable: bool = false
var _phase_two_health: int = 0
var _attack_cooldown_left: float = 0.0
var _slash_cooldown_left: float = 0.0
var _last_attack: StringName = &""
var _walls: GuideWalls = null
var _shot_specs: Array[GuideShotSpec] = []


func _on_enemy_ready() -> void:
	move_speed = float(CombatUtils.get_scene_root_property(speed_reference_scene, &"move_speed", move_speed))
	_phase_two_health = roundi(float(health.max_health) * phase_two_health_ratio) if health != null else 0
	_build_shot_specs()
	_validate_attack_references()
	_apply_tint()
	_acquire_target()


func _validate_attack_references() -> void:
	var missing: PackedStringArray = []
	if circle_pool == null: missing.append("circle_pool")
	if shot_pool == null: missing.append("shot_pool")
	if laser_pool == null: missing.append("laser_pool")
	if slash_pool == null: missing.append("slash_pool")
	if walls_scene == null: missing.append("walls_scene")
	if not missing.is_empty():
		push_warning("GuideEnemy '%s': referências não atribuídas: %s" % [name, ", ".join(missing)])


## Desconta as recargas dos ataques.
func _physics_process(delta: float) -> void:
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	_slash_cooldown_left = maxf(_slash_cooldown_left - delta, 0.0)


# --- Alvo (o chefão sempre sabe onde o player está) ---

## Sem alvo (ex.: o player acabou de nascer), procura o Player em vez de esperar a detecção.
func has_target() -> bool:
	if not super.has_target():
		_acquire_target()
	return super.has_target()


## O Guide nunca perde o player de vista.
func _on_detection_body_exited(_body: Node2D) -> void:
	pass


func _acquire_target() -> void:
	target = CombatUtils.get_player(self)


## Persegue o player contornando paredes (para a `chase_stop_distance` dele).
func chase_target(delta: float) -> void:
	if not has_target():
		brake(delta)
		return
	if distance_sq_to_target() <= chase_stop_distance * chase_stop_distance:
		brake(delta)
		face_target()
		return
	navigate_towards(target.global_position, move_speed, delta)


# --- Fase, vida e dano ---

func get_phase() -> Phase:
	return phase


func is_phase_two() -> bool:
	return phase == Phase.TWO


func is_invulnerable() -> bool:
	return _invulnerable


## Liga/desliga a invulnerabilidade (transição de fase).
func set_invulnerable(value: bool) -> void:
	_invulnerable = value
	_apply_tint()


## Cálculo de dano: recusa se invulnerável, aplica o multiplicador e, na fase 1, nunca passa do
## limite da transição (o excedente é descartado para a fase 2 sempre acontecer).
func take_damage(amount: int, source: Variant = null) -> bool:
	if _dead or _invulnerable or health == null:
		return false
	var applied: int = _calculate_damage(amount)
	if applied <= 0:
		return false
	if health.take_damage(applied, source) <= 0:
		return false
	if phase == Phase.ONE and not health.is_dead() and health.current_health <= _phase_two_health:
		_begin_transition()
	return true


## Dano efetivo de um golpe de `amount`.
func _calculate_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	var scaled: int = maxi(roundi(float(amount) * damage_taken_multiplier), 1)
	if phase == Phase.ONE:
		return mini(scaled, health.current_health - _phase_two_health)
	return scaled


## Fica invulnerável já e entra no estado de transição no fim do frame (o dano chega num
## callback de física, onde não se mexe em colisões).
func _begin_transition() -> void:
	set_invulnerable(true)
	if state_machine != null:
		state_machine.transition_to.call_deferred(STATE_TRANSITION)


## Chamado pelo estado Transition ao entrar: limpa os ataques e para o chefão.
func on_transition_started() -> void:
	release_attacks()
	velocity = Vector2.ZERO


## Anda até o meio da sala (invulnerável, sem atacar). Devolve true quando chegou.
func return_to_center(delta: float) -> bool:
	var center: Vector2 = arena_rect.get_center()
	if global_position.distance_to(center) <= transition_return_speed * delta:
		global_position = center
		velocity = Vector2.ZERO
		return true
	move_towards(center, transition_return_speed)
	return false


## Chegou ao meio da sala: levanta as paredes em volta dele e pede a wave.
func on_center_reached() -> void:
	_spawn_walls()
	EventBus.boss_transition_started.emit(enemy_kind, global_position, _get_cage_clear_radius())


## Chamado pelo estado Transition ao terminar: remove as paredes e inicia a fase 2.
func on_transition_finished() -> void:
	_remove_walls()
	phase = Phase.TWO
	set_invulnerable(false)
	_attack_cooldown_left = _by_phase(attack_interval)
	phase_changed.emit(phase)
	EventBus.boss_phase_changed.emit(enemy_kind, phase + 1)


## Morte: avisa por sinal, libera ataques e paredes.
func _on_death() -> void:
	_invulnerable = false
	_remove_walls()
	release_attacks()
	defeated.emit(self)
	EventBus.boss_defeated.emit(enemy_kind)


## Devolve ao pool todos os ataques em campo.
func release_attacks() -> void:
	for pool: ObjectPool in [circle_pool, shot_pool, laser_pool, slash_pool]:
		if pool != null:
			pool.release_all()


# --- Escolha dos ataques ---

func attack_ready() -> bool:
	return _attack_cooldown_left <= 0.0


func start_attack_cooldown() -> void:
	_attack_cooldown_left = _by_phase(attack_interval)


## O player está dentro do alcance do golpe de espada e o golpe está carregado.
func can_slash() -> bool:
	if _slash_cooldown_left > 0.0 or not has_target():
		return false
	var reach: float = get_slash_radius() * SLASH_TRIGGER_FACTOR
	return distance_sq_to_target() <= reach * reach


## Sorteia o próximo ataque à distância, evitando repetir o anterior.
func pick_attack() -> StringName:
	_last_attack = _pick_attack_avoiding(_last_attack, 0)
	return _last_attack


## Recursão do sorteio: tenta de novo se repetiu o anterior, até MAX_PICK_DEPTH tentativas.
func _pick_attack_avoiding(previous: StringName, depth: int) -> StringName:
	var candidate: StringName = RANGED_ATTACKS[randi() % RANGED_ATTACKS.size()]
	if candidate == previous and depth < MAX_PICK_DEPTH:
		return _pick_attack_avoiding(previous, depth + 1)
	return candidate


# --- Ataque 1: círculos de aviso ---

func get_circle_count() -> int:
	return _by_phase_i(circle_counts)


## Cria o círculo `index` da rajada: o primeiro cai no player, os outros em volta dele.
func spawn_circle(index: int) -> void:
	var circle := _acquire(circle_pool) as WarningCircle
	if circle == null:
		return
	var center: Vector2 = _get_target_position()
	if index > 0:
		center += Vector2.from_angle(randf() * TAU) * randf_range(0.0, circle_scatter_radius)
	center = center.clamp(arena_rect.position + Vector2.ONE * circle_radius,
			arena_rect.end - Vector2.ONE * circle_radius)
	circle.launch(center, circle_radius, circle_warning_time, circle_active_time, circle_damage, self)


# --- Ataques 2 e 6: tiros no player (e divisão na fase 2) ---

func get_shot_count() -> int:
	return _by_phase_i(shot_counts)


## Atira um tiro principal na direção do player.
func fire_shot() -> void:
	var shot := _acquire(shot_pool) as GuideShot
	if shot == null:
		return
	var direction: Vector2 = global_position.direction_to(_get_target_position())
	shot.launch(global_position, direction, _shot_specs[phase], 0, self)


## Receitas dos tiros por fase: a fase 2 encadeia o filho (tiros do tamanho do tiro do player).
func _build_shot_specs() -> void:
	var main := GuideShotSpec.new()
	main.radius = PlayerProjectile.BASE_RADIUS * shot_width_multiplier
	main.speed = shot_speed
	main.damage = shot_damage
	main.lifetime = shot_lifetime
	var split := GuideShotSpec.new()
	split.radius = PlayerProjectile.BASE_RADIUS
	split.speed = split_shot_speed
	split.damage = split_shot_damage
	split.lifetime = split_shot_lifetime
	var main_phase_two := GuideShotSpec.new()
	main_phase_two.radius = main.radius
	main_phase_two.speed = main.speed
	main_phase_two.damage = main.damage
	main_phase_two.lifetime = main.lifetime
	main_phase_two.split_delay = split_delay
	main_phase_two.child = split
	_shot_specs = [main, main_phase_two]


# --- Ataque 3: raio que cruza a sala ---

## Solta os raios da fase (varrendo a sala numa direção sorteada). Devolve a duração total.
func spawn_lasers() -> float:
	var count: int = _by_phase_i(laser_counts)
	var thickness: float = PlayerProjectile.BASE_RADIUS * 2.0
	var sweep: Vector2 = SWEEP_DIRECTIONS[randi() % SWEEP_DIRECTIONS.size()]
	var horizontal: bool = sweep.x != 0.0
	# Comprimento e percurso: o raio cobre a sala na perpendicular e a atravessa na direção do giro.
	var length: float = (arena_rect.size.y if horizontal else arena_rect.size.x) + thickness * 2.0
	var travel: float = arena_rect.size.x if horizontal else arena_rect.size.y
	var center: Vector2 = arena_rect.get_center()
	var start: Vector2 = center - sweep * travel * 0.5
	var gap_time: float = laser_spacing / maxf(laser_speed, 1.0)
	for i: int in count:
		var laser := _acquire(laser_pool) as GuideLaser
		if laser == null:
			break
		laser.launch(start, sweep, length, thickness, laser_speed, travel,
				laser_warning_time + float(i) * gap_time, laser_damage, self)
	return laser_warning_time + float(maxi(count - 1, 0)) * gap_time + travel / maxf(laser_speed, 1.0)


# --- Ataque 4: golpe de espada em área ---

## Raio do golpe: 3x a hitbox da espada do player.
func get_slash_radius() -> float:
	return Sword.HITBOX_RADIUS * slash_radius_multiplier


## Faz o golpe ao redor do chefão. Devolve a duração total.
func spawn_slash() -> float:
	_slash_cooldown_left = slash_cooldown
	var slash := _acquire(slash_pool) as GuideSlash
	if slash == null:
		return 0.0
	slash.launch(self, get_slash_radius(), slash_windup_time, slash_active_time, slash_damage, self)
	return slash.get_total_time()


# --- Transição: paredes ---

## Levanta a gaiola em volta do chefão e tira o player de dentro dela.
func _spawn_walls() -> void:
	_remove_walls()
	if walls_scene == null:
		return
	var walls := CombatUtils.spawn(walls_scene, self, global_position, GuideWalls) as GuideWalls
	if walls == null:
		return
	walls.half_size = cage_half_size
	_walls = walls
	_eject_player_from.call_deferred(walls)


func _remove_walls() -> void:
	if CombatUtils.is_valid(_walls):
		_walls.dismantle()
	_walls = null


## Raio que a wave precisa respeitar para não nascer dentro da gaiola.
func _get_cage_clear_radius() -> float:
	var thickness: float = float(CombatUtils.get_scene_root_property(walls_scene, &"thickness", DEFAULT_WALL_THICKNESS))
	return (cage_half_size + Vector2.ONE * thickness).length() + EJECT_MARGIN


## Se o player está dentro da gaiola, empurra para fora pelo lado mais próximo (dentro da sala).
func _eject_player_from(walls: GuideWalls) -> void:
	var player: Node2D = CombatUtils.get_player(self)
	if not CombatUtils.is_alive(walls) or player == null:
		return
	var outer: Rect2 = walls.get_outer_rect().grow(EJECT_MARGIN)
	if not outer.has_point(player.global_position):
		return
	var pos: Vector2 = player.global_position
	var exits: Array[Vector2] = [
		Vector2(outer.position.x, pos.y), Vector2(outer.end.x, pos.y),
		Vector2(pos.x, outer.position.y), Vector2(pos.x, outer.end.y),
	]
	var solid: Rect2 = outer.grow(-2.0)
	var best: Vector2 = arena_rect.get_center()
	var best_distance: float = INF
	for exit_point: Vector2 in exits:
		var clamped: Vector2 = exit_point.clamp(arena_rect.position, arena_rect.end)
		if solid.has_point(clamped):
			continue  # esse lado dá na parede da sala: continua dentro da gaiola
		var distance: float = pos.distance_squared_to(clamped)
		if distance < best_distance:
			best_distance = distance
			best = clamped
	player.global_position = best


# --- Auxiliares ---

func _acquire(pool: ObjectPool) -> PooledArea:
	return pool.acquire() if pool != null else null


## Posição do player (ou do próprio chefão se não houver player).
func _get_target_position() -> Vector2:
	return target.global_position if has_target() else global_position


## Valor da fase atual de um par (F1, F2).
func _by_phase(pair: Vector2) -> float:
	return pair.y if phase == Phase.TWO else pair.x


func _by_phase_i(pair: Vector2i) -> int:
	return pair.y if phase == Phase.TWO else pair.x


## Cor do corpo conforme a situação (normal, invulnerável, fase 2).
func _apply_tint() -> void:
	if body_visual == null:
		return
	if _invulnerable:
		body_visual.modulate = TINT_INVULNERABLE
	else:
		body_visual.modulate = TINT_PHASE_TWO if phase == Phase.TWO else TINT_NORMAL
