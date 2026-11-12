class_name Sword
extends Weapon
## Espada: golpe em 3 fases controladas por corrotina (await).

# Fases do golpe: parada, preparação, golpe ativo e recuperação.
enum Phase { IDLE, WINDUP, ACTIVE, RECOVERY }

const SLASH_ANIMATION: StringName = &"slash"  # Nome da animação do golpe.
## Raio da hitbox do golpe (px). O chefão Guide usa um múltiplo dele.
const HITBOX_RADIUS: float = 28.0
## Distância do centro da arma ao centro da hitbox e do efeito visual (px).
const HITBOX_DISTANCE: float = 34.0
## Escala original do efeito visual do golpe (definida na cena).
const SLASH_SPRITE_BASE_SCALE: float = 0.186

@export_group("Alcance")
## Multiplicador da hitbox (raio, distância e efeito visual) da espada do player: 1.4 = +40%.
## O chefão Guide continua usando HITBOX_RADIUS puro.
@export_range(0.5, 3.0, 0.05) var hitbox_scale: float = 1.4

@export_group("Tempo do golpe")
@export_range(0.0, 1.0, 0.01) var windup_time: float = 0.08  # Tempo de preparação.
@export_range(0.01, 1.0, 0.01) var active_time: float = 0.14  # Tempo do golpe ativo (hitbox ligada).
@export_range(0.0, 1.0, 0.01) var recovery_time: float = 0.16  # Tempo de recuperação.

@export_group("Referências (já ligadas na cena)")
@export var hitbox: Hitbox  # Hitbox do golpe.
@export var hitbox_shape: CollisionShape2D  # Forma da hitbox.
@export var slash_sprite: Sprite2D  # Sprite do efeito do golpe.
@export var animation_player: AnimationPlayer  # Tocador de animações do golpe.

var phase: Phase = Phase.IDLE  # Fase atual.

var _swing_id: int = 0  # Número do golpe atual (invalida corrotinas de golpes cancelados).


## Prepara a hitbox: dano ao encostar, um acerto por alvo, começa desligada e o efeito visual escondido.
func _ready() -> void:
	super._ready()  # Prepara a arma base.
	if hitbox == null:  # Sem hitbox não funciona.
		push_warning("Sword '%s': 'hitbox' não atribuída." % name)  # Avisa o erro.
		return
	_apply_hitbox_size()  # Aplica o tamanho do golpe.
	hitbox.active_on_start = false  # Não começa ligada.
	hitbox.one_hit_per_target = true  # Um acerto por alvo.
	hitbox.damage_on_contact = true  # Dano ao encostar.
	hitbox.set_active(false)  # Desligada até a janela do golpe.
	# Quando acerta, a espada repassa o aviso.
	CombatUtils.connect_once(hitbox.hit_landed, _on_hitbox_hit_landed)
	if slash_sprite != null:  # Tem efeito visual.
		slash_sprite.visible = false  # Escondido até o golpe.


## Aplica o tamanho do golpe (HITBOX_RADIUS) na forma de colisão e no efeito visual.
## Aplica o tamanho do golpe na forma de colisão e no efeito visual (raio e distância vezes a escala).
func _apply_hitbox_size() -> void:
	# Forma própria com o raio escalado.
	CombatUtils.set_unique_circle_radius(hitbox_shape, HITBOX_RADIUS * hitbox_scale)
	hitbox.position.x = HITBOX_DISTANCE * hitbox_scale  # Afasta a hitbox do centro da arma.
	if slash_sprite != null:  # Tem efeito visual.
		slash_sprite.position.x = HITBOX_DISTANCE * hitbox_scale  # Afasta o efeito.
		slash_sprite.scale = Vector2.ONE * SLASH_SPRITE_BASE_SCALE * hitbox_scale  # Escala o efeito.


## Raio da área de golpe no mundo (px), já com a escala do portador.
## Raio da área de golpe no mundo, já com a escala do portador.
func get_zone_radius() -> float:
	return HITBOX_RADIUS * hitbox_scale * absf(global_scale.x)


## Distância do centro da arma ao centro da área de golpe no mundo.
## Distância do centro da arma ao centro da área de golpe no mundo (px).
func get_zone_distance() -> float:
	return HITBOX_DISTANCE * hitbox_scale * absf(global_scale.x)


## Diz se o golpe está em andamento (preparação ou golpe ativo).
## True enquanto o golpe está em andamento (preparação ou golpe ativo).
func is_swinging() -> bool:
	return phase == Phase.WINDUP or phase == Phase.ACTIVE


