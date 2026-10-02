class_name Player
extends CharacterBody2D
## Player (Alan Turing): movimento em 8 direções, dash, ataque melee e tiro carregado.
## State machine própria com enum + match.

signal hp_changed(hp_atual: int, hp_maximo: int)
signal tomou_dano(quantidade: int)
signal causou_dano(alvo: Node, quantidade: int)
signal morreu
signal carga_mudou(percentual: float)
signal estado_mudou(novo_estado: int)

enum State { IDLE, MOVE, DASH, ATTACK_MELEE, ATTACK_RANGED }

const ANIM_NAMES: Dictionary[State, StringName] = {
	State.IDLE: &"Idle",
	State.MOVE: &"Walk",
	State.DASH: &"Dash",
	State.ATTACK_MELEE: &"AttackMelee",
	State.ATTACK_RANGED: &"AttackRanged",
}

const ACTION_LEFT: StringName = &"move_left"
const ACTION_RIGHT: StringName = &"move_right"
const ACTION_UP: StringName = &"move_up"
const ACTION_DOWN: StringName = &"move_down"
const ACTION_DASH: StringName = &"dash"
const ACTION_MELEE: StringName = &"attack_sword"
const ACTION_SHOOT: StringName = &"charge_shoot"

const EIGHTH_TURN: float = PI / 4.0


@export_group("Status")
@export var hp_maximo: int = 10000
@export var hp: int = 10000
@export var speed: float = 300.0
@export var dano_base: int = 10

@export_group("Dash")
@export var dash_speed: float = 400.0
@export var dash_duration: float = 0.18      ## Tempo de deslocamento.
@export var dash_cooldown: float = 0.6       ## Espera para outro dash.
@export var iframes_duration: float = 0.25   ## Invulnerabilidade iniciada no dash.

@export_group("Ataque Melee")
@export var melee_duration: float = 0.30

@export_group("Ataque Ranged")
@export var projectile_scene: PackedScene
@export var max_damage: int = 40             ## Dano com carga cheia.
@export var charge_time: float = 1.2         ## Segundos até a carga máxima.
@export_range(0.0, 1.0) var charge_move_multiplier: float = 0.4

@export_group("Animação")
@export var sprites_4_direcoes: bool = true

## Referências de nós: arraste cada nó do Player no Inspector.
@export_group("Referências (arraste os nós)")
@export var attack_pivot: Marker2D
@export var melee_hitbox: Area2D
@export var projectile_spawn: Marker2D
@export var hurtbox: Hurtbox
@export var anim_tree: AnimationTree  ## Opcional.

var state: State = State.IDLE
var facing_direction: Vector2 = Vector2.DOWN

var playback: AnimationNodeStateMachinePlayback = null

var _input_dir: Vector2 = Vector2.ZERO
var _dash_dir: Vector2 = Vector2.DOWN
var _carga: float = 0.0
var _alvos_atingidos: Array[Node] = []
var _morto: bool = false

# Cronômetros em segundos (no lugar de nós Timer)
var _dash_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _iframes_left: float = 0.0
var _melee_left: float = 0.0

static var _avisou_anim_tree: bool = false

var _blend_params: Array[StringName] = []
var _anim_sm: AnimationNodeStateMachine = null


## Entra no grupo player antes de qualquer _ready.
func _enter_tree() -> void:
	# Os inimigos acham o player por este grupo.
	add_to_group(CombatUtils.GROUP_PLAYER)


## Valida referências, configura hitbox/animação e avisa a HUD.
func _ready() -> void:
	hp_maximo = maxi(hp_maximo, 1)
	hp = clampi(hp, 0, hp_maximo)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	_validar_referencias()
	_configurar_hitbox()
	_configurar_animation_tree()
	_avisar_camadas()
	_conectar_event_bus()

	_sincronizar_facing()
	_enter_state(state)
	EventBus.player_registered.emit(self)
	_emitir_estado_para_ui()


