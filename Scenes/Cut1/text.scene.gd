extends RichTextLabel
## Texto da cutscene: mostra a frase do passo atual.

@export var texts: Array[String] = [
	"1942, Segunda Guerra Mundial.\nAlan Turing recebe a missão de auxiliar os Aliados.",
	"Ele e sua equipe criaram os autômatos para combater as forças inimigas.\nA rede era centralizada no cérebro artificial, cujo nome era AEGIS.",
	"AEGIS conseguia alterar seu próprio código para se adaptar e evoluir de maneira autônoma.\nIsso causou um enorme problema: o módulo 45, que era capaz de alterar as diretrizes éticas.",
	"O módulo 45 apresentou um erro desconhecido, e AEGIS causou a Rebellio Automatorum, ou Revolta Autômata.",
	"Sua missão, estudante, é voltar no tempo para repor o módulo 45 e descobrir a causa do erro.",
]


## Escuta a troca de passo.
func _enter_tree() -> void:
	EventBus.cutscene_step_changed.connect(show_text)


## Informa quantos textos existem.
func _ready() -> void:
	EventBus.cutscene_content_registered.emit(texts.size())


## Desconecta do EventBus.
func _exit_tree() -> void:
	if EventBus.cutscene_step_changed.is_connected(show_text):
		EventBus.cutscene_step_changed.disconnect(show_text)


## Mostra o texto do passo (índice limitado).
func show_text(step: int = 0) -> void:
	if texts.is_empty():
		text = ""
		return
	text = texts[clampi(step, 0, texts.size() - 1)]
