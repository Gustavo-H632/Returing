class_name DroneEnemy
extends EnemyBase
## Seguidor (melee) — sprite drone.png.

## Ondas de choque criadas com antecedência no pool.
const WAVE_PREWARM: int = 2
## Raio usado se a forma da Range 2 não for um círculo.
const DEFAULT_RANGE2_RADIUS: float = 110.0

@export_group("Perseguição")
@export var chase_speed_multiplier: float = 1.0  # Multiplicador de velocidade na perseguição.

@export_group("Ataque Corpo a Corpo")
@export var attack_damage: int = 10  # Dano do golpe corpo a corpo.
## Preparação (telegrafada pela animação).
@export var attack_windup_time: float = 0.35
## Tempo com a hitbox ligada.
@export var attack_hit_window: float = 0.15
## Recuperação após o golpe.
@export var attack_cooldown_time: float = 0.6

@export_group("Range 2 (onda de choque)")
@export var wave_scene: PackedScene  # Cena da onda de choque.
@export var wave_damage: int = 8  # Dano da onda.
## Intervalo mínimo entre ondas (evita rajada se o player oscilar na borda).
@export_range(0.0, 5.0, 0.05) var wave_cooldown: float = 0.4

@export_group("Referências (já ligadas na cena)")
@export var attack_range: Area2D  # Área onde o corpo a corpo começa.
@export var attack_hitbox: Hitbox  # Hitbox do golpe corpo a corpo.
@export var range2_area: Area2D  # Área da "Range 2" (onde dispara a onda).
@export var range2_shape: CollisionShape2D  # Forma da Range 2 (o raio vira o alcance da onda).

var target_in_attack_range: bool = false  # True se o jogador está no alcance do golpe.

## Recarga da onda em segundos de jogo.
var _wave_cooldown_left: float = 0.0


## Prepara o Drone: pré-cria ondas e liga os sinais das áreas de ataque e da Range 2.
func _on_enemy_ready() -> void:
	PoolHub.prewarm(wave_scene, self, WAVE_PREWARM)  # Cria as ondas antes da luta.
	if attack_hitbox != null:  # Configura o dano da hitbox do golpe.
		attack_hitbox.damage = attack_damage  # Dano do golpe.
		attack_hitbox.set_active(false)  # Começa desligada (só liga na janela do golpe).
	if attack_range != null:  # Área de ataque corpo a corpo.
		# Jogador entrou no alcance.
		CombatUtils.connect_once(attack_range.body_entered, _on_attack_range_body_entered)
		# Jogador saiu do alcance.
		CombatUtils.connect_once(attack_range.body_exited, _on_attack_range_body_exited)
	if range2_area != null:  # Área da Range 2.
		# Entrar na Range 2 dispara uma onda.
		CombatUtils.connect_once(range2_area.body_entered, _on_range2_body_entered)
		CombatUtils.connect_once(range2_area.body_exited, _on_range2_body_exited)  # Sair dela dispara outra.


## Desconta a recarga da onda de choque.
func _physics_process(delta: float) -> void:
	_wave_cooldown_left = maxf(_wave_cooldown_left - delta, 0.0)  # Nunca fica negativa.


## Diz se o drone enxerga o alvo.
func can_see_target() -> bool:
	return has_target()


## Raio atual da Range 2 (é também a distância máxima percorrida pela onda).
func get_range2_radius() -> float:
	# Raio do círculo da Range 2 (ou o padrão).
	return CombatUtils.get_circle_radius(range2_shape, DEFAULT_RANGE2_RADIUS)


## Esquece o alvo e também o aviso de que ele estava no alcance do golpe.
func drop_target() -> void:
	super.drop_target()  # Esquece o alvo (classe base).
	target_in_attack_range = false  # Sem alvo, também não está no alcance.


# --- Attack Range ---

## O jogador entrou no alcance do golpe corpo a corpo.
func _on_attack_range_body_entered(body: Node2D) -> void:
	if CombatUtils.is_player(body):  # Só o jogador conta.
		target_in_attack_range = true  # Liga o aviso.


## O jogador saiu do alcance do golpe.
func _on_attack_range_body_exited(body: Node2D) -> void:
	if CombatUtils.is_player(body):  # Só o jogador conta.
		target_in_attack_range = false  # Desliga o aviso.


# --- Range 2 ---

## O jogador entrou na Range 2: lança uma onda de choque na direção dele.
func _on_range2_body_entered(body: Node2D) -> void:
	if CombatUtils.is_player(body):  # Só o jogador conta.
		_launch_wave(body.global_position)  # Lança a onda.


## O player pode sair da árvore/morrer ao mesmo tempo: só confere o grupo.
# Basta estar no grupo do jogador (ele pode estar saindo da cena).
func _on_range2_body_exited(body: Node2D) -> void:
	# Sair da Range 2 também lança uma onda.
	if CombatUtils.is_valid(body) and body.is_in_group(CombatUtils.GROUP_PLAYER):
		_launch_wave(body.global_position)


## Lança a onda de choque na direção do player.
func _launch_wave(aim_at: Vector2) -> void:  # Morto ou em recarga: não lança.
	if is_dead() or _wave_cooldown_left > 0.0:
		return
	_wave_cooldown_left = maxf(wave_cooldown, 0.0)  # Começa a recarga.
	var wave := PoolHub.acquire(wave_scene, self, ShockWave) as ShockWave  # Pega uma onda do pool.
	if wave == null:  # Pool cheio ou cena inválida: nada a lançar.
		return
	# Lança do centro do drone na direção do jogador, com o alcance da Range 2.
	wave.launch(global_position, global_position.direction_to(aim_at), get_range2_radius(), wave_damage, self)
