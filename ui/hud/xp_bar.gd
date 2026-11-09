class_name XpBar
extends Control
## Barra de nível e XP no estilo da barra de vida (moldura dourada, preenchimento azul-ciano, emblema
## hexagonal com o nível). Na HUD ela é VERTICAL: fica à direita do bloco das barras de vida e de carga,
## com o topo na altura da primeira e a base na base da última (o comprimento acompanha o bloco).
## A versão HORIZONTAL (`orientation`) serve para cabeçalhos, como o do menu de build.
##
## Uso: `set_xp(atual, maximo, nivel, nivel_maximo)`; `atual` e `maximo` são o XP DENTRO do nível
## (ex.: 40 de 150). Com `auto_bind` ligado ela se conecta ao `ExperienceComponent` do Player.

enum BarLayout { VERTICAL, HORIZONTAL }  # Duas orientações: vertical (na HUD) e horizontal (cabeçalhos).

# Imagens da versão vertical: moldura, preenchimento e brilho.
const FRAME_V: Texture2D = preload("res://ui/hud/xp_frame_v.png")
const FILL_V: Texture2D = preload("res://ui/hud/xp_fill_v.png")
const SHINE_V: Texture2D = preload("res://ui/hud/xp_shine_v.png")
# Imagens da versão horizontal: moldura, preenchimento e brilho.
const FRAME_H: Texture2D = preload("res://ui/hud/xp_frame.png")
const FILL_H: Texture2D = preload("res://ui/hud/xp_fill.png")
const SHINE_H: Texture2D = preload("res://ui/hud/xp_shine.png")

const COLOR_TEXT: Color = UiPalette.TEXT  # Cores e tamanhos do texto.
const COLOR_TEXT_OUTLINE: Color = UiPalette.OUTLINE
const OUTLINE_SIZE: int = 4
const FONT_VALUE_HORIZONTAL: int = 14
const FONT_VALUE_VERTICAL: int = 12
const FONT_LEVEL: int = 30
const SHINE_ALPHA: float = 0.9  # Opacidade do brilho que percorre a barra ao subir de nível.
const GLOW_MAX_ALPHA: float = 0.95  # Opacidade máxima do brilho dourado do nível máximo.
const GLOW_MIN_ALPHA: float = 0.45  # Opacidade mínima do brilho dourado do nível máximo.
const EMBLEM_POP_SCALE: float = 1.18  # Quanto o emblema cresce no pulso.

## Medidas em pixels de tela (a escala de pixel da HUD é 4x, a mesma da barra de vida).
const THICKNESS: float = 64.0
const EMBLEM_SIZE: float = 80.0
const GLOW_SIZE: float = 112.0
const FRAME_MARGIN: int = 32
const FILL_STRETCH_MARGIN: int = 16
## Vertical: o emblema fica centrado na borda de cima, sobreposto à moldura.
const V_EMBLEM_POS: Vector2 = Vector2(-8.0, -40.0)
const V_FILL_INSET_X: float = 16.0
const V_FILL_TOP: float = 44.0
const V_FILL_BOTTOM_INSET: float = 20.0
## Horizontal: o emblema fica à esquerda e a moldura começa debaixo dele.
const H_EMBLEM_POS: Vector2 = Vector2(0.0, -8.0)
const H_BODY_X: float = 56.0
const H_FILL_X: float = 76.0
const H_FILL_RIGHT_INSET: float = 24.0
const H_FILL_Y: float = 16.0
const FILL_THICKNESS: float = 32.0
## Espaço (px) entre o bloco de barras de vida e a barra de XP.
const GAP: float = 16.0

@export var orientation: BarLayout = BarLayout.VERTICAL  # Orientação da barra.

@export_group("Animação")
## Tempo (s) do preenchimento suave.
@export_range(0.05, 1.5, 0.05) var fill_time: float = 0.35
## Tempo (s) do brilho que percorre a barra ao subir de nível.
@export_range(0.1, 2.0, 0.05) var shine_time: float = 0.7
## Tempo (s) do pulso do emblema.
@export_range(0.1, 1.0, 0.05) var pulse_time: float = 0.4

@export_group("Ligação")
## Liga sozinha ao `ExperienceComponent` do Player (desligue na galeria de testes).
@export var auto_bind: bool = true
## Na versão vertical da HUD: acompanha o bloco de barras de vida (posição e comprimento).
@export var follow_health_block: bool = true

