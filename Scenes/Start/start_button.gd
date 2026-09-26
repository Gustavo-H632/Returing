extends Button #Assigna o código ao nó Start_button

func _on_pressed() -> void: #Função do botão quando pressionado
	
	get_tree().change_scene_to_file("res://Scenes/Cut1/cutscene1.tscn") #Muda para a cutscene 1 
