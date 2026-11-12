class_name DefensePortal
extends Area2D
## Portal da fase de defesa. A arte é o PNG `assets/defesa/portal.png` (6 quadros x 2 linhas: carregando / pronto).
## Os inimigos ORIGINAIS (Drone, Atirador, Tank) o atacam sem código novo: o corpo `Corpo` (grupo `enemy_target`,
## camada do jogador) liga os sensores de alcance deles e a `Hurtbox` (camada das hurtboxes do jogador) recebe
## os golpes, os tiros e as ondas de choque. Cada golpe aceito tira HIT_DAMAGE, qualquer que seja o inimigo.
##
## Carrega por CHARGE_TIME segundos; ao chegar lá fica READY, mas a fase NÃO termina: o jogador precisa entrar nele.
## Sem _process: carga, crescimento e animação são Tweens.

signal hp_changed(hp: int, hp_max: int)  # A vida mudou.
signal charge_changed(ratio: float)  # A carga mudou (0..1).
signal became_ready  # A carga chegou ao fim: o portal pode ser usado.
signal destroyed  # A vida chegou a zero.
signal entered  # O jogador entrou com o portal READY.
signal entry_denied  # O jogador tocou o portal ainda carregando.

enum State { CHARGING, READY, DESTROYED, USED }

# ===== BALANCEAMENTO (valores editáveis) =====
const MAX_HP: int = 100  # Vida do portal.
const HIT_DAMAGE: int = 10  # Dano de CADA golpe de inimigo (100 de vida = 10 golpes).
const HIT_COOLDOWN_MSEC: int = 150  # Dois golpes em menos que isso contam como um (ondas e tiros em rajada).
const CHARGE_TIME: float = 30.0  # Tempo (s) até ficar READY.
const GROWTH_PER_SECOND: float = 0.005  # Crescimento visual: +0,5 % da escala base por segundo.
const MAX_SCALE: float = 1.35  # Escala máxima do portal (1.0 = tamanho inicial).
const FRAME_TIME: float = 0.12  # Duração de cada quadro da animação (s).
const HURT_FLASH_COLOR: Color = Color(2.4, 0.6, 0.6)  # Pisca ao levar dano.
const HURT_FLASH_TIME: float = 0.12
const READY_PULSE: Color = Color(1.35, 1.3, 1.1)  # Brilho do pulso quando READY.
const FRAMES: int = 6  # Colunas do PNG.
const ROW_CHARGING: int = 0  # Linha do PNG: carregando.
const ROW_READY: int = 1  # Linha do PNG: pronto.

@export var sprite: Sprite2D  # Sprite do portal (portal.png, hframes 6, vframes 2).
@export var hurtbox: Hurtbox  # Recebe os golpes dos inimigos.

## Vida atual.
var hp: int = MAX_HP
var state: State = State.CHARGING

## Carga de 0 a 1, animada por um Tween; o setter avisa quem escuta.
var charge: float = 0.0:
	set(value):
		charge = clampf(value, 0.0, 1.0)
		charge_changed.emit(charge)

var _row: int = ROW_CHARGING
var _last_hit_msec: int = -1000
var _charge_tween: Tween = null
var _growth_tween: Tween = null
var _anim_tween: Tween = null
var _flash_tween: Tween = null
var _pulse_tween: Tween = null


func _ready() -> void:
	if sprite == null or hurtbox == null:
		push_error("DefensePortal: 'sprite' e 'hurtbox' precisam ser atribuídos no Inspector.")
		return
	hurtbox.actor = self
	body_entered.connect(_on_body_entered)
	start()


## Liga a carga, o crescimento e a animação (chamado no _ready; chame de novo para reiniciar).
func start() -> void:
	hp = MAX_HP
	state = State.CHARGING
	scale = Vector2.ONE
	_row = ROW_CHARGING
	charge = 0.0
	sprite.modulate = Color.WHITE
	hurtbox.set_active(true)
	hp_changed.emit(hp, MAX_HP)
	_kill_tween(_pulse_tween)
	_kill_tween(_charge_tween)
	_charge_tween = create_tween()
	_charge_tween.tween_property(self, "charge", 1.0, CHARGE_TIME)
	_charge_tween.tween_callback(_on_charged)
	_kill_tween(_growth_tween)
	_growth_tween = create_tween()
	_growth_tween.tween_property(self, "scale", Vector2.ONE * MAX_SCALE, (MAX_SCALE - 1.0) / GROWTH_PER_SECOND)
	_kill_tween(_anim_tween)
	_anim_tween = create_tween().set_loops()
	_anim_tween.tween_method(_set_frame, 0.0, float(FRAMES), FRAME_TIME * float(FRAMES))


## API de dano do projeto (a Hurtbox entrega aqui). Cada golpe aceito tira HIT_DAMAGE. Devolve true se contou.
func take_damage(_amount: int, _source: Variant = null) -> bool:
	if state == State.DESTROYED or state == State.USED:
		return false
	var now: int = Time.get_ticks_msec()
	if now - _last_hit_msec < HIT_COOLDOWN_MSEC:
		return false
	_last_hit_msec = now
	hp = maxi(hp - HIT_DAMAGE, 0)
	hp_changed.emit(hp, MAX_HP)
	_flash_tween = CombatUtils.flash_sprite(sprite, _flash_tween, HURT_FLASH_COLOR, HURT_FLASH_TIME)
	if hp == 0:
		_destroy()
	return true


## Usado por CombatUtils.is_dead_actor: portal destruído ou usado não é mais alvo.
func is_dead() -> bool:
	return state == State.DESTROYED or state == State.USED


## True quando a carga terminou e o portal pode ser usado.
func is_ready_to_enter() -> bool:
	return state == State.READY


## Para tudo (usado ao sair da fase ou no game over).
func halt() -> void:
	for tween: Tween in [_charge_tween, _growth_tween, _anim_tween, _pulse_tween]:
		_kill_tween(tween)


## A carga chegou a 100 %: troca para a linha "pronto" do PNG e pulsa. A fase continua.
func _on_charged() -> void:
	if state != State.CHARGING:
		return
	state = State.READY
	_row = ROW_READY
	became_ready.emit()
	_kill_tween(_pulse_tween)
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(sprite, "modulate", READY_PULSE, 0.45).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(sprite, "modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_SINE)


## Vida zerada: para a carga e some.
func _destroy() -> void:
	state = State.DESTROYED
	halt()
	hurtbox.set_active(false)
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.6)
	destroyed.emit()


## O jogador tocou o portal.
func _on_body_entered(body: Node2D) -> void:
	if not CombatUtils.is_player(body):
		return
	if state == State.READY:
		state = State.USED
		halt()
		hurtbox.set_active(false)
		entered.emit()
	elif state == State.CHARGING:
		entry_denied.emit()


func _set_frame(value: float) -> void:
	sprite.frame_coords = Vector2i(int(value) % FRAMES, _row)


func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
