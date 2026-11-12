extends CanvasLayer
## Autoload MobileControls: controles de toque (Android/iOS/iPad). Só ficam ativos no celular, ou no PC
## com o argumento de usuário `--mobile` (o mouse simula o toque).
##
## Layout (padrão = print `res://referencias/mobile_layout.png`, editável em `MobileLayout`):
##   joystick de movimento (esq.), joystick de mira/tiro (dir.), botões de espada, dash, trocar arma e
##   modo comando, botão de pausa (sempre visível), botão E perto de terminais e o quadro de comandos.
##
## Tudo vira as MESMAS ações do InputMap que o teclado/mouse usam: o jogo não sabe de onde veio o input.
##
## Ataque do joystick direito: segure para mirar e solte para atacar (com o tiro, segurar carrega).
## Um toque rápido mira sozinho no inimigo mais próximo. O botão de espada sempre golpeia.

## Algum botão foi tocado (id = `MobileLayout.*`). Usado pelo tutorial e pelos testes.
signal button_pressed(id: StringName)
## O botão de trocar arma foi tocado (true = tiro, false = espada).
signal weapon_swapped(ranged: bool)
## O jogador tocou num botão do D-pad de fallback do quadro de comandos.
signal dpad_pressed(dir: int)
## O layout dos controles mudou (editor de HUD, restaurar padrão, área segura).
signal layout_changed

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

const MOVE_ZONE: float = 1.9  # O joystick de movimento aceita o toque até este múltiplo do raio.
const AIM_ZONE: float = 1.9  # Idem para o de mira.
const HIT_SLACK: float = 1.2  # Folga na área de toque dos botões.
const MOVE_DEADZONE: float = 0.12  # Parte do joystick de movimento que é ignorada.
const AIM_DEADZONE: float = 0.22  # Parte do joystick de mira que é ignorada.
const DASH_HOLD_FRAMES: int = 3  # Quadros que o dash fica "apertado".
const AUTO_AIM_RANGE: float = 420.0  # Alcance (px) da mira automática do toque rápido.
const TAP_TIMEOUT_FRAMES: int = 20  # Quadros que um toque rápido espera o player poder atacar.
const TAP_DELIVERED_FRAMES: int = 2  # Quadros seguidos com o player já atacando = toque entregue.
const REPRESS_FRAMES: int = 2  # Quadros sem reação até soltar e apertar de novo.
const SIM_FINGER: int = 99  # Dedo "virtual" do mouse (simulação no PC).
## Espada no joystick: true = mira enquanto segura e golpeia ao soltar.
const MELEE_ON_RELEASE: bool = true
const INTERACT_ANIM_TIME: float = 0.15  # Duração (s) da entrada/saída do botão E.
const INTERACT_ANIM_FRAMES: int = 3  # Quadros da entrada/saída do botão E.
const INTERACT_ANIM_SCALE: Array[float] = [0.0, 0.62, 1.12, 1.0]  # Escala em cada quadro (o 2º passa um pouco: "pop").
const INTERACT_ANIM_GLOW: Array[float] = [0.0, 0.9, 0.5, 0.0]  # Brilho dourado em cada quadro.
const LAYER_CONTROLS: int = 60  # Camada dos controles (acima do jogo e da HUD).
const LAYER_PAUSE: int = 110  # Camada do botão de pausa (acima do menu de pausa, que é 100).

## True quando os controles de toque estão valendo (celular ou `--mobile`).
var ativo: bool = false
## True = o joystick direito atira (tiro carregado); false = golpeia com a espada.
var weapon_ranged: bool = true
## Posição e tamanho de cada controle (carregado de `user://`).
var layout: MobileLayout = MobileLayout.new()
## Controle que o tutorial quer destacar (pisca). `&""` = nenhum.
var highlight: StringName = &""
## Enquanto o editor de HUD está aberto, os controles de jogo ficam parados.
var edit_mode: bool = false
## Escondido de propósito (ex.: a abertura escura do tutorial, antes de o jogador aparecer).
var suspended: bool = false
var _suspenders: Dictionary = {}  # Quem pediu `suspend` (id -> true).

