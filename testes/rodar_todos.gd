extends SceneTree
## Roda TODA a suíte de testes automáticos (cada teste num processo novo do Godot, em headless) e sai com
## código 0 se tudo passou ou 1 se algo falhou.
##
##   godot --headless --path . --script res://testes/rodar_todos.gd
##   godot --headless --path . --script res://testes/rodar_todos.gd -- --filtro=tutorial     (só os que casam)
##
## Falha também quando o console mostra erro de script (SCRIPT ERROR, Parse Error...) ou qualquer linha
## `ERROR:`/`WARNING:` que não seja ruído conhecido de saída do Godot (veja IGNORAR).
## As capturas de tela (precisam de renderizador) são geradas por `testes/capturar_todas.gd`.

const MOBILE_CFG: String = "--mobile-config=user://teste_layout.cfg"

## [script, argumentos extras, descrição]
const SUITE: Array = [
	["t_carga.gd", [], "carrega todos os scripts e cenas (computador)"],
	["t_carga.gd", ["--mobile"], "carrega todos os scripts e cenas (celular)"],
	["t_equilibrio.gd", [], "EQUILÍBRIO: dificuldade igual à base (testes/equilibrio_base.json)"],
	["t_ondas.gd", [], "waves com 50% dos inimigos (max(1, ceil(n x 0,5))), chefes = 1"],
	["t_menu.gd", [], "tela inicial sem dicas, botões e foco (computador)"],
	["t_menu.gd", ["--mobile"], "tela inicial sem dicas, botões e foco (celular)"],
	["t_tilt_logico.gd", [], "função pura do acelerômetro (plataformas x orientações x direções)"],
	["t_tilt_input.gd", [], "TiltInput: zona morta, histerese, cooldown, calibração e sensor ausente"],
	["t_pc.gd", [], "REGRESSÃO no computador: sem controles de toque, teclado/mouse como antes"],
	["t_tutorial_pc.gd", [], "REGRESSÃO do tutorial no computador"],
	["t_controles.gd", ["--mobile"], "joysticks, botões, multitouch, pausa e layout do print"],
	["t_interagir.gd", ["--mobile"], "botão temporário E: aparece/some com o alcance, anima e interage (terminal e labirinto)"],
	["t_comando_mobile.gd", ["--mobile"], "modo comando por inclinação, quadro de comandos e D-pad de fallback"],
	["t_layout.gd", ["--mobile", MOBILE_CFG], "editor de HUD: arrastar, pinça, limites, restaurar e salvar"],
	["t_layout_reinicio.gd", ["--mobile", MOBILE_CFG], "editor de HUD: layout restaurado depois de reiniciar"],
	["t_config.gd", ["--mobile", "--mobile-config=user://teste_config.cfg"], "configurações do acelerômetro e Calibrar"],
	["t_resolucoes.gd", ["--mobile", "--mobile-config=user://teste_resolucoes.cfg"], "matriz de resoluções: 23 telas x 8 resoluções x 2 orientações com notch (seção 15.3)"],
	["t_cutscene.gd", ["--mobile"], "botão 'Avançar cutscene'"],
	["t_tutorial_mobile.gd", ["--mobile"], "tutorial mobile completo (6 passos, inclinação)"],
	["t_skip_mobile.gd", ["--mobile"], "'Pular tutorial' responde ao toque"],
]

## Linhas de saída que o Godot imprime ao fechar e que NÃO são do jogo (vazamentos de saída do áudio do menu
## principal, que existiam antes deste trabalho, e do renderizador dummy).
const IGNORAR: Array[String] = [
	"ObjectDB instances were leaked at exit", "resources still in use at exit", "at: cleanup (core/object/object.cpp",
	"at: clear (core/io/resource.cpp", "RIDs of type", "RID allocations of type", "at: _free_rids",
	"Godot Engine v", "Vulkan", "OpenGL", "WARNING: Pages in use", "at: ~PagedAllocator",
]


var _summary_regex: RegEx = null


