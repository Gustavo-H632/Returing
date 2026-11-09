class_name ShockWave
extends PooledArea
## Onda de choque do Seguidor (Drone), reaproveitada pelo PoolHub.

## Quadros da onda na spritesheet Laser1_sprite (4 colunas, células de 368 px).
const SHEET_COLUMNS: int = 4
const CELL_SIZE: Vector2 = Vector2(368.0, 368.0)  # Tamanho de cada quadro da spritesheet.
const FIRST_FRAME: int = 3  # Primeiro quadro da animação em loop.
const LAST_FRAME: int = 9  # Último quadro da animação em loop.
const FRAMES_PER_SECOND: float = 12.0  # Velocidade da animação.

@export var speed: float = 260.0  # Velocidade da onda em pixels por segundo.
## Camadas tratadas como parede (1 = Mundo).
@export_flags_2d_physics var wall_mask: int = 1
## Componentes da cena (arraste no Inspector).
@export var hitbox: Hitbox
@export var sprite: Sprite2D  # Sprite da onda.

var shooter: Node = null  # Quem lançou a onda (não é atingido).

var _direction: Vector2 = Vector2.RIGHT  # Direção do movimento.
var _remaining: float = 0.0  # Distância que ainda falta percorrer.
var _elapsed: float = 0.0  # Tempo de animação acumulado.
var _frame: int = -1  # Quadro atual.
var _consumed: bool = false  # True depois de acabar.


## Prepara a onda: confere as referências e liga o sinal de colisão com paredes.
func _ready() -> void:
	super._ready()  # Prepara o PooledArea.
	if hitbox == null or sprite == null:  # Sem hitbox ou sprite não funciona.
		push_error("ShockWave: 'hitbox' e 'sprite' precisam ser atribuídos no Inspector.")  # Avisa o erro.
		set_physics_process(false)  # Desliga a física.
		return
	hitbox.set_active(false)  # Começa desligada.
	body_entered.connect(_on_body_entered)  # Bater em corpo (parede) interrompe a onda.


## Dispara a onda de `origin` na direção `direction` (vetor de mundo) por `travel_distance` px.
## Lança a onda e reinicia o estado dela (reaproveitada do pool).
func launch(origin: Vector2, direction: Vector2, travel_distance: float, damage: int,
		from_shooter: Node = null) -> void:
	global_position = origin  # Nasce no drone.
	# Direção normalizada (zero vira direita).
	_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	global_rotation = _direction.angle()  # Gira para a direção.
	_remaining = maxf(travel_distance, 0.0)  # Distância que ainda falta.
	shooter = from_shooter  # Quem lançou.
	_elapsed = 0.0  # Zera a animação.
	_frame = -1  # Força a escolha do primeiro quadro.
	_consumed = false  # Libera para acertar.
	if hitbox == null:
		return
	hitbox.source = shooter  # nunca acerta quem lançou a onda
	hitbox.configure(damage, true)  # Um acerto por alvo.
	hitbox.set_active(true)  # Liga a hitbox.
	_show_frame(FIRST_FRAME)  # Mostra o primeiro quadro.
	if _remaining <= 0.0:  # Distância zero: acaba logo.
		_consume()


## Ao voltar ao pool desliga a hitbox.
func _on_pool_deactivate() -> void:
	if hitbox != null:  # Hitbox existe.
		hitbox.set_active(false)


## A cada quadro anda até a distância máxima ou a primeira parede, animando.
func _physics_process(delta: float) -> void:
	if _consumed:  # Já acabou.
		return
	# O último passo é encurtado.
	# Passo do quadro (o último é encurtado para parar exatamente no alcance).
	var step: float = minf(speed * delta, _remaining)
	if CombatUtils.move_until_wall(self, _direction * step, wall_mask):  # Anda até a parede.
		_consume()  # Bateu na parede: acaba.
		return
	_remaining -= step  # Desconta a distância andada.
	_animate(delta)  # Anima os quadros.
	if _remaining <= 0.0:  # Chegou ao alcance máximo.
		_consume()


## Parede (mundo) interrompe a onda.
# Bater em qualquer coisa que não seja quem lançou acaba a onda.
func _on_body_entered(body: Node) -> void:
	if body != shooter:
		_consume()


## Repete os quadros 3..9 da spritesheet enquanto viaja.
## Repete os quadros em loop enquanto a onda viaja.
func _animate(delta: float) -> void:
	_elapsed += delta  # Soma o tempo.
	var count: int = LAST_FRAME - FIRST_FRAME + 1  # Quantidade de quadros do loop.
	_show_frame(FIRST_FRAME + int(_elapsed * FRAMES_PER_SECOND) % count)  # Quadro atual do loop.


## Mostra um quadro da spritesheet recortando a região correta.
func _show_frame(frame: int) -> void:
	if frame == _frame:  # Já está nesse quadro.
		return
	_frame = frame  # Guarda o quadro.
	@warning_ignore("integer_division")
	var row: int = frame / SHEET_COLUMNS  # Linha do quadro na grade.
	# Recorta a região do quadro.
	sprite.region_rect = Rect2(Vector2(frame % SHEET_COLUMNS, row) * CELL_SIZE, CELL_SIZE)


## Volta ao pool uma vez.
## Devolve a onda ao pool, uma vez só.
func _consume() -> void:
	if _consumed:  # Já devolvida.
		return
	_consumed = true  # Marca como consumida.
	recycle()  # Volta ao pool.
