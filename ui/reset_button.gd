# Reset_button
extends Button

func _ready() -> void:
	pressed.connect(on_button_pressed)

func on_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
