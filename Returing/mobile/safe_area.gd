class_name SafeArea
extends RefCounted
## Encaixa um Control na área segura do celular (fora do notch, dos cantos arredondados, da barra de gestos do
## Android e da barra home do iOS), sem posições fixas: cada lado é empurrado conforme a âncora dele.
##
##   SafeArea.fit(meu_container)        # no _ready de quem monta a tela
##
## - âncora na borda esquerda (0)  -> anda `margem esquerda` para dentro;
## - âncora na borda direita (1)   -> anda `margem direita` para dentro;
## - âncora no meio (0,5)          -> fica centralizado na área segura.
## No computador não faz nada (a área segura é a tela toda), então o layout de teclado/mouse não muda.

const META: StringName = &"safe_area_base"  # Guarda os offsets originais para poder reaplicar.


## Aplica a área segura ao Control e mantém aplicada quando ela muda (girar o aparelho, redimensionar).
static func fit(control: Control) -> void:
	if control == null or not Platform.is_mobile():
		return
	if not control.has_meta(META):
		control.set_meta(META, [control.offset_left, control.offset_top, control.offset_right, control.offset_bottom])
		var ref: WeakRef = weakref(control)
		var refit: Callable = func() -> void:
			var c: Control = ref.get_ref() as Control
			if c != null:
				_apply(c)
		Platform.safe_area_changed.connect(refit)
		control.tree_exiting.connect(func() -> void:
			if Platform.safe_area_changed.is_connected(refit):
				Platform.safe_area_changed.disconnect(refit), CONNECT_ONE_SHOT)
	_apply(control)


## Troca os offsets "de fábrica" (para quem reposiciona o Control por código depois do `fit`).
static func rebase(control: Control) -> void:
	if control != null and control.has_meta(META):
		control.set_meta(META, [control.offset_left, control.offset_top, control.offset_right, control.offset_bottom])
		_apply(control)


static func _apply(control: Control) -> void:
	var base: Array = control.get_meta(META)
	var m: Vector4 = Platform.get_safe_margins()  # esquerda, topo, direita, base
	control.offset_left = float(base[0]) + lerpf(m.x, -m.z, control.anchor_left)
	control.offset_right = float(base[2]) + lerpf(m.x, -m.z, control.anchor_right)
	control.offset_top = float(base[1]) + lerpf(m.y, -m.w, control.anchor_top)
	control.offset_bottom = float(base[3]) + lerpf(m.y, -m.w, control.anchor_bottom)


## Faixas que o layout ATUAL dos controles de toque deixa livres (retângulos em coordenadas de tela):
## - TOP: no alto, da direita das barras de status até a esquerda do botão de pausa;
## - BOTTOM: embaixo, da direita do joystick de movimento até a esquerda dos botões de ação.
## Se o jogador mudou tanto o layout que a faixa sumiu, devolve a largura segura inteira.
enum Band { TOP, BOTTOM }

const BAND_GAP: float = 12.0
const BAND_MIN_WIDTH: float = 240.0


static func free_band(band: Band) -> Rect2:
	var safe: Rect2 = Platform.get_safe_rect()
	var left: float = safe.position.x + BAND_GAP
	var right: float = safe.end.x - BAND_GAP
	if band == Band.TOP:
		var status: Rect2 = MobileControls.control_rect(MobileLayout.STATUS)
		var pause: Rect2 = MobileControls.control_rect(MobileLayout.PAUSE)
		if status.position.y < safe.position.y + 170.0:
			if status.get_center().x < safe.get_center().x:
				left = maxf(left, status.end.x + BAND_GAP)
			else:
				right = minf(right, status.position.x - BAND_GAP)
		if pause.position.y < safe.position.y + 170.0:
			if pause.get_center().x > safe.get_center().x:
				right = minf(right, pause.position.x - BAND_GAP)
			else:
				left = maxf(left, pause.end.x + BAND_GAP)
	else:
		for id: StringName in [MobileLayout.MOVE, MobileLayout.AIM, MobileLayout.DASH, MobileLayout.WEAPON, MobileLayout.COMMAND]:
			var rect: Rect2 = MobileControls.control_rect(id)
			if rect.end.y < safe.position.y + safe.size.y * 0.5:
				continue  # controle fora da metade de baixo da tela
			if rect.get_center().x < safe.get_center().x:
				left = maxf(left, rect.end.x + BAND_GAP)
			else:
				right = minf(right, rect.position.x - BAND_GAP)
	if right - left < BAND_MIN_WIDTH:
		left = safe.position.x + BAND_GAP
		right = safe.end.x - BAND_GAP
	return Rect2(left, safe.position.y, right - left, safe.size.y)


