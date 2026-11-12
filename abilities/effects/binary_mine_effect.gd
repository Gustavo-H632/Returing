class_name BinaryMineEffect
extends AbilityEffect
## Mina Binária: planta uma mina (`BinaryMine`, do PoolHub) nos pés do Player e termina.
## A mina cuida do resto sozinha. Passando do limite de minas ao mesmo tempo, a mais antiga é recolhida.

## Quantos frames espera o pool criar a primeira instância antes de desistir.
const MAX_ATTEMPTS: int = 12

@export var mine_scene: PackedScene

@export_group("Mina")
@export var damage: int = 70
## Raio (px) da explosão.
@export var blast_radius: float = 80.0
## Distância (px) em que um inimigo dispara a mina.
@export var trigger_radius: float = 36.0
## Tempo (s) que a mina espera antes de sumir sozinha.
@export_range(1.0, 120.0, 0.5, "or_greater") var lifetime: float = 20.0
## Tempo (s) até a mina ficar armada (não explode em quem já estava colado).
@export_range(0.0, 5.0, 0.05) var arm_time: float = 0.6
## Quantas minas podem existir ao mesmo tempo.
@export_range(1, 10) var max_mines: int = 3
## Deslocamento (px) a partir do Player até o chão, onde a mina é plantada.
@export var feet_offset: Vector2 = Vector2(0.0, 10.0)

var _attempts: int = 0


func _on_activate() -> void:
	if mine_scene == null:
		push_warning("BinaryMineEffect: 'mine_scene' não atribuída.")
		_finish()
		return
	PoolHub.prewarm(mine_scene, caster, 2)
	_try_plant()


## Enquanto o pool ainda cria a instância, tenta de novo a cada frame.
func _physics_process(_delta: float) -> void:
	_try_plant()


func _try_plant() -> void:
	if _cleaned:
		return
	if not is_instance_valid(caster) or not caster.is_inside_tree():
		_finish()
		return
	var mine: BinaryMine = PoolHub.acquire(mine_scene, caster, BinaryMine) as BinaryMine
	if mine == null:
		_attempts += 1
		if _attempts >= MAX_ATTEMPTS:
			push_warning("BinaryMineEffect: o pool não entregou a mina.")
			_finish()
		return
	_discard_oldest_mines(mine)
	var id: StringName = data.id if data != null else &""
	mine.plant(caster.global_position + feet_offset * caster.global_scale, damage, blast_radius, trigger_radius,
			lifetime, arm_time, caster, id)
	_finish()


## Deixa espaço para a mina nova (`fresh`): recolhe as mais antigas quando passa do limite.
func _discard_oldest_mines(fresh: BinaryMine) -> void:
	var mines: Array[BinaryMine] = []
	for node: Node in get_tree().get_nodes_in_group(BinaryMine.GROUP_MINES):
		var mine: BinaryMine = node as BinaryMine
		if mine != null and mine != fresh and mine.is_in_use():
			mines.append(mine)
	mines.sort_custom(func(a: BinaryMine, b: BinaryMine) -> bool: return a.get_age() > b.get_age())
	while mines.size() >= max_mines:
		mines.pop_front().recycle()
