extends SceneTree
## Gera as capturas de tela em `res://testes/capturas/` (jogo, quadro de comandos, cada passo do tutorial mobile,
## editor de HUD e botão "Avançar cutscene") rodando os testes com JANELA (precisa de renderizador).
## No Linux sem monitor: xvfb-run -a godot --path . --rendering-driver opengl3 --script res://testes/capturar_todas.gd
##
##   godot --path . --script res://testes/capturar_todas.gd

const SUITE: Array = [
	["cap_jogo.gd", ["--mobile"]],
	["t_comando_mobile.gd", ["--mobile"]],
	["t_layout.gd", ["--mobile", "--mobile-config=user://teste_layout.cfg"]],
	["t_cutscene.gd", ["--mobile"]],
	["t_tutorial_mobile.gd", ["--mobile"]],
]


func _init() -> void:
	var project: String = ProjectSettings.globalize_path("res://")
	var failed: int = 0
	for entry: Array in SUITE:
		var args: PackedStringArray = ["--path", project, "res://testes/executor.tscn", "--", "--teste=res://testes/" + entry[0]]
		for e: String in entry[1]:
			args.append(e)
		print(">>> capturas: ", entry[0])
		var output: Array = []
		var code: int = OS.execute(OS.get_executable_path(), args, output, true)
		if code != 0:
			failed += 1
			print("    falhou (código %d)" % code)
	print("capturas geradas em res://testes/capturas/ (falhas: %d)" % failed)
	quit(1 if failed > 0 else 0)
