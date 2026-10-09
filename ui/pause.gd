extends CanvasLayer

var _modo_mouse_anterior: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_preparar_filhos(self)

	$Continue_button.pressed.connect(resume)
	$Reset_button.pressed.connect(restart)
	$Bye_button.pressed.connect(go_to_menu)

func _preparar_filhos(no: Node) -> void:
	
	for filho in no.get_children():
		
		filho.process_mode = Node.PROCESS_MODE_INHERIT
		if filho is Control and not filho is BaseButton:
			filho.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_preparar_filhos(filho)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("Pause"):
		if get_tree().paused:
			resume()
		else:
			pause()

func pause() -> void:
	
	get_tree().paused = true
	visible = true
	_modo_mouse_anterior = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Continue_button.grab_focus()

func resume() -> void:

	get_tree().paused = false
	visible = false
	Input.mouse_mode = _modo_mouse_anterior

func restart() -> void:
	
	get_tree().paused = false
	Input.mouse_mode = _modo_mouse_anterior
	get_tree().reload_current_scene()

func go_to_menu() -> void:

	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://Scenes/Start/menu_start.tscn")
