class_name AbilitiesUI
extends CanvasLayer
## Interface das habilidades (filha do Player): HUD de comando, barra de XP e menu de level-up.
## Liga os sinais dos componentes e cuida da fila de level-ups: o menu só abre com o jogo livre
## (sem pausa, quiz ou Player morto); level-ups durante pausa ficam na fila.

@onready var _command_hud: CommandHud = $CommandHud  # HUD da faixa de habilidades e do modo comando.
@onready var _touch_pad: TouchCommandPad = $TouchPad  # Botões de toque do modo comando (só no celular).
@onready var _menu: LevelUpMenu = $LevelUpMenu  # Menu de escolha de habilidade ao subir de nível.
@onready var _build_menu: BuildMenu = $BuildMenu  # Menu "SUA BUILD" (só leitura).

var _player: Player = null  # Jogador dono desta interface.
var _abilities: AbilityComponent = null  # Componente de habilidades.
var _experience: ExperienceComponent = null  # Componente de XP.
var _catalog: AbilityCatalog = null  # Catálogo com todas as habilidades.

## Níveis alcançados esperando o menu (em ordem).
var _queue: Array[int] = []
var _current_level: int = 0  # Nível do menu aberto agora.
var _current_offer: Array[AbilityData] = []  # Cartas oferecidas no menu aberto.
var _menu_open: bool = false  # True enquanto o menu de escolha está aberto.
var _build_open: bool = false  # True enquanto o menu de build está aberto.
# Modo do mouse antes de abrir o menu (devolvido ao fechar).
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


## Guarda o jogador, escuta o fim de jogo e agenda a configuração para o fim do quadro.
func _ready() -> void:
	_player = get_parent() as Player  # O pai é o jogador.
	# Nas telas de fim de jogo e de fase concluída a interface das habilidades some.
	CombatUtils.connect_once(EventBus.game_over, _hide_for_end_screen)  # Fim de jogo: esconde a interface.
	# Fase concluída: esconde a interface.
	CombatUtils.connect_once(EventBus.level_completed, _hide_for_end_screen)
	_setup.call_deferred()  # Espera o jogador terminar o próprio _ready.


## Ao sair da cena desliga os sinais e, se algum menu estava aberto, despausa o jogo e devolve o mouse.
func _exit_tree() -> void:
	CombatUtils.disconnect_if_connected(EventBus.game_over, _hide_for_end_screen)
	CombatUtils.disconnect_if_connected(EventBus.level_completed, _hide_for_end_screen)
	if (_menu_open or _build_open) and is_inside_tree():  # Algum menu aberto: despausa e devolve o cursor.
		get_tree().paused = false
		Input.mouse_mode = _previous_mouse_mode
	if is_instance_valid(_experience):  # Desliga o sinal de subida de nível.
		CombatUtils.disconnect_if_connected(_experience.level_up, _on_level_up)


## Procura os componentes do jogador e liga os sinais da HUD, dos menus e do XP.
func _setup() -> void:
	if _player == null or not is_inside_tree():  # Saiu da cena antes da hora.
		return
	# Componente de habilidades.
	_abilities = _player.get_node_or_null(^"AbilityComponent") as AbilityComponent
	# Componente de XP.
	_experience = _player.get_node_or_null(^"ExperienceComponent") as ExperienceComponent
	if _abilities == null or _experience == null:  # Sem os dois componentes a interface não funciona.
		push_warning("AbilitiesUI: o Player precisa ter AbilityComponent e ExperienceComponent.")
		return
	_catalog = _abilities.catalog  # Catálogo usado nas ofertas.
	_command_hud.setup(_abilities)  # Liga a HUD às habilidades.
	_touch_pad.setup(_abilities, _command_hud)  # Liga os botões de toque.
	# Clicar num amuleto abre o menu de build.
	CombatUtils.connect_once(_command_hud.slot_pressed, _on_slot_pressed)
	# Tocar num amuleto (celular) abre o menu de build.
	CombatUtils.connect_once(_touch_pad.build_requested, _on_slot_pressed)
	# O menu de build pede para fechar.
	CombatUtils.connect_once(_build_menu.close_requested, _close_build_menu)
	CombatUtils.connect_once(_experience.level_up, _on_level_up)  # Subir de nível entra na fila.
	# Escolher uma carta aprende a habilidade.
	CombatUtils.connect_once(_menu.ability_chosen, _on_ability_chosen)
	CombatUtils.connect_once(_menu.kept_current, _on_kept_current)  # Manter as atuais.
	# Níveis que subiram em outra fase (ou antes do menu poder abrir) e ainda não foram resolvidos.
	for level: int in _experience.get_pending_levels():  # Níveis pendentes de outras fases entram na fila.
		_queue.append(level)  # Entra na fila.


## Esconde a interface nas telas de fim de jogo e de fase concluída.
func _hide_for_end_screen(_unused: Variant = null) -> void:
	visible = false


## Subiu de nível: o menu entra na fila.
func _on_level_up(new_level: int) -> void:
	_queue.append(new_level)  # Entra na fila.


