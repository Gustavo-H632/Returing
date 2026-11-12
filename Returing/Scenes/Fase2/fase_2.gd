extends Node2D
## Fase 2: o terminal abre o quiz e o quiz fecha a fase.

## Próxima cena depois do quiz. Vazio = última fase.
@export_file("*.tscn") var next_scene: String = ""
## Pausa entre a mensagem final do quiz e a tela de fim.
@export_range(0.0, 10.0, 0.1, "or_greater") var complete_delay: float = 1.0

@export_group("Nós da cena")
@export var quiz: QuizScreen  # Tela do quiz.
@export var terminal: QuizTerminal  # Terminal que abre o quiz.

var _quiz_done: bool = false  # True depois que o quiz terminou.
## True depois que o jogador morreu no quiz.
var _quiz_failed: bool = false


## Confere as referências e liga o terminal e o quiz: o terminal abre o quiz e o fim do quiz conclui a fase.
func _ready() -> void:
	if quiz == null or terminal == null:  # Sem as referências a fase não funciona.
		var missing: PackedStringArray = []  # Lista do que falta.
		if quiz == null: missing.append("quiz")
		if terminal == null: missing.append("terminal")
		# Avisa o erro no console.
		push_error("Fase2: referências não atribuídas no Inspector: %s" % ", ".join(missing))
		return
	quiz.hide()  # O quiz começa escondido.
	quiz.process_mode = Node.PROCESS_MODE_ALWAYS  # o quiz roda com o jogo pausado
	terminal.terminal_ativado.connect(_open_quiz)  # O terminal abre o quiz.
	quiz.quiz_terminado.connect(_on_quiz_finished)  # Quiz concluído.
	quiz.quiz_falhou.connect(_on_quiz_failed)  # Jogador morreu no quiz.


## Abre o quiz: pausa o jogo e mostra a primeira pergunta (só uma vez e só se o quiz está fechado).
func _open_quiz() -> void:
	# Já terminou, o jogador morreu ou o quiz já está aberto: ignora.
	if _quiz_done or _quiz_failed or quiz.visible:
		return
	get_tree().paused = true  # Pausa o jogo.
	quiz.iniciar()  # Inicia o quiz.


## O jogador morreu no quiz.
# Marca que o jogador morreu e despausa (o game over segue pelo EventBus).
func _on_quiz_failed() -> void:
	_quiz_failed = true  # Marca a falha.
	get_tree().paused = false  # Despausa.


## Libera o jogo e, depois de uma pausa, anuncia a fase concluída pelo EventBus.
func _on_quiz_finished() -> void:  # Marca como concluído.
	_quiz_done = true
	terminal.mark_completed()  # O terminal mostra "CONCLUÍDO".
	get_tree().paused = false  # Despausa.
	# Timer de jogo para a pausa antes do fim.
	var timer: SceneTreeTimer = CombatUtils.game_timer(self, complete_delay)
	if timer != null:
		timer.timeout.connect(_complete_level)  # Ao fim do timer, conclui a fase.


## Anuncia a fase concluída pelo EventBus (a HUD mostra o fim de jogo ou o botão continuar).
func _complete_level() -> void:
	EventBus.level_completed.emit(next_scene)  # Avisa a conclusão e a próxima cena.
