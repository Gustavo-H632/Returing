class_name PiercingShotEffect
extends AbilityEffect
## Tiro Perfurante: dispara um projétil de dano máximo na direção do cursor que atravessa inimigos.
## Reaproveita `PlayerProjectile` (subclasse) e o `PoolHub`.

## Quantos frames espera o pool criar a primeira instância antes de desistir.
const MAX_ATTEMPTS: int = 12

@export var projectile_scene: PackedScene  # Cena do tiro perfurante.
## 0 usa o dano do tiro com carga máxima do Player (`max_damage`).
@export var damage_override: int = 0

var _attempts: int = 0  # Tentativas já feitas.


## Prepara o pool e tenta disparar o tiro.
func _on_activate() -> void:
	if projectile_scene == null:  # Sem cena configurada: avisa e termina.
		push_warning("PiercingShotEffect: 'projectile_scene' não atribuída.")  # Aviso no console.
		_finish()
		return
	PoolHub.prewarm(projectile_scene, caster, 2)  # Cria o tiro antes de usar.
	_try_fire()  # Tenta disparar.


## Enquanto o pool ainda cria a instância, tenta de novo a cada frame.
# Tenta de novo a cada quadro enquanto o pool cria a instância.
func _physics_process(_delta: float) -> void:
	_try_fire()


## Tenta pegar um tiro do pool e dispará-lo; desiste depois de algumas tentativas.
func _try_fire() -> void:
	if _cleaned:  # Já terminou.
		return
	if not is_instance_valid(caster) or not caster.is_inside_tree():  # Jogador sumiu: termina.
		_finish()
		return
	# Pega um tiro do pool.
	var shot: PiercingProjectile = PoolHub.acquire(projectile_scene, caster, PiercingProjectile) as PiercingProjectile
	if shot == null:  # O pool ainda não entregou.
		_attempts += 1  # Conta a tentativa.
		if _attempts >= MAX_ATTEMPTS:  # Desistiu.
			push_warning("PiercingShotEffect: o pool não entregou o projétil.")
			_finish()
		return
	# Dano máximo do jogador (ou o configurado).
	var dano: int = damage_override if damage_override > 0 else caster.max_damage
	# Dispara da boca do cano na direção da mira, com carga total.
	shot.launch(caster.get_muzzle_position(), caster.get_shot_direction(), dano, 1.0, caster, Platform.aim_assist)
	# Quando o tiro acerta, o jogador repassa o dano.
	CombatUtils.connect_once(shot.damage_dealt, Callable(caster, &"_on_projectile_damage_dealt"))
	_finish()  # Termina o efeito.
