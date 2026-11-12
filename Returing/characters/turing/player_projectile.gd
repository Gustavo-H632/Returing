class_name PlayerProjectile
extends PooledArea
## Tiro carregado do player (reaproveitado pelo PoolHub).

## Avisa quem atirou que o tiro acertou.
signal damage_dealt(target: Node, amount: int)

## Raio do tiro com 0% de carga (igual ao CircleShape2D da cena): a largura base do ataque do player.
const BASE_RADIUS: float = 5.0
## Escala do tiro com 100% de carga, em relação ao tamanho mínimo.
const MAX_CHARGE_SCALE: float = 3.0

# --- Mira assistida (só celular) ---
# --- Mira assistida (só celular) ---
## Alcance máximo (px) em que um inimigo pode atrair o tiro.
const ASSIST_RANGE: float = 520.0
## Meio-ângulo do cone à frente do tiro onde um inimigo conta como "quase na mira".
const ASSIST_CONE_DEG: float = 30.0
## Quanto o tiro pode curvar por segundo (leve: o jogador ainda precisa mirar).
const ASSIST_TURN_DEG_PER_SEC: float = 85.0

@export var speed: float = 300.0  # Velocidade do tiro em pixels por segundo.
@export var lifetime: float = 2.0  # Quanto tempo o tiro vive antes de sumir.
## Camadas que contam como parede.
@export_flags_2d_physics var wall_mask: int = 1

## Direção fixa, decidida no disparo.
var direction: Vector2 = Vector2.RIGHT
var damage: int = 0  # Dano que o tiro causa.
var shooter: Node = null  # Quem atirou (não pode ser atingido pelo próprio tiro).

var _life_left: float = 0.0  # Tempo de vida restante.
var _consumido: bool = false  # True depois de acertar ou bater na parede (impede acertar duas vezes).
## Inimigo que está atraindo o tiro (mira assistida); null = tiro reto.
var _assist_target: Node2D = null


## Liga os sinais de colisão (corpo e área) quando o tiro nasce.
func _ready() -> void:
	super._ready()  # Prepara o PooledArea.
	body_entered.connect(_on_body_entered)  # Bateu num corpo (inimigo ou parede com corpo).
	area_entered.connect(_on_area_entered)  # Bateu numa área (hurtbox).


## Dispara o tiro de `origin` na direção `aim`; a carga (0.0 a 1.0) define o tamanho.
## `assist` liga a mira assistida: o tiro curva um pouco para o inimigo mais próximo da linha de tiro.
## Todas as informações do disparo chegam aqui: posição, direção, dano, tamanho e dono. Reinicia o tiro reaproveitado do pool.
func launch(origin: Vector2, aim: Vector2, new_damage: int, charge_ratio: float, from_shooter: Node,
		assist: bool = false) -> void:
	global_position = origin  # Nasce na boca do cano.
	# Direção normalizada (se vier zero, vai para a direita).
	direction = aim.normalized() if aim != Vector2.ZERO else Vector2.RIGHT
	global_rotation = direction.angle()  # Gira o sprite para a direção do voo.
	damage = new_damage  # Guarda o dano.
	shooter = from_shooter  # Guarda o dono.
	apply_charge(charge_ratio)  # Aplica o tamanho conforme a carga.
	_life_left = lifetime  # Zera o tempo de vida.
	_consumido = false  # Libera para acertar de novo (veio do pool).
	# Escolhe o alvo da mira assistida (só celular).
	_assist_target = _pick_assist_target() if assist else null
	_block_if_spawned_behind_wall(origin)  # Se nasceu dentro de uma parede, morre ali.


## Se há parede entre quem atirou e a boca da arma (ex.: parede de 1 tile encostada no player), o tiro
## morre na parede em vez de nascer do outro lado dela.
## Impede que o tiro atravesse parede fina quando a boca da arma nasce depois dela.
func _block_if_spawned_behind_wall(muzzle: Vector2) -> void:
	var shooter_body := shooter as Node2D  # Corpo de quem atirou.
	if shooter_body == null:  # Sem dono, não há trecho para testar.
		return
	# Varre do corpo até a boca.
	var spawn: Dictionary = CombatUtils.trace_spawn(self, shooter_body.global_position, muzzle, wall_mask)
	if spawn["blocked"] as bool:  # Parede no caminho: o tiro acaba no ponto de contato.
		global_position = spawn["position"] as Vector2  # Coloca o tiro no ponto de contato.
		_consumir()  # Encerra o tiro.


## Escala o tiro pela carga: 0.0 = tamanho mínimo, 1.0 = MAX_CHARGE_SCALE vezes o mínimo
## (e vezes a escala dos sprites da plataforma).
## Define o tamanho do tiro pela carga, multiplicado pela escala do celular.
func apply_charge(ratio: float) -> void:
	scale = Vector2.ONE * charge_scale(ratio) * Platform.sprite_scale  # Escala uniforme.


## Fator de escala do tiro para uma carga (sem a escala de plataforma).
## Fator de escala (1.0 sem carga até 3.0 com carga total).
static func charge_scale(ratio: float) -> float:
	return lerpf(1.0, MAX_CHARGE_SCALE, clampf(ratio, 0.0, 1.0))  # Interpola entre mínimo e máximo.


