class_name CommandHud
extends Control
## HUD de habilidades. Fora do modo comando: faixa compacta de slots (embaixo à direita, longe da barra de
## vida e da de XP) com varredura de cooldown. Durante o modo comando: painel com as habilidades, as setas
## e a barra de recarga. Só escuta os sinais do AbilityComponent: ele não conhece esta HUD.

## Clique ou toque no amuleto de uma habilidade (abre o menu de build).
signal slot_pressed(ability: AbilityData)

# Cores da barra de recarga: fundo, preenchimento e "pronta".
const COLOR_BAR_BG: Color = Color(0.1, 0.09, 0.14, 1.0)
const COLOR_BAR_FILL: Color = Color(0.56, 0.58, 0.64, 1.0)
const COLOR_BAR_READY: Color = UiPalette.GOLD

const ROW_AMULET_SIZE: float = 40.0  # Tamanho do amuleto nas linhas do painel de comando.
const NAME_WIDTH: float = 150.0  # Largura do nome da habilidade.
const BAR_SIZE: Vector2 = Vector2(70.0, 6.0)  # Tamanho da barra de recarga.
## Largura da coluna de setas (cabe a sequência mais longa: 6 setas).
const ARROWS_COLUMN_WIDTH: float = 133.0
## Quantos slots a faixa compacta mostra (vazios aparecem discretos até as habilidades chegarem).
const MAX_SLOTS: int = 3
const SLOT_SEPARATION: int = UiPalette.UNIT
## No celular a faixa compacta desce (px) para ficar abaixo do botão de pausa.
const MOBILE_COMPACT_TOP: float = 72.0
## Margem inferior do painel de comando no celular (centralizado, entre os analógicos).
const MOBILE_PANEL_BOTTOM: int = 24
## Transparência das linhas que não combinam com o que foi digitado.
const DIMMED_ALPHA: float = 0.35
## Dica de como ativar (aparece sobre os slots até o jogador abrir o modo comando uma vez).
const HINT_PC: String = "Aperte CTRL, digite as setas e confirme com ENTER"
## Rodapé do painel de comando (teclado).
const FOOTER_PC: String = "ENTER confirma  -  BACKSPACE apaga  -  CTRL cancela"
## "Colinha": sequência em miniatura acima de cada slot da faixa compacta (sempre visível).
const CHEAT_ARROW_SIZE: float = 10.0
const CHEAT_ARROW_GAP: float = 3.0
const CHEAT_SLOT_GAP: int = 3
const HINT_MOBILE: String = "Toque no botão de comando e incline o celular"  # Dica de como ativar no celular.
# Aviso quando não há habilidades.
const NOTICE_NO_ABILITIES: String = "Sem habilidades ainda: suba de nível"
## Quanto tempo (s) o aviso substitui a dica.
const NOTICE_TIME: float = 2.5

var _abilities: AbilityComponent = null  # Componente de habilidades.
var _panel: PanelContainer = null  # Painel do modo comando.
var _rows_box: VBoxContainer = null  # Linhas do painel (uma por habilidade).
var _compact: HBoxContainer = null  # Faixa compacta de slots.
var _hint: Label = null  # Dica de como ativar.
var _notice_token: int = 0  # Identificador do aviso atual (evita que um aviso antigo apague o novo).
var _notice_active: bool = false  # True enquanto o aviso está na tela.
## id -> { "data", "row", "arrows", "bar", "amulet", "slot", "cooling", "dimmed" }
var _entries: Dictionary = {}


## Prepara a HUD: ocupa a tela toda sem bloquear cliques e cria o painel e a faixa compacta.
func _ready() -> void:
	add_to_group(&"mobile_layout_listeners")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # Cobre a tela inteira.
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # a HUD nunca bloqueia cliques do jogo
	theme = UiPalette.load_theme()  # Tema do jogo.
	_build_panel()  # Painel do modo comando.
	_build_compact()  # Faixa compacta.
	_panel.visible = false  # O painel começa escondido.


