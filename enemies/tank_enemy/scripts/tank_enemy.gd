class_name TankEnemy
extends CharacterBody2D
## Inimigo Tank: lento e resistente. Pisoteio perto e investida longe.

signal died

const ENEMY_KIND: StringName = &"tank"

@export_group("Status")
@export var max_health: int = 500
@export var move_speed: float = 45.0

@export_group("Detecção")
@export var detection_radius: float = 420.0    ## Raio da área de busca.
@export var attack_range_radius: float = 90.0  ## Raio da área de ataque.

@export_group("Ataque de Área (Pisoteio)")
@export var stomp_damage: int = 15
@export var stomp_pulse_interval: float = 1.0

@export_group("Investida (Special Attack / Bull Dash)")
@export var min_distance_for_dash: float = 260.0  ## Distância mínima para a investida.
@export var dash_prepare_time: float = 0.8
@export var dash_duration: float = 0.5
@export var dash_speed: float = 520.0
@export var dash_damage: int = 40
## Tempo mínimo entre investidas
@export var special_attack_cooldown: float = 1.0

@export_group("Vagar (Idle Ativo)")
@export var wander_radius: float = 110.0
@export var wander_speed_multiplier: float = 0.35

## Referências de nós: arraste cada nó no Inspector.
@export_group("Referências (arraste os nós)")
@export var state_machine: TankStateMachine
@export var health_component: TankHealthComponent
@export var hurtbox: TankHurtbox
@export var detection_area: Area2D
@export var detection_shape: CollisionShape2D
@export var attack_range_area: Area2D  ## Opcional.
@export var attack_range_shape: CollisionShape2D  ## Opcional.
@export var stomp_hitbox: TankHitbox
@export var stomp_shape: CollisionShape2D
@export var dash_hitbox: TankHitbox
@export var sprite: Sprite2D  ## Opcional (flash de dano e fade da morte).

var player: Node2D = null
var spawn_position: Vector2 = Vector2.ZERO
var dash_direction: Vector2 = Vector2.ZERO  ## Direção travada da investida

var _dash_cooldown_left: float = 0.0
## Recarga do pisoteio (no Tank para não zerar ao trocar de estado)
var _stomp_cooldown_left: float = 0.0
var _dead: bool = false
var _flash_tween: Tween = null


## Entra no grupo enemy.
func _enter_tree() -> void:
	add_to_group(CombatUtils.GROUP_ENEMY)


## Vida, eventos, sensores e máquina de estados.
func _ready() -> void:
	spawn_position = global_position
	_validar_referencias()

	if health_component != null:
		# Vida máxima vem do export do Tank
		health_component.setup(max_health)
		health_component.damaged.connect(_on_damaged)
		health_component.died.connect(_on_died)
		if hurtbox != null and hurtbox.health_component == null:
			hurtbox.health_component = health_component
	EnemyEvents.bind(self, ENEMY_KIND, health_component)
	EventBus.player_died.connect(_on_player_died)

	_setup_detection_shapes()

	if detection_area != null:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
	if stomp_hitbox != null:
		# Acerto do pisoteio reinicia a recarga
		stomp_hitbox.hit_landed.connect(_on_stomp_hit_landed)

	if state_machine != null:
		state_machine.start()


## Avisa slots vazios.
func _validar_referencias() -> void:
	var faltando: PackedStringArray = []
	if state_machine == null: faltando.append("state_machine")
	if health_component == null: faltando.append("health_component")
	if hurtbox == null: faltando.append("hurtbox")
	if detection_area == null: faltando.append("detection_area")
	if stomp_hitbox == null: faltando.append("stomp_hitbox")
	if dash_hitbox == null: faltando.append("dash_hitbox")
	if not faltando.is_empty():
		push_warning("TankEnemy '%s': referências não atribuídas no Inspector: %s" % [name, ", ".join(faltando)])


## Desconta as recargas.
func _physics_process(delta: float) -> void:
	if _dash_cooldown_left > 0.0:
		_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	if _stomp_cooldown_left > 0.0:
		_stomp_cooldown_left = maxf(_stomp_cooldown_left - delta, 0.0)


## Aplica os raios nas formas.
func _setup_detection_shapes() -> void:
	# Formas próprias com os raios dos exports
	CombatUtils.set_unique_circle_radius(detection_shape, detection_radius)
	CombatUtils.set_unique_circle_radius(attack_range_shape, attack_range_radius)
	CombatUtils.set_unique_circle_radius(stomp_shape, attack_range_radius)


## Tem player vivo para atacar.
func has_target() -> bool:
	return CombatUtils.is_targetable(player)


## Distância ao quadrado (INF sem alvo).
func distance_sq_to_player() -> float:
	return global_position.distance_squared_to(player.global_position) if has_target() else INF


## Investida fora da recarga.
func can_dash() -> bool:
	return _dash_cooldown_left <= 0.0


## Inicia a recarga da investida.
func start_dash_cooldown() -> void:
	_dash_cooldown_left = special_attack_cooldown


## Pisoteio fora da recarga.
func can_stomp() -> bool:
	return _stomp_cooldown_left <= 0.0


## Inicia a recarga do pisoteio.
func start_stomp_cooldown() -> void:
	_stomp_cooldown_left = maxf(stomp_pulse_interval, 0.05)


## Freia aos poucos.
func brake(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, move_speed * delta)


## true depois da morte.
func is_dead() -> bool:
	return _dead


## API de dano no corpo. false se morto.
func take_damage(amount: int, source: Variant = null) -> bool:
	if _dead or health_component == null:
		return false
	return health_component.take_damage(amount, source) > 0


## Guarda o player detectado (os estados decidem o resto).
func _on_detection_area_body_entered(body: Node2D) -> void:
	if CombatUtils.is_player(body):
		player = body


## Player saiu da detecção.
func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player:
		player = null


## Player morreu: esquece o alvo.
func _on_player_died() -> void:
	player = null


## Pisoteio acertou.
func _on_stomp_hit_landed(_target: Node, _damage_dealt: int) -> void:
	start_stomp_cooldown()


## Pisca ao levar dano.
func _on_damaged(_amount: int) -> void:
	_flash_white()


## Flash branco no sprite.
func _flash_white() -> void:
	if sprite == null:
		return
	_kill_flash()
	var alpha := sprite.modulate.a
	sprite.modulate = Color(3.0, 3.0, 3.0, alpha)
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, ^"modulate", Color(1.0, 1.0, 1.0, alpha), 0.15)


## Cancela o flash.
func _kill_flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()


## Morte: para tudo, desliga colisões e some com fade.
func _on_died() -> void:
	if _dead:
		return
	_dead = true
	died.emit()

	if state_machine != null:
		state_machine.die()
	set_physics_process(false)
	velocity = Vector2.ZERO
	if detection_area != null:
		detection_area.set_deferred(&"monitoring", false)
	if attack_range_area != null:
		attack_range_area.set_deferred(&"monitoring", false)
	if hurtbox != null:
		hurtbox.set_active(false)
	if stomp_hitbox != null:
		stomp_hitbox.set_active(false)
	if dash_hitbox != null:
		dash_hitbox.set_active(false)

	if sprite == null:
		queue_free()
		return
	_kill_flash()
	var death_tween := create_tween()
	death_tween.tween_property(sprite, ^"modulate:a", 0.0, 0.5)
	death_tween.tween_callback(queue_free)
