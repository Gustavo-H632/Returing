class_name EnemyProjectile
extends PooledArea
## Projétil do Robo: o dano cresce com a distância percorrida (reaproveitado pelo PoolHub).

@export var speed: float = 400.0  # Velocidade do projétil.
@export var min_damage: int = 5  # Dano mínimo (perto do Robô).
@export var max_damage: int = 25  # Dano máximo (longe do Robô).
@export var max_damage_distance: float = 500.0  # Distância em que o dano chega ao máximo.
@export var lifetime: float = 3.0  # Tempo de vida.
## Camadas tratadas como parede (1 = Mundo).
@export_flags_2d_physics var wall_mask: int = 1

## Hitbox filha.
@export var hitbox: Hitbox

var shooter: Node = null  # Quem atirou.

var _direction: Vector2 = Vector2.RIGHT  # Direção do voo.
var _start_position: Vector2 = Vector2.ZERO  # Onde o projétil nasceu (base do cálculo de dano).
var _life_left: float = 0.0  # Tempo de vida restante.
var _damage_maxed: bool = false  # True quando o dano já chegou ao máximo (não recalcula).
var _consumed: bool = false  # True depois de acertar ou bater.


## Liga os sinais uma única vez (a instância é reaproveitada).
## Liga os sinais uma única vez (a instância é reaproveitada pelo pool).
func _ready() -> void:
	super._ready()  # Prepara o PooledArea.
	if hitbox == null:  # Sem hitbox não funciona.
		push_error("EnemyProjectile: 'hitbox' não foi atribuído no Inspector.")  # Avisa o erro.
		set_physics_process(false)  # Desliga a física.
		return
	hitbox.set_active(false)  # Começa desligada.
	hitbox.hit_landed.connect(_on_hitbox_hit_landed)  # Quando acerta, some.
	body_entered.connect(_on_body_entered)  # Quando bate em corpo (parede), some.


## Dispara de `origin` na direção `direction` (vetor de mundo) em nome de `from_shooter`.
## Lança o projétil e reinicia o estado dele (reaproveitado do pool).
func launch(origin: Vector2, direction: Vector2, from_shooter: Node = null) -> void:
	global_position = origin  # Nasce na boca.
	scale = Vector2.ONE * Platform.sprite_scale  # celular: sprites maiores
	# Direção normalizada (zero vira direita).
	_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	global_rotation = _direction.angle()  # Gira para a direção do voo.
	shooter = from_shooter  # Guarda quem atirou.
	_start_position = origin  # Guarda o ponto de partida.
	_life_left = lifetime  # Zera o tempo de vida.
	_damage_maxed = false  # O dano volta a crescer.
	_consumed = false  # Libera para acertar.
	if hitbox == null:
		return
	hitbox.source = shooter  # não acerta quem atirou
	hitbox.configure(min_damage, true)  # Começa com o dano mínimo (um acerto por alvo).
	hitbox.set_active(true)  # Liga a hitbox.
	_block_if_spawned_behind_wall(origin)  # Se nasceu atrás de uma parede, some ali.


## Se há parede entre o Robo e a boca da arma (parede fina encostada nele), o tiro morre na parede
## em vez de nascer do outro lado dela.
## Evita atravessar parede fina quando a boca da arma nasce depois dela.
func _block_if_spawned_behind_wall(muzzle: Vector2) -> void:
	var shooter_body := shooter as Node2D  # Corpo de quem atirou.
	if shooter_body == null:  # Sem dono, nada a testar.
		return
	# Varre do corpo até a boca.
	var spawn: Dictionary = CombatUtils.trace_spawn(self, shooter_body.global_position, muzzle, wall_mask)
	if spawn["blocked"] as bool:  # Parede no caminho.
		global_position = spawn["position"] as Vector2  # O projétil morre no ponto de contato.
		_consume()  # Encerra.


## Ao voltar ao pool, desliga a hitbox.
func _on_pool_deactivate() -> void:
	if hitbox != null:  # Hitbox existe.
		hitbox.set_active(false)


## Anda e atualiza o dano.
## A cada quadro anda até a parede e atualiza o dano conforme a distância percorrida.
func _physics_process(delta: float) -> void:
	if _consumed:  # Já acabou.
		return
	if CombatUtils.move_until_wall(self, _direction * speed * delta, wall_mask):  # Anda até a parede.
		_consume()  # Bateu: acaba.
		return
	if not _damage_maxed and hitbox != null:  # Enquanto o dano não chegou ao máximo, recalcula.
		hitbox.damage = _calculate_current_damage()

	_life_left -= delta  # Desconta o tempo de vida.
	if _life_left <= 0.0:  # Acabou o tempo.
		_consume()


## Bateu em parede.
## Bateu em um corpo que não é quem atirou (parede): some.
func _on_body_entered(body: Node) -> void:
	if body != shooter:  # Ignora quem atirou.
		_consume()  # parede


## Acertou: some.
func _on_hitbox_hit_landed(_target: Node, _damage_dealt: int) -> void:
	_consume()  # Some.


## Dano pela distância percorrida.
## Calcula o dano: cresce de `min_damage` a `max_damage` com a distância já percorrida.
func _calculate_current_damage() -> int:
	if max_damage_distance <= 0.0:  # Sem distância máxima: dano máximo sempre.
		_damage_maxed = true  # Marca como no máximo.
		return max_damage  # Devolve o dano máximo.
	# Fração da distância percorrida (0 a 1).
	var t := clampf(_start_position.distance_to(global_position) / max_damage_distance, 0.0, 1.0)
	_damage_maxed = t >= 1.0  # Chegou ao máximo.
	return roundi(lerpf(float(min_damage), float(max_damage), t))  # Interpola entre o mínimo e o máximo.


## Volta ao pool uma vez.
## Devolve o projétil ao pool, uma vez só.
func _consume() -> void:
	if _consumed:  # Já devolvido.
		return
	_consumed = true  # Marca como consumido.
	recycle()  # Volta ao pool.
