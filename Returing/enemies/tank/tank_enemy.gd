class_name TankEnemy
extends EnemyBase
## Tank (Pesado) — sprite tank.png.

## Raio de corpo considerado "tamanho 1.0".
const REFERENCE_BODY_RADIUS: float = 16.0

@export_group("Detecção")
@export var detection_radius: float = 420.0  # Raio da área de detecção do jogador.

@export_group("Pisoteio (área)")
@export var stomp_base_damage: int = 12  # Dano do pisoteio para um corpo de tamanho 1.0.
## Raio do pisoteio = raio do corpo × este fator.
@export var stomp_radius_factor: float = 2.6
@export var stomp_pulse_interval: float = 1.0  # Intervalo entre pulsos de pisoteio.
@export var stomp_windup_time: float = 0.35  # Preparação antes do primeiro pisoteio.

@export_group("Investida (Special Attack)")
@export var dash_base_damage: int = 30  # Dano da investida para um corpo de tamanho 1.0.
@export var min_distance_for_dash: float = 260.0  # Distância mínima ao jogador para poder investir.
@export var dash_prepare_time: float = 0.8  # Tempo de preparação (aviso) antes da investida.
@export var dash_duration: float = 0.75  # 520 px/s × 0.75 s ≈ 390 px: cobre a faixa de investida.
@export var dash_speed: float = 520.0  # Velocidade da investida.
@export var special_attack_cooldown: float = 2.0  # Recarga entre investidas.

@export_group("Referências (já ligadas na cena)")
@export var stomp_hitbox: Hitbox  # Hitbox do pisoteio (em área).
@export var stomp_shape: CollisionShape2D  # Forma do pisoteio (recebe o raio calculado).
@export var dash_hitbox: Hitbox  # Hitbox da investida.
@export var detection_shape: CollisionShape2D  # Forma da área de detecção.

## Calculados em _on_enemy_ready a partir do tamanho do corpo.
var size_factor: float = 1.0
var stomp_radius: float = 64.0  # Raio do pisoteio já calculado (px).
var stomp_damage: int = 10  # Dano do pisoteio já escalado pelo tamanho.
var dash_damage: int = 25  # Dano da investida já escalado pelo tamanho.
var dash_direction: Vector2 = Vector2.ZERO  # Direção da investida atual.

var _dash_cooldown_left: float = 0.0  # Tempo restante da recarga da investida.
var _stomp_cooldown_left: float = 0.0  # Tempo restante da recarga do pisoteio.


## Prepara o Tank: calcula tamanho, raios e danos a partir do corpo e configura as hitboxes e áreas.
func _on_enemy_ready() -> void:
	# Raio do corpo (ou o de referência).
	var body_radius: float = CombatUtils.get_circle_radius(body_collision, REFERENCE_BODY_RADIUS)
	# Fator de tamanho (nunca menor que 0,25).
	size_factor = maxf(body_radius / REFERENCE_BODY_RADIUS, 0.25)
	stomp_radius = body_radius * stomp_radius_factor  # Raio do pisoteio.
	stomp_damage = roundi(stomp_base_damage * size_factor)  # Dano do pisoteio escalado.
	dash_damage = roundi(dash_base_damage * size_factor)  # Dano da investida escalado.

	# Área de detecção com o raio configurado.
	CombatUtils.set_unique_circle_radius(detection_shape, detection_radius)
	# Forma do pisoteio com o raio calculado.
	CombatUtils.set_unique_circle_radius(stomp_shape, stomp_radius)
	if stomp_hitbox != null:  # Hitbox do pisoteio existe.
		stomp_hitbox.damage = stomp_damage  # Dano do pisoteio.
		stomp_hitbox.damage_on_contact = false  # dano vem dos pulsos
		stomp_hitbox.set_active(false)  # Começa desligada.
		# Cada acerto reinicia a recarga do pisoteio.
		CombatUtils.connect_once(stomp_hitbox.hit_landed, _on_stomp_hit_landed)
	if dash_hitbox != null:  # Hitbox da investida existe.
		dash_hitbox.damage = dash_damage  # Dano da investida.
		dash_hitbox.set_active(false)  # Começa desligada.


## A cada quadro de física desconta as recargas da investida e do pisoteio.
func _physics_process(delta: float) -> void:
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)  # Recarga da investida.
	_stomp_cooldown_left = maxf(_stomp_cooldown_left - delta, 0.0)  # Recarga do pisoteio.


## Diz se a investida já esfriou.
func can_dash() -> bool:
	return _dash_cooldown_left <= 0.0


## Começa a recarga da investida.
func start_dash_cooldown() -> void:
	_dash_cooldown_left = special_attack_cooldown


## Diz se o pisoteio já esfriou.
func can_stomp() -> bool:
	return _stomp_cooldown_left <= 0.0


## Começa a recarga do pisoteio (nunca menos que 0,05 s).
func start_stomp_cooldown() -> void:
	_stomp_cooldown_left = maxf(stomp_pulse_interval, 0.05)


## Um pisoteio acertou o jogador: reinicia a recarga.
func _on_stomp_hit_landed(_target: Area2D, _damage_dealt: int) -> void:
	start_stomp_cooldown()
