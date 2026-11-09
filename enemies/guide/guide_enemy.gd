class_name GuideEnemy
extends EnemyBase
## Chefão "Guide": 1000 HP, 2 fases. Persegue o player sem parar e ataca na direção dele.

## Emitido ao entrar numa nova fase.
signal phase_changed(phase: Phase)
## Emitido uma única vez, quando o chefão morre.
signal defeated(boss: GuideEnemy)

enum Phase { ONE, TWO }  # Fases do chefão: a primeira e a enfurecida.

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

var phase: Phase = Phase.ONE  # Fase atual.

var _invulnerable: bool = false  # True durante a transição (não recebe dano).
var _phase_two_health: int = 0  # Vida em que a fase 1 termina.
var _attack_cooldown_left: float = 0.0  # Tempo restante até o próximo ataque.
var _slash_cooldown_left: float = 0.0  # Tempo restante da recarga do golpe de espada.
var _last_attack: StringName = &""  # Último ataque sorteado (para não repetir).
var _walls: GuideWalls = null  # Paredes da transição (gaiola).
var _shot_specs: Array[GuideShotSpec] = []  # Receitas dos tiros de cada fase.


## Prepara o chefão: copia a velocidade do Tank, calcula a vida em que a fase 2 começa e monta as receitas dos tiros.
func _on_enemy_ready() -> void:
	# Anda na mesma velocidade da cena de referência (o Tank).
	move_speed = float(CombatUtils.get_scene_root_property(speed_reference_scene, &"move_speed", move_speed))
	# Vida em que termina a fase 1.
	_phase_two_health = roundi(float(health.max_health) * phase_two_health_ratio) if health != null else 0
	_build_shot_specs()  # Monta as receitas dos tiros de cada fase.
	_validate_attack_references()  # Avisa o que faltar ligar na cena.
	_apply_tint()  # Aplica a cor da fase.
	_acquire_target()  # Procura o jogador logo ao nascer.


## Confere se pools e paredes foram ligados no Inspector e avisa no console o que faltar.
func _validate_attack_references() -> void:
	var missing: PackedStringArray = []  # Lista dos nomes que faltam.
	if circle_pool == null: missing.append("circle_pool")
	if shot_pool == null: missing.append("shot_pool")
	if laser_pool == null: missing.append("laser_pool")
	if slash_pool == null: missing.append("slash_pool")
	if walls_scene == null: missing.append("walls_scene")
	if not missing.is_empty():
		push_warning("GuideEnemy '%s': referências não atribuídas: %s" % [name, ", ".join(missing)])


## Desconta as recargas dos ataques.
func _physics_process(delta: float) -> void:  # Desconta a recarga do ataque.
	# Desconta a recarga do golpe de espada.
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	_slash_cooldown_left = maxf(_slash_cooldown_left - delta, 0.0)  # (nunca fica negativa)


# --- Alvo (o chefão sempre sabe onde o player está) ---

## Sem alvo (ex.: o player acabou de nascer), procura o Player em vez de esperar a detecção.
func has_target() -> bool:
	if not super.has_target():  # Sem alvo: tenta achar o jogador.
		_acquire_target()
	return super.has_target()  # Devolve o resultado atualizado.


## O Guide nunca perde o player de vista.
func _on_detection_body_exited(_body: Node2D) -> void:  # O chefão nunca perde o jogador de vista.
	pass


## Procura o jogador no grupo e o define como alvo.
func _acquire_target() -> void:
	target = CombatUtils.get_player(self)  # Procura o jogador vivo.


## Persegue o player contornando paredes (para a `chase_stop_distance` dele).
func chase_target(delta: float) -> void:
	if not has_target():  # Sem alvo: só freia.
		brake(delta)
		return
	# Já está perto: freia e encara o jogador.
	if distance_sq_to_target() <= chase_stop_distance * chase_stop_distance:
		brake(delta)
		face_target()
		return
	navigate_towards(target.global_position, move_speed, delta)  # Anda até o jogador contornando paredes.


