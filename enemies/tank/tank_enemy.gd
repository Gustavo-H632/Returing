class_name TankEnemy
extends EnemyBase
## Tank (Pesado) — sprite tank.png.
## Lento e resistente. Pisoteio em área quando perto e investida (bull dash) quando longe.
## Ataques PROPORCIONAIS AO TAMANHO: dano e raio escalam com size_factor, calculado a
## partir do raio do corpo (derivado do tamanho real do sprite).

## Raio de corpo considerado "tamanho 1.0".
const REFERENCE_BODY_RADIUS: float = 16.0

@export_group("Detecção")
@export var detection_radius: float = 420.0

@export_group("Pisoteio (área)")
@export var stomp_base_damage: int = 12
## Raio do pisoteio = raio do corpo × este fator.
@export var stomp_radius_factor: float = 2.6
@export var stomp_pulse_interval: float = 1.0
@export var stomp_windup_time: float = 0.35

@export_group("Investida (Special Attack)")
@export var dash_base_damage: int = 30
@export var min_distance_for_dash: float = 260.0
@export var dash_prepare_time: float = 0.8
@export var dash_duration: float = 0.75  ## 520 px/s × 0.75 s ≈ 390 px: cobre a faixa de investida.
@export var dash_speed: float = 520.0
@export var special_attack_cooldown: float = 2.0

@export_group("Vagar")
@export var wander_radius: float = 110.0
@export var wander_speed_multiplier: float = 0.35

@export_group("Referências (já ligadas na cena)")
@export var stomp_hitbox: Hitbox
@export var stomp_shape: CollisionShape2D
@export var dash_hitbox: Hitbox
@export var detection_shape: CollisionShape2D

## Calculados em _on_enemy_ready a partir do tamanho do corpo.
var size_factor: float = 1.0
var stomp_radius: float = 64.0
var stomp_damage: int = 10
var dash_damage: int = 25
var dash_direction: Vector2 = Vector2.ZERO

var _dash_cooldown_left: float = 0.0
var _stomp_cooldown_left: float = 0.0


func _on_enemy_ready() -> void:
	var body_radius: float = CombatUtils.get_circle_radius(body_collision, REFERENCE_BODY_RADIUS)
	size_factor = maxf(body_radius / REFERENCE_BODY_RADIUS, 0.25)
	stomp_radius = body_radius * stomp_radius_factor
	stomp_damage = roundi(stomp_base_damage * size_factor)
	dash_damage = roundi(dash_base_damage * size_factor)

	CombatUtils.set_unique_circle_radius(detection_shape, detection_radius)
	CombatUtils.set_unique_circle_radius(stomp_shape, stomp_radius)
	if stomp_hitbox != null:
		stomp_hitbox.damage = stomp_damage
		stomp_hitbox.damage_on_contact = false  # dano vem dos pulsos
		stomp_hitbox.set_active(false)
		CombatUtils.connect_once(stomp_hitbox.hit_landed, _on_stomp_hit_landed)
	if dash_hitbox != null:
		dash_hitbox.damage = dash_damage
		dash_hitbox.set_active(false)


func _physics_process(delta: float) -> void:
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	_stomp_cooldown_left = maxf(_stomp_cooldown_left - delta, 0.0)


func can_dash() -> bool:
	return _dash_cooldown_left <= 0.0


func start_dash_cooldown() -> void:
	_dash_cooldown_left = special_attack_cooldown


func can_stomp() -> bool:
	return _stomp_cooldown_left <= 0.0


func start_stomp_cooldown() -> void:
	_stomp_cooldown_left = maxf(stomp_pulse_interval, 0.05)


func _on_stomp_hit_landed(_target: Area2D, _damage_dealt: int) -> void:
	start_stomp_cooldown()
