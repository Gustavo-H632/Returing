class_name Camara
extends Node2D
## Fase "Câmara de Provas - Linha de Tiro": 3 salas numa cena, ligadas por portas.
##   Sala 1 "Passagem": só dash. 2 raios (máquinas indestrutíveis) e 1 trecho de fogo.
##   Sala 2 "Calibração": dash + 1 tiro. Destruir a máquina abre a porta.
##   Sala 3 "Câmara Principal": 10 máquinas em sequência fixa. Destruir as 10 abre a porta final (o quiz).
##
## Toda a arena (arte, colisões, máquinas, emissores, portas, gatilhos) está posicionada de forma ESTÁTICA em
## Camara.tscn (gerado uma vez por tools/gerar_cena_camara.py a partir da planta tools/camara_layout.py).
## Este script só liga os sinais: entrar numa sala liga o cronograma dela; máquina destruída -> contadores e portas;
## porta final -> saída para a próxima cena. O Player e a HUD são os do projeto, sem alterações de código.

## Uma porta foi aberta (1 = Sala 1->2, 2 = Sala 2->3, 3 = porta final).
signal porta_liberada(numero: int)
## As 10 máquinas da Sala 3 foram destruídas.
signal camara_vencida

## Cena seguinte (depois da Câmara vem a Fase 3).
@export_file("*.tscn") var next_scene: String = "res://Scenes/Fase3/fase_3.tscn"
## Pausa entre morrer e mostrar o game over (a HUD do projeto mostra a tela).
@export_range(0.0, 10.0, 0.1, "or_greater") var game_over_delay: float = 1.5

@export_group("Abertura (a voz do tutorial)")
## Falas do homem misterioso: tela preta e texto azul, como a voz do tutorial (Dialogue.Style.VOICE).
## Não é cutscene: sem caixa nem ilustração, e segurar ESC pula. Vazio = a fase começa direto.
@export var falas_abertura: PackedStringArray = [
	"Você passou pelo terminal. Mas respostas certas não bastam.",
	"A Aegis só responde a quem prova que pensa.",
	"Desvie dos raios com o dash. E quebre as máquinas com o tiro carregado.",
]
## Tempo (s) da tela preta sumindo depois das falas.
@export_range(0.0, 3.0, 0.1) var fade_abertura: float = 0.8

@export_group("Salas (cada uma é um cronograma com as máquinas como filhas)")
@export var sala1: CamaraSequenciador
@export var sala2: CamaraSequenciador
@export var sala3: CamaraSequenciador

@export_group("Portas")
@export var porta1: CamaraPorta  # Sala 1 -> 2 (já aberta).
@export var porta2: CamaraPorta  # Sala 2 -> 3 (abre ao destruir a máquina da Sala 2).
@export var porta_final: CamaraPorta  # Sala 3 -> quiz (abre ao destruir as 10).

@export_group("Gatilhos")
@export var entrada1: Area2D  # Começo da Sala 1 (liga o cronograma dela).
@export var entrada2: Area2D  # Entrada da Sala 2.
@export var entrada3: Area2D  # Entrada da Sala 3.
@export var saida: Area2D  # Fundo do vestíbulo, atrás da porta final.

@export_group("Nós da cena")
@export var player: Player  # Alan Turing (o do projeto).
@export var hud: CamaraHud  # HUD da câmara.

## Camada da tela preta da abertura (acima da HUD = 10 e 11, abaixo do Dialogue = 120).
const ABERTURA_LAYER: int = 119

var sala_atual: int = 0 # Sala cujo cronograma está ligado (0 = nenhuma ainda).

var _destruidas_sala3: int = 0  # Máquinas da Sala 3 já destruídas.
var _total_sala3: int = 0  # Máquinas da Sala 3.
var _saindo: bool = false  # Já pediu a troca de cena.
var _em_abertura: bool = false  # True durante as falas da abertura (gatilhos de entrada ignorados).