# --- Fase, vida e dano ---

## Devolve a fase atual.
func get_phase() -> Phase:
	return phase


## Diz se o chefão está na fase 2.
func is_phase_two() -> bool:
	return phase == Phase.TWO


## Diz se o chefão está invulnerável.
func is_invulnerable() -> bool:
	return _invulnerable


## Liga/desliga a invulnerabilidade (transição de fase).
func set_invulnerable(value: bool) -> void:
	_invulnerable = value  # Guarda o estado.
	_apply_tint()  # Atualiza a cor.


## Cálculo de dano: recusa se invulnerável, aplica o multiplicador e, na fase 1, nunca passa do
## limite da transição (o excedente é descartado para a fase 2 sempre acontecer).
func take_damage(amount: int, source: Variant = null) -> bool:
	if _dead or _invulnerable or health == null:  # Morto, invulnerável ou sem vida: recusa.
		return false
	var applied: int = _calculate_damage(amount)  # Dano já calculado.
	if applied <= 0:
		return false  # Dano zerado: recusa.
	if health.take_damage(applied, source) <= 0:  # Aplica na vida.
		return false
	# Fase 1, vivo e chegou ao limite: começa a transição.
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
	set_invulnerable(true)  # Fica invulnerável imediatamente.
	if state_machine != null:  # Entra no estado de transição no fim do quadro.
		# Adiado: o dano chega dentro da física, onde não se mexe em colisões.
		state_machine.transition_to.call_deferred(STATE_TRANSITION)


## Chamado pelo estado Transition ao entrar: limpa os ataques e para o chefão.
func on_transition_started() -> void:
	release_attacks()  # Remove os ataques em campo.
	velocity = Vector2.ZERO  # Para o chefão.


## Anda até o meio da sala (invulnerável, sem atacar). Devolve true quando chegou.
func return_to_center(delta: float) -> bool:
	var center: Vector2 = arena_rect.get_center()  # Centro da sala.
	# Chegou (passo menor que o deslocamento do quadro).
	if global_position.distance_to(center) <= transition_return_speed * delta:
		global_position = center  # Encaixa no centro.
		velocity = Vector2.ZERO  # Para.
		return true
	move_towards(center, transition_return_speed)  # Anda até o centro na velocidade da transição.
	return false


## Chegou ao meio da sala: levanta as paredes em volta dele e pede a wave.
func on_center_reached() -> void:
	_spawn_walls()  # Levanta a gaiola.
	# Pede a wave da transição ao EventBus, com o raio livre da gaiola.
	EventBus.boss_transition_started.emit(enemy_kind, global_position, _get_cage_clear_radius())


## Chamado pelo estado Transition ao terminar: remove as paredes e inicia a fase 2.
func on_transition_finished() -> void:
	_remove_walls()  # Remove as paredes.
	phase = Phase.TWO  # Entra na fase 2.
	set_invulnerable(false)  # Volta a receber dano.
	# Reinicia a espera do próximo ataque (ritmo da fase 2).
	_attack_cooldown_left = _by_phase(attack_interval)
	phase_changed.emit(phase)  # Avisa a fase nova.
	EventBus.boss_phase_changed.emit(enemy_kind, phase + 1)  # Avisa o EventBus (HUD e música).


## Morte: avisa por sinal, libera ataques e paredes.
func _on_death() -> void:
	_invulnerable = false  # Garante que não fique invulnerável.
	_remove_walls()  # Remove as paredes.
	release_attacks()  # Remove ataques em campo.
	defeated.emit(self)  # Avisa que o chefão foi derrotado.
	EventBus.boss_defeated.emit(enemy_kind)  # Avisa o EventBus.


## Devolve ao pool todos os ataques em campo.
func release_attacks() -> void:
	for pool: ObjectPool in [circle_pool, shot_pool, laser_pool, slash_pool]:  # Para cada pool de ataque.
		if pool != null:  # Pool existe.
			pool.release_all()  # Devolve todas as instâncias em uso.


# --- Escolha dos ataques ---

