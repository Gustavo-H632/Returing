class_name PlayerProjectile
extends Area2D
## Projétil do tiro carregado. Configurado antes de entrar na árvore.

@export var speed: float = 300.0
@export var lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT
var damage: int = 0
var shooter: Node = null

var _life_left: float = 0.0
var _consumido: bool = false


## Normaliza a direção e conecta as colisões.
func _ready() -> void:
	direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	rotation = direction.angle()
	_life_left = lifetime
	monitorable = false
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


## Move em linha reta até acabar o tempo de vida.
func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_life_left -= delta
	if _life_left <= 0.0:
		_consumir()


## Bateu em corpo: dano se der e some.
func _on_body_entered(body: Node2D) -> void:
	if _consumido or body == shooter:
		return  # nunca colide com quem atirou
	if CombatUtils.can_take_damage(body):
		_aplicar_dano(body, body)
	_consumir()  # parede ou corpo atingido


## Bateu em hurtbox: dano e some.
func _on_area_entered(area: Area2D) -> void:
	# Atravessa áreas que não são Hurtbox
	if _consumido or not area.is_in_group(CombatUtils.GROUP_HURTBOX):
		return
	var raiz := CombatUtils.get_actor(area)
	if raiz == shooter:
		return
	_aplicar_dano(area, raiz)
	_consumir()


## Dano em nome do atirador.
func _aplicar_dano(alvo: Node, notificar: Node) -> void:
	if CombatUtils.is_alive(shooter) and shooter.has_method(&"causar_dano"):
		shooter.call(&"causar_dano", alvo, damage, notificar)  # passa pelo player para avisar a HUD
	else:
		CombatUtils.apply_damage(alvo, damage, self)


## Some uma única vez.
func _consumir() -> void:
	if _consumido:
		return
	_consumido = true
	set_physics_process(false)
	set_deferred(&"monitoring", false)
	queue_free()