@onready var _glow: TextureRect = $Glow  # Brilho dourado atrás do emblema.
@onready var _body: NinePatchRect = $Body  # Moldura (nove partes, estica sem deformar os cantos).
@onready var _fill_clip: Control = $FillClip  # Recorte que limita o preenchimento.
@onready var _fill: TextureProgressBar = $FillClip/Fill  # Preenchimento.
@onready var _shine: TextureRect = $FillClip/Shine  # Brilho que percorre a barra.
@onready var _value_label: Label = $ValueLabel  # Texto "atual/máximo".
@onready var _emblem: TextureRect = $Emblem  # Emblema com o nível.
@onready var _emblem_max: TextureRect = $EmblemMax  # Emblema do nível máximo.
@onready var _level_label: Label = $LevelLabel  # Número do nível.

var _experience: ExperienceComponent = null  # Componente de XP do jogador.
var _level: int = -1  # Nível mostrado.
var _is_max: bool = false  # True no nível máximo.
var _shown_ratio: float = 0.0  # Fração do preenchimento mostrada agora.
var _fill_tween: Tween = null  # Animações (preenchimento, brilho, pulso e brilho dourado).
var _shine_tween: Tween = null
var _pulse_tween: Tween = null
var _glow_tween: Tween = null


## Prepara textos, preenchimento e layout; liga a barra ao XP do jogador (se `auto_bind`).
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Não captura cliques.
	for label: Label in [_value_label, _level_label]:  # Estilo dos dois textos.
		label.add_theme_color_override(&"font_color", COLOR_TEXT)
		label.add_theme_color_override(&"font_outline_color", COLOR_TEXT_OUTLINE)
		label.add_theme_constant_override(&"outline_size", OUTLINE_SIZE)
	_level_label.add_theme_font_size_override(&"font_size", FONT_LEVEL)  # Tamanho do número do nível.
	_value_label.add_theme_font_size_override(&"font_size",  # Tamanho do texto de XP conforme a orientação.
			FONT_VALUE_VERTICAL if orientation == BarLayout.VERTICAL else FONT_VALUE_HORIZONTAL)
	_fill.max_value = 1.0  # Preenchimento de 0 a 1.
	_fill.step = 0.0  # Sem passos.
	_fill.nine_patch_stretch = true  # Estica só o miolo da imagem.
	_shine.modulate.a = 0.0  # O brilho começa invisível.
	resized.connect(_apply_layout)  # Refaz o layout se o tamanho mudar.
	_apply_layout()  # Posiciona as partes.
	set_xp(0, 1, 0, false)  # Estado inicial: nível 0 sem XP.
	if orientation == BarLayout.VERTICAL and follow_health_block:  # Versão vertical da HUD.
		_align_to_health_block.call_deferred()  # Alinha ao bloco de barras de vida depois do layout.
	if auto_bind:  # Liga ao XP do jogador.
		_bind.call_deferred()  # Liga depois do _ready do jogador.


## Ao sair da cena desliga a ligação e cancela as animações.
func _exit_tree() -> void:
	_unbind()  # Solta o componente de XP.
	for tween: Tween in [_fill_tween, _shine_tween, _pulse_tween, _glow_tween]:  # Cancela cada animação.
		if tween != null and tween.is_valid():
			tween.kill()


