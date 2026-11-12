class_name EnemyBase
extends CharacterBody2D
## Base de todos os inimigos (Drone, Tank, Robo).

signal damaged(amount: int)  # Avisa que o inimigo tomou dano (quantidade).
signal died(enemy: EnemyBase)  # Avisa que o inimigo morreu (entrega ele mesmo).

const ANIM_DEATH: StringName = &"death"  # Nome da animação de morte.

@export_group("Identidade")
@export var enemy_kind: StringName = &"enemy"  # Tipo do inimigo (usado na pontuação e nos eventos).

@export_group("Movimento")
@export var move_speed: float = 100.0  # Velocidade de movimento em pixels por segundo.

@export_group("Navegação (desvio de paredes)")
## Liga o desvio de paredes por raycast em navigate_towards().
@export var avoid_obstacles: bool = true
## Camadas de física tratadas como obstáculo (padrão: camada 1, "Mundo").
@export_flags_2d_physics var obstacle_mask: int = 1
## 24 raios = 15 graus entre eles.
@export_range(4, 48, 1) var avoid_ray_count: int = 24
## Alcance dos raios, medido a partir da borda do corpo.
@export_range(16.0, 200.0, 1.0) var avoid_probe_distance: float = 56.0
## Intervalo entre varreduras dos raios (0 = todo frame).
@export_range(0.0, 0.5, 0.01) var avoid_update_interval: float = 0.05
## Velocidade máxima de giro do rumo, em graus por segundo.
@export_range(90.0, 1440.0, 10.0) var avoid_turn_rate: float = 540.0
## Desenha os raios.
@export var debug_steering: bool = false:
	set(value):
		debug_steering = value
		queue_redraw()

@export_group("Visual")
## True = os quadros da spritesheet olham para a direita.
@export var frames_face_right: bool = true
@export var hurt_flash_color: Color = Color(2.2, 0.35, 0.35, 1.0)  # Cor do pisca ao tomar dano.
@export_range(0.0, 1.0, 0.01) var hurt_flash_time: float = 0.12  # Duração do pisca.
## Tempo máximo esperando a animação de morte antes de liberar o nó.
@export_range(0.1, 5.0, 0.1) var death_timeout: float = 1.5

@export_group("Barra de vida")
## Cria uma EnemyHealthBar por código acima do corpo.
@export var show_health_bar: bool = true
## Largura da barra.
@export_range(0.0, 200.0, 1.0, "or_greater") var health_bar_width: float = 0.0
## Folga em pixels entre o topo do corpo e a barra.
@export_range(0.0, 80.0, 1.0, "or_greater") var health_bar_margin: float = 10.0
## Liga para a barra ficar sempre na tela, em vez de só aparecer ao levar dano.
@export var health_bar_always_visible: bool = false

@export_group("Referências (já ligadas na cena)")
@export var sprite: Sprite2D  # Sprite do inimigo.
@export var animation_player: AnimationPlayer  # Tocador de animações.
@export var body_collision: CollisionShape2D  # Forma de colisão do corpo.
@export var health: HealthComponent  # Componente de vida.
@export var hurtbox: Hurtbox  # Área que recebe dano.
@export var detection_area: Area2D  # Área que detecta o jogador.
@export var state_machine: StateWarden  # Máquina de estados da IA.

## Alvo atual (o Player).
var target: Node2D = null:
	set(value):
		target = value
		_target_frame = -1  # Força o cache de `has_target` a ser refeito.
var spawn_position: Vector2 = Vector2.ZERO  # Posição onde o inimigo nasceu (âncora da patrulha).

var _dead: bool = false  # True depois que o inimigo morre.
var _flash_tween: Tween = null  # Tween do pisca de dano.
var _current_anim: StringName = &""  # Animação que está tocando.
var _sprite_offset_x: float = 0.0  # Posição X original do sprite (para espelhar sem deslocar).
var _steering: ObstacleSteering = null  # Desvio de paredes (criado sob demanda).
## Hitboxes da cena, coletadas uma única vez (desligadas de uma vez na morte).
var _hitboxes: Array[Hitbox] = []
## Barra de vida flutuante, criada no _ready quando show_health_bar está ligado.
var _health_bar: EnemyHealthBar = null
## Cache de has_target() por frame de física.
var _target_frame: int = -1
var _target_valid: bool = false  # Resultado em cache de `has_target`.


