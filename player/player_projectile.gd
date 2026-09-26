class_name PlayerProjectile
extends Area2D

@export var speed: float = 300.0
@export var lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT
var damage: int = 0       
var shooter: Node = null


func _ready() -> void:
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body != shooter:
		_tentar_aplicar_dano(body)
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	# quem é reportado no sinal causou_dano é o dono dela.
	var raiz: Node = area.get_parent() if area.get_parent() != null else area
	if raiz != shooter:
		_tentar_aplicar_dano(area, raiz)
	queue_free()


func _tentar_aplicar_dano(alvo: Node, notificar: Node = null) -> void:
	if not is_instance_valid(alvo):
		return
	if not (alvo.has_method("tomar_dano") or alvo.has_method("take_damage")):
		return
	if is_instance_valid(shooter) and shooter.has_method("causar_dano"):
		shooter.causar_dano(alvo, damage, notificar)   # passa pelo player 
	elif alvo.has_method("tomar_dano"):
		alvo.tomar_dano(damage)
	else:
		alvo.take_damage(damage, shooter)
