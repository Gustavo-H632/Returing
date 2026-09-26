## player
class_name Player
extends CharacterBody2D

#states
enum State { IDLE, MOVE, DASH, ATTACK_MELEE, ATTACK_RANGED }

const ANIM_NAMES := {
	State.IDLE: "Idle",
	State.MOVE: "Walk",
	State.DASH: "Dash",
	State.ATTACK_MELEE: "AttackMelee",
	State.ATTACK_RANGED: "AttackRanged",
}

signal hp_changed(hp_atual: int, hp_maximo: int)
signal tomou_dano(quantidade: int)
signal causou_dano(alvo: Node, quantidade: int)
signal morreu
signal carga_mudou(percentual: float)         
signal estado_mudou(novo_estado: int)

@export_group("Status")
@export var hp_maximo: int = 100
@export var hp: int = 100
@export var speed: float = 110.0
@export var dano_base: int = 10

@export_group("Dash")
@export var dash_speed: float = 320.0
@export var dash_duration: float = 0.18        # tempo de deslocamento
@export var dash_cooldown: float = 0.6         # espera para dar outro dash
@export var iframes_duration: float = 0.25     # invulnerabilidade 

@export_group("Ataque Melee")
@export var melee_duration: float = 0.30      

@export_group("Ataque Ranged")
@export var projectile_scene: PackedScene
@export var max_damage: int = 40               # dano máximo com carga cheia
@export var charge_time: float = 1.2           # segundos para atingir a carga máxima
@export_range(0.0, 1.0) var charge_move_multiplier: float = 0.4  

@export_group("Animação")

@export var sprites_4_direcoes: bool = true


@onready var anim_tree: AnimationTree = $AnimationTree
@onready var attack_pivot: Marker2D = $AttackPivot
@onready var melee_hitbox: Area2D = $AttackPivot/MeleeHitbox
@onready var projectile_spawn: Marker2D = $AttackPivot/ProjectileSpawn
@onready var dash_timer: Timer = $Timers/DashTimer
@onready var dash_cooldown_timer: Timer = $Timers/DashCooldownTimer
@onready var iframes_timer: Timer = $Timers/IFramesTimer
@onready var melee_timer: Timer = $Timers/MeleeTimer


var playback: AnimationNodeStateMachinePlayback = null


var state: int = State.IDLE
var facing_direction: Vector2 = Vector2.DOWN   # última direção olhada 

var _input_dir: Vector2 = Vector2.ZERO
var _dash_dir: Vector2 = Vector2.ZERO
var _carga: float = 0.0                        
var _alvos_atingidos: Array[Node] = []     
var _morto: bool = false


func _ready() -> void:
	hp = clampi(hp, 0, hp_maximo)

	
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	_configurar_timers()
	_configurar_hitbox()
	_configurar_animation_tree()

	_sincronizar_facing()
	_enter_state(state)
	hp_changed.emit(hp, hp_maximo)


func _configurar_timers() -> void:
	for t in [dash_timer, dash_cooldown_timer, iframes_timer, melee_timer]:
		t.stop()        
		t.one_shot = true
	dash_timer.timeout.connect(_on_dash_timer_timeout)
	melee_timer.timeout.connect(_on_melee_timer_timeout)


func _configurar_hitbox() -> void:
	melee_hitbox.monitoring = false   
	melee_hitbox.body_entered.connect(_on_melee_hitbox_body_entered)
	melee_hitbox.area_entered.connect(_on_melee_hitbox_area_entered)


func _configurar_animation_tree() -> void:
	anim_tree.process_callback = AnimationTree.ANIMATION_PROCESS_PHYSICS
	anim_tree.active = true
	playback = anim_tree.get("parameters/playback")
	if playback == null:
		push_error("Player: o Tree Root do AnimationTree precisa ser um " +
			"AnimationNodeStateMachine com os estados Idle/Walk/Dash/AttackMelee/" +
			"AttackRanged (veja o tutorial de configuração da GUI).")



func _physics_process(delta: float) -> void:
	_input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	match state:
		State.IDLE:          _state_idle()
		State.MOVE:          _state_move()
		State.DASH:          _state_dash()
		State.ATTACK_MELEE:  _state_attack_melee()
		State.ATTACK_RANGED: _state_attack_ranged(delta)

	move_and_slide()   
func _state_idle() -> void:
	_atualizar_facing()
	velocity = _input_dir * speed
	if _tentar_acoes():
		return
	if _input_dir != Vector2.ZERO:
		change_state(State.MOVE)


func _state_move() -> void:
	_atualizar_facing()
	velocity = _input_dir * speed
	if _tentar_acoes():
		return
	if _input_dir == Vector2.ZERO:
		change_state(State.IDLE)


func _state_dash() -> void:
	velocity = _dash_dir * dash_speed


func _state_attack_melee() -> void:
	velocity = Vector2.ZERO


func _state_attack_ranged(delta: float) -> void:
	_atualizar_facing()   
	velocity = _input_dir * speed * charge_move_multiplier

	
	var carga_anterior := _carga
	_carga = minf(_carga + delta, charge_time)
	if _carga != carga_anterior:
		carga_mudou.emit(_carga / maxf(charge_time, 0.01))

	
	if Input.is_action_just_pressed("dash") and _pode_dashar():
		change_state(State.DASH)
		return

	
	if not Input.is_action_pressed("charge_shoot"):
		_disparar_projetil()
		change_state(State.IDLE)