## Avisa no Output os slots vazios.
func _validar_referencias() -> void:
	if attack_pivot == null:
		push_warning("Player: 'attack_pivot' não foi atribuído no Inspector.")
	if melee_hitbox == null:
		push_warning("Player: 'melee_hitbox' não foi atribuído no Inspector; o golpe não funciona.")
	if projectile_spawn == null:
		push_warning("Player: 'projectile_spawn' não foi atribuído; o tiro sai do centro do Player.")
	if hurtbox == null:
		push_warning("Player: 'hurtbox' não foi atribuído; o morto não desliga a Hurtbox.")


## Espelha os sinais do Player no EventBus (HUD e fase não conhecem o Player).
func _conectar_event_bus() -> void:
	hp_changed.connect(func(atual: int, maximo: int) -> void: EventBus.player_hp_changed.emit(atual, maximo))
	tomou_dano.connect(func(quantidade: int) -> void: EventBus.player_damaged.emit(quantidade))
	causou_dano.connect(func(alvo: Node, quantidade: int) -> void: EventBus.player_dealt_damage.emit(alvo, quantidade))
	carga_mudou.connect(func(percentual: float) -> void: EventBus.player_charge_changed.emit(percentual))
	morreu.connect(func() -> void: EventBus.player_died.emit())
	# HUD pede o estado atual quando nasce
	EventBus.hud_refresh_requested.connect(_emitir_estado_para_ui)
	# Cura ao limpar uma onda
	EventBus.player_heal_requested.connect(curar)


## Reenvia HP e carga para a HUD.
func _emitir_estado_para_ui() -> void:
	hp_changed.emit(hp, hp_maximo)
	carga_mudou.emit(0.0 if state != State.ATTACK_RANGED else _carga / maxf(charge_time, 0.01))


## Melee começa desligada e só detecta por sinal.
func _configurar_hitbox() -> void:
	if melee_hitbox == null:
		return
	melee_hitbox.monitoring = false
	melee_hitbox.monitorable = false
	melee_hitbox.body_entered.connect(_on_melee_hitbox_body_entered)
	melee_hitbox.area_entered.connect(_on_melee_hitbox_area_entered)


## Prepara o AnimationTree (opcional).
func _configurar_animation_tree() -> void:
	if anim_tree == null:
		return
	_anim_sm = anim_tree.tree_root as AnimationNodeStateMachine
	if _anim_sm == null:
		# Sem Tree Root: desliga a árvore para não gerar erros
		anim_tree.active = false
		if not _avisou_anim_tree:  # avisa uma vez só
			_avisou_anim_tree = true
			push_warning("Player: AnimationTree sem AnimationNodeStateMachine como Tree Root; animações desativadas.")
		return

	anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	anim_tree.active = true
	var playback_value: Variant = anim_tree.get(&"parameters/playback")
	playback = playback_value if playback_value is AnimationNodeStateMachinePlayback else null

	# Guarda só os parâmetros de blend que existem
	_blend_params.clear()
	for nome: StringName in ANIM_NAMES.values():
		if _anim_sm.has_node(nome) and _anim_sm.get_node(nome) is AnimationNodeBlendSpace2D:  # audit-ok: API do AnimationNodeStateMachine (recurso), não da árvore
			_blend_params.append(StringName("parameters/%s/blend_position" % nome))


## Avisa se o corpo não está na camada Player.
func _avisar_camadas() -> void:
	if not get_collision_layer_value(CombatUtils.LAYER_PLAYER):
		push_warning("Player: o CharacterBody2D não está na camada 2 (Player); inimigos não vão detectá-lo.")


## Loop do player: cronômetros, input e estado atual.
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

	move_and_slide()


## Desconta o tempo de dash, i-frames e melee.
func _atualizar_cronometros(delta: float) -> void:
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	_iframes_left = maxf(_iframes_left - delta, 0.0)
	if _dash_left > 0.0:
		_dash_left -= delta
	if _melee_left > 0.0:
		_melee_left -= delta


## IDLE e MOVE usam a mesma lógica.
func _state_locomocao() -> void:
	_atualizar_facing()
	velocity = _input_dir * speed
	if _tentar_acoes():
		return
	var movendo := _input_dir != Vector2.ZERO
	if movendo and state == State.IDLE:
		change_state(State.MOVE)
	elif not movendo and state == State.MOVE:
		change_state(State.IDLE)


