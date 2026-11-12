class_name Player
extends CharacterBody2D
## Alan Turing (jogador): movimento em 8 direções, dash, espada e tiro carregado.

# Avisa a vida atual e a máxima sempre que a vida muda (a HUD escuta pelo EventBus).
signal hp_changed(hp_atual: int, hp_maximo: int)
# Avisa quanto dano o jogador realmente tomou, já descontados escudo e invulnerabilidade.
signal tomou_dano(quantidade: int)
# Avisa que o jogador acertou um alvo e quanto de dano causou (espada ou tiro).
signal causou_dano(alvo: Node, quantidade: int)
signal morreu  # Avisa que o jogador morreu (quem escuta decide o game over).
# Avisa o quanto o tiro está carregado, de 0.0 a 1.0 (a barra de carga escuta).
signal carga_mudou(percentual: float)
signal estado_mudou(novo_estado: int)  # Avisa a troca de estado do jogador (o valor é o enum State).

# Todos os estados possíveis do jogador; só um fica ativo por vez.
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
	State.ATTACK_RANGED: "shoot",
	State.DEAD: "death",
}

# Nomes das ações do Input Map que o jogador consulta (teclado, mouse ou toque).
const ACTION_LEFT: StringName = &"move_left"
const ACTION_RIGHT: StringName = &"move_right"
const ACTION_UP: StringName = &"move_up"
const ACTION_DOWN: StringName = &"move_down"
const ACTION_DASH: StringName = &"dash"
const ACTION_MELEE: StringName = &"attack_sword"
const ACTION_SHOOT: StringName = &"charge_shoot"

# Um oitavo de volta (45°): o movimento é arredondado para 8 direções.
const EIGHTH_TURN: float = PI / 4.0
## Índice numérico de cada sufixo de direção (chave do cache de animações).
const _SUFFIX_INDEX: Dictionary[String, int] = {"side": 0, "down": 1, "up": 2}
## Multiplicador do estado na chave do cache: estado * passo + índice do sufixo.
const _ANIM_KEY_STRIDE: int = 3
## Tiros criados com antecedência no pool (evita nascer nós no meio da luta).
const PROJECTILE_PREWARM: int = 6
## Folga somada à duração da espada antes de forçar a saída do ATTACK_MELEE.
const MELEE_SAFETY_MARGIN: float = 0.25

@export_group("Status")
@export var hp_maximo: int = 1000  # Vida máxima base do jogador.
@export var hp: int = 1000  # Vida atual (começa cheia).

@export_group("Regeneração")
## Segundos seguidos sem receber dano para a regeneração começar.
@export_range(0.0, 60.0, 0.5, "or_greater") var regen_delay: float = 10.0
## Vida recuperada por segundo depois do atraso.
@export_range(0.0, 20.0, 0.1, "or_greater") var regen_per_second: float = 1.0

@export_group("Status")
@export var speed: float = 300.0  # Velocidade de caminhada em pixels por segundo.
# Dano do tiro sem carga nenhuma (o tiro carregado cresce a partir daqui).
@export var dano_base: int = 10

@export_group("Dash")
@export var dash_speed: float = 400.0  # Velocidade do dash em pixels por segundo.
@export var dash_duration: float = 0.18  # Quanto tempo o dash dura.
@export var dash_cooldown: float = 0.6  # Espera entre um dash e o próximo.
@export var iframes_duration: float = 0.25  # Tempo de invulnerabilidade dado pelo dash.
## Regra de direção do dash (movimento/mouse).
@export var dash_aim: DashAim = DashAim.MOVIMENTO_OU_MOUSE
## Nuvem de poeira criada no início do dash (opcional).
@export var dash_dust_scene: PackedScene

@export_group("Ataque Ranged")
@export var projectile_scene: PackedScene  # Cena do tiro (precisa ter player_projectile.gd na raiz).
## Dano do tiro com carga máxima (antes 40; +70% = 68).
@export var max_damage: int = 68
@export var charge_time: float = 1.2  # Tempo (s) para carregar o tiro por completo.
# Fração da velocidade mantida enquanto carrega o tiro (0.4 = 40%).
@export_range(0.0, 1.0) var charge_move_multiplier: float = 0.4

@export_group("Espada")
## Dano de cada golpe da espada (antes 25; o dobro = 50).
@export var sword_damage: int = 50

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
@export var sprite: Sprite2D  # Sprite do personagem.
@export var animation_player: AnimationPlayer  # Tocador das animações.
# Ponto que gira para a direção do ataque (a espada e o tiro nascem dele).
@export var attack_pivot: Marker2D
@export var weapon: Weapon  # Arma equipada (espada).
@export var projectile_spawn: Marker2D  # Marcador de onde o tiro nasce.
@export var hurtbox: Hurtbox  # Área que recebe dano do jogador.