## Diz se o intervalo entre ataques já acabou.
func attack_ready() -> bool:
	return _attack_cooldown_left <= 0.0


## Começa a espera até o próximo ataque (mais curta na fase 2).
func start_attack_cooldown() -> void:
	_attack_cooldown_left = _by_phase(attack_interval)


## O player está dentro do alcance do golpe de espada e o golpe está carregado.
func can_slash() -> bool:
	if _slash_cooldown_left > 0.0 or not has_target():  # Em recarga ou sem alvo: não golpeia.
		return false
	# Distância em que o golpe já alcança o jogador.
	var reach: float = get_slash_radius() * SLASH_TRIGGER_FACTOR
	return distance_sq_to_target() <= reach * reach  # Compara distâncias ao quadrado.


## Sorteia o próximo ataque à distância, evitando repetir o anterior.
func pick_attack() -> StringName:
	_last_attack = _pick_attack_avoiding(_last_attack, 0)  # Sorteia sem repetir o anterior.
	return _last_attack


## Recursão do sorteio: tenta de novo se repetiu o anterior, até MAX_PICK_DEPTH tentativas.
func _pick_attack_avoiding(previous: StringName, depth: int) -> StringName:
	# Escolhe um ataque aleatório da lista.
	var candidate: StringName = RANGED_ATTACKS[randi() % RANGED_ATTACKS.size()]
	# Se repetiu, tenta de novo (até o limite de tentativas).
	if candidate == previous and depth < MAX_PICK_DEPTH:
		return _pick_attack_avoiding(previous, depth + 1)
	return candidate


# --- Ataque 1: círculos de aviso ---

## Quantidade de círculos da rajada na fase atual.
func get_circle_count() -> int:
	return _by_phase_i(circle_counts)


## Cria o círculo `index` da rajada: o primeiro cai no player, os outros em volta dele.
func spawn_circle(index: int) -> void:
	var circle := _acquire(circle_pool) as WarningCircle  # Pega um círculo do pool.
	if circle == null:  # Pool cheio: nada a fazer.
		return
	var center: Vector2 = _get_target_position()  # O primeiro círculo cai no jogador.
	if index > 0:  # Os outros nascem espalhados em volta dele.
		# Ponto aleatório dentro do raio de espalhamento.
		center += Vector2.from_angle(randf() * TAU) * randf_range(0.0, circle_scatter_radius)
	# Mantém o círculo dentro da arena.
	center = center.clamp(arena_rect.position + Vector2.ONE * circle_radius,
			arena_rect.end - Vector2.ONE * circle_radius)
	# Lança o círculo com aviso, tempo ativo e dano.
	circle.launch(center, circle_radius, circle_warning_time, circle_active_time, circle_damage, self)


# --- Ataques 2 e 6: tiros no player (e divisão na fase 2) ---

## Quantidade de tiros da rajada na fase atual.
func get_shot_count() -> int:
	return _by_phase_i(shot_counts)


## Atira um tiro principal na direção do player.
func fire_shot() -> void:
	var shot := _acquire(shot_pool) as GuideShot  # Pega um tiro do pool.
	if shot == null:  # Pool cheio: nada a fazer.
		return
	var direction: Vector2 = global_position.direction_to(_get_target_position())  # Direção até o jogador.
	shot.launch(global_position, direction, _shot_specs[phase], 0, self)  # Lança com a receita da fase.


