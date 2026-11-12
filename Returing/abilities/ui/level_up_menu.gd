class_name LevelUpMenu
extends CanvasLayer
## Menu de level-up: fundo escurecido, título e 3 cartas lado a lado.
## Funciona com a árvore pausada. Escolher uma lendária pede confirmação listando o que será perdido.
## Não conhece o Player: quem abre (AbilitiesUI) aplica a escolha.

## Uma carta foi escolhida (e, se lendária, confirmada).
signal ability_chosen(ability: AbilityData)
## O jogador preferiu manter as habilidades que tem (só quando as 3 cartas são lendárias).
signal kept_current

const CARD_SEPARATION: int = Palette.UNIT * 3  # Espaço entre as cartas.
const BOX_SEPARATION: int = Palette.UNIT * 3  # Espaço entre os blocos do menu.
const CONFIRM_WIDTH: float = 460.0  # Largura do texto de confirmação.
## Atraso (s) entre o aparecimento de uma carta e a seguinte.
const CARD_STAGGER: float = 0.08

@export_group("Entrada")
## Tempo (s) em que toda entrada é ignorada ao abrir (evita escolher sem querer em combate).
@export_range(0.0, 3.0, 0.05) var input_delay: float = 0.5
## Duração (s) do fade-in.
@export_range(0.0, 2.0, 0.05) var fade_time: float = 0.25

var _root: Control = null  # Raiz de tudo o que o menu desenha.
var _title: Label = null  # Título do menu.
var _cards_box: HBoxContainer = null  # Linha com as cartas.
var _keep_button: Button = null  # Botão "Manter minhas habilidades".
var _confirm: Control = null  # Painel de confirmação da lendária.
var _confirm_text: Label = null  # Texto da confirmação.
var _confirm_ok: Button = null  # Botão de confirmar.
var _confirm_back: Button = null  # Botão de voltar.

var _cards: Array[LevelUpCard] = []  # Cartas atuais.
var _owned: Array[AbilityData] = []  # Habilidades que o jogador já tem (para listar o que será perdido).
var _pending: AbilityData = null  # Carta lendária aguardando confirmação.
var _is_open: bool = false  # True com o menu aberto.
var _locked: bool = false  # True logo ao abrir (entrada ignorada).
var _confirming: bool = false  # True durante o passo de confirmação.


## Monta o menu e o deixa escondido; roda com o jogo pausado.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # roda com o jogo pausado
	_build()  # Constrói os nós por código.
	visible = false


## Diz se o menu está aberto.
func is_open() -> bool:
	return _is_open


## Abre o menu com as cartas sorteadas. `owned` são as habilidades atuais (para o aviso de perda).
## Abre o menu com as cartas sorteadas. `owned` são as habilidades atuais (usadas no aviso de perda da lendária).
func open(level: int, offer: Array[AbilityData], owned: Array[AbilityData]) -> void:
	_clear_cards()  # Remove as cartas anteriores.
	_owned = owned.duplicate()  # Guarda as habilidades atuais.
	_pending = null  # Nenhuma carta pendente.
	_confirming = false  # Fora do passo de confirmação.
	_confirm.visible = false  # Esconde a confirmação.
	_title.text = "NÍVEL %d — ESCOLHA UMA HABILIDADE" % level  # Título com o nível.
	var all_legendary: bool = not offer.is_empty()  # Todas lendárias? (começa verdadeiro se há cartas).
	var has_legendary: bool = false  # Tem alguma lendária?
	for data: AbilityData in offer:  # Procura lendárias.
		if data.rarity == AbilityData.Rarity.LENDARIA:  # Achou uma.
			has_legendary = true
	for data: AbilityData in offer:  # Cria uma carta por habilidade.
		var card: LevelUpCard = LevelUpCard.new()
		_cards_box.add_child(card)  # Entra na linha.
		card.setup(data, has_legendary)  # Reserva o espaço do aviso se há lendária.
		card.selected.connect(_on_card_selected)  # Escolher a carta avisa o menu.
		_cards.append(card)  # Guarda a carta.
		if data.rarity != AbilityData.Rarity.LENDARIA:  # Se alguma não é lendária...
			all_legendary = false  # ...então não são todas lendárias.
	# As 3 cartas lendárias: a perda de tudo nunca é obrigatória.
	_keep_button.visible = all_legendary  # O botão "Manter" só existe quando as três são lendárias.
	_set_focusable(true)  # Cartas focáveis.

	for i: int in _cards.size():  # Entrada animada de cada carta.
		_cards[i].play_entrance(float(i) * CARD_STAGGER)

	_is_open = true  # Marca como aberto.
	_locked = true  # Entrada travada por um instante.
	visible = true  # Mostra o menu.
	_root.modulate.a = 0.0  # Começa transparente.
	var tween: Tween = UiTween.create(self)  # Aparece com fade.
	tween.tween_property(_root, ^"modulate:a", 1.0, fade_time)
	await get_tree().create_timer(input_delay, true, false, true).timeout  # Espera o atraso de proteção.
	_locked = false  # Libera a entrada.
	if _is_open and not _cards.is_empty():  # Dá o foco à primeira carta.
		_cards[0].grab_focus()


