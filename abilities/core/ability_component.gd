class_name AbilityComponent
extends Node
## Cérebro do sistema de habilidades (filho do Player): modo comando, sequência de setas,
## cooldowns, ativação e efeitos ativos. Não conhece a HUD nem o menu: eles escutam os sinais.

signal command_mode_changed(ativo: bool)  # Avisa que o modo comando abriu (true) ou fechou (false).
# Avisa a sequência digitada até agora e as habilidades que ainda combinam.
signal input_progress(sequencia_atual: Array[int], candidatas: Array[AbilityData])
signal input_failed  # Avisa que a sequência digitada não combina com nenhuma habilidade.
signal ability_activated(ability: AbilityData)  # Avisa que uma habilidade foi ativada.
# Avisa a recarga de uma habilidade (restante e total).
signal cooldown_changed(ability: AbilityData, restante: float, total: float)
signal abilities_changed  # Avisa que a lista de habilidades mudou (aprendeu ou perdeu uma).
## O jogador apertou o Ctrl mas o modo não pode abrir por um motivo que ele precisa saber
## (`&"sem_habilidades"`). Estar em dash ou golpe não gera aviso: o modo abre ao terminar.
signal command_unavailable(motivo: StringName)

## Ctrl: abre o modo comando (aperta de novo para cancelar). Não precisa segurar.
const ACTION_COMMAND: StringName = &"command_mode"
## Enter: confirma a sequência digitada.
const ACTION_CONFIRM: StringName = &"cmd_confirm"
## Backspace: apaga a última seta digitada.
const ACTION_BACK: StringName = &"cmd_back"
## Ação de cada seta digitada no modo comando.
const ARROW_ACTIONS: Dictionary = {
	&"cmd_up": AbilityData.Dir.UP,
	&"cmd_down": AbilityData.Dir.DOWN,
	&"cmd_left": AbilityData.Dir.LEFT,
	&"cmd_right": AbilityData.Dir.RIGHT,
}

@export var catalog: AbilityCatalog  # Catálogo com todas as habilidades do jogo.
## Habilidades que o jogador possui. No jogo real são restauradas do `RunState`;
## o valor do Inspector serve para testar no editor.
@export var abilities: Array[AbilityData] = []

@export_group("Câmera lenta")
## Escala de tempo durante o modo comando (1.0 desliga o efeito). Vale enquanto o modo está aberto,
## e o modo só fecha com Enter, Ctrl ou pausa.
@export_range(0.05, 1.0) var command_time_scale: float = 0.2

## Bônus de atributo ativos (único ponto consultado pelo Player e pelos efeitos).
var stats: StatModifiers = StatModifiers.new()
var command_active: bool = false  # True enquanto o modo comando está aberto.

var _player: Player = null  # Jogador dono do componente.
var _sequence: Array[int] = []  # Setas digitadas até agora.
## id da habilidade -> segundos restantes de recarga.
var _cooldowns: Dictionary = {}
var _effects: Array[AbilityEffect] = []  # Efeitos ainda ativos.
var _slowed: bool = false  # True se a câmera lenta está ligada.
## True quando o modo foi aberto por toque (celular): a habilidade dispara ao completar a sequência
## (não há Enter) e o modo fica aberto até tocar de novo.
var _toggle_mode: bool = false
var _setup_done: bool = false  # True depois que a configuração terminou.
# Escala original da espada (os bônus multiplicam sobre ela).
var _weapon_base_scale: Vector2 = Vector2.ONE
## Fração de vida roubada ainda não convertida em 1 unidade de vida.
var _steal_accumulated: float = 0.0


## Liga o componente ao jogador e agenda a configuração para o fim do quadro.
func _ready() -> void:
	_player = get_parent() as Player  # O componente precisa ser filho direto do jogador.
	if _player == null:
		push_warning("AbilityComponent: precisa ser filho direto do Player.")
		return
	# Quando um bônus muda, reaplica área e dano da espada e a vida máxima.
	stats.changed.connect(_apply_stats)
	# O Player termina o próprio _ready depois dos filhos: a configuração espera o fim do frame.
	_setup.call_deferred()


