extends SceneTree
## Auditoria da paleta e do tema dos menus: contraste mínimo de texto (4,5:1), ausência de branco/preto
## puros e carga do res://themes/main_theme.tres.
## Rodar: godot --headless --path . --script res://qa/palette_audit.gd

const MIN_CONTRAST: float = 4.5  # Contraste mínimo de texto (WCAG AA).
const THEME_PATH: String = "res://themes/main_theme.tres"  # Caminho do tema.


## Confere o contraste de cada texto sobre cada fundo, a ausência de branco e preto puros e a carga do tema.
func _initialize() -> void:
	var falhas: int = 0  # Contador de falhas.
	# Texto sobre as superfícies onde ele realmente aparece.
	var textos: Dictionary[String, Color] = {
		"TEXT": Palette.TEXT,
		"TEXT_DIM": Palette.TEXT_DIM,
		"ACCENT": Palette.ACCENT,
		"ACCENT_PRESSED": Palette.ACCENT_PRESSED,
		"DANGER": Palette.DANGER,
		"DISABLED_TEXT": Palette.DISABLED_TEXT,
	}
	var fundos: Dictionary[String, Color] = {  # Fundos possíveis.
		"BG": Palette.BG,
		"PANEL": Palette.PANEL,
		"PANEL_RAISED": Palette.PANEL_RAISED,
	}
	for nome_texto: String in textos:  # Para cada texto.
		for nome_fundo: String in fundos:  # Sobre cada fundo.
			var razao: float = Palette.contrast(textos[nome_texto], fundos[nome_fundo])  # Razão de contraste.
			# Texto desabilitado é isento da regra (WCAG), mas o resultado sai no log.
			var exigido: bool = nome_texto != "DISABLED_TEXT"  # Este texto precisa cumprir a regra?
			var ok: bool = razao >= MIN_CONTRAST  # Passou?
			# Marca mostrada no log.
			var marca: String = "ok" if ok else ("ABAIXO" if exigido else "abaixo (isento)")
			print("%-15s sobre %-13s %5.2f  %s" % [nome_texto, nome_fundo, razao, marca])  # Linha do relatório.
			if exigido and not ok:  # Só conta falha se for exigido.
				falhas += 1  # Soma a falha.
	# Nenhuma cor da paleta pode ser branco ou preto puro.
	for cor: Color in [Palette.BG, Palette.PANEL, Palette.PANEL_RAISED, Palette.BORDER, Palette.TEXT,
			Palette.TEXT_DIM, Palette.ACCENT, Palette.ACCENT_PRESSED, Palette.DANGER,
			Palette.DISABLED, Palette.DISABLED_TEXT]:
		if cor == Color.WHITE or cor == Color.BLACK:  # Cor pura encontrada.
			printerr("Cor pura (branco/preto) na paleta: ", cor)  # Avisa.
			falhas += 1  # Soma a falha.
	var tema: Theme = load(THEME_PATH) as Theme  # Carrega o tema.
	if tema == null or not tema is PixelTheme:  # Falhou ou não é um PixelTheme.
		printerr("Falha ao carregar ", THEME_PATH, " como PixelTheme")  # Avisa.
		falhas += 1  # Soma a falha.
	else:  # Tema carregado.
		# Confere se tem os estilos esperados.
		if not tema.has_stylebox(&"normal", &"Button") or not tema.has_stylebox(&"slider", &"HSlider"):
			printerr("Tema sem estilos esperados (Button/normal ou HSlider/slider)")  # Avisa.
			falhas += 1  # Soma a falha.
	print("palette_audit: %d falha(s)" % falhas)  # Resultado.
	quit(1 if falhas > 0 else 0)  # Sai com código de erro se algo falhou.
