extends CanvasLayer
## Autoload MobileControls: controles de toque (Android/iPhone). Só ficam ativos no celular, ou no PC
## com o argumento de usuário `--mobile` (o mouse simula o toque).
##
## Layout (igual ao do APK anterior):
##   esquerda  -> analógico de movimento (flutuante: nasce onde o dedo toca)
##   direita   -> analógico de mira/ataque (fixo)
##   botões    -> trocar arma, dash, interagir (E) e pausa
##
## Ataque (igual para tiro e espada): segure o analógico da direita para mirar (aparece a mira no
## chão) e solte para atacar na direção apontada. Com o tiro, segurar também carrega.
## Um toque rápido mira sozinho no inimigo mais próximo.

# --- Constantes ---
# Nome do argumento de linha de comando que liga o modo celular no PC.
const SIM_ARG: String = "--mobile"
# Cena do tutorial, que ganha uma versão de toque.
const TUTORIAL_SCENE: String = "res://Scenes/Tutorial/tutorial.tscn"

# Nomes das ações do Input Map que os toques viram (o Player lê essas mesmas ações).
const ACT_LEFT: StringName = &"move_left"
const ACT_RIGHT: StringName = &"move_right"
const ACT_UP: StringName = &"move_up"
const ACT_DOWN: StringName = &"move_down"
const ACT_DASH: StringName = &"dash"
const ACT_MELEE: StringName = &"attack_sword"
const ACT_SHOOT: StringName = &"charge_shoot"
const ACT_INTERACT: StringName = &"interagir"
const ACT_PAUSE: StringName = &"Pause"

# Papéis (funções) dos dedos e botões na tela.
const ROLE_WEAPON: StringName = &"weapon"
const ROLE_DASH: StringName = &"dash"
const ROLE_PAUSE: StringName = &"pause"
const ROLE_INTERACT: StringName = &"interact"
const ROLE_MOVE: StringName = &"move"
const ROLE_AIM: StringName = &"aim"

# Cores dos controles: cinza translúcido para não esconder o jogo.
const FILL: Color = Color(0.62, 0.62, 0.62, 0.5)
const FILL_PRESSED: Color = Color(0.62, 0.62, 0.62, 0.72)
const RING: Color = Color(0.85, 0.85, 0.85, 0.5)
const ICON: Color = Color(1.0, 1.0, 1.0, 0.85)

const STICK_RADIUS: float = 80.0  # Raio do círculo grande dos analógicos (px lógicos).
const THUMB_RADIUS: float = 34.0  # Raio do "polegar" que anda dentro do analógico.
const BUTTON_RADIUS: float = 46.0  # Raio dos botões grandes (arma, dash, interagir).
const SMALL_BUTTON_RADIUS: float = 28.0  # Raio do botão pequeno (pausa).
const MARGIN: float = 20.0  # Distância dos controles até a borda da tela.
## Faixa no topo da tela que não inicia analógicos (barras de vida e botão de pausa).
const TOP_DEAD_ZONE: float = 84.0
## O analógico de mira só aceita o toque até este múltiplo do raio, a partir do centro dele.
const AIM_ZONE: float = 1.9
## Folga na área de toque dos botões.
const HIT_SLACK: float = 1.25
# Parte do analógico de movimento que é ignorada (evita andar sozinho).
const MOVE_DEADZONE: float = 0.12
const AIM_DEADZONE: float = 0.22  # Parte do analógico de mira que é ignorada.
# Quantos quadros o botão de dash fica "apertado" (tempo para o jogador perceber).
const DASH_HOLD_FRAMES: int = 3
## Alcance (px) da mira automática do toque rápido.
const AUTO_AIM_RANGE: float = 420.0
## Quadros (física) que um toque rápido espera o player poder atacar antes de desistir (~0.33 s).
const TAP_TIMEOUT_FRAMES: int = 20
## Quadros seguidos com o player já atacando para considerar o toque entregue.
const TAP_DELIVERED_FRAMES: int = 2
## Quadros sem o player reagir ao botão pressionado até soltar e apertar de novo.
const REPRESS_FRAMES: int = 2
## Dedo "virtual" do mouse (simulação no PC).
const SIM_FINGER: int = 99
## Espada: true = mira enquanto segura e golpeia ao soltar (como o tiro); false = golpeia sem parar
## enquanto o dedo estiver no analógico.
const MELEE_ON_RELEASE: bool = true

## True quando os controles de toque estão valendo (celular ou `--mobile`).
var ativo: bool = false
## True = o botão de arma está no tiro carregado; false = espada.
var weapon_ranged: bool = false

var _shown: bool = false  # True enquanto os controles aparecem na tela.
var _blocked: bool = false  # True quando os controles estão bloqueados (morte, fim de fase).
var _player: Player = null  # Referência ao jogador atual.
var _canvas: Control = null  # Nó onde os controles são desenhados.
# Terminais da Fase 2 (para mostrar o botão E só quando há um por perto).
var _terminals: Array[Node] = []

