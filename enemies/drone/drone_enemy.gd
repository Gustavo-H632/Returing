class_name DroneEnemy
extends EnemyBase
## Seguidor (melee) — sprite drone.png.

## Raio usado se a forma da Range 2 não for um círculo.
const DEFAULT_RANGE2_RADIUS: float = 110.0

@export_group("Perseguição")
@export var chase_speed_multiplier: float = 1.0

@export_group("Ataque Corpo a Corpo")
@export var attack_damage: int = 10
## Preparação (telegrafada pela animação).
@export var attack_windup_time: float = 0.35
## Tempo com a hitbox ligada.
@export var attack_hit_window: float = 0.15
## Recuperação após o golpe.
@export var attack_cooldown_time: float = 0.6

@export_group("Range 2 (onda de choque)")
@export var wave_scene: PackedScene
@export var wave_damage: int = 8
## Intervalo mínimo entre ondas (evita rajada se o player oscilar na borda).
@export_range(0.0, 5.0, 0.05) var wave_cooldown: float = 0.4

@export_group("Referências (já ligadas na cena)")
@export var attack_range: Area2D
@export var attack_hitbox: Hitbox
@export var range2_area: Area2D
@export var range2_shape: CollisionShape2D

var target_in_attack_range: bool = false

## Recarga da onda em segundos de jogo.
var _wave_cooldown_left: float = 0.0


func _on_enemy_ready() -> void:
	if attack_hitbox != null:
		attack_hitbox.damage = attack_damage
		attack_hitbox.set_active(false)
	if attack_range != null:
		CombatUtils.connect_once(attack_range.body_entered, _on_attack_range_body_entered)
		CombatUtils.connect_once(attack_range.body_exited, _on_attack_range_body_exited)
	if range2_area != null:
		CombatUtils.connect_once(range2_area.body_entered, _on_range2_body_entered)
		CombatUtils.connect_once(range2_area.body_exited, _on_range2_body_exited)


## Desconta a recarga da onda de choque.
func _physics_process(delta: float) -> void:
	_wave_cooldown_left = maxf(_wave_cooldown_left - delta, 0.0)


func can_see_target() -> bool:
	return has_target()


## Raio atual da Range 2 (é também a distância máxima percorrida pela onda).
func get_range2_radius() -> float:
	return CombatUtils.get_circle_radius(range2_shape, DEFAULT_RANGE2_RADIUS)


func drop_target() -> void:
	super.drop_target()
	target_in_attack_range = false


# --- Attack Range ---

func _on_attack_range_body_entered(body: Node2D) -> void:
	if CombatUtils.is_player(body):
		target_in_attack_range = true


func _on_attack_range_body_exited(body: Node2D) -> void:
	if CombatUtils.is_player(body):
		target_in_attack_range = false


# --- Range 2 ---

func _on_range2_body_entered(body: Node2D) -> void:
	if CombatUtils.is_player(body):
		_launch_wave(body.global_position)


## O player pode sair da árvore/morrer ao mesmo tempo: só confere o grupo.
func _on_range2_body_exited(body: Node2D) -> void:
	if CombatUtils.is_valid(body) and body.is_in_group(CombatUtils.GROUP_PLAYER):
		_launch_wave(body.global_position)


## Lança a onda de choque na direção do player.
func _launch_wave(aim_at: Vector2) -> void:
	if is_dead() or _wave_cooldown_left > 0.0:
		return
	_wave_cooldown_left = maxf(wave_cooldown, 0.0)
	var wave := CombatUtils.spawn(wave_scene, self, global_position, ShockWave) as ShockWave
	if wave == null:
		return
	wave.launch(global_position.direction_to(aim_at), get_range2_radius(), wave_damage, self)
