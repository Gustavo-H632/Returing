class_name Player
extends CharacterBody2D
## Alan Turing (jogador): movimento em 8 direções, dash, espada e tiro carregado.
## Máquina de estados por enum + match. A espada é uma Weapon independente:
## o estado ATTACK_MELEE só termina quando a arma emite attack_finished (ou no
## tempo limite de segurança), então animação e hitbox nunca saem de sincronia.

signal hp_changed(hp_atual: int, hp_maximo: int)
signal tomou_dano(quantidade: int)
signal causou_dano(alvo: Node, quantidade: int)
signal morreu
signal carga_mudou(percentual: float)
signal estado_mudou(novo_estado: int)

enum State { IDLE, MOVE, DASH, ATTACK_MELEE, ATTACK_RANGED, DEAD }

## Prefixo da animação por estado. Nome final: "<prefixo>_<down|up|side>".
const ANIM_PREFIX: Dictionary[State, String] = {
	State.IDLE: "idle",
	State.MOVE: "walk",
	State.DASH: "dash",
	State.ATTACK_MELEE: "attack",
	State.ATTACK_RANGED: "idle",
	State.DEAD: "death",
}

const ACTION_LEFT: StringName = &"move_left"
const ACTION_RIGHT: StringName = &"move_right"
const ACTION_UP: StringName = &"move_up"
const ACTION_DOWN: StringName = &"move_down"
const ACTION_DASH: StringName = &"dash"
const ACTION_MELEE: StringName = &"attack_sword"
const ACTION_SHOOT: StringName = &"charge_shoot"

const EIGHTH_TURN: float = PI / 4.0
## Folga somada à duração da espada antes de forçar a saída do ATTACK_MELEE.
const MELEE_SAFETY_MARGIN: float = 0.25

@export_group("Status")
@export var hp_maximo: int = 10000
@export var hp: int = 10000
@export var speed: float = 300.0
@export var dano_base: int = 10

@export_group("Dash")
@export var dash_speed: float = 400.0
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 0.6
@export var iframes_duration: float = 0.25

@export_group("Ataque Ranged")
@export var projectile_scene: PackedScene
@export var max_damage: int = 40
@export var charge_time: float = 1.2
@export_range(0.0, 1.0) var charge_move_multiplier: float = 0.4

@export_group("Animação")
## true = os quadros laterais da spritesheet olham para a direita.
@export var side_frames_face_right: bool = true

@export_group("Referências (já ligadas na cena)")
@export var sprite: Sprite2D
@export var animation_player: AnimationPlayer
@export var attack_pivot: Marker2D
@export var weapon: Weapon
@export var projectile_spawn: Marker2D
@export var hurtbox: Hurtbox

var state: State = State.IDLE
var facing_direction: Vector2 = Vector2.DOWN

var _input_dir: Vector2 = Vector2.ZERO
var _dash_dir: Vector2 = Vector2.DOWN
var _carga: float = 0.0
var _morto: bool = false

var _dash_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _iframes_left: float = 0.0
var _melee_safety_left: float = 0.0
var _current_anim: StringName = &""
var _sprite_offset_x: float = 0.0
## true durante exit/enter: sinais emitidos nesse intervalo não disparam outra troca.
var _transitioning: bool = false


func _enter_tree() -> void:
	add_to_group(CombatUtils.GROUP_PLAYER)


func _ready() -> void:
	hp_maximo = maxi(hp_maximo, 1)
	hp = clampi(hp, 0, hp_maximo)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	if sprite != null:
		_sprite_offset_x = sprite.offset.x

	_validar_referencias()
	_configurar_arma()
	_conectar_event_bus()

	_sincronizar_facing()
	_enter_state(state)
	EventBus.player_registered.emit(self)
	_emitir_estado_para_ui()