var _fingers: Dictionary[int, StringName] = { }  # Mapa: número do dedo -> papel que ele cumpre.
var _move_finger: int = -1  # Dedo que controla o movimento (-1 = nenhum).
var _aim_finger: int = -1  # Dedo que controla a mira (-1 = nenhum).
var _move_center: Vector2 = Vector2.ZERO  # Centro atual do analógico de movimento (flutuante).
var _move_vec: Vector2 = Vector2.ZERO  # Posição do dedo no analógico de movimento (de -1 a 1).
var _aim_center: Vector2 = Vector2.ZERO  # Centro do analógico de mira (fixo).
var _aim_vec: Vector2 = Vector2.ZERO  # Posição do dedo no analógico de mira (de -1 a 1).
## Última direção de mira. Persiste depois de soltar o dedo: é ela que o tiro usa ao sair.
var _aim_dir: Vector2 = Vector2.ZERO
var _aim_down: bool = false  # True enquanto o dedo está no analógico de mira.
## Toque rápido que ainda não virou ataque (o player estava ocupado: dash, golpe...).
var _tap_pending: bool = false
var _tap_frames_left: int = 0  # Quadros que o toque rápido ainda espera.
var _tap_delivered_frames: int = 0  # Quadros seguidos em que o ataque do toque foi visto.
var _repress_counter: int = 0  # Contador para soltar e apertar de novo quando o jogador não reage.
var _dash_frames: int = 0  # Quadros restantes com o dash apertado.
var _pressed_roles: Dictionary[StringName, bool] = { }  # Botões que estão apertados agora.
# Estado (apertada ou não) de cada ação que este nó controla.
var _act_state: Dictionary[StringName, bool] = { }
var _view: Vector2 = Vector2(1152.0, 648.0)  # Tamanho da tela lógica atual.
# Margens de área segura (notch, cantos, barra de gestos): esquerda, topo, direita, base.
var _margins: Vector4 = Vector4.ZERO


## Liga os controles de toque. No PC sem `--mobile` desliga tudo para não gastar processamento.
func _ready() -> void:
	ativo = Platform.is_mobile  # Só fica ativo se a plataforma for celular.
	if not ativo:  # Fora do celular nada disso precisa rodar.
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		visible = false
		return
	layer = 60  # Desenha por cima do jogo e da HUD.
	# Continua funcionando com o jogo pausado (para não travar o toque).
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -100  # antes do player: o toque vira ação no mesmo quadro
	get_tree().set_quit_on_go_back(false)  # O botão voltar do Android não fecha o app sozinho.
	# O toque vira clique de mouse (necessário para os menus): sem isso o clique também atacaria.
	# Remove o mouse das ações de ataque (o toque já vira clique de mouse e atacaria duas vezes).
	InputMap.action_erase_events(ACT_MELEE)
	InputMap.action_erase_events(ACT_SHOOT)
	_canvas = Control.new()  # Cria a área onde os controles são desenhados.
	_canvas.name = "TouchCanvas"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Não captura cliques: só desenha.
	_canvas.draw.connect(_draw_controls)  # O desenho é refeito sempre que a área pede.
	_canvas.visible = false  # Começa escondida até o jogador existir.
	add_child(_canvas)
	EventBus.player_registered.connect(_on_player_registered)  # Descobre quando o jogador nasce.
	EventBus.player_died.connect(_on_blocked)  # Bloqueia os controles na morte.
	EventBus.game_over.connect(_on_blocked)  # Bloqueia os controles no game over.
	EventBus.level_completed.connect(_on_level_completed)  # Bloqueia os controles no fim da fase.
	EventBus.level_started.connect(_on_unblocked)  # Libera os controles quando a fase começa.
	get_tree().node_added.connect(_on_node_added)  # Observa nós novos (terminal, HUD e tutorial).
	# Recalcula o layout quando a janela muda de tamanho.
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()  # Calcula o layout inicial.
	_scan_existing_nodes.call_deferred()  # Procura nós que já existiam antes deste autoload ligar.


## Reage a eventos do sistema: perder o foco solta todos os dedos; o botão voltar vira pausa/menu.
func _notification(what: int) -> void:
	if not ativo:
		return
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_release_all()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back_pressed()


# --- API usada pelo Player ---

## Direção de mira do analógico. Fica valendo depois de soltar o dedo (o tiro sai nela).
func direcao_mira(_desde: Vector2, fallback: Vector2) -> Vector2:
	return _aim_dir if _aim_dir != Vector2.ZERO else fallback


## True enquanto o dedo está no analógico de mira.
func is_aiming() -> bool:
	return _aim_down


## O jogador nasceu: guarda a referência e reinicia mira, toque pendente e dedos.
func _on_player_registered(player: Node2D) -> void:
	_player = player as Player
	_blocked = false
	_aim_dir = Vector2.ZERO
	_tap_pending = false
	_release_all()


## Bloqueia os controles (jogador morreu ou game over).
func _on_blocked(_arg: Variant = null) -> void:
	_blocked = true


## Libera os controles quando uma fase começa.
func _on_unblocked() -> void:
	_blocked = false


## Fim da fase: bloqueia os controles.
func _on_level_completed(_next_scene: String) -> void:
	_blocked = true


## Passa por todos os nós existentes para adaptar terminais, HUD e tutorial.
func _scan_existing_nodes() -> void:
	for node: Node in get_tree().root.find_children("*", "", true, false):
		_on_node_added(node)


## Chamado para cada nó novo: guarda terminais, adapta a HUD e troca o tutorial por uma versão de toque.
func _on_node_added(node: Node) -> void:
	if node is QuizTerminal:
		_terminals.append(node)
	elif node is GameHUD:
		_adapt_hud.call_deferred(node)
	elif node is Control and node.scene_file_path == TUTORIAL_SCENE:
		_build_mobile_tutorial.call_deferred(node)