var _shown: bool = false  # True enquanto os controles aparecem na tela.
var _pause_shown: bool = false  # True enquanto o botão de pausa aparece.
var _blocked: bool = false  # True quando os controles estão bloqueados (morte, fim de fase).
var _player: Player = null  # Jogador atual.
var _abilities: AbilityComponent = null  # Habilidades do jogador (modo comando).
var _canvas: Control = null  # Nó onde os controles são desenhados.
var _pause_layer: CanvasLayer = null  # Camada própria do botão de pausa.
var _pause_canvas: Control = null  # Desenho do botão de pausa.
var _terminals: Array[Node] = []  # Terminais da Fase 2 (para o botão E).
var _lab_huds: Array[Node] = []  # HUDs do labirinto: a dica "[E] ..." delas também liga o botão E (portas e painéis).
var _hud: GameHUD = null  # HUD da fase (as barras de status seguem o layout).
var _bar_native: Dictionary = {}  # Barra -> tamanho original.
var _hl_clock: float = 0.0  # Relógio do pisca de destaque.
var _interact_anim: float = 0.0  # 0 = botão E escondido, 1 = inteiro.
var _safe_clock: float = 0.0  # Relógio da conferência da área segura.

var _fingers: Dictionary[int, StringName] = { }  # dedo -> papel (id do controle)
var _move_finger: int = -1
var _aim_finger: int = -1
var _move_vec: Vector2 = Vector2.ZERO  # Joystick de movimento (-1 a 1).
var _aim_vec: Vector2 = Vector2.ZERO  # Joystick de mira (-1 a 1).
## Última direção de mira. Persiste depois de soltar o dedo: é ela que o tiro/golpe usa.
var _aim_dir: Vector2 = Vector2.ZERO
var _aim_down: bool = false
var _tap_pending: bool = false
var _tap_frames_left: int = 0
var _tap_delivered_frames: int = 0
var _repress_counter: int = 0
var _dash_frames: int = 0
var _pressed_roles: Dictionary[StringName, bool] = { }
var _act_state: Dictionary[StringName, bool] = { }
var _view: Vector2 = Vector2(1152.0, 648.0)
var _margins: Vector4 = Vector4.ZERO  # Área segura: esquerda, topo, direita, base.


func _ready() -> void:
	ativo = Platform.is_mobile()
	if not ativo:  # Fora do celular nada disso precisa rodar.
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		visible = false
		return
	layer = LAYER_CONTROLS
	process_mode = Node.PROCESS_MODE_ALWAYS  # Continua funcionando com o jogo pausado.
	process_physics_priority = -100  # antes do player: o toque vira ação no mesmo quadro
	get_tree().set_quit_on_go_back(false)  # O botão voltar do Android não fecha o app sozinho.
	# O toque já vira clique de mouse (menus); os ataques não podem ler o mouse também.
	InputMap.action_erase_events(ACT_MELEE)
	InputMap.action_erase_events(ACT_SHOOT)
	layout.load_saved()
	_canvas = Control.new()
	_canvas.name = "TouchCanvas"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_controls)
	_canvas.visible = false
	add_child(_canvas)
	_pause_layer = CanvasLayer.new()
	_pause_layer.name = "PauseLayer"
	_pause_layer.layer = LAYER_PAUSE
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_layer)
	_pause_canvas = Control.new()
	_pause_canvas.name = "PauseCanvas"
	_pause_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_canvas.draw.connect(_draw_pause)
	_pause_canvas.visible = false
	_pause_layer.add_child(_pause_canvas)
	EventBus.player_registered.connect(_on_player_registered)
	EventBus.player_died.connect(_on_blocked)
	EventBus.game_over.connect(_on_blocked)
	EventBus.level_completed.connect(_on_level_completed)
	EventBus.level_started.connect(_on_unblocked)
	TiltInput.arrow.connect(_on_tilt_arrow)
	get_tree().node_added.connect(_on_node_added)
	get_viewport().size_changed.connect(_update_layout)
	Platform.safe_area_changed.connect(func() -> void:
		_update_layout()
		refresh_layout())
	_update_layout()
	_scan_existing_nodes.call_deferred()


func _notification(what: int) -> void:
	if not ativo:
		return
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_release_all()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back_pressed()


# --- API usada pelo Player e pelos outros sistemas ---

## Direção de mira do joystick. Fica valendo depois de soltar o dedo.
func direcao_mira(_desde: Vector2, fallback: Vector2) -> Vector2:
	return _aim_dir if _aim_dir != Vector2.ZERO else fallback


## True enquanto o dedo está no joystick de mira.
func is_aiming() -> bool:
	return _aim_down


## Centro (px) do controle `id` na tela lógica atual.
func control_center(id: StringName) -> Vector2:
	return layout.get_center(id, _view, _margins)