var state: State = State.IDLE  # Estado atual da máquina de estados do jogador.
var facing_direction: Vector2 = Vector2.DOWN  # Direção para onde o personagem olha.
## Direção da mira.
var aim_direction: Vector2 = Vector2.DOWN

var _input_dir: Vector2 = Vector2.ZERO  # Direção pedida pelo teclado/analógico neste quadro.
## Último vetor de movimento não nulo.
var _last_move_dir: Vector2 = Vector2.DOWN
var _dash_dir: Vector2 = Vector2.DOWN  # Direção travada do dash em andamento.
var _carga: float = 0.0  # Tempo de carga acumulado do tiro.
## Regeneração: tempo seguido sem dano e fração de HP acumulada.
var _tempo_sem_dano: float = 0.0
var _regen_acumulado: float = 0.0  # Fração de vida regenerada que ainda não virou 1 ponto inteiro.
var _morto: bool = false  # True depois que o jogador morre (nenhuma ação é aceita).
## Habilidades (componente filho; null se a cena não o tiver).
@onready var abilities: AbilityComponent = get_node_or_null(^"AbilityComponent") as AbilityComponent
## Vida máxima sem bônus de habilidades.
var _hp_maximo_base: int = 100

var _flash_tween: Tween = null  # Tween do pisca de dano (guardado para cancelar se for preciso).

var _dash_left: float = 0.0  # Tempo restante do dash atual.
var _dash_cooldown_left: float = 0.0  # Tempo restante até poder dar outro dash.
var _iframes_left: float = 0.0  # Tempo restante de invulnerabilidade.
var _melee_safety_left: float = 0.0  # Tempo restante da rede de segurança do golpe.
var _current_anim: StringName = &""  # Nome da animação que está tocando.
# Posição X original do sprite (necessária para espelhar sem deslocar).
var _sprite_offset_x: float = 0.0
## Cache "estado + direção" -> nome da animação.
var _anim_cache: Dictionary[int, StringName] = {}
## True durante exit/enter.
var _transitioning: bool = false


## Entra na árvore e coloca o jogador no grupo "player", para inimigos e HUD o encontrarem.
func _enter_tree() -> void:
	add_to_group(CombatUtils.GROUP_PLAYER)


## Prepara o jogador: aplica a escala da plataforma, valida referências, equipa a arma,
## liga o EventBus, cria mira e câmera e avisa o resto do jogo que o jogador existe.
func _ready() -> void:
	scale *= Platform.sprite_scale  # celular: sprites maiores (corpo, hurtbox e espada crescem juntos)
	hp_maximo = maxi(hp_maximo, 1)  # Garante pelo menos 1 de vida máxima para não dividir por zero.
	_hp_maximo_base = hp_maximo  # Guarda a vida máxima original para os bônus de habilidade.
	hp = clampi(hp, 0, hp_maximo)  # Mantém a vida dentro do intervalo válido.
	# Movimento flutuante: sem chão nem gravidade (jogo visto de cima).
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	if sprite != null:
		_sprite_offset_x = sprite.offset.x  # Guarda o deslocamento original do sprite.

	_validar_referencias()  # Avisa no console se algo essencial não foi ligado na cena.
	_configurar_arma()  # Equipa a espada e liga os sinais dela.
	_conectar_event_bus()  # Liga os sinais do jogador ao EventBus.

	_sincronizar_facing()  # Alinha o pivô de ataque com a direção inicial.
	_enter_state(state)  # Entra no estado inicial (toca a animação certa).
	_criar_indicador_de_mira()  # Cria a barra translúcida de mira.
	add_child(RunRecorder.new())  # Adiciona o gravador de estatísticas da run (pontuação).
	_configurar_camera()  # Liga a câmera de seguimento (só no celular).
	EventBus.player_registered.emit(self)  # Avisa quem escuta (inimigos, HUD) que o jogador está pronto.
	_emitir_estado_para_ui()  # Manda vida e carga atuais para a HUD já na primeira imagem.


## Confere se as referências ligadas no Inspector existem e se o corpo está na camada certa.
## Só emite avisos no console; não impede o jogo de rodar.
func _validar_referencias() -> void:
	var faltando: PackedStringArray = []  # Lista dos nomes que faltam.
	if sprite == null: faltando.append("sprite")
	if animation_player == null: faltando.append("animation_player")
	if attack_pivot == null: faltando.append("attack_pivot")
	if weapon == null: faltando.append("weapon")
	if hurtbox == null: faltando.append("hurtbox")
	if not faltando.is_empty():
		push_warning("Player: referências não atribuídas: %s" % ", ".join(faltando))
	# Sem a camada Player, os inimigos nunca detectam o jogador.
	if not get_collision_layer_value(CombatUtils.LAYER_PLAYER):
		push_warning("Player: o corpo não está na camada 2 (Player); inimigos não vão detectá-lo.")


