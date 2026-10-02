class_name RangedEnemy
extends CharacterBody2D
## Inimigo atirador: persegue até a distância de tiro e atira.
## Perto do player usa o ataque em área; ao morrer deixa uma armadilha elétrica.

signal died

const ENEMY_KIND: StringName = &"shooter"

@export_group("Movimento")
@export var move_speed: float = 120.0

@export_group("Ataque à Distância")
@export var projectile_scene: PackedScene
@export var ranged_attack_distance: float = 350.0
@export var ranged_attack_cooldown: float = 1.4

@export_group("Ataque Corpo a Corpo")
@export var melee_telegraph_scene: PackedScene
@export var melee_telegraph_time: float = 1.0
@export var melee_damage: int = 25
@export var melee_attack_cooldown: float = 1.8

@export_group("Morte")
@export var electric_trap_scene: PackedScene

## Referências de nós: arraste cada nó no Inspector.
@export_group("Referências (arraste os nós)")
@export var state_machine: ShooterStateMachine
@export var health: ShooterHealthComponent
@export var hurtbox: ShooterHurtbox
@export var detection_area: Area2D
@export var melee_range_area: Area2D
@export var projectile_spawn_point: Marker2D  ## Opcional.
@export var body_collision: CollisionShape2D  ## Opcional (desligado ao morrer).
@export var animation_player: AnimationPlayer  ## Opcional (animação "death").

## Aggro permanente: não esquece o player ao sair da área
var target: Node2D = null
var has_aggro: bool = false
var is_player_in_melee_range: bool = false

var _dead: bool = false


## Entra no grupo enemy.
func _enter_tree() -> void:
	add_to_group(CombatUtils.GROUP_ENEMY)


## Sensores, vida, eventos e state.
func _ready() -> void:
	_validar_referencias()

	if detection_area != null:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
	if melee_range_area != null:
		melee_range_area.body_entered.connect(_on_melee_range_body_entered)
		melee_range_area.body_exited.connect(_on_melee_range_body_exited)
	if health != null:
		health.died.connect(_on_health_died)
		# A Hurtbox entrega o dano direto na vida
		if hurtbox != null and hurtbox.health_component == null:
			hurtbox.health_component = health
	EnemyEvents.bind(self, ENEMY_KIND, health)
	EventBus.player_died.connect(_on_player_died)

	if state_machine != null:
		state_machine.start()


## Avisa slots vazios.
func _validar_referencias() -> void:
	var faltando: PackedStringArray = []
	if state_machine == null: faltando.append("state_machine")
	if health == null: faltando.append("health")
	if hurtbox == null: faltando.append("hurtbox")
	if detection_area == null: faltando.append("detection_area")
	if melee_range_area == null: faltando.append("melee_range_area")
	if not faltando.is_empty():
		push_warning("RangedEnemy '%s': referências não atribuídas no Inspector: %s" % [name, ", ".join(faltando)])


## Tem player vivo.
func has_target() -> bool:
	return CombatUtils.is_targetable(target)


## Esquece o alvo.
func drop_target() -> void:
	target = null
	has_aggro = false
	is_player_in_melee_range = false


## Distância ao quadrado (INF sem alvo).
func distance_sq_to_target() -> float:
	return global_position.distance_squared_to(target.global_position) if has_target() else INF


## Alvo no alcance de tiro.
func is_target_in_ranged_distance(multiplier: float = 1.0) -> bool:
	var max_dist := ranged_attack_distance * multiplier
	return distance_sq_to_target() <= max_dist * max_dist


## Ponto de saída do tiro.
func get_projectile_origin() -> Vector2:
	return projectile_spawn_point.global_position if projectile_spawn_point != null else global_position


## Para no lugar.
func stop_moving() -> void:
	velocity = Vector2.ZERO
	move_and_slide()


## true depois da morte.
func is_dead() -> bool:
	return _dead


## API de dano no corpo. false se morto.
func take_damage(amount: int, source: Variant = null) -> bool:
	if _dead or health == null:
		return false
	return health.take_damage(amount, source) > 0


## Viu o player: ganha aggro.
func _on_detection_area_body_entered(body: Node) -> void:
	if CombatUtils.is_player(body):
		target = body as Node2D
		has_aggro = true


## Player perto.
func _on_melee_range_body_entered(body: Node) -> void:
	if CombatUtils.is_player(body):
		is_player_in_melee_range = true


## Player saiu de perto.
func _on_melee_range_body_exited(body: Node) -> void:
	if CombatUtils.is_player(body):
		is_player_in_melee_range = false


## Player morreu: esquece o aggro.
func _on_player_died() -> void:
	drop_target()


## Morte: estado Death.
func _on_health_died() -> void:
	if _dead:
		return
	_dead = true
	died.emit()
	if state_machine != null:
		state_machine.die()  # entra em Death e trava a state
	else:
		queue_free()