## Confere as referências, liga os sinais e anuncia o início da fase.
func _ready() -> void:
	if not _referencias_ok():
		return
	_total_sala3 = sala3.maquinas().size()
	for m: CamaraMaquina in sala2.maquinas():
		m.destruida.connect(_on_maquina_sala2_destruida)
	for m: CamaraMaquina in sala3.maquinas():
		m.destruida.connect(_on_maquina_sala3_destruida)
	entrada1.body_entered.connect(_on_entrada.bind(1))
	entrada2.body_entered.connect(_on_entrada.bind(2))
	entrada3.body_entered.connect(_on_entrada.bind(3))
	saida.body_entered.connect(_on_saida_entrou)
	CombatUtils.connect_once(EventBus.player_died, _on_player_died)
	porta2.definir_restantes(sala2.maquinas().size())
	porta_final.definir_restantes(_total_sala3)
	EventBus.level_started.emit()  # Avisa a HUD do projeto e os controles do celular.
	_abertura()


## Desliga o sinal do EventBus ao sair da cena.
func _exit_tree() -> void:
	CombatUtils.disconnect_if_connected(EventBus.player_died, _on_player_died)


## Total de máquinas destrutíveis desta sala (para a HUD).
func total_da_sala(numero: int) -> int:
	match numero:
		2: return sala2.maquinas().size()
		3: return _total_sala3
	return 0


# --- Abertura ---

## Tela preta com a voz do tutorial (texto azul). O jogador fica parado e nada dispara até acabar; depois a
## tela preta some e a Sala 1 liga o cronograma.
func _abertura() -> void:
	if falas_abertura.is_empty():
		_entrar_sala(1)
		return
	var camada := CanvasLayer.new()
	camada.layer = ABERTURA_LAYER  # Acima da HUD, abaixo do diálogo (120).
	var preto := ColorRect.new()
	preto.color = Color.BLACK
	preto.set_anchors_preset(Control.PRESET_FULL_RECT)
	preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(preto)
	add_child(camada)
	var pausa: Node = get_node_or_null("Pause")  # ESC (segurar) pula as falas: a pausa não pode abrir junto.
	if pausa != null:
		pausa.process_mode = Node.PROCESS_MODE_DISABLED
	player.set_physics_process(false)
	_em_abertura = true  # o Player já nasce dentro do gatilho da Sala 1: ele só vale depois das falas
	var dialogo: Dialogue = Dialogue.show_lines(self, falas_abertura, Dialogue.Style.VOICE)
	await dialogo.finished
	if not is_inside_tree():
		return
	_em_abertura = false
	player.set_physics_process(true)
	if pausa != null:
		pausa.process_mode = Node.PROCESS_MODE_INHERIT
	_entrar_sala(1)
	var tween: Tween = create_tween()
	tween.tween_property(preto, "modulate:a", 0.0, fade_abertura)
	tween.tween_callback(camada.queue_free)


# --- Salas ---

## O jogador pisou no gatilho de entrada de uma sala (só o Player conta).
func _on_entrada(corpo: Node2D, numero: int) -> void:
	if not _em_abertura and CombatUtils.is_player(corpo):
		_entrar_sala(numero)


## Liga o cronograma da sala e desliga o da anterior. Entrar de novo na mesma sala não reinicia nada.
func _entrar_sala(numero: int) -> void:
	if numero <= sala_atual or _saindo:
		return
	var anterior: CamaraSequenciador = _sala(sala_atual)
	if anterior != null:
		anterior.parar()
	sala_atual = numero
	var nova: CamaraSequenciador = _sala(numero)
	if nova != null and nova.vivas() > 0:
		nova.iniciar()
	_atualizar_textos()


## Cronograma de uma sala (null para 0 ou fora do intervalo).
func _sala(numero: int) -> CamaraSequenciador:
	match numero:
		1: return sala1
		2: return sala2
		3: return sala3
	return null


# --- Máquinas e portas ---