## Duração total do golpe: preparação, golpe ativo e recuperação.
func get_attack_duration() -> float:
	return windup_time + active_time + recovery_time


## Ao ser equipada, a hitbox passa a ignorar quem empunha.
func _on_equipped() -> void:
	if hitbox != null:  # Tem hitbox.
		hitbox.source = wielder  # nunca acerta a Hurtbox de quem empunha


## Gira a espada para a nova mira, só durante a preparação e o golpe ativo.
## Gira a espada para a nova mira.
func aim_at(direction: Vector2) -> void:
	if direction == Vector2.ZERO:  # Direção zero: ignora.
		return
	if phase == Phase.WINDUP or phase == Phase.ACTIVE:  # Só gira durante o golpe.
		rotation = direction.angle()  # Aponta para a mira.


## Começa o golpe: invalida golpes antigos, aponta a espada, aplica o dano e roda animação e corrotina.
func _start_attack(direction: Vector2) -> void:
	_swing_id += 1  # Novo número de golpe.
	rotation = direction.angle()  # Aponta para a direção.
	if hitbox != null:  # Tem hitbox.
		hitbox.damage = damage  # Dano atual (pode ter bônus de habilidades).
	_play_slash()  # Toca a animação.
	_run_swing(_swing_id)  # Roda as três fases.


## Interrompe o golpe: invalida a corrotina, fecha a hitbox e esconde o efeito.
func _stop_attack() -> void:
	_swing_id += 1  # invalida a corrotina em andamento
	_close_hit_window()  # Fecha a hitbox agora.
	phase = Phase.IDLE  # Volta à fase parada.
	if animation_player != null:  # Tem animação.
		animation_player.stop()  # Para a animação.
	if slash_sprite != null:  # Tem efeito visual.
		slash_sprite.visible = false  # Esconde o efeito.


## Corrotina do golpe.
## Corrotina do golpe: preparação, golpe ativo (hitbox ligada) e recuperação. Cada espera confere se o golpe não foi cancelado.
func _run_swing(id: int) -> void:
	phase = Phase.WINDUP  # Fase de preparação.
	if not await _wait(windup_time, id):  # Espera; false = golpe cancelado.
		return

	phase = Phase.ACTIVE  # Fase do golpe ativo.
	_open_hit_window()  # Liga a hitbox.
	if not await _wait(active_time, id):  # Espera.
		return
	_close_hit_window()  # Fecha a hitbox.

	phase = Phase.RECOVERY  # Fase de recuperação.
	if not await _wait(recovery_time, id):  # Espera.
		return

	phase = Phase.IDLE  # Volta à fase parada.
	_finish(true)  # Termina como completo.


## Espera em tempo de física respeitando a pausa.
## Espera em tempo de física, respeitando a pausa. Devolve false se o golpe foi cancelado ou a espada saiu da cena.
func _wait(seconds: float, id: int) -> bool:
	if seconds > 0.0:  # Só espera se há tempo.
		if not is_inside_tree():  # Fora da cena: cancela.
			return false
		await get_tree().create_timer(seconds, false, true).timeout  # Timer de jogo (pausa respeitada).
	# Só vale se o golpe é o mesmo e a espada ainda está na cena.
	return id == _swing_id and is_inside_tree()


## Abre a janela de dano: liga a hitbox.
func _open_hit_window() -> void:
	if hitbox != null:  # Tem hitbox.
		hitbox.set_active(true)  # Liga.


## Fecha a janela de dano: desliga a hitbox.
func _close_hit_window() -> void:
	if hitbox != null and hitbox.is_active():  # Só se estiver ligada.
		hitbox.set_active(false)  # Desliga.


## Toca a animação do golpe, se existir.
func _play_slash() -> void:
	# Sem animação: nada a tocar.
	if animation_player == null or not animation_player.has_animation(SLASH_ANIMATION):
		return
	animation_player.stop()  # Reinicia a animação.
	animation_player.play(SLASH_ANIMATION)  # Toca.


## A hitbox acertou: avisa o dono do alvo e o dano causado.
func _on_hitbox_hit_landed(target: Area2D, damage_dealt: int) -> void:
	var victim: Node = CombatUtils.get_actor(target)  # Dono da hurtbox atingida.
	# Repassa (usa a própria área se não achar o dono).
	hit_landed.emit(victim if victim != null else target, damage_dealt)
