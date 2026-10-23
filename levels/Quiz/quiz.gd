class_name QuizScreen
extends Control
## Quiz da Fase 2, que roda com o jogo pausado.

## Emitido depois da mensagem final, com o quiz já escondido.
signal quiz_terminado
## Emitido quando o jogador morre durante o quiz, com o quiz já escondido.
signal quiz_falhou
## Cada questão registrada.
signal resposta_registrada(indice: int, correta: bool, motivo: StringName)

## Momentos do quiz.
enum Phase {
	## Fechado (antes de iniciar() ou depois de terminar/falhar).
	CLOSED,
	## Pergunta na tela, cronômetro rodando, campo de resposta liberado.
	ANSWERING,
	## Feedback de acerto/erro na tela (campo travado), esperando a próxima pergunta.
	FEEDBACK,
	## Mensagem final na tela.
	ENDING,
}

const COLOR_RIGHT: Color = Color.GREEN
const COLOR_WRONG: Color = Color.RED
const COLOR_TIMER_OK: Color = Color(0.35, 0.85, 0.45)
const COLOR_TIMER_ALERT: Color = Color.RED
const FINAL_MESSAGE: String = "Sistemas de defesa desativados! AEGIS está livre"
## Tempo que a mensagem final fica na tela antes de fechar o painel.
const FINAL_MESSAGE_TIME: float = 2.5
## Vida máxima usada até o Player informar a dele.
const FALLBACK_HP_MAX: int = 100

const REASON_CORRECT: StringName = &"acerto"
const REASON_WRONG: StringName = &"erro"
const REASON_TIMEOUT: StringName = &"timeout"

## Perguntas padrão: { pergunta, resposta }.
const DEFAULT_QUESTIONS: Array[Dictionary] = [
	{
		"pergunta": "Energia = 100 E Energia_reator = 50\nSe Energia > 50:\n\tEnergia = 50\nEnergia_reator = 100\nQUAL SERÁ A QUANTIDADE DE ENERGIA DIRECIONADA AO GERADOR?",
		"resposta": "50",
	},
	{
		"pergunta": "Bots_ativos = 1000 E Bots_inativos = 2000\nSe Bots_ativos < Bots_inativos:\n\tBots_ativos = Bots_inativos + Bots_ativos\n\tBots_inativos = 0\nQUAL O TOTAL DE BOTS ATIVOS?",
		"resposta": "3000",  # 2000 + 1000
	},
	{
		"pergunta": "Drones_Londres = 150\nEnquanto Drones_Londres != 200:\n\tDrones_Londres = Drones_Londres + 25\nQUANTOS LOOPS SERÃO EXECUTADOS?",
		"resposta": "2",  # 150 -> 175 -> 200
	},
	{
		"pergunta": "Temperatura_nucleo = 80 E Resfriamento = 30\nSe Temperatura_nucleo - Resfriamento > 40:\n\tTemperatura_nucleo = Temperatura_nucleo - 20\nSenão:\n\tTemperatura_nucleo = Temperatura_nucleo + 20\nQUAL A TEMPERATURA FINAL DO NÚCLEO?",
		"resposta": "60",  # 80 - 30 = 50 (> 40), então cai no primeiro bloco: 80 - 20
	},
	{
		"pergunta": "Firewalls = 0 E Ataques = 3\nEnquanto Firewalls < 10:\n\tFirewalls = Firewalls + Ataques\nQUANTOS FIREWALLS EXISTEM NO FINAL?",
		"resposta": "12",  # 0, 3, 6, 9, 12
	},
]

## Perguntas do Inspector.
@export var perguntas: Array[QuizQuestion] = []

@export_group("Tempo")
## Segundos que o jogador tem para responder cada questão.
@export_range(3.0, 120.0, 0.5, "or_greater") var tempo_por_questao: float = 30.0
## Quando restar esse tempo (ou menos), o relógio fica vermelho.
@export_range(1.0, 30.0, 0.5, "or_greater") var tempo_alerta: float = 5.0

@export_group("Dano")
## Quantos erros (resposta errada ou tempo esgotado) zeram a barra de vida.
@export_range(1, 20) var erros_para_game_over: int = 3

@export_group("Nós da cena")
@export var question_label: RichTextLabel
@export var answer_input: LineEdit
## Botão clicável de envio (equivale a Enter no campo de resposta).
@export var submit_button: Button
## Espera do feedback (acerto/erro na tela) entre uma pergunta e a seguinte.
@export var feedback_timer: Timer
## Contagem regressiva da questão.
@export var question_timer: Timer
@export var countdown_box: Control
@export var countdown_label: Label
@export var countdown_bar: ProgressBar