## Liga a HUD ao componente de habilidades e escuta todos os sinais dele.
func setup(abilities: AbilityComponent) -> void:
	_abilities = abilities  # Guarda o componente.
	CombatUtils.connect_once(abilities.abilities_changed, _rebuild)  # Lista mudou: refaz tudo.
	# Modo comando abriu ou fechou.
	CombatUtils.connect_once(abilities.command_mode_changed, _on_command_mode_changed)
	CombatUtils.connect_once(abilities.input_progress, _on_input_progress)  # Progresso da digitação.
	CombatUtils.connect_once(abilities.input_failed, _on_input_failed)  # Erro de digitação.
	CombatUtils.connect_once(abilities.cooldown_changed, _on_cooldown_changed)  # Recarga mudou.
	# Ctrl sem habilidades.
	CombatUtils.connect_once(abilities.command_unavailable, _on_command_unavailable)
	_rebuild()  # Monta a HUD.


## Ao sair da cena desliga todos os sinais do componente.
func _exit_tree() -> void:
	if not is_instance_valid(_abilities):  # Componente já removido: nada a desligar.
		return
	CombatUtils.disconnect_if_connected(_abilities.abilities_changed, _rebuild)
	CombatUtils.disconnect_if_connected(_abilities.command_mode_changed, _on_command_mode_changed)
	CombatUtils.disconnect_if_connected(_abilities.input_progress, _on_input_progress)
	CombatUtils.disconnect_if_connected(_abilities.input_failed, _on_input_failed)
	CombatUtils.disconnect_if_connected(_abilities.cooldown_changed, _on_cooldown_changed)
	CombatUtils.disconnect_if_connected(_abilities.command_unavailable, _on_command_unavailable)


# --- Construção ---

## Cria o painel do modo comando (moldura dourada vinda do tema) e a coluna das linhas.
func _build_panel() -> void:
	_panel = PanelContainer.new()  # moldura dourada vem do tema
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_rows_box = VBoxContainer.new()  # Coluna das linhas.
	_rows_box.add_theme_constant_override(&"separation", UiPalette.UNIT)
	_rows_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_rows_box)
	_panel.resized.connect(_place_panel)  # Reposiciona o painel quando o tamanho muda.


## Painel no canto inferior direito (longe das barras de vida e XP); no celular, no centro de baixo.
## Posiciona o painel: embaixo à direita no PC; no celular, centralizado embaixo.
func _place_panel() -> void:
	if Platform.is_mobile():
		_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, MOBILE_PANEL_BOTTOM)
	else:
		_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, UiPalette.SAFE_MARGIN)


## Cria a faixa compacta de slots e a dica de como ativar.
func _build_compact() -> void:
	_compact = HBoxContainer.new()  # Faixa de slots.
	_compact.add_theme_constant_override(&"separation", SLOT_SEPARATION)
	_compact.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_compact)
	_compact.minimum_size_changed.connect(_place_compact)  # Reposiciona quando o tamanho mínimo muda.
	_hint = Label.new()  # Dica.
	_hint.theme_type_variation = &"HintLabel"
	_hint.text = HINT_MOBILE if Platform.is_mobile() else HINT_PC  # Texto conforme a plataforma.
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Contorno para ler sobre o jogo.
	_hint.add_theme_color_override(&"font_outline_color", UiPalette.OUTLINE)
	_hint.add_theme_constant_override(&"outline_size", 4)
	add_child(_hint)
	_hint.minimum_size_changed.connect(_place_compact)