## Raio (px) do controle redondo `id`.
func control_radius(id: StringName) -> float:
	return layout.get_radius(id)


## Retângulo (px) do controle `id`.
func control_rect(id: StringName) -> Rect2:
	return layout.get_rect(id, _view, _margins)


## Escala efetiva (layout x ajuste à proporção da tela) do controle `id`.
func control_scale(id: StringName) -> float:
	return layout.effective_scale(id, _view, _margins)


## Tamanho lógico da tela e margens seguras (o editor e o quadro usam).
func view_size() -> Vector2:
	return _view


func safe_margins() -> Vector4:
	return _margins


## True se o controle `id` está aparecendo e aceitando toque agora.
func is_control_active(id: StringName) -> bool:
	if id == MobileLayout.PAUSE:
		return _pause_shown
	if not _shown:
		return false
	return _button_enabled(id)


## Depois de mudar o layout (editor, restaurar padrão): reposiciona barras de status, quadro e redesenha.
func refresh_layout() -> void:
	_update_layout()
	if is_instance_valid(_hud):
		_adapt_hud(_hud)
	layout_changed.emit()
	get_tree().call_group(&"mobile_layout_listeners", &"on_mobile_layout_changed")


## Liga/desliga o modo de edição (editor de HUD).
func set_edit_mode(value: bool) -> void:
	edit_mode = value
	_release_all()
	if _canvas != null:
		_canvas.queue_redraw()


## Destaca (pisca) um controle do tutorial. `&""` apaga o destaque.
func set_highlight(id: StringName) -> void:
	highlight = id
	_hl_clock = 0.0
	if _canvas != null:
		_canvas.queue_redraw()
		_pause_canvas.queue_redraw()


## Volta ao estado inicial de cada fase (joystick solto, arma = tiro).
func reset_state() -> void:
	weapon_ranged = true
	_release_all()


# --- Eventos do jogo ---

func _on_player_registered(player: Node2D) -> void:
	_player = player as Player
	_blocked = false
	_aim_dir = Vector2.ZERO
	_tap_pending = false
	_release_all()
	_bind_abilities.call_deferred()


## Liga o modo comando às habilidades do jogador (o componente nasce junto com o Player).
func _bind_abilities() -> void:
	if not is_instance_valid(_player):
		return
	var found: AbilityComponent = _player.get_node_or_null(^"AbilityComponent") as AbilityComponent
	if found == _abilities:
		return
	if is_instance_valid(_abilities):
		CombatUtils.disconnect_if_connected(_abilities.command_mode_changed, _on_command_mode_changed)
	_abilities = found
	TiltInput.release(self)
	if _abilities != null:
		CombatUtils.connect_once(_abilities.command_mode_changed, _on_command_mode_changed)


## O modo comando abriu ou fechou: liga/desliga a leitura do acelerômetro.
func _on_command_mode_changed(active: bool) -> void:
	if active:
		TiltInput.acquire(self)
	else:
		TiltInput.release(self)
	if _canvas != null:
		_canvas.queue_redraw()


## O acelerômetro detectou uma seta: vira uma seta digitada no modo comando.
func _on_tilt_arrow(dir: int) -> void:
	if is_instance_valid(_abilities) and _abilities.command_active and not get_tree().paused:
		_abilities.press_arrow(dir)


func _on_blocked(_arg: Variant = null) -> void:
	_blocked = true


func _on_unblocked() -> void:
	_blocked = false


func _on_level_completed(_next_scene: String) -> void:
	_blocked = true


func _scan_existing_nodes() -> void:
	for node: Node in get_tree().root.find_children("*", "", true, false):
		_on_node_added(node)


## Chamado para cada nó novo: guarda terminais e adapta a HUD.
func _on_node_added(node: Node) -> void:
	if node is QuizTerminal:
		_terminals.append(node)
	elif node is LabHud:
		_lab_huds.append(node)
	elif node is GameHUD:
		_adapt_hud.call_deferred(node)


## Telas modais (diálogos, cutscenes) pedem para esconder os controles e a pausa enquanto estão abertas.
func suspend(holder: Object) -> void:
	_suspenders[holder.get_instance_id()] = true


func resume(holder: Object) -> void:
	_suspenders.erase(holder.get_instance_id())


func is_suspended() -> bool:
	return suspended or not _suspenders.is_empty()


func _wants_to_show() -> bool:
	if edit_mode or is_suspended() or _blocked or get_tree().paused:
		return false
	return _player_alive()


