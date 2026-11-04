class_name PlayerProjectile
extends PooledArea
## Tiro carregado do player (reaproveitado pelo PoolHub).

## Avisa quem atirou que o tiro acertou.
signal damage_dealt(target: Node, amount: int)

## Raio do tiro com 0% de carga (igual ao CircleShape2D da cena): a largura base do ataque do player.
const BASE_RADIUS: float = 5.0
## Escala do tiro com 100% de carga, em relação ao tamanho mínimo.
const MAX_CHARGE_SCALE: float = 3.0

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


func _ready() -> void:
	super._ready()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


## Dispara o tiro de `origin` na direção `aim`; a carga (0.0 a 1.0) define o tamanho.
func launch(origin: Vector2, aim: Vector2, new_damage: int, charge_ratio: float, from_shooter: Node) -> void:
	global_position = origin
	direction = aim.normalized() if aim != Vector2.ZERO else Vector2.RIGHT
	global_rotation = direction.angle()
	damage = new_damage
	shooter = from_shooter
	apply_charge(charge_ratio)
	_life_left = lifetime
	_consumido = false


## Escala o tiro pela carga: 0.0 = tamanho mínimo, 1.0 = MAX_CHARGE_SCALE vezes o mínimo.
func apply_charge(ratio: float) -> void:
	scale = Vector2.ONE * lerpf(1.0, MAX_CHARGE_SCALE, clampf(ratio, 0.0, 1.0))


## Anda em linha reta até bater ou acabar o tempo.
func _physics_process(delta: float) -> void:
	# Testa o trecho todo.
	if CombatUtils.move_until_wall(self, direction * speed * delta, wall_mask):
		_consumir()
		return
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


## Volta ao pool uma vez só.
func _consumir() -> void:
	if _consumido:
		return
	_consumido = true
	recycle()
