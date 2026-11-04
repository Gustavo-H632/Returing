class_name MeleeTelegraph
extends PooledArea
## Aviso de ataque em área (círculo no chão), reaproveitado pelo PoolHub.

enum Phase { CHARGING, IMPACT }

@export var radius: float = 80.0
@export var warning_color: Color = Color(1.0, 0.2, 0.2, 0.35)
@export var impact_color: Color = Color(1.0, 1.0, 0.6, 0.6)
@export var impact_duration: float = 0.15
@export var pulse_amount: float = 0.06

## Hitbox filha e a forma dela.
@export var hitbox: Hitbox
@export var hitbox_shape: CollisionShape2D

## Quem criou o telegraph (o dano é atribuído a ele).
var source: Node = null

var _phase: Phase = Phase.CHARGING
var _time_left: float = 1.0
var _visual_scale: float = 1.0


## Raio próprio (a forma é do telegraph, não da cena) e hitbox desligada.
func _ready() -> void:
	super._ready()
	if hitbox == null:
		push_error("MeleeTelegraph: 'hitbox' não foi atribuído no Inspector.")
		set_physics_process(false)
		return
	CombatUtils.set_unique_circle_radius(hitbox_shape, radius)
	hitbox.set_active(false)  # só avisa


## Começa o aviso em `center`: carrega `charge_time` s e depois causa `damage`.
func launch(center: Vector2, charge_time: float, damage: int, from_source: Node) -> void:
	global_position = center
	source = from_source
	_phase = Phase.CHARGING
	_time_left = maxf(charge_time, 0.0)
	_visual_scale = 1.0
	if hitbox != null:
		hitbox.configure(damage, true)
		hitbox.source = source
		hitbox.damage_on_contact = true
		hitbox.set_active(false)
	queue_redraw()


func _on_pool_deactivate() -> void:
	if hitbox != null:
		hitbox.set_active(false)


## Carga com pulso visual e depois o impacto.
func _physics_process(delta: float) -> void:
	_time_left -= delta
	match _phase:
		Phase.CHARGING:
			# Pulso só no desenho
			_visual_scale = 1.0 + sin(Time.get_ticks_msec() / 100.0) * pulse_amount
			queue_redraw()
			if _time_left <= 0.0:
				_impact()
		Phase.IMPACT:
			if _time_left <= 0.0:
				# Garante o dano em quem ficou dentro
				hitbox.pulse(false)
				recycle()


## Desenha o círculo.
func _draw() -> void:
	var color := warning_color if _phase == Phase.CHARGING else impact_color
	draw_circle(Vector2.ZERO, radius * _visual_scale, color)


## Liga a hitbox no impacto.
func _impact() -> void:
	_phase = Phase.IMPACT
	_time_left = impact_duration
	_visual_scale = 1.0
	# Liga a hitbox: acerta quem está dentro
	hitbox.set_active(true)
	queue_redraw()