## Entra no grupo "enemy" ao entrar na árvore (mira automática e ondas usam esse grupo).
func _enter_tree() -> void:
	add_to_group(CombatUtils.GROUP_ENEMY)


## Prepara o inimigo: escala do celular, referências, sinais, eventos, hitboxes, barra de vida e IA.
func _ready() -> void:
	scale *= Platform.sprite_scale  # celular: sprites maiores (corpo e hurtbox crescem juntos)
	spawn_position = global_position  # Guarda o ponto de nascimento.
	if sprite != null:
		_sprite_offset_x = sprite.offset.x  # Guarda o deslocamento original do sprite.
	_validate_references()  # Avisa no console o que faltou ligar na cena.
	_connect_signals()  # Liga os sinais de vida e detecção.
	EnemyEvents.bind(self, enemy_kind, health)  # Registra o inimigo no EventBus e no grupo.
	_on_enemy_ready()  # Gancho das subclasses antes da IA iniciar.
	_collect_hitboxes()  # Coleta as hitboxes para desligá-las na morte.
	_build_health_bar()  # Cria a barra de vida.
	if state_machine != null:
		state_machine.start()  # Inicia a máquina de estados.


## Gancho para subclasses (configurar hitboxes, raios etc.) antes da IA iniciar.
func _on_enemy_ready() -> void:
	pass


## Confere se as referências obrigatórias foram ligadas na cena e avisa o que faltar.
func _validate_references() -> void:
	var missing: PackedStringArray = []  # Lista dos nomes que faltam.
	if sprite == null: missing.append("sprite")
	if animation_player == null: missing.append("animation_player")
	if health == null: missing.append("health")
	if hurtbox == null: missing.append("hurtbox")
	if detection_area == null: missing.append("detection_area")
	if state_machine == null: missing.append("state_machine")
	if not missing.is_empty():
		push_warning("%s '%s': referências não atribuídas: %s" % [enemy_kind, name, ", ".join(missing)])


## Fallback das conexões que já estão gravadas na cena.
## Liga por código os sinais de vida e detecção (garantia caso a cena não os tenha gravados).
func _connect_signals() -> void:
	if health != null:  # Vida: dano e morte.
		CombatUtils.connect_once(health.damaged, _on_health_damaged)
		CombatUtils.connect_once(health.died, _on_health_died)
	if detection_area != null:  # Detecção: jogador entrou ou saiu do raio.
		CombatUtils.connect_once(detection_area.body_entered, _on_detection_body_entered)
		CombatUtils.connect_once(detection_area.body_exited, _on_detection_body_exited)
	# Se o jogador morrer, o inimigo esquece o alvo.
	CombatUtils.connect_once(EventBus.player_died, _on_player_died)


## Desliga o sinal do EventBus ao sair da árvore.
func _exit_tree() -> void:
	CombatUtils.disconnect_if_connected(EventBus.player_died, _on_player_died)


# --- Alvo ---

## Resolvido uma vez por frame de física (ver _target_frame).
## Diz se há um alvo válido. O resultado é calculado uma vez por quadro de física e guardado em cache.
func has_target() -> bool:
	var frame: int = Engine.get_physics_frames()  # Número do quadro de física atual.
	if frame != _target_frame:  # Só refaz a conta se o quadro mudou.
		_target_frame = frame
		_target_valid = CombatUtils.is_targetable(target)  # O alvo precisa existir, estar na cena e vivo.
	return _target_valid


## Distância ao quadrado até o alvo (mais rápido que a distância normal). Devolve infinito sem alvo.
func distance_sq_to_target() -> float:
	return global_position.distance_squared_to(target.global_position) if has_target() else INF


## Vetor unitário apontando para o alvo (zero sem alvo).
func direction_to_target() -> Vector2:
	return global_position.direction_to(target.global_position) if has_target() else Vector2.ZERO


## Esquece o alvo atual.
func drop_target() -> void:
	target = null


## O jogador entrou no raio de detecção: vira o alvo.
func _on_detection_body_entered(body: Node2D) -> void:
	if CombatUtils.is_player(body):  # Só o jogador conta.
		target = body


