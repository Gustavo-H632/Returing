class_name FanShotEffect
extends AbilityEffect
## Tiro em Leque: dispara vários projéteis de uma vez em arco, centrado na direção do cursor.
## Mesmo esquema do `PiercingShotEffect`: tiros do `PoolHub`; se o pool ainda está criando
## instâncias, tenta de novo a cada frame até lançar todos.

## Quantos frames espera o pool criar as instâncias antes de desistir.
const MAX_ATTEMPTS: int = 12

@export var projectile_scene: PackedScene

@export_group("Leque")
@export_range(1, 15) var count: int = 5
## Abertura total do arco, em graus.
@export_range(0.0, 180.0, 1.0) var arc_degrees: float = 40.0
@export var damage: int = 30
## Tamanho dos tiros (0 a 1, o mesmo "carga" do tiro do Player).
@export_range(0.0, 1.0, 0.05) var shot_charge: float = 0.4

var _pending: Array[Vector2] = []
var _attempts: int = 0


func _on_activate() -> void:
	if projectile_scene == null:
		push_warning("FanShotEffect: 'projectile_scene' não atribuída.")
		_finish()
		return
	var center: Vector2 = caster.get_shot_direction()  # direção bruta do cursor (sem mira assistida)
	for i: int in count:
		var t: float = 0.5 if count <= 1 else float(i) / float(count - 1)
		_pending.append(center.rotated(deg_to_rad(lerpf(-arc_degrees * 0.5, arc_degrees * 0.5, t))))
	PoolHub.prewarm(projectile_scene, caster, count)
	_try_fire()


## Enquanto o pool ainda cria instâncias, tenta de novo a cada frame.
func _physics_process(_delta: float) -> void:
	_try_fire()


func _try_fire() -> void:
	if _cleaned:
		return
	if not is_instance_valid(caster) or not caster.is_inside_tree():
		_finish()
		return
	while not _pending.is_empty():
		var shot: PlayerProjectile = PoolHub.acquire(projectile_scene, caster, PlayerProjectile) as PlayerProjectile
		if shot == null:
			_attempts += 1
			if _attempts >= MAX_ATTEMPTS:
				push_warning("FanShotEffect: o pool não entregou todos os projéteis.")
				_finish()
			return
		shot.launch(caster.get_muzzle_position(), _pending.pop_front() as Vector2, damage, shot_charge, caster, false)
		CombatUtils.connect_once(shot.damage_dealt, Callable(caster, &"_on_projectile_damage_dealt"))
	_finish()
