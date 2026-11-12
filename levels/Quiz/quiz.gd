class_name QuizScreen
extends Control
## Quiz da Fase 2, que roda com o jogo pausado.

## Emitido depois da mensagem final, com o quiz já escondido.
signal quiz_terminado
## Emitido quando o jogador morre durante o quiz, com o quiz já escondido.
signal quiz_falhou
## Cada questão registrada.
signal resposta_registrada(indice: int, correta: bool, motivo: StringName)

#divide o quiz em fases
# Etapas do quiz.
enum fase_do_quiz {
	## Fechado (antes de iniciar() ou depois de terminar/falhar).
	CLOSED,
	## Pergunta na tela, cronômetro rodando, campo de resposta liberado.
	ANSWERING,
	## Feedback de acerto/erro na tela (campo travado), esperando a próxima pergunta.
	FEEDBACK,
	## Mensagem final na tela.
	ENDING,
}

## Cores da Palette: acerto e relógio normal em ACCENT; erro e pouco tempo em DANGER
## (erro tira vida do jogador, então conta como ação destrutiva).
# Cores do quiz: acerto e relógio normal em dourado; erro e pouco tempo em laranja.
const COLOR_RIGHT: Color = Palette.ACCENT
const COLOR_WRONG: Color = Palette.DANGER
const COLOR_TIMER_OK: Color = Palette.ACCENT
const COLOR_TIMER_ALERT: Color = Palette.DANGER
# Mensagem exibida no fim do quiz.
const FINAL_MESSAGE: String = "Sistemas de defesa desativados! AEGIS está livre"
## Tempo que a mensagem final fica na tela antes de fechar o painel.
const FINAL_MESSAGE_TIME: float = 2.5
## Vida máxima usada até o Player informar a dele.
const FALLBACK_HP_MAX: int = 100

# Motivos de um resultado: acerto, erro de resposta e tempo esgotado.
const REASON_CORRECT: StringName = &"acerto"
const REASON_WRONG: StringName = &"erro"
const REASON_TIMEOUT: StringName = &"timeout"