## Ao sair da cena fecha o modo (devolve o tempo normal) e desliga os sinais.
func _exit_tree() -> void:
	close_command_mode()  # Garante que a câmera lenta termine.
	# Desliga o sinal de reinício de fase.
	CombatUtils.disconnect_if_connected(EventBus.level_restart_requested, RunState.mark_restart)
	if _player != null:  # Só se o jogador ainda existe.
		CombatUtils.disconnect_if_connected(_player.morreu, _on_player_died)  # Desliga o sinal de morte.
		if _player.weapon != null:  # Desliga o roubo de vida da espada.
			CombatUtils.disconnect_if_connected(_player.weapon.hit_landed, _on_weapon_hit_landed)


## Quando o jogo pausa (pausa, quiz, level-up), fecha o modo comando e devolve o tempo normal.
func _notification(what: int) -> void:
	# Pausa (menu de pausa, quiz, menu de level-up): sai do modo comando e devolve o tempo normal.
	if what == NOTIFICATION_PAUSED:  # Pausou: fecha o modo.
		close_command_mode()


## Configuração final: avisa o RunState, restaura as habilidades da run e liga os sinais do jogador.
func _setup() -> void:
	if _player == null or not is_inside_tree():  # Saiu da cena antes da hora.
		return
	# Raiz da cena onde o jogador foi criado.
	var scene_root: Node = _player.owner if _player.owner != null else get_tree().current_scene
	# Avisa a nova cena (decide entre run nova e checkpoint).
	RunState.begin_scene(scene_root.scene_file_path if scene_root != null else "")
	if catalog != null:  # Só se há catálogo.
		catalog.validate_once()  # Valida o catálogo uma vez.
		if not RunState.owned_ids.is_empty():  # Se a run já tem habilidades, restaura.
			abilities.clear()  # Recomeça a lista.
			for ability_id: StringName in RunState.owned_ids:  # Para cada id guardado na run.
				var data: AbilityData = catalog.find_by_id(ability_id)  # Procura a habilidade no catálogo.
				if data != null:  # Achou.
					abilities.append(data)  # Restaura.
	if _player.weapon != null:  # Só se o jogador tem arma.
		_weapon_base_scale = _player.weapon.scale  # Guarda a escala original da espada.
		# Escuta os acertos da espada (roubo de vida).
		CombatUtils.connect_once(_player.weapon.hit_landed, _on_weapon_hit_landed)
	CombatUtils.connect_once(_player.morreu, _on_player_died)  # Escuta a morte do jogador.
	# Escuta o reinício de fase.
	CombatUtils.connect_once(EventBus.level_restart_requested, RunState.mark_restart)
	_setup_done = true  # Pronto.
	abilities_changed.emit()  # Avisa a UI.


# --- Entrada ---

## Recebe as teclas: Ctrl abre/fecha; com o modo aberto, Enter confirma, Backspace apaga e as setas digitam.
func _input(event: InputEvent) -> void:
	if not _setup_done:  # Antes da configuração: ignora.
		return
	# Ctrl (esquerdo ou direito): abre; apertar de novo cancela. Eco de tecla segurada é ignorado.
	if event.is_action_pressed(ACTION_COMMAND):  # Ctrl pressionado.
		if command_active:  # Já aberto: cancela.
			close_command_mode()
		elif abilities.is_empty():  # Sem habilidades: avisa a HUD.
			command_unavailable.emit(&"sem_habilidades")
		elif can_open_command_mode():  # Pode abrir.
			_open_command_mode()  # Abre o modo.
		return
	if not command_active:  # Modo fechado: ignora o resto.
		return
	if event.is_action_pressed(ACTION_CONFIRM):  # Enter confirma a sequência.
		_confirm()  # Confirma.
		get_viewport().set_input_as_handled()  # Consome a tecla.
		return
	if event.is_action_pressed(ACTION_BACK):  # Backspace apaga a última seta.
		_erase_last_arrow()  # Apaga.
		get_viewport().set_input_as_handled()  # Consome a tecla.
		return
	for action: StringName in ARROW_ACTIONS:  # Cada seta possível.
		if event.is_action_pressed(action):  # Seta pressionada.
			_on_arrow(int(ARROW_ACTIONS[action]))  # Digita a seta.
			get_viewport().set_input_as_handled()  # Consome a tecla.
			return


