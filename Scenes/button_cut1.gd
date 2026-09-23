extends Button #Botão da cutscene 1

func _ready() -> void:
	
	Global.i = 0 #Define o índice global

func _on_button_pressed() -> void: #Serve para conectar o _on_button_pressed aos outros nodes
	
	pass #A incrementação ocorre no Back_cut1
