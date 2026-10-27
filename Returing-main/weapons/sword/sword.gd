class_name Sword
extends Weapon
## Espada: golpe em 3 fases controladas por corrotina (await).

enum Phase { IDLE, WINDUP, ACTIVE, RECOVERY }

const SLASH_ANIMATION: StringName = &"slash"
## Raio da hitbox do golpe (px). O chefão Guide usa um múltiplo dele.
const HITBOX_RADIUS: float = 28.0
## Distância do centro da arma ao centro da hitbox e do efeito visual (px).
const HITBOX_DISTANCE: float = 34.0

@export_group("Tempo do golpe")
@export_range(0.0, 1.0, 0.01) var windup_time: float = 0.08
@export_range(0.01, 1.0, 0.01) var active_time: float = 0.14
@export_range(0.0, 1.0, 0.01) var recovery_time: float = 0.16

@export_group("Referências (já ligadas na cena)")
@export var hitbox: Hitbox
@export var hitbox_shape: CollisionShape2D
@export var slash_sprite: Sprite2D
@export var animation_player: AnimationPlayer

var phase: Phase = Phase.IDLE

var _swing_id: int = 0


func _ready() -> void:
	super._ready()
	if hitbox == null:
		push_warning("Sword '%s': 'hitbox' não atribuída." % name)
		return
	_apply_hitbox_size()
	hitbox.active_on_start = false
	hitbox.one_hit_per_target = true
	hitbox.damage_on_contact = true
	hitbox.set_active(false)
	CombatUtils.connect_once(hitbox.hit_landed, _on_hitbox_hit_landed)
	if slash_sprite != null:
		slash_sprite.visible = false


## Aplica o tamanho do golpe (HITBOX_RADIUS) na forma de colisão e no efeito visual.
func _apply_hitbox_size() -> void:
	CombatUtils.set_unique_circle_radius(hitbox_shape, HITBOX_RADIUS)
	hitbox.position.x = HITBOX_DISTANCE
	if slash_sprite != null:
		slash_sprite.position.x = HITBOX_DISTANCE


func get_attack_duration() -> float:
	return windup_time + active_time + recovery_time


func _on_equipped() -> void:
	if hitbox != null:
		hitbox.source = wielder  # nunca acerta a Hurtbox de quem empunha


## Gira a espada para a nova mira.
func aim_at(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	if phase == Phase.WINDUP or phase == Phase.ACTIVE:
		rotation = direction.angle()


func _start_attack(direction: Vector2) -> void:
	_swing_id += 1
	rotation = direction.angle()
	if hitbox != null:
		hitbox.damage = damage
	_play_slash()
	_run_swing(_swing_id)


func _stop_attack() -> void:
	_swing_id += 1  # invalida a corrotina em andamento
	_close_hit_window()
	phase = Phase.IDLE
	if animation_player != null:
		animation_player.stop()
	if slash_sprite != null:
		slash_sprite.visible = false


## Corrotina do golpe.
func _run_swing(id: int) -> void:
	phase = Phase.WINDUP
	if not await _wait(windup_time, id):
		return

	phase = Phase.ACTIVE
	_open_hit_window()
	if not await _wait(active_time, id):
		return
	_close_hit_window()

	phase = Phase.RECOVERY
	if not await _wait(recovery_time, id):
		return

	phase = Phase.IDLE
	_finish(true)


## Espera em tempo de física respeitando a pausa.
func _wait(seconds: float, id: int) -> bool:
	if seconds > 0.0:
		if not is_inside_tree():
			return false
		await get_tree().create_timer(seconds, false, true).timeout
	return id == _swing_id and is_inside_tree()


func _open_hit_window() -> void:
	if hitbox != null:
		hitbox.set_active(true)


func _close_hit_window() -> void:
	if hitbox != null and hitbox.is_active():
		hitbox.set_active(false)


func _play_slash() -> void:
	if animation_player == null or not animation_player.has_animation(SLASH_ANIMATION):
		return
	animation_player.stop()
	animation_player.play(SLASH_ANIMATION)


func _on_hitbox_hit_landed(target: Area2D, damage_dealt: int) -> void:
	var victim: Node = CombatUtils.get_actor(target)
	hit_landed.emit(victim if victim != null else target, damage_dealt)
