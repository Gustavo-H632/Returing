extends TextureRect #Background da cutscene

var image_exibit: Array[Texture2D] = [ #Vetor das imagens (provisórias)
	
	preload("res://Sprites/Cutscenes/London.png"), 
	preload("res://Sprites/Cutscenes/pxArt.png"),
	preload("res://Sprites/Tilemap/TheComputer.png"),
	preload("res://icon.svg"),
	preload("res://Sprites/Cutscenes/Lab-Turing.png")
	
]

func _ready() -> void: #Inicializa as imagens
	
	show_image() #Mostra a imagem de fundo

func show_image() -> void :
	
	texture = image_exibit[Global.i]

func _on_button_pressed() -> void: #Botão avançar pressionado
	
	Global.i += 1 #Ele incrementa aqui, não no botão
	
	if Global.i < 5 : #Se o índice for menor que o vetor
		
		show_image() #Função de mostrar imagem
		
	else : #Acabou a cena
		
		get_tree().change_scene_to_file("res://Scenes/fase_1.tscn") #Vai para a cena da fase 1