## Equipa a arma e liga os sinais dela.
func _configurar_arma() -> void:
	# Cria os tiros antes da luta para não instanciar nós no meio do combate.
	PoolHub.prewarm(projectile_scene, self, PROJECTILE_PREWARM)
	if weapon == null:
		return
	weapon.damage = sword_damage  # A espada herda o dano configurado no jogador.
	weapon.equip(self)  # Entrega a espada ao jogador (dono do golpe).
	# Quando o golpe termina, o jogador volta ao estado parado.
	CombatUtils.connect_once(weapon.attack_finished, _on_weapon_attack_finished)
	# Quando a espada acerta, o jogador repassa o dano causado.
	CombatUtils.connect_once(weapon.hit_landed, _on_weapon_hit_landed)


## Espelha os sinais do Player no EventBus (HUD e fase não conhecem o Player).
func _conectar_event_bus() -> void:
	# Vida mudou: repassa a HUD.
	hp_changed.connect(func(atual: int, maximo: int) -> void: EventBus.player_hp_changed.emit(atual, maximo))
	# Dano tomado: repassa ao EventBus.
	tomou_dano.connect(func(quantidade: int) -> void: EventBus.player_damaged.emit(quantidade))
	# Dano causado: repassa ao EventBus.
	causou_dano.connect(func(alvo: Node, quantidade: int) -> void: EventBus.player_dealt_damage.emit(alvo, quantidade))
	# Carga mudou: repassa a barra de carga.
	carga_mudou.connect(func(percentual: float) -> void: EventBus.player_charge_changed.emit(percentual))
	morreu.connect(func() -> void: EventBus.player_died.emit())  # Morte: repassa o game over.
	# A HUD pode pedir para o jogador reenviar vida e carga.
	EventBus.hud_refresh_requested.connect(_emitir_estado_para_ui)
	EventBus.player_heal_requested.connect(curar)  # Pedidos de cura de outros sistemas chegam por aqui.
	# Pedidos de dano (ex.: erro no quiz) chegam por aqui.
	EventBus.player_damage_requested.connect(_on_dano_solicitado)


## Ao sair da árvore desliga as conexões com o EventBus para não deixar sinais pendurados.
func _exit_tree() -> void:
	CombatUtils.disconnect_if_connected(EventBus.hud_refresh_requested, _emitir_estado_para_ui)
	CombatUtils.disconnect_if_connected(EventBus.player_heal_requested, curar)
	CombatUtils.disconnect_if_connected(EventBus.player_damage_requested, _on_dano_solicitado)


## Reenvia vida e carga atuais para a HUD (usado ao nascer e quando a HUD pede).
func _emitir_estado_para_ui() -> void:
	hp_changed.emit(hp, hp_maximo)
	# A carga só conta se está no estado de tiro.
	carga_mudou.emit(0.0 if state != State.ATTACK_RANGED else _carga / maxf(charge_time, 0.01))


## Loop de física: lê a entrada, atualiza a mira, roda o estado atual e move o corpo.
func _physics_process(delta: float) -> void:
	# Cronômetros primeiro, para as decisões do quadro já usarem os valores novos.
	_atualizar_cronometros(delta)
	# Direção do teclado/analógico (já normalizada em círculo).
	_input_dir = Input.get_vector(ACTION_LEFT, ACTION_RIGHT, ACTION_UP, ACTION_DOWN)
	if _input_dir != Vector2.ZERO:  # Guarda a última direção diferente de zero.
		_last_move_dir = _input_dir.normalized()
	_atualizar_mira()  # Atualiza a mira antes de qualquer ataque.

	match state:  # Cada estado tem sua própria regra de movimento.
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

	move_and_slide()  # Aplica a velocidade calculada e resolve colisões.
	_atualizar_animacao()  # Escolhe a animação do quadro.


## Desconta o tempo de todos os cronômetros do jogador (regeneração, dash, i-frames e golpe).
func _atualizar_cronometros(delta: float) -> void:
	_atualizar_regeneracao(delta)
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	_iframes_left = maxf(_iframes_left - delta, 0.0)
	_dash_left = maxf(_dash_left - delta, 0.0)
	_melee_safety_left = maxf(_melee_safety_left - delta, 0.0)


# --- Estados ---

