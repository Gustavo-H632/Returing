class_name Player
extends CharacterBody2D
## Alan Turing (jogador): movimento em 8 direções, dash, espada e tiro carregado.

signal hp_changed(hp_atual: int, hp_maximo: int)
signal tomou_dano(quantidade: int)
signal causou_dano(alvo: Node, quantidade: int)
signal morreu
signal carga_mudou(percentual: float)
signal estado_mudou(novo_estado: int)

enum State { IDLE, MOVE, DASH, ATTACK_MELEE, ATTACK_RANGED, DEAD }

## Como a direção do dash é escolhida.
enum DashAim {
	## Usa o vetor de movimento atual (WASD).
	MOVIMENTO_OU_MOUSE,
	## Sempre em direção ao cursor, mesmo andando para outro lado.
	SEMPRE_MOUSE,
}

## Prefixo da animação por estado.
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
## Índice numérico de cada sufixo de direção (chave do cache de animações).
const _SUFFIX_INDEX: Dictionary[String, int] = {"side": 0, "down": 1, "up": 2}
## Multiplicador do estado na chave do cache: estado * passo + índice do sufixo.
const _ANIM_KEY_STRIDE: int = 3
## Folga somada à duração da espada antes de forçar a saída do ATTACK_MELEE.
const MELEE_SAFETY_MARGIN: float = 0.25

@export_group("Status")
@export var hp_maximo: int = 100
@export var hp: int = 100

@export_group("Regeneração")
## Segundos seguidos sem receber dano para a regeneração começar.
@export_range(0.0, 60.0, 0.5, "or_greater") var regen_delay: float = 10.0
## Vida recuperada por segundo depois do atraso.
@export_range(0.0, 20.0, 0.1, "or_greater") var regen_per_second: float = 1.0

@export_group("Status")
@export var speed: float = 300.0
@export var dano_base: int = 10

@export_group("Dash")
@export var dash_speed: float = 400.0
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 0.6
@export var iframes_duration: float = 0.25
## Regra de direção do dash (movimento/mouse).
@export var dash_aim: DashAim = DashAim.MOVIMENTO_OU_MOUSE

@export_group("Ataque Ranged")
@export var projectile_scene: PackedScene
@export var max_damage: int = 40
@export var charge_time: float = 1.2
@export_range(0.0, 1.0) var charge_move_multiplier: float = 0.4

@export_group("Mira (mouse)")
## Distância mínima (px) entre o jogador e o cursor para a mira ser atualizada.
@export var aim_deadzone: float = 6.0

@export_group("Dano")
## Cor do pisca ao tomar dano.
@export var hurt_flash_color: Color = Color(2.2, 0.35, 0.35, 1.0)
## Quanto tempo o pisca dura.
@export_range(0.0, 1.0, 0.01) var hurt_flash_time: float = 0.12

@export_group("Animação")
## True = os quadros laterais da spritesheet olham para a direita.
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
## Direção da mira.
var aim_direction: Vector2 = Vector2.DOWN

var _input_dir: Vector2 = Vector2.ZERO
## Último vetor de movimento não nulo.
var _last_move_dir: Vector2 = Vector2.DOWN
var _dash_dir: Vector2 = Vector2.DOWN
var _carga: float = 0.0
## Regeneração: tempo seguido sem dano e fração de HP acumulada.
var _tempo_sem_dano: float = 0.0
var _regen_acumulado: float = 0.0
var _morto: bool = false

var _flash_tween: Tween = null

var _dash_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _iframes_left: float = 0.0
var _melee_safety_left: float = 0.0
var _current_anim: StringName = &""
var _sprite_offset_x: float = 0.0
## Cache "estado + direção" -> nome da animação.
var _anim_cache: Dictionary[int, StringName] = {}
## True durante exit/enter.
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


## Equipa a arma e liga os sinais dela.
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
	EventBus.player_damage_requested.connect(_on_dano_solicitado)


func _exit_tree() -> void:
	if EventBus.hud_refresh_requested.is_connected(_emitir_estado_para_ui):
		EventBus.hud_refresh_requested.disconnect(_emitir_estado_para_ui)
	if EventBus.player_heal_requested.is_connected(curar):
		EventBus.player_heal_requested.disconnect(curar)
	if EventBus.player_damage_requested.is_connected(_on_dano_solicitado):
		EventBus.player_damage_requested.disconnect(_on_dano_solicitado)


func _emitir_estado_para_ui() -> void:
	hp_changed.emit(hp, hp_maximo)
	carga_mudou.emit(0.0 if state != State.ATTACK_RANGED else _carga / maxf(charge_time, 0.01))