## Faixa compacta no canto inferior direito; no celular, dentro da região do quadro de comandos (abaixo
## do botão de pausa), acompanhando o layout.
func _place_compact() -> void:
	if Platform.is_mobile():
		var rect: Rect2 = MobileControls.control_rect(MobileLayout.BOARD)
		var left: float = rect.end.x - 8.0 - _compact.size.x
		_compact.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_compact.position = Vector2(left, rect.position.y + MOBILE_COMPACT_TOP)
	else:
		_compact.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, UiPalette.SAFE_MARGIN)
	# A dica fica junto dos slots (acima deles; no celular, abaixo).
	# Altura ocupada pelos slots e pela colinha.
	var slot_band: float = CooldownSlot.TOUCH_SLOT_SIZE + CHEAT_ARROW_SIZE + CHEAT_SLOT_GAP + UiPalette.UNIT if Platform.is_mobile() 			else CooldownSlot.SLOT_SIZE + CHEAT_ARROW_SIZE + CHEAT_SLOT_GAP + UiPalette.UNIT
	if Platform.is_mobile():
		_hint.set_anchors_preset(Control.PRESET_TOP_LEFT)
		var hint_x: float = MobileControls.control_rect(MobileLayout.BOARD).end.x - 8.0 - _hint.size.x
		_hint.position = Vector2(hint_x, _compact.position.y + slot_band)
	else:
		_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, UiPalette.SAFE_MARGIN)
		_hint.position.y -= slot_band


## O layout do celular mudou: reposiciona a faixa de habilidades.
func on_mobile_layout_changed() -> void:
	_place_compact()


## Recria as linhas do painel e os slots compactos.
## Recria as linhas do painel e os slots da faixa compacta a partir das habilidades atuais.
func _rebuild() -> void:
	for child: Node in _rows_box.get_children():  # Apaga as linhas antigas.
		child.queue_free()
	for child: Node in _compact.get_children():  # Apaga os slots antigos.
		child.queue_free()
	_entries.clear()  # Esquece os dados antigos.
	if _abilities == null:  # Sem componente: nada a mostrar.
		return
	for data: AbilityData in _abilities.abilities:  # Uma linha e um slot por habilidade.
		_add_entry(data)
	for i: int in range(_abilities.abilities.size(), MAX_SLOTS):  # slots vazios, discretos
		_compact.add_child(_make_slot_column(CooldownSlot.new(), null))
	# No PC mostra o rodapé com as teclas.
	if not _abilities.abilities.is_empty() and not Platform.is_mobile():
		var footer: Label = Label.new()
		footer.theme_type_variation = &"HintLabel"
		footer.text = FOOTER_PC
		footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rows_box.add_child(footer)
	_refresh_visibility()  # Mostra ou esconde conforme o modo.
	_place_panel.call_deferred()  # Posiciona o painel depois do layout.
	_place_compact.call_deferred()  # Posiciona a faixa depois do layout.


## Cria a linha do painel e o slot compacto de uma habilidade e guarda os nós no dicionário.
func _add_entry(data: AbilityData) -> void:
	var entry: Dictionary = {"data": data, "cooling": false, "dimmed": false}  # Dados da habilidade na HUD.

	# Linha do painel (modo comando).
	var row: HBoxContainer = HBoxContainer.new()  # Linha do painel de comando.
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var amulet: AmuletIcon = AmuletIcon.new()  # Amuleto.
	amulet.custom_minimum_size = Vector2(ROW_AMULET_SIZE, ROW_AMULET_SIZE)
	amulet.set_ability(data)
	row.add_child(amulet)
	var name_label: Label = Label.new()  # Nome.
	name_label.text = data.display_name
	name_label.custom_minimum_size.x = NAME_WIDTH
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)
	var arrows: ArrowSequenceView = ArrowSequenceView.new()  # Setas da sequência.
	arrows.set_sequence(data.sequence)
	arrows.custom_minimum_size.x = ARROWS_COLUMN_WIDTH  # a barra de recarga fica alinhada em todas as linhas
	arrows.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(arrows)
	var bar: ProgressBar = _make_bar()  # Barra de recarga.
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	_rows_box.add_child(row)  # Entra no painel.
	entry["row"] = row
	entry["amulet"] = amulet
	entry["arrows"] = arrows
	entry["bar"] = bar

	# Slot compacto (fora do modo comando).
	var slot: CooldownSlot = CooldownSlot.new()  # Slot compacto.
	slot.ability = data
	slot.pressed.connect(_on_slot_pressed)  # Clicar no slot avisa a HUD.
	var cheat: ArrowSequenceView = ArrowSequenceView.new()  # Colinha: sequência em miniatura.
	cheat.arrow_size = CHEAT_ARROW_SIZE
	cheat.arrow_gap = CHEAT_ARROW_GAP
	cheat.set_sequence(data.sequence)
	_compact.add_child(_make_slot_column(slot, cheat))  # Coluna com a colinha e o slot.
	entry["slot"] = slot
	entry["cheat"] = cheat

	_entries[data.id] = entry  # Guarda no dicionário.
	# Mostra a recarga atual sem animar.
	_apply_cooldown(entry, _abilities.get_cooldown_left(data.id), data.cooldown, false)