## Decide se os controles aparecem: não aparecem pausado, bloqueado ou com o jogador morto.
func _wants_to_show() -> bool:
	if _blocked or get_tree().paused:
		return false
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		return false
	if _player.esta_morto():
		return false
	return true


## Mostra ou esconde os controles. Ao esconder, solta todos os dedos.
func _set_shown(value: bool) -> void:
	if value == _shown:
		return
	_shown = value
	if not value:
		_release_all()
	_canvas.visible = value  # Mostra ou esconde a área de desenho.
	_canvas.queue_redraw()


# --- Layout ---

## Recalcula tamanho da tela, margens seguras e posição dos analógicos.
func _update_layout() -> void:
	# Tamanho visível atual da tela (muda em celulares mais compridos).
	_view = get_viewport().get_visible_rect().size
	_margins = _safe_margins()  # Margens de área segura.
	if _move_finger == -1:  # Só reposiciona o analógico se não houver dedo nele.
		_move_center = _rest_move()
	if _aim_finger == -1:
		_aim_center = _rest_aim()
	if _canvas != null:
		_canvas.queue_redraw()


## Margens (px de tela lógica) das áreas que o celular reserva: notch do iPhone, cantos
## arredondados, barra de gestos.
func _safe_margins() -> Vector4:
	if not OS.has_feature("mobile"):
		return Vector4.ZERO  # Fora do celular não há margens.
	var window: Vector2 = Vector2(DisplayServer.window_get_size())  # Tamanho da janela em pixels físicos.
	var screen: Vector2 = Vector2(DisplayServer.screen_get_size())  # Tamanho da tela em pixels físicos.
	# Retângulo que o aparelho garante estar livre de recortes.
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if window.x <= 0.0 or screen.x <= 0.0 or safe.size.x <= 0:
		return Vector4.ZERO
	var k: float = _view.x / window.x  # Fator de conversão entre pixels físicos e pixels lógicos.
	return Vector4(
		float(safe.position.x) * k,
		float(safe.position.y) * k,
		maxf(screen.x - float(safe.end.x), 0.0) * k,
		maxf(screen.y - float(safe.end.y), 0.0) * k)


## Posição de descanso do analógico de movimento: canto inferior esquerdo.
func _rest_move() -> Vector2:
	return Vector2(_margins.x + MARGIN + STICK_RADIUS + 36.0, _view.y - _margins.w - MARGIN - STICK_RADIUS - 24.0)


## Posição do analógico de mira: canto inferior direito.
func _rest_aim() -> Vector2:
	return Vector2(_view.x - _margins.z - MARGIN - STICK_RADIUS - 36.0, _view.y - _margins.w - MARGIN - STICK_RADIUS - 24.0)


## Centro de cada botão, calculado em relação ao analógico de mira (menos a pausa, que fica no canto superior).
func _button_center(role: StringName) -> Vector2:
	# Todos os botões da direita se posicionam a partir do analógico de mira.
	var aim: Vector2 = _rest_aim()
	match role:
		ROLE_WEAPON:
			return aim + Vector2(-152.0, -92.0)
		ROLE_DASH:
			return aim + Vector2(-196.0, 30.0)
		ROLE_INTERACT:
			return aim + Vector2(0.0, -188.0)
		ROLE_PAUSE:
			return Vector2(_view.x - _margins.z - 44.0, _margins.y + 44.0)
	return Vector2.ZERO


## Raio do botão (a pausa é menor).
func _button_radius(role: StringName) -> float:
	return SMALL_BUTTON_RADIUS if role == ROLE_PAUSE else BUTTON_RADIUS


## Diz se o botão está ativo: o de interagir só existe perto de um terminal.
func _button_enabled(role: StringName) -> bool:
	return role != ROLE_INTERACT or _interact_available()


## Diz se algum terminal da Fase 2 está com a dica "[E]" visível.
func _interact_available() -> bool:
	for terminal: Node in _terminals:
		# Ignora terminais já removidos da cena.
		if not is_instance_valid(terminal) or not terminal.is_inside_tree():
			continue
		# A dica do terminal é o sinal de que o jogador está por perto.
		var prompt: Variant = terminal.get("prompt")
		if prompt is Control and (prompt as Control).is_visible_in_tree():
			return true
	return false


## As barras de vida/carga saem do canto inferior (onde fica o analógico) para o topo esquerdo.
func _adapt_hud(hud: GameHUD) -> void:
	if not is_instance_valid(hud):  # A HUD pode ter sido removida antes de esta chamada atrasada rodar.
		return
	var y: float = _margins.y + 10.0  # Posição vertical inicial (abaixo do notch).
	for bar: Control in [hud.player_health_bar, hud.charge_bar]:  # Reposiciona cada barra.
		if bar == null:
			continue  # Barra ausente: pula.
		var width: float = bar.offset_right - bar.offset_left  # Largura atual da barra.
		var height: float = bar.offset_bottom - bar.offset_top  # Altura atual da barra.
		var left: float = _margins.x + 16.0  # Margem esquerda com área segura.
		bar.set_anchor_and_offset(SIDE_LEFT, 0.0, left)  # Ancora a borda esquerda no canto superior esquerdo.
		bar.set_anchor_and_offset(SIDE_RIGHT, 0.0, left + width)
		bar.set_anchor_and_offset(SIDE_TOP, 0.0, y)  # Ancora a borda de cima.
		bar.set_anchor_and_offset(SIDE_BOTTOM, 0.0, y + height)
		bar.grow_vertical = Control.GROW_DIRECTION_END  # Cresce para baixo.
		y += height + 4.0  # A próxima barra fica logo abaixo.


