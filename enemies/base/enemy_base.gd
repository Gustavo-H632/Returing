class_name EnemyBase
extends CharacterBody2D
## Base de todos os inimigos (Drone, Tank, Robo).
## Responsável por: alvo, movimento, animação segura, dano, barra de vida e morte.
## A IA fica nos estados (StateWarden + EnemyState). As cenas já vêm montadas com
## referências preenchidas e sinais de dano/morte conectados; _ready usa connect_once
## para que cenas montadas à mão também funcionem, sem conexões duplicadas.

signal damaged(amount: int)
signal died(enemy: EnemyBase)

const ANIM_DEATH: StringName = &"death"

@export_group("Identidade")
@export var enemy_kind: StringName = &"enemy"

@export_group("Movimento")
@export var move_speed: float = 100.0

@export_group("Visual")
## true = os quadros da spritesheet olham para a direita.
@export var frames_face_right: bool = true
@export var hurt_flash_color: Color = Color(3.0, 3.0, 3.0, 1.0)
@export_range(0.0, 1.0, 0.01) var hurt_flash_time: float = 0.12
## Tempo máximo esperando a animação de morte antes de liberar o nó.
@export_range(0.1, 5.0, 0.1) var death_timeout: float = 1.5

@export_group("Referências (já ligadas na cena)")
@export var sprite: Sprite2D
@export var animation_player: AnimationPlayer
@export var body_collision: CollisionShape2D
@export var health: HealthComponent
@export var hurtbox: Hurtbox
@export var detection_area: Area2D
@export var state_machine: StateWarden
@export var health_bar: EnemyHealthBar

var target: Node2D = null
var spawn_position: Vector2 = Vector2.ZERO

var _dead: bool = false
var _flash_tween: Tween = null
var _current_anim: StringName = &""
var _sprite_offset_x: float = 0.0


func _enter_tree() -> void:
	add_to_group(CombatUtils.GROUP_ENEMY)


func _ready() -> void:
	spawn_position = global_position
	if sprite != null:
		_sprite_offset_x = sprite.offset.x
	_validate_references()
	_connect_signals()
	EnemyEvents.bind(self, enemy_kind, health)
	if health_bar != null and health != null:
		health_bar.set_health(health.current_health, health.max_health)
	_on_enemy_ready()
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
		if health_bar != null:
			CombatUtils.connect_once(health.health_changed, health_bar.set_health)
	if detection_area != null:
		CombatUtils.connect_once(detection_area.body_entered, _on_detection_body_entered)
		CombatUtils.connect_once(detection_area.body_exited, _on_detection_body_exited)
	CombatUtils.connect_once(EventBus.player_died, _on_player_died)


func _exit_tree() -> void:
	if EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.disconnect(_on_player_died)


# --- Alvo -----------------------------------------------------------------------

func has_target() -> bool:
	return CombatUtils.is_targetable(target)


func distance_sq_to_target() -> float:
	return global_position.distance_squared_to(target.global_position) if has_target() else INF


func direction_to_target() -> Vector2:
	return global_position.direction_to(target.global_position) if has_target() else Vector2.ZERO


func drop_target() -> void:
	target = null


func _on_detection_body_entered(body: Node2D) -> void:
	if CombatUtils.is_player(body):
		target = body


## Por padrão o inimigo esquece o alvo ao perder a visão (Robo sobrescreve: aggro permanente).
func _on_detection_body_exited(body: Node2D) -> void:
	if body == target:
		target = null


func _on_player_died() -> void:
	drop_target()


# --- Movimento ------------------------------------------------------------------

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


## Espelha o sprite mantendo o conteúdo centralizado (o offset X também é espelhado).
func _set_sprite_flip(flipped: bool) -> void:
	sprite.flip_h = flipped
	sprite.offset.x = -_sprite_offset_x if flipped else _sprite_offset_x


func face_target() -> void:
	if has_target():
		face_direction(target.global_position - global_position)


# --- Animação -------------------------------------------------------------------

## Toca uma animação se existir. Não reinicia a mesma (evita "travar" no 1º quadro),
## a não ser que restart = true (ex.: golpes consecutivos).
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


# --- Dano e morte ---------------------------------------------------------------

func is_dead() -> bool:
	return _dead


## API de dano no corpo (a Hurtbox entrega aqui). false = recusado.
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
	for area: Node in find_children("*", "Area2D", true, false):
		if area is Hitbox:
			(area as Hitbox).set_active(false)
	if health_bar != null:
		health_bar.fade_out()
	_on_death()
	_play_death_and_free()


## Gancho de morte (ex.: Robo deixa armadilha).
func _on_death() -> void:
	pass


## Corrotina: espera a animação "death" e libera o nó.
## Um timer de segurança garante a liberação mesmo se a animação for interrompida.
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
	_kill_flash()
	sprite.self_modulate = hurt_flash_color
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, ^"self_modulate", Color.WHITE, hurt_flash_time)


func _kill_flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	if sprite != null:
		sprite.self_modulate = Color.WHITE