## Posiciona cada parte conforme a orientação e o tamanho atual.
## Posiciona cada parte (emblema, moldura, preenchimento e texto) conforme a orientação e o tamanho atual.
func _apply_layout() -> void:
	var vertical: bool = orientation == BarLayout.VERTICAL  # Vertical?
	var emblem_pos: Vector2 = V_EMBLEM_POS if vertical else H_EMBLEM_POS  # Posição do emblema.
	for emblem: TextureRect in [_emblem, _emblem_max]:  # Os dois emblemas.
		emblem.position = emblem_pos  # Posição.
		emblem.size = Vector2.ONE * EMBLEM_SIZE  # Tamanho.
	_level_label.position = emblem_pos  # Número do nível sobre o emblema.
	_level_label.size = Vector2.ONE * EMBLEM_SIZE  # Tamanho.
	# Brilho dourado centrado no emblema.
	_glow.position = emblem_pos + Vector2.ONE * (EMBLEM_SIZE - GLOW_SIZE) * 0.5
	_glow.size = Vector2.ONE * GLOW_SIZE  # Tamanho.
	# Os emblemas giram/crescem a partir do centro.
	for pivoted: Control in [_emblem, _emblem_max, _level_label]:
		pivoted.pivot_offset = pivoted.size * 0.5  # Pivô no centro.
	var margin: int = FRAME_MARGIN  # Margem dos nove pedaços da moldura.
	if vertical:  # Barra vertical.
		_body.texture = FRAME_V  # Imagem da moldura.
		_body.position = Vector2.ZERO  # Posição.
		_body.size = Vector2(THICKNESS, maxf(size.y, 96.0))  # Tamanho.
		_fill_clip.position = Vector2(V_FILL_INSET_X, V_FILL_TOP)  # Recorte do preenchimento.
		# Tamanho do recorte.
		_fill_clip.size = Vector2(FILL_THICKNESS, maxf(_body.size.y - V_FILL_TOP - V_FILL_BOTTOM_INSET, 8.0))
		_fill.texture_progress = FILL_V  # Imagem do preenchimento.
		_fill.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP  # Enche de baixo para cima.
		_fill.set_stretch_margin(SIDE_TOP, FILL_STRETCH_MARGIN)  # Margens que não esticam (topo).
		_fill.set_stretch_margin(SIDE_BOTTOM, FILL_STRETCH_MARGIN)
		_fill.set_stretch_margin(SIDE_LEFT, 0)
		_fill.set_stretch_margin(SIDE_RIGHT, 0)
		_shine.texture = SHINE_V
		_value_label.position = Vector2(0.0, _fill_clip.position.y)
		_value_label.size = Vector2(THICKNESS, _fill_clip.size.y)
	else:  # Texto cobre a barra toda.
		_body.texture = FRAME_H  # Barra horizontal.
		_body.position = Vector2(H_BODY_X, 0.0)  # Imagem da moldura.
		_body.size = Vector2(maxf(size.x - H_BODY_X, 128.0), THICKNESS)  # Posição.
		_fill_clip.position = Vector2(H_FILL_X, H_FILL_Y)  # Tamanho.
		# Recorte do preenchimento.
		_fill_clip.size = Vector2(maxf(size.x - H_FILL_X - H_FILL_RIGHT_INSET, 8.0), FILL_THICKNESS)
		_fill.texture_progress = FILL_H  # Tamanho do recorte.
		_fill.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT  # Imagem do preenchimento.
		_fill.set_stretch_margin(SIDE_LEFT, FILL_STRETCH_MARGIN)  # Enche da esquerda para a direita.
		_fill.set_stretch_margin(SIDE_RIGHT, FILL_STRETCH_MARGIN)  # Margens que não esticam (esquerda).
		_fill.set_stretch_margin(SIDE_TOP, 0)
		_fill.set_stretch_margin(SIDE_BOTTOM, 0)
		_shine.texture = SHINE_H
		_value_label.position = _fill_clip.position
		_value_label.size = _fill_clip.size
	_body.patch_margin_left = margin  # Margens da moldura.
	_body.patch_margin_right = margin
	_body.patch_margin_top = margin
	_body.patch_margin_bottom = margin
	_fill.position = Vector2.ZERO  # Preenchimento ocupa o recorte.
	_fill.size = _fill_clip.size
	_shine.size = _shine.texture.get_size()  # Brilho com o tamanho da imagem.
	# Brilho começa fora da barra.
	_shine.position = Vector2(-_shine.size.x, 0.0) if not vertical else Vector2(0.0, _fill_clip.size.y)


## Atualiza a barra. `atual`/`maximo`: XP dentro do nível; `nivel_maximo`: mostra "MÁX" e barra cheia.
## Atualiza a barra. `atual` e `maximo` são o XP dentro do nível; `nivel_maximo` mostra "MÁX" e barra cheia.
func set_xp(atual: int, maximo: int, nivel: int, nivel_maximo: bool) -> void:
	var first: bool = _level < 0  # Primeira atualização?
	var leveled_up: bool = not first and nivel > _level  # Subiu de nível?
	# Fração do preenchimento.
	var target: float = 1.0 if nivel_maximo else clampf(float(atual) / float(maxi(maximo, 1)), 0.0, 1.0)
	_level = nivel  # Guarda o nível.
	_is_max = nivel_maximo  # Guarda se é o máximo.
	_level_label.text = str(nivel)  # Número do nível.
	_value_label.text = "MÁX" if nivel_maximo else "%d/%d" % [atual, maximo]  # Texto de XP (ou "MÁX").
	_emblem.visible = not nivel_maximo  # Emblema normal.
	_emblem_max.visible = nivel_maximo  # Emblema do nível máximo.
	_update_glow()  # Brilho dourado do nível máximo.
	if first:  # Primeira vez: mostra direto, sem animar.
		_set_ratio(target)
		return
	_kill(_fill_tween)  # Cancela a animação anterior.
	if leveled_up:  # Subiu de nível.
		# enche até o fim, zera e recomeça do que sobrou: a barra "estoura" ao subir de nível
		_fill_tween = UiTween.create(self)  # Animação.
		_fill_tween.tween_method(_set_ratio, _shown_ratio, 1.0, fill_time * 0.6)  # Enche até o fim.
		_fill_tween.tween_callback(_set_ratio.bind(0.0))  # Zera.
		_fill_tween.tween_method(_set_ratio, 0.0, target, fill_time)  # Recomeça do que sobrou.
		_play_level_up()  # Brilho e pulso do emblema.
	else:  # Mesmo nível: preenchimento suave.
		_fill_tween = UiTween.create(self)  # Animação.
		_fill_tween.tween_method(_set_ratio, _shown_ratio, target, fill_time)  # Vai até o novo valor.