# --- Entrada ---

## Recebe os toques: botões, analógicos e (no PC com `--mobile`) o mouse como dedo.
func _input(event: InputEvent) -> void:
	if not _shown:  # Escondido, ignora tudo.
		return
	if event is InputEventScreenTouch:  # Toque de tela (apertou ou soltou).
		var touch := event as InputEventScreenTouch
		# Apertar chama _press; soltar chama _release.
		var used: bool = _press(touch.index, touch.position) if touch.pressed else _release(touch.index)
		if used:
			# Marca o evento como tratado para o jogo não reagir a ele também.
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:  # Dedo se arrastando.
		var drag := event as InputEventScreenDrag
		if _drag(drag.index, drag.position):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton or event is InputEventMouseMotion:  # Cliques do mouse.
		# O toque também gera um clique de mouse "emulado". Durante o jogo ele não pode vazar para o
		# mundo (ex.: tocar num botão por cima do terminal abriria o quiz sem querer).
		# Clique "emulado" pelo toque: engole para não vazar para o mundo.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			get_viewport().set_input_as_handled()
		elif Platform.mouse_as_finger:  # No PC com `--mobile`, o mouse vira um dedo.
			_simulate_with_mouse(event)
			get_viewport().set_input_as_handled()


## No PC (com `--mobile`) o botão esquerdo do mouse faz o papel de um dedo.
func _simulate_with_mouse(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION:  # Já foi tratado como toque emulado.
		return
	# Só o botão esquerdo conta.
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var click := event as InputEventMouseButton
		if click.pressed:
			_press(SIM_FINGER, click.position)  # Apertou: dedo falso toca na tela.
		else:
			_release(SIM_FINGER)  # Soltou: dedo falso sai da tela.
	elif event is InputEventMouseMotion and _fingers.has(SIM_FINGER):  # Arrastar com o botão pressionado.
		_drag(SIM_FINGER, (event as InputEventMouseMotion).position)


## Dedo encostou na tela: vira botão, analógico de movimento ou analógico de mira. Devolve true se o toque foi usado.
func _press(index: int, pos: Vector2) -> bool:
	if _fingers.has(index):  # O mesmo dedo não pode apertar duas vezes.
		return false
	# Primeiro tenta os botões.
	for role: StringName in [ROLE_PAUSE, ROLE_INTERACT, ROLE_WEAPON, ROLE_DASH]:
		if not _button_enabled(role):  # Botão desativado (ex.: interagir longe do terminal) é pulado.
			continue
		# Dentro do raio do botão (com folga).
		if pos.distance_to(_button_center(role)) <= _button_radius(role) * HIT_SLACK:
			_fingers[index] = role  # O dedo passa a "ser" esse botão.
			_pressed_roles[role] = true
			_button_down(role)
			_canvas.queue_redraw()
			return true
	if pos.y < TOP_DEAD_ZONE:  # Faixa do topo não inicia analógicos.
		return false
	if pos.x < _view.x * 0.5:  # Metade esquerda da tela: analógico de movimento flutuante.
		if _move_finger != -1:  # Só um dedo no movimento.
			return false
		_move_finger = index  # Guarda o dedo do movimento.
		_fingers[index] = ROLE_MOVE
		# O analógico nasce onde o dedo tocou (dentro dos limites da tela).
		_move_center = _clamp_stick_center(pos)
		_move_vec = Vector2.ZERO
		_drag(index, pos)
	else:
		# Metade direita: o analógico de mira é fixo e o toque precisa ser perto dele.
		if _aim_finger != -1 or pos.distance_to(_rest_aim()) > STICK_RADIUS * AIM_ZONE:
			return false
		_start_aim(index, pos)
	_canvas.queue_redraw()
	return true


## Começa a mira: se não houver arraste, o toque mira no inimigo mais próximo.
func _start_aim(index: int, pos: Vector2) -> void:
	_aim_finger = index  # Guarda o dedo da mira.
	_fingers[index] = ROLE_AIM
	_aim_center = _rest_aim()  # O analógico de mira fica sempre no lugar de descanso.
	_aim_vec = Vector2.ZERO
	_aim_down = true  # Marca que o dedo está na mira.
	_tap_pending = false  # Um novo toque cancela o toque pendente anterior.
	_tap_delivered_frames = 0
	_repress_counter = 0
	# Sem arrastar, o toque mira no inimigo mais próximo (ou segue na última direção).
	# Procura o inimigo mais próximo para mirar sozinho.
	var auto: Vector2 = _nearest_enemy_direction(_player_position())
	if auto != Vector2.ZERO:
		_aim_dir = auto
	elif _aim_dir == Vector2.ZERO and is_instance_valid(_player):
		_aim_dir = _player.facing_direction
	_drag(index, pos)


## Dedo arrastando: atualiza o analógico de movimento ou o de mira.
func _drag(index: int, pos: Vector2) -> bool:
	var role: StringName = _fingers.get(index, &"")  # Qual função esse dedo cumpre.
	if role == ROLE_MOVE:
		var delta: Vector2 = pos - _move_center  # Movimento: o centro acompanha o dedo se ele passar do raio.
		if delta.length() > STICK_RADIUS:  # Quanto o dedo se afastou do centro.
			_move_center += delta.normalized() * (delta.length() - STICK_RADIUS)
			delta = pos - _move_center
		_move_vec = delta / STICK_RADIUS  # Valor de -1 a 1 entregue ao jogador.
	elif role == ROLE_AIM:
		# Mira: o polegar não passa do raio do analógico.
		var delta: Vector2 = (pos - _aim_center).limit_length(STICK_RADIUS)
		_aim_vec = delta / STICK_RADIUS
		if _aim_vec.length() >= AIM_DEADZONE:  # Só muda a direção se passou da zona morta.
			_aim_dir = _aim_vec.normalized()
	else:
		return false
	_canvas.queue_redraw()
	return true


## Dedo saiu da tela: desfaz o papel dele (analógico volta ao descanso; mira vira tiro/golpe).
func _release(index: int) -> bool:
	if not _fingers.has(index):  # Dedo desconhecido (já liberado).
		return false
	var role: StringName = _fingers[index]
	_fingers.erase(index)  # Esquece o dedo.
	match role:
		ROLE_MOVE:
			_move_finger = -1  # Soltou o analógico de movimento: o personagem para.
			_move_vec = Vector2.ZERO
			_move_center = _rest_move()
		ROLE_AIM:
			_aim_finger = -1  # Soltou o analógico de mira: o ataque sai agora.
			_aim_down = false
			_aim_vec = Vector2.ZERO
			_aim_center = _rest_aim()
			# Toque rápido: se o ataque ainda não saiu, garante um (a direção em `_aim_dir` fica).
			# Se o ataque ainda não saiu, deixa pendente por alguns quadros.
			if _tap_delivered_frames < TAP_DELIVERED_FRAMES:
				_tap_pending = true
				_tap_frames_left = TAP_TIMEOUT_FRAMES
		_:
			_pressed_roles[role] = false  # Botões só liberam o estado de apertado.
	_canvas.queue_redraw()
	return true


## Ação de cada botão quando é apertado.
func _button_down(role: StringName) -> void:
	match role:
		ROLE_WEAPON:
			weapon_ranged = not weapon_ranged  # Alterna entre espada e tiro.
		ROLE_DASH:
			_set_action(ACT_DASH, true)  # Aperta o dash.
			_dash_frames = DASH_HOLD_FRAMES  # Mantém o dash apertado alguns quadros.
		ROLE_PAUSE:
			_tap_action(ACT_PAUSE)  # Pausa vira um toque na ação Pause.
		ROLE_INTERACT:
			_tap_action(ACT_INTERACT)  # Interagir vira um toque na ação interagir.


## Mantém o centro do analógico de movimento dentro da tela, fora da faixa do topo e das margens seguras.
func _clamp_stick_center(pos: Vector2) -> Vector2:
	var min_x: float = _margins.x + STICK_RADIUS + 8.0  # Limite esquerdo.
	var max_x: float = _view.x - _margins.z - STICK_RADIUS - 8.0  # Limite direito.
	var min_y: float = TOP_DEAD_ZONE + STICK_RADIUS * 0.5  # Limite de cima (abaixo da faixa morta).
	var max_y: float = _view.y - _margins.w - STICK_RADIUS - 8.0  # Limite de baixo.
	return Vector2(clampf(pos.x, min_x, max_x), clampf(pos.y, min_y, max_y))


# --- Ações ---

## A cada quadro de física: mostra/esconde os controles e converte dedos em ações do Input Map.
func _physics_process(_delta: float) -> void:
	var want: bool = _wants_to_show()  # Decide se os controles aparecem.
	_set_shown(want)
	if not _shown:
		return
	_apply_move()  # Movimento do analógico vira W/A/S/D.
	_apply_dash()  # Solta o dash depois dos quadros marcados.
	_apply_attack()  # Mira vira ataque (espada ou tiro).


## A cada quadro visual, redesenha os controles enquanto aparecem.
func _process(_delta: float) -> void:
	if _shown:
		_canvas.queue_redraw()


## Converte o analógico esquerdo nas quatro ações de movimento, com zona morta e força proporcional.
func _apply_move() -> void:
	var length: float = _move_vec.length()  # Tamanho do vetor do analógico.
	var out: Vector2 = Vector2.ZERO
	if length > MOVE_DEADZONE:  # Passou da zona morta: reescala para 0 a 1.
		out = _move_vec.normalized() * clampf((length - MOVE_DEADZONE) / (1.0 - MOVE_DEADZONE), 0.0, 1.0)
	_set_action(ACT_LEFT, out.x < 0.0, -out.x)  # Esquerda.
	_set_action(ACT_RIGHT, out.x > 0.0, out.x)  # Direita.
	_set_action(ACT_UP, out.y < 0.0, -out.y)  # Cima.
	_set_action(ACT_DOWN, out.y > 0.0, out.y)  # Baixo.


## Solta a ação de dash depois dos quadros em que ela ficou apertada.
func _apply_dash() -> void:
	if _dash_frames > 0:  # Ainda há quadros restantes.
		_dash_frames -= 1  # Um quadro a menos.
		if _dash_frames == 0:  # Acabou: solta o dash.
			_set_action(ACT_DASH, false)


## Converte o dedo no analógico de mira em ataque.
## - Tiro: mantém `charge_shoot` apertado enquanto o dedo está lá (carrega) e solta ao levantar (atira).
## - Espada: mira enquanto o dedo está lá e golpeia ao soltar (MELEE_ON_RELEASE).
## - Toque rápido: se o player estava ocupado, o ataque fica pendente até ele conseguir começar.
func _apply_attack() -> void:
	# O jogador já está atacando (carregando o tiro ou golpeando)?
	var attacking: bool = _player_is_attacking()
	if _tap_pending:  # Toque rápido pendente: conta quadros.
		_tap_frames_left -= 1
		if attacking:  # Contou quadros de ataque reconhecido.
			_tap_delivered_frames += 1
			if _tap_delivered_frames >= TAP_DELIVERED_FRAMES:  # Ataque confirmado: o toque foi entregue.
				_tap_pending = false
		elif _tap_frames_left <= 0:  # Esgotou o tempo de espera: desiste.
			_tap_pending = false
	elif _aim_down and attacking:  # Dedo na tela e jogador atacando: confirma a entrega.
		_tap_delivered_frames += 1
	var holding: bool = _aim_down or _tap_pending  # True enquanto há dedo na mira ou toque pendente.
	if weapon_ranged:  # Modo tiro: segura o botão de tiro enquanto o dedo está na mira.
		_set_action(ACT_MELEE, false)  # A espada fica solta.
		if not holding:  # Sem dedo: solta o tiro (ele sai).
			_set_action(ACT_SHOOT, false)  # Solta o botão do tiro.
			_repress_counter = 0
		elif attacking:  # Já atacando: mantém o botão apertado.
			_set_action(ACT_SHOOT, true)
			_repress_counter = 0
		# Botão apertado mas o jogador não reagiu: solta por um quadro para gerar um novo "apertou".
		elif _act_state.get(ACT_SHOOT, false):
			# O player não reagiu (estava no dash/golpe): solta um quadro para gerar novo "apertou".
			_repress_counter += 1
			if _repress_counter >= REPRESS_FRAMES:  # Passou o tempo: solta o botão.
				_set_action(ACT_SHOOT, false)
				_repress_counter = 0
		else:  # Aperta o botão do tiro.
			_set_action(ACT_SHOOT, true)
	else:
		_set_action(ACT_SHOOT, false)  # Modo espada: o tiro fica solto.
		# Alterna apertar/soltar: cada "apertou" é um golpe (a espada só bate quando está livre).
		# Com MELEE_ON_RELEASE só golpeia pelo toque pendente (ao soltar).
		var swing: bool = _tap_pending if MELEE_ON_RELEASE else holding
		# Alterna apertar e soltar: cada "apertou" é um golpe.
		_set_action(ACT_MELEE, swing and not _act_state.get(ACT_MELEE, false))


## O player já está carregando o tiro (modo tiro) ou golpeando (modo espada).
func _player_is_attacking() -> bool:
	if not is_instance_valid(_player):  # Sem jogador válido, não há ataque.
		return false
	if weapon_ranged:  # Tiro: estado de carga.
		return _player.state == Player.State.ATTACK_RANGED
	return _player.state == Player.State.ATTACK_MELEE  # Espada: estado de golpe.


## Aperta ou solta uma ação do Input Map só quando o estado muda (evita eventos repetidos).
func _set_action(action: StringName, pressed: bool, strength: float = 1.0) -> void:
	if pressed:  # Aperta.
		# Só envia de novo se a ação não estava apertada ou a força mudou.
		if not _act_state.get(action, false) or absf(Input.get_action_strength(action) - strength) > 0.01:
			Input.action_press(action, clampf(strength, 0.0, 1.0))  # Aperta a ação com a força indicada (0 a 1).
		_act_state[action] = true  # Guarda que está apertada.
	elif _act_state.get(action, false):  # Solta.
		Input.action_release(action)  # Solta a ação no Input Map.
		_act_state[action] = false  # Guarda que está solta.


## Aperta e solta uma ação (pausa, interagir) como um toque.
func _tap_action(action: StringName) -> void:
	var press := InputEventAction.new()  # Cria o evento de apertar.
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)  # Envia agora.
	var release := InputEventAction.new()  # Cria o evento de soltar.
	release.action = action
	release.pressed = false
	# Envia o "soltou" no fim do quadro, para o jogo ver os dois eventos.
	Input.parse_input_event.call_deferred(release)


