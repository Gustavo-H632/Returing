class_name BinaryMine
extends PooledArea
## Mina Binária (reaproveitada pelo PoolHub): fica no chão, arma depois de um instante e explode
## quando o primeiro inimigo chega perto, causando dano em todos os inimigos do raio da explosão.
## Some sozinha ao fim do tempo de vida, se quem a plantou morreu ou perdeu a habilidade.
## Não precisa de forma de colisão: a proximidade é medida pela distância até o grupo `enemy`.

const GROUP_MINES: StringName = &"binary_mine"
## Duração (s) da animação da explosão.
const BOOM_TIME: float = 0.3
## Sprites pixelados (gerados por `tests/gerar_sprites.gd`): tira de quadros lado a lado.
const SHEET_PATH: String = "res://abilities/sprites/binary_mine.png"
const BOOM_PATH: String = "res://abilities/sprites/mine_explosion.png"
const FRAME_SIZE: int = 16
const BOOM_FRAME_SIZE: int = 40
const BOOM_FRAMES: int = 5
## Cada pixel do sprite vira 2x2 pixels na tela (mesma escala pixelada do resto do jogo).
const PIXEL_SCALE: int = 2
## Segundos de cada quadro do LED piscando (mina armada).
const BLINK_TIME: float = 0.25

var _damage: int = 0
var _blast_radius: float = 80.0
var _trigger_radius: float = 36.0
var _life_left: float = 0.0
var _arm_left: float = 0.0
var _boom_left: float = 0.0
var _age: float = 0.0
var _exploded: bool = false
var _source: Node = null
var _owner_ability: StringName = &""
var _sheet: Texture2D = null
var _boom_sheet: Texture2D = null


func _ready() -> void:
	super._ready()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sheet = load(SHEET_PATH) as Texture2D
	_boom_sheet = load(BOOM_PATH) as Texture2D


## Planta a mina em `origin`. `owner_ability` é o id da habilidade (a mina some se o Player a perder).
func plant(origin: Vector2, damage: int, blast_radius: float, trigger_radius: float, lifetime: float,
		arm_time: float, source: Node, owner_ability: StringName) -> void:
	global_position = origin.round()  # posição inteira: o sprite pixelado não tremula
	_damage = damage
	_blast_radius = blast_radius
	_trigger_radius = trigger_radius
	_life_left = maxf(lifetime, 0.1)
	_arm_left = maxf(arm_time, 0.0)
	_boom_left = 0.0
	_age = 0.0
	_exploded = false
	_source = source
	_owner_ability = owner_ability
	queue_redraw()


## Tempo (s) desde que foi plantada (a mais antiga é descartada quando passa do limite de minas).
func get_age() -> float:
	return _age


func is_armed() -> bool:
	return not _exploded and _arm_left <= 0.0


func is_exploded() -> bool:
	return _exploded


func _on_pool_activate() -> void:
	add_to_group(GROUP_MINES)


## Volta ao pool com o estado limpo.
func _on_pool_deactivate() -> void:
	if is_in_group(GROUP_MINES):
		remove_from_group(GROUP_MINES)
	_damage = 0
	_life_left = 0.0
	_arm_left = 0.0
	_boom_left = 0.0
	_age = 0.0
	_exploded = false
	_source = null
	_owner_ability = &""
	queue_redraw()


func _physics_process(delta: float) -> void:
	_age += delta
	if _exploded:
		_boom_left -= delta
		queue_redraw()
		if _boom_left <= 0.0:
			recycle()
		return
	_life_left -= delta
	if _life_left <= 0.0 or not _owner_is_valid():
		recycle()
		return
	if _arm_left > 0.0:
		_arm_left -= delta
	elif _enemy_close():
		_explode()
	queue_redraw()


## Quem plantou continua vivo e ainda tem a habilidade (a lendária apaga as outras).
func _owner_is_valid() -> bool:
	if not CombatUtils.is_targetable(_source):
		return false
	var player: Player = _source as Player
	if player != null and player.abilities != null and _owner_ability != &"":
		return player.abilities.has_ability(_owner_ability)
	return true


func _enemy_close() -> bool:
	for node: Node in get_tree().get_nodes_in_group(CombatUtils.GROUP_ENEMY):
		var foe: Node2D = node as Node2D
		if foe != null and CombatUtils.is_targetable(foe) \
				and foe.global_position.distance_to(global_position) <= _trigger_radius:
			return true
	return false


func _explode() -> void:
	_exploded = true
	_boom_left = BOOM_TIME
	var origem: Node = _source if CombatUtils.is_alive(_source) else self
	for node: Node in get_tree().get_nodes_in_group(CombatUtils.GROUP_ENEMY):
		var foe: Node2D = node as Node2D
		if foe == null or not CombatUtils.is_targetable(foe):
			continue
		if foe.global_position.distance_to(global_position) <= _blast_radius:
			CombatUtils.apply_damage(foe, _damage, origem)
	queue_redraw()


func _draw() -> void:
	if _sheet == null or _boom_sheet == null:
		return
	if _exploded:
		var quadro: int = clampi(int((1.0 - _boom_left / BOOM_TIME) * float(BOOM_FRAMES)), 0, BOOM_FRAMES - 1)
		var lado: float = _blast_radius * 2.0  # o anel termina no raio real da explosão
		draw_texture_rect_region(_boom_sheet, Rect2(-lado * 0.5, -lado * 0.5, lado, lado),
				Rect2(quadro * BOOM_FRAME_SIZE, 0, BOOM_FRAME_SIZE, BOOM_FRAME_SIZE))
		return
	# Parada: LED ciano apagado. Armada: LED vermelho piscando.
	var frame: int = 0
	if is_armed():
		frame = 1 if int(_age / BLINK_TIME) % 2 == 0 else 2
	var tamanho: float = float(FRAME_SIZE * PIXEL_SCALE)
	draw_texture_rect_region(_sheet, Rect2(-tamanho * 0.5, -tamanho * 0.5, tamanho, tamanho),
			Rect2(frame * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE))
