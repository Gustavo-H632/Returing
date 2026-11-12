extends Node
## Teste de fluxo das configurações: abre o menu principal, entra em Configurações, mexe nos sliders,
## confere os buses, volta com ui_cancel e testa o foco por teclado. Restaura os volumes no fim.
## Rodar: godot --path . res://qa/settings_flow_test.tscn   (precisa de janela: o foco só existe com ela)

var _falhas: int = 0  # Falhas.


## Espera `n` quadros.
func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


## Agenda o teste para o fim do quadro.
func _ready() -> void:
	_rodar.call_deferred()  # Roda depois da criação dos nós.


## Abre o menu, entra em Configurações, mexe nos sliders, confere os buses, volta com ui_cancel e testa o foco por teclado.
func _rodar() -> void:
	var musica_original: float = AudioSettings.get_volume(&"Music")  # Guarda o volume original da música.
	var sfx_original: float = AudioSettings.get_volume(&"SFX")  # Guarda o volume original dos efeitos.

	# Cria o menu principal.
	var menu: Node = (load("res://Scenes/Start/menu_start.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(menu)  # Entra na árvore.
	await _frames(30)  # Espera 30 quadros.

	var iniciar: Button = menu.get_node("Center/Column/MenuPanel/Buttons/Start_button")  # Botão "Iniciar".
	# Botão "Configurações".
	var config: Button = menu.get_node("Center/Column/MenuPanel/Buttons/Settings_button")
	var botoes: Control = menu.get_node("Center/Column/MenuPanel/Buttons")  # Botões da página principal.
	_checar(iniciar.has_focus(), "o foco começa em Iniciar")  # O foco começa em "Iniciar".

	_tecla(&"ui_down")  # Seta para baixo.
	await _frames(5)
	# O foco vai para "Configurações".
	_checar(config.has_focus(), "seta para baixo leva o foco a Configurações")

	config.pressed.emit()  # Aperta "Configurações".
	await _frames(5)
	var painel: SettingsPanel = null  # Painel de configurações.
	# Procura o painel entre os filhos.
	for filho: Node in menu.get_node("Center/Column/MenuPanel").get_children():
		if filho is SettingsPanel:
			painel = filho
	# Abriu e escondeu os botões.
	_checar(painel != null and painel.visible and not botoes.visible, "Configurações abre e esconde a página principal")

	var sliders: Array[HSlider] = []  # Sliders.
	_coletar(painel, sliders)  # Coleta os sliders.
	_checar(sliders.size() == 2, "há 2 sliders")  # Há dois sliders.
	if sliders.size() == 2:
		# O foco vai para o primeiro slider.
		_checar(sliders[0].has_focus(), "o foco vai para o primeiro slider")
		sliders[0].value = 50.0  # efeitos sonoros
		var sfx: int = AudioServer.get_bus_index(&"SFX")
		# O bus recebeu -6 dB.
		_checar(absf(AudioServer.get_bus_volume_db(sfx) - linear_to_db(0.5)) < 0.01, "slider em 50% = -6,02 dB no bus SFX")
		sliders[1].value = 0.0  # música
		var musica: int = AudioServer.get_bus_index(&"Music")
		# O bus da música ficou mudo.
		_checar(AudioServer.is_bus_mute(musica), "slider em 0% silencia o bus Music")

	_tecla(&"ui_cancel")  # Esc (ui_cancel).
	await _frames(5)
	# Voltou à página principal.
	_checar(botoes.visible and not painel.visible, "ui_cancel volta para a página principal")
	_checar(config.has_focus(), "o foco volta para Configurações")  # O foco voltou para "Configurações".

	AudioSettings.set_volume(&"Music", musica_original)  # Restaura a música.
	AudioSettings.set_volume(&"SFX", sfx_original)  # Restaura os efeitos.
	AudioSettings.save_settings()  # Salva.
	print("settings_flow_test: %d falha(s)" % _falhas)  # Resultado.
	get_tree().quit(1 if _falhas > 0 else 0)  # Sai com código de erro se algo falhou.


## Coleta todos os HSlider dentro de um nó (busca recursiva).
func _coletar(no: Node, saida: Array[HSlider]) -> void:
	for filho: Node in no.get_children():  # Cada filho.
		if filho is HSlider:  # É um slider.
			saida.append(filho)  # Guarda.
		_coletar(filho, saida)  # Desce nos filhos.


## Simula apertar e soltar uma ação do Input Map.
func _tecla(acao: StringName) -> void:
	var evento: InputEventAction = InputEventAction.new()  # Evento de apertar.
	evento.action = acao  # Qual ação.
	evento.pressed = true  # Apertada.
	Input.parse_input_event(evento)  # Envia.
	var solto: InputEventAction = InputEventAction.new()  # Evento de soltar.
	solto.action = acao  # Qual ação.
	solto.pressed = false  # Solta.
	Input.parse_input_event(solto)  # Envia.


## Confere uma condição e conta a falha.
func _checar(condicao: bool, descricao: String) -> void:
	if condicao:  # Passou.
		print("ok      ", descricao)  # Mostra "ok".
	else:
		printerr("FALHOU  ", descricao)  # Falhou.
		_falhas += 1  # Soma a falha.
