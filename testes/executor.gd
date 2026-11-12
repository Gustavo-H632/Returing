extends Node
## Executor de um teste: `godot --path . res://testes/executor.tscn -- --teste=res://testes/<teste>.gd [--mobile] ...`
## Carrega o script (que estende `TesteBase`), espera o `rodar()` e sai com código 0 (tudo ok) ou 1 (falhas).
## Quem roda a suíte inteira é o `rodar_todos.gd`.

const TIMEOUT_SECONDS: float = 240.0  # Segurança: um teste travado não pode prender a suíte.


func _ready() -> void:
	_go.call_deferred()


func _go() -> void:
	var script_path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--teste="):
			script_path = arg.trim_prefix("--teste=")
	if script_path.is_empty() or not ResourceLoader.exists(script_path):
		printerr("executor: informe --teste=<caminho do script de teste em testes>")
		get_tree().quit(2)
		return
	var teste: TesteBase = (load(script_path) as GDScript).new() as TesteBase
	teste.name = "Teste"
	add_child(teste)
	var timer: SceneTreeTimer = get_tree().create_timer(TIMEOUT_SECONDS, true, false, true)
	timer.timeout.connect(func() -> void:
		printerr("executor: TIMEOUT em %s" % script_path)
		get_tree().quit(3))
	await teste.rodar()
	print("=== %s: %d verificações, %d falhas ===" % [script_path.get_file(), teste.checks, teste.fails])
	get_tree().quit(1 if teste.fails > 0 else 0)
