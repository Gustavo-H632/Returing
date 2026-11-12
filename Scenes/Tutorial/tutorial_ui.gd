class_name TutorialUi
extends Node
## Interface do tutorial: vinheta e granulado, a voz do mentor (só texto), os painéis de comando
## (WASD, tecla, mouse) com checks verdes e o botão de pular. Tudo é desenhado por código.

## O jogador pediu para pular o tutorial.
signal skip_requested

const FONT: Font = preload("res://assets/fonts/VT323-Regular.ttf")

const COLOR_VOICE: Color = Color("#d8ecff")  # Texto da voz.
const COLOR_GLOW: Color = Color("#4aa8ff")  # Brilho da voz.
const COLOR_PANEL: Color = Color(0.03, 0.05, 0.08, 0.9)  # Fundo dos painéis.
const COLOR_CYAN: Color = Color("#3ad6ff")  # Destaque (borda e tecla apertada).
const COLOR_OK: Color = Color("#43e07a")  # Check verde.
const COLOR_OK_DARK: Color = Color("#17492b")  # Tecla já testada.
const COLOR_KEY_FACE: Color = Color("#29323f")  # Tecla solta.
const COLOR_KEY_EDGE: Color = Color("#5a6a80")  # Borda da tecla.
const COLOR_KEY_SHADOW: Color = Color("#05080c")  # Sombra da tecla.
const COLOR_KEY_INK: Color = Color("#e6eef8")  # Letra da tecla.
const COLOR_GOLD: Color = Color("#f2c94c")  # Botão do mouse em destaque.

## Letras por segundo da digitação da voz.
const TYPE_SPEED: float = 30.0
## Tamanho da fonte da voz e dos textos de painel.
const FONT_VOICE: int = 44
const FONT_PANEL: int = 32
const FONT_HINT: int = 22
## Tempo (s) segurando TAB para pular.
const SKIP_HOLD: float = 1.0
## Celular: o painel de comando se centraliza entre os joysticks e botões (proporção da largura da tela) e tem esta largura.
const MOBILE_PANEL_CENTER: float = 0.42
const MOBILE_PANEL_WIDTH: float = 560.0

## Efeito de tela: vinheta, granulado e escurecimento.
const POST_SHADER: String = """
shader_type canvas_item;
uniform float darkness : hint_range(0.0, 1.0) = 0.0;
uniform float vignette : hint_range(0.0, 1.5) = 0.7;
uniform float grain : hint_range(0.0, 0.4) = 0.07;
uniform float time_s = 0.0;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
void fragment() {
	float d = distance(UV, vec2(0.5)) * 1.4142;
	float v = smoothstep(0.35, 1.05, d) * vignette;
	float n = hash(floor(FRAGCOORD.xy * 0.5) + floor(time_s * 24.0)) - 0.5;
	float ga = abs(n) * grain * 2.0;
	float base_a = clamp(darkness + v, 0.0, 1.0);
	float out_a = base_a + (1.0 - base_a) * ga;
	vec3 gc = vec3(n > 0.0 ? 1.0 : 0.0);
	vec3 col = (gc * ga * (1.0 - base_a)) / max(out_a, 0.0001);
	COLOR = vec4(col, out_a);
}
"""

var sfx: TutorialSfx = null  # Sons (o tutorial entrega pronto).

var _post_layer: CanvasLayer = null  # Camada do efeito de tela (abaixo da interface).
var _post: ColorRect = null  # Retângulo com o shader.
var _post_material: ShaderMaterial = null
var _ui_layer: CanvasLayer = null  # Camada da interface.
var _root: Control = null  # Raiz da interface (com o tema do jogo).
var _voice_wrap: Control = null  # Moldura da voz.
var _voice: Label = null  # Texto da voz do mentor.
var _voice_tween: Tween = null  # Fade da voz.
var _speak_id: int = 0  # Número da fala atual (invalida falas antigas).
var _jitter_clock: float = 0.0  # Relógio da tremida da voz.
var _clock: float = 0.0  # Relógio geral (pulso do brilho e do granulado).

