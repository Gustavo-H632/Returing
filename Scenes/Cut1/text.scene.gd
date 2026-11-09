extends RichTextLabel
## Texto da cutscene: mostra a frase do passo atual.

@export var texts: Array[String] = [  # Texto de cada passo da cutscene (editável no Inspector).
	"Ano 2150.\nHá 200 anos, os autômatos se voltaram contra nós.",
	"Precisamos voltar ao passado, e mudar o módulo central da IA",
	"Vamos para Londres, você deve acessar o computador central e resolver as os bugs lógicos.",
	"Depois disso, você poderá acabar com AEGIS.",
	"Agora vamos! Temos que retornar ao passado!",
]


## Escuta a troca de passo.
func _enter_tree() -> void:  # Quando o passo muda, mostra o texto correspondente.
	EventBus.cutscene_step_changed.connect(show_text)


## Informa quantos textos existem.
func _ready() -> void:  # Avisa quantos textos existem.
	EventBus.cutscene_content_registered.emit(texts.size())


## Desconecta do EventBus.
func _exit_tree() -> void:  # Só desconecta se ainda estiver conectado.
	if EventBus.cutscene_step_changed.is_connected(show_text):
		EventBus.cutscene_step_changed.disconnect(show_text)  # Desliga o sinal.


## Mostra o texto do passo (índice limitado).
func show_text(step: int = 0) -> void:
	if texts.is_empty():  # Sem textos: limpa o rótulo.
		text = ""
		return
	text = texts[clampi(step, 0, texts.size() - 1)]  # Usa o passo limitado ao tamanho da lista.