## Coluna da faixa compacta: a colinha (setas da sequência) em cima e o slot embaixo.
## Slot vazio recebe um espaço do mesmo tamanho para os slots ficarem alinhados.
## Cria a coluna da faixa compacta: colinha em cima e slot embaixo (slot vazio ganha um espaço do mesmo tamanho).
func _make_slot_column(slot: CooldownSlot, cheat: Control) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", CHEAT_SLOT_GAP)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if cheat == null:  # Slot vazio: espaço no lugar da colinha.
		cheat = Control.new()
		cheat.custom_minimum_size = Vector2(0.0, CHEAT_ARROW_SIZE)
		cheat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cheat.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(cheat)
	column.add_child(slot)
	return column


## Cria a barra de recarga com fundo e preenchimento próprios.
func _make_bar() -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = BAR_SIZE
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 1.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = COLOR_BAR_BG
	bar.add_theme_stylebox_override(&"background", background)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = COLOR_BAR_FILL
	bar.add_theme_stylebox_override(&"fill", fill)
	return bar


# --- Sinais do AbilityComponent ---

## Um slot foi pressionado: repassa ao menu de build.
func _on_slot_pressed(ability: AbilityData) -> void:
	slot_pressed.emit(ability)


## Devolve as áreas (em coordenadas da tela) dos slots clicáveis da faixa compacta, usadas pelo toque no celular.
## Áreas (coordenadas da tela) dos slots clicáveis da faixa compacta, para o toque no celular.
func get_slot_hit_rects() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _compact == null or not _compact.visible:  # Faixa escondida: sem áreas.
		return result
	for entry: Dictionary in _entries.values():  # Uma área por habilidade.
		var slot: CooldownSlot = entry["slot"] as CooldownSlot  # Slot da habilidade.
		# Guarda habilidade e retângulo.
		result.append({"ability": entry["data"], "rect": slot.get_global_rect()})
	return result


## Ctrl apertado sem habilidades: o aviso substitui a dica por alguns segundos.
## Ctrl apertado sem nenhuma habilidade: o aviso substitui a dica por alguns segundos.
func _on_command_unavailable(motivo: StringName) -> void:
	if motivo != &"sem_habilidades":  # Só esse motivo é tratado.
		return
	_hint.text = NOTICE_NO_ABILITIES  # Troca o texto.
	_notice_active = true  # Marca o aviso ativo.
	_notice_token += 1  # Novo identificador.
	var token: int = _notice_token  # Guarda o identificador.
	_refresh_visibility()  # Atualiza a visibilidade.
	# Espera o tempo do aviso (respeitando a pausa).
	await get_tree().create_timer(NOTICE_TIME, false).timeout
	if token == _notice_token:  # Só apaga se ninguém criou um aviso mais novo.
		_notice_active = false  # Aviso acabou.
		_hint.text = HINT_MOBILE if Platform.is_mobile() else HINT_PC  # Volta a dica normal.
		_refresh_visibility()


## O modo comando abriu ou fechou: alterna entre faixa compacta e painel.
func _on_command_mode_changed(active: bool) -> void:
	if active:  # Abriu: a dica não precisa mais aparecer.
		RunState.command_hint_seen = true
	_refresh_visibility()


## Mostra o painel no modo comando e a faixa compacta fora dele; a dica some depois do primeiro uso.
func _refresh_visibility() -> void:
	var active: bool = _abilities != null and _abilities.command_active  # Modo comando aberto?
	_panel.visible = active and not _entries.is_empty() and not Platform.is_mobile()  # Painel só com habilidades (no celular, o quadro de comandos faz esse papel).
	_compact.visible = not active  # Faixa compacta quando o modo está fechado.
	# Dica: aviso ativo ou jogador ainda não usou o modo.
	_hint.visible = not active and (_notice_active or (not _entries.is_empty() and not RunState.command_hint_seen))
	if _panel.visible:  # Reposiciona o painel.
		_place_panel.call_deferred()


