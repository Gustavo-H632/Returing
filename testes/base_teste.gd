class_name TesteBase
extends Node
## Base dos testes automáticos: verificações, espera de quadros, toques simulados (InputEventScreenTouch/Drag),
## carregar uma fase e tirar capturas. Cada teste estende esta classe e implementa `rodar()`.

const VIEW_WINDOW: Vector2i = Vector2i(1500, 664)  # Janela do print de referência.

var fails: int = 0  # Verificações que falharam.
var checks: int = 0  # Total de verificações.
var level: Node = null  # Fase carregada por `load_level`.


## Implementado pelo teste.
func rodar() -> void:
	pass


## Confere uma condição, mostra o resultado e conta a falha.
func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("  ok   ", label)
	else:
		fails += 1
		print("  FAIL ", label)


## Falha explícita (uso em ramos que não deveriam acontecer).
func fail(label: String) -> void:
	check(false, label)


## Espera `n` quadros de física.
func frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


## Espera `seconds` segundos de jogo.
func seconds(value: float) -> void:
	await get_tree().create_timer(value, true, true).timeout


## Espera `value` segundos de relógio real (ignora a câmera lenta do modo comando e a pausa).
func real_seconds(value: float) -> void:
	await get_tree().create_timer(value, true, false, true).timeout


## Gravidade em tela (m/s²) de um celular segurado a 40 graus, inclinado `roll` (borda direita desce) e `pitch`
## (borda de cima desce) graus. É o que o acelerômetro entrega no Android e no iOS com o Godot 4.x.
static func gravity(roll: float = 0.0, pitch: float = 0.0) -> Vector3:
	var p: float = deg_to_rad(-50.0 + pitch)
	var r: float = deg_to_rad(roll)
	return Vector3(sin(r), cos(r) * sin(p), -cos(r) * cos(p)) * 9.8


## Vetor do acelerômetro para inclinar em `dir` (valor de `AbilityData.Dir`) 26 graus.
static func tilt_vector(dir: int) -> Vector3:
	match dir:
		AbilityData.Dir.UP: return gravity(0.0, 26.0)
		AbilityData.Dir.DOWN: return gravity(0.0, -26.0)
		AbilityData.Dir.LEFT: return gravity(-26.0, 0.0)
		AbilityData.Dir.RIGHT: return gravity(26.0, 0.0)
	return gravity()


## Posição lógica (coordenadas do jogo) -> pixel da janela (o stretch do projeto muda a escala).
func to_window(pos: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * pos


## Simula um toque (apertar ou soltar) na posição lógica.
func touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = to_window(pos)
	e.pressed = pressed
	Input.parse_input_event(e)


## Simula o arrastar de um dedo.
func drag(index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = to_window(pos)
	Input.parse_input_event(e)


## Toca num ponto e solta depois de `hold` quadros.
func tap(index: int, pos: Vector2, hold: int = 3) -> void:
	touch(index, pos, true)
	await frames(hold)
	touch(index, pos, false)
	await frames(2)


## Deixa a janela no tamanho do print (1500x664).
func set_window() -> void:
	var win: Window = get_tree().root
	win.mode = Window.MODE_WINDOWED
	win.size = VIEW_WINDOW
	await get_tree().process_frame
	await get_tree().process_frame


## Carrega e instancia uma cena como cena atual (como no jogo: tiros e efeitos nascem sob a fase).
func load_level(path: String) -> Node:
	level = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	return level


## Descarrega a fase atual (se houver).
func unload_level() -> void:
	if is_instance_valid(level):
		level.queue_free()
		await get_tree().process_frame
	level = null


## Impede que o `Global` troque de cena de verdade (a carga em thread da cena seguinte, com o teste já saindo,
## gera erros de saída que não são do jogo) e devolve a lista onde os pedidos de troca são anotados.
func block_scene_changes() -> Array[String]:
	var requests: Array[String] = []
	if EventBus.scene_change_requested.is_connected(Global.change_scene):
		EventBus.scene_change_requested.disconnect(Global.change_scene)
	EventBus.scene_change_requested.connect(func(path: String) -> void: requests.append(path))
	return requests


## Salva uma captura da janela em `res://testes/capturas/<nome>.png` (só funciona com renderizador, não em `--headless`).
func snap(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":  # sem renderizador não há imagem (e frame_post_draw nunca dispara)
		return
	await RenderingServer.frame_post_draw
	var image: Image = get_tree().root.get_texture().get_image()
	if image == null or image.is_empty():
		print("  (sem imagem: renderizador dummy) ", file_name)
		return
	var path: String = "res://testes/capturas/%s.png" % file_name
	image.save_png(path)
	print("  captura ", path)


## Jogador da fase carregada.
func player() -> Player:
	var found: Array[Node] = get_tree().get_nodes_in_group(&"player")
	return found[0] as Player if not found.is_empty() else null


## Lista os tiros do jogador que estão em uso.
func active_projectiles() -> Array[PlayerProjectile]:
	var out: Array[PlayerProjectile] = []
	for n: Node in get_tree().root.find_children("*", "PlayerProjectile", true, false):
		var p := n as PlayerProjectile
		if p.is_in_use():
			out.append(p)
	return out