## Abre o próximo menu assim que o jogo estiver livre. `_process` não roda com a árvore pausada,
## então pausa, quiz e o próprio menu seguram a fila automaticamente.
## O menu só abre com o jogo livre: sem pausa, quiz ou jogador morto.
func _process(_delta: float) -> void:
	# Fila vazia, menu aberto ou tudo ainda não configurado: nada a fazer.
	if _queue.is_empty() or _menu_open or _build_open or _player == null or _abilities == null:
		return
	if _player.esta_morto() or get_tree().paused:  # Jogador morto ou jogo pausado: espera.
		return
	_open_next()  # Abre o próximo menu da fila.


## Abre o próximo menu de level-up: sorteia as cartas, pausa o jogo e mostra o menu.
func _open_next() -> void:
	var level: int = _queue.pop_front()  # Próximo nível da fila.
	_abilities.close_command_mode()  # devolve Engine.time_scale = 1.0 antes de pausar
	var offer: Array[AbilityData] = []  # Cartas sorteadas.
	if _catalog != null:  # Só se há catálogo.
		# Sorteia sem repetir as já possuídas ou rejeitadas.
		offer = _catalog.draw_offer(level, RunState.excluded_ids())
	if offer.is_empty():  # Sem cartas para oferecer.
		RunState.resolve_level(level)  # nada para oferecer: pula o menu
		return
	_current_level = level  # Guarda o nível.
	_current_offer = offer  # Guarda a oferta.
	_menu_open = true  # Marca o menu como aberto.
	_previous_mouse_mode = Input.mouse_mode  # Guarda o modo do mouse.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # Mostra o cursor.
	get_tree().paused = true  # Pausa o jogo.
	_menu.open(level, offer, _abilities.abilities)  # Mostra o menu.


## O jogador escolheu uma carta: rejeita as outras, aprende a escolhida (a lendária apaga as demais) e fecha o menu.
func _on_ability_chosen(data: AbilityData) -> void:
	# As não escolhidas nunca mais aparecem nesta run.
	var rejected: Array[StringName] = []  # Cartas não escolhidas.
	for offered: AbilityData in _current_offer:  # Passa por cada carta oferecida.
		if offered != data:  # Não foi a escolhida.
			rejected.append(offered.id)
	RunState.reject(rejected)  # Nunca mais aparecem nesta run.
	if data.rarity == AbilityData.Rarity.LENDARIA:  # Lendária: apaga as outras habilidades.
		_abilities.replace_all_with(data)  # Substitui tudo pela lendária.
	else:
		_abilities.learn(data)  # Habilidade comum ou avançada.
	_finish_menu()  # Fecha o menu.


## O jogador manteve as habilidades atuais: todas as cartas oferecidas são rejeitadas.
func _on_kept_current() -> void:
	var rejected: Array[StringName] = []  # Cartas rejeitadas.
	for offered: AbilityData in _current_offer:  # Passa por cada carta.
		rejected.append(offered.id)  # Rejeita.
	RunState.reject(rejected)  # Guarda a rejeição.
	_finish_menu()  # Fecha o menu.


## Fecha o menu de level-up: marca o nível como resolvido, despausa e devolve o mouse.
func _finish_menu() -> void:
	RunState.resolve_level(_current_level)  # Nível resolvido.
	_menu.close()  # Fecha o menu.
	_menu_open = false  # Libera a fila.
	UiFx.swallow_attack_input()  # o clique na carta não pode virar um golpe
	get_tree().paused = false  # Despausa o jogo.
	Input.mouse_mode = _previous_mouse_mode  # Devolve o cursor.


# --- Menu de build (só leitura) ---

## Um amuleto foi pressionado: abre o menu de build focado nele.
func _on_slot_pressed(ability: AbilityData) -> void:
	open_build_menu(ability.id)  # Abre o menu.


## Abre o menu "SUA BUILD" com a habilidade `focus_id` em destaque. Pausa o jogo, como o menu de
## escolha. Não abre com outro menu aberto, a árvore pausada (quiz, pause) ou o Player morto.
func open_build_menu(focus_id: StringName = &"") -> bool:
	if _player == null or _abilities == null or _experience == null:  # Sem componentes: não abre.
		return false
	# Não abre com outro menu aberto, jogo pausado, jogador morto ou interface escondida.
	if _build_open or _menu_open or get_tree().paused or _player.esta_morto() or not visible:
		return false
	_abilities.close_command_mode()  # devolve Engine.time_scale = 1.0 antes de pausar
	_build_open = true  # Marca como aberto.
	_previous_mouse_mode = Input.mouse_mode  # Guarda o modo do mouse.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # Mostra o cursor.
	get_tree().paused = true  # Pausa o jogo.
	UiFx.swallow_attack_input()
	_build_menu.open(_abilities, _experience, focus_id)  # Mostra o menu.
	return true


## Fecha o menu de build e despausa o jogo.
func _close_build_menu() -> void:
	if not _build_open:  # Já fechado: nada a fazer.
		return
	_build_menu.close()  # Fecha o menu.
	_build_open = false  # Marca como fechado.
	UiFx.swallow_attack_input()  # o clique que fechou o menu não pode virar um golpe
	get_tree().paused = false  # Despausa.
	Input.mouse_mode = _previous_mouse_mode  # Devolve o cursor.