## Abre com habilidades, vivo e sem pausa/quiz/menu (todos pausam a árvore). O jogador continua
## livre para andar, esquivar e atacar enquanto o modo está aberto.
func can_open_command_mode() -> bool:
	# Precisa estar configurado, com habilidades e sem pausa.
	if not _setup_done or _player == null or abilities.is_empty() or get_tree().paused:
		return false
	return not _player.esta_morto()  # E o jogador precisa estar vivo.


## Celular: abre ou fecha o modo comando com um toque (não há tecla para segurar).
func toggle_command_mode() -> void:
	if command_active:
		close_command_mode()
	elif can_open_command_mode():
		_open_command_mode(true)


## Celular: digita uma seta (valor de `AbilityData.Dir`) no modo comando.
func press_arrow(dir: int) -> void:
	if command_active:
		_on_arrow(dir)


## Abre o modo comando: limpa a sequência, liga a câmera lenta (se configurada) e avisa a UI.
func _open_command_mode(by_touch: bool = false) -> void:
	_toggle_mode = by_touch  # Guarda se foi por toque.
	command_active = true  # Marca como aberto.
	_sequence.clear()  # Começa uma sequência nova.
	if command_time_scale < 1.0:  # Câmera lenta ligada?
		Engine.time_scale = command_time_scale  # Aplica a escala de tempo.
		_slowed = true  # Lembra de devolver depois.
	command_mode_changed.emit(true)  # Avisa a abertura.
	input_progress.emit(_sequence.duplicate(), _candidates())  # Mostra as habilidades candidatas.


## Fecha o modo comando, apaga a sequência e devolve `Engine.time_scale = 1.0`.
## Seguro de chamar a qualquer momento (soltar a tecla, morte, pausa, level-up, troca de cena).
func close_command_mode() -> void:
	if _slowed:  # Devolve o tempo normal.
		Engine.time_scale = 1.0
		_slowed = false  # Não está mais lento.
	if not command_active:  # Já estava fechado: nada a fazer.
		return
	command_active = false  # Marca como fechado.
	_toggle_mode = false  # Limpa a marca de toque.
	_sequence.clear()  # Apaga a sequência.
	command_mode_changed.emit(false)  # Avisa o fechamento.


## Jogador morreu: fecha o modo e cancela os efeitos.
func _on_player_died() -> void:
	close_command_mode()  # Fecha o modo.
	_cancel_all_effects()  # Cancela os efeitos.


# --- Sequência ---

## Digitou uma seta: acrescenta à sequência, vê quem ainda combina e (no celular) dispara ao completar.
func _on_arrow(dir: int) -> void:
	_sequence.append(dir)  # Acrescenta a seta.
	var candidatas: Array[AbilityData] = _candidates()  # Habilidades que ainda combinam.
	if candidatas.is_empty():  # Nenhuma combina: erro.
		_fail()  # Zera a sequência e avisa o erro.
		return
	# Teclado: só digita; quem dispara é o Enter. Celular (sem Enter): dispara ao completar.
	if _toggle_mode and _try_activate():  # No celular tenta disparar na hora.
		input_progress.emit(_sequence.duplicate(), _candidates())  # Mostra a sequência zerada.
		return
	input_progress.emit(_sequence.duplicate(), candidatas)  # Mostra o progresso.


## Enter: dispara a habilidade cuja sequência é exatamente a digitada e fecha o modo.
## Sequência que não bate (ou habilidade em recarga) conta como erro e zera o que foi digitado.
func _confirm() -> void:
	if _sequence.is_empty():  # Sequência vazia: nada a confirmar.
		return
	if _try_activate():  # Disparou: fecha o modo.
		close_command_mode()
	else:
		_fail()  # Não bateu (ou em recarga): conta como erro.


