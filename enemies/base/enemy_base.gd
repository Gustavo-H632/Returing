class_name EnemyBase
extends CharacterBody2D
## Base de todos os inimigos (Drone, Tank, Robo).

signal damaged(amount: int)
signal died(enemy: EnemyBase)

const ANIM_DEATH: StringName = &"death"

@export_group("Identidade")
@export var enemy_kind: StringName = &"enemy"

@export_group("Movimento")
@export var move_speed: float = 100.0

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
@export var hurt_flash_color: Color = Color(2.2, 0.35, 0.35, 1.0)
@export_range(0.0, 1.0, 0.01) var hurt_flash_time: float = 0.12
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
@export var sprite: Sprite2D
@export var animation_player: AnimationPlayer
@export var body_collision: CollisionShape2D
@export var health: HealthComponent
@export var hurtbox: Hurtbox
@export var detection_area: Area2D
@export var state_machine: StateWarden

## Alvo atual (o Player).
var target: Node2D = null:
	set(value):
		target = value
		_target_frame = -1
var spawn_position: Vector2 = Vector2.ZERO

var _dead: bool = false
var _flash_tween: Tween = null
var _current_anim: StringName = &""
var _sprite_offset_x: float = 0.0
var _steering: ObstacleSteering = null
## Hitboxes da cena, coletadas uma única vez (desligadas de uma vez na morte).
var _hitboxes: Array[Hitbox] = []
## Barra de vida flutuante, criada no _ready quando show_health_bar está ligado.
var _health_bar: EnemyHealthBar = null
## Cache de has_target() por frame de física.
var _target_frame: int = -1
var _target_valid: bool = false


func _enter_tree() -> void:
	add_to_group(CombatUtils.GROUP_ENEMY)


func _ready() -> void:
	spawn_position = global_position
	if sprite != null:
		_sprite_offset_x = sprite.offset.x
	_validate_references()
	_connect_signals()
	EnemyEvents.bind(self, enemy_kind, health)
	_on_enemy_ready()
	_collect_hitboxes()
	_build_health_bar()
	if state_machine != null:
		state_machine.start()


## Gancho para subclasses (configurar hitboxes, raios etc.) antes da IA iniciar.
func _on_enemy_ready() -> void:
	pass


func _validate_references() -> void:
	var missing: PackedStringArray = []
	if sprite == null: missing.append("sprite")
	if animation_player == null: missing.append("animation_player")
	if health == null: missing.append("health")
	if hurtbox == null: missing.append("hurtbox")
	if detection_area == null: missing.append("detection_area")
	if state_machine == null: missing.append("state_machine")
	if not missing.is_empty():
		push_warning("%s '%s': referências não atribuídas: %s" % [enemy_kind, name, ", ".join(missing)])


## Fallback das conexões que já estão gravadas na cena.
func _connect_signals() -> void:
	if health != null:
		CombatUtils.connect_once(health.damaged, _on_health_damaged)
		CombatUtils.connect_once(health.died, _on_health_died)
	if detection_area != null:
		CombatUtils.connect_once(detection_area.body_entered, _on_detection_body_entered)
		CombatUtils.connect_once(detection_area.body_exited, _on_detection_body_exited)
	CombatUtils.connect_once(EventBus.player_died, _on_player_died)


func _exit_tree() -> void:
	CombatUtils.disconnect_if_connected(EventBus.player_died, _on_player_died)


# --- Alvo ---

## Resolvido uma vez por frame de física (ver _target_frame).
func has_target() -> bool:
	var frame: int = Engine.get_physics_frames()
	if frame != _target_frame:
		_target_frame = frame
		_target_valid = CombatUtils.is_targetable(target)
	return _target_valid


func distance_sq_to_target() -> float:
	return global_position.distance_squared_to(target.global_position) if has_target() else INF


func direction_to_target() -> Vector2:
	return global_position.direction_to(target.global_position) if has_target() else Vector2.ZERO


