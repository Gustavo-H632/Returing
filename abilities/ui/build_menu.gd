class_name BuildMenu
extends CanvasLayer
## Menu "SUA BUILD": mostra, só para leitura, o nível, o XP e as habilidades que o jogador tem,
## com os slots ainda bloqueados e os efeitos ativos. Abre ao clicar ou tocar no amuleto da HUD de
## cooldown. Não escolhe, troca nem remove nada: quem abre e fecha (AbilitiesUI) cuida da pausa.

## Pedido de fechar (clique ou toque fora, `ui_cancel` ou o botão "Fechar").
signal close_requested

const CARD_SEPARATION: int = Palette.UNIT * 3  # Espaço entre as cartas.
const BOX_SEPARATION: int = Palette.UNIT  # Espaço entre os blocos do menu.
## Quantos slots de habilidade a run tem (um por nível, até o nível máximo).
const SLOT_COUNT: int = 3
const PLACEHOLDER_SIZE: Vector2 = Vector2(240.0, 220.0)  # Tamanho do espaço de um slot ainda vazio.
const XP_BAR_SIZE: Vector2 = Vector2(320.0, 64.0)  # Tamanho da barra de XP.
const XP_BAR_AREA: Vector2 = Vector2(320.0, 64.0)  # Área reservada para a barra de XP.
## Atraso (s) de CARD_STAGGER entre cartas e tempo (s) em que o clique fora ainda não fecha.
const CARD_STAGGER: float = 0.06
const CLOSE_GUARD_TIME: float = 0.25  # Tempo logo após abrir em que o clique ainda não fecha.

var _root: Control = null  # Raiz de tudo o que o menu desenha.
var _box: VBoxContainer = null  # Coluna central com o conteúdo.
var _subtitle: Label = null  # Texto "Nível X de Y".
var _xp_holder: Control = null  # Área da barra de XP.
var _cards_box: HBoxContainer = null  # Linha com as cartas.
var _active_title: Label = null  # Título "ATIVOS AGORA".
var _active_list: VBoxContainer = null  # Lista de efeitos ativos.
var _close_button: Button = null  # Botão de fechar.

var _cards: Array[LevelUpCard] = []  # Cartas atuais.
var _is_open: bool = false  # True com o menu aberto.
var _accepting_close: bool = false  # True quando o clique já pode fechar.


## Monta o menu e o deixa escondido; roda com o jogo pausado.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # roda com o jogo pausado
	_build()  # Constrói todos os nós por código.
	visible = false


## Diz se o menu está aberto.
func is_open() -> bool:
	return _is_open


## Abre o menu. `focus_id`: habilidade clicada, que começa com foco/destaque.
## Abre o menu: mostra nível, barra de XP, cartas das habilidades (só leitura), slots vazios ou bloqueados e efeitos ativos.
func open(abilities: AbilityComponent, experience: ExperienceComponent, focus_id: StringName) -> void:
	_clear()  # Limpa o conteúdo anterior.
	var level: int = RunState.level  # Nível atual.
	_subtitle.text = "Nível %d de %d" % [level, experience.get_max_level()]  # Subtítulo com o nível.
	_fill_xp(experience)  # Barra de XP.
	var owned: Array[AbilityData] = abilities.abilities  # Habilidades que o jogador tem.
	var focus_card: LevelUpCard = null  # Carta que começa em foco.
	for i: int in SLOT_COUNT:  # Um slot por nível.
		if i < owned.size():  # Slot com habilidade.
			var card: LevelUpCard = LevelUpCard.new()  # Cria a carta.
			_cards_box.add_child(card)
			card.setup(owned[i], false, true)  # só leitura
			card.play_entrance(float(i) * CARD_STAGGER)  # Entrada animada.
			_cards.append(card)  # Guarda a carta.
			if owned[i].id == focus_id:  # A carta clicada recebe o foco.
				focus_card = card
		else:  # Slot sem habilidade.
			var unlock_level: int = i + 1  # Nível em que o slot desbloqueia.
			_cards_box.add_child(_make_placeholder(
					"Slot vazio" if level >= unlock_level else "Desbloqueia no nível %d" % unlock_level))
	_fill_active(abilities, owned)  # Lista de efeitos ativos.
	_is_open = true  # Marca como aberto.
	_accepting_close = false  # O primeiro toque ainda não fecha.
	visible = true  # Mostra o menu.
	_root.modulate.a = 0.0  # Começa transparente.
	var fade: Tween = UiTween.create(self)  # Aparece com fade.
	fade.tween_property(_root, ^"modulate:a", 1.0, Palette.FADE_TIME)
	if focus_card != null:  # Foco na carta clicada.
		focus_card.grab_focus.call_deferred()
	elif not _cards.is_empty():  # Senão na primeira carta.
		_cards[0].grab_focus.call_deferred()
	else:  # Senão no botão de fechar.
		_close_button.grab_focus.call_deferred()
	# o toque que abriu o menu não pode fechá-lo logo em seguida
	# Espera um pouco antes de aceitar o clique de fechar.
	await get_tree().create_timer(CLOSE_GUARD_TIME, true, false, true).timeout
	_accepting_close = _is_open  # Só aceita se ainda estiver aberto.