#
# Perguntas padrão (usadas quando o Inspector não define nenhuma).
const Questoes: Array[Dictionary] = [
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
@export var question_label: RichTextLabel  # Texto da pergunta.
@export var answer_input: LineEdit  # Campo de resposta.
## Botão clicável de envio (equivale a Enter no campo de resposta).
@export var submit_button: Button
## Espera do feedback (acerto/erro na tela) entre uma pergunta e a seguinte.
@export var feedback_timer: Timer
## Contagem regressiva da questão.
@export var question_timer: Timer
@export var countdown_box: Control  # Caixa do relógio.
@export var countdown_label: Label  # Texto do relógio.
@export var countdown_bar: ProgressBar  # Barra do relógio.

## Estilo da barra do relógio (lido da cena; a cor troca no alerta).
var _countdown_fill: StyleBoxFlat = null
var _urgent: bool = false  # True com pouco tempo (relógio laranja).

var _phase: fase_do_quiz = fase_do_quiz.CLOSED  # Etapa atual.
var _index: int = 0  # Índice da pergunta atual.
var _hp_max: int = FALLBACK_HP_MAX  # Vida máxima do jogador (para calcular o dano dos erros).
var _player_dead: bool = false  # True se o jogador morreu.
## False quando falta algum nó no Inspector.
var _valid: bool = false
## Um item por questão já registrada.
var _results: Array[bool] = []


## Conecta antes dos _ready (o Player anuncia a vida dele no próprio _ready).
## Liga os sinais do EventBus antes do _ready (o jogador anuncia a vida dele no próprio _ready).
func _enter_tree() -> void:
	CombatUtils.connect_once(EventBus.player_hp_changed, _on_player_hp_changed)  # Vida do jogador mudou.
	CombatUtils.connect_once(EventBus.player_died, _on_player_died)  # Jogador morreu.


## Ao sair da cena desliga os sinais do EventBus.
func _exit_tree() -> void:
	CombatUtils.disconnect_if_connected(EventBus.player_hp_changed, _on_player_hp_changed)
	CombatUtils.disconnect_if_connected(EventBus.player_died, _on_player_died)


## Prepara o quiz: valida as referências, usa as perguntas padrão se necessário e liga os sinais.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # cronômetro e feedback andam com o jogo pausado
	_valid = _validate_references()  # Confere os nós da cena.
	if not _valid:  # Faltou algo: esconde e para.
		hide()
		return
	_adapt_mobile()
	if perguntas.is_empty():  # Sem perguntas no Inspector, usa as padrão.
		perguntas = _build_default_questions()
	# Preenchimento próprio (cada instância troca a cor sem afetar o tema compartilhado).
	_countdown_fill = StyleBoxFlat.new()
	_countdown_fill.bg_color = COLOR_TIMER_OK
	countdown_bar.add_theme_stylebox_override(&"fill", _countdown_fill)
	answer_input.placeholder_text = "Insira aqui a resposta"  # Texto de ajuda do campo.
	answer_input.text_submitted.connect(_on_answer_submitted)  # Enter no campo envia a resposta.
	submit_button.pressed.connect(_on_submit_pressed)  # O botão também envia.
	feedback_timer.timeout.connect(_on_feedback_finished)  # Fim da espera do feedback.
	question_timer.timeout.connect(_on_question_timeout)  # Tempo da questão esgotado.
	set_process(false)  # _process só roda enquanto o cronômetro estiver contando
	hide()  # Começa escondido.


# --- Cronômetro ---

## Zera o relógio e começa a contar a questão atual.
func _start_countdown() -> void:
	countdown_bar.max_value = tempo_por_questao  # Barra vai de zero ao tempo da questão.
	_set_urgent(false)  # Começa com a cor normal.
	question_timer.start(tempo_por_questao)  # Inicia a contagem.
	set_process(true)  # Liga o _process.
	_refresh_countdown()  # Atualiza o texto e a barra.


## Para a contagem (o texto e a barra ficam congelados no último valor).
func _stop_countdown() -> void:
	question_timer.stop()  # Para o timer.
	set_process(false)  # Desliga o _process.


## A cada quadro atualiza o relógio na tela.
func _process(_delta: float) -> void:
	if Platform.is_mobile() and visible:  # sobe o conteúdo quando o teclado virtual aparece
		position.y = -_keyboard_shift()
	_refresh_countdown()


## Atualiza texto e barra com o tempo que falta.
func _refresh_countdown() -> void:
	var left: float = question_timer.time_left  # Tempo que falta.
	countdown_bar.value = left  # Barra.
	countdown_label.text = "Tempo: %d s" % ceili(left)  # Texto.
	_set_urgent(left <= tempo_alerta)  # Fica laranja com pouco tempo.


## Troca a cor do relógio só quando o estado muda.
func _set_urgent(value: bool) -> void:
	if value == _urgent:  # Mesmo estado: nada a fazer.
		return
	_urgent = value  # Guarda o estado.
	if _countdown_fill != null:  # Há estilo próprio.
		_countdown_fill.bg_color = COLOR_TIMER_ALERT if value else COLOR_TIMER_OK  # Cor da barra.
	if value:  # Pouco tempo.
		countdown_label.add_theme_color_override(&"font_color", COLOR_TIMER_ALERT)  # Cor do texto.
	else:
		countdown_label.remove_theme_color_override(&"font_color")  # Tempo normal: volta à cor do tema.


## Tempo zerou: a questão atual conta como incorreta e o jogador leva dano.
func _on_question_timeout() -> void:
	if _phase != fase_do_quiz.ANSWERING:  # Só vale se estava respondendo.
		return
	_phase = fase_do_quiz.FEEDBACK  # Passa ao feedback.
	_stop_countdown()  # Para o relógio.
	_refresh_countdown()  # Mostra o zero.
	_lock_input()  # Trava o campo.
	answer_input.add_theme_color_override(&"font_color", COLOR_WRONG)  # Texto em laranja (erro).
	# Mostra a resposta certa.
	question_label.text = "Tempo esgotado! A resposta era: " + perguntas[_index].resposta_correta
	_register_result(false, REASON_TIMEOUT)  # Conta como erro (tira vida).
	feedback_timer.start()  # Espera o feedback.


# --- Mouse ---

## Os filtros de mouse ficam na cena.

## Clique no botão = mesmo efeito de Enter no campo de resposta.
func _on_submit_pressed() -> void:
	if _phase == fase_do_quiz.ANSWERING:  # ignora cliques enquanto o feedback está na tela
		_on_answer_submitted(answer_input.text)  # Mesmo efeito do Enter.


## Cliques no fundo do quiz (Panel, enunciado ou o próprio quiz).
## Clique esquerdo no fundo: durante o feedback pula a espera; durante a resposta devolve o foco ao campo.
func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton  # Só o clique esquerdo.
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()  # Consome o clique.
	match _phase:  # Depende da etapa.
		fase_do_quiz.FEEDBACK:  # Feedback na tela.
			# Feedback na tela (acerto/erro): clicar pula a espera de 1,5 s.
			feedback_timer.stop()  # Para o timer.
			_on_feedback_finished()  # Vai direto à próxima pergunta.
		fase_do_quiz.ANSWERING:  # Respondendo.
			answer_input.grab_focus()  # clicar fora do campo não "perde" o teclado


# --- Fluxo das perguntas ---

## Celular: campo e botão com tamanho de toque, tudo dentro da área segura (o painel de fundo cobre a tela toda)
## e o conjunto sobe quando o teclado virtual aparece, para o campo nunca ficar escondido atrás dele.
func _adapt_mobile() -> void:
	if not Platform.is_mobile():
		return
	answer_input.offset_bottom = answer_input.offset_top + Platform.MIN_TOUCH
	submit_button.offset_top = answer_input.offset_bottom + 12.0
	submit_button.offset_bottom = submit_button.offset_top + Platform.MIN_TOUCH
	# Pergunta, campo, botão e relógio vão para a faixa livre do alto (da direita das barras de status até a pausa),
	# com quebra de linha; o painel de fundo continua cobrindo a tela toda.
	var conteudo: Array[Control] = []
	for no: Node in get_children():
		if no is Control and not (no is Panel):
			conteudo.append(no as Control)
	var faixa: Control = SafeArea.band_region(self, SafeArea.Band.TOP, "Conteudo")
	for c: Control in conteudo:
		c.reparent(faixa, false)
		if c is Label:
			(c as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		elif c is RichTextLabel:  # usa a largura da faixa (até 600 px, como no computador)
			c.anchor_left = 0.0
			c.anchor_right = 1.0
			c.offset_left = 8.0
			c.offset_right = -8.0


## Celular: quanto o conteúdo sobe (px lógicos) por causa do teclado virtual.
func _keyboard_shift() -> float:
	var window_h: float = float(get_tree().root.size.y)
	if window_h <= 0.0:
		return 0.0
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return 0.0
	var keyboard: float = float(DisplayServer.virtual_keyboard_get_height()) * get_viewport_rect().size.y / window_h
	if keyboard <= 0.0:
		return 0.0
	var bottom: float = submit_button.get_global_rect().end.y - position.y + 8.0
	return clampf(bottom - (get_viewport_rect().size.y - keyboard), 0.0, answer_input.get_global_rect().position.y - position.y)


## Abre o quiz na primeira pergunta.
func iniciar() -> void:
	if not _valid or _player_dead:  # Sem referências ou com o jogador morto: não abre.
		return
	_index = 0  # Começa na primeira pergunta.
	_results.clear()  # Zera os resultados.
	answer_input.show()  # Mostra o campo.
	submit_button.show()  # Mostra o botão.
	countdown_box.show()  # Mostra o relógio.
	show()  # Mostra o quiz.
	_load_question()  # Carrega a primeira pergunta.


## Mostra a pergunta atual.
func _load_question() -> void:
	if _index >= perguntas.size():  # Acabaram as perguntas: termina.
		_finish()
		return
	_phase = fase_do_quiz.ANSWERING  # Etapa de resposta.
	answer_input.editable = true  # Libera o campo.
	submit_button.disabled = false  # Libera o botão.
	answer_input.clear()  # Limpa o campo.
	answer_input.grab_focus()  # Foco no campo.
	answer_input.add_theme_color_override(&"font_color", Palette.TEXT)  # Cor normal do texto.
	question_label.text = perguntas[_index].pergunta  # Mostra a pergunta.
	_start_countdown()  # Começa a contar o tempo.


## Mostra a mensagem final, espera e fecha o painel.
func _finish() -> void:
	if _phase == fase_do_quiz.ENDING:  # Já está terminando.
		return
	_phase = fase_do_quiz.ENDING  # Etapa final.
	_stop_countdown()  # Para o relógio.
	countdown_box.hide()  # Esconde o relógio.
	question_label.text = FINAL_MESSAGE  # Mensagem final.
	answer_input.hide()  # Esconde o campo.
	submit_button.hide()  # Esconde o botão.
	# O timer segue rodando com o jogo pausado (process_always = true).
	await get_tree().create_timer(FINAL_MESSAGE_TIME, true).timeout  # audit-ok: quiz roda pausado
	if not is_inside_tree():  # A cena mudou durante a espera.
		return  # A cena mudou durante a espera.
	hide()  # Esconde o quiz.
	_phase = fase_do_quiz.CLOSED  # Etapa fechada.
	quiz_terminado.emit()  # Avisa a fase que o quiz terminou.


## O jogador enviou a resposta: compara com a esperada, mostra o feedback e registra o resultado.
func _on_answer_submitted(typed: String) -> void:
	if _phase != fase_do_quiz.ANSWERING or _index >= perguntas.size():  # Só vale enquanto responde.
		return
	_phase = fase_do_quiz.FEEDBACK  # Passa ao feedback.
	_stop_countdown()  # Para o relógio.
	_lock_input()  # trava até a próxima pergunta (evita envio duplo)

	var question: QuizQuestion = perguntas[_index]  # Pergunta atual.
	# Compara sem diferenciar maiúsculas nem espaços nas pontas.
	var correct: bool = _normalize(typed) == _normalize(question.resposta_correta)
	# Verde se acertou, laranja se errou.
	answer_input.add_theme_color_override(&"font_color", COLOR_RIGHT if correct else COLOR_WRONG)
	if correct:  # Acertou.
		_register_result(true, REASON_CORRECT)  # Registra o acerto.
	else:
		# Mostra a resposta certa.
		question_label.text = "Incorreto! A resposta era: " + question.resposta_correta
		_register_result(false, REASON_WRONG)  # Registra o erro.
	feedback_timer.start()  # Espera o feedback.


## Guarda o resultado da questão atual.
func _register_result(correct: bool, reason: StringName) -> void:
	_results.append(correct)  # Guarda o resultado.
	resposta_registrada.emit(_index, correct, reason)  # Avisa a pontuação e a HUD.
	if not correct:  # Erro (resposta ou tempo): o jogador leva dano.
		EventBus.player_damage_requested.emit(_damage_per_error())  # Pede o dano ao EventBus.


## Calcula o dano de cada erro.
func _damage_per_error() -> int:
	var errors: int = maxi(erros_para_game_over, 1)  # Pelo menos 1 erro para dividir.
	# Dano: vida máxima dividida pelos erros permitidos (arredondada para cima).
	return maxi(ceili(float(_hp_max) / float(errors)), 1)


## Fim da espera do feedback.
func _on_feedback_finished() -> void:
	if _phase != fase_do_quiz.FEEDBACK:  # Só vale durante o feedback.
		return
	if _player_dead:  # O jogador morreu no quiz.
		_phase = fase_do_quiz.CLOSED  # Fecha.
		countdown_box.hide()  # Esconde o relógio.
		hide()  # Esconde o quiz.
		quiz_falhou.emit()  # Avisa a fase.
		return
	_index += 1  # Próxima pergunta.
	_load_question()  # Carrega.


## Trava campo e botão (durante o feedback e depois que o tempo acaba).
func _lock_input() -> void:
	answer_input.editable = false  # Campo travado.
	submit_button.disabled = true  # Botão travado.


# --- EventBus ---

## Guarda a vida máxima do Player para calcular o dano de cada erro.
func _on_player_hp_changed(_hp: int, hp_max: int) -> void:
	_hp_max = maxi(hp_max, 1)  # Guarda a vida máxima (mínimo 1).


# O energumeno do player morreu
func _on_player_died() -> void:
	_player_dead = true  # Guarda que o jogador morreu.


## True se todos os nós obrigatórios foram arrastados no Inspector.
func _validate_references() -> bool:
	var missing: PackedStringArray = []  # Lista do que falta.
	if question_label == null: missing.append("question_label")  # Texto da pergunta.
	if answer_input == null: missing.append("answer_input")  # Campo de resposta.
	if submit_button == null: missing.append("submit_button")  # Botão de enviar.
	if feedback_timer == null: missing.append("feedback_timer")  # Timer do feedback.
	if question_timer == null: missing.append("question_timer")  # Timer do relógio.
	if countdown_box == null: missing.append("countdown_box")  # Caixa do relógio.
	if countdown_label == null: missing.append("countdown_label")  # Texto do relógio.
	if countdown_bar == null: missing.append("countdown_bar")  # Barra do relógio.
	if missing.is_empty():  # Tudo certo.
		return true  # Válido.
	return false  # Falta algo.


## Ignora espaços nas pontas e diferença entre maiúsculas e minúsculas.
func _normalize(text: String) -> String:
	return text.strip_edges().to_lower()  # Tira espaços das pontas e usa minúsculas.


## Resultado de cada questão já registrada.
func get_resultados() -> Array[bool]:
	return _results.duplicate()  # Cópia da lista de resultados.


## Cria as perguntas padrão a partir da lista embutida.
func _build_default_questions() -> Array[QuizQuestion]:
	var result: Array[QuizQuestion] = []  # Lista de resultado.
	for data: Dictionary in Questoes:  # Cada pergunta embutida.
		var question := QuizQuestion.new()  # Recurso novo.
		question.pergunta = data["pergunta"]  # Enunciado.
		question.resposta_correta = data["resposta"]  # Resposta esperada.
		result.append(question)  # Entra na lista.
	return result
