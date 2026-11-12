extends TesteBase
## Seção 15.3: matriz de resoluções. Cada tela do jogo é aberta em 8 resoluções, com notch simulado (recuo lateral
## de 120 px e inferior de 40 px da janela) em paisagem e paisagem invertida, e conferida por asserção:
##   - todo controle visível e interativo e todo texto está dentro da área segura;
##   - nenhum texto estoura a sua caixa;
##   - nenhum par de controles interativos se sobrepõe;
##   - os alvos de toque têm o tamanho mínimo (Platform.MIN_TOUCH; os botões redondos seguem o layout da seção 1).
## Rode com --mobile. `--so=<cenário>` roda só um cenário; com janela (xvfb) salva capturas das resoluções extremas.

const RESOLUCOES: Array[Vector2i] = [
	Vector2i(800, 480), Vector2i(1280, 720), Vector2i(1500, 664), Vector2i(1920, 886), Vector2i(2400, 1080),
	Vector2i(1024, 768), Vector2i(2048, 1536), Vector2i(2778, 1284),
]
const NOTCH_LADO: float = 120.0
const NOTCH_BASE: float = 40.0
## Resoluções que ganham captura (as extremas: menor, mais larga, 4:3 e a maior).
const CAPTURAR: Array[Vector2i] = [Vector2i(800, 480), Vector2i(2778, 1284), Vector2i(1024, 768)]
const TOLERANCIA: float = 1.0

var mc: Node = null
var so: String = ""
var _falhas_cenario: int = 0


func rodar() -> void:
	mc = get_node("/root/MobileControls")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--so="):
			so = arg.trim_prefix("--so=")
	block_scene_changes()
	MobileSettings.wipe()
	Input.set_accelerometer(gravity())  # aparelho com sensor (a página do acelerômetro existe)
	var cenarios := CenariosResolucao.new()
	for cenario: Array in CenariosResolucao.LISTA:
		if so != "" and not String(cenario[0]).contains(so):
			continue
		await _rodar_cenario(cenarios, cenario[0], cenario[1])
	Platform.set_safe_insets_override(null)
	Input.set_accelerometer(Vector3.ZERO)
	MobileSettings.wipe()


func _rodar_cenario(cenarios: CenariosResolucao, nome: String, preparar: StringName) -> void:
	_falhas_cenario = 0
	await _janela(Vector2i(1500, 664), false)
	var ctx: Dictionary = await cenarios.call(preparar, self)
	var total: int = 0
	for res: Vector2i in RESOLUCOES:
		for invertida: bool in [false, true]:
			await _janela(res, invertida)
			if ctx.has("atualizar"):
				await (ctx["atualizar"] as Callable).call()
			await get_tree().process_frame
			await get_tree().process_frame
			var problemas: Array[String] = _conferir(ctx)
			total += 1
			if not problemas.is_empty():
				_falhas_cenario += 1
				if _falhas_cenario == 1:
					print("  FALHA %s em %dx%d%s:" % [nome, res.x, res.y, " (invertida)" if invertida else ""])
					for linha: String in problemas.slice(0, 14):
						print("       ", linha)
				else:
					print("  FALHA %s em %dx%d%s: %d problemas (1º: %s)" % [nome, res.x, res.y, " (invertida)" if invertida else "", problemas.size(), problemas[0].substr(0, 110)])
			if res in CAPTURAR and not invertida:
				await snap_em("resolucoes/%s_%dx%d" % [nome, res.x, res.y])
	check(_falhas_cenario == 0, "%s: inteiro e utilizável nas %d combinações de resolução/orientação (%d com problema)" % [nome, total, _falhas_cenario])
	if ctx.has("fechar"):
		await (ctx["fechar"] as Callable).call()
	get_tree().paused = false
	await unload_level()
	await frames(3)


func _janela(res: Vector2i, invertida: bool) -> void:
	var win: Window = get_tree().root
	win.mode = Window.MODE_WINDOWED
	win.size = res
	Platform.set_safe_insets_override(Vector4(0.0, 0.0, NOTCH_LADO, NOTCH_BASE) if invertida else Vector4(NOTCH_LADO, 0.0, 0.0, NOTCH_BASE))
	for i: int in 4:
		await get_tree().process_frame


