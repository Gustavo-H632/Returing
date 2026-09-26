extends RichTextLabel #Conecta ao texto da Cutscene 1

var text_exibit: Array[String] = [  #Aqui tem o vetor com os textos (definitivo)
	"1942, Segunda Guerra Mundial.\nAlan Turing recebe a missão de auxiliar os aliados.",
	"Ele e sua equipe criaram os autômatos para combater as forças inimigas.\nA rede era centralizada no cérebro artificial, cujo nome era Aegis",
	"Aegis coseguia alterar seu próprio código para se adaptar e evoluir de maneira autônoma.\nIsso causou um enorme problema: O módulo 45, que capaz de alterar as diretrizes éticas.",
	"O módulo 45 apresentou um erro desconhecido, e AEGIS causou a Rebellio Automatorum, ou Revolta Autômata.",
	"Sua missão, estudante, é voltar no tempo para repor o módulo 45 e descobrir a causa do erro."
]

func _ready() -> void: #Tem que inicializar para exibir imagem
	
	show_text() #Chama a função de mostar texto

func show_text() -> void : #Função de chamar texto
	
	text = text_exibit[Global.i]

func _on_button_pressed() -> void:
	
	if Global.i < 5 : #Só mostra a imagem quando o índice for menor ou igual ao vetor
		
		show_text()# Exibe o texto