## Por padrão o inimigo esquece o alvo ao perder a visão.
## O corpo saiu do raio de detecção: se era o alvo, esquece (os estados voltam a patrulhar).
func _on_detection_body_exited(body: Node2D) -> void:
	if body == target:  # Só esquece se for o alvo atual.
		target = null


## O jogador morreu: esquece o alvo.
func _on_player_died() -> void:
	drop_target()


# --- Movimento ---

## Anda em linha reta até o ponto na velocidade pedida (sem desviar de paredes).
func move_towards(point: Vector2, speed: float) -> void:
	var to_point: Vector2 = point - global_position  # Vetor até o ponto.
	# Se já chegou (menos de 1 px), para.
	velocity = to_point.normalized() * speed if to_point.length_squared() > 1.0 else Vector2.ZERO
	face_direction(velocity)  # Vira o sprite para o lado do movimento.
	move_and_slide()  # Aplica o movimento e resolve colisões.


## Para o inimigo imediatamente.
func stop_moving() -> void:
	velocity = Vector2.ZERO
	move_and_slide()


## Freia aos poucos; sem valor de desaceleração usa 4 vezes a velocidade de movimento.
func brake(delta: float, deceleration: float = -1.0) -> void:
	var decel: float = deceleration if deceleration > 0.0 else move_speed * 4.0  # Desaceleração escolhida.
	velocity = velocity.move_toward(Vector2.ZERO, decel * delta)  # Aproxima a velocidade de zero.
	move_and_slide()  # Aplica o movimento.


## Vira o sprite para a direção horizontal indicada (ignora movimento quase só vertical).
func face_direction(direction: Vector2) -> void:
	if sprite == null or absf(direction.x) < 0.01:  # Sem sprite ou sem movimento horizontal: mantém o lado.
		return
	var looking_left: bool = direction.x < 0.0  # True se olha para a esquerda.
	# Espelha de acordo com o lado em que a arte original olha.
	_set_sprite_flip(looking_left if frames_face_right else not looking_left)


## Espelha o sprite mantendo o conteúdo centralizado.
## Espelha o sprite horizontalmente mantendo o centro da arte.
func _set_sprite_flip(flipped: bool) -> void:
	CombatUtils.set_sprite_flip(sprite, flipped, _sprite_offset_x)


## Vira o sprite para o alvo.
func face_target() -> void:
	if has_target():
		face_direction(target.global_position - global_position)


# --- Navegação (desvio de paredes) ---

## Como move_towards(), mas contorna paredes (ver ObstacleSteering).
## Anda até o ponto contornando paredes (usa o ObstacleSteering). Sem desvio ligado, anda reto.
func navigate_towards(point: Vector2, speed: float, delta: float) -> void:
	var to_point: Vector2 = point - global_position  # Vetor até o ponto.
	if not avoid_obstacles or to_point.length_squared() <= 1.0:  # Sem desvio (ou já chegou): anda reto.
		move_towards(point, speed)
		return
	var heading: Vector2 = _get_steering().steer(  # Pede ao desvio o melhor rumo livre.
			get_world_2d().direct_space_state, _get_nav_origin(), to_point.normalized(), speed, delta)
	velocity = heading * speed  # Rumo vezes a velocidade.
	face_direction(velocity)  # Vira o sprite para onde anda.
	move_and_slide()  # Aplica o movimento.
	if debug_steering:  # Redesenha os raios, se pedido.
		queue_redraw()


## Encurta o trajeto.
## Encurta um trajeto para que ele termine antes da primeira parede.
func trim_to_free_space(point: Vector2) -> Vector2:
	return _get_steering().trim_segment(get_world_2d().direct_space_state, _get_nav_origin(), point)


## True uma única vez depois que o desvio detectou que o inimigo travou.
## Devolve true uma única vez depois que o desvio percebeu que o inimigo ficou preso.
func consume_navigation_stuck() -> bool:
	return _steering != null and _steering.consume_stuck()


## Zera o estado do desvio.
## Reinicia o estado do desvio (usado ao trocar de comportamento).
func reset_navigation() -> void:
	if _steering != null:
		_steering.reset(_get_nav_origin())