func _player_alive() -> bool:
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		return false
	return not _player.esta_morto()


## O botão de pausa aparece em jogo, também por cima de qualquer painel.
func _wants_pause_button() -> bool:
	return not edit_mode and not is_suspended() and not _blocked and _player_alive()


func _set_shown(value: bool) -> void:
	if value == _shown:
		return
	_shown = value
	if not value:
		_release_all()
	_canvas.visible = value
	_canvas.queue_redraw()


# --- Layout ---

func _update_layout() -> void:
	_view = get_viewport().get_visible_rect().size
	_margins = _compute_safe_margins()
	if _canvas != null:
		_canvas.queue_redraw()
		_pause_canvas.queue_redraw()


## Margens (px de tela lógica) das áreas que o celular reserva: notch, cantos arredondados, barra de gestos.
func _compute_safe_margins() -> Vector4:
	return Platform.get_safe_margins()


## As barras de vida/escudo e a barra de XP seguem o layout (posição e escala do controle "status"), sempre
## inteiras dentro da área segura: o emblema da barra de XP, que no computador passa da borda da barra, aqui desce.
func _adapt_hud(hud: GameHUD) -> void:
	if not is_instance_valid(hud):
		return
	_hud = hud
	var rect: Rect2 = layout.get_rect(MobileLayout.STATUS, _view, _margins)
	var s: float = layout.get_scale(MobileLayout.STATUS)
	var y: float = 0.0
	var bars_width: float = 0.0
	for bar: Control in [hud.player_health_bar, hud.charge_bar]:
		if bar == null:
			continue
		if not _bar_native.has(bar):
			_bar_native[bar] = Vector2(bar.offset_right - bar.offset_left, bar.offset_bottom - bar.offset_top)
		var native: Vector2 = _bar_native[bar]
		bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
		bar.grow_vertical = Control.GROW_DIRECTION_END
		bar.offset_left = rect.position.x
		bar.offset_top = rect.position.y + y
		bar.offset_right = bar.offset_left + native.x * s
		bar.offset_bottom = bar.offset_top + native.y * s
		bars_width = maxf(bars_width, native.x)
		y += (native.y + 8.0) * s
	var xp: XpBar = hud.get_node_or_null(^"Root/XpBar") as XpBar
	if xp != null and bars_width > 0.0:
		var top: float = -XpBar.V_EMBLEM_POS.y  # o emblema sobe isto acima da barra
		var left: float = XpBar.GAP - XpBar.V_EMBLEM_POS.x  # e passa isto para a esquerda
		xp.set_anchors_preset(Control.PRESET_TOP_LEFT)
		xp.scale = Vector2(s, s)
		xp.position = rect.position + Vector2(bars_width + left, top) * s
		xp.size = Vector2(XpBar.THICKNESS, MobileLayout.DEFS[MobileLayout.STATUS]["size"].y - top)


func _button_enabled(id: StringName) -> bool:
	return id != MobileLayout.INTERACT or _interact_available()


## Entrada/saída do botão E em 3 quadros (escala + brilho), sem atrasar o toque: o botão já responde no 1º quadro.
func _step_interact_anim(delta: float) -> void:
	var target: float = 1.0 if (_shown and _interact_available()) else 0.0
	_interact_anim = move_toward(_interact_anim, target, delta / INTERACT_ANIM_TIME)


## Quadro atual da animação do botão E: 0 = escondido, 1..INTERACT_ANIM_FRAMES = entrando/saindo, o último = parado.
func interact_anim_frame() -> int:
	return ceili(_interact_anim * float(INTERACT_ANIM_FRAMES) - 0.0001)


## Há um objeto interativo ao alcance? É a MESMA condição que mostra o aviso da tecla E no computador:
## a dica "[E]" de um terminal do quiz ou da HUD do labirinto (portas e painéis) está visível.
func _interact_available() -> bool:
	for hud: Node in _lab_huds:
		if not is_instance_valid(hud) or not hud.is_inside_tree():
			continue
		var label: Label = (hud as LabHud).prompt_label
		if label != null and label.is_visible_in_tree():
			return true
	for terminal: Node in _terminals:
		if not is_instance_valid(terminal) or not terminal.is_inside_tree():
			continue
		var prompt: Variant = terminal.get("prompt")
		if prompt is Control and (prompt as Control).is_visible_in_tree():
			return true
	return false