func drop_target() -> void:
	target = null


func _on_detection_body_entered(body: Node2D) -> void:
	if CombatUtils.is_player(body):
		target = body


## Por padrão o inimigo esquece o alvo ao perder a visão.
func _on_detection_body_exited(body: Node2D) -> void:
	if body == target:
		target = null


func _on_player_died() -> void:
	drop_target()


# --- Movimento ---

func move_towards(point: Vector2, speed: float) -> void:
	var to_point: Vector2 = point - global_position
	velocity = to_point.normalized() * speed if to_point.length_squared() > 1.0 else Vector2.ZERO
	face_direction(velocity)
	move_and_slide()


func stop_moving() -> void:
	velocity = Vector2.ZERO
	move_and_slide()


func brake(delta: float, deceleration: float = -1.0) -> void:
	var decel: float = deceleration if deceleration > 0.0 else move_speed * 4.0
	velocity = velocity.move_toward(Vector2.ZERO, decel * delta)
	move_and_slide()


func face_direction(direction: Vector2) -> void:
	if sprite == null or absf(direction.x) < 0.01:
		return
	var looking_left: bool = direction.x < 0.0
	_set_sprite_flip(looking_left if frames_face_right else not looking_left)


## Espelha o sprite mantendo o conteúdo centralizado.
func _set_sprite_flip(flipped: bool) -> void:
	CombatUtils.set_sprite_flip(sprite, flipped, _sprite_offset_x)


func face_target() -> void:
	if has_target():
		face_direction(target.global_position - global_position)


# --- Navegação (desvio de paredes) ---

## Como move_towards(), mas contorna paredes (ver ObstacleSteering).
func navigate_towards(point: Vector2, speed: float, delta: float) -> void:
	var to_point: Vector2 = point - global_position
	if not avoid_obstacles or to_point.length_squared() <= 1.0:
		move_towards(point, speed)
		return
	var heading: Vector2 = _get_steering().steer(
			get_world_2d().direct_space_state, _get_nav_origin(), to_point.normalized(), speed, delta)
	velocity = heading * speed
	face_direction(velocity)
	move_and_slide()
	if debug_steering:
		queue_redraw()


## Encurta o trajeto.
func trim_to_free_space(point: Vector2) -> Vector2:
	return _get_steering().trim_segment(get_world_2d().direct_space_state, _get_nav_origin(), point)


## True uma única vez depois que o desvio detectou que o inimigo travou.
func consume_navigation_stuck() -> bool:
	return _steering != null and _steering.consume_stuck()


## Zera o estado do desvio.
func reset_navigation() -> void:
	if _steering != null:
		_steering.reset(_get_nav_origin())


## Origem dos raios.
func _get_nav_origin() -> Vector2:
	return body_collision.global_position if body_collision != null else global_position


## Cria o desvio sob demanda.
func _get_steering() -> ObstacleSteering:
	if _steering == null:
		var exclude: Array[RID] = [get_rid()]
		_steering = ObstacleSteering.new()
		_steering.configure(obstacle_mask, avoid_ray_count, avoid_probe_distance,
				_estimate_body_radius(), avoid_update_interval, avoid_turn_rate, exclude)
	return _steering


## Raio aproximado do corpo, lido da forma de colisão.
func _estimate_body_radius() -> float:
	const FALLBACK_RADIUS: float = 12.0
	if body_collision == null or body_collision.shape == null:
		return FALLBACK_RADIUS
	var shape: Shape2D = body_collision.shape
	var scale_factor: float = maxf(absf(body_collision.global_scale.x), absf(body_collision.global_scale.y))
	if shape is CircleShape2D:
		return (shape as CircleShape2D).radius * scale_factor
	if shape is CapsuleShape2D:
		return (shape as CapsuleShape2D).radius * scale_factor
	if shape is RectangleShape2D:
		var size: Vector2 = (shape as RectangleShape2D).size
		return maxf(size.x, size.y) * 0.5 * scale_factor
	return FALLBACK_RADIUS


