extends RichTextLabel

var text_exibit: Array[String] = [
	"1942, Segunda Guerra Mundial.\nAlan Turing recebe a missão de ",
	"Ele e sua equipe criaram os autômatos para combater as forças inimigas.\nA rede era centralizada no cérebro artificial, cujo nome era Aegis",
	"Aegis coseguia alterar seu próprio código para se adaptar e evoluir de maneira autônoma.\nIsso causou um enorme problema: O módulo 45, que capaz de alterar as diretrizes éticas.",
	"O módulo 45 apresentou um erro desconhecido, e AEGIS causou a Rebellio Automatorum, ou Revolta Autômata.",
	"Sua missão, estudante, é voltar no tempo para repor o módulo 45 e descobrir a causa do erro."
]

func _ready() -> void:
	Global.i = 0
	show_text()

func show_text() -> void :
	text = text_exibit[Global.i]

func _on_button_pressed() -> void:
	Global.i += 1
	
	if Global.i < 5 :
		show_text()
	else :
		get_tree().change_scene_to_file("res://Scenes/fase_1.tscn")