func _init() -> void:
	_summary_regex = RegEx.new()
	_summary_regex.compile("(\\d+) verifica\\D*, (\\d+) falhas")
	var filtro: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--filtro="):
			filtro = arg.trim_prefix("--filtro=")
	var project: String = ProjectSettings.globalize_path("res://")
	var exe: String = OS.get_executable_path()
	var results: Array[Dictionary] = []
	var started: int = Time.get_ticks_msec()
	for entry: Array in SUITE:
		var script: String = entry[0]
		var extra: Array = entry[1]
		if filtro != "" and not (script + " " + " ".join(extra)).contains(filtro):
			continue
		var args: PackedStringArray = ["--headless", "--path", project, "res://testes/executor.tscn", "--", "--teste=res://testes/" + script]
		for e: String in extra:
			args.append(e)
		print("\n>>> %s %s  (%s)" % [script, " ".join(extra), entry[2]])
		var output: Array = []
		var t0: int = Time.get_ticks_msec()
		var code: int = OS.execute(exe, args, output, true)
		var text: String = "\n".join(output)
		var verdict: Dictionary = _analisar(text, code)
		verdict["nome"] = "%s %s" % [script, " ".join(extra)]
		verdict["segundos"] = float(Time.get_ticks_msec() - t0) / 1000.0
		results.append(verdict)
		for line: String in verdict["problemas"]:
			print("    ! ", line)
		print("    -> %s (%d verificações, %d falhas, %.0fs)" % ["OK" if verdict["ok"] else "FALHOU", verdict["checks"], verdict["fails"], verdict["segundos"]])
		if not verdict["ok"]:
			print(_cauda(text, 25))
	var failed: int = 0
	var total_checks: int = 0
	print("\n================ RESUMO ================")
	for r: Dictionary in results:
		total_checks += int(r["checks"])
		if not r["ok"]:
			failed += 1
		print("%s  %-60s %4d verificações  %.0fs" % ["OK    " if r["ok"] else "FALHOU", r["nome"], r["checks"], r["segundos"]])
	print("Testes: %d, falhas: %d, verificações: %d, tempo: %.0fs" % [results.size(), failed, total_checks, float(Time.get_ticks_msec() - started) / 1000.0])
	quit(1 if failed > 0 or results.is_empty() else 0)


## Lê a saída de um teste: contagem de verificações/falhas e problemas no console.
func _analisar(text: String, code: int) -> Dictionary:
	var problems: Array[String] = []
	var checks: int = 0
	var fails: int = 0
	var summary_found: bool = false
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line.is_empty():
			continue
		if line.begins_with("=== ") and line.ends_with(" ==="):
			# "=== t_x.gd: 12 verificações, 0 falhas ===" (a saída do Windows pode vir com acentos trocados: só os números contam).
			var found: RegExMatch = _summary_regex.search(line)
			if found != null:
				summary_found = true
				checks = int(found.get_string(1))
				fails = int(found.get_string(2))
				continue
		if line.begins_with("FAIL") or line.begins_with("  FAIL") or line.contains(" FAIL "):
			problems.append(line)
			continue
		var ignore: bool = false
		for pattern: String in IGNORAR:
			if line.contains(pattern):
				ignore = true
				break
		if ignore:
			continue
		if line.begins_with("SCRIPT ERROR") or line.begins_with("ERROR:") or line.begins_with("WARNING:") \
				or line.begins_with("USER ERROR") or line.begins_with("USER WARNING") or line.contains("Parse Error"):
			problems.append(line)
	if not summary_found:
		problems.append("o teste não terminou (sem linha de resumo; código de saída %d)" % code)
	if code != 0:
		problems.append("código de saída %d" % code)
	return {"ok": problems.is_empty() and fails == 0, "checks": checks, "fails": fails, "problemas": problems}


## Últimas linhas do texto (para mostrar quando um teste falha).
func _cauda(text: String, count: int) -> String:
	var lines: PackedStringArray = text.split("\n")
	var start: int = maxi(lines.size() - count, 0)
	return "\n".join(lines.slice(start))
