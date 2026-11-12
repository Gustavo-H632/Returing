class_name DefenseHud
extends CanvasLayer
## HUD da fase de defesa: barras do portal (vida e carga, em PNG), contador da wave e o aviso de início de wave.
## Visual: PNGs de `assets/defesa/` + o tema e a fonte do projeto (main_theme / VT323). Nada é desenhado por código.

const THEME: Theme = preload("res://themes/main_theme.tres")
const TEX_FRAME: Texture2D = preload("res://assets/defesa/barra_fundo.png")
const TEX_HP: Texture2D = preload("res://assets/defesa/barra_hp.png")
const TEX_HP_LOW: Texture2D = preload("res://assets/defesa/barra_hp_baixo.png")
const TEX_CHARGE: Texture2D = preload("res://assets/defesa/barra_carga.png")
const TEX_READY: Texture2D = preload("res://assets/defesa/barra_pronto.png")

# ===== BALANCEAMENTO / VISUAL =====
const LAYER_INDEX: int = 9  # Logo abaixo da HUD do projeto (10).
const TOP_MARGIN: float = 14.0
const BAR_SCALE: float = 1.0  # Os PNGs já estão no tamanho de uso (240 x 22).
const LOW_HP_RATIO: float = 0.35  # Abaixo disso a barra de vida troca de cor.
const HINT_TIME: float = 3.5  # Tempo (s) de uma dica na tela.
const BANNER_TIME: float = 1.8  # Tempo (s) do aviso de wave na tela.
const FONT_LABEL: int = 24
const FONT_HINT: int = 32
const FONT_BANNER: int = 64
const FONT_BANNER_SUB: int = 28
const READY_TEXT: String = "PORTAL PRONTO - ENTRE NELE!"
## Nomes mostrados no aviso de wave (chave da tabela -> nome).
const KIND_NAMES: Dictionary = {"drone": "Drones", "robo": "Atiradores", "tank": "Tanks"}

var _hp_bar: TextureProgressBar = null
var _charge_bar: TextureProgressBar = null
var _wave_label: Label = null
var _hint: Label = null
var _hint_tween: Tween = null
var _banner: Panel = null
var _banner_title: Label = null
var _banner_sub: Label = null
var _banner_tween: Tween = null


func _init() -> void:
	layer = LAYER_INDEX


var _banner_host: Control = null  # Celular: faixa livre onde o aviso de wave aparece.


func _ready() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = THEME
	add_child(root)
	SafeArea.fit(root)  # Celular: wave, aviso e barras dentro da área segura.

	var box: VBoxContainer = VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.offset_left = -TEX_FRAME.get_width() * 0.5
	box.offset_right = TEX_FRAME.get_width() * 0.5
	box.offset_top = TOP_MARGIN
	box.add_theme_constant_override(&"separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Celular: barras do portal, wave e aviso ficam na faixa livre do alto (fora das barras de status e da pausa).
	var top: Control = SafeArea.band_region(root, SafeArea.Band.TOP)
	top.add_child(box)
	_hp_bar = _make_bar(box, "PORTAL", TEX_HP)
	_charge_bar = _make_bar(box, "CARGA", TEX_CHARGE)
	_wave_label = _make_label(FONT_LABEL, Palette.ACCENT)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_wave_label)

	_hint = _make_label(FONT_HINT, Palette.TEXT)
	_hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint.offset_top = TOP_MARGIN + 100.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate.a = 0.0
	if Platform.is_mobile():
		_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(_hint)

	_banner = Panel.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.offset_left = -300.0
	_banner.offset_right = 300.0
	_banner.offset_top = -150.0
	_banner.offset_bottom = -40.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	if Platform.is_mobile():  # Celular: o aviso de wave ocupa a faixa livre entre o joystick esquerdo e os botões da direita.
		_banner.anchor_left = 0.0
		_banner.anchor_right = 1.0
		_banner.offset_left = 0.0
		_banner.offset_right = 0.0
		_banner_host = SafeArea.band_region(root, SafeArea.Band.BOTTOM, "FaixaDoAviso")
		_banner_host.add_child(_banner)
	else:
		root.add_child(_banner)
	_banner_title = _make_label(FONT_BANNER, Palette.ACCENT)
	_banner_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner_title.offset_top = 6.0
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_title)
	_banner_sub = _make_label(FONT_BANNER_SUB, Palette.TEXT)
	_banner_sub.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_banner_sub.offset_top = -44.0
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_sub)
	set_wave(0)


## Atualiza a barra de vida do portal.
func set_portal_hp(hp: int, hp_max: int) -> void:
	_hp_bar.max_value = float(hp_max)
	_hp_bar.value = float(hp)
	_hp_bar.texture_progress = TEX_HP_LOW if float(hp) / float(maxi(hp_max, 1)) <= LOW_HP_RATIO else TEX_HP


## Atualiza a barra de carga (0 a 1).
func set_charge(ratio: float) -> void:
	_charge_bar.value = ratio * 100.0


## Portal pronto: barra verde e aviso fixo.
func set_ready() -> void:
	_charge_bar.texture_progress = TEX_READY
	_charge_bar.value = 100.0
	show_hint(READY_TEXT, 0.0)


## Número da wave atual e inimigos vivos.
func set_wave(number: int, enemies_left: int = 0) -> void:
	_wave_label.text = "WAVE %d  -  INIMIGOS %d" % [number, enemies_left]


## Mostra uma dica por `seconds` segundos (0 = fica até a próxima).
func show_hint(text: String, seconds: float = HINT_TIME) -> void:
	_hint.text = text
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint.modulate.a = 1.0
	if seconds > 0.0:
		_hint_tween = create_tween()
		_hint_tween.tween_interval(seconds)
		_hint_tween.tween_property(_hint, "modulate:a", 0.0, 0.5)


## Aviso de início de wave ("WAVE 2" + o que vem), por BANNER_TIME segundos.
func show_wave_banner(number: int, counts: Dictionary) -> void:
	_banner_title.text = "WAVE %d" % number
	var parts: PackedStringArray = []
	for kind: Variant in KIND_NAMES:
		if counts.has(kind) and int(counts[kind]) > 0:
			parts.append("%s %d" % [KIND_NAMES[kind], int(counts[kind])])
	_banner_sub.text = "  -  ".join(parts)
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_interval(maxf(BANNER_TIME - 0.65, 0.1))
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.4)


## Texto atual da dica e do aviso (usados nos testes).
func get_hint_text() -> String:
	return _hint.text


func get_banner_text() -> String:
	return _banner_title.text


func _make_label(size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Palette.BG)
	label.add_theme_constant_override(&"outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Barra de PNG (moldura + preenchimento) com um rótulo por cima.
func _make_bar(parent: Control, caption: String, fill: Texture2D) -> TextureProgressBar:
	var bar: TextureProgressBar = TextureProgressBar.new()
	bar.texture_under = TEX_FRAME
	bar.texture_progress = fill
	bar.texture_progress_offset = Vector2(4.0, 4.0)
	bar.nine_patch_stretch = false
	bar.max_value = 100.0
	bar.value = 0.0
	bar.custom_minimum_size = TEX_FRAME.get_size() * BAR_SCALE
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label: Label = _make_label(18, Palette.TEXT)
	label.text = caption
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_constant_override(&"outline_size", 4)
	bar.add_child(label)
	parent.add_child(bar)
	return bar
