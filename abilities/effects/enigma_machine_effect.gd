class_name EnigmaMachineEffect
extends AbilityEffect
## Máquina Enigma (lendária): efeito global. Por `data.duration` segundos TODOS os inimigos ficam
## mais lentos (via `EnemySlow`): os comuns bastante, os chefões menos. Inimigos que nascem durante o
## efeito também entram, pois o grupo `enemy` é varrido de `scan_interval` em `scan_interval` segundos.

const DEFAULT_TIME: float = 8.0

@export_group("Lentidão")
## Multiplica a velocidade dos inimigos comuns (0.3 = 70% mais lentos).
@export_range(0.05, 1.0, 0.05) var common_factor: float = 0.3
## Multiplica a velocidade dos chefões (0.7 = 30% mais lentos).
@export_range(0.05, 1.0, 0.05) var boss_factor: float = 0.7
## Tipos de inimigo tratados como chefão (o mesmo `enemy_kind` que o Pulso EMP usa).
@export var boss_kinds: Array[StringName] = [&"guide"]
## Intervalo (s) da varredura que pega os inimigos que nasceram durante o efeito.
@export_range(0.1, 2.0, 0.1) var scan_interval: float = 0.5
@export var slow_tint: Color = Color(0.75, 0.7, 1.4, 1.0)

@export_group("Visual")
@export var aura_color: Color = Color(0.72, 0.62, 1.0, 1.0)
@export var aura_radius: float = 34.0

var _time_left: float = DEFAULT_TIME
var _scan_left: float = 0.0
var _age: float = 0.0
## Inimigos que esta fonte deixou lentos (pode conter instâncias já liberadas: sempre checar).
var _slowed: Array = []


func _on_activate() -> void:
	_time_left = data.duration if data != null and data.duration > 0.0 else DEFAULT_TIME
	_scan()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _cleaned:
		return  # cancelado: varrer de novo deixaria inimigos lentos para sempre (ninguém desfaria)
	_age += delta
	_time_left -= delta
	_scan_left -= delta
	if _scan_left <= 0.0:
		_scan()
	queue_redraw()
	if _time_left <= 0.0:
		_finish()


## Deixa lentos os inimigos que ainda não estão (inclui os recém-nascidos).
func _scan() -> void:
	_scan_left = scan_interval
	for i: int in range(_slowed.size() - 1, -1, -1):
		if not is_instance_valid(_slowed[i]):
			_slowed.remove_at(i)
	for node: Node in get_tree().get_nodes_in_group(CombatUtils.GROUP_ENEMY):
		var foe: EnemyBase = node as EnemyBase
		if foe == null or not CombatUtils.is_targetable(foe) or EnemySlow.has_source(foe, self):
			continue
		EnemySlow.apply(foe, self, boss_factor if boss_kinds.has(foe.enemy_kind) else common_factor, slow_tint)
		_slowed.append(foe)


## Fim do tempo, morte do Player, lendária apagando as outras ou saída da cena: devolve a velocidade.
func _on_cleanup() -> void:
	for foe: Variant in _slowed:
		if is_instance_valid(foe):
			EnemySlow.remove(foe as EnemyBase, self)
	_slowed.clear()


func _draw() -> void:
	var fade_out: float = clampf(_time_left / 0.6, 0.0, 1.0)  # some devagar no fim
	var pulso: float = 0.5 + 0.5 * sin(_age * 3.0)
	var fill: Color = aura_color
	fill.a = (0.05 + 0.05 * pulso) * fade_out
	draw_circle(Vector2.ZERO, aura_radius, fill)
	var cor: Color = aura_color
	cor.a = (0.5 + 0.3 * pulso) * fade_out
	var dashes: int = 8
	for i: int in dashes:  # anel tracejado girando, como um rotor
		var start: float = _age * 1.4 + TAU * float(i) / float(dashes)
		draw_arc(Vector2.ZERO, aura_radius, start, start + TAU / float(dashes) * 0.55, 8, cor, 2.0)
