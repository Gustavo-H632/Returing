extends TextureRect

var image_exibit: Array[Texture2D] = [
	preload("res://Sprites/Cutscenes/London.png"), 
	preload("res://Sprites/Cutscenes/pxArt.png"),
	preload("res://Sprites/Tilemap/TheComputer.png"),
	preload("res://icon.svg"),
	preload("res://Sprites/Cutscenes/Lab-Turing.png")
]

func _ready() -> void:
	show_image()

func show_image() -> void :
	texture = image_exibit[Global.i]

func _on_button_pressed() -> void:
	
	if Global.i < 6 :
		show_image()
	else :
		get_tree().change_scene_to_file("res://Scenes/fase_1.tscn")