## Move na direção travada até o dash acabar.
func _state_dash() -> void:
	velocity = _dash_dir * dash_speed
	if _dash_left <= 0.0:
		change_state(State.IDLE)


## Parado enquanto o golpe dura.
func _state_attack_melee() -> void:
	velocity = Vector2.ZERO
	if _melee_left <= 0.0:
		change_state(State.IDLE)


## Carrega o tiro; solta o botão para disparar.
func _state_attack_ranged(delta: float) -> void:
	_atualizar_facing()
	velocity = _input_dir * speed * charge_move_multiplier

	var tempo_total := maxf(charge_time, 0.01)
	if _carga < tempo_total:
		_carga = minf(_carga + delta, tempo_total)
		carga_mudou.emit(_carga / tempo_total)

	if Input.is_action_just_pressed(ACTION_DASH) and _pode_dashar():
		change_state(State.DASH)
		return

	if not Input.is_action_pressed(ACTION_SHOOT):
		_disparar_projetil()
		change_state(State.IDLE)


## Dash, golpe ou tiro. true se trocou de estado.
func _tentar_acoes() -> bool:
	if Input.is_action_just_pressed(ACTION_DASH) and _pode_dashar():
		change_state(State.DASH)
	elif Input.is_action_just_pressed(ACTION_MELEE):
		change_state(State.ATTACK_MELEE)
	elif Input.is_action_just_pressed(ACTION_SHOOT):
		change_state(State.ATTACK_RANGED)
	else:
		return false
	return true


## Dash fora da recarga.
func _pode_dashar() -> bool:
	return _dash_cooldown_left <= 0.0


## Troca de estado (sai do atual e entra no novo).
func change_state(novo_estado: State) -> void:
	if _morto or novo_estado == state:
		return
	_exit_state(state)
	state = novo_estado
	_enter_state(novo_estado)
	estado_mudou.emit(novo_estado)


## Efeitos de entrada de cada estado.
func _enter_state(s: State) -> void:
	match s:
		State.DASH:
			var base_dir := _input_dir if _input_dir != Vector2.ZERO else facing_direction
			_dash_dir = base_dir.normalized() if base_dir != Vector2.ZERO else Vector2.DOWN
			velocity = _dash_dir * dash_speed
			_dash_left = dash_duration
			_iframes_left = maxf(_iframes_left, iframes_duration)
		State.ATTACK_MELEE:
			velocity = Vector2.ZERO
			_alvos_atingidos.clear()
			_set_melee_hitbox(true)
			_melee_left = melee_duration
		State.ATTACK_RANGED:
			_carga = 0.0
			carga_mudou.emit(0.0)
	_tocar_anim(ANIM_NAMES[s])


## Limpeza ao sair de cada estado.
func _exit_state(s: State) -> void:
	match s:
		State.DASH:
			_dash_left = 0.0
			_dash_cooldown_left = dash_cooldown
		State.ATTACK_MELEE:
			_melee_left = 0.0
			_set_melee_hitbox(false)
		State.ATTACK_RANGED:
			_carga = 0.0
			carga_mudou.emit(0.0)


## Liga/desliga a hitbox do golpe (deferido).
func _set_melee_hitbox(ligada: bool) -> void:
	if melee_hitbox != null:
		melee_hitbox.set_deferred(&"monitoring", ligada)


## Arredonda a direção para 8 lados.
func _atualizar_facing() -> void:
	if _input_dir == Vector2.ZERO:
		return  # mantém a última direção
	var ang := roundf(_input_dir.angle() / EIGHTH_TURN) * EIGHTH_TURN
	var nova := Vector2.from_angle(ang)
	if not nova.is_equal_approx(facing_direction):
		facing_direction = nova
		_sincronizar_facing()


## Gira o pivô de ataque e o blend da animação.
func _sincronizar_facing() -> void:
	if attack_pivot != null:
		attack_pivot.rotation = facing_direction.angle()
	if _blend_params.is_empty():
		return
	var blend := _direcao_para_blend(facing_direction)
	for param in _blend_params:
		anim_tree.set(param, blend)


