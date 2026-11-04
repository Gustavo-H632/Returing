extends Node2D
## Fase 2: o terminal abre o quiz e o quiz fecha a fase.

## Próxima cena depois do quiz. Vazio = última fase.
@export_file("*.tscn") var next_scene: String = ""
## Pausa entre a mensagem final do quiz e a tela de fim.
@export_range(0.0, 10.0, 0.1, "or_greater") var complete_delay: float = 1.0

@export_group("Nós da cena")
@export var quiz: QuizScreen
@export var terminal: QuizTerminal

var _quiz_done: bool = false
## True depois que o jogador morreu no quiz.
var _quiz_failed: bool = false


func _ready() -> void:
	if quiz == null or terminal == null:
		var missing: PackedStringArray = []
		if quiz == null: missing.append("quiz")
		if terminal == null: missing.append("terminal")
		push_error("Fase2: referências não atribuídas no Inspector: %s" % ", ".join(missing))
		return
	quiz.hide()
	quiz.process_mode = Node.PROCESS_MODE_ALWAYS  # o quiz roda com o jogo pausado
	terminal.terminal_ativado.connect(_open_quiz)
	quiz.quiz_terminado.connect(_on_quiz_finished)
	quiz.quiz_falhou.connect(_on_quiz_failed)


func _open_quiz() -> void:
	if _quiz_done or _quiz_failed or quiz.visible:
		return
	get_tree().paused = true
	quiz.iniciar()


## O jogador morreu no quiz.
func _on_quiz_failed() -> void:
	_quiz_failed = true
	get_tree().paused = false


## Libera o jogo e, depois de uma pausa, anuncia a fase concluída pelo EventBus.
func _on_quiz_finished() -> void:
	_quiz_done = true
	terminal.mark_completed()
	get_tree().paused = false
	var timer: SceneTreeTimer = CombatUtils.game_timer(self, complete_delay)
	if timer != null:
		timer.timeout.connect(_complete_level)


func _complete_level() -> void:
	EventBus.level_completed.emit(next_scene)