func _draw() -> void:
	if debug_steering and _steering != null:
		_steering.draw_debug(self, _get_nav_origin())


# --- Animação ---

## Toca uma animação se existir.
func play_anim(anim_name: StringName, restart: bool = false, speed_scale: float = 1.0) -> void:
	if animation_player == null or (_dead and anim_name != ANIM_DEATH):
		return
	if not animation_player.has_animation(anim_name):
		return
	animation_player.speed_scale = speed_scale
	if anim_name == _current_anim and animation_player.is_playing() and not restart:
		return
	_current_anim = anim_name
	animation_player.play(anim_name)
	if restart:
		animation_player.seek(0.0, true)


# --- Dano e morte ---

func is_dead() -> bool:
	return _dead


## API de dano no corpo (a Hurtbox entrega aqui).
func take_damage(amount: int, source: Variant = null) -> bool:
	if _dead or health == null:
		return false
	return health.take_damage(amount, source) > 0


func _on_health_damaged(amount: int) -> void:
	damaged.emit(amount)
	_flash()


func _on_health_died() -> void:
	die()


## Morte: trava a IA, desliga colisões/hitboxes, anima e libera o nó.
func die() -> void:
	if _dead:
		return
	_dead = true
	died.emit(self)
	if state_machine != null:
		state_machine.die()  # para a IA (exit() do estado atual fecha hitboxes)
	set_physics_process(false)
	velocity = Vector2.ZERO
	if hurtbox != null:
		hurtbox.set_active(false)
	if detection_area != null:
		detection_area.set_deferred(&"monitoring", false)
	if body_collision != null:
		body_collision.set_deferred(&"disabled", true)
	for hitbox: Hitbox in _hitboxes:
		if CombatUtils.is_valid(hitbox):
			hitbox.set_active(false)
	if CombatUtils.is_valid(_health_bar):
		_health_bar.dismiss()
	_on_death()
	_play_death_and_free()


## Cria a barra de vida acima do corpo.
func _build_health_bar() -> void:
	if not show_health_bar or health == null:
		return
	var radius: float = _estimate_body_radius()
	_health_bar = EnemyHealthBar.new()
	_health_bar.name = &"HealthBar"
	_health_bar.width = health_bar_width if health_bar_width > 0.0 else maxf(radius * 3.2, 20.0)
	_health_bar.height = maxf(_health_bar.width * 0.15, 4.0)
	# Filha direta da raiz: o espelhamento é feito só no sprite, então a
	# barra não vira junto quando o inimigo troca de lado.
	_health_bar.always_visible = health_bar_always_visible
	_health_bar.position = Vector2(0.0, -(radius + health_bar_margin))
	add_child(_health_bar)
	_health_bar.bind(health)


## Coleta as Hitboxes da cena uma única vez (varredura recursiva da árvore).
func _collect_hitboxes() -> void:
	_hitboxes.clear()
	for node: Node in CombatUtils.find_descendants(self, func(candidate: Node) -> bool: return candidate is Hitbox):
		_hitboxes.append(node as Hitbox)


## Gancho de morte (ex.: Robo deixa armadilha).
func _on_death() -> void:
	pass


## Corrotina: espera a animação "death" e libera o nó.
func _play_death_and_free() -> void:
	_kill_flash()
	if animation_player != null and animation_player.has_animation(ANIM_DEATH):
		play_anim(ANIM_DEATH, true)
		get_tree().create_timer(death_timeout, false).timeout.connect(queue_free)
		await animation_player.animation_finished
	queue_free()


func _flash() -> void:
	if sprite == null or _dead:
		return
	_flash_tween = CombatUtils.flash_sprite(sprite, _flash_tween, hurt_flash_color, hurt_flash_time)


func _kill_flash() -> void:
	CombatUtils.kill_flash(sprite, _flash_tween)