var _panel_slot: Control = null  # Área onde o painel de comando aparece.
var _panel: PanelContainer = null  # Painel atual (null se não há).
var _panel_style: StyleBoxFlat = null  # Estilo do painel atual (a borda vira verde ao concluir).
var _panel_keys: Dictionary[StringName, Control] = {}  # Teclas do painel atual, por ação.
var _panel_big_check: Control = null  # Check grande ao concluir.
var _panel_tween: Tween = null  # Animação do painel.

var _skip_button: Button = null  # Botão "Pular tutorial".
var _skip_bar: ColorRect = null  # Barra de progresso do TAB.
var _skip_hold: float = 0.0  # Tempo segurando TAB.
var _skip_confirm_left: float = 0.0  # Tempo restante para confirmar o clique no botão.
var _skip_emitted: bool = false  # Já pediu para pular.


## Cria as camadas, a voz, o painel e o botão de pular.
func _ready() -> void:
	_build_post()
	_build_ui()


## Relógios: granulado, tremida da voz, brilho e botão de pular.
func _process(delta: float) -> void:
	_clock += delta
	_post_material.set_shader_parameter(&"time_s", _clock)
	_update_voice_fx(delta)
	_update_skip(delta)


# --- Efeito de tela ---

## Escurecimento total da tela (0 = normal, 1 = preto).
func set_darkness(value: float) -> void:
	_post_material.set_shader_parameter(&"darkness", clampf(value, 0.0, 1.0))


## Anima o escurecimento até `target` em `time` segundos.
func fade_darkness(target: float, time: float) -> Tween:
	var tween: Tween = create_tween()
	tween.tween_method(set_darkness, float(_post_material.get_shader_parameter(&"darkness")), target, time)
	return tween


## Força da vinheta (bordas escuras).
func set_vignette(value: float) -> void:
	_post_material.set_shader_parameter(&"vignette", value)


## Anima a vinheta até `target`.
func fade_vignette(target: float, time: float) -> Tween:
	var tween: Tween = create_tween()
	tween.tween_method(set_vignette, float(_post_material.get_shader_parameter(&"vignette")), target, time)
	return tween


# --- Voz do mentor ---

## Fala uma linha com digitação, espera `hold` segundos e some. Devolve quando a linha sumiu.
func speak(text: String, hold: float = 1.5) -> void:
	var id: int = await _type_line(text)
	if id != _speak_id:  # Outra fala começou: esta não faz mais nada.
		return
	await get_tree().create_timer(hold, false).timeout
	if id != _speak_id:
		return
	await _fade_voice(0.0, 0.5)


## Fala uma linha e devolve assim que terminar de digitar; a linha some sozinha depois de `hold`.
func say(text: String, hold: float = 1.8) -> void:
	var id: int = await _type_line(text)
	if id != _speak_id:
		return
	_hide_later(id, hold)  # Não espera: o tutorial segue enquanto a linha fica na tela.


## Some depois de `hold` segundos, se nenhuma fala nova tiver começado.
func _hide_later(id: int, hold: float) -> void:
	await get_tree().create_timer(hold, false).timeout
	if id == _speak_id:
		await _fade_voice(0.0, 0.5)


## Faz a digitação letra por letra (sem som: a voz do mentor é só texto). Devolve o número da fala.
func _type_line(text: String) -> int:
	_speak_id += 1
	var id: int = _speak_id
	_voice.text = text
	_voice.visible_characters = 0
	_voice.modulate.a = 0.0
	_fade_voice(1.0, 0.3)
	var typed: float = 0.0
	var shown: int = 0
	while shown < text.length():
		await get_tree().process_frame
		if id != _speak_id:  # Outra fala assumiu.
			return id
		if get_tree().paused:
			continue
		typed += get_process_delta_time() * TYPE_SPEED
		var target: int = mini(int(typed), text.length())
		if target != shown:
			shown = target
			_voice.visible_characters = shown
	_voice.visible_characters = -1
	return id


## Anima a transparência da voz.
func _fade_voice(target: float, time: float) -> void:
	if _voice_tween != null and _voice_tween.is_valid():
		_voice_tween.kill()
	_voice_tween = create_tween()
	_voice_tween.tween_property(_voice, ^"modulate:a", target, time)
	await _voice_tween.finished


## Texto que está na voz agora (usado nos testes).
func voice_text() -> String:
	return _voice.text


