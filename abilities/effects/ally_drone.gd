class_name AllyDrone
extends Node2D
## Drone do Drone Aliado: orbita o Player e atira no inimigo mais próximo ao alcance.
## É criado em tempo de execução pelo `DroneAllyEffect` como filho do Player (o `Turing.tscn` não muda).
## Os tiros vêm do `PoolHub` (`PlayerProjectile`, com `shooter` = Player, então nunca o acertam).

## Sprite pixelado (gerado por `tests/gerar_sprites.gd`): 2 quadros com as hélices em posições diferentes.
const SHEET_PATH: String = "res://abilities/sprites/ally_drone.png"
const FRAME_SIZE: int = 16
const FRAME_COUNT: int = 2
const ROTOR_FPS: float = 24.0
## Cada pixel do sprite vira 2x2 pixels na tela.
const PIXEL_SCALE: int = 2

var projectile_scene: PackedScene = null
var damage: int = 18
var fire_interval: float = 0.8
var orbit_radius: float = 48.0
## Velocidade da órbita em radianos por segundo.
var orbit_speed: float = 2.2
var aim_range: float = 280.0
## Carga (0 a 1) usada só para o tamanho do tiro.
var shot_charge: float = 0.2

var _player: Player = null
var _angle: float = 0.0
var _fire_left: float = 0.0
var _age: float = 0.0
var _aim: Vector2 = Vector2.RIGHT
var _sheet: Texture2D = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sheet = load(SHEET_PATH) as Texture2D


func setup(player: Player) -> void:
	_player = player
	position = Vector2.RIGHT * orbit_radius
	_fire_left = fire_interval * 0.5  # o primeiro tiro não sai no mesmo instante


func _physics_process(delta: float) -> void:
	_age += delta
	_angle = fmod(_angle + orbit_speed * delta, TAU)
	position = (Vector2.from_angle(_angle) * orbit_radius).round()
	_fire_left -= delta
	var target: Node2D = _nearest_enemy()
	if target != null:
		_aim = (target.global_position - global_position).normalized()
		if _fire_left <= 0.0 and _shoot(_aim):
			_fire_left = fire_interval
	queue_redraw()


## Inimigo vivo mais próximo dentro do alcance (null se não houver).
func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_dist: float = aim_range
	for node: Node in get_tree().get_nodes_in_group(CombatUtils.GROUP_ENEMY):
		var foe: Node2D = node as Node2D
		if foe == null or not CombatUtils.is_targetable(foe):
			continue
		var dist: float = foe.global_position.distance_to(global_position)
		if dist <= best_dist:
			best = foe
			best_dist = dist
	return best


## Dispara um tiro. False se o pool ainda não entregou (tenta de novo no frame seguinte).
func _shoot(direction: Vector2) -> bool:
	if projectile_scene == null or not CombatUtils.is_alive(_player):
		return false
	var shot: PlayerProjectile = PoolHub.acquire(projectile_scene, _player, PlayerProjectile) as PlayerProjectile
	if shot == null:
		return false
	shot.launch(global_position, direction, damage, shot_charge, _player, false)
	CombatUtils.connect_once(shot.damage_dealt, Callable(_player, &"_on_projectile_damage_dealt"))
	return true


func _draw() -> void:
	if _sheet == null:
		return
	var quadro: int = int(_age * ROTOR_FPS) % FRAME_COUNT
	var lado: float = float(FRAME_SIZE * PIXEL_SCALE)
	draw_texture_rect_region(_sheet, Rect2(-lado * 0.5, -lado * 0.5, lado, lado),
			Rect2(quadro * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE))