## Estilo da barra do relógio (lido da cena; a cor troca no alerta).
var _countdown_fill: StyleBoxFlat = null
var _urgent: bool = false

var _phase: Phase = Phase.CLOSED
var _index: int = 0
var _hp_max: int = FALLBACK_HP_MAX
var _player_dead: bool = false
## False quando falta algum nó no Inspector.
var _valid: bool = false
## Um item por questão já registrada.
var _results: Array[bool] = []


## Conecta antes dos _ready (o Player anuncia a vida dele no próprio _ready).
func _enter_tree() -> void:
	CombatUtils.connect_once(EventBus.player_hp_changed, _on_player_hp_changed)
	CombatUtils.connect_once(EventBus.player_died, _on_player_died)


func _exit_tree() -> void:
	if EventBus.player_hp_changed.is_connected(_on_player_hp_changed):
		EventBus.player_hp_changed.disconnect(_on_player_hp_changed)
	if EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.disconnect(_on_player_died)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # cronômetro e feedback andam com o jogo pausado
	_valid = _validate_references()
	if not _valid:
		hide()
		return
	if perguntas.is_empty():
		perguntas = _build_default_questions()
	# Cópia própria do estilo.
	# instâncias da cena (o StyleBox da cena é compartilhado entre elas).
	var fill := countdown_bar.get_theme_stylebox(&"fill") as StyleBoxFlat
	if fill != null:
		_countdown_fill = fill.duplicate() as StyleBoxFlat
		countdown_bar.add_theme_stylebox_override(&"fill", _countdown_fill)
	answer_input.placeholder_text = "Insira aqui a resposta"
	answer_input.text_submitted.connect(_on_answer_submitted)
	submit_button.pressed.connect(_on_submit_pressed)
	feedback_timer.timeout.connect(_on_feedback_finished)
	question_timer.timeout.connect(_on_question_timeout)
	set_process(false)  # _process só roda enquanto o cronômetro estiver contando
	hide()


# --- Cronômetro ---

## Zera o relógio e começa a contar a questão atual.
func _start_countdown() -> void:
	countdown_bar.max_value = tempo_por_questao
	_set_urgent(false)
	question_timer.start(tempo_por_questao)
	set_process(true)
	_refresh_countdown()


## Para a contagem (o texto e a barra ficam congelados no último valor).
func _stop_countdown() -> void:
	question_timer.stop()
	set_process(false)


func _process(_delta: float) -> void:
	_refresh_countdown()


## Atualiza texto e barra com o tempo que falta.
func _refresh_countdown() -> void:
	var left: float = question_timer.time_left
	countdown_bar.value = left
	countdown_label.text = "Tempo: %d s" % ceili(left)
	_set_urgent(left <= tempo_alerta)


## Troca a cor do relógio só quando o estado muda.
func _set_urgent(value: bool) -> void:
	if value == _urgent:
		return
	_urgent = value
	if _countdown_fill != null:
		_countdown_fill.bg_color = COLOR_TIMER_ALERT if value else COLOR_TIMER_OK
	if value:
		countdown_label.add_theme_color_override(&"font_color", COLOR_TIMER_ALERT)
	else:
		countdown_label.remove_theme_color_override(&"font_color")


## Tempo zerou: a questão atual conta como incorreta e o jogador leva dano.
func _on_question_timeout() -> void:
	if _phase != Phase.ANSWERING:
		return
	_phase = Phase.FEEDBACK
	_stop_countdown()
	_refresh_countdown()
	_lock_input()
	answer_input.add_theme_color_override(&"font_color", COLOR_WRONG)
	question_label.text = "Tempo esgotado! A resposta era: " + perguntas[_index].resposta_correta
	_register_result(false, REASON_TIMEOUT)
	feedback_timer.start()


# --- Mouse ---

## Os filtros de mouse ficam na cena.

## Clique no botão = mesmo efeito de Enter no campo de resposta.
func _on_submit_pressed() -> void:
	if _phase == Phase.ANSWERING:  # ignora cliques enquanto o feedback está na tela
		_on_answer_submitted(answer_input.text)


## Cliques no fundo do quiz (Panel, enunciado ou o próprio quiz).
func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	match _phase:
		Phase.FEEDBACK:
			# Feedback na tela (acerto/erro): clicar pula a espera de 1,5 s.
			feedback_timer.stop()
			_on_feedback_finished()
		Phase.ANSWERING:
			answer_input.grab_focus()  # clicar fora do campo não "perde" o teclado


# --- Fluxo das perguntas ---

## Abre o quiz na primeira pergunta.
func iniciar() -> void:
	if not _valid or _player_dead:
		return
	_index = 0
	_results.clear()
	answer_input.show()
	submit_button.show()
	countdown_box.show()
	show()
	_load_question()