## Ativa a habilidade que combina exatamente com a sequência digitada. False se nenhuma combina
## ou se está em recarga (a sequência é mantida; quem chamou decide se trata como erro).
func _try_activate() -> bool:
	for data: AbilityData in _candidates():  # Só as candidatas.
		if data.sequence.size() != _sequence.size():  # Ainda faltam setas para esta.
			continue
		if get_cooldown_left(data.id) > 0.0:  # Está em recarga.
			if _toggle_mode:  # No celular trata como erro na hora.
				_fail()  # celular: em recarga, trata como erro na hora
				return true  # Avisa que tratou o pedido.
			return false  # No teclado devolve false (o Enter decide).
		_sequence.clear()  # Limpa a sequência.
		_activate(data)  # Dispara a habilidade.
		return true  # Disparou.
	return false


## Backspace: apaga a última seta digitada.
func _erase_last_arrow() -> void:
	if _sequence.is_empty():  # Nada para apagar.
		return
	_sequence.pop_back()  # Remove a última seta.
	input_progress.emit(_sequence.duplicate(), _candidates())  # Atualiza as candidatas.


## Erro de digitação: zera a sequência e avisa a HUD.
func _fail() -> void:
	_sequence.clear()  # Zera.
	input_failed.emit()  # Avisa o erro (a HUD treme).
	input_progress.emit(_sequence.duplicate(), _candidates())  # Mostra a sequência zerada.


## Habilidades cuja sequência começa com o que já foi digitado.
func _candidates() -> Array[AbilityData]:
	var result: Array[AbilityData] = []  # Lista das candidatas.
	for data: AbilityData in abilities:  # Para cada habilidade.
		if data.sequence.size() < _sequence.size():  # Sequência dela é mais curta que a digitada: não combina.
			continue
		var combina: bool = true  # Combina até agora?
		for i: int in _sequence.size():  # Compara seta por seta.
			if data.sequence[i] != _sequence[i]:  # Setas diferentes.
				combina = false  # Não combina.
				break
		if combina:  # Combinou com tudo o que foi digitado.
			result.append(data)  # Candidata.
	return result


# --- Ativação e cooldown ---

## Ativa a habilidade: começa a recarga, cria o efeito como filho do jogador e avisa a UI.
func _activate(data: AbilityData) -> void:
	_cooldowns[data.id] = data.cooldown  # Começa a recarga.
	cooldown_changed.emit(data, data.cooldown, data.cooldown)  # Avisa a recarga cheia.
	_prune_effects()  # Remove efeitos que já terminaram.
	if data.effect_scene != null:  # Há cena de efeito.
		var effect: AbilityEffect = data.effect_scene.instantiate() as AbilityEffect  # Cria o efeito.
		if effect == null:  # A raiz precisa ser um AbilityEffect.
			# Avisa o erro no console.
			push_warning("AbilityComponent: a cena de '%s' precisa ter AbilityEffect na raiz." % data.id)
		else:
			effect.data = data  # Entrega os dados.
			_effects.append(effect)  # Guarda para cancelar depois.
			_player.add_child(effect)  # Entra na cena como filho do jogador.
			effect.activate(_player)  # Liga o efeito.
	ability_activated.emit(data)  # Avisa a ativação.


## A cada quadro de física desconta a recarga de todas as habilidades e avisa a UI.
func _physics_process(delta: float) -> void:
	if _cooldowns.is_empty():  # Nenhuma recarga: nada a fazer.
		return
	for ability_id: StringName in _cooldowns.keys():  # Para cada habilidade em recarga.
		# Desconta (nunca abaixo de zero).
		var restante: float = maxf(float(_cooldowns[ability_id]) - delta, 0.0)
		if restante <= 0.0:  # Acabou a recarga.
			_cooldowns.erase(ability_id)  # Remove da lista.
		else:
			_cooldowns[ability_id] = restante  # Guarda o tempo restante.
		var data: AbilityData = _find_owned(ability_id)  # Habilidade correspondente.
		if data != null:  # Ainda é do jogador.
			cooldown_changed.emit(data, restante, data.cooldown)  # Avisa o progresso da recarga.


