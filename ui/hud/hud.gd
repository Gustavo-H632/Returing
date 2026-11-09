class_name GameHUD
extends CanvasLayer
## HUD da fase. Só usa o EventBus.

@export_group("Jogador (arraste os nós)")
## Barra de vida em sprite, ancorada no canto inferior esquerdo pela cena.
@export var player_health_bar: SpriteBar
## Barra de ataque carregado (sprite azul), logo abaixo da barra de vida.
@export var charge_bar: SpriteBar

@export_group("Fim de jogo (arraste os nós)")
## Espera exata (s) entre o Game Over e o aparecimento do botão "Tentar de novo".
@export_range(0.0, 30.0, 0.5, "or_greater") var retry_delay: float = 5.0
@export var game_over_panel: Control  # Painel de game over.
@export var retry_button: Button  # Botão "Tentar de novo".
@export var game_over_menu_button: Button  # Botão "Menu" do game over.

@export_group("Fim de fase (arraste os nós)")
@export var complete_panel: Control  # Painel de fase concluída.
## Título "Fase concluída!" (escondido quando a fase é a última).
@export var complete_label: Label
## Letreiro "Fim de jogo" (só aparece quando não há próxima fase).
@export var complete_banner: EndGameBanner
@export var continue_button: Button  # Botão "Continuar".
@export var complete_menu_button: Button  # Botão "Menu" da fase concluída.

var _next_scene: String = ""  # Próxima cena (vazio = última fase).
var _bus_links: Array[Array] = []  # Ligações com o EventBus (para desligar depois).
var _valid: bool = false  # True se todas as referências foram atribuídas.


## Conecta antes dos _ready para não perder o primeiro hp_changed.
## Confere as referências e liga os sinais do EventBus antes do _ready (para não perder o primeiro hp_changed).
func _enter_tree() -> void:
	_valid = _validate_references()  # Confere as referências do Inspector.
	if not _valid:  # Sem elas a HUD não funciona.
		return
	_bus_links = [  # Pares sinal e função.
		[EventBus.player_hp_changed, _on_player_hp_changed],  # Vida mudou.
		[EventBus.player_damaged, _on_player_damaged],  # Tomou dano.
		[EventBus.player_charge_changed, _on_player_charge_changed],  # Carga do tiro mudou.
		[EventBus.level_completed, _on_level_completed],  # Fase concluída.
		[EventBus.game_over, _on_game_over],  # Game over.
	]
	for link: Array in _bus_links:  # Liga cada par.
		CombatUtils.connect_once(link[0], link[1])  # Conecta sem duplicar.


## Esconde os painéis, liga os botões e pede o estado atual do Player.
## Esconde os painéis, liga os botões (que viram pedidos no EventBus) e pede o estado atual do jogador.
func _ready() -> void:
	if not _valid:  # HUD inválida: não faz nada.
		return

	game_over_panel.hide()  # Esconde o game over.
	complete_panel.hide()  # Esconde a fase concluída.
	if charge_bar != null:  # Barra de carga vazia.
		charge_bar.set_ratio(0.0)  # Zera a barra.

	# Botões viram pedidos no EventBus.
	# Tentar de novo: reinicia a fase.
	retry_button.pressed.connect(func() -> void: EventBus.level_restart_requested.emit())
	# Menu (game over): volta ao menu.
	game_over_menu_button.pressed.connect(func() -> void: EventBus.main_menu_requested.emit())
	# Menu (fase concluída): volta ao menu.
	complete_menu_button.pressed.connect(func() -> void: EventBus.main_menu_requested.emit())
	continue_button.pressed.connect(_on_continue_pressed)  # Continuar: vai à próxima cena.

	EventBus.hud_refresh_requested.emit()  # Pede ao jogador vida e carga atuais.


## Ao sair da cena desliga os sinais do EventBus.
func _exit_tree() -> void:
	for link: Array in _bus_links:  # Cada ligação.
		CombatUtils.disconnect_if_connected(link[0], link[1])  # Desconecta.


# --- Jogador ---

## A vida do jogador mudou: atualiza a barra de vida.
func _on_player_hp_changed(hp: int, hp_max: int) -> void:
	player_health_bar.set_health(hp, hp_max)  # Atualiza a barra.


## O jogador tomou dano: a barra pisca.
func _on_player_damaged(_amount: int) -> void:
	player_health_bar.flash()  # Pisca.


## Barra de carga do tiro: enche de 0.0 a 1.0 enquanto o botão está pressionado.
## A carga do tiro mudou: atualiza a barra de carga (0 a 1).
func _on_player_charge_changed(ratio: float) -> void:
	if charge_bar != null:  # Só se existe barra de carga.
		charge_bar.set_ratio(ratio)  # Atualiza a barra.


# --- Fim de fase / fim de jogo ---

## Fase concluída: com próxima fase mostra "Continuar".
## Mostra o painel de fase concluída: com próxima fase aparece "Continuar"; sem ela, o letreiro "Fim de jogo".
func _on_level_completed(next_scene: String) -> void:
	_next_scene = next_scene  # Guarda a próxima cena.
	var has_next: bool = not next_scene.is_empty()  # Existe próxima fase?
	continue_button.visible = has_next  # "Continuar" só se há próxima fase.
	if complete_label != null:  # Título só se há próxima fase.
		complete_label.visible = has_next  # Título.
	if complete_banner != null:  # Letreiro só na última fase.
		complete_banner.visible = not has_next  # Letreiro.
	complete_panel.show()  # Mostra o painel.
	(continue_button if has_next else complete_menu_button).grab_focus()  # Foco no botão certo.


## Game Over em tela cheia (o painel cobre a HUD).
## Game over em tela cheia; o botão "Tentar de novo" só aparece depois de `retry_delay` segundos.
func _on_game_over() -> void:
	retry_button.hide()  # Esconde "Tentar de novo".
	game_over_panel.show()  # Mostra o painel.
	game_over_menu_button.grab_focus()  # Foco no botão de menu.
	await get_tree().create_timer(retry_delay).timeout  # Espera o tempo de bloqueio.
	if not is_inside_tree() or not game_over_panel.visible:  # A cena mudou durante a espera?
		return  # A cena mudou durante a espera.
	retry_button.show()  # Mostra "Tentar de novo".
	retry_button.grab_focus()  # Foco nele.


## Continuar: pede a troca para a próxima cena.
func _on_continue_pressed() -> void:
	if not _next_scene.is_empty():  # Só se há próxima cena.
		EventBus.scene_change_requested.emit(_next_scene)  # Pede a troca.


## True se todos os nós obrigatórios foram arrastados no Inspector.
## Confere se todos os nós obrigatórios foram arrastados no Inspector e avisa o que faltar.
func _validate_references() -> bool:
	var missing: PackedStringArray = []  # Lista do que falta.
	if player_health_bar == null: missing.append("player_health_bar")  # Barra de vida.
	if game_over_panel == null: missing.append("game_over_panel")  # Painel de game over.
	if retry_button == null: missing.append("retry_button")  # Botão "Tentar de novo".
	if game_over_menu_button == null: missing.append("game_over_menu_button")  # Botão "Menu" do game over.
	if complete_panel == null: missing.append("complete_panel")  # Painel de fase concluída.
	if continue_button == null: missing.append("continue_button")  # Botão "Continuar".
	if complete_menu_button == null: missing.append("complete_menu_button")  # Botão "Menu" da fase.
	if missing.is_empty():  # Tudo certo.
		return true  # Valida.
	push_error("GameHUD: referências não atribuídas no Inspector: %s" % ", ".join(missing))  # Avisa o erro.
	return false  # Inválida.