## Mostra a pergunta atual.
func _load_question() -> void:
	if _index >= perguntas.size():
		_finish()
		return
	_phase = Phase.ANSWERING
	answer_input.editable = true
	submit_button.disabled = false
	answer_input.clear()
	answer_input.grab_focus()
	answer_input.add_theme_color_override(&"font_color", Color.WHITE)
	question_label.text = perguntas[_index].pergunta
	_start_countdown()


## Mostra a mensagem final, espera e fecha o painel.
func _finish() -> void:
	if _phase == Phase.ENDING:
		return
	_phase = Phase.ENDING
	_stop_countdown()
	countdown_box.hide()
	question_label.text = FINAL_MESSAGE
	answer_input.hide()
	submit_button.hide()
	# O timer segue rodando com o jogo pausado (process_always = true).
	await get_tree().create_timer(FINAL_MESSAGE_TIME, true).timeout  # audit-ok: quiz roda pausado
	if not is_inside_tree():
		return  # A cena mudou durante a espera.
	hide()
	_phase = Phase.CLOSED
	quiz_terminado.emit()


func _on_answer_submitted(typed: String) -> void:
	if _phase != Phase.ANSWERING or _index >= perguntas.size():
		return
	_phase = Phase.FEEDBACK
	_stop_countdown()
	_lock_input()  # trava até a próxima pergunta (evita envio duplo)

	var question: QuizQuestion = perguntas[_index]
	var correct: bool = _normalize(typed) == _normalize(question.resposta_correta)
	answer_input.add_theme_color_override(&"font_color", COLOR_RIGHT if correct else COLOR_WRONG)
	if correct:
		_register_result(true, REASON_CORRECT)
	else:
		question_label.text = "Incorreto! A resposta era: " + question.resposta_correta
		_register_result(false, REASON_WRONG)
	feedback_timer.start()


## Guarda o resultado da questão atual.
func _register_result(correct: bool, reason: StringName) -> void:
	_results.append(correct)
	resposta_registrada.emit(_index, correct, reason)
	if not correct:
		EventBus.player_damage_requested.emit(_damage_per_error())


## Calcula o dano de cada erro.
func _damage_per_error() -> int:
	var errors: int = maxi(erros_para_game_over, 1)
	return maxi(ceili(float(_hp_max) / float(errors)), 1)


## Fim da espera do feedback.
func _on_feedback_finished() -> void:
	if _phase != Phase.FEEDBACK:
		return
	if _player_dead:
		_phase = Phase.CLOSED
		countdown_box.hide()
		hide()
		quiz_falhou.emit()
		return
	_index += 1
	_load_question()


## Trava campo e botão (durante o feedback e depois que o tempo acaba).
func _lock_input() -> void:
	answer_input.editable = false
	submit_button.disabled = true


# --- EventBus ---

## Guarda a vida máxima do Player para calcular o dano de cada erro.
func _on_player_hp_changed(_hp: int, hp_max: int) -> void:
	_hp_max = maxi(hp_max, 1)


## A vida zerou.
func _on_player_died() -> void:
	_player_dead = true
	if _phase == Phase.ANSWERING:
		# Morte por outra causa no meio de uma pergunta.
		_phase = Phase.FEEDBACK
		_stop_countdown()
		_lock_input()
		feedback_timer.start()


## True se todos os nós obrigatórios foram arrastados no Inspector.
func _validate_references() -> bool:
	var missing: PackedStringArray = []
	if question_label == null: missing.append("question_label")
	if answer_input == null: missing.append("answer_input")
	if submit_button == null: missing.append("submit_button")
	if feedback_timer == null: missing.append("feedback_timer")
	if question_timer == null: missing.append("question_timer")
	if countdown_box == null: missing.append("countdown_box")
	if countdown_label == null: missing.append("countdown_label")
	if countdown_bar == null: missing.append("countdown_bar")
	if missing.is_empty():
		return true
	push_error("QuizScreen: referências não atribuídas no Inspector: %s" % ", ".join(missing))
	return false


## Ignora espaços nas pontas e diferença entre maiúsculas e minúsculas.
func _normalize(text: String) -> String:
	return text.strip_edges().to_lower()


## Resultado de cada questão já registrada.
func get_resultados() -> Array[bool]:
	return _results.duplicate()


func _build_default_questions() -> Array[QuizQuestion]:
	var result: Array[QuizQuestion] = []
	for data: Dictionary in DEFAULT_QUESTIONS:
		var question := QuizQuestion.new()
		question.pergunta = data["pergunta"]
		question.resposta_correta = data["resposta"]
		result.append(question)
	return result