## Fecha o menu e apaga as cartas.
func close() -> void:
	_is_open = false  # Marca como fechado.
	_confirming = false
	visible = false
	_clear_cards()


## Remove as cartas da cena.
func _clear_cards() -> void:
	for card: LevelUpCard in _cards:  # Cada carta.
		if is_instance_valid(card):  # Só se ainda existe.
			card.queue_free()
	_cards.clear()


# --- Construção ---

## Constrói por código todos os nós do menu: fundo escurecido, título, cartas e botão de manter.
func _build() -> void:
	_root = Control.new()  # Raiz que captura cliques.
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = Palette.load_theme()  # tema dos menus só nesta raiz
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim: ColorRect = ColorRect.new()  # Película escura.
	dim.color = Palette.dim_color()
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center: CenterContainer = CenterContainer.new()  # Centraliza o conteúdo.
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box: VBoxContainer = VBoxContainer.new()  # Coluna do conteúdo.
	box.add_theme_constant_override(&"separation", BOX_SEPARATION)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)

	# Título
	var title_row: HBoxContainer = HBoxContainer.new()  # Linha do título.
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title_row)
	_title = Label.new()  # Título.
	_title.theme_type_variation = &"PanelTitleLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_row.add_child(_title)

	_cards_box = HBoxContainer.new()  # Linha das cartas.
	_cards_box.add_theme_constant_override(&"separation", CARD_SEPARATION)
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_cards_box)

	_keep_button = PixelButton.new()  # Botão "Manter minhas habilidades".
	_keep_button.text = "Manter minhas habilidades"
	_keep_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_keep_button.pressed.connect(_on_keep_pressed)
	_keep_button.visible = false
	box.add_child(_keep_button)

	_build_confirm()  # Cria também o passo de confirmação.


## Passo de confirmação da lendária (lista o que será perdido).
## Cria o passo de confirmação da escolha lendária (lista o que será perdido).
func _build_confirm() -> void:
	_confirm = Control.new()  # Camada da confirmação.
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_confirm)
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.visible = false

	var dim: ColorRect = ColorRect.new()  # Película escura.
	dim.color = Palette.dim_color()
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center: CenterContainer = CenterContainer.new()  # Centraliza o painel.
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel: PanelContainer = PanelContainer.new()  # Painel.
	center.add_child(panel)

	var column: VBoxContainer = VBoxContainer.new()  # Coluna do painel.
	panel.add_child(column)

	var heading: Label = Label.new()  # Título do painel.
	heading.text = "CONFIRMAR ESCOLHA LENDÁRIA"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override(&"font_color", Palette.DANGER)  # escolha lendária = perda (destrutiva)
	column.add_child(heading)

	_confirm_text = Label.new()  # Texto com a lista do que será perdido.
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_text.custom_minimum_size.x = CONFIRM_WIDTH
	column.add_child(_confirm_text)

	var buttons: HBoxContainer = HBoxContainer.new()  # Linha dos botões.
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	_confirm_ok = PixelButton.new()  # Botão "Confirmar".
	_confirm_ok.text = "Confirmar"
	_confirm_ok.custom_minimum_size = Vector2(Palette.UNIT * 16, 0.0)
	_confirm_ok.pressed.connect(_on_confirm_pressed)
	buttons.add_child(_confirm_ok)
	_confirm_back = PixelButton.new()  # Botão "Voltar".
	_confirm_back.text = "Voltar"
	_confirm_back.custom_minimum_size = Vector2(Palette.UNIT * 16, 0.0)
	_confirm_back.pressed.connect(_on_back_pressed)
	buttons.add_child(_confirm_back)