## Largura do tiro (px, no mundo) para uma carga: o diâmetro da hitbox. Usada pela barra de mira.
## Largura do tiro em pixels do mundo (usada pela barra de mira).
static func width_for_charge(ratio: float) -> float:
	# Diâmetro da hitbox com a escala aplicada.
	return BASE_RADIUS * 2.0 * charge_scale(ratio) * Platform.sprite_scale


## Inimigo vivo mais alinhado com a direção do tiro, dentro do cone e sem parede no caminho.
## Procura o inimigo mais alinhado com a direção do tiro, dentro do cone e sem parede no meio.
func _pick_assist_target() -> Node2D:
	var best: Node2D = null  # Melhor candidato até agora.
	var best_angle: float = deg_to_rad(ASSIST_CONE_DEG)  # Menor ângulo aceito (começa no limite do cone).
	# Passa por todos os inimigos.
	for node: Node in get_tree().get_nodes_in_group(CombatUtils.GROUP_ENEMY):
		var enemy := node as Node2D  # Converte para Node2D.
		# Ignora inimigos mortos ou fora da cena.
		if enemy == null or not CombatUtils.is_targetable(enemy) or not enemy.is_inside_tree():
			continue
		var offset: Vector2 = enemy.global_position - global_position  # Vetor do tiro até o inimigo.
		# Fora do alcance (ou em cima do tiro): ignora.
		if offset.length() > ASSIST_RANGE or offset.length() < 1.0:
			continue
		var angle: float = absf(direction.angle_to(offset))  # Ângulo entre o voo e o inimigo.
		if angle >= best_angle:  # Fora do cone ou pior que o melhor.
			continue
		# Parede no caminho: ignora.
		if not CombatUtils.trace_wall(self, global_position, enemy.global_position, wall_mask).is_empty():
			continue
		best = enemy  # Guarda o novo melhor.
		best_angle = angle  # Guarda o ângulo dele.
	return best  # Devolve o escolhido (ou null).


## Curva a direção um pouco em direção ao alvo da mira assistida.
## Gira a direção do tiro um pouco por quadro em direção ao alvo da mira assistida.
func _steer_towards_assist_target(delta: float) -> void:
	if not CombatUtils.is_targetable(_assist_target):  # Alvo morreu ou sumiu: desliga a assistência.
		_assist_target = null  # Esquece o alvo.
		return
	var offset: Vector2 = _assist_target.global_position - global_position  # Vetor até o alvo.
	# Passou do inimigo (ou está em cima dele): deixa de puxar para não fazer "rodinha".
	# Passou do alvo ou está em cima: para de puxar (evita "rodinha").
	if offset.length() < 12.0 or direction.dot(offset) <= 0.0:
		_assist_target = null
		return
	var max_step: float = deg_to_rad(ASSIST_TURN_DEG_PER_SEC) * delta  # Quanto pode girar neste quadro.
	# Gira limitado ao passo máximo.
	direction = direction.rotated(clampf(direction.angle_to(offset), -max_step, max_step)).normalized()
	global_rotation = direction.angle()  # Gira o sprite junto.


## Anda em linha reta até bater ou acabar o tempo.
## A cada quadro: curva para o alvo (se houver), anda até a parede e conta o tempo de vida.
func _physics_process(delta: float) -> void:
	if _assist_target != null:  # Mira assistida ativa.
		_steer_towards_assist_target(delta)  # Ajusta a direção.
	# Testa o trecho todo.
	# Anda o passo inteiro, parando na primeira parede.
	if CombatUtils.move_until_wall(self, direction * speed * delta, wall_mask):
		_consumir()  # Bateu na parede: acaba.
		return
	_life_left -= delta  # Desconta o tempo de vida.
	if _life_left <= 0.0:  # Acabou o tempo: some.
		_consumir()


## Bateu em um corpo.
## Bateu num corpo: causa dano se ele aceita e some.
func _on_body_entered(body: Node2D) -> void:
	if _consumido or body == shooter:  # Já foi consumido ou é o próprio dono: ignora.
		return
	if CombatUtils.can_take_damage(body):  # Só causa dano em quem sabe receber.
		_aplicar_dano(body, body)  # Aplica o dano.
	_consumir()  # O tiro some ao bater em qualquer corpo.


## Bateu em uma hurtbox.
## Bateu numa hurtbox: causa dano ao dono dela e some.
func _on_area_entered(area: Area2D) -> void:
	if _consumido or not area.is_in_group(CombatUtils.GROUP_HURTBOX):  # Só áreas que recebem dano contam.
		return
	var raiz := CombatUtils.get_actor(area)  # Dono da hurtbox.
	if raiz == shooter:  # Não acerta o dono do tiro.
		return
	_aplicar_dano(area, raiz)  # Aplica o dano.
	_consumir()  # Some.


## Aplica o dano em nome de quem atirou.
## Aplica o dano em nome de quem atirou e avisa pelo sinal `damage_dealt` se foi aceito.
func _aplicar_dano(alvo: Node, notificar: Node) -> void:
	# Origem do dano (o jogador, ou o próprio tiro se ele morreu).
	var origem: Node = shooter if CombatUtils.is_alive(shooter) else self
	if CombatUtils.apply_damage(alvo, damage, origem):  # Só avisa se o dano foi aceito.
		damage_dealt.emit(notificar, damage)  # Avisa o jogador.


## Volta ao pool uma vez só.
## Devolve o tiro ao pool uma única vez.
func _consumir() -> void:
	if _consumido:  # Já devolvido.
		return
	_consumido = true  # Marca como consumido.
	recycle()  # Volta ao pool.