## Solta todas as ações e dedos (perdeu o foco, jogador nasceu ou controles escondidos).
func _release_all() -> void:
	# Lista das ações que este nó controla.
	for action: StringName in [ACT_LEFT, ACT_RIGHT, ACT_UP, ACT_DOWN, ACT_DASH, ACT_MELEE, ACT_SHOOT]:
		if _act_state.get(action, false) or Input.is_action_pressed(action):  # Solta ações que estão presas.
			Input.action_release(action)
		_act_state[action] = false
	_fingers.clear()  # Esquece todos os dedos.
	_pressed_roles.clear()
	_move_finger = -1  # Volta aos valores de descanso.
	_aim_finger = -1
	_move_vec = Vector2.ZERO
	_aim_vec = Vector2.ZERO
	_aim_down = false
	_tap_pending = false
	_dash_frames = 0
	_move_center = _rest_move()  # Recentraliza o analógico de movimento.
	_aim_center = _rest_aim()


## Posição do jogador (ou origem se ele não existe mais).
func _player_position() -> Vector2:
	return _player.global_position if is_instance_valid(_player) else Vector2.ZERO


## Direção até o inimigo vivo mais próximo dentro do alcance da mira automática (ou ZERO).
## Direção até o inimigo vivo mais próximo (dentro de AUTO_AIM_RANGE), ou ZERO.
func _nearest_enemy_direction(from: Vector2) -> Vector2:
	var best: float = AUTO_AIM_RANGE  # Começa com o alcance máximo.
	var direction: Vector2 = Vector2.ZERO
	# Passa por todos os inimigos.
	for node: Node in get_tree().get_nodes_in_group(CombatUtils.GROUP_ENEMY):
		var enemy := node as Node2D
		if enemy == null or not CombatUtils.is_targetable(enemy):  # Ignora inimigos mortos ou intangíveis.
			continue
		var to_enemy: Vector2 = enemy.global_position - from  # Vetor do jogador até o inimigo.
		var distance: float = to_enemy.length()  # Distância até o inimigo.
		if distance < best and distance > 1.0:  # Fica com o mais próximo.
			best = distance
			direction = to_enemy / distance
	return direction