## Tremida leve e pulso do brilho: "voz vinda de lugar nenhum".
func _update_voice_fx(delta: float) -> void:
	if _voice.modulate.a <= 0.01:
		return
	_jitter_clock += delta
	if _jitter_clock >= 0.06:  # ~16 tremidas por segundo.
		_jitter_clock = 0.0
		_voice.position = Vector2(randf_range(-1.4, 1.4), randf_range(-1.2, 1.2))
	var glow: Color = COLOR_GLOW
	glow.a = 0.32 + 0.12 * sin(_clock * 3.0)
	_voice.add_theme_color_override(&"font_outline_color", glow)


# --- Painéis de comando ---

## Mostra um painel. `kind`: `wasd`, `key`, `mouse_left`, `mouse_right` ou `arrow_right`.
## `key_text` é o nome da tecla (só para `key`). `hint` é uma linha pequena abaixo do ícone.
func show_panel(kind: StringName, text: String, key_text: String = "", hint: String = "") -> void:
	clear_panel()
	_panel_keys.clear()
	_panel = PanelContainer.new()
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = COLOR_PANEL
	_panel_style.border_color = COLOR_CYAN
	_panel_style.set_border_width_all(2)
	_panel_style.set_content_margin_all(18.0)
	_panel_style.shadow_color = Color(COLOR_CYAN, 0.18)
	_panel_style.shadow_size = 10
	_panel.add_theme_stylebox_override(&"panel", _panel_style)
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_bottom = -52.0
	# Celular: `_panel_slot` é a faixa livre de baixo (entre o joystick esquerdo e os botões da direita): centralizado
	# nela, o painel não cobre nenhum controle.
	_panel_slot.add_child(_panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	_panel.add_child(column)

	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override(&"separation", 12)
	column.add_child(title_row)
	title_row.add_child(_label(text, FONT_PANEL, COLOR_KEY_INK))
	_panel_big_check = _BigCheck.new()
	_panel_big_check.modulate.a = 0.0
	title_row.add_child(_panel_big_check)

	var icon: Control = _build_icon(kind, key_text)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon)
	if not hint.is_empty():
		var hint_label: Label = _label(hint, FONT_HINT, Color("#8fa3b8"))
		if Platform.is_mobile():  # dica quebra em linhas para o painel caber entre os controles
			hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			# A largura acompanha a faixa livre (muda com a resolução, o notch e o layout escolhido pelo jogador).
			var fit_hint: Callable = func() -> void:
				if is_instance_valid(hint_label):
					hint_label.custom_minimum_size.x = minf(MOBILE_PANEL_WIDTH, _panel_slot.size.x - 48.0)
			fit_hint.call()
			_panel_slot.resized.connect(fit_hint)
			hint_label.tree_exiting.connect(func() -> void: _panel_slot.resized.disconnect(fit_hint))
		column.add_child(hint_label)

	# Entrada: sobe um pouco e aparece.
	_panel_slot.position.y = 24.0
	_panel_slot.modulate.a = 0.0
	_kill_panel_tween()
	_panel_tween = create_tween().set_parallel(true)
	_panel_tween.tween_property(_panel_slot, ^"position:y", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_panel_tween.tween_property(_panel_slot, ^"modulate:a", 1.0, 0.25)
	if sfx != null:
		sfx.play(&"menu_open", -10.0, 1.4)


## Liga ou desliga o brilho de "apertada" de uma tecla do painel.
func set_key_pressed(action: StringName, pressed: bool) -> void:
	var key: Control = _panel_keys.get(action)
	if key != null:
		key.set(&"pressed", pressed)


## Marca uma tecla como testada (check verde). Devolve true se ela ainda não estava marcada.
func mark_key(action: StringName) -> bool:
	var key: Control = _panel_keys.get(action)
	if key == null or bool(key.get(&"checked")):
		return false
	key.set(&"checked", true)
	if sfx != null:
		sfx.play(&"key_ok", -4.0, 1.0 + 0.12 * float(_checked_count()))
	return true


## A tecla `action` do painel atual já tem check?
func is_key_checked(action: StringName) -> bool:
	var key: Control = _panel_keys.get(action)
	return key != null and bool(key.get(&"checked"))


## Quantas teclas do painel já têm check.
func _checked_count() -> int:
	var total: int = 0
	for key: Control in _panel_keys.values():
		if bool(key.get(&"checked")):
			total += 1
	return total


## Há um painel na tela?
func has_panel() -> bool:
	return _panel != null


## Conclui o painel: pisca em verde, mostra o check, toca o som de sucesso e some com fade.
## Devolve quando o painel sumiu.
func complete_panel() -> void:
	if _panel == null:
		return
	var panel: PanelContainer = _panel
	var style: StyleBoxFlat = _panel_style
	if sfx != null:
		sfx.play(&"success", -2.0)
	style.border_color = COLOR_OK
	style.shadow_color = Color(COLOR_OK, 0.45)
	style.bg_color = Color(0.04, 0.16, 0.08, 0.92)
	_kill_panel_tween()
	_panel_tween = create_tween()
	_panel_tween.tween_property(_panel_slot, ^"modulate", Color(1.7, 2.2, 1.7, 1.0), 0.12)  # Pisca verde.
	_panel_tween.tween_property(_panel_slot, ^"modulate", Color.WHITE, 0.2)
	if _panel_big_check != null:
		var check: Control = _panel_big_check
		_panel_tween.parallel().tween_property(check, ^"modulate:a", 1.0, 0.15)
	await _panel_tween.finished
	await get_tree().create_timer(0.55, false).timeout  # Deixa o jogador ver o check.
	if panel != _panel:  # Outro painel já assumiu.
		return
	_kill_panel_tween()
	_panel_tween = create_tween().set_parallel(true)
	_panel_tween.tween_property(_panel_slot, ^"modulate:a", 0.0, 0.4)
	_panel_tween.tween_property(_panel_slot, ^"position:y", 14.0, 0.4)
	await _panel_tween.finished
	if panel == _panel:
		clear_panel()


## Remove o painel atual na hora.
func clear_panel() -> void:
	_kill_panel_tween()
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	_panel_style = null
	_panel_big_check = null
	_panel_keys.clear()
	if _panel_slot != null:
		_panel_slot.modulate = Color.WHITE
		_panel_slot.position.y = 0.0


## Para a animação do painel.
func _kill_panel_tween() -> void:
	if _panel_tween != null and _panel_tween.is_valid():
		_panel_tween.kill()


## Constrói o ícone de cada tipo de painel.
func _build_icon(kind: StringName, key_text: String) -> Control:
	if String(kind).begins_with("m_"):  # Celular: ilustração do controle no lugar do teclado/mouse.
		return _build_mobile_icon(kind)
	match kind:
		&"wasd":
			var grid: GridContainer = GridContainer.new()
			grid.columns = 3
			grid.add_theme_constant_override(&"h_separation", 6)
			grid.add_theme_constant_override(&"v_separation", 4)
			var layout: Array = [
				["", &""], ["W", &"move_up"], ["", &""],
				["A", &"move_left"], ["S", &"move_down"], ["D", &"move_right"],
			]
			for entry: Array in layout:
				if (entry[1] as StringName) == &"":
					var spacer: Control = Control.new()
					spacer.custom_minimum_size = Vector2(56.0, 62.0)
					grid.add_child(spacer)
				else:
					var key: KeyCap = KeyCap.new(entry[0] as String, 56.0, 62.0)
					grid.add_child(key)
					_panel_keys[entry[1] as StringName] = key
			return grid
		&"key":
			var wide: KeyCap = KeyCap.new(key_text, maxf(80.0, 26.0 * float(key_text.length()) + 36.0), 62.0)
			wide.pulsing = true
			_panel_keys[&"key"] = wide
			return wide
		&"arrow_right":
			var arrow: KeyCap = KeyCap.new("", 62.0, 62.0)
			arrow.glyph = &"right"
			arrow.pulsing = true
			_panel_keys[&"key"] = arrow
			return arrow
		&"mouse_left":
			var left: MouseIcon = MouseIcon.new(&"left")
			return left
		&"mouse_right":
			var right: MouseIcon = MouseIcon.new(&"right")
			return right
	return Control.new()


## Ícone do celular: o controle da vez pisca/anima. Os tipos de quatro direções registram uma "tecla" por direção.
func _build_mobile_icon(kind: StringName) -> Control:
	var icon: MobileGuideIcon = MobileGuideIcon.new(kind)
	if icon.dir_keys.is_empty():
		_panel_keys[&"key"] = icon
	else:
		for action: StringName in icon.dir_keys:
			_panel_keys[action] = icon.dir_keys[action] as Control
	return icon


## Ícone do painel atual (para os testes).
func current_icon() -> Control:
	if _panel == null:
		return null
	for node: Node in _panel.find_children("*", "MobileGuideIcon", true, false):
		return node as Control
	return null


# --- Pular tutorial ---

## Conta o tempo segurando TAB e o tempo para confirmar o clique no botão.
func _update_skip(delta: float) -> void:
	if _skip_emitted:
		return
	if Input.is_physical_key_pressed(KEY_TAB):
		_skip_hold += delta
	else:
		_skip_hold = maxf(_skip_hold - delta * 2.0, 0.0)
	_skip_bar.size.x = 160.0 * clampf(_skip_hold / SKIP_HOLD, 0.0, 1.0)
	if _skip_hold >= SKIP_HOLD:
		_emit_skip()
		return
	if _skip_confirm_left > 0.0:
		_skip_confirm_left -= delta
		if _skip_confirm_left <= 0.0:
			_skip_button.text = "Pular tutorial"


## Clique no botão: o primeiro pede confirmação, o segundo (em até 3 s) pula.
func _on_skip_pressed() -> void:
	if _skip_confirm_left > 0.0:
		_emit_skip()
		return
	_skip_confirm_left = 3.0
	_skip_button.text = "Clique de novo para pular"


## Avisa que o jogador quer pular (uma única vez).
func _emit_skip() -> void:
	if _skip_emitted:
		return
	_skip_emitted = true
	skip_requested.emit()


# --- Construção ---

## Camada do efeito de tela (abaixo da interface).
func _build_post() -> void:
	_post_layer = CanvasLayer.new()
	_post_layer.layer = 4
	_post_layer.name = &"PostLayer"
	add_child(_post_layer)
	var shader: Shader = Shader.new()
	shader.code = POST_SHADER
	_post_material = ShaderMaterial.new()
	_post_material.shader = shader
	_post_material.set_shader_parameter(&"darkness", 0.0)  # Valores iniciais explícitos (os tweens leem daqui).
	_post_material.set_shader_parameter(&"vignette", 1.0)
	_post_material.set_shader_parameter(&"grain", 0.07)
	_post_material.set_shader_parameter(&"time_s", 0.0)
	_post = ColorRect.new()
	_post.name = &"Post"
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post.material = _post_material
	_post.set_anchors_preset(Control.PRESET_FULL_RECT)
	_post_layer.add_child(_post)


## Camada da interface: voz, área dos painéis e botão de pular.
func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 20
	_ui_layer.name = &"UiLayer"
	add_child(_ui_layer)
	_root = Control.new()
	_root.name = &"Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(_root)
	SafeArea.fit(_root)  # Celular: voz, painéis e "Pular tutorial" dentro da área segura.

	# Voz: grande, centralizada no alto da tela.
	_voice_wrap = Control.new()
	_voice_wrap.name = &"VoiceWrap"
	_voice_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voice_wrap.anchor_left = 0.5
	_voice_wrap.anchor_right = 0.5
	_voice_wrap.offset_left = -480.0
	_voice_wrap.offset_right = 480.0
	_voice_wrap.offset_top = 54.0
	_voice_wrap.offset_bottom = 170.0
	if Platform.is_mobile():  # Celular: a voz ocupa a faixa livre do alto (fora das barras de status e da pausa).
		_voice_wrap.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_voice_wrap.offset_left = 0.0
		_voice_wrap.offset_right = 0.0
		_voice_wrap.offset_top = 54.0
		_voice_wrap.offset_bottom = 170.0
	SafeArea.band_region(_root, SafeArea.Band.TOP, "FaixaDaVoz").add_child(_voice_wrap)
	_voice = _label("", FONT_VOICE, COLOR_VOICE)
	_voice.name = &"Voice"
	_voice.set_anchors_preset(Control.PRESET_FULL_RECT)
	_voice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_voice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_voice.add_theme_constant_override(&"outline_size", 10)
	_voice.add_theme_color_override(&"font_outline_color", Color(COLOR_GLOW, 0.35))
	_voice.add_theme_color_override(&"font_shadow_color", Color(COLOR_GLOW, 0.5))
	_voice.add_theme_constant_override(&"shadow_offset_x", 0)
	_voice.add_theme_constant_override(&"shadow_offset_y", 0)
	_voice.modulate.a = 0.0
	_voice_wrap.add_child(_voice)

	# Área do painel de comando.
	_panel_slot = Control.new()
	_panel_slot.name = &"PanelSlot"
	_panel_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_slot.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_panel_slot)
	SafeArea.fit_band(_panel_slot, SafeArea.Band.BOTTOM)  # só no celular

	# Pular tutorial (canto superior direito).
	var skip_box: VBoxContainer = VBoxContainer.new()
	skip_box.name = &"SkipBox"
	skip_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skip_box.offset_top = 14.0
	skip_box.offset_right = -16.0
	if Platform.is_mobile():  # Celular: fora do botão de pausa e do quadro de comandos (canto superior direito).
		skip_box.anchor_left = 0.77
		skip_box.anchor_right = 0.77
		skip_box.offset_right = 0.0
	skip_box.add_theme_constant_override(&"separation", 4)
	_root.add_child(skip_box)
	_skip_button = Button.new()
	_skip_button.text = "Pular tutorial"
	_skip_button.flat = true
	_skip_button.focus_mode = Control.FOCUS_NONE
	if Platform.is_mobile():  # alvo de toque de tamanho mínimo
		_skip_button.custom_minimum_size = Vector2(Platform.MIN_TOUCH * 2.0, Platform.MIN_TOUCH)
	_skip_button.add_theme_font_override(&"font", FONT)
	_skip_button.add_theme_font_size_override(&"font_size", FONT_HINT + 2)
	_skip_button.add_theme_color_override(&"font_color", Color("#8fa3b8"))
	_skip_button.add_theme_color_override(&"font_hover_color", COLOR_KEY_INK)
	_skip_button.pressed.connect(_on_skip_pressed)
	skip_box.add_child(_skip_button)
	var hold_label: Label = _label("ou segure TAB", FONT_HINT - 2, Color("#5f7288"))
	hold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hold_label.visible = not Platform.is_mobile()  # Celular não tem TAB.
	skip_box.add_child(hold_label)
	var bar_back: ColorRect = ColorRect.new()
	bar_back.visible = not Platform.is_mobile()
	bar_back.color = Color(1, 1, 1, 0.08)
	bar_back.custom_minimum_size = Vector2(160.0, 4.0)
	bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_box.add_child(bar_back)
	_skip_bar = ColorRect.new()
	_skip_bar.color = COLOR_CYAN
	_skip_bar.size = Vector2(0.0, 4.0)
	_skip_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_back.add_child(_skip_bar)


