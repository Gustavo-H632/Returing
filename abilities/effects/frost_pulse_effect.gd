class_name FrostPulseEffect
extends AbilityEffect
## Pulso Gélido: onda azul ao redor do Player. Os inimigos dentro do raio ficam mais lentos por
## `data.duration` segundos (o fator multiplica a `move_speed`, via `EnemySlow`). Não causa dano.
## Chefões (`exclude_kinds`) são imunes, a mesma regra do Pulso EMP.

const DEFAULT_TIME: float = 4.0

@export_group("Pulso")
@export var radius: float = 150.0
## Duração (s) da animação do anel.
@export_range(0.1, 2.0, 0.05) var ring_time: float = 0.45
@export var ring_color: Color = Color(0.5, 0.85, 1.0, 1.0)

@export_group("Lentidão")
## Multiplica a velocidade do inimigo (0.5 = 50% mais lento).
@export_range(0.05, 1.0, 0.05) var speed_factor: float = 0.5
## Inimigos que não ficam lentos (chefões têm fases próprias).
@export var exclude_kinds: Array[StringName] = [&"guide"]
@export var slow_tint: Color = Color(0.6, 0.85, 1.4, 1.0)

var _time_left: float = DEFAULT_TIME
var _age: float = 0.0
## Inimigos que esta fonte deixou lentos (pode conter instâncias já liberadas: sempre checar).
var _slowed: Array = []


func _on_activate() -> void:
	top_level = true  # o anel fica parado no mundo, sem herdar a escala do Player
	global_position = caster.global_position
	_time_left = data.duration if data != null and data.duration > 0.0 else DEFAULT_TIME
	for node: Node in get_tree().get_nodes_in_group(CombatUtils.GROUP_ENEMY):
		var foe: EnemyBase = node as EnemyBase
		if foe == null or not CombatUtils.is_targetable(foe) or exclude_kinds.has(foe.enemy_kind):
			continue
		if foe.global_position.distance_to(global_position) > radius:
			continue
		EnemySlow.apply(foe, self, speed_factor, slow_tint)
		_slowed.append(foe)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _cleaned:
		return
	_age += delta
	_time_left -= delta
	queue_redraw()
	if _time_left <= 0.0:
		_finish()


## Fim do tempo, morte do Player, lendária apagando as outras ou saída da cena: devolve a velocidade.
func _on_cleanup() -> void:
	for foe: Variant in _slowed:
		if is_instance_valid(foe):
			EnemySlow.remove(foe as EnemyBase, self)
	_slowed.clear()


func _draw() -> void:
	if _age >= ring_time:
		return
	var t: float = clampf(_age / ring_time, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - t, 3.0)
	var cor: Color = ring_color
	cor.a = 1.0 - t
	draw_arc(Vector2.ZERO, radius * eased, 0.0, TAU, 64, cor, 3.0)
	var interno: Color = ring_color
	interno.a = (1.0 - t) * 0.14
	draw_circle(Vector2.ZERO, radius * eased, interno)