## Botão voltar do celular: pausa durante o jogo, despausa na pausa, senão vai ao menu ou sai.
func _on_back_pressed() -> void:
	if _shown:  # Em jogo: abre a pausa.
		_tap_action(ACT_PAUSE)
		return
	if get_tree().paused:  # Na pausa: o mesmo toque fecha a pausa.
		_tap_action(ACT_PAUSE)
		return
	var current: Node = get_tree().current_scene  # Fora do jogo: volta ao menu ou fecha o app.
	if current != null and current.scene_file_path == Global.MENU_SCENE:
		EventBus.quit_requested.emit()
	else:
		EventBus.main_menu_requested.emit()


# --- Desenho ---

## Desenha os analógicos e os botões ativos.
func _draw_controls() -> void:
	# Analógico de movimento.
	_draw_stick(_canvas, _move_center, _move_center + _move_vec.limit_length(1.0) * STICK_RADIUS, _move_finger != -1)
	# Analógico de mira.
	_draw_stick(_canvas, _aim_center, _aim_center + _aim_vec.limit_length(1.0) * STICK_RADIUS, _aim_finger != -1)
	for role: StringName in [ROLE_WEAPON, ROLE_DASH, ROLE_PAUSE, ROLE_INTERACT]:  # Botões.
		if _button_enabled(role):
			_draw_button(_canvas, role, _button_center(role), _pressed_roles.get(role, false))