## Como `set_xp`, mas sem animar (para telas que abrem já no valor certo).
## Como `set_xp`, mas sem animar (para telas que já abrem no valor certo).
func set_xp_instant(atual: int, maximo: int, nivel: int, nivel_maximo: bool) -> void:
	_kill(_fill_tween)  # Cancela a animação.
	_level = -1  # Trata como primeira atualização.
	set_xp(atual, maximo, nivel, nivel_maximo)  # Atualiza.


## Passo da animação do preenchimento.
func _set_ratio(value: float) -> void:
	_shown_ratio = value  # Guarda a fração mostrada.
	_fill.value = value  # Aplica na barra.


## Brilho que percorre a barra (de baixo para cima na vertical) e pulso do emblema.
## Brilho que percorre a barra (de baixo para cima na vertical) e pulso do emblema ao subir de nível.
func _play_level_up() -> void:
	_kill(_shine_tween)  # Cancela o brilho anterior.
	var vertical: bool = orientation == BarLayout.VERTICAL  # Vertical?
	# Ponto de partida do brilho.
	var travel_from: float = _fill_clip.size.y if vertical else -_shine.size.x
	var travel_to: float = -_shine.size.y if vertical else _fill_clip.size.x  # Ponto de chegada do brilho.
	var axis: NodePath = ^"position:y" if vertical else ^"position:x"  # Eixo do movimento.
	# Coloca o brilho no começo.
	_shine.position = Vector2(0.0, travel_from) if vertical else Vector2(travel_from, 0.0)
	_shine.modulate.a = SHINE_ALPHA  # Visível.
	_shine_tween = UiTween.create(self)  # Animação.
	_shine_tween.tween_property(_shine, axis, travel_to, shine_time)  # Percorre a barra.
	_shine_tween.tween_property(_shine, ^"modulate:a", 0.0, 0.05)  # Some.
	_kill(_pulse_tween)  # Cancela o pulso anterior.
	var target: Control = _emblem_max if _is_max else _emblem  # Emblema que pulsa.
	target.scale = Vector2.ONE  # Escala normal.
	_level_label.scale = Vector2.ONE  # Número também.
	_pulse_tween = UiTween.create(self)  # Animação.
	_pulse_tween.set_parallel(true)  # Crescer e voltar ao mesmo tempo.
	# Emblema cresce.
	_pulse_tween.tween_property(target, ^"scale", Vector2.ONE * EMBLEM_POP_SCALE, pulse_time * 0.5)
	# Número cresce.
	_pulse_tween.tween_property(_level_label, ^"scale", Vector2.ONE * EMBLEM_POP_SCALE, pulse_time * 0.5)
	_pulse_tween.chain().set_parallel(true)  # Depois volta.
	_pulse_tween.tween_property(target, ^"scale", Vector2.ONE, pulse_time * 0.5)  # Emblema volta.
	_pulse_tween.tween_property(_level_label, ^"scale", Vector2.ONE, pulse_time * 0.5)  # Número volta.


