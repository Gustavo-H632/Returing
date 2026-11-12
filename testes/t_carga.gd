extends TesteBase
## Carrega TODOS os scripts e cenas do projeto (menos addons): pega erro de parse, caminho quebrado e
## maiúsculas/minúsculas erradas nos recursos.

const IGNORE: Array[String] = ["res://addons/", "res://.godot/", "res://build/", "res://testes/capturas/"]


func rodar() -> void:
	var files: Array[String] = []
	_collect("res://", files)
	var bad: int = 0
	for path: String in files:
		var res: Resource = ResourceLoader.load(path)
		if res == null:
			bad += 1
			print("  não carregou: ", path)
	check(bad == 0, "todos os %d scripts/cenas carregam" % files.size())
	# Cenas novas do modo celular.
	for path: String in ["res://testes/executor.tscn", "res://abilities/ui/abilities_ui.tscn", "res://ui/pause.tscn"]:
		var packed: PackedScene = load(path) as PackedScene
		check(packed != null and packed.instantiate() != null, "instancia " + path)
	# Assets gerados existem e são importados (carregam como textura).
	for name: String in ["btn_base.png", "ic_sword.png", "ic_swap.png", "ic_command.png", "ic_pause.png", "ic_dash.png",
			"stick_base.png", "stick_thumb.png", "board_frame.png", "arrow_up.png", "tilt_ring.png", "phone_neutral.png",
			"dpad_base.png", "glow_0.png", "joy_demo_0.png"]:
		check(MobileDraw.tex(name) != null, "asset gerado " + name)
	_check_paths()
	check(ResourceLoader.exists("res://referencias/mobile_layout.png"), "referencia mobile_layout.png")
	check(ResourceLoader.exists("res://referencias/mobile_layout_zonas.png"), "referencia mobile_layout_zonas.png")


## Confere, em todo texto do projeto, que cada caminho `res://...` existe com as MESMAS maiúsculas/minúsculas
## (Linux e macOS diferenciam; o Windows não) e que não há caminho absoluto de disco.
func _check_paths() -> void:
	var texts: Array[String] = []
	_collect_text("res://", texts)
	# Em scripts só valem os caminhos de `preload("...")`/`load("...")` (o resto pode ser sondagem opcional ou comentário);
	# em cenas, recursos, project.godot e presets, todo `res://...`.
	var regex_gd: RegEx = RegEx.new()
	regex_gd.compile(r"(?:preload|load)\(\s*\"(res://[^\"]+)\"")
	var regex_all: RegEx = RegEx.new()
	regex_all.compile(r"\"(res://[^\"]+\.[A-Za-z0-9]+)\"")
	var absolute: RegEx = RegEx.new()
	absolute.compile(r"[\"'](?:[A-Za-z]:[\\/]|/home/|/Users/)")
	var cache: Dictionary = {}
	var wrong: Array[String] = []
	var absolutes: Array[String] = []
	for path: String in texts:
		if path.begins_with("res://qa/") or path.begins_with("res://tests/"):
			continue  # scripts de depuração antigos (apontam para arquivos de teste temporários)
		var content: String = FileAccess.get_file_as_string(path)
		if absolute.search(content) != null and not path.begins_with("res://testes/") and not path.begins_with("res://tools/"):
			absolutes.append(path)
		var regex: RegEx = regex_gd if path.ends_with(".gd") else regex_all
		for found: RegExMatch in regex.search_all(content):
			var ref: String = found.get_string(1)
			if ref.ends_with("/") or ref.contains("%"):
				continue
			if not _exact_case_exists(ref, cache):
				wrong.append("%s -> %s" % [path, ref])
	for line: String in wrong.slice(0, 15):
		print("  caminho com problema: ", line)
	check(wrong.is_empty(), "todos os caminhos res:// existem com maiúsculas/minúsculas exatas (%d problemas)" % wrong.size())
	check(absolutes.is_empty(), "nenhum caminho absoluto de disco no código (%s)" % [absolutes])


func _exact_case_exists(ref: String, cache: Dictionary) -> bool:
	var parts: PackedStringArray = ref.trim_prefix("res://").split("/")
	var dir: String = "res://"
	for i: int in parts.size():
		var name: String = parts[i]
		if not cache.has(dir):
			cache[dir] = [DirAccess.get_directories_at(dir), DirAccess.get_files_at(dir)]
		var listing: Array = cache[dir]
		var is_last: bool = i == parts.size() - 1
		var names: PackedStringArray = listing[1] if is_last else listing[0]
		if is_last:
			if not names.has(name):
				# Arquivos .import/.uid/.png importados: o original precisa existir.
				return false
		elif not names.has(name):
			return false
		dir = dir.path_join(name) if not is_last else dir
	return true


func _collect_text(dir: String, out: Array[String]) -> void:
	for prefix: String in IGNORE:
		if dir.begins_with(prefix):
			return
	for sub: String in DirAccess.get_directories_at(dir):
		_collect_text(dir.path_join(sub), out)
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".gd") or file.ends_with(".tscn") or file.ends_with(".tres") or file == "project.godot" or file == "export_presets.cfg":
			out.append(dir.path_join(file))


func _collect(dir: String, out: Array[String]) -> void:
	for prefix: String in IGNORE:
		if dir.begins_with(prefix):
			return
	for sub: String in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(sub), out)
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".gd") or file.ends_with(".tscn"):
			out.append(dir.path_join(file))