# --- Interação ---

## Durante a confirmação, Esc volta para as cartas.
func _input(event: InputEvent) -> void:
	# Só no passo de confirmação e sem a entrada travada.
	if _is_open and _confirming and not _locked and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()  # Consome a tecla.
		_on_back_pressed()  # Volta.


## Uma carta foi escolhida: comum e avançada valem na hora; lendária pede confirmação.
func _on_card_selected(data: AbilityData) -> void:
	if _locked or not _is_open or _confirming:  # Ignora se travado, fechado ou já confirmando.
		return
	if data.rarity == AbilityData.Rarity.LENDARIA:  # Lendária: confirma antes.
		_show_confirm(data)
	else:
		ability_chosen.emit(data)  # Comum ou avançada: escolhe direto.


## Mostra a confirmação listando as habilidades que serão perdidas.
func _show_confirm(data: AbilityData) -> void:
	_pending = data  # Guarda a carta pendente.
	_confirming = true  # Entra no passo de confirmação.
	var lines: PackedStringArray = PackedStringArray()  # Linhas do texto.
	for owned: AbilityData in _owned:  # Uma linha por habilidade possuída.
		lines.append("• " + owned.display_name)
	# Texto com a lista (ou "nenhuma").
	var lost: String = "\n".join(lines) if not lines.is_empty() else "(nenhuma)"
	# Mensagem de aviso.
	_confirm_text.text = "Ao escolher %s você perde TODAS as outras habilidades desta run:\n\n%s" % [data.display_name, lost]
	_confirm.visible = true  # Mostra o painel.
	_set_focusable(false)  # As cartas deixam de receber foco.
	_confirm_back.grab_focus()  # O foco vai para "Voltar" (opção segura).


## O jogador confirmou: avisa a escolha da lendária.
func _on_confirm_pressed() -> void:
	if _locked or _pending == null:  # Travado ou sem carta pendente: ignora.
		return
	var data: AbilityData = _pending  # Guarda a escolha.
	_pending = null  # Limpa a pendência.
	ability_chosen.emit(data)  # Avisa a escolha.


## O jogador voltou: esconde a confirmação e devolve o foco à carta.
func _on_back_pressed() -> void:
	if not _confirming:  # Só no passo de confirmação.
		return
	_confirming = false  # Sai da confirmação.
	_confirm.visible = false  # Esconde o painel.
	_set_focusable(true)  # As cartas voltam a receber foco.
	for card: LevelUpCard in _cards:  # Procura a carta que estava pendente.
		if card.ability == _pending:  # Devolve o foco a ela.
			card.grab_focus()
	_pending = null  # Limpa a pendência.


## O jogador escolheu manter as habilidades atuais.
func _on_keep_pressed() -> void:
	if _locked or not _is_open or _confirming:  # Ignora se travado, fechado ou confirmando.
		return
	kept_current.emit()  # Avisa.


## Liga/desliga o foco das cartas e do botão (o passo de confirmação tem o dele).
## Liga ou desliga o foco das cartas e do botão (o passo de confirmação tem o dele).
func _set_focusable(enabled: bool) -> void:
	var mode: Control.FocusMode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE  # Modo de foco.
	for card: LevelUpCard in _cards:  # Cada carta.
		card.focus_mode = mode  # Aplica.
	_keep_button.focus_mode = mode  # Botão de manter.