## Estado parado/andando: define a velocidade, tenta dash ou ataque e alterna idle/walk.
func _state_locomocao() -> void:
	_atualizar_facing()  # Vira o personagem para onde ele anda.
	# Velocidade base vezes o bônus de habilidades (Passo Ágil, Ninja Furtivo).
	velocity = _input_dir * speed * _stat_mult(StatModifiers.MOVE_SPEED)
	if _tentar_acoes():  # Se começou uma ação (dash, golpe ou tiro) não troca entre idle e andar.
		return
	var movendo: bool = _input_dir != Vector2.ZERO  # True quando há entrada de movimento.
	if movendo and state == State.IDLE:
		change_state(State.MOVE)
	elif not movendo and state == State.MOVE:
		change_state(State.IDLE)


## Estado de dash: mantém a velocidade fixa na direção travada até o tempo acabar.
func _state_dash() -> void:
	velocity = _dash_dir * dash_speed  # O dash não é controlável: velocidade constante.
	if _dash_left <= 0.0:  # Acabou o tempo: volta ao parado.
		change_state(State.IDLE)


## Parado durante o golpe.
func _state_attack_melee() -> void:
	velocity = Vector2.ZERO
	# A espada acompanha o cursor durante o golpe (o personagem não troca de direção no meio
	# do golpe, o que reiniciaria a animação de ataque).
	if weapon != null:  # Aponta a espada para a mira atual.
		weapon.aim_at(aim_direction)
	if _melee_safety_left <= 0.0:  # Rede de segurança: se a espada travar, o estado termina sozinho.
		change_state(State.IDLE)  # rede de segurança: nunca trava no ataque


## Estado de tiro carregado: carrega, anda devagar, permite dash e dispara ao soltar o botão.
func _state_attack_ranged(delta: float) -> void:
	_apontar_para_mouse()  # durante a carga o personagem encara o cursor, não o movimento
	# Anda mais devagar enquanto carrega.
	velocity = _input_dir * speed * charge_move_multiplier * _stat_mult(StatModifiers.MOVE_SPEED)

	var tempo_total: float = maxf(charge_time, 0.01)  # Evita divisão por zero se o tempo de carga for 0.
	if _carga < tempo_total:
		_carga = minf(_carga + delta, tempo_total)  # Acumula a carga sem passar do máximo.
		carga_mudou.emit(_carga / tempo_total)  # Avisa a barra de carga.

	if Input.is_action_just_pressed(ACTION_DASH) and _pode_dashar():  # Dash cancela a carga (sem disparar).
		change_state(State.DASH)
		return
	if not Input.is_action_pressed(ACTION_SHOOT):  # Soltou o botão: dispara o tiro com a carga acumulada.
		_disparar_projetil()
		change_state(State.IDLE)


## Verifica a ordem de prioridade das ações: dash, depois golpe, depois tiro.
## Devolve true se alguma ação começou neste quadro.
func _tentar_acoes() -> bool:
	if Input.is_action_just_pressed(ACTION_DASH) and _pode_dashar():  # Dash tem prioridade sobre tudo.
		change_state(State.DASH)
	elif UiFx.is_attack_input_blocked():  # O clique que acabou de fechar um menu não pode virar ataque.
		return false  # o clique que fechou um menu não vira golpe
	elif Input.is_action_just_pressed(ACTION_MELEE):  # Botão da espada.
		return atacar_com_arma()
	elif Input.is_action_just_pressed(ACTION_SHOOT):  # Botão do tiro.
		change_state(State.ATTACK_RANGED)
	else:
		return false
	return true


## Inicia o golpe da arma.
func atacar_com_arma() -> bool:
	# Não ataca morto, sem arma, já atacando ou com a arma em recarga.
	if _morto or weapon == null or state == State.ATTACK_MELEE or not weapon.can_attack():
		return false
	change_state(State.ATTACK_MELEE)
	return state == State.ATTACK_MELEE


## Diz se o dash já esfriou e pode ser usado.
func _pode_dashar() -> bool:
	return _dash_cooldown_left <= 0.0


## Troca o estado do jogador: sai do antigo, entra no novo e emite o sinal estado_mudou.
## Recusa a troca se o jogador está morto, no meio de outra troca ou se é o mesmo estado.
func change_state(novo_estado: State) -> void:
	if _morto or _transitioning or novo_estado == state:
		return  # Marca que há uma troca em andamento.
	_transitioning = true
	_exit_state(state)  # Roda a saída do estado antigo (limpa o que ele deixou).
	state = novo_estado  # Troca de fato.
	_enter_state(novo_estado)  # Roda a entrada do novo estado.
	_transitioning = false
	estado_mudou.emit(novo_estado)