## Desenha um analógico: círculo grande, contorno e o polegar.
func _draw_stick(ci: CanvasItem, center: Vector2, thumb: Vector2, active: bool) -> void:
	ci.draw_circle(center, STICK_RADIUS, Color(FILL.r, FILL.g, FILL.b, 0.28))
	ci.draw_arc(center, STICK_RADIUS, 0.0, TAU, 48, RING, 3.0, true)
	ci.draw_circle(thumb, THUMB_RADIUS, FILL_PRESSED if active else FILL)
	ci.draw_arc(thumb, THUMB_RADIUS, 0.0, TAU, 32, RING, 2.0, true)


## Desenha um botão com o ícone do papel dele (espada/tiro, dash, pausa ou E).
func _draw_button(ci: CanvasItem, role: StringName, center: Vector2, pressed: bool) -> void:
	var radius: float = _button_radius(role)  # Raio do botão.
	ci.draw_circle(center, radius, FILL_PRESSED if pressed else FILL)  # Fundo mais forte quando apertado.
	ci.draw_arc(center, radius, 0.0, TAU, 40, RING, 3.0, true)
	var s: float = radius / 46.0  # Escala dos ícones (os desenhos foram feitos para raio 46).
	match role:
		ROLE_WEAPON:
			if weapon_ranged:
				_draw_shot_icon(ci, center, s)
			else:
				_draw_sword_icon(ci, center, s)
		ROLE_DASH:
			ci.draw_polyline(PackedVector2Array([
				center + Vector2(-17.0, -14.0) * s, center + Vector2(-3.0, 0.0) * s, center + Vector2(-17.0, 14.0) * s]), ICON, 5.0 * s, true)
			ci.draw_polyline(PackedVector2Array([
				center + Vector2(3.0, -14.0) * s, center + Vector2(17.0, 0.0) * s, center + Vector2(3.0, 14.0) * s]), ICON, 5.0 * s, true)
		ROLE_PAUSE:
			ci.draw_rect(Rect2(center + Vector2(-9.0, -10.0), Vector2(6.0, 20.0)), ICON)
			ci.draw_rect(Rect2(center + Vector2(3.0, -10.0), Vector2(6.0, 20.0)), ICON)
		ROLE_INTERACT:
			var font: Font = ThemeDB.fallback_font
			ci.draw_string(font, center + Vector2(-radius, 11.0), "E", HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 32, ICON)


