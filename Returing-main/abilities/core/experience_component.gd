class_name ExperienceComponent
extends Node
## XP e níveis (filho do Player). Não conhece a UI: ela escuta `xp_changed` e `level_up`.

# Avisa o XP atual, o necessário para o próximo nível e o nível atual.
signal xp_changed(xp: int, xp_proximo: int, nivel: int)
signal level_up(novo_nivel: int)  # Avisa que o jogador subiu de nível.

@export_group("XP")
## XP acumulado necessário para cada nível (o último valor é o nível máximo).
@export var xp_por_nivel: Array[int] = [100, 250, 400]
## Cada inimigo morto dá um inteiro aleatório entre estes dois valores.
@export var xp_min: int = 20
@export var xp_max: int = 30  # XP máximo ganho por inimigo.

var _player: Player = null  # Jogador dono do componente.


## Liga o componente ao jogador e ao evento de morte de inimigos; a configuração termina no fim do quadro.
func _ready() -> void:
	_player = get_parent() as Player  # O componente precisa ser filho direto do jogador.
	CombatUtils.connect_once(EventBus.enemy_died, _on_enemy_died)  # Cada inimigo morto dá XP.
	_setup.call_deferred()  # Espera o jogador terminar o próprio _ready.


## Ao sair da cena desliga o sinal do EventBus.
func _exit_tree() -> void:
	CombatUtils.disconnect_if_connected(EventBus.enemy_died, _on_enemy_died)


## Avisa o RunState que uma cena começou (ele decide se zera a run ou restaura o checkpoint) e reenvia o XP para a UI.
func _setup() -> void:
	if not is_inside_tree():  # Saiu da cena antes da hora.
		return
	var scene_root: Node = null  # Raiz da cena atual.
	if _player != null:
		scene_root = _player.owner  # Prefere a raiz da cena onde o jogador foi criado.
	if scene_root == null:
		scene_root = get_tree().current_scene  # Senão usa a cena atual.
	RunState.begin_scene(scene_root.scene_file_path if scene_root != null else "")  # Avisa a nova cena.
	_emit_xp()  # Manda o XP atual para a HUD.


## Reemite o estado atual (para a UI que acabou de conectar).
func refresh() -> void:
	_emit_xp()


## Nível máximo: a quantidade de limiares de XP.
func get_max_level() -> int:
	return xp_por_nivel.size()


## Diz se o jogador já chegou ao nível máximo.
func is_max_level() -> bool:
	return RunState.level >= get_max_level()


## XP acumulado em que o nível atual começou.
func get_level_floor() -> int:
	# Nível 0 começa em 0 XP; os outros no limiar do nível anterior.
	return 0 if RunState.level <= 0 else xp_por_nivel[mini(RunState.level, get_max_level()) - 1]


## XP acumulado necessário para o próximo nível (o do nível máximo, se já chegou lá).
func get_next_threshold() -> int:
	if xp_por_nivel.is_empty():  # Sem lista de níveis não há limiar.
		return 0
	# Limiar do próximo nível (ou do máximo, se já chegou).
	return xp_por_nivel[mini(RunState.level, get_max_level() - 1)]


## Níveis alcançados cujo menu de escolha ainda não foi resolvido (em ordem).
func get_pending_levels() -> Array[int]:
	var result: Array[int] = []  # Lista de níveis alcançados sem escolha resolvida.
	# Do primeiro pendente até o nível atual.
	for n: int in range(RunState.resolved_level + 1, RunState.level + 1):
		result.append(n)  # Guarda cada nível pendente.
	return result


## Soma XP e emite um `level_up` por nível cruzado (no nível máximo, ignora).
func add_xp(amount: int) -> void:
	# Ignora XP inválido, lista vazia ou nível máximo.
	if amount <= 0 or xp_por_nivel.is_empty() or is_max_level():
		return
	var teto: int = xp_por_nivel[get_max_level() - 1]  # Teto: o XP do nível máximo.
	RunState.xp = mini(RunState.xp + amount, teto)  # Soma sem passar do teto.
	# Enquanto o XP alcança o limiar do próximo nível.
	while RunState.level < get_max_level() and RunState.xp >= xp_por_nivel[RunState.level]:
		RunState.level += 1  # Sobe um nível.
		level_up.emit(RunState.level)  # Avisa cada nível cruzado (o menu de escolha aparece).
	_emit_xp()  # Atualiza a HUD.


## Um inimigo morreu: o jogador ganha um XP aleatório entre o mínimo e o máximo.
func _on_enemy_died(_enemy: Node2D, _kind: StringName, _world_position: Vector2) -> void:
	if _player != null and _player.esta_morto():  # Jogador morto não ganha XP.
		return
	add_xp(randi_range(mini(xp_min, xp_max), maxi(xp_min, xp_max)))  # Aceita mínimo e máximo invertidos.


## Envia XP, limiar e nível atuais para quem escuta.
func _emit_xp() -> void:
	xp_changed.emit(RunState.xp, get_next_threshold(), RunState.level)  # Avisa.
