class_name TutorialUpgradeMenu
extends CanvasLayer
## Aba de melhorias do tutorial. Mostra uma melhoria já conhecida e a nova melhoria especial "Saída"
## (dourada, com partículas). O cursor começa na anterior; apertar a seta para a DIREITA uma vez
## seleciona "Saída" e avisa o tutorial. Usa as mesmas cartas do menu de level-up do jogo.

## O jogador selecionou "Saída".
signal exit_selected

## Habilidade mostrada ao lado da "Saída" (a "melhoria anterior").
const PREVIOUS_ABILITY: AbilityData = preload("res://abilities/data/passo_agil.tres")
## Tempo (s) em que a entrada é ignorada ao abrir (evita selecionar sem querer).
const INPUT_DELAY: float = 0.7
const GOLD: Color = Color("#e8c15a")
const GOLD_LIGHT: Color = Color("#fff0b0")
## Desenho do ícone da "Saída" (16 x 16): `o` = porta dourada, `a` = seta clara.
const EXIT_ICON_ROWS: PackedStringArray = [
	"................",
	"..oooooooo......",
	"..o......o......",
	"..o......o......",
	"..o......o......",
	"..o......o..a...",
	"..o......o..aa..",
	"..o..aaaaaaaaaa.",
	"..o..aaaaaaaaaa.",
	"..o......o..aa..",
	"..o......o..a...",
	"..o......o......",
	"..o......o......",
	"..o......o......",
	"..oooooooo......",
	"................",
]

var sfx: TutorialSfx = null  # Sons (o tutorial entrega pronto).
var exit_ability: AbilityData = null  # Dados da melhoria "Saída".

var _root: Control = null  # Raiz de tudo que o menu desenha.
var _content: Control = null  # Bloco que desliza ao abrir.
var _cards: Array[LevelUpCard] = []  # [anterior, Saída].
var _sparkles: _Sparkles = null  # Partículas douradas sobre a "Saída".
var _arrow_key: TutorialUi.KeyCap = null  # Tecla → pulsando.
var _open: bool = false  # Menu aberto.
var _armed: bool = false  # Já aceita a seta (passou o atraso de proteção).
var _done: bool = false  # "Saída" já foi selecionada.


## Monta o menu e o deixa escondido.
func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	exit_ability = _make_exit_ability()
	_build()
	visible = false


## Diz se o menu está aberto.
func is_open() -> bool:
	return _open


## Abre o menu deslizando de baixo com fade. Devolve quando as cartas já podem ser usadas.
func open() -> void:
	_open = true
	_armed = false
	_done = false
	visible = true
	_content.modulate.a = 0.0
	_content.position.y = 90.0
	if sfx != null:
		sfx.play(&"menu_open")
	var tween: Tween = UiTween.create(self).set_parallel(true)
	tween.tween_property(_content, ^"modulate:a", 1.0, 0.35)
	tween.tween_property(_content, ^"position:y", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i: int in _cards.size():  # Entrada escalonada das cartas.
		_cards[i].play_entrance(0.12 * float(i) + 0.1)
	await get_tree().create_timer(INPUT_DELAY, true, false, true).timeout
	if not _open:
		return
	_cards[0].grab_focus()  # O cursor começa na melhoria anterior.
	_armed = true


## Some com fade (despedida) e fecha.
func fade_out(time: float) -> void:
	var tween: Tween = UiTween.create(self)
	tween.tween_property(_root, ^"modulate:a", 0.0, time)
	await tween.finished
	close()


## Fecha o menu.
func close() -> void:
	_open = false
	visible = false


## Qual carta tem o cursor agora: 0 = anterior, 1 = Saída, -1 = nenhuma.
func focused_index() -> int:
	for i: int in _cards.size():
		if _cards[i].has_focus():
			return i
	return -1


## A seta para a direita (uma vez) move o cursor para "Saída" e a ativa.
func _input(event: InputEvent) -> void:
	if not _open or not _armed or _done:
		return
	if event.is_action_pressed(&"ui_right") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_select_exit()
	elif Platform.is_mobile() and _is_tap_on_exit(event):  # Celular: toque na carta "Saída".
		get_viewport().set_input_as_handled()
		_select_exit()


## True se o evento é um toque (ou clique do mouse na simulação) em cima da carta "Saída".
func _is_tap_on_exit(event: InputEvent) -> bool:
	var pos: Vector2 = Vector2.ZERO
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed 			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pos = (event as InputEventMouseButton).position
	else:
		return false
	return _cards[1].get_global_rect().grow(24.0).has_point(pos)


## Move o cursor para "Saída", dá o destaque dourado e avisa o tutorial.
func _select_exit() -> void:
	_done = true
	_cards[1].grab_focus()
	_arrow_key.pressed = true  # A tecla afunda.
	_arrow_key.checked = true
	_sparkles.burst()
	if sfx != null:
		sfx.play(&"select")
	await get_tree().create_timer(0.8, true, false, true).timeout  # Deixa o jogador ver a seleção.
	exit_selected.emit()


## Cria os dados da melhoria "Saída" (só existe no tutorial; não entra no catálogo do jogo).
func _make_exit_ability() -> AbilityData:
	var data: AbilityData = AbilityData.new()
	data.id = &"saida"
	data.display_name = "Saída"
	data.description = "Deixa o treinamento e segue para a Fase 1."
	data.sequence = [AbilityData.Dir.RIGHT]
	data.cooldown = 0.0
	data.duration = 0.0
	data.rarity = AbilityData.Rarity.LENDARIA  # Moldura e amuleto dourados.
	data.icon = _make_exit_icon()
	return data


## Desenha o ícone da "Saída" pixel a pixel.
func _make_exit_icon() -> ImageTexture:
	var image: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y: int in EXIT_ICON_ROWS.size():
		var row: String = EXIT_ICON_ROWS[y]
		for x: int in row.length():
			match row[x]:
				"o":
					image.set_pixel(x, y, GOLD)
				"a":
					image.set_pixel(x, y, GOLD_LIGHT)
	return ImageTexture.create_from_image(image)


## Constrói o fundo, o título, as cartas, as partículas e o painel de instrução.
func _build() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = Palette.load_theme()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim: ColorRect = ColorRect.new()
	dim.color = Palette.dim_color()
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_content)
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", Palette.UNIT * 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)

	var title: Label = Label.new()
	title.text = "MELHORIAS"
	title.theme_type_variation = &"PanelTitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", Palette.UNIT * 3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	for data: AbilityData in [PREVIOUS_ABILITY, exit_ability]:
		var card: LevelUpCard = LevelUpCard.new()
		row.add_child(card)
		card.setup(data, false, true)  # Carta de consulta: sem escolha por clique.
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE  # O mouse não muda o cursor.
		_cards.append(card)

	box.add_child(_build_instruction())

	_sparkles = _Sparkles.new()
	_sparkles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparkles.card = _cards[1]
	_content.add_child(_sparkles)
	_sparkles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Painel: "Aperte a seta para a DIREITA uma vez..." com a tecla → pulsando.