func _command_open() -> bool:
	return is_instance_valid(_abilities) and _abilities.command_active


## O D-pad de fallback aparece com o modo comando aberto e sem acelerômetro.
func dpad_wanted() -> bool:
	return _shown and _command_open() and (TiltInput.sensor_missing or bool(MobileSettings.get_value(MobileSettings.SECTION_TILT, "force_dpad", false)))


## Botões do D-pad na tela: lista de {dir, center, radius}.
func dpad_buttons() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rect: Rect2 = control_rect(MobileLayout.BOARD)
	var s: float = layout.effective_scale(MobileLayout.BOARD, _view, _margins)
	var origin: Vector2 = rect.position + CommandBoard.DPAD_CENTER * s
	var cell: float = CommandBoard.DPAD_CELL * s
	var offsets: Dictionary = {
		AbilityData.Dir.UP: Vector2(0.0, -cell), AbilityData.Dir.DOWN: Vector2(0.0, cell),
		AbilityData.Dir.LEFT: Vector2(-cell, 0.0), AbilityData.Dir.RIGHT: Vector2(cell, 0.0),
	}
	for dir: int in offsets:
		out.append({"dir": dir, "center": origin + (offsets[dir] as Vector2), "radius": cell * 0.5})
	return out


# --- Entrada ---

func _input(event: InputEvent) -> void:
	if edit_mode:
		return
	if not _shown and not _pause_shown:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var used: bool = _press(touch.index, touch.position) if touch.pressed else _release(touch.index)
		if used:
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _drag(drag.index, drag.position):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		# O toque também gera um clique de mouse "emulado". Durante o jogo ele não pode vazar para o mundo.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			var pos: Vector2 = (event as InputEventMouse).position
			# Botões da interface (ex.: "Pular tutorial") precisam do clique emulado; o mundo não.
			if (_shown or (_pause_shown and _hits_pause(pos))) and not _gui_button_at(pos):
				get_viewport().set_input_as_handled()
		elif Platform.mouse_as_finger:  # No PC com `--mobile`, o mouse vira um dedo.
			_simulate_with_mouse(event)
			get_viewport().set_input_as_handled()