func _validar_referencias() -> void:
	var faltando: PackedStringArray = []
	if sprite == null: faltando.append("sprite")
	if animation_player == null: faltando.append("animation_player")
	if attack_pivot == null: faltando.append("attack_pivot")
	if weapon == null: faltando.append("weapon")
	if hurtbox == null: faltando.append("hurtbox")
	if not faltando.is_empty():
		push_warning("Player: referências não atribuídas: %s" % ", ".join(faltando))
	if not get_collision_layer_value(CombatUtils.LAYER_PLAYER):
		push_warning("Player: o corpo não está na camada 2 (Player); inimigos não vão detectá-lo.")


## Equipa a arma e liga os sinais (as conexões já estão gravadas na cena; connect_once evita duplicar).
func _configurar_arma() -> void:
	if weapon == null:
		return
	weapon.damage = dano_base
	weapon.equip(self)
	CombatUtils.connect_once(weapon.attack_finished, _on_weapon_attack_finished)
	CombatUtils.connect_once(weapon.hit_landed, _on_weapon_hit_landed)


## Espelha os sinais do Player no EventBus (HUD e fase não conhecem o Player).
func _conectar_event_bus() -> void:
	hp_changed.connect(func(atual: int, maximo: int) -> void: EventBus.player_hp_changed.emit(atual, maximo))
	tomou_dano.connect(func(quantidade: int) -> void: EventBus.player_damaged.emit(quantidade))
	causou_dano.connect(func(alvo: Node, quantidade: int) -> void: EventBus.player_dealt_damage.emit(alvo, quantidade))
	carga_mudou.connect(func(percentual: float) -> void: EventBus.player_charge_changed.emit(percentual))
	morreu.connect(func() -> void: EventBus.player_died.emit())
	EventBus.hud_refresh_requested.connect(_emitir_estado_para_ui)
	EventBus.player_heal_requested.connect(curar)


func _exit_tree() -> void:
	if EventBus.hud_refresh_requested.is_connected(_emitir_estado_para_ui):
		EventBus.hud_refresh_requested.disconnect(_emitir_estado_para_ui)
	if EventBus.player_heal_requested.is_connected(curar):
		EventBus.player_heal_requested.disconnect(curar)


func _emitir_estado_para_ui() -> void:
	hp_changed.emit(hp, hp_maximo)
	carga_mudou.emit(0.0 if state != State.ATTACK_RANGED else _carga / maxf(charge_time, 0.01))


func _physics_process(delta: float) -> void:
	_atualizar_cronometros(delta)
	_input_dir = Input.get_vector(ACTION_LEFT, ACTION_RIGHT, ACTION_UP, ACTION_DOWN)

	match state:
		State.IDLE, State.MOVE:
			_state_locomocao()
		State.DASH:
			_state_dash()
		State.ATTACK_MELEE:
			_state_attack_melee()
		State.ATTACK_RANGED:
			_state_attack_ranged(delta)
		State.DEAD:
			velocity = Vector2.ZERO

	move_and_slide()
	_atualizar_animacao()


func _atualizar_cronometros(delta: float) -> void:
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	_iframes_left = maxf(_iframes_left - delta, 0.0)
	_dash_left = maxf(_dash_left - delta, 0.0)
	_melee_safety_left = maxf(_melee_safety_left - delta, 0.0)


# --- Estados ------------------------------------------------------------------

func _state_locomocao() -> void:
	_atualizar_facing()
	velocity = _input_dir * speed
	if _tentar_acoes():
		return
	var movendo: bool = _input_dir != Vector2.ZERO
	if movendo and state == State.IDLE:
		change_state(State.MOVE)
	elif not movendo and state == State.MOVE:
		change_state(State.IDLE)


func _state_dash() -> void:
	velocity = _dash_dir * dash_speed
	if _dash_left <= 0.0:
		change_state(State.IDLE)


## Parado durante o golpe. A saída normal vem de _on_weapon_attack_finished.
func _state_attack_melee() -> void:
	velocity = Vector2.ZERO
	if _melee_safety_left <= 0.0:
		change_state(State.IDLE)  # rede de segurança: nunca trava no ataque