## Fecha o menu e apaga o conteúdo.
func close() -> void:
	_is_open = false  # Marca como fechado.
	_accepting_close = false
	visible = false
	_clear()


## Remove os nós de cartas, efeitos ativos e barra de XP.
func _clear() -> void:
	for child: Node in _cards_box.get_children():  # Cartas.
		child.queue_free()
	_cards.clear()  # Esvazia a lista.
	for child: Node in _active_list.get_children():  # Efeitos ativos.
		child.queue_free()
	for child: Node in _xp_holder.get_children():  # Barra de XP.
		child.queue_free()


# --- Conteúdo ---

## Cria uma barra de XP horizontal (a mesma da HUD) sem animação e com os valores da run.
## `XpBar` horizontal reaproveitada no cabeçalho (sem animação: já abre no valor certo).
func _fill_xp(experience: ExperienceComponent) -> void:
	# Carrega a cena da barra.
	var bar: XpBar = (load("res://ui/hud/xp_bar.tscn") as PackedScene).instantiate() as XpBar
	bar.orientation = XpBar.BarLayout.HORIZONTAL  # Versão horizontal.
	bar.auto_bind = false  # Não escuta o EventBus.
	bar.follow_health_block = false  # Não acompanha o bloco de vida.
	_xp_holder.add_child(bar)  # Entra no menu.
	bar.set_anchors_preset(Control.PRESET_TOP_LEFT)  # Posição.
	bar.position = Vector2(0.0, (XP_BAR_AREA.y - XP_BAR_SIZE.y) * 0.5)  # Centraliza na vertical.
	bar.size = XP_BAR_SIZE  # Tamanho.
	var floor_xp: int = experience.get_level_floor()  # XP onde o nível atual começou.
	# Mostra os valores já prontos.
	bar.set_xp_instant(RunState.xp - floor_xp, experience.get_next_threshold() - floor_xp, RunState.level,
			experience.is_max_level())


## Cria um espaço vazio com texto (slot ainda não usado ou bloqueado).
func _make_placeholder(text: String) -> Control:
	var panel: PanelContainer = PanelContainer.new()  # Painel do slot.
	panel.custom_minimum_size = PLACEHOLDER_SIZE  # Tamanho mínimo.
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Não captura cliques.
	var label: Label = Label.new()  # Texto.
	label.text = text  # Texto do slot.
	label.theme_type_variation = &"HintLabel"  # Estilo de dica.
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER  # Centraliza.
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # Quebra de linha.
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL  # Ocupa a altura.
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)  # Entra no painel.
	return panel  # Devolve o painel.