## Origem dos raios.
## Centro dos raios: o centro da colisão, ou a posição do inimigo.
func _get_nav_origin() -> Vector2:
	return body_collision.global_position if body_collision != null else global_position


## Cria o desvio sob demanda.
## Cria o desvio na primeira vez que alguém precisa dele, com a configuração do inimigo.
func _get_steering() -> ObstacleSteering:
	if _steering == null:  # Ainda não criado.
		var exclude: Array[RID] = [get_rid()]  # O próprio corpo não conta como obstáculo.
		_steering = ObstacleSteering.new()  # Cria.
		_steering.configure(obstacle_mask, avoid_ray_count, avoid_probe_distance,  # Entrega a configuração.
				_estimate_body_radius(), avoid_update_interval, avoid_turn_rate, exclude)
	return _steering


## Raio aproximado do corpo, lido da forma de colisão.
## Estima o raio do corpo a partir da forma de colisão (círculo, cápsula ou retângulo).
func _estimate_body_radius() -> float:
	const FALLBACK_RADIUS: float = 12.0  # Raio usado quando não há forma conhecida.
	if body_collision == null or body_collision.shape == null:  # Sem colisão: usa o raio padrão.
		return FALLBACK_RADIUS
	var shape: Shape2D = body_collision.shape  # Forma de colisão.
	# Maior escala (o inimigo pode estar ampliado no celular).
	var scale_factor: float = maxf(absf(body_collision.global_scale.x), absf(body_collision.global_scale.y))
	if shape is CircleShape2D:  # Círculo: o raio.
		return (shape as CircleShape2D).radius * scale_factor
	if shape is CapsuleShape2D:  # Cápsula: o raio.
		return (shape as CapsuleShape2D).radius * scale_factor
	if shape is RectangleShape2D:  # Retângulo: metade do maior lado.
		var size: Vector2 = (shape as RectangleShape2D).size
		return maxf(size.x, size.y) * 0.5 * scale_factor
	return FALLBACK_RADIUS


## Desenha os raios do desvio quando `debug_steering` está ligado.
func _draw() -> void:
	if debug_steering and _steering != null:
		_steering.draw_debug(self, _get_nav_origin())


# --- Animação ---

## Toca uma animação se existir.
## Toca a animação se ela existir. Morto só toca a de morte. Não reinicia a que já está tocando (a menos que `restart`).
func play_anim(anim_name: StringName, restart: bool = false, speed_scale: float = 1.0) -> void:
	# Sem tocador, ou morto tentando outra animação: ignora.
	if animation_player == null or (_dead and anim_name != ANIM_DEATH):
		return
	if not animation_player.has_animation(anim_name):  # Animação inexistente: ignora.
		return
	animation_player.speed_scale = speed_scale  # Ajusta a velocidade da animação.
	# Já tocando: não reinicia.
	if anim_name == _current_anim and animation_player.is_playing() and not restart:
		return
	_current_anim = anim_name  # Guarda o nome atual.
	animation_player.play(anim_name)  # Toca.
	if restart:  # Se pedido, volta ao primeiro quadro.
		animation_player.seek(0.0, true)


# --- Dano e morte ---

## Diz se o inimigo já morreu.
func is_dead() -> bool:
	return _dead


## API de dano no corpo (a Hurtbox entrega aqui).
## Recebe dano da Hurtbox e repassa ao componente de vida. Devolve true se o dano foi aplicado.
func take_damage(amount: int, source: Variant = null) -> bool:
	if _dead or health == null:  # Morto ou sem vida: recusa.
		return false
	return health.take_damage(amount, source) > 0  # Aceito se tirou alguma vida.


## A vida tomou dano: avisa quem escuta e pisca.
func _on_health_damaged(amount: int) -> void:
	damaged.emit(amount)  # Repassa o sinal.
	_flash()  # Pisca em vermelho.


## A vida chegou a zero: o inimigo morre.
func _on_health_died() -> void:
	die()