## Receitas dos tiros por fase: a fase 2 encadeia o filho (tiros do tamanho do tiro do player).
func _build_shot_specs() -> void:
	var main := GuideShotSpec.new()  # Receita do tiro principal da fase 1.
	# Largura: fator vezes a largura do tiro do jogador.
	main.radius = PlayerProjectile.BASE_RADIUS * shot_width_multiplier
	main.speed = shot_speed
	main.damage = shot_damage
	main.lifetime = shot_lifetime
	var split := GuideShotSpec.new()  # Receita dos tiros divididos.
	split.style = GuideShotSpec.Style.ORB  # tiros divididos: orbe pequeno
	split.radius = PlayerProjectile.BASE_RADIUS
	split.speed = split_shot_speed
	split.damage = split_shot_damage
	split.lifetime = split_shot_lifetime
	# Receita do tiro principal da fase 2 (igual ao da fase 1, mas se divide).
	var main_phase_two := GuideShotSpec.new()
	main_phase_two.radius = main.radius
	main_phase_two.speed = main.speed
	main_phase_two.damage = main.damage
	main_phase_two.lifetime = main.lifetime
	main_phase_two.split_delay = split_delay  # Tempo até se dividir.
	main_phase_two.child = split  # Os filhos nascem da divisão.
	_shot_specs = [main, main_phase_two]  # Receitas por fase.


# --- Ataque 3: raio que cruza a sala ---

## Solta os raios da fase (varrendo a sala numa direção sorteada). Devolve a duração total.
func spawn_lasers() -> float:
	var count: int = _by_phase_i(laser_counts)  # Quantidade de raios.
	# Espessura do raio (largura do tiro do jogador).
	var thickness: float = PlayerProjectile.BASE_RADIUS * 2.0
	# Direção da varredura sorteada.
	var sweep: Vector2 = SWEEP_DIRECTIONS[randi() % SWEEP_DIRECTIONS.size()]
	var horizontal: bool = sweep.x != 0.0  # Varredura horizontal ou vertical?
	# Comprimento e percurso: o raio cobre a sala na perpendicular e a atravessa na direção do giro.
	# Comprimento do raio (cobre a sala na outra direção).
	var length: float = (arena_rect.size.y if horizontal else arena_rect.size.x) + thickness * 2.0
	# Percurso (atravessa a sala na direção do movimento).
	var travel: float = arena_rect.size.x if horizontal else arena_rect.size.y
	var center: Vector2 = arena_rect.get_center()  # Centro da sala.
	var start: Vector2 = center - sweep * travel * 0.5  # Ponto de partida dos raios.
	var gap_time: float = laser_spacing / maxf(laser_speed, 1.0)  # Intervalo entre um raio e o seguinte.
	for i: int in count:  # Um raio por vez.
		var laser := _acquire(laser_pool) as GuideLaser  # Pega um raio do pool.
		if laser == null:  # Pool cheio: para.
			break
		# Lança com aviso crescente (cada raio um pouco depois).
		laser.launch(start, sweep, length, thickness, laser_speed, travel,
				laser_warning_time + float(i) * gap_time, laser_damage, self)
	# Duração total do ataque (aviso + espaçamento + percurso).
	return laser_warning_time + float(maxi(count - 1, 0)) * gap_time + travel / maxf(laser_speed, 1.0)


# --- Ataque 4: golpe de espada em área ---

## Raio do golpe: 3x a hitbox da espada do player.
func get_slash_radius() -> float:
	# Raio do golpe: multiplicador vezes o raio da hitbox da espada.
	return Sword.HITBOX_RADIUS * slash_radius_multiplier


## Faz o golpe ao redor do chefão. Devolve a duração total.
func spawn_slash() -> float:
	_slash_cooldown_left = slash_cooldown  # Começa a recarga do golpe.
	var slash := _acquire(slash_pool) as GuideSlash  # Pega um golpe do pool.
	if slash == null:  # Pool cheio: sem duração.
		return 0.0
	# Lança o golpe ao redor do chefão.
	slash.launch(self, get_slash_radius(), slash_windup_time, slash_active_time, slash_damage, self)
	return slash.get_total_time()  # Duração total do golpe.


# --- Transição: paredes ---

## Levanta a gaiola em volta do chefão e tira o player de dentro dela.
func _spawn_walls() -> void:
	_remove_walls()  # Remove a gaiola anterior, se houver.
	if walls_scene == null:  # Sem cena de paredes configurada.
		return
	# Cria as paredes na posição do chefão.
	var walls := CombatUtils.spawn(walls_scene, self, global_position, GuideWalls) as GuideWalls
	if walls == null:
		return
	walls.half_size = cage_half_size  # Define o tamanho da gaiola.
	_walls = walls  # Guarda a referência.
	_eject_player_from.call_deferred(walls)  # Empurra o jogador para fora no fim do quadro.