## Segundos restantes de recarga (0 = pronta).
func get_cooldown_left(ability_id: StringName) -> float:
	return float(_cooldowns.get(ability_id, 0.0))


## Diz se o jogador possui a habilidade.
func has_ability(ability_id: StringName) -> bool:
	return _find_owned(ability_id) != null


## True se alguma habilidade possuída é lendária.
func has_legendary() -> bool:
	for data: AbilityData in abilities:
		if data.rarity == AbilityData.Rarity.LENDARIA:
			return true
	return false


## Procura a habilidade pelo id entre as que o jogador possui.
func _find_owned(ability_id: StringName) -> AbilityData:
	for data: AbilityData in abilities:
		if data.id == ability_id:
			return data
	return null


# --- Aprender e substituir ---

## Acrescenta uma habilidade.
func learn(data: AbilityData) -> void:
	if data == null or has_ability(data.id):  # Nula ou repetida: ignora.
		return
	abilities.append(data)  # Adiciona à lista.
	if not RunState.owned_ids.has(data.id):  # Guarda na run.
		RunState.owned_ids.append(data.id)
	abilities_changed.emit()  # Avisa a UI.


## Lendária: remove todas as outras, cancela os efeitos ativos e zera os cooldowns das removidas.
func replace_all_with(data: AbilityData) -> void:
	if data == null:
		return
	_cancel_all_effects()  # Cancela todos os efeitos ativos.
	_cooldowns.clear()  # Zera as recargas.
	stats.clear()  # Remove todos os bônus.
	abilities.clear()  # Apaga as outras habilidades.
	abilities.append(data)  # Fica só com a lendária.
	RunState.owned_ids.clear()  # Apaga a lista da run.
	RunState.owned_ids.append(data.id)  # Guarda só a lendária.
	abilities_changed.emit()  # Avisa a UI.


## Cancela todos os efeitos ativos (cada um desfaz o que aplicou).
func _cancel_all_effects() -> void:
	for effect: AbilityEffect in _effects:  # Para cada efeito.
		if is_instance_valid(effect) and not effect.is_queued_for_deletion():  # Só se ainda existe.
			effect.cancel()  # Cancela.
	_effects.clear()  # Esvazia a lista.


## Remove da lista os efeitos que já terminaram ou foram liberados.
func _prune_effects() -> void:
	for i: int in range(_effects.size() - 1, -1, -1):  # De trás para frente, para remover sem pular itens.
		if not is_instance_valid(_effects[i]) or _effects[i].is_queued_for_deletion():  # Já liberado.
			_effects.remove_at(i)  # Remove.


# --- Atributos que dependem de nós externos ---

## Reaplica o que os modificadores mudam fora do Player: área e dano da espada e vida máxima.
func _apply_stats() -> void:
	# Antes da configuração ou fora da cena: ignora.
	if not _setup_done or not is_instance_valid(_player) or not _player.is_inside_tree():
		return
	var weapon: Weapon = _player.weapon  # Arma do jogador.
	if weapon != null:  # Há arma.
		# A área da espada multiplica a escala original.
		weapon.scale = _weapon_base_scale * stats.get_mult(StatModifiers.SWORD_AREA)
		# O dano da espada multiplica o dano base.
		weapon.damage = roundi(float(_player.sword_damage) * stats.get_mult(StatModifiers.DAMAGE))
	_player.recalcular_hp_maximo()  # Recalcula a vida máxima.


## Roubo de vida: acumula a fração do dano e cura quando completa 1 unidade.
func _on_weapon_hit_landed(_target: Node, damage_dealt: int) -> void:
	var rate: float = stats.get_add(StatModifiers.LIFE_STEAL)  # Taxa de roubo de vida.
	if rate <= 0.0 or not is_instance_valid(_player):  # Sem roubo ativo: nada a fazer.
		return
	_steal_accumulated += float(damage_dealt) * rate  # Soma a fração do dano causado.
	var inteiro: int = int(_steal_accumulated)  # Parte inteira.
	if inteiro > 0:  # Completou pelo menos 1 ponto.
		_steal_accumulated -= float(inteiro)  # Guarda o resto.
		_player.curar(inteiro)  # Cura o jogador.