## A máquina da Sala 2 caiu: a porta abre e o cronograma da sala acaba.
func _on_maquina_sala2_destruida(_maquina: CamaraMaquina) -> void:
	porta2.definir_restantes(sala2.vivas())
	if sala2.vivas() > 0:
		return
	sala2.parar()
	porta2.abrir()
	hud.mostrar_aviso("Máquina destruída! A porta abriu.", 3.0)
	porta_liberada.emit(2)
	_atualizar_textos()


## Uma das 10 máquinas da Sala 3 caiu: sai da sequência (a sala fica mais fácil) e os contadores andam.
func _on_maquina_sala3_destruida(_maquina: CamaraMaquina) -> void:
	_destruidas_sala3 += 1
	var restantes: int = _total_sala3 - _destruidas_sala3
	porta_final.definir_restantes(restantes)
	hud.definir_maquinas(_destruidas_sala3, _total_sala3)
	if restantes > 0:
		return
	sala3.parar()
	porta_final.abrir()
	hud.mostrar_aviso("Todas as máquinas foram destruídas! A porta final abriu.", 4.0)
	porta_liberada.emit(3)
	camara_vencida.emit()
	_atualizar_textos()


## Objetivo e contador da HUD conforme a sala e o progresso.
func _atualizar_textos() -> void:
	match sala_atual:
		1:
			hud.definir_maquinas(0, 0)
			hud.definir_objetivo("Atravesse o corredor. O DASH (Espaço) atravessa os raios.")
		2:
			hud.definir_maquinas(sala2.maquinas().size() - sala2.vivas(), sala2.maquinas().size())
			if porta2.esta_aberta:
				hud.definir_objetivo("Máquina destruída. Siga pela porta.")
			else:
				hud.definir_objetivo("Segure o botão direito (1,2 s) e acerte a máquina. O dash cancela a carga.")
		3:
			hud.definir_maquinas(_destruidas_sala3, _total_sala3)
			if porta_final.esta_aberta:
				hud.definir_objetivo("Atravesse a porta final até o terminal.")
			else:
				hud.definir_objetivo("Destrua as 10 máquinas. A máquina que pisca dispara em 1 s. Duas são reforçadas.")


# --- Saída e morte ---

## O jogador chegou ao fundo do vestíbulo (só depois da porta final aberta).
func _on_saida_entrou(corpo: Node2D) -> void:
	if _saindo or not porta_final.esta_aberta or not CombatUtils.is_player(corpo):
		return
	_saindo = true
	sala3.parar()
	RunStats.registrar_fim_de_fase()  # Mesmo registro de tempo que o level_completed faria.
	EventBus.scene_change_requested.emit(next_scene)


## O jogador morreu: para os raios e, depois de uma pausa, a HUD do projeto mostra o game over.
func _on_player_died() -> void:
	for s: CamaraSequenciador in [sala1, sala2, sala3]:
		s.parar()
	var timer: SceneTreeTimer = CombatUtils.game_timer(self, game_over_delay)
	if timer != null:
		timer.timeout.connect(func() -> void: EventBus.game_over.emit())


## Confere os nós obrigatórios (avisa no console o que faltar).
func _referencias_ok() -> bool:
	var faltando: PackedStringArray = []
	if sala1 == null: faltando.append("sala1")
	if sala2 == null: faltando.append("sala2")
	if sala3 == null: faltando.append("sala3")
	if porta1 == null: faltando.append("porta1")
	if porta2 == null: faltando.append("porta2")
	if porta_final == null: faltando.append("porta_final")
	if entrada1 == null: faltando.append("entrada1")
	if entrada2 == null: faltando.append("entrada2")
	if entrada3 == null: faltando.append("entrada3")
	if saida == null: faltando.append("saida")
	if player == null: faltando.append("player")
	if hud == null: faltando.append("hud")
	if faltando.is_empty():
		return true
	push_error("Camara: referências não atribuídas no Inspector: %s" % ", ".join(faltando))
	return false