## Desmonta a gaiola, se existir.
func _remove_walls() -> void:
	if CombatUtils.is_valid(_walls):  # Paredes existem.
		_walls.dismantle()  # Desmonta.
	_walls = null  # Esquece.


## Raio que a wave precisa respeitar para não nascer dentro da gaiola.
func _get_cage_clear_radius() -> float:
	# Espessura da parede (lida da cena).
	var thickness: float = float(CombatUtils.get_scene_root_property(walls_scene, &"thickness", DEFAULT_WALL_THICKNESS))
	# Raio da gaiola mais uma folga.
	return (cage_half_size + Vector2.ONE * thickness).length() + EJECT_MARGIN


## Se o player está dentro da gaiola, empurra para fora pelo lado mais próximo (dentro da sala).
func _eject_player_from(walls: GuideWalls) -> void:
	var player: Node2D = CombatUtils.get_player(self)  # Jogador vivo.
	if not CombatUtils.is_alive(walls) or player == null:  # Sem paredes ou jogador: nada a fazer.
		return
	var outer: Rect2 = walls.get_outer_rect().grow(EJECT_MARGIN)  # Retângulo externo da gaiola com folga.
	if not outer.has_point(player.global_position):  # Jogador fora da gaiola: nada a fazer.
		return
	var pos: Vector2 = player.global_position  # Posição do jogador.
	var exits: Array[Vector2] = [  # Saídas candidatas: uma por lado da gaiola.
		Vector2(outer.position.x, pos.y), Vector2(outer.end.x, pos.y),
		Vector2(pos.x, outer.position.y), Vector2(pos.x, outer.end.y),
	]
	var solid: Rect2 = outer.grow(-2.0)  # Região sólida (a parede).
	var best: Vector2 = arena_rect.get_center()  # Melhor saída (começa no centro).
	var best_distance: float = INF  # Menor distância encontrada.
	for exit_point: Vector2 in exits:  # Testa cada saída.
		# Mantém a saída dentro da sala.
		var clamped: Vector2 = exit_point.clamp(arena_rect.position, arena_rect.end)
		if solid.has_point(clamped):  # Saída que ainda cai na gaiola: descarta.
			continue  # esse lado dá na parede da sala: continua dentro da gaiola
		var distance: float = pos.distance_squared_to(clamped)  # Distância do jogador até a saída.
		if distance < best_distance:  # Fica com a mais próxima.
			best_distance = distance
			best = clamped
	player.global_position = best  # Teletransporta o jogador para a melhor saída.


# --- Auxiliares ---

## Pega uma instância do pool (ou null se não há pool).
func _acquire(pool: ObjectPool) -> PooledArea:
	return pool.acquire() if pool != null else null


## Posição do player (ou do próprio chefão se não houver player).
func _get_target_position() -> Vector2:
	return target.global_position if has_target() else global_position  # Posição do alvo.


## Valor da fase atual de um par (F1, F2).
func _by_phase(pair: Vector2) -> float:  # Fase 2 usa o segundo valor; fase 1 o primeiro.
	return pair.y if phase == Phase.TWO else pair.x


## Igual a `_by_phase`, para pares de inteiros.
func _by_phase_i(pair: Vector2i) -> int:
	return pair.y if phase == Phase.TWO else pair.x


## Cor do corpo conforme a situação (normal, invulnerável, fase 2).
func _apply_tint() -> void:  # Sem nó visual: nada a pintar.
	if body_visual == null:
		return
	if _invulnerable:  # Invulnerável: cor azulada translúcida.
		body_visual.modulate = TINT_INVULNERABLE
	else:
		# Normal ou enfurecido (fase 2).
		body_visual.modulate = TINT_PHASE_TWO if phase == Phase.TWO else TINT_NORMAL