## Executa o que precisa acontecer ao entrar em cada estado (dash, golpe ou carga).
func _enter_state(s: State) -> void:
	match s:
		State.DASH:
			_dash_dir = _escolher_direcao_dash()  # Escolhe a direção do dash (movimento ou cursor).
			# Sprite e animação do dash passam a olhar para a direção real do dash.
			facing_direction = _dash_dir  # O sprite passa a olhar para onde o dash vai.
			_sincronizar_facing()
			velocity = _dash_dir * dash_speed
			# O bônus de Ninja Furtivo estica a duração do dash.
			_dash_left = dash_duration * _stat_mult(StatModifiers.DASH_DISTANCE)
			_iframes_left = maxf(_iframes_left, iframes_duration)  # Dash dá invulnerabilidade curta.
			_spawn_dash_dust()  # Poeira nos pés.
		State.ATTACK_MELEE:
			_iniciar_golpe()
		State.ATTACK_RANGED:
			_carga = 0.0
			carga_mudou.emit(0.0)
			_apontar_para_mouse()
	_atualizar_animacao(true)  # Toca a animação do novo estado do começo.


## Cria a poeira do dash nos pés do jogador; ela fica no mundo e se remove sozinha.
func _spawn_dash_dust() -> void:
	if dash_dust_scene == null:
		return
	var dust := dash_dust_scene.instantiate() as DashDust
	if dust == null:
		push_warning("Player: dash_dust_scene precisa ter dash_dust.gd na raiz.")
		return
	add_child(dust)
	var center: Vector2 = sprite.global_position if sprite != null else global_position
	dust.play(center, _dash_dir.x < -0.01)


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


## Executa o que precisa ser desfeito ao sair de cada estado (cooldown do dash, fim do golpe, zera a carga).
func _exit_state(s: State) -> void:
	match s:
		State.DASH:
			_dash_left = 0.0  # Dash terminou: zera o tempo e começa o cooldown.
			_dash_cooldown_left = dash_cooldown
		State.ATTACK_MELEE:
			_melee_safety_left = 0.0
			if weapon != null and weapon.is_attacking():  # Se a espada ainda está batendo, corta o golpe agora.
				weapon.cancel()  # saída forçada: fecha a hitbox imediatamente
		State.ATTACK_RANGED:
			_carga = 0.0
			carga_mudou.emit(0.0)


# --- Arma ---

## A espada avisa que o golpe acabou: o jogador volta ao estado parado.
func _on_weapon_attack_finished(_completed: bool) -> void:
	# Ignora o aviso gerado pelo próprio cancel() durante uma troca de estado.
	if state == State.ATTACK_MELEE and not _transitioning:
		change_state(State.IDLE)


## A espada acertou algo: o jogador repassa o aviso de dano causado.
func _on_weapon_hit_landed(target: Node, damage_dealt: int) -> void:
	causou_dano.emit(target, damage_dealt)


# --- Mira e dash pelo mouse ---

## Atualiza `aim_direction` com a posição atual do cursor.
func _atualizar_mira() -> void:
	# Mantém a direção antiga se o cursor está em cima do jogador.
	aim_direction = _direcao_para_mouse(global_position, aim_direction)


## Direção normalizada de `desde` até o cursor, em coordenadas de mundo.
func _direcao_para_mouse(desde: Vector2, fallback: Vector2) -> Vector2:
	# Celular: a direção vem do analógico de mira (e persiste depois de soltar o dedo).
	if MobileControls.ativo:  # No celular a direção vem do analógico direito.
		return MobileControls.direcao_mira(desde, fallback)
	# Vetor do jogador até o cursor, em coordenadas do mundo.
	var para_cursor: Vector2 = get_global_mouse_position() - desde
	if para_cursor.length() < aim_deadzone:
		return fallback  # Cursor muito perto: mantém a mira anterior.
	return para_cursor.normalized()


## Vira o personagem (sprite e AttackPivot, onde nasce o projétil) para o cursor.
func _apontar_para_mouse() -> void:
	if not facing_direction.is_equal_approx(aim_direction):
		facing_direction = aim_direction
		_sincronizar_facing()


## Direção do dash, conforme `dash_aim`: 1.
func _escolher_direcao_dash() -> Vector2:
	var dir: Vector2
	# Andando: o dash sai na direção do movimento.
	if dash_aim == DashAim.MOVIMENTO_OU_MOUSE and _input_dir != Vector2.ZERO:
		dir = _input_dir
	else:
		dir = _direcao_para_mouse(global_position, _last_move_dir)  # Parado: o dash sai na direção do cursor.
	return dir.normalized() if dir != Vector2.ZERO else Vector2.DOWN


# --- Direção e animação ---

## Vira o personagem para o lado do movimento, arredondado para 8 direções.
func _atualizar_facing() -> void:
	if _input_dir == Vector2.ZERO:  # Sem entrada não muda a direção.
		return
	# Arredonda o ângulo para o múltiplo de 45° mais próximo.
	var ang: float = roundf(_input_dir.angle() / EIGHTH_TURN) * EIGHTH_TURN
	var nova: Vector2 = Vector2.from_angle(ang)  # Vetor unitário da direção arredondada.
	if not nova.is_equal_approx(facing_direction):  # Só atualiza se a direção realmente mudou.
		facing_direction = nova
		_sincronizar_facing()


