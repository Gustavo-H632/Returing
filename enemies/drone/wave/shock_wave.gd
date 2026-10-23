class_name ShockWave
extends Area2D
## Onda de choque do Seguidor (Drone).

## Quadros da onda na spritesheet Laser1_sprite (4 colunas, células de 368 px).
const SHEET_COLUMNS: int = 4
const CELL_SIZE: Vector2 = Vector2(368.0, 368.0)
const FIRST_FRAME: int = 3
const LAST_FRAME: int = 9
const FRAMES_PER_SECOND: float = 12.0

@export var speed: float = 260.0
## Camadas tratadas como parede (1 = Mundo).
@export_flags_2d_physics var wall_mask: int = 1
## Componentes da cena (arraste no Inspector).
@export var hitbox: Hitbox
@export var sprite: Sprite2D

var shooter: Node = null

var _direction: Vector2 = Vector2.RIGHT
var _remaining: float = 0.0
var _damage: int = 0
var _elapsed: float = 0.0
var _frame: int = -1
var _consumed: bool = false


## Configura a onda (antes ou depois de entrar na árvore).
func launch(direction: Vector2, travel_distance: float, damage: int, from_shooter: Node = null) -> void:
	_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	_remaining = maxf(travel_distance, 0.0)
	_damage = damage
	shooter = from_shooter
	if is_inside_tree():
		global_rotation = _direction.angle()
	else:
		rotation = _direction.angle()  # fora da árvore não há transform global
	if hitbox != null:
		hitbox.source = shooter  # nunca acerta quem lançou a onda


func _ready() -> void:
	monitorable = false
	if hitbox == null or sprite == null:
		push_error("ShockWave: 'hitbox' e 'sprite' precisam ser atribuídos no Inspector.")
		queue_free()
		return
	# `_direction` é um vetor de MUNDO.
	# mundo, senão a onda saía torta sob um pai com transform próprio.
	global_rotation = _direction.angle()
	hitbox.configure(_damage, true)
	if shooter != null:
		hitbox.source = shooter
	body_entered.connect(_on_body_entered)
	_show_frame(FIRST_FRAME)
	if _remaining <= 0.0:
		_consume()


func _physics_process(delta: float) -> void:
	if _consumed:
		return
	# O último passo é encurtado.
	var step: float = minf(speed * delta, _remaining)
	var alvo: Vector2 = global_position + _direction * step
	var parede: Dictionary = CombatUtils.trace_wall(self, global_position, alvo, wall_mask)
	if not parede.is_empty():
		global_position = parede["position"]
		_consume()
		return
	global_position = alvo
	_remaining -= step
	_animate(delta)
	if _remaining <= 0.0:
		_consume()


## Parede (mundo) interrompe a onda.
func _on_body_entered(body: Node) -> void:
	if body != shooter:
		_consume()


## Repete os quadros 3..9 da spritesheet enquanto viaja.
func _animate(delta: float) -> void:
	_elapsed += delta
	var count: int = LAST_FRAME - FIRST_FRAME + 1
	_show_frame(FIRST_FRAME + int(_elapsed * FRAMES_PER_SECOND) % count)


func _show_frame(frame: int) -> void:
	if frame == _frame:
		return
	_frame = frame
	@warning_ignore("integer_division")
	var row: int = frame / SHEET_COLUMNS
	sprite.region_rect = Rect2(Vector2(frame % SHEET_COLUMNS, row) * CELL_SIZE, CELL_SIZE)


func _consume() -> void:
	if _consumed:
		return
	_consumed = true
	set_physics_process(false)
	if hitbox != null:
		hitbox.set_active(false)
	queue_free()