func _tentar_acoes() -> bool:
	if Input.is_action_just_pressed("dash") and _pode_dashar():
		change_state(State.DASH)
		return true
	if Input.is_action_just_pressed("attack_sword"):
		change_state(State.ATTACK_MELEE)
		return true
	if Input.is_action_just_pressed("charge_shoot"):
		change_state(State.ATTACK_RANGED)
		return true
	return false


func _pode_dashar() -> bool:
	return dash_cooldown_timer.is_stopped()


func change_state(novo_estado: int) -> void:
	if _morto or novo_estado == state:
		return
	_exit_state(state)
	state = novo_estado
	_enter_state(novo_estado)
	estado_mudou.emit(novo_estado)


func _enter_state(s: int) -> void:
	match s:
		State.DASH:
			# Direção do dash com a última direção olhada.
			_dash_dir = (_input_dir if _input_dir != Vector2.ZERO else facing_direction).normalized()
			velocity = _dash_dir * dash_speed
			dash_timer.start(dash_duration)
			iframes_timer.start(iframes_duration)  
		State.ATTACK_MELEE:
			velocity = Vector2.ZERO
			_alvos_atingidos.clear()
			melee_hitbox.set_deferred("monitoring", true)   # liga a hitbox
			melee_timer.start(melee_duration)
		State.ATTACK_RANGED:
			_carga = 0.0
	_tocar_anim(ANIM_NAMES[s])


func _exit_state(s: int) -> void:
	match s:
		State.DASH:
			dash_timer.stop()
			dash_cooldown_timer.start(dash_cooldown)
		State.ATTACK_MELEE:
			melee_timer.stop()
			melee_hitbox.set_deferred("monitoring", false)  # desliga a hitbox
		State.ATTACK_RANGED:
			_carga = 0.0
			carga_mudou.emit(0.0)


func _on_dash_timer_timeout() -> void:
	if state == State.DASH:
		change_state(State.IDLE)


func _on_melee_timer_timeout() -> void:
	if state == State.ATTACK_MELEE:
		change_state(State.IDLE)


func _atualizar_facing() -> void:
	if _input_dir == Vector2.ZERO:
		return  # mantém a última direção
	
	var ang := roundf(_input_dir.angle() / (PI / 4.0)) * (PI / 4.0)
	var nova := Vector2.from_angle(ang)
	if nova != facing_direction:
		facing_direction = nova
		_sincronizar_facing()


func _sincronizar_facing() -> void:
	
	attack_pivot.rotation = facing_direction.angle()

	
	var blend := _direcao_para_blend(facing_direction)
	for nome in ANIM_NAMES.values():
		anim_tree.set("parameters/%s/blend_position" % nome, blend)


func _direcao_para_blend(dir: Vector2) -> Vector2:
	if not sprites_4_direcoes:
		return dir

	if absf(dir.x) + 0.01 >= absf(dir.y):
		return Vector2(signf(dir.x), 0.0)
	return Vector2(0.0, signf(dir.y))


func _tocar_anim(nome: StringName) -> void:
	if playback == null:
		return  
	if playback.get_current_node() == nome:
		playback.start(nome)   
	else:
		playback.travel(nome)    


# Atque meelee
func _on_melee_hitbox_body_entered(body: Node2D) -> void:
	_acertar_alvo(body)


func _on_melee_hitbox_area_entered(area: Area2D) -> void:
	_acertar_alvo(area)   # área pode ser a Hurtbox  de um inimigo


func _acertar_alvo(alvo: Node) -> void:
	var raiz: Node = alvo
	if alvo is Area2D and alvo.get_parent() != null:
		raiz = alvo.get_parent()
	if raiz == self or raiz in _alvos_atingidos:
		return
	_alvos_atingidos.append(raiz)
	causar_dano(alvo, dano_base, raiz)

#ataque projetil
func _disparar_projetil() -> void:
	if projectile_scene == null:
		push_warning("Player: projectile_scene não foi definida no Inspector.")
		return

	var proj: PlayerProjectile = projectile_scene.instantiate() as PlayerProjectile
	if proj == null:
		push_warning("Player: projectile_scene precisa ter player_projectile.gd na raiz.")
		return

	# Dano cresce linearmente 
	var ratio := _carga / maxf(charge_time, 0.01)
	var dano_final := roundi(lerpf(float(dano_base), float(max_damage), ratio))

	proj.direction = facing_direction
	proj.damage = dano_final
	proj.shooter = self

	var pai := get_tree().current_scene if get_tree().current_scene else get_tree().root
	pai.add_child(proj)

	proj.global_position = projectile_spawn.global_position


# Tomar dano
func esta_invulneravel() -> bool:
	return not iframes_timer.is_stopped()


func take_damage(quantidade: int, _source = null) -> void:
	tomar_dano(quantidade)


## Chamado por inimigos
func tomar_dano(quantidade: int) -> void:
	if _morto or quantidade <= 0 or esta_invulneravel():
		return
	hp = maxi(hp - quantidade, 0)
	hp_changed.emit(hp, hp_maximo)
	tomou_dano.emit(quantidade)
	if hp == 0:
		_morrer()


## O player aplicando dano em alvo
func causar_dano(alvo: Node, quantidade: int, notificar: Node = null) -> void:
	if not is_instance_valid(alvo):
		return
	if alvo.has_method("tomar_dano"):
		alvo.tomar_dano(quantidade)
	elif alvo.has_method("take_damage"):
		alvo.take_damage(quantidade, self)
	else:
		return
	causou_dano.emit(notificar if notificar != null else alvo, quantidade)


func _morrer() -> void:
	_morto = true
	velocity = Vector2.ZERO
	melee_hitbox.set_deferred("monitoring", false)
	set_physics_process(false)
	morreu.emit()
