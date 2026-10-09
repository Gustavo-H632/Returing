class_name DroneEnemy
extends EnemyBase
## Perseguidor (Melee) — sprite drone.png.
## Vaga até ver o player, persegue e ataca por contato. NÃO dispara projéteis.

@export_group("Perseguição")
@export var chase_speed_multiplier: float = 1.0
@export var wander_speed_multiplier: float = 0.35

@export_group("Ataque Corpo a Corpo")
@export var attack_damage: int = 10
@export var attack_windup_time: float = 0.35   ## Preparação (telegrafada pela animação).
@export var attack_hit_window: float = 0.15    ## Hitbox ligada.
@export var attack_cooldown_time: float = 0.6  ## Recuperação após o golpe.

@export_group("Referências (já ligadas na cena)")
@export var attack_range: Area2D
@export var attack_hitbox: Hitbox

var target_in_attack_range: bool = false


func _on_enemy_ready() -> void:
	if attack_hitbox != null:
		attack_hitbox.damage = attack_damage
		attack_hitbox.set_active(false)
	if attack_range != null:
		CombatUtils.connect_once(attack_range.body_entered, _on_attack_range_body_entered)
		CombatUtils.connect_once(attack_range.body_exited, _on_attack_range_body_exited)


func can_see_target() -> bool:
	return has_target()


func _on_attack_range_body_entered(body: Node2D) -> void:
	if CombatUtils.is_player(body):
		target_in_attack_range = true


func _on_attack_range_body_exited(body: Node2D) -> void:
	if CombatUtils.is_player(body):
		target_in_attack_range = false


func drop_target() -> void:
	super.drop_target()
	target_in_attack_range = false