## Morte: trava a IA, desliga colisões/hitboxes, anima e libera o nó.
## Morte: trava a IA, desliga colisões e hitboxes, esconde a barra, anima e libera o nó.
func die() -> void:
	if _dead:  # Já morreu: não repete.
		return
	_dead = true  # Marca como morto.
	died.emit(self)  # Avisa (a pontuação e as ondas escutam).
	if state_machine != null:  # Entra no estado Dead e trava a máquina.
		state_machine.die()  # para a IA (exit() do estado atual fecha hitboxes)
	set_physics_process(false)  # Para a física do inimigo.
	velocity = Vector2.ZERO  # Para o corpo.
	if hurtbox != null:  # Não recebe mais dano.
		hurtbox.set_active(false)
	if detection_area != null:  # Não detecta mais o jogador.
		detection_area.set_deferred(&"monitoring", false)
	if body_collision != null:  # Desliga a colisão do corpo.
		body_collision.set_deferred(&"disabled", true)
	for hitbox: Hitbox in _hitboxes:  # Desliga todas as hitboxes.
		if CombatUtils.is_valid(hitbox):
			hitbox.set_active(false)
	if CombatUtils.is_valid(_health_bar):  # Esconde a barra de vida.
		_health_bar.dismiss()
	_on_death()  # Gancho das subclasses (ex.: o Robo deixa armadilha).
	_play_death_and_free()  # Toca a animação e remove o nó.


## Cria a barra de vida acima do corpo.
## Cria a barra de vida acima do corpo (largura e altura proporcionais ao tamanho do inimigo).
func _build_health_bar() -> void:
	if not show_health_bar or health == null:  # Sem barra pedida ou sem vida: não cria.
		return
	var radius: float = _estimate_body_radius()  # Raio do corpo, para posicionar a barra.
	_health_bar = EnemyHealthBar.new()  # Cria a barra.
	_health_bar.name = &"HealthBar"
	# Largura: a configurada ou 3,2 vezes o raio (mínimo 20).
	_health_bar.width = health_bar_width if health_bar_width > 0.0 else maxf(radius * 3.2, 20.0)
	_health_bar.height = maxf(_health_bar.width * 0.15, 4.0)  # Altura proporcional (mínimo 4).
	# Filha direta da raiz: o espelhamento é feito só no sprite, então a
	# barra não vira junto quando o inimigo troca de lado.
	_health_bar.always_visible = health_bar_always_visible  # Visibilidade configurada.
	_health_bar.position = Vector2(0.0, -(radius + health_bar_margin))  # Posição acima do topo do corpo.
	add_child(_health_bar)  # Entra na árvore.
	_health_bar.bind(health)  # Liga a barra à vida do inimigo.


## Coleta as Hitboxes da cena uma única vez (varredura recursiva da árvore).
## Guarda todas as Hitboxes da cena (varredura recursiva) para desligá-las de uma vez na morte.
func _collect_hitboxes() -> void:
	_hitboxes.clear()  # Recomeça a lista.
	# Procura todo descendente que seja Hitbox.
	for node: Node in CombatUtils.find_descendants(self, func(candidate: Node) -> bool: return candidate is Hitbox):
		_hitboxes.append(node as Hitbox)  # Guarda cada uma.


## Gancho de morte (ex.: Robo deixa armadilha).
## Gancho vazio para as subclasses (ex.: deixar uma armadilha ao morrer).
func _on_death() -> void:
	pass


## Corrotina: espera a animação "death" e libera o nó.
## Toca a animação de morte e remove o inimigo (com limite de tempo, caso a animação não termine).
func _play_death_and_free() -> void:
	_kill_flash()  # Cancela o pisca de dano.
	# Se existe animação de morte, toca.
	if animation_player != null and animation_player.has_animation(ANIM_DEATH):
		play_anim(ANIM_DEATH, true)  # Toca do começo.
		# Rede de segurança: remove o nó depois do tempo limite.
		get_tree().create_timer(death_timeout, false).timeout.connect(queue_free)
		await animation_player.animation_finished  # Espera a animação acabar.
	queue_free()  # Remove o nó da cena.


## Pisca o sprite com a cor de dano.
func _flash() -> void:
	if sprite == null or _dead:  # Sem sprite ou morto: não pisca.
		return
	# Inicia o pisca guardando o Tween.
	_flash_tween = CombatUtils.flash_sprite(sprite, _flash_tween, hurt_flash_color, hurt_flash_time)


## Cancela o pisca e restaura a cor.
func _kill_flash() -> void:
	CombatUtils.kill_flash(sprite, _flash_tween)
