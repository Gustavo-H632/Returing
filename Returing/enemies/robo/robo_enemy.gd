class_name RoboEnemy
extends EnemyBase
## Projétil (Ranged) — sprite robo.png.

## Instâncias de projétil e de aviso criadas com antecedência no pool.
const PROJECTILE_PREWARM: int = 4
const TELEGRAPH_PREWARM: int = 2  # Avisos de ataque em área criados antecipadamente.

@export_group("Ataque à Distância")
@export var projectile_scene: PackedScene  # Cena do projétil.
@export var ranged_attack_distance: float = 350.0  # Distância máxima do tiro.
@export var ranged_attack_cooldown: float = 1.4  # Intervalo entre tiros.
## Tempo de carga antes de cada disparo (animação "attack_ranged").
@export var ranged_windup_time: float = 0.3

@export_group("Ataque em Área")
@export var melee_telegraph_scene: PackedScene  # Cena do aviso (círculo no chão) do ataque em área.
@export var melee_telegraph_time: float = 1.0  # Tempo de aviso antes do dano.
@export var melee_damage: int = 25  # Dano do ataque em área.
@export var melee_attack_cooldown: float = 1.8  # Recarga do ataque em área.

@export_group("Percepção")
## True = aggro permanente: depois de ver o player, o Robo nunca mais o esquece.
@export var permanent_aggro: bool = false

@export_group("Morte")
@export var electric_trap_scene: PackedScene  # Cena da armadilha elétrica deixada ao morrer.

@export_group("Referências (já ligadas na cena)")
@export var melee_range_area: Area2D  # Área onde o ataque em área é usado.
@export var projectile_spawn_point: Marker2D  # Ponto de onde o projétil sai.

var target_in_melee_range: bool = false  # True se o jogador está no alcance do ataque em área.


## Prepara o Robô: pré-cria projéteis e avisos e liga os sinais da área corpo a corpo.
func _on_enemy_ready() -> void:
	PoolHub.prewarm(projectile_scene, self, PROJECTILE_PREWARM)  # Cria projéteis antes da luta.
	PoolHub.prewarm(melee_telegraph_scene, self, TELEGRAPH_PREWARM)  # Cria avisos antes da luta.
	if melee_range_area != null:  # Área do ataque em área.
		# Jogador entrou.
		CombatUtils.connect_once(melee_range_area.body_entered, _on_melee_range_body_entered)
		CombatUtils.connect_once(melee_range_area.body_exited, _on_melee_range_body_exited)  # Jogador saiu.


## Com aggro permanente, o Robo não esquece o player.
func _on_detection_body_exited(body: Node2D) -> void:
	if not permanent_aggro:  # Só esquece o jogador se o aggro não for permanente.
		super._on_detection_body_exited(body)


## Esquece o alvo e também o aviso de que ele estava no alcance do ataque em área.
func drop_target() -> void:
	super.drop_target()  # Esquece o alvo (classe base).
	target_in_melee_range = false  # Sem alvo, também não está no alcance.


## Diz se o alvo está dentro da distância de tiro (o multiplicador alarga o limite para dar margem).
func is_target_in_ranged_distance(multiplier: float = 1.0) -> bool:
	var max_dist: float = ranged_attack_distance * multiplier  # Distância máxima (com margem).
	# Compara a distância ao quadrado com o limite ao quadrado (sem raiz).
	return distance_sq_to_target() <= max_dist * max_dist


## Posição onde o projétil nasce: o marcador da arma, ou o centro do Robô.
func get_projectile_origin() -> Vector2:
	return projectile_spawn_point.global_position if projectile_spawn_point != null else global_position


## O jogador entrou na área do ataque em área.
func _on_melee_range_body_entered(body: Node2D) -> void:
	if CombatUtils.is_enemy_target(body):  # Só o jogador (ou outro alvo dos inimigos) conta.
		target_in_melee_range = true  # Liga o aviso.


## O jogador saiu da área do ataque em área.
func _on_melee_range_body_exited(body: Node2D) -> void:
	if CombatUtils.is_enemy_target(body):  # Só o jogador (ou outro alvo dos inimigos) conta.
		target_in_melee_range = false  # Desliga o aviso.


## Ao morrer desliga a área corpo a corpo e deixa uma armadilha elétrica no chão.
func _on_death() -> void:
	if melee_range_area != null:  # Sem área, nada a desligar.
		melee_range_area.set_deferred(&"monitoring", false)  # Desliga a detecção (adiado).
	if electric_trap_scene == null:  # Sem a cena da armadilha: avisa.
		push_warning("RoboEnemy: electric_trap_scene não configurada.")  # Aviso no console.
		return
	CombatUtils.spawn(electric_trap_scene, self, global_position)  # Cria a armadilha onde o Robô morreu.