## No nível máximo o brilho dourado fica ligado e pulsando devagar; fora dele, apagado.
## No nível máximo o brilho dourado fica ligado e pulsando devagar; fora dele, apagado.
func _update_glow() -> void:
	_kill(_glow_tween)  # Cancela o anterior.
	if not _is_max:  # Fora do nível máximo.
		_glow.modulate.a = 0.0  # Apagado.
		return
	_glow.modulate.a = GLOW_MAX_ALPHA  # Brilho ligado.
	_glow_tween = UiTween.create(self)  # Animação.
	_glow_tween.set_loops()  # Repete para sempre.
	_glow_tween.tween_property(_glow, ^"modulate:a", GLOW_MIN_ALPHA, 0.9)  # Escurece devagar.
	_glow_tween.tween_property(_glow, ^"modulate:a", GLOW_MAX_ALPHA, 0.9)  # Volta a clarear.


## Cancela uma animação, se ainda estiver rodando.
func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():  # Só se existe e está válida.
		tween.kill()  # Cancela.


## Fica logo à direita do bloco das barras de vida e de carga, com o topo na primeira e a base na
## última (o comprimento é o do bloco, espaço entre elas incluído), onde quer que elas estejam.
## Alinha a barra à direita do bloco de vida e carga (topo na primeira, base na última).
func _align_to_health_block() -> void:
	await get_tree().process_frame  # deixa o SpriteBar e o MobileControls acertarem as barras antes
	await get_tree().process_frame
	var parent: Node = get_parent()  # Pai da barra.
	if parent == null:  # Sem pai: nada a fazer.
		return
	var health: Control = parent.get_node_or_null(^"PlayerHealthBar") as Control  # Barra de vida.
	if health == null:  # Sem barra de vida: nada a alinhar.
		return
	var last_bar: Control = parent.get_node_or_null(^"ChargeBar") as Control  # Última barra do bloco.
	if last_bar == null:  # HUD de uma barra só: iguala a altura dela.
		last_bar = health  # HUD de uma barra só: iguala a altura dela
	anchor_left = health.anchor_left  # Mesmas âncoras horizontais.
	anchor_right = health.anchor_right
	anchor_top = minf(health.anchor_top, last_bar.anchor_top)  # Âncora de cima.
	anchor_bottom = maxf(health.anchor_bottom, last_bar.anchor_bottom)  # Âncora de baixo.
	grow_vertical = health.grow_vertical  # Direção de crescimento.
	offset_left = maxf(health.offset_right, last_bar.offset_right) + GAP  # Fica logo à direita das barras.
	offset_right = offset_left + THICKNESS  # Largura da barra.
	offset_top = minf(health.offset_top, last_bar.offset_top)  # Topo.
	offset_bottom = maxf(health.offset_bottom, last_bar.offset_bottom)  # Base.


# --- Ligação ao sistema de XP ---

## Liga a barra ao XP do jogador: escuta o nascimento do jogador e já usa o que existir.
func _bind() -> void:
	# Escuta jogadores que nascerem depois.
	CombatUtils.connect_once(EventBus.player_registered, _on_player_registered)
	# Jogador que já existe.
	var player: Node2D = get_tree().get_first_node_in_group(CombatUtils.GROUP_PLAYER) as Node2D
	if player != null:  # Existe.
		_on_player_registered(player)  # Liga a ele.


## Um jogador nasceu: liga ao componente de XP dele.
func _on_player_registered(player: Node2D) -> void:
	# Componente de XP.
	var component: ExperienceComponent = player.get_node_or_null(^"ExperienceComponent") as ExperienceComponent
	if component == null or component == _experience:  # Sem componente ou já ligado: nada a fazer.
		return
	_unbind()  # Solta o componente anterior.
	_experience = component  # Guarda o novo.
	CombatUtils.connect_once(_experience.xp_changed, _on_xp_changed)  # Escuta as mudanças de XP.
	_experience.refresh.call_deferred()  # Pede o estado atual no fim do quadro.


## Desliga a barra do XP (jogador e EventBus).
func _unbind() -> void:
	# Desliga o aviso de jogador novo.
	CombatUtils.disconnect_if_connected(EventBus.player_registered, _on_player_registered)
	if is_instance_valid(_experience):  # Componente ainda existe.
		CombatUtils.disconnect_if_connected(_experience.xp_changed, _on_xp_changed)  # Desliga o XP.
	_experience = null  # Esquece.


## O XP mudou: converte para XP dentro do nível e atualiza a barra.
func _on_xp_changed(xp: int, _xp_next: int, level: int) -> void:
	var floor_xp: int = _experience.get_level_floor()  # XP onde o nível atual começou.
	var next_xp: int = _experience.get_next_threshold()  # XP do próximo nível.
	set_xp(xp - floor_xp, next_xp - floor_xp, level, _experience.is_max_level())  # Atualiza a barra.
