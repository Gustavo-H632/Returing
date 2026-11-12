extends SceneTree
## Uso: godot --path . --script tests/shot.gd -- <cena> <png> [frames]

## Carrega a cena pedida, espera alguns quadros e salva uma captura.
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()  # Argumentos.
	var scene: PackedScene = load(args[0])  # Carrega a cena.
	var node: Node = scene.instantiate()  # Cria a instância.
	root.add_child(node)  # Entra na árvore.
	var frames: int = int(args[2]) if args.size() > 2 else 40  # Quadros de espera (padrão 40).
	_run(args[1], frames)  # Roda a captura.

## Espera os quadros, salva a imagem e fecha.
func _run(out: String, frames: int) -> void:
	for i in frames:  # Espera.
		await process_frame
	var img: Image = root.get_texture().get_image()  # Imagem da janela.
	img.save_png(out)  # Salva.
	print("saved ", out, " ", img.get_size())  # Avisa.
	quit()  # Fecha.