func _build_instruction() -> Control:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = TutorialUi.COLOR_PANEL
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_content_margin_all(14.0)
	panel.add_theme_stylebox_override(&"panel", style)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 16)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(line)

	var arrow_text: String = " (→)" if TutorialUi.FONT.has_char(0x2192) else ""  # A fonte pode não ter a seta.
	var label: Label = Label.new()
	label.text = "Aperte a seta para a DIREITA%s uma vez\npara selecionar 'Saída'" % arrow_text
	if Platform.is_mobile():  # Celular não tem seta: toca na carta.
		label.text = "Toque na carta 'Saída'\npara selecioná-la"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", TutorialUi.FONT)
	label.add_theme_font_size_override(&"font_size", TutorialUi.FONT_PANEL)
	label.add_theme_color_override(&"font_color", TutorialUi.COLOR_KEY_INK)
	line.add_child(label)

	_arrow_key = TutorialUi.KeyCap.new("", 62.0, 62.0)
	_arrow_key.glyph = &"right"
	_arrow_key.pulsing = true
	_arrow_key.visible = not Platform.is_mobile()  # celular: sem tecla, só o toque na carta
	line.add_child(_arrow_key)
	return panel


## Fagulhas douradas que sobem em volta da carta "Saída" (e uma explosão ao selecionar).
class _Sparkles extends Control:
	var card: Control = null  # Carta ao redor da qual as fagulhas aparecem.
	var _dots: Array[Dictionary] = []  # Cada fagulha: pos, vel, life, max, size.
	var _spawn_clock: float = 0.0

	func _process(delta: float) -> void:
		if card == null or not is_visible_in_tree():
			return
		_spawn_clock += delta
		while _spawn_clock >= 0.05:  # ~20 fagulhas por segundo.
			_spawn_clock -= 0.05
			var rect: Rect2 = card.get_global_rect()
			var x: float = rect.position.x + randf() * rect.size.x
			var y: float = rect.end.y - randf() * rect.size.y * 0.3
			_dots.append({"pos": Vector2(x, y), "vel": Vector2(randf_range(-8.0, 8.0), randf_range(-60.0, -25.0)),
					"life": 1.4, "max": 1.4, "size": randf_range(1.5, 3.0)})
		var i: int = _dots.size() - 1
		while i >= 0:
			var d: Dictionary = _dots[i]
			d["life"] = (d["life"] as float) - delta
			d["pos"] = (d["pos"] as Vector2) + (d["vel"] as Vector2) * delta
			if (d["life"] as float) <= 0.0:
				_dots.remove_at(i)
			i -= 1
		queue_redraw()

	## Explosão de fagulhas do centro da carta.
	func burst() -> void:
		if card == null:
			return
		var center: Vector2 = card.get_global_rect().get_center()
		for n: int in 40:
			var angle: float = randf() * TAU
			_dots.append({"pos": center, "vel": Vector2.from_angle(angle) * randf_range(60.0, 260.0),
					"life": 0.9, "max": 0.9, "size": randf_range(2.0, 4.0)})

	func _draw() -> void:
		for d: Dictionary in _dots:
			var t: float = (d["life"] as float) / (d["max"] as float)
			var color: Color = TutorialUpgradeMenu.GOLD_LIGHT
			color.a = t
			draw_circle(d["pos"] as Vector2, (d["size"] as float) * (0.5 + t * 0.5), color)