## Gira o pivô de ataque para a direção em que o personagem olha.
func _sincronizar_facing() -> void:
	if attack_pivot != null:
		attack_pivot.rotation = facing_direction.angle()


## Sufixo de direção da animação (4 direções a partir das 8 de movimento).
func _direction_suffix() -> String:
	# Mais horizontal que vertical: usa a animação lateral.
	if absf(facing_direction.x) + 0.01 >= absf(facing_direction.y):
		return "side"
	return "down" if facing_direction.y > 0.0 else "up"


## Escolhe e toca a animação do estado atual.
func _atualizar_animacao(force: bool = false) -> void:
	if animation_player == null:  # Sem tocador não há o que animar.
		return
	var suffix: String = _direction_suffix()  # Sufixo "side", "down" ou "up".
	var anim_name: StringName = _animation_for(state, suffix)  # Nome da animação vindo do cache.
	if anim_name == &"":  # Estado sem animação: não faz nada.
		return
	# Quadros laterais (inclusive o tiro `shoot_side`, usado também para cima/baixo) olham para
	# o lado do cursor.
	if suffix == "side" or anim_name.ends_with("_side"):
		_aplicar_flip_lateral()
	# Já está tocando essa animação: não reinicia.
	if anim_name == _current_anim and not force and animation_player.is_playing():
		return
	_current_anim = anim_name
	animation_player.play(anim_name)  # Toca a animação.
	if force:  # Com `force`, volta ao primeiro quadro.
		animation_player.seek(0.0, true)


## Espelha o sprite nos quadros laterais, mantendo o conteúdo centralizado.
func _aplicar_flip_lateral() -> void:
	if sprite == null:
		return
	# True se a mira ou o movimento aponta para a esquerda.
	var looking_left: bool = facing_direction.x < 0.0
	CombatUtils.set_sprite_flip(sprite, looking_left if side_frames_face_right else not looking_left,
			_sprite_offset_x)


## Pega o nome da animação do estado e da direção.
func _animation_for(s: State, suffix: String) -> StringName:
	# Chave do cache: estado vezes o passo mais o índice do sufixo.
	var key: int = s * _ANIM_KEY_STRIDE + _SUFFIX_INDEX[suffix]
	if not _anim_cache.has(key):  # Primeira vez: resolve o nome e guarda.
		_anim_cache[key] = _resolve_animation(ANIM_PREFIX[s], suffix)
	return _anim_cache[key]


## "<prefixo>_<dir>" -> "<prefixo>_side" -> "<prefixo>" -> "idle_<dir>".
func _resolve_animation(prefix: String, suffix: String) -> StringName:
	# Tenta cada nome até achar um que exista.
	for candidate: String in ["%s_%s" % [prefix, suffix], "%s_side" % prefix, prefix, "idle_%s" % suffix]:
		if animation_player.has_animation(candidate):
			return StringName(candidate)
	return &""


# --- Tiro carregado ---

## Dispara o tiro carregado: pega um tiro do pool, calcula dano e tamanho pela carga e toca o som.
func _disparar_projetil() -> void:
	if projectile_scene == null:  # Cena do tiro não configurada: avisa e não atira.
		push_warning("Player: projectile_scene não foi definida.")
		return
	# Ponto de nascimento do tiro (boca da arma).
	var origem: Vector2 = projectile_spawn.global_position if projectile_spawn != null else global_position
	# Pega um tiro do pool (reaproveitado, não instanciado).
	var projetil := PoolHub.acquire(projectile_scene, self, PlayerProjectile) as PlayerProjectile
	if projetil == null:
		push_warning("Player: projectile_scene precisa ter player_projectile.gd na raiz (ou o pool de tiros esgotou).")
		return
	# Um toque rápido (celular) ainda dá um tiro de tamanho decente.
	# Garante um tamanho mínimo de tiro no celular (toque rápido).
	var ratio: float = clampf(maxf(_carga / maxf(charge_time, 0.01), Platform.min_shot_charge), 0.0, 1.0)
	# Mira a partir do ponto de nascimento (não do centro do jogador): o tiro
	# sai exatamente na linha que liga a boca do disparo ao cursor.
	# A carga define o dano e o tamanho do tiro.
	# Lança o tiro da boca do cano na direção da mira.
	projetil.launch(origem, _direcao_para_mouse(origem, aim_direction), _dano_por_carga(ratio), ratio, self,
			Platform.aim_assist)
	if not projetil.has_meta(&"speed_base"):  # Na primeira vez guarda a velocidade original do tiro.
		projetil.set_meta(&"speed_base", projetil.speed)  # velocidade original do tiro, guardada na 1ª vez
	# Aplica o bônus de velocidade (Tiro Rápido) sobre a velocidade original.
	projetil.speed = float(projetil.get_meta(&"speed_base")) * _stat_mult(StatModifiers.PROJECTILE_SPEED)
	# Quando o tiro acerta, o jogador repassa o dano.
	CombatUtils.connect_once(projetil.damage_dealt, _on_projectile_damage_dealt)
	$AttackSound.play()  # Som do disparo.


