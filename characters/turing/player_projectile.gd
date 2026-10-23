class_name PlayerProjectile
extends Area2D
## Tiro carregado do player.

## Avisa quem atirou que o tiro acertou.
signal damage_dealt(target: Node, amount: int)

@export var speed: float = 300.0
@export var lifetime: float = 2.0
## Camadas que contam como parede.
@export_flags_2d_physics var wall_mask: int = 1

## Direção fixa, decidida no disparo.
var direction: Vector2 = Vector2.RIGHT
var damage: int = 0
var shooter: Node = null

var _life_left: float = 0.0
var _consumido: bool = false


## Prepara o tiro.
func _ready() -> void:
	direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	global_rotation = direction.angle()
	_life_left = lifetime
	monitorable = false
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


## Anda em linha reta até bater ou acabar o tempo.
func _physics_process(delta: float) -> void:
	var alvo: Vector2 = global_position + direction * speed * delta
	# Testa o trecho todo.
	var parede: Dictionary = CombatUtils.trace_wall(self, global_position, alvo, wall_mask)
	if not parede.is_empty():
		global_position = parede["position"]
		_consumir()
		return
	global_position = alvo
	_life_left -= delta
	if _life_left <= 0.0:
		_consumir()


## Bateu em um corpo.
func _on_body_entered(body: Node2D) -> void:
	if _consumido or body == shooter:
		return
	if CombatUtils.can_take_damage(body):
		_aplicar_dano(body, body)
	_consumir()


## Bateu em uma hurtbox.
func _on_area_entered(area: Area2D) -> void:
	if _consumido or not area.is_in_group(CombatUtils.GROUP_HURTBOX):
		return
	var raiz := CombatUtils.get_actor(area)
	if raiz == shooter:
		return
	_aplicar_dano(area, raiz)
	_consumir()


## Aplica o dano em nome de quem atirou.
func _aplicar_dano(alvo: Node, notificar: Node) -> void:
	var origem: Node = shooter if CombatUtils.is_alive(shooter) else self
	if CombatUtils.apply_damage(alvo, damage, origem):
		damage_dealt.emit(notificar, damage)


## Some uma vez só.
func _consumir() -> void:
	if _consumido:
		return
	_consumido = true
	set_physics_process(false)
	set_deferred(&"monitoring", false)
	queue_free()