func _physics_process(delta: float) -> void:
	_atualizar_cronometros(delta)
	_input_dir = Input.get_vector(ACTION_LEFT, ACTION_RIGHT, ACTION_UP, ACTION_DOWN)
	if _input_dir != Vector2.ZERO:
		_last_move_dir = _input_dir.normalized()
	_atualizar_mira()

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
	_atualizar_regeneracao(delta)
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	_iframes_left = maxf(_iframes_left - delta, 0.0)
	_dash_left = maxf(_dash_left - delta, 0.0)
	_melee_safety_left = maxf(_melee_safety_left - delta, 0.0)


# --- Estados ---

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


## Parado durante o golpe.
func _state_attack_melee() -> void:
	velocity = Vector2.ZERO
	# A espada acompanha o cursor durante o golpe.
	# de direção no meio do golpe (reiniciaria a animação de ataque).
	if weapon != null:
		weapon.aim_at(aim_direction)
	if _melee_safety_left <= 0.0:
		change_state(State.IDLE)  # rede de segurança: nunca trava no ataque


func _state_attack_ranged(delta: float) -> void:
	_apontar_para_mouse()  # durante a carga o personagem encara o cursor, não o movimento
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


## Inicia o golpe da arma.
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
			_dash_dir = _escolher_direcao_dash()
			# Sprite e animação do dash passam a olhar para a direção real do dash.
			facing_direction = _dash_dir
			_sincronizar_facing()
			velocity = _dash_dir * dash_speed
			_dash_left = dash_duration
			_iframes_left = maxf(_iframes_left, iframes_duration)
		State.ATTACK_MELEE:
			_iniciar_golpe()
		State.ATTACK_RANGED:
			_carga = 0.0
			carga_mudou.emit(0.0)
			_apontar_para_mouse()
	_atualizar_animacao(true)


## Entrada do ATTACK_MELEE.
func _iniciar_golpe() -> void:
	velocity = Vector2.ZERO
	_atualizar_mira()
	facing_direction = aim_direction
	_sincronizar_facing()
	if weapon == null:
		_melee_safety_left = 0.0
		return
	_melee_safety_left = weapon.get_attack_duration() + MELEE_SAFETY_MARGIN
	if not weapon.attack(aim_direction):
		_melee_safety_left = 0.0  # arma recusou: sai no próximo frame


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


# --- Arma ---

func _on_weapon_attack_finished(_completed: bool) -> void:
	# Ignora o aviso gerado pelo próprio cancel() durante uma troca de estado.
	if state == State.ATTACK_MELEE and not _transitioning:
		change_state(State.IDLE)


func _on_weapon_hit_landed(target: Node, damage_dealt: int) -> void:
	causou_dano.emit(target, damage_dealt)


# --- Mira e dash pelo mouse ---

## Atualiza `aim_direction` com a posição atual do cursor.
func _atualizar_mira() -> void:
	aim_direction = _direcao_para_mouse(global_position, aim_direction)


## Direção normalizada de `desde` até o cursor, em coordenadas de mundo.
func _direcao_para_mouse(desde: Vector2, fallback: Vector2) -> Vector2:
	var para_cursor: Vector2 = get_global_mouse_position() - desde
	if para_cursor.length() < aim_deadzone:
		return fallback
	return para_cursor.normalized()


## Vira o personagem (sprite e AttackPivot, onde nasce o projétil) para o cursor.
func _apontar_para_mouse() -> void:
	if not facing_direction.is_equal_approx(aim_direction):
		facing_direction = aim_direction
		_sincronizar_facing()


## Direção do dash, conforme `dash_aim`: 1.
func _escolher_direcao_dash() -> Vector2:
	var dir: Vector2
	if dash_aim == DashAim.MOVIMENTO_OU_MOUSE and _input_dir != Vector2.ZERO:
		dir = _input_dir
	else:
		dir = _direcao_para_mouse(global_position, _last_move_dir)
	return dir.normalized() if dir != Vector2.ZERO else Vector2.DOWN


# --- Direção e animação ---

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


## Escolhe e toca a animação do estado atual.
func _atualizar_animacao(force: bool = false) -> void:
	if animation_player == null:
		return
	var suffix: String = _direction_suffix()
	if suffix == "side":
		_aplicar_flip_lateral()
	var anim_name: StringName = _animation_for(state, suffix)
	if anim_name == &"":
		return
	if anim_name == _current_anim and not force and animation_player.is_playing():
		return
	_current_anim = anim_name
	animation_player.play(anim_name)
	if force:
		animation_player.seek(0.0, true)