## Celular: faz de `region` (filho de um Control qualquer) uma coluna que ocupa exatamente a faixa livre `band`,
## da borda de cima à de baixo da área segura. O que for ancorado dentro dela (centro, alto, largura total...)
## fica automaticamente fora das barras de status e dos controles. Reaplica quando a área segura muda.
## No computador não faz nada.
static func fit_band(region: Control, band: Band) -> void:
	if region == null or not Platform.is_mobile():
		return
	var ref: WeakRef = weakref(region)
	var place: Callable = func() -> void:
		var c: Control = ref.get_ref() as Control
		if c == null or not c.is_inside_tree():
			return
		var rect: Rect2 = free_band(band)
		var parent: Control = c.get_parent() as Control
		var origin: Vector2 = parent.global_position if parent != null else Vector2.ZERO
		c.set_anchors_preset(Control.PRESET_TOP_LEFT)
		c.position = Vector2(rect.position.x - origin.x, rect.position.y - origin.y)
		c.size = rect.size
	place.call()
	place.call_deferred()  # de novo depois do layout do pai
	Platform.safe_area_changed.connect(place)
	MobileControls.layout_changed.connect(place)
	region.tree_exiting.connect(func() -> void:
		if Platform.safe_area_changed.is_connected(place):
			Platform.safe_area_changed.disconnect(place)
		if MobileControls.layout_changed.is_connected(place):
			MobileControls.layout_changed.disconnect(place), CONNECT_ONE_SHOT)


## Cria (só no celular) uma região na faixa livre `band` dentro de `parent` e a devolve; no computador devolve o
## próprio `parent`, de modo que o código de montagem é o mesmo e o layout de computador não muda.
static func band_region(parent: Control, band: Band, region_name: String = "FaixaLivre") -> Control:
	if not Platform.is_mobile():
		return parent
	var region: Control = Control.new()
	region.name = region_name
	region.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(region)
	fit_band(region, band)
	return region


## Celular: textos de objetivo que no computador ficam no canto superior esquerdo (onde o celular tem as barras de
## status) vão para uma coluna na faixa livre do alto, com quebra de linha automática.
## `corner` (opcional) é um item pequeno do canto superior direito (ex.: slot da chave), que passa a ficar no fim da
## mesma faixa, à esquerda do botão de pausa.
static func stack_top_band(parent: Control, labels: Array, corner: Control = null) -> void:
	if parent == null or not Platform.is_mobile():
		return
	var region: Control = band_region(parent, Band.TOP, "FaixaDoAlto")
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Coluna"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 2)
	column.set_anchors_preset(Control.PRESET_TOP_WIDE)
	column.offset_top = 12.0
	region.add_child(column)
	if corner != null:
		var width: float = corner.offset_right - corner.offset_left
		var top: float = corner.offset_top
		var height: float = corner.offset_bottom - corner.offset_top
		corner.reparent(region, false)
		corner.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		corner.offset_right = 0.0
		corner.offset_left = -width
		corner.offset_top = top
		corner.offset_bottom = top + height
		column.offset_right = -(width + BAND_GAP)
	for item: Variant in labels:
		var label: Label = item as Label
		if label == null:
			continue
		label.reparent(column, false)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2.ZERO
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