## Dano do tiro para uma carga de 0.0 a 1.0.
func _dano_por_carga(ratio: float) -> int:
	return roundi(lerpf(float(dano_base), float(max_damage), clampf(ratio, 0.0, 1.0)))


# --- Vida ---

## Diz se o jogador está invulnerável agora (dash ou habilidade).
func esta_invulneravel() -> bool:
	return _iframes_left > 0.0


## Diz se o jogador já morreu.
func esta_morto() -> bool:
	return _morto


## Invulnerabilidade extra (habilidades): nunca encurta a que já existe.
func conceder_invulnerabilidade(segundos: float) -> void:
	# Só aumenta, nunca encurta a invulnerabilidade existente.
	_iframes_left = maxf(_iframes_left, segundos)


## Encerra a invulnerabilidade (habilidade cancelada antes do fim).
func remover_invulnerabilidade() -> void:
	_iframes_left = 0.0


## Recalcula a vida máxima com os bônus de habilidade. Subir o teto também sobe a vida atual
## no mesmo valor; descer o teto limita a vida atual ao novo máximo.
func recalcular_hp_maximo() -> void:
	# Nova vida máxima: base vezes bônus, nunca menos que 1.
	var novo: int = maxi(roundi(float(_hp_maximo_base) * _stat_mult(StatModifiers.MAX_HEALTH)), 1)
	if novo == hp_maximo:  # Nada mudou: não faz nada.
		return
	if novo > hp_maximo and not _morto:  # Se o teto sobe, a vida atual sobe junto.
		hp += novo - hp_maximo
	hp_maximo = novo  # Atualiza o teto.
	hp = clampi(hp, 0, hp_maximo)  # A vida atual nunca passa do teto.
	hp_changed.emit(hp, hp_maximo)  # Avisa a HUD.


## Multiplicador de um atributo vindo das habilidades (1.0 sem componente).
func _stat_mult(stat: StringName) -> float:
	# Sem componente de habilidades o multiplicador é 1.0 (sem bônus).
	return abilities.stats.get_mult(stat) if abilities != null else 1.0


## API de dano do projeto (Hurtbox -> ator).
func take_damage(quantidade: int, _source: Variant = null) -> bool:
	return tomar_dano(quantidade)


## Pedido de dano vindo do EventBus (ex.: erro no quiz).
func _on_dano_solicitado(quantidade: int) -> void:
	tomar_dano(quantidade, true)


## `ignorar_iframes` = true aplica o dano mesmo com o player invulnerável (dash).
func tomar_dano(quantidade: int, ignorar_iframes: bool = false) -> bool:
	if _morto or quantidade <= 0:  # Morto ou dano inválido: ignora.
		return false
	# Invulnerável: ignora, a menos que o dano force (quiz).
	if esta_invulneravel() and not ignorar_iframes:
		return false
	var aplicado: int = mini(quantidade, hp)  # Nunca tira mais vida do que existe.
	hp -= aplicado  # Desconta a vida.
	_tempo_sem_dano = 0.0  # Regeneração: dano reinicia a contagem dos 10 s.
	_regen_acumulado = 0.0
	hp_changed.emit(hp, hp_maximo)  # Avisa a HUD.
	tomou_dano.emit(aplicado)  # Avisa quanto de dano foi aplicado.
	_piscar()  # Pisca em vermelho.
	if hp == 0:  # Zerou a vida: morre.
		_morrer()
	return true


## Pisca o sprite de vermelho por um instante.
func _piscar() -> void:
	if sprite == null or _morto:  # Sem sprite ou já morto não pisca.
		return
	# Segue rodando com o jogo pausado: o dano do quiz chega assim.
	_flash_tween = CombatUtils.flash_sprite(sprite, _flash_tween, hurt_flash_color, hurt_flash_time, true)


## Corta o pisca e devolve a cor normal.
func _apagar_pisca() -> void:
	CombatUtils.kill_flash(sprite, _flash_tween)


