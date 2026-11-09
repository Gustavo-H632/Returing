class_name GuideAttack
extends PooledArea
## Base dos ataques do Guide: uma Hitbox que só fica ligada durante a janela de dano.

@export_group("Referências (já ligadas na cena)")
@export var hitbox: Hitbox  # Hitbox que causa o dano.
@export var hit_shape: CollisionShape2D  # Forma da hitbox (cada instância tem a sua).

## Quem criou o ataque (o dano é atribuído a ele e ele nunca é atingido).
var source: Node = null


## Prepara a hitbox: forma própria, dano ao encostar, um acerto por alvo e começa desligada.
func _ready() -> void:
	super._ready()  # Prepara o PooledArea.
	if hitbox == null or hit_shape == null:  # Sem hitbox ou forma, o ataque não funciona.
		# Avisa o erro.
		push_error("GuideAttack '%s': 'hitbox' e 'hit_shape' precisam ser atribuídos no Inspector." % name)
		set_physics_process(false)  # Desliga a física.
		return
	# Forma própria: as instâncias da mesma cena compartilhariam o mesmo recurso.
	hit_shape.shape = hit_shape.shape.duplicate() as Shape2D  # Copia a forma para cada instância ter a sua.
	hitbox.damage_on_contact = true  # Dano ao encostar.
	hitbox.one_hit_per_target = true  # Um acerto por alvo.
	hitbox.set_active(false)  # Começa desligada (só liga na janela de dano).
	CombatUtils.connect_once(hitbox.hit_landed, _on_hitbox_hit_landed)  # Escuta os acertos.


## Liga a hitbox com o dano pedido.
## Liga a hitbox com o dano pedido (começa a janela de dano).
func arm(damage: int) -> void:
	if hitbox == null:  # Sem hitbox: nada a fazer.
		return
	hitbox.damage = damage  # Dano.
	hitbox.source = source  # Quem causa o dano.
	hitbox.set_active(true)  # Liga.


## Desliga a hitbox.
## Desliga a hitbox (fim da janela de dano).
func disarm() -> void:
	if hitbox != null:  # Hitbox existe.
		hitbox.set_active(false)  # Desliga.


## Raio da forma circular de dano (ajuste a cada disparo).
## Ajusta o raio da forma circular (cada disparo pode ter um raio diferente).
func set_hit_radius(radius: float) -> void:
	var circle := hit_shape.shape as CircleShape2D  # Forma como círculo.
	if circle != null:  # Só se for círculo.
		circle.radius = maxf(radius, 0.0)  # Raio nunca negativo.


## Ao voltar ao pool, desliga a hitbox.
func _on_pool_deactivate() -> void:
	disarm()  # Desliga.


## Acertou o player: subclasses decidem se o ataque some.
## Gancho vazio: as subclasses decidem se o ataque some ao acertar.
func _on_hitbox_hit_landed(_target: Area2D, _damage_dealt: int) -> void:
	pass