func _state_attack_ranged(delta: float) -> void:
	_atualizar_facing()
	velocity = _input_dir * speed * charge_move_multiplier

	var tempo_total: float = maxf(charge_time, 0.01)
	if _carga < tempo_total:
		_carga = minf(_carga + delta, tempo_total)
		carga_mudou.emit(_carga / tempo_total)

	if Input.is_action_just_pressed(ACTION_DASH) and _pode_dashar():
		change_state(State.DASH)
		return
	if not Input.is_action_pressed(ACTION_SHOOT):
		_disparar_projetil()
		change_state(State.IDLE)


func _tentar_acoes() -> bool:
	if Input.is_action_just_pressed(ACTION_DASH) and _pode_dashar():
		change_state(State.DASH)
	elif Input.is_action_just_pressed(ACTION_MELEE):
		return atacar_com_arma()
	elif Input.is_action_just_pressed(ACTION_SHOOT):
		change_state(State.ATTACK_RANGED)
	else:
		return false
	return true


## Inicia o golpe da arma. Público para testes e IA. true se o golpe começou.
func atacar_com_arma() -> bool:
	if _morto or weapon == null or state == State.ATTACK_MELEE or not weapon.can_attack():
		return false
	change_state(State.ATTACK_MELEE)
	return state == State.ATTACK_MELEE


func _pode_dashar() -> bool:
	return _dash_cooldown_left <= 0.0


func change_state(novo_estado: State) -> void:
	if _morto or _transitioning or novo_estado == state:
		return
	_transitioning = true
	_exit_state(state)
	state = novo_estado
	_enter_state(novo_estado)
	_transitioning = false
	estado_mudou.emit(novo_estado)


func _enter_state(s: State) -> void:
	match s:
		State.DASH:
			var base_dir: Vector2 = _input_dir if _input_dir != Vector2.ZERO else facing_direction
			_dash_dir = base_dir.normalized() if base_dir != Vector2.ZERO else Vector2.DOWN
			velocity = _dash_dir * dash_speed
			_dash_left = dash_duration
			_iframes_left = maxf(_iframes_left, iframes_duration)
		State.ATTACK_MELEE:
			velocity = Vector2.ZERO
			_melee_safety_left = weapon.get_attack_duration() + MELEE_SAFETY_MARGIN
			if not weapon.attack(facing_direction):
				_melee_safety_left = 0.0  # arma recusou: sai no próximo frame
		State.ATTACK_RANGED:
			_carga = 0.0
			carga_mudou.emit(0.0)
	_atualizar_animacao(true)


func _exit_state(s: State) -> void:
	match s:
		State.DASH:
			_dash_left = 0.0
			_dash_cooldown_left = dash_cooldown
		State.ATTACK_MELEE:
			_melee_safety_left = 0.0
			if weapon != null and weapon.is_attacking():
				weapon.cancel()  # saída forçada: fecha a hitbox imediatamente
		State.ATTACK_RANGED:
			_carga = 0.0
			carga_mudou.emit(0.0)


# --- Arma -----------------------------------------------------------------------

func _on_weapon_attack_finished(_completed: bool) -> void:
	# Ignora o aviso gerado pelo próprio cancel() durante uma troca de estado.
	if state == State.ATTACK_MELEE and not _transitioning:
		change_state(State.IDLE)


func _on_weapon_hit_landed(target: Node, damage_dealt: int) -> void:
	causou_dano.emit(target, damage_dealt)


# --- Direção e animação ---------------------------------------------------------

func _atualizar_facing() -> void:
	if _input_dir == Vector2.ZERO:
		return
	var ang: float = roundf(_input_dir.angle() / EIGHTH_TURN) * EIGHTH_TURN
	var nova: Vector2 = Vector2.from_angle(ang)
	if not nova.is_equal_approx(facing_direction):
		facing_direction = nova
		_sincronizar_facing()


func _sincronizar_facing() -> void:
	if attack_pivot != null:
		attack_pivot.rotation = facing_direction.angle()


