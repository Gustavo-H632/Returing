class_name GuideAttack
extends PooledArea
## Base dos ataques do Guide: uma Hitbox que só fica ligada durante a janela de dano.

@export_group("Referências (já ligadas na cena)")
@export var hitbox: Hitbox
@export var hit_shape: CollisionShape2D

## Quem criou o ataque (o dano é atribuído a ele e ele nunca é atingido).
var source: Node = null


func _ready() -> void:
	super._ready()
	if hitbox == null or hit_shape == null:
		push_error("GuideAttack '%s': 'hitbox' e 'hit_shape' precisam ser atribuídos no Inspector." % name)
		set_physics_process(false)
		return
	# Forma própria: as instâncias da mesma cena compartilhariam o mesmo recurso.
	hit_shape.shape = hit_shape.shape.duplicate() as Shape2D
	hitbox.damage_on_contact = true
	hitbox.one_hit_per_target = true
	hitbox.set_active(false)
	CombatUtils.connect_once(hitbox.hit_landed, _on_hitbox_hit_landed)


## Liga a hitbox com o dano pedido.
func arm(damage: int) -> void:
	if hitbox == null:
		return
	hitbox.damage = damage
	hitbox.source = source
	hitbox.set_active(true)


## Desliga a hitbox.
func disarm() -> void:
	if hitbox != null:
		hitbox.set_active(false)


## Raio da forma circular de dano (ajuste a cada disparo).
func set_hit_radius(radius: float) -> void:
	var circle := hit_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = maxf(radius, 0.0)


func _on_pool_deactivate() -> void:
	disarm()


## Acertou o player: subclasses decidem se o ataque some.
func _on_hitbox_hit_landed(_target: Area2D, _damage_dealt: int) -> void:
	pass