## Regenera vida depois de um tempo sem apanhar.
func _atualizar_regeneracao(delta: float) -> void:
	if _morto or hp >= hp_maximo:  # Cheio ou morto: não regenera.
		_regen_acumulado = 0.0
		return
	_tempo_sem_dano += delta  # Conta o tempo sem apanhar.
	if _tempo_sem_dano < regen_delay:  # Ainda no atraso inicial.
		return
	_regen_acumulado += regen_per_second * delta  # Acumula a vida regenerada (pode ser fração).
	if _regen_acumulado >= 1.0:
		var inteiro: int = int(_regen_acumulado)  # Quando junta 1 ponto inteiro, cura.
		_regen_acumulado -= float(inteiro)
		curar(inteiro)


## Recupera vida (aplicando o bônus de cura recebida) e devolve quanto realmente curou.
func curar(quantidade: int) -> int:
	if _morto or quantidade <= 0 or hp >= hp_maximo:  # Morto, sem cura ou com vida cheia: nada a fazer.
		return 0
	# Aplica o bônus de cura (mínimo 1).
	quantidade = maxi(roundi(float(quantidade) * _stat_mult(StatModifiers.HEAL_RECEIVED)), 1)
	var antes: int = hp  # Guarda a vida antes para calcular o ganho.
	hp = mini(hp + quantidade, hp_maximo)  # Não passa da vida máxima.
	hp_changed.emit(hp, hp_maximo)  # Avisa a HUD.
	return hp - antes


## O projétil avisa por sinal.
func _on_projectile_damage_dealt(alvo: Node, quantidade: int) -> void:
	causou_dano.emit(alvo, quantidade)


## Mata o jogador: sai do estado atual, trava ações, desliga a hurtbox e emite morreu.
func _morrer() -> void:
	_transitioning = true  # Impede novas trocas de estado.
	_exit_state(state)
	state = State.DEAD
	_morto = true
	velocity = Vector2.ZERO  # Para o corpo.
	if weapon != null:
		weapon.cancel()  # Cancela o golpe em andamento.
	if hurtbox != null:
		hurtbox.set_active(false)  # Desliga a área de dano.
	_apagar_pisca()
	_transitioning = false
	_atualizar_animacao(true)  # Toca a animação de morte.
	set_physics_process(false)  # Desliga a física do jogador.
	estado_mudou.emit(State.DEAD)
	morreu.emit()


# --- Mira visual, câmera e consultas para a UI ---

## Barra de mira (retângulo translúcido na direção do tiro).
func _criar_indicador_de_mira() -> void:
	var indicador := AimIndicator.new()  # Cria a mira por código, sem precisar de nó na cena.
	indicador.name = "AimIndicator"
	indicador.player = self
	add_child(indicador)


## Câmera que segue o player com zoom (só no celular; no PC fica como a cena já define).
func _configurar_camera() -> void:
	if Platform.is_mobile():  # Câmera de seguimento só no celular (no PC a cena já tem a sua).
		FollowCamera.attach_to(self, Platform.camera_zoom)


## Boca do cano (onde o tiro nasce).
func get_muzzle_position() -> Vector2:
	return projectile_spawn.global_position if projectile_spawn != null else global_position


## Carga atual do tiro de 0.0 a 1.0 (0 fora do ATTACK_RANGED).
func get_charge_ratio() -> float:
	if state != State.ATTACK_RANGED:
		return 0.0
	return clampf(_carga / maxf(charge_time, 0.01), 0.0, 1.0)


## True enquanto a barra de mira deve aparecer (carregando o tiro).
func is_aiming_shot() -> bool:
	return not _morto and state == State.ATTACK_RANGED


## True enquanto a mira da espada deve aparecer: durante o golpe (PC e celular) e, no celular,
## enquanto o dedo está no analógico de mira com a espada equipada.
func is_aiming_sword() -> bool:
	if _morto or not weapon is Sword:
		return false
	if state == State.ATTACK_MELEE and (weapon as Sword).is_swinging():
		return true
	return MobileControls.ativo and MobileControls.is_aiming() and not MobileControls.weapon_ranged 			and (state == State.IDLE or state == State.MOVE)


## Direção do golpe da espada.
func get_sword_direction() -> Vector2:
	return _direcao_para_mouse(global_position, aim_direction)


## Direção em que o tiro sairia agora, a partir da boca do cano.
func get_shot_direction() -> Vector2:
	return _direcao_para_mouse(get_muzzle_position(), aim_direction)


## Alcance do tiro (px): velocidade x tempo de vida do projétil.
func get_shot_range() -> float:
	var speed_value: float = float(CombatUtils.get_scene_root_property(projectile_scene, &"speed", 300.0))
	var life_value: float = float(CombatUtils.get_scene_root_property(projectile_scene, &"lifetime", 2.0))
	return speed_value * life_value
