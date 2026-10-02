class_name ChaserEnemy
extends CharacterBody2D
## Inimigo perseguidor: vaga, persegue e ataca de perto.
## Se o player foge da detecção, solta uma Onda de Energia.

signal health_changed(current_health: int, max_health: int)
signal died(enemy: ChaserEnemy)

const ENEMY_KIND: StringName = &"chaser"

@export_group("Movimento")
@export var move_speed: float = 120.0
@export var chase_speed_multiplier: float = 1.0

@export_group("Vida e Dano")
@export var max_health: int = 30
@export var base_damage: int = 10  ## Aplicado à ChaserHitbox.

@export_group("Ataque Corpo a Corpo")
@export var attack_windup_time: float = 0.4    ## Preparação antes do golpe.
@export var attack_hit_window: float = 0.15    ## Tempo em que a hitbox fica ligada.
@export var attack_cooldown_time: float = 0.6  ## Pausa depois do golpe.

@export_group("Onda de Energia")
@export var energy_wave_scene: PackedScene
@export var energy_wave_damage: int = 15
@export var energy_wave_expand_time: float = 0.6
## Raio usado se a detecção não for um círculo
@export var default_detection_radius: float = 150.0

var player_ref: Node2D = null
var player_in_detection: bool = false
var player_in_attack_range: bool = false
## true só se o player saiu vivo da visão (dispara a onda)
var player_fled: bool = false

## Referências de nós: arraste cada nó no Inspector.
@export_group("Referências (arraste os nós)")
@export var state_machine: ChaserStateMachine
@export var health: HealthComponent  ## Se vazio, um HealthComponent é criado por código.
@export var hurtbox: ChaserHurtbox
@export var hitbox: ChaserHitbox
@export var detection_area: Area2D
@export var detection_shape: CollisionShape2D  ## Define o raio da Onda de Energia.
@export var attack_range: Area2D
@export var sprite: AnimatedSprite2D  ## Opcional.

var current_health: int:
	get:
		return health.current_health if health != null else 0

var _detection_radius: float = 150.0
var _dead: bool = false


## Entra no grupo enemy.
func _enter_tree() -> void:
	add_to_group(CombatUtils.GROUP_ENEMY)


## Vida, hitbox, sensores, eventos e state.
func _ready() -> void:
	_validar_referencias()
	_setup_health()

	_detection_radius = CombatUtils.get_circle_radius(detection_shape, default_detection_radius)

	if hitbox != null:
		hitbox.damage = base_damage
		hitbox.deactivate()

	if detection_area != null:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)
	if attack_range != null:
		attack_range.body_entered.connect(_on_attack_range_body_entered)
		attack_range.body_exited.connect(_on_attack_range_body_exited)

	EnemyEvents.bind(self, ENEMY_KIND, health)
	EventBus.player_died.connect(_on_player_died)

	if state_machine != null:
		state_machine.start()


## Avisa slots vazios.
func _validar_referencias() -> void:
	var faltando: PackedStringArray = []
	if state_machine == null: faltando.append("state_machine")
	if hurtbox == null: faltando.append("hurtbox")
	if hitbox == null: faltando.append("hitbox")
	if detection_area == null: faltando.append("detection_area")
	if attack_range == null: faltando.append("attack_range")
	if not faltando.is_empty():
		push_warning("ChaserEnemy '%s': referências não atribuídas no Inspector: %s" % [name, ", ".join(faltando)])


## Cria a vida se faltar e liga os sinais.
func _setup_health() -> void:
	if health == null:
		health = HealthComponent.new()
		health.name = &"HealthComponent"
		add_child(health)
	health.setup(max_health)
	health.health_changed.connect(func(cur: int, mx: int) -> void: health_changed.emit(cur, mx))
	health.died.connect(die)


## Tem player vivo.
func has_target() -> bool:
	return CombatUtils.is_targetable(player_ref)


## Player na visão e vivo.
func can_see_player() -> bool:
	return player_in_detection and has_target()


## true depois da morte.
func is_dead() -> bool:
	return _dead


## Para no lugar.
func stop_moving() -> void:
	velocity = Vector2.ZERO
	move_and_slide()


## Anda até um ponto.
func move_towards(target_position: Vector2, speed: float) -> void:
	var to_target := target_position - global_position
	velocity = to_target.normalized() * speed if to_target.length_squared() > 0.0001 else Vector2.ZERO
	face_direction(velocity)
	move_and_slide()


## Vira o sprite conforme a direção do movimento.
func face_direction(direction: Vector2) -> void:
	if sprite != null and absf(direction.x) > 0.01:
		sprite.flip_h = direction.x < 0.0


## Vira para o player.
func face_player() -> void:
	if has_target():
		face_direction(player_ref.global_position - global_position)


## API de dano. false se morto.
func take_damage(amount: int, source: Variant = null) -> bool:
	if _dead or health == null:
		return false
	return health.take_damage(amount, source) > 0


## Morte: trava a state, desliga colisões e some.
func die() -> void:
	if _dead:
		return
	_dead = true
	died.emit(self)
	set_physics_process(false)
	if state_machine != null:
		state_machine.die()
	if hurtbox != null:
		hurtbox.set_active(false)
	if hitbox != null:
		hitbox.deactivate()
	set_deferred(&"collision_layer", 0)
	set_deferred(&"collision_mask", 0)
	queue_free()


## Cria a onda com o raio da visão.
func fire_energy_wave() -> void:
	if energy_wave_scene == null:
		push_warning("[%s] energy_wave_scene não configurado no Inspector." % name)
		return
	var wave := CombatUtils.spawn(energy_wave_scene, self, global_position, EnergyWave) as EnergyWave
	if wave != null:
		wave.setup(_detection_radius, energy_wave_damage, energy_wave_expand_time, self)


## Player entrou na visão.
func _on_detection_body_entered(body: Node2D) -> void:
	if CombatUtils.is_player(body):
		player_ref = body
		player_in_detection = true
		player_fled = false


## Player saiu da visão.
func _on_detection_body_exited(body: Node2D) -> void:
	if body == player_ref:
		player_fled = CombatUtils.is_targetable(body)
		player_in_detection = false
		player_ref = null


## Perdeu a visão: fuga = onda, morte = Idle.
func lost_target_state() -> StringName:
	return &"EnergyWaveState" if player_fled else &"IdleState"


## Player no alcance do golpe.
func _on_attack_range_body_entered(body: Node2D) -> void:
	if CombatUtils.is_player(body):
		player_in_attack_range = true


## Player fora do alcance.
func _on_attack_range_body_exited(body: Node2D) -> void:
	if CombatUtils.is_player(body):
		player_in_attack_range = false


## Player morreu: limpa as flags.
func _on_player_died() -> void:
	player_ref = null
	player_in_detection = false
	player_in_attack_range = false
	player_fled = false