## Cria um Label com a fonte do tutorial.
func _label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override(&"font", FONT)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# --- Ícones desenhados ---

## Tecla de teclado em pixel art. Afunda e acende ao ser apertada; ganha check verde quando testada.
class KeyCap extends Control:
	var text: String = ""  # Letra ou nome da tecla.
	var glyph: StringName = &""  # `right` desenha uma seta para a direita no lugar do texto.
	var pressed: bool = false:  # Apertada agora.
		set(value):
			if value != pressed:
				pressed = value
				queue_redraw()
	var checked: bool = false:  # Já foi testada.
		set(value):
			checked = value
			queue_redraw()
	var pulsing: bool = false  # Pulsa para chamar atenção.
	var _time: float = 0.0

	func _init(label: String = "", width: float = 56.0, height: float = 62.0) -> void:
		text = label
		custom_minimum_size = Vector2(width, height)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if pulsing:
			_time += delta
			queue_redraw()

	func _draw() -> void:
		var depth: float = 6.0
		var dy: float = 4.0 if pressed else 0.0  # Afunda ao apertar.
		draw_rect(Rect2(0.0, depth, size.x, size.y - depth), TutorialUi.COLOR_KEY_SHADOW)
		var face: Rect2 = Rect2(0.0, dy, size.x, size.y - depth)
		var fill: Color = TutorialUi.COLOR_KEY_FACE
		var edge: Color = TutorialUi.COLOR_KEY_EDGE
		var ink: Color = TutorialUi.COLOR_KEY_INK
		if checked:
			fill = TutorialUi.COLOR_OK_DARK
			edge = TutorialUi.COLOR_OK
		if pressed:  # Brilho de tecla apertada.
			fill = TutorialUi.COLOR_CYAN
			edge = Color.WHITE
			ink = Color("#04121a")
		draw_rect(face, fill)
		draw_rect(face, edge, false, 2.0)
		draw_rect(Rect2(face.position + Vector2(3.0, 3.0), Vector2(face.size.x - 6.0, 2.0)), Color(1, 1, 1, 0.12))
		var center: Vector2 = face.get_center()
		if glyph == &"right":
			var arrow: PackedVector2Array = PackedVector2Array([
				center + Vector2(-12.0, -4.0), center + Vector2(2.0, -4.0), center + Vector2(2.0, -12.0),
				center + Vector2(14.0, 0.0), center + Vector2(2.0, 12.0), center + Vector2(2.0, 4.0),
				center + Vector2(-12.0, 4.0),
			])
			draw_colored_polygon(arrow, ink)
		elif not text.is_empty():
			draw_string(TutorialUi.FONT, Vector2(0.0, center.y + 9.0), text, HORIZONTAL_ALIGNMENT_CENTER,
					size.x, 32, ink)
		if pulsing:  # Anel que respira.
			var grow: float = 3.0 + 3.0 * (0.5 + 0.5 * sin(_time * 5.0))
			var ring: Color = TutorialUi.COLOR_CYAN
			ring.a = 0.8 - 0.4 * (grow - 3.0) / 3.0
			draw_rect(face.grow(grow), ring, false, 2.0)
		if checked:  # Selo verde com ✓ no canto.
			var badge: Vector2 = Vector2(size.x - 4.0, 4.0)
			draw_circle(badge, 11.0, TutorialUi.COLOR_OK)
			draw_polyline(PackedVector2Array([badge + Vector2(-5.0, 0.0), badge + Vector2(-1.0, 4.0),
					badge + Vector2(6.0, -4.0)]), Color("#06210f"), 3.0)