## Ícone da espada: lâmina, guarda e cabo.
func _draw_sword_icon(ci: CanvasItem, center: Vector2, s: float) -> void:
	ci.draw_line(center + Vector2(-14.0, 14.0) * s, center + Vector2(17.0, -17.0) * s, ICON, 6.0 * s, true)
	ci.draw_line(center + Vector2(-17.0, 3.0) * s, center + Vector2(-3.0, 17.0) * s, ICON, 5.0 * s, true)
	ci.draw_circle(center + Vector2(-19.0, 19.0) * s, 4.0 * s, ICON)


## Ícone do tiro: ponto central, anel e quatro traços (mira).
func _draw_shot_icon(ci: CanvasItem, center: Vector2, s: float) -> void:
	ci.draw_circle(center, 7.0 * s, ICON)
	ci.draw_arc(center, 16.0 * s, 0.0, TAU, 28, ICON, 3.0 * s, true)
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		ci.draw_line(center + direction * 16.0 * s, center + direction * 24.0 * s, ICON, 3.0 * s, true)


# --- Tutorial de controles (substitui a imagem de teclado/mouse no celular) ---

## Monta a tela de controles do tutorial para celular (substitui a imagem de teclado e mouse).
func _build_mobile_tutorial(tutorial: Control) -> void:
	# O tutorial pode ter sumido antes desta chamada atrasada.
	if not is_instance_valid(tutorial) or tutorial.has_node("MobileTutorial"):
		return
	var tutorial_layer := CanvasLayer.new()  # Camada própria por cima do tutorial.
	tutorial_layer.name = "MobileTutorial"
	tutorial_layer.layer = 20
	tutorial.add_child(tutorial_layer)
	var background := ColorRect.new()  # Fundo escuro.
	background.color = Color(0.03, 0.06, 0.11)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	tutorial_layer.add_child(background)
	var margin := MarginContainer.new()  # Margens da tela do tutorial.
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	tutorial_layer.add_child(margin)
	var column := VBoxContainer.new()  # Coluna com título, grade e botão.
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()  # Título.
	title.text = "CONTROLES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.1))
	column.add_child(title)
	var grid := GridContainer.new()  # Grade de duas colunas com um item por controle.
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)
	var rows: Array[Array] = [  # Texto de cada controle: papel, título e explicação.
		[ROLE_MOVE, "MOVER", "Analógico esquerdo."],
		[ROLE_AIM, "MIRAR E ATACAR", "Analógico direito: arraste para mirar (uma área colorida mostra o alcance) e solte para atacar. Com o tiro, segurar carrega. Um toque rápido mira no inimigo mais próximo."],
		[ROLE_WEAPON, "TROCAR DE ARMA", "Alterna entre a espada (área laranja) e o tiro carregado (barra azul)."],
		[ROLE_DASH, "ESQUIVAR", "Dash: desvia dos ataques por um instante."],
		[ROLE_INTERACT, "INTERAGIR", "O botão E aparece perto do terminal."],
		[ROLE_PAUSE, "PAUSA", "Botão no canto superior direito (ou o botão voltar do celular)."],
	]
	for row: Array in rows:  # Uma célula por controle.
		grid.add_child(_tutorial_cell(row[0], row[1], row[2]))
	var button := Button.new()  # Botão "Continuar".
	button.text = "Continuar"
	button.custom_minimum_size = Vector2(320.0, 64.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 28)
	button.pressed.connect(func() -> void:  # Ao tocar, chama a função do tutorial que avança.
		if is_instance_valid(tutorial) and tutorial.has_method("_on_continue_pressed"):
			tutorial.call("_on_continue_pressed"))
	column.add_child(button)


## Cria uma célula do tutorial: ícone à esquerda, título e texto à direita.
func _tutorial_cell(role: StringName, heading: String, body: String) -> Control:
	var cell := HBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override("separation", 14)
	var icon := TutorialIcon.new()  # Ícone que reaproveita o desenho dos botões.
	icon.role = role
	icon.owner_controls = self
	icon.custom_minimum_size = Vector2(112.0, 112.0)
	cell.add_child(icon)
	var texts := VBoxContainer.new()  # Coluna com título e explicação.
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	var head := Label.new()  # Título do controle.
	head.text = heading
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	texts.add_child(head)
	var text := Label.new()  # Explicação do controle.
	text.text = body
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 19)
	texts.add_child(text)
	cell.add_child(texts)
	return cell


## Ícone de controle do tutorial (reaproveita o desenho dos botões).
class TutorialIcon extends Control:
	var role: StringName = &""
	var owner_controls: Node = null

	## Desenha o analógico ou botão do papel correspondente.
	func _draw() -> void:
		if owner_controls == null:  # Sem o dono dos controles não dá para desenhar.
			return
		var center: Vector2 = size * 0.5  # Centro do ícone.
		if role == &"move" or role == &"aim":  # Analógicos são desenhados menores.
			draw_set_transform(center, 0.0, Vector2(0.62, 0.62))  # Reduz o desenho para caber no ícone.
			# Analógico com o polegar levemente deslocado.
			owner_controls.call("_draw_stick", self, Vector2.ZERO, Vector2(26.0, -16.0), false)
		else:
			owner_controls.call("_draw_button", self, role, center, false)  # Botões usam o desenho padrão.