func _simulate_with_mouse(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var click := event as InputEventMouseButton
		if click.pressed:
			_press(SIM_FINGER, click.position)
		else:
			_release(SIM_FINGER)
	elif event is InputEventMouseMotion and _fingers.has(SIM_FINGER):
		_drag(SIM_FINGER, (event as InputEventMouseMotion).position)


## Há um botão de interface (visível, ativo, fora dos controles de toque) embaixo de `pos`?
func _gui_button_at(pos: Vector2) -> bool:
	if _hits_pause(pos):
		return false
	for node: Node in get_tree().root.find_children("*", "BaseButton", true, false):
		var button: BaseButton = node as BaseButton
		if button.disabled or not button.is_visible_in_tree() or button.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		if button.get_global_rect().has_point(pos):
			return true
	return false


func _hits_pause(pos: Vector2) -> bool:
	return pos.distance_to(control_center(MobileLayout.PAUSE)) <= control_radius(MobileLayout.PAUSE) * HIT_SLACK


## Dedo encostou na tela. Devolve true se o toque foi usado por algum controle.
func _press(index: int, pos: Vector2) -> bool:
	if _fingers.has(index):
		return false
	if _pause_shown and _hits_pause(pos):
		_fingers[index] = MobileLayout.PAUSE
		_pressed_roles[MobileLayout.PAUSE] = true
		_button_down(MobileLayout.PAUSE)
		_pause_canvas.queue_redraw()
		return true
	if not _shown:
		return false
	for id: StringName in [MobileLayout.COMMAND, MobileLayout.WEAPON, MobileLayout.DASH, MobileLayout.INTERACT]:
		if not _button_enabled(id):
			continue
		if pos.distance_to(control_center(id)) <= control_radius(id) * HIT_SLACK:
			_fingers[index] = id
			_pressed_roles[id] = true
			_button_down(id)
			_canvas.queue_redraw()
			return true
	if dpad_wanted():
		for button: Dictionary in dpad_buttons():
			if pos.distance_to(button["center"] as Vector2) <= float(button["radius"]):
				_fingers[index] = &"dpad"
				_dpad_press(int(button["dir"]))
				return true
	# Joysticks (fixos).
	var move_center: Vector2 = control_center(MobileLayout.MOVE)
	var aim_center: Vector2 = control_center(MobileLayout.AIM)
	if _move_finger == -1 and pos.distance_to(move_center) <= control_radius(MobileLayout.MOVE) * MOVE_ZONE:
		_move_finger = index
		_fingers[index] = MobileLayout.MOVE
		_move_vec = Vector2.ZERO
		_drag(index, pos)
		_canvas.queue_redraw()
		return true
	if _aim_finger == -1 and pos.distance_to(aim_center) <= control_radius(MobileLayout.AIM) * AIM_ZONE:
		_start_aim(index, pos)
		_canvas.queue_redraw()
		return true
	return false


## Começa a mira: sem arrastar, o toque mira no inimigo mais próximo.
func _start_aim(index: int, pos: Vector2) -> void:
	_aim_finger = index
	_fingers[index] = MobileLayout.AIM
	_aim_vec = Vector2.ZERO
	_aim_down = true
	_tap_pending = false
	_tap_delivered_frames = 0
	_repress_counter = 0
	var auto: Vector2 = _nearest_enemy_direction(_player_position())
	if auto != Vector2.ZERO:
		_aim_dir = auto
	elif _aim_dir == Vector2.ZERO and is_instance_valid(_player):
		_aim_dir = _player.facing_direction
	_drag(index, pos)


func _drag(index: int, pos: Vector2) -> bool:
	var role: StringName = _fingers.get(index, &"")
	if role == MobileLayout.MOVE:
		var radius: float = control_radius(MobileLayout.MOVE)
		_move_vec = (pos - control_center(MobileLayout.MOVE)).limit_length(radius) / radius
	elif role == MobileLayout.AIM:
		var radius: float = control_radius(MobileLayout.AIM)
		_aim_vec = (pos - control_center(MobileLayout.AIM)).limit_length(radius) / radius
		if _aim_vec.length() >= AIM_DEADZONE:
			_aim_dir = _aim_vec.normalized()
	else:
		return false
	_canvas.queue_redraw()
	return true


## Dedo saiu da tela: desfaz o papel dele (joystick volta ao centro; mira vira tiro/golpe).
func _release(index: int) -> bool:
	if not _fingers.has(index):
		return false
	var role: StringName = _fingers[index]
	_fingers.erase(index)
	match role:
		MobileLayout.MOVE:
			_move_finger = -1
			_move_vec = Vector2.ZERO
		MobileLayout.AIM:
			_aim_finger = -1
			_aim_down = false
			_aim_vec = Vector2.ZERO
			# Toque rápido: se o ataque ainda não saiu, deixa pendente por alguns quadros.
			if _tap_delivered_frames < TAP_DELIVERED_FRAMES:
				_tap_pending = true
				_tap_frames_left = TAP_TIMEOUT_FRAMES
		&"dpad":
			pass
		_:
			_pressed_roles[role] = false
	if _canvas != null:
		_canvas.queue_redraw()
		_pause_canvas.queue_redraw()
	return true


## Ação de cada botão quando é apertado.
func _button_down(id: StringName) -> void:
	match id:
		MobileLayout.WEAPON:
			weapon_ranged = not weapon_ranged
			weapon_swapped.emit(weapon_ranged)
		MobileLayout.DASH:
			_set_action(ACT_DASH, true)
			_dash_frames = DASH_HOLD_FRAMES
		MobileLayout.PAUSE:
			_tap_action(ACT_PAUSE)
		MobileLayout.INTERACT:
			_tap_action(ACT_INTERACT)
		MobileLayout.COMMAND:
			_command_press()
	button_pressed.emit(id)


## Botão de modo comando: abre/fecha o modo (as setas vêm da inclinação do celular).
func _command_press() -> void:
	if is_instance_valid(_abilities):
		_abilities.toggle_command_mode()


## Toque no D-pad de fallback.
func _dpad_press(dir: int) -> void:
	dpad_pressed.emit(dir)
	if is_instance_valid(_abilities):
		_abilities.press_arrow(dir)


# --- Ações ---

func _physics_process(_delta: float) -> void:
	_set_shown(_wants_to_show())
	var pause_now: bool = _wants_pause_button()
	if pause_now != _pause_shown:
		_pause_shown = pause_now
		_pause_canvas.visible = pause_now
		_pause_canvas.queue_redraw()
	if not _shown:
		return
	_apply_move()
	_apply_dash()
	_apply_attack()


func _process(delta: float) -> void:
	_hl_clock += delta
	_step_interact_anim(delta)
	if Platform.is_real_device():  # girar 180 graus troca o lado do notch sem mudar o tamanho da janela
		_safe_clock += delta
		if _safe_clock >= 0.5:
			_safe_clock = 0.0
			var margins: Vector4 = _compute_safe_margins()
			if not margins.is_equal_approx(_margins):
				_update_layout()
				refresh_layout()
	if _shown:
		_canvas.queue_redraw()
	if _pause_shown:
		_pause_canvas.queue_redraw()


## Converte o joystick esquerdo nas quatro ações de movimento, com zona morta e força proporcional.
func _apply_move() -> void:
	var length: float = _move_vec.length()
	var out: Vector2 = Vector2.ZERO
	if length > MOVE_DEADZONE:
		out = _move_vec.normalized() * clampf((length - MOVE_DEADZONE) / (1.0 - MOVE_DEADZONE), 0.0, 1.0)
	_set_action(ACT_LEFT, out.x < 0.0, -out.x)
	_set_action(ACT_RIGHT, out.x > 0.0, out.x)
	_set_action(ACT_UP, out.y < 0.0, -out.y)
	_set_action(ACT_DOWN, out.y > 0.0, out.y)


func _apply_dash() -> void:
	if _dash_frames > 0:
		_dash_frames -= 1
		if _dash_frames == 0:
			_set_action(ACT_DASH, false)


## Converte o dedo no joystick de mira (e o botão de espada) em ataque.
## - Tiro: mantém `charge_shoot` apertado enquanto o dedo está lá (carrega) e solta ao levantar (atira).
## - Espada no joystick: mira enquanto o dedo está lá e golpeia ao soltar.
## - Botão de espada: sempre golpeia (insiste por alguns quadros até o player poder).
func _apply_attack() -> void:
	var attacking: bool = _player_is_attacking()
	if _tap_pending:
		_tap_frames_left -= 1
		if attacking:
			_tap_delivered_frames += 1
			if _tap_delivered_frames >= TAP_DELIVERED_FRAMES:
				_tap_pending = false
		elif _tap_frames_left <= 0:
			_tap_pending = false
	elif _aim_down and attacking:
		_tap_delivered_frames += 1
	var holding: bool = _aim_down or _tap_pending
	var swing: bool = false
	if weapon_ranged:
		if not holding:
			_set_action(ACT_SHOOT, false)
			_repress_counter = 0
		elif attacking:
			_set_action(ACT_SHOOT, true)
			_repress_counter = 0
		elif _act_state.get(ACT_SHOOT, false):
			_repress_counter += 1  # O player não reagiu (dash/golpe): solta um quadro para gerar novo "apertou".
			if _repress_counter >= REPRESS_FRAMES:
				_set_action(ACT_SHOOT, false)
				_repress_counter = 0
		else:
			_set_action(ACT_SHOOT, true)
	else:
		_set_action(ACT_SHOOT, false)
		swing = _tap_pending if MELEE_ON_RELEASE else holding
	_set_action(ACT_MELEE, swing and not _act_state.get(ACT_MELEE, false))


## O player já está carregando o tiro (modo tiro) ou golpeando (modo espada).
func _player_is_attacking() -> bool:
	if not is_instance_valid(_player):
		return false
	if weapon_ranged:
		return _player.state == Player.State.ATTACK_RANGED
	return _player.state == Player.State.ATTACK_MELEE


## Aperta ou solta uma ação do Input Map só quando o estado muda (evita eventos repetidos).
func _set_action(action: StringName, pressed: bool, strength: float = 1.0) -> void:
	if pressed:
		if not _act_state.get(action, false) or absf(Input.get_action_strength(action) - strength) > 0.01:
			Input.action_press(action, clampf(strength, 0.0, 1.0))
		_act_state[action] = true
	elif _act_state.get(action, false):
		Input.action_release(action)
		_act_state[action] = false


## Aperta e solta uma ação (pausa, interagir) como um toque.
func _tap_action(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event.call_deferred(release)  # o "soltou" vai no fim do quadro


## Solta todas as ações e dedos (perdeu o foco, jogador nasceu ou controles escondidos).
func _release_all() -> void:
	for action: StringName in [ACT_LEFT, ACT_RIGHT, ACT_UP, ACT_DOWN, ACT_DASH, ACT_MELEE, ACT_SHOOT]:
		if _act_state.get(action, false) or Input.is_action_pressed(action):
			Input.action_release(action)
		_act_state[action] = false
	_fingers.clear()
	_pressed_roles.clear()
	_move_finger = -1
	_aim_finger = -1
	_move_vec = Vector2.ZERO
	_aim_vec = Vector2.ZERO
	_aim_down = false
	_tap_pending = false
	_dash_frames = 0


func _player_position() -> Vector2:
	return _player.global_position if is_instance_valid(_player) else Vector2.ZERO


## Direção até o inimigo vivo mais próximo dentro de AUTO_AIM_RANGE (ou ZERO).
func _nearest_enemy_direction(from: Vector2) -> Vector2:
	var best: float = AUTO_AIM_RANGE
	var direction: Vector2 = Vector2.ZERO
	for node: Node in get_tree().get_nodes_in_group(CombatUtils.GROUP_ENEMY):
		var enemy := node as Node2D
		if enemy == null or not CombatUtils.is_targetable(enemy):
			continue
		var to_enemy: Vector2 = enemy.global_position - from
		var distance: float = to_enemy.length()
		if distance < best and distance > 1.0:
			best = distance
			direction = to_enemy / distance
	return direction


## Botão voltar do celular: pausa durante o jogo, despausa na pausa, senão vai ao menu ou sai.
func _on_back_pressed() -> void:
	if _shown or get_tree().paused:
		_tap_action(ACT_PAUSE)
		return
	var current: Node = get_tree().current_scene
	if current != null and current.scene_file_path == Global.MENU_SCENE:
		EventBus.quit_requested.emit()
	else:
		EventBus.main_menu_requested.emit()


# --- Desenho ---

func _draw_controls() -> void:
	var move_r: float = control_radius(MobileLayout.MOVE)
	MobileDraw.stick(_canvas, control_center(MobileLayout.MOVE), move_r, _move_vec.limit_length(1.0) * move_r * 0.62, _move_finger != -1)
	var aim_r: float = control_radius(MobileLayout.AIM)
	# A bolinha do joystick direito mostra a arma atual (o botão de trocar arma alterna entre tiro e espada).
	MobileDraw.stick(_canvas, control_center(MobileLayout.AIM), aim_r, _aim_vec.limit_length(1.0) * aim_r * 0.62, _aim_finger != -1,
			"ic_shot.png" if weapon_ranged else "ic_sword.png")
	for id: StringName in [MobileLayout.DASH, MobileLayout.WEAPON, MobileLayout.COMMAND]:
		var active: bool = id == MobileLayout.COMMAND and _command_open()
		MobileDraw.button(_canvas, control_center(id), control_radius(id), id, _pressed_roles.get(id, false), active)
	var frame: int = interact_anim_frame()
	if frame > 0:  # botão E: aparece/some em 3 quadros de escala e brilho
		var center: Vector2 = control_center(MobileLayout.INTERACT)
		var radius: float = control_radius(MobileLayout.INTERACT) * INTERACT_ANIM_SCALE[frame]
		MobileDraw.button(_canvas, center, radius, MobileLayout.INTERACT, _pressed_roles.get(MobileLayout.INTERACT, false))
		if INTERACT_ANIM_GLOW[frame] > 0.0:
			_canvas.draw_arc(center, radius + 3.0, 0.0, TAU, 40, Color(MobileDraw.COLOR_SELECTED, INTERACT_ANIM_GLOW[frame]), 4.0, true)
	if highlight != &"" and highlight != MobileLayout.PAUSE:
		_draw_highlight(_canvas)


func _draw_pause() -> void:
	MobileDraw.button(_pause_canvas, control_center(MobileLayout.PAUSE), control_radius(MobileLayout.PAUSE),
			MobileLayout.PAUSE, _pressed_roles.get(MobileLayout.PAUSE, false))
	if highlight == MobileLayout.PAUSE:
		_draw_highlight(_pause_canvas)


## Anel dourado que pisca no controle que o tutorial quer mostrar.
func _draw_highlight(ci: CanvasItem) -> void:
	if not MobileLayout.DEFS.has(highlight):
		return
	if layout.is_circle(highlight):
		MobileDraw.glow(ci, control_center(highlight), control_radius(highlight), _hl_clock)
	else:
		var rect: Rect2 = control_rect(highlight).grow(6.0)
		var pulse: float = 0.5 + 0.5 * sin(_hl_clock * TAU * 1.6)
		ci.draw_rect(rect, Color(MobileDraw.COLOR_SELECTED, 0.35 + 0.65 * pulse), false, 4.0)
