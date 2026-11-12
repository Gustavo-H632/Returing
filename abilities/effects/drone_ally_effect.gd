class_name DroneAllyEffect
extends AbilityEffect
## Drone Aliado: um drone orbita o Player por `data.duration` segundos e atira no inimigo mais próximo.
## O drone (`AllyDrone`) nasce em tempo de execução como filho do Player e some em qualquer saída do efeito.

const DEFAULT_TIME: float = 12.0

## Cena do tiro do drone (`PlayerProjectile` herdado, do PoolHub).
@export var projectile_scene: PackedScene

@export_group("Drone")
@export var damage: int = 18
## Segundos entre os tiros.
@export_range(0.1, 5.0, 0.05) var fire_interval: float = 0.8
## Raio da órbita (px) e velocidade (rad/s).
@export var orbit_radius: float = 48.0
@export var orbit_speed: float = 2.2
## Alcance (px) para mirar em inimigos.
@export var aim_range: float = 280.0
## Tamanho do tiro (0 a 1, o mesmo "carga" do tiro do Player).
@export_range(0.0, 1.0, 0.05) var shot_charge: float = 0.2

var _time_left: float = DEFAULT_TIME
var _drone: AllyDrone = null


func _on_activate() -> void:
	_time_left = data.duration if data != null and data.duration > 0.0 else DEFAULT_TIME
	PoolHub.prewarm(projectile_scene, caster, 4)
	_drone = AllyDrone.new()
	_drone.name = &"AllyDrone"
	_drone.projectile_scene = projectile_scene
	_drone.damage = damage
	_drone.fire_interval = fire_interval
	_drone.orbit_radius = orbit_radius
	_drone.orbit_speed = orbit_speed
	_drone.aim_range = aim_range
	_drone.shot_charge = shot_charge
	caster.add_child(_drone)
	_drone.setup(caster)


func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		_finish()


## Fim do tempo, morte do Player, lendária apagando as outras ou saída da cena: o drone some.
func _on_cleanup() -> void:
	if is_instance_valid(_drone):
		_drone.queue_free()
	_drone = null