## Espelha o sprite nos quadros laterais, mantendo o conteúdo centralizado.
func _aplicar_flip_lateral() -> void:
	if sprite == null:
		return
	var looking_left: bool = facing_direction.x < 0.0
	var flipped: bool = looking_left if side_frames_face_right else not looking_left
	sprite.flip_h = flipped
	sprite.offset.x = -_sprite_offset_x if flipped else _sprite_offset_x


## Pega o nome da animação do estado e da direção.
func _animation_for(s: State, suffix: String) -> StringName:
	var key: int = s * _ANIM_KEY_STRIDE + _SUFFIX_INDEX[suffix]
	if not _anim_cache.has(key):
		_anim_cache[key] = _resolve_animation(ANIM_PREFIX[s], suffix)
	return _anim_cache[key]


## "<prefixo>_<dir>" -> "<prefixo>_side" -> "<prefixo>" -> "idle_<dir>".
func _resolve_animation(prefix: String, suffix: String) -> StringName:
	for candidate: String in ["%s_%s" % [prefix, suffix], "%s_side" % prefix, prefix, "idle_%s" % suffix]:
		if animation_player.has_animation(candidate):
			return StringName(candidate)
	return &""


# --- Tiro carregado ---

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
	# Mira a partir do ponto de nascimento (não do centro do jogador).
	# sai exatamente na linha que liga a boca do disparo ao cursor.
	projetil.direction = _direcao_para_mouse(origem, aim_direction)
	projetil.damage = roundi(lerpf(float(dano_base), float(max_damage), ratio))
	projetil.shooter = self
	projetil.damage_dealt.connect(_on_projectile_damage_dealt)


# --- Vida ---

func esta_invulneravel() -> bool:
	return _iframes_left > 0.0


func esta_morto() -> bool:
	return _morto


## API de dano do projeto (Hurtbox -> ator).
func take_damage(quantidade: int, _source: Variant = null) -> bool:
	return tomar_dano(quantidade)


## Pedido de dano vindo do EventBus (ex.: erro no quiz).
func _on_dano_solicitado(quantidade: int) -> void:
	tomar_dano(quantidade, true)


## `ignorar_iframes` = true aplica o dano mesmo com o player invulnerável (dash).
func tomar_dano(quantidade: int, ignorar_iframes: bool = false) -> bool:
	if _morto or quantidade <= 0:
		return false
	if esta_invulneravel() and not ignorar_iframes:
		return false
	var aplicado: int = mini(quantidade, hp)
	hp -= aplicado
	_tempo_sem_dano = 0.0  # Regeneração: dano reinicia a contagem dos 10 s.
	_regen_acumulado = 0.0
	hp_changed.emit(hp, hp_maximo)
	tomou_dano.emit(aplicado)
	_piscar()
	if hp == 0:
		_morrer()
	return true


## Pisca o sprite de vermelho por um instante.
func _piscar() -> void:
	if sprite == null or _morto:
		return
	_apagar_pisca()
	sprite.self_modulate = hurt_flash_color
	_flash_tween = create_tween()
	# Segue rodando com o jogo pausado: o dano do quiz chega assim.
	_flash_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_flash_tween.tween_property(sprite, ^"self_modulate", Color.WHITE, hurt_flash_time)


## Corta o pisca e devolve a cor normal.
func _apagar_pisca() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	if sprite != null:
		sprite.self_modulate = Color.WHITE


## Regenera vida depois de um tempo sem apanhar.
func _atualizar_regeneracao(delta: float) -> void:
	if _morto or hp >= hp_maximo:
		_regen_acumulado = 0.0
		return
	_tempo_sem_dano += delta
	if _tempo_sem_dano < regen_delay:
		return
	_regen_acumulado += regen_per_second * delta
	if _regen_acumulado >= 1.0:
		var inteiro: int = int(_regen_acumulado)
		_regen_acumulado -= float(inteiro)
		curar(inteiro)


func curar(quantidade: int) -> int:
	if _morto or quantidade <= 0 or hp >= hp_maximo:
		return 0
	var antes: int = hp
	hp = mini(hp + quantidade, hp_maximo)
	hp_changed.emit(hp, hp_maximo)
	return hp - antes


## O projétil avisa por sinal.
func _on_projectile_damage_dealt(alvo: Node, quantidade: int) -> void:
	causou_dano.emit(alvo, quantidade)


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
	_apagar_pisca()
	_transitioning = false
	_atualizar_animacao(true)
	set_physics_process(false)
	estado_mudou.emit(State.DEAD)
	morreu.emit()