## Captura numa subpasta de testes/capturas (cria a pasta).
func snap_em(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://testes/capturas/" + file_name.get_base_dir()))
	await snap(file_name)


## Devolve a lista de problemas da tela atual. `ctx`: {"raizes": [Node...], "controles": bool (controles de toque
## fazem parte da tela), "extras": Callable -> Array[{nome, rect, interativo}] }.
func _conferir(ctx: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var segura: Rect2 = Platform.get_safe_rect().grow(TOLERANCIA)
	var interativos: Array[Dictionary] = []
	# Áreas já ocupadas pelo HUD de toque: nenhum texto ou botão de outra tela pode ficar por cima/por baixo delas.
	var ocupados: Array[Dictionary] = []
	# ("modal": a tela cobre o jogo com um fundo escuro por cima do HUD — pausa, fim de run, escolha de habilidade.)
	for hud: Node in ([] if ctx.get("modal", false) else get_tree().root.find_children("*", "GameHUD", true, false)):
		if (hud as GameHUD).player_health_bar != null and (hud as GameHUD).player_health_bar.is_visible_in_tree():
			ocupados.append({"nome": "barras de status", "rect": mc.control_rect(MobileLayout.STATUS)})
	if mc._shown:
		for id: StringName in [MobileLayout.MOVE, MobileLayout.AIM, MobileLayout.DASH, MobileLayout.WEAPON, MobileLayout.COMMAND, MobileLayout.INTERACT]:
			if mc.is_control_active(id) or id in [MobileLayout.MOVE, MobileLayout.AIM]:
				ocupados.append({"nome": "controle %s" % id, "rect": mc.control_rect(id), "circulo": true})
		if mc._command_open():
			ocupados.append({"nome": "quadro de comandos", "rect": mc.control_rect(MobileLayout.BOARD)})
	if mc._pause_shown:
		ocupados.append({"nome": "botão de pausa", "rect": mc.control_rect(MobileLayout.PAUSE), "circulo": true})
	for raiz: Node in ctx.get("raizes", []):
		if not is_instance_valid(raiz):
			out.append("raiz inválida")
			continue
		var nos: Array[Node] = [raiz]
		nos.append_array(raiz.find_children("*", "Control", true, false))
		for no: Node in nos:
			var c: Control = no as Control
			if c == null or not c.is_visible_in_tree() or c.size.x <= 0.0 or c.size.y <= 0.0:
				continue
			if _transparente(c) or c.has_meta(&"fora_da_matriz"):
				continue
			var eh_interativo: bool = (c is BaseButton or c is Range or c is LineEdit) and c.mouse_filter != Control.MOUSE_FILTER_IGNORE and not (c is ScrollBar)
			var eh_texto: bool = c is Label or c is RichTextLabel
			var eh_caixa: bool = c is PanelContainer or c is Panel  # caixas de texto/avisos também não podem cobrir o HUD de toque
			if eh_caixa and not ctx.get("modal", false) and not ctx.get("editor", false) and not _do_hud(c) and c.get_global_rect().size.x < Platform.get_safe_rect().size.x * 0.95:
				for o: Dictionary in ocupados:
					if _toca(c.get_global_rect(), o):
						out.append("caixa em cima do HUD de toque: %s %s x %s %s" % [_nome(c), c.get_global_rect(), o["nome"], o["rect"]])
			if not (eh_interativo or eh_texto or c.is_in_group(&"hud_seguro")):
				continue
			var rect: Rect2 = _rect_visivel(c)
			if rect.size.x <= 0.0 or rect.size.y <= 0.0:
				continue  # todo cortado por um ScrollContainer: alcançável por rolagem
			var inteiro: Rect2 = c.get_global_rect()  # tamanho real (o alvo de toque rola junto com a página)
			if not segura.encloses(rect):
				out.append("fora da área segura: %s %s (segura %s)" % [_nome(c), rect, Platform.get_safe_rect()])
			if not _do_hud(c) and not ctx.get("editor", false):
				var area_texto: Rect2 = _rect_do_texto(c, rect)
				for o: Dictionary in ocupados:
					if _toca(area_texto, o):
						out.append("em cima do HUD de toque: %s %s x %s %s" % [_nome(c), area_texto, o["nome"], o["rect"]])
			if eh_texto or c is Button:
				var estouro: String = _estouro(c)
				if estouro != "":
					out.append("texto estoura: %s %s" % [_nome(c), estouro])
			if eh_interativo:
				if not (c is BaseButton and (c as BaseButton).disabled):
					if minf(inteiro.size.x, inteiro.size.y) < Platform.MIN_TOUCH - TOLERANCIA:
						out.append("alvo de toque pequeno: %s %s (mínimo %d)" % [_nome(c), inteiro.size, int(Platform.MIN_TOUCH)])
				interativos.append({"nome": _nome(c), "rect": rect, "no": c})
	# Controles de toque desenhados por código (joysticks, botões, quadro, barras).
	if ctx.get("controles", false):
		for id: StringName in MobileLayout.IDS:
			var ativo: bool = mc.is_control_active(id) if id not in [MobileLayout.STATUS, MobileLayout.BOARD, MobileLayout.MOVE, MobileLayout.AIM] else mc._shown
			if id == MobileLayout.BOARD:
				ativo = mc._shown and mc._command_open()
			if ctx.get("editor", false):
				ativo = true
			if not ativo:
				continue
			var r: Rect2 = mc.control_rect(id) if not ctx.get("editor", false) else (ctx["rect_editor"] as Callable).call(id)
			if not segura.encloses(r):
				out.append("fora da área segura: controle %s %s (segura %s)" % [id, r, Platform.get_safe_rect()])
			if id != MobileLayout.STATUS and id != MobileLayout.BOARD:
				interativos.append({"nome": "controle %s" % id, "rect": r, "circulo": true})
	elif mc._pause_shown:
		var r: Rect2 = mc.control_rect(MobileLayout.PAUSE)
		if not segura.encloses(r):
			out.append("fora da área segura: botão de pausa %s" % r)
		interativos.append({"nome": "controle pause", "rect": r, "circulo": true})
	if ctx.has("extras"):
		for extra: Dictionary in (ctx["extras"] as Callable).call():
			if not segura.encloses(extra["rect"]):
				out.append("fora da área segura: %s %s" % [extra["nome"], extra["rect"]])
			if extra.get("interativo", false):
				interativos.append(extra)
	# Nenhum par de interativos se sobrepõe.
	for i: int in interativos.size():
		for j: int in range(i + 1, interativos.size()):
			var a: Dictionary = interativos[i]
			var b: Dictionary = interativos[j]
			if a.has("no") and b.has("no") and ((a["no"] as Node).is_ancestor_of(b["no"]) or (b["no"] as Node).is_ancestor_of(a["no"])):
				continue
			if _sobrepoe(a, b):
				out.append("sobreposição: %s %s x %s %s" % [a["nome"], a["rect"], b["nome"], b["rect"]])
	return out


## O Control faz parte das barras de status (vida, carga, XP)?
func _do_hud(c: Control) -> bool:
	var no: Node = c
	while no != null:
		if no is XpBar or no is SpriteBar:
			return true
		no = no.get_parent()
	return false


## Para um Label, a área realmente ocupada pelas letras (um Label centralizado de largura total não "ocupa" a tela toda).
func _rect_do_texto(c: Control, rect: Rect2) -> Rect2:
	var l: Label = c as Label
	if l == null or l.text.strip_edges() == "":
		return rect
	var font: Font = l.get_theme_font(&"font")
	var tamanho: Vector2 = font.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, l.size.x if l.autowrap_mode != TextServer.AUTOWRAP_OFF else -1.0, l.get_theme_font_size(&"font_size"))
	tamanho = tamanho * l.get_global_transform().get_scale()
	tamanho.x = minf(tamanho.x, rect.size.x)
	tamanho.y = minf(tamanho.y, rect.size.y)
	var x: float = rect.position.x
	match l.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER: x = rect.get_center().x - tamanho.x * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT: x = rect.end.x - tamanho.x
	var y: float = rect.position.y
	match l.vertical_alignment:
		VERTICAL_ALIGNMENT_CENTER: y = rect.get_center().y - tamanho.y * 0.5
		VERTICAL_ALIGNMENT_BOTTOM: y = rect.end.y - tamanho.y
	return Rect2(Vector2(x, y), tamanho)


func _toca(area: Rect2, o: Dictionary) -> bool:
	var r: Rect2 = o["rect"]
	if o.get("circulo", false):
		var c: Vector2 = r.get_center()
		var perto: Vector2 = Vector2(clampf(c.x, area.position.x, area.end.x), clampf(c.y, area.position.y, area.end.y))
		return perto.distance_to(c) < r.size.x * 0.5 - TOLERANCIA
	return area.grow(-TOLERANCIA).intersects(r.grow(-TOLERANCIA))


func _sobrepoe(a: Dictionary, b: Dictionary) -> bool:
	var ra: Rect2 = a["rect"]
	var rb: Rect2 = b["rect"]
	if a.get("circulo", false) and b.get("circulo", false):
		return ra.get_center().distance_to(rb.get_center()) < (ra.size.x + rb.size.x) * 0.5 - TOLERANCIA
	return ra.grow(-TOLERANCIA).intersects(rb.grow(-TOLERANCIA))


## Retângulo global do Control cortado pelos ScrollContainers/clip dos ancestrais.
func _rect_visivel(c: Control) -> Rect2:
	var rect: Rect2 = c.get_global_rect()
	var pai: Node = c.get_parent()
	while pai != null:
		if pai is Control and ((pai as Control).clip_contents or pai is ScrollContainer):
			if not rect.intersects((pai as Control).get_global_rect()):
				return Rect2()
			rect = rect.intersection((pai as Control).get_global_rect())
		pai = pai.get_parent()
	return rect


func _transparente(c: Control) -> bool:
	var no: Node = c
	while no != null:
		if no is CanvasItem and (no as CanvasItem).modulate.a < 0.05:
			return true
		if no is CanvasItem and (no as CanvasItem).self_modulate.a < 0.05 and no == c:
			return true
		no = no.get_parent()
	return false


## "" se o texto cabe; senão descreve o estouro.
func _estouro(c: Control) -> String:
	if c is Label:
		var l: Label = c as Label
		if l.text.strip_edges() == "":
			return ""
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF or l.clip_text:
			if l.get_visible_line_count() < l.get_line_count() and l.max_lines_visible < 0:
				return "(%d de %d linhas visíveis)" % [l.get_visible_line_count(), l.get_line_count()]
			if l.clip_text and l.autowrap_mode == TextServer.AUTOWRAP_OFF and l.get_theme_font(&"font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size(&"font_size")).x > l.size.x + 1.0:
				return "(texto cortado na largura)"
		elif l.get_minimum_size().x > l.size.x + 1.0 or l.get_minimum_size().y > l.size.y + 1.0:
			return "(precisa %s, tem %s)" % [l.get_minimum_size(), l.size]
		var caixa: Control = _caixa(l)
		if caixa != null and not caixa.get_global_rect().grow(TOLERANCIA).encloses(_rect_visivel(l)):
			return "(sai da caixa %s: %s fora de %s)" % [caixa.name, l.get_global_rect(), caixa.get_global_rect()]
	elif c is Button:
		var b: Button = c as Button
		if not b.clip_text and b.get_minimum_size().x > b.size.x + 1.0:
			return "(precisa %s, tem %s)" % [b.get_minimum_size(), b.size]
		if b.clip_text and b.text != "" and b.get_theme_font(&"font").get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size(&"font_size")).x > b.size.x:
			return "(texto do botão cortado)"
	elif c is RichTextLabel:
		var r: RichTextLabel = c as RichTextLabel
		if not r.scroll_active and not r.fit_content and r.get_content_height() > int(r.size.y) + 2:
			return "(conteúdo %d px em caixa de %d px)" % [r.get_content_height(), int(r.size.y)]
		var caixa2: Control = _caixa(r)
		if caixa2 != null and not caixa2.get_global_rect().grow(TOLERANCIA).encloses(_rect_visivel(r)):
			return "(sai da caixa %s)" % caixa2.name
	return ""


func _caixa(c: Control) -> Control:
	var pai: Node = c.get_parent()
	while pai != null:
		if pai is PanelContainer or pai is Panel:
			return pai as Control
		pai = pai.get_parent()
	return null


func _nome(c: Control) -> String:
	var texto: String = str(c.get("text")).substr(0, 24) if "text" in c else ""
	return "%s[%s]%s" % [c.name, c.get_class(), (" \"%s\"" % texto) if texto != "" else ""]