## Sufixo de direção da animação (4 direções a partir das 8 de movimento).
func _direction_suffix() -> String:
	if absf(facing_direction.x) + 0.01 >= absf(facing_direction.y):
		return "side"
	return "down" if facing_direction.y > 0.0 else "up"


## Escolhe e toca a animação do estado atual. Só reinicia se o nome mudar,
## exceto em `force` (entrada de estado), que reinicia golpes consecutivos.
func _atualizar_animacao(force: bool = false) -> void:
	if animation_player == null:
		return
	var suffix: String = _direction_suffix()
	if sprite != null and suffix == "side":
		var looking_left: bool = facing_direction.x < 0.0
		var flipped: bool = looking_left if side_frames_face_right else not looking_left
		sprite.flip_h = flipped
		sprite.offset.x = -_sprite_offset_x if flipped else _sprite_offset_x
	var anim_name: StringName = _resolve_animation(ANIM_PREFIX[state], suffix)
	if anim_name == &"":
		return
	if anim_name == _current_anim and not force and animation_player.is_playing():
		return
	_current_anim = anim_name
	animation_player.play(anim_name)
	if force:
		animation_player.seek(0.0, true)


## "<prefixo>_<dir>" -> "<prefixo>_side" -> "<prefixo>" -> "idle_<dir>".
func _resolve_animation(prefix: String, suffix: String) -> StringName:
	for candidate: String in ["%s_%s" % [prefix, suffix], "%s_side" % prefix, prefix, "idle_%s" % suffix]:
		if animation_player.has_animation(candidate):
			return StringName(candidate)
	return &""


# --- Tiro carregado -------------------------------------------------------------

func _disparar_projetil() -> void:
	if projectile_scene == null:
		push_warning("Player: projectile_scene não foi definida.")
		return
	var origem: Vector2 = projectile_spawn.global_position if projectile_spawn != null else global_position
	var projetil := CombatUtils.spawn(projectile_scene, self, origem, PlayerProjectile) as PlayerProjectile
	if projetil == null:
		push_warning("Player: projectile_scene precisa ter player_projectile.gd na raiz.")
		return
	var ratio: float = clampf(_carga / maxf(charge_time, 0.01), 0.0, 1.0)
	projetil.direction = facing_direction
	projetil.damage = roundi(lerpf(float(dano_base), float(max_damage), ratio))
	projetil.shooter = self


# --- Vida -------------------------------------------------------------------------

func esta_invulneravel() -> bool:
	return _iframes_left > 0.0


func esta_morto() -> bool:
	return _morto


## API de dano do projeto (Hurtbox -> ator). false se recusou (morto/i-frames).
func take_damage(quantidade: int, _source: Variant = null) -> bool:
	return tomar_dano(quantidade)


func tomar_dano(quantidade: int) -> bool:
	if _morto or quantidade <= 0 or esta_invulneravel():
		return false
	var aplicado: int = mini(quantidade, hp)
	hp -= aplicado
	hp_changed.emit(hp, hp_maximo)
	tomou_dano.emit(aplicado)
	if hp == 0:
		_morrer()
	return true


func curar(quantidade: int) -> int:
	if _morto or quantidade <= 0 or hp >= hp_maximo:
		return 0
	var antes: int = hp
	hp = mini(hp + quantidade, hp_maximo)
	hp_changed.emit(hp, hp_maximo)
	return hp - antes


## Dano causado pelo player (projétil usa este caminho para avisar a HUD).
func causar_dano(alvo: Node, quantidade: int, notificar: Node = null) -> bool:
	if not CombatUtils.apply_damage(alvo, quantidade, self):
		return false
	causou_dano.emit(notificar if notificar != null else alvo, quantidade)
	return true


func _morrer() -> void:
	_transitioning = true
	_exit_state(state)
	state = State.DEAD
	_morto = true
	velocity = Vector2.ZERO
	if weapon != null:
		weapon.cancel()
	if hurtbox != null:
		hurtbox.set_active(false)
	_transitioning = false
	_atualizar_animacao(true)
	set_physics_process(false)
	estado_mudou.emit(State.DEAD)
	morreu.emit()
