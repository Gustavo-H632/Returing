class_name MeleeTelegraph
extends Node2D
#Dano de mortre em área 

@export var radius: float = 80.0
@export var warning_color: Color = Color(1.0, 0.2, 0.2, 0.35)

@onready var hitbox: ShooterHitbox = $ShooterHitbox
@onready var collision_shape: CollisionShape2D = $ShooterHitbox/CollisionShape2D
@onready var charge_timer: Timer = $ChargeTimer


func _ready() -> void:
	if collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = radius

	#poe a cor mas nao da dano
	hitbox.set_active(false)
	charge_timer.one_shot = true
	charge_timer.timeout.connect(_on_charge_finished)
	queue_redraw()


## Chamado por AttackMeleeState 
func setup(charge_time: float, damage: int) -> void:
	hitbox.configure(damage, true)
	charge_timer.wait_time = charge_time
	charge_timer.start()


func _process(_delta: float) -> void:
	if charge_timer.time_left > 0.0:
		# Pulso simples para deixar claro que a área está "carregando".
		var pulse := 1.0 + sin(Time.get_ticks_msec() / 100.0) * 0.06
		scale = Vector2.ONE * pulse
		queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, warning_color)


func _on_charge_finished() -> void:
	hitbox.set_active(true)
	hitbox.apply_burst_damage()

	modulate = Color(1.0, 1.0, 0.6)  # Flash marcando o instante do impacto.
	await get_tree().create_timer(0.15).timeout
	queue_free()
