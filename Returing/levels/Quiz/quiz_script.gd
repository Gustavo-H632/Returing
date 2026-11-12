class_name QuizQuestion
extends Resource
## Uma pergunta do quiz: o enunciado e a resposta esperada.

@export_multiline var pergunta: String = ""  # Texto da pergunta.
@export var resposta_correta: String = ""  # Resposta esperada.