## A cada seta digitada, apaga as linhas que não combinam e acende as setas já acertadas nas outras.
func _on_input_progress(sequence: Array[int], candidates: Array[AbilityData]) -> void:
	for entry: Dictionary in _entries.values():
		var data: AbilityData = entry["data"] as AbilityData  # Dados da habilidade.
		var arrows: ArrowSequenceView = entry["arrows"] as ArrowSequenceView  # Setas da linha.
		var row: Control = entry["row"] as Control  # Linha inteira.
		var matches: bool = candidates.has(data)  # Ainda combina com o que foi digitado?
		entry["dimmed"] = not matches  # Guarda se está apagada.
		row.modulate.a = 1.0 if matches else DIMMED_ALPHA  # Linha apagada ou normal.
		arrows.set_progress(sequence.size() if matches else 0)  # Acende as setas acertadas.
		if not matches:  # Não combina: setas apagadas.
			arrows.set_state(ArrowSequenceView.State.DIMMED)
		else:  # Combina: cor de recarga ou normal.
			arrows.set_state(ArrowSequenceView.State.COOLDOWN if bool(entry["cooling"])
					else ArrowSequenceView.State.NORMAL)


## Erro de digitação: todas as sequências tremem.
func _on_input_failed() -> void:
	for entry: Dictionary in _entries.values():
		(entry["arrows"] as ArrowSequenceView).shake()


## A recarga mudou: atualiza a linha e o slot dessa habilidade.
func _on_cooldown_changed(ability: AbilityData, remaining: float, total: float) -> void:
	if not _entries.has(ability.id):  # Habilidade desconhecida: ignora.
		return
	_apply_cooldown(_entries[ability.id] as Dictionary, remaining, total, true)  # Aplica a recarga.


## Atualiza barra, slot e setas de uma habilidade. Quando a recarga termina, as setas dão um brilho.
func _apply_cooldown(entry: Dictionary, remaining: float, total: float, animate: bool) -> void:
	var cooling: bool = remaining > 0.0  # Em recarga agora?
	var was_cooling: bool = bool(entry["cooling"])  # Estava em recarga antes?
	entry["cooling"] = cooling  # Guarda o estado.
	var bar: ProgressBar = entry["bar"] as ProgressBar  # Barra da linha.
	var arrows: ArrowSequenceView = entry["arrows"] as ArrowSequenceView  # Setas da linha.
	var slot: CooldownSlot = entry["slot"] as CooldownSlot  # Slot compacto.
	var ratio: float = clampf(remaining / maxf(total, 0.01), 0.0, 1.0)  # Fração da recarga que falta.
	bar.value = 1.0 - ratio  # A barra enche conforme a recarga avança.
	var fill: StyleBoxFlat = bar.get_theme_stylebox(&"fill") as StyleBoxFlat  # Preenchimento da barra.
	if fill != null:
		# Cinza na recarga, dourado quando pronta.
		fill.bg_color = COLOR_BAR_FILL if cooling else COLOR_BAR_READY
	slot.update_cooldown(remaining, total, animate)  # Atualiza o slot compacto.
	var cheat: ArrowSequenceView = entry["cheat"] as ArrowSequenceView  # Colinha.
	# Atualiza o estado da colinha.
	cheat.set_state(ArrowSequenceView.State.COOLDOWN if cooling else ArrowSequenceView.State.NORMAL)
	if bool(entry["dimmed"]):  # Linha apagada por não combinar.
		arrows.set_state(ArrowSequenceView.State.DIMMED)
	else:
		# Linha que combina: cor de recarga ou normal.
		arrows.set_state(ArrowSequenceView.State.COOLDOWN if cooling else ArrowSequenceView.State.NORMAL)
	if animate and was_cooling and not cooling:  # Acabou a recarga: brilho.
		arrows.pulse()
		cheat.pulse()