## Mouse em pixel art com um dos botões em destaque. O botão "aperta" de tempos em tempos.
class MouseIcon extends Control:
	var side: StringName = &"left"  # Botão em destaque: `left` ou `right`.
	var _time: float = 0.0

	func _init(button: StringName = &"left") -> void:
		side = button
		custom_minimum_size = Vector2(96.0, 112.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var body: Rect2 = Rect2(20.0, 6.0, 56.0, 98.0)
		var pressed: bool = fmod(_time, 1.3) < 0.22  # Aperta a cada 1,3 s.
		draw_rect(body.grow(4.0), Color("#05080c"))
		draw_rect(body, TutorialUi.COLOR_KEY_FACE)
		draw_rect(body, TutorialUi.COLOR_KEY_EDGE, false, 2.0)
		var left_btn: Rect2 = Rect2(body.position + Vector2(2.0, 2.0), Vector2(26.0, 42.0))
		var right_btn: Rect2 = Rect2(body.position + Vector2(28.0, 2.0), Vector2(26.0, 42.0))
		var active: Rect2 = left_btn if side == &"left" else right_btn
		var glow: float = 0.5 + 0.5 * sin(_time * 6.0)
		var gold: Color = TutorialUi.COLOR_GOLD
		draw_rect(active.grow(3.0 + 2.0 * glow), Color(gold, 0.35), false, 2.0)  # Aura pulsando.
		draw_rect(active, Color("#fff2b0") if pressed else gold)
		draw_rect(left_btn, TutorialUi.COLOR_KEY_EDGE, false, 2.0)
		draw_rect(right_btn, TutorialUi.COLOR_KEY_EDGE, false, 2.0)
		draw_rect(Rect2(body.position + Vector2(23.0, 14.0), Vector2(8.0, 14.0)), Color("#0e141c"))  # Rodinha.
		if pressed:  # Ondinha de clique.
			var c: Vector2 = active.get_center()
			draw_arc(c, 18.0, 0.0, TAU, 20, Color(1, 1, 0.8, 0.7), 2.0)


## Check verde grande que aparece ao concluir o painel.
class _BigCheck extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(34.0, 34.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_circle(size * 0.5, 16.0, TutorialUi.COLOR_OK)
		draw_polyline(PackedVector2Array([Vector2(9.0, 18.0), Vector2(15.0, 24.0), Vector2(26.0, 10.0)]),
				Color("#06210f"), 4.0)