## Converte a direção para o blend (4 ou 8 lados).
func _direcao_para_blend(dir: Vector2) -> Vector2:
	if not sprites_4_direcoes:
		return dir
	if absf(dir.x) + 0.01 >= absf(dir.y):
		return Vector2(signf(dir.x), 0.0)
	return Vector2(0.0, signf(dir.y))


## Toca a animação do estado se ela existir.
func _tocar_anim(nome: StringName) -> void:
	if playback == null or _anim_sm == null or not _anim_sm.has_node(nome):
		return
	if playback.get_current_node() == nome:
		playback.start(nome)
	else:
		playback.travel(nome)


## Golpe encostou em um corpo.
func _on_melee_hitbox_body_entered(body: Node2D) -> void:
	_acertar_alvo(body)


## Golpe encostou em uma área.
func _on_melee_hitbox_area_entered(area: Area2D) -> void:
	# Só Hurtboxes contam
	if area.is_in_group(CombatUtils.GROUP_HURTBOX):
		_acertar_alvo(area)


## Dano do golpe, uma vez por alvo por ataque.
func _acertar_alvo(alvo: Node) -> void:
	if state != State.ATTACK_MELEE or not CombatUtils.can_take_damage(alvo):
		return
	var raiz: Node = CombatUtils.get_actor(alvo) if alvo is Area2D else alvo
	if raiz == null:
		raiz = alvo
	if raiz == self or raiz in _alvos_atingidos:
		return
	if causar_dano(alvo, dano_base, raiz):
		_alvos_atingidos.append(raiz)


## Cria o projétil com dano proporcional à carga.
func _disparar_projetil() -> void:
	if projectile_scene == null:
		push_warning("Player: projectile_scene não foi definida no Inspector.")
		return

	var origem := projectile_spawn.global_position if projectile_spawn != null else global_position
	# Cena com raiz errada é descartada pelo spawn
	var projetil := CombatUtils.spawn(projectile_scene, self, origem, PlayerProjectile) as PlayerProjectile
	if projetil == null:
		push_warning("Player: projectile_scene precisa ter player_projectile.gd na raiz.")
		return

	var ratio := clampf(_carga / maxf(charge_time, 0.01), 0.0, 1.0)
	projetil.direction = facing_direction
	projetil.damage = roundi(lerpf(float(dano_base), float(max_damage), ratio))
	projetil.shooter = self


## true durante os i-frames.
func esta_invulneravel() -> bool:
	return _iframes_left > 0.0


## true depois da morte.
func esta_morto() -> bool:
	return _morto


## API de dano do projeto.
## Retorna false se recusou (morto ou em i-frames).
func take_damage(quantidade: int, _source: Variant = null) -> bool:
	return tomar_dano(quantidade)


## Aplica o dano no HP. false se recusou.
func tomar_dano(quantidade: int) -> bool:
	if _morto or quantidade <= 0 or esta_invulneravel():
		return false
	var aplicado := mini(quantidade, hp)
	hp -= aplicado
	hp_changed.emit(hp, hp_maximo)
	tomou_dano.emit(aplicado)
	if hp == 0:
		_morrer()
	return true


## Retorna o HP recuperado. Com HP cheio não emite nada.
func curar(quantidade: int) -> int:
	if _morto or quantidade <= 0 or hp >= hp_maximo:
		return 0
	var antes := hp
	hp = mini(hp + quantidade, hp_maximo)
	hp_changed.emit(hp, hp_maximo)
	return hp - antes


## Dano do player em um alvo. true se o alvo aceitou.
func causar_dano(alvo: Node, quantidade: int, notificar: Node = null) -> bool:
	if not CombatUtils.apply_damage(alvo, quantidade, self):
		return false
	causou_dano.emit(notificar if notificar != null else alvo, quantidade)
	return true


## Para o player e desliga a hurtbox.
func _morrer() -> void:
	_exit_state(state)
	_morto = true
	velocity = Vector2.ZERO
	_set_melee_hitbox(false)
	if hurtbox != null:
		hurtbox.set_active(false)
	set_physics_process(false)
	morreu.emit()
