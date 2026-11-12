class_name ElectricTrap
extends Node2D
## Armadilha elétrica deixada na morte: dano por tick durante `duration`.

@export var damage_per_tick: int = 10  # Dano de cada tick.
@export var tick_interval: float = 0.5  # Intervalo entre ticks.
@export var duration: float = 6.0  # Duração total da armadilha.
@export var radius: float = 70.0  # Raio da armadilha.

@export var hitbox: Hitbox  # Hitbox de dano contínuo.
@export var hitbox_shape: CollisionShape2D  # Forma da hitbox.

# 1. Referência para o nó de animação (ajuste o nome se for diferente na árvore)
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D  # Animação da armadilha.

var _time_left: float = 0.0  # Tempo restante.


## Raio próprio e hitbox em modo contínuo.
## Define o raio da hitbox, liga o dano contínuo e toca a animação.
func _ready() -> void:
	if hitbox == null:  # Sem hitbox a armadilha não funciona.
		push_error("ElectricTrap: 'hitbox' não foi atribuído no Inspector.")  # Avisa o erro.
		set_physics_process(false)  # Desliga a física.
		queue_free()  # Remove a armadilha.
		return
	# Dá à forma da hitbox um círculo próprio com o raio configurado.
	CombatUtils.set_unique_circle_radius(hitbox_shape, radius)

	# Dano ao entrar e a cada tick
	hitbox.damage_on_contact = true  # Dá dano ao entrar.
	hitbox.configure(damage_per_tick, false, tick_interval)  # Dano contínuo: um tick a cada intervalo.
	hitbox.set_active(true)  # Liga a hitbox.
	_time_left = duration  # Começa a contagem.

	# 2. Inicia a animação padrão ("default") assim que a armadilha surge
	if animated_sprite:  # Se há animação, toca.
		animated_sprite.play("default")  # Animação padrão.


## Some quando o tempo acaba.
## A cada quadro desconta o tempo e remove a armadilha quando ele acaba.
func _physics_process(delta: float) -> void:
	_time_left -= delta  # Desconta o tempo.
	if _time_left <= 0.0:  # Acabou.
		set_physics_process(false)  # Para de processar.
		hitbox.set_active(false)  # Desliga a hitbox.
		
		# O queue_free() já limpa a armadilha inteira da memória, 
		# incluindo o animated_sprite que é filho deste nó.
		queue_free()  # Remove a armadilha da cena.
