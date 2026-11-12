class_name OverclockEffect
extends StatBuffEffect
## Overclock (lendária): dois estágios. Primeiro um bônus de dano e de velocidade; nos últimos
## `data.penalty_duration` segundos da duração vira uma penalidade. Mesmo padrão do `BloodModeEffect`:
## os modificadores são refeitos na troca de estágio e removidos em qualquer saída (`_on_cleanup`).
## "Dano" é o atributo `StatModifiers.DAMAGE` (golpe da espada), igual ao Modo Sanguinário.

@export_group("Bônus")
@export_range(1.0, 3.0, 0.05) var boost_damage: float = 1.5
@export_range(1.0, 3.0, 0.05) var boost_speed: float = 1.3

@export_group("Penalidade")
@export_range(0.1, 1.0, 0.05) var penalty_damage: float = 0.8
@export_range(0.1, 1.0, 0.05) var penalty_speed: float = 0.8

@export_group("Visual")
@export var boost_color: Color = Color(1.0, 0.78, 0.25, 1.0)
@export var penalty_color: Color = Color(0.9, 0.25, 0.2, 1.0)
@export var ring_radius: float = 24.0

var _penalty: bool = false
var _age: float = 0.0


## True enquanto está na fase de penalidade.
func is_penalty() -> bool:
	return _penalty


func _on_activate() -> void:
	_penalty = false
	_age = 0.0
	super._on_activate()
	queue_redraw()


func _apply_stats() -> void:
	var stats: StatModifiers = get_stats()
	if stats == null:
		return
	stats.add(StatModifiers.DAMAGE, penalty_damage if _penalty else boost_damage, StatModifiers.Mode.MULT, self)
	stats.add(StatModifiers.MOVE_SPEED, penalty_speed if _penalty else boost_speed, StatModifiers.Mode.MULT, self)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _cleaned:
		return
	_age += delta
	var entra_na_penalidade: bool = data != null and data.penalty_duration > 0.0 \
			and _time_left <= data.penalty_duration
	if entra_na_penalidade and not _penalty:
		_penalty = true
		_refresh_stats()
	queue_redraw()


func _draw() -> void:
	var cor: Color = penalty_color if _penalty else boost_color
	var pulso: float = 0.5 + 0.5 * sin(_age * (4.0 if _penalty else 10.0))
	var fill: Color = cor
	fill.a = 0.08 + 0.06 * pulso
	draw_circle(Vector2.ZERO, ring_radius, fill)
	var borda: Color = cor
	borda.a = 0.45 + 0.4 * pulso
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 40, borda, 2.0)