## "Ativos agora": efeitos com duração em andamento e o tempo que falta (calculado do cooldown).
## "Ativos agora": lista os efeitos com duração em andamento e o tempo que falta (calculado a partir da recarga).
func _fill_active(abilities: AbilityComponent, owned: Array[AbilityData]) -> void:
	var lines: PackedStringArray = []  # Linhas de texto.
	for data: AbilityData in owned:  # Cada habilidade do jogador.
		var left: float = abilities.get_cooldown_left(data.id)  # Recarga restante.
		var elapsed: float = data.cooldown - left  # Tempo desde a ativação.
		if data.duration > 0.0 and left > 0.0 and elapsed < data.duration:  # Efeito com duração ainda ativo.
			# Linha: nome e tempo restante.
			lines.append("%s  ·  %.1f s" % [data.display_name, data.duration - elapsed])
	_active_title.visible = not lines.is_empty()  # O título só aparece se há efeitos.
	for line: String in lines:  # Uma etiqueta por linha.
		var label: Label = Label.new()
		label.text = line
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_active_list.add_child(label)  # Entra na lista.


# --- Construção ---

## Constrói todos os nós do menu por código: fundo escurecido, título, subtítulo, barra de XP, cartas, efeitos ativos e botão de fechar.
func _build() -> void:
	_root = Control.new()  # Raiz que captura o clique.
	_root.mouse_filter = Control.MOUSE_FILTER_STOP  # o clique não vaza para o jogo
	_root.theme = Palette.load_theme()  # Tema do jogo.
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.gui_input.connect(_on_root_gui_input)  # Clique fora do conteúdo fecha o menu.

	var dim: ColorRect = ColorRect.new()  # Película escura.
	dim.color = Palette.dim_color()
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center: CenterContainer = CenterContainer.new()  # Centraliza o conteúdo.
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_box = VBoxContainer.new()  # Coluna do conteúdo.
	_box.add_theme_constant_override(&"separation", BOX_SEPARATION)
	_box.mouse_filter = Control.MOUSE_FILTER_STOP  # clique dentro do conteúdo não fecha o menu
	center.add_child(_box)

	var title_row: HBoxContainer = HBoxContainer.new()  # Linha do título.
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(title_row)
	var title: Label = Label.new()  # Título.
	title.theme_type_variation = &"PanelTitleLabel"
	title.text = "SUA BUILD"
	title_row.add_child(title)

	_subtitle = Label.new()  # Subtítulo.
	_subtitle.theme_type_variation = &"HintLabel"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_subtitle)

	_xp_holder = Control.new()  # Área da barra de XP.
	_xp_holder.custom_minimum_size = XP_BAR_AREA
	_xp_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_xp_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_xp_holder)

	_cards_box = HBoxContainer.new()  # Linha das cartas.
	_cards_box.add_theme_constant_override(&"separation", CARD_SEPARATION)
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_cards_box)

	_active_title = Label.new()  # Título dos efeitos ativos.
	_active_title.text = "ATIVOS AGORA"
	_active_title.theme_type_variation = &"HintLabel"
	_active_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_active_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_active_title)
	_active_list = VBoxContainer.new()  # Lista dos efeitos ativos.
	_active_list.add_theme_constant_override(&"separation", 2)
	_active_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_active_list)

	_close_button = PixelButton.new()  # Botão de fechar.
	_close_button.text = "Fechar"
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close_button.custom_minimum_size = Vector2(Palette.UNIT * 20, 0.0)
	_close_button.pressed.connect(_request_close)  # Ao apertar, pede para fechar.
	_box.add_child(_close_button)


# --- Interação ---

## Esc (ui_cancel) também fecha o menu.
func _input(event: InputEvent) -> void:
	if _is_open and event.is_action_pressed(&"ui_cancel"):  # Só se estiver aberto.
		get_viewport().set_input_as_handled()  # Consome a tecla.
		_request_close()  # Pede para fechar.


## Clique ou toque fora do conteúdo fecha o menu (o clique dentro é do conteúdo).
## Clique fora do conteúdo fecha o menu (o clique dentro é do conteúdo).
func _on_root_gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:  # Só clique esquerdo.
		return
	if not _accepting_close:  # Ainda dentro do tempo de proteção.
		return
	if _box.get_global_rect().has_point(click.global_position):  # Clique dentro do conteúdo: ignora.
		return
	_request_close()  # Fora do conteúdo: fecha.


## Emite o pedido de fechar, se o menu está aberto.
func _request_close() -> void:
	if _is_open:  # Só se está aberto.
		close_requested.emit()  # Avisa quem abre e fecha o menu.
