# Bye_button
extends Button

func _ready() -> void:
	pressed.connect(on_button_pressed)

func on_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/Start/menu_start.tscn")
