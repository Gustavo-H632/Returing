class_name RunState
extends RefCounted
## Estado da run (nível, XP e habilidades). Sobrevive à troca de fase sem precisar de autoload.
## Zera ao entrar na primeira fase e, ao reiniciar uma fase, volta ao estado do início dela.

## Entrar nesta cena começa uma run nova.
const FIRST_LEVEL_SCENE: String = "res://Scenes/Fase1/fase_1.tscn"

## Nível atual (0 a 3).
static var level: int = 0
## XP acumulado (para de crescer no nível máximo).
static var xp: int = 0
## Maior nível cujo menu de escolha já foi resolvido (níveis acima disso estão pendentes).
static var resolved_level: int = 0
## Ids das habilidades que o jogador possui.
static var owned_ids: Array[StringName] = []
## Ids das habilidades rejeitadas (nunca mais aparecem nesta run).
static var rejected_ids: Array[StringName] = []
## True depois que o jogador abriu o modo comando pela primeira vez (a dica na tela some).
static var command_hint_seen: bool = false

static var _checkpoint: Dictionary = {}  # Cópia do estado no começo da fase (usada ao reiniciar).
static var _restart_pending: bool = false  # True se a fase vai ser reiniciada.
# Último quadro em que begin_scene agiu (impede rodar duas vezes no mesmo quadro).
static var _last_begin_frame: int = -1


## Zera tudo (run nova).
## Zera tudo: nível, XP, habilidades e as estatísticas da run (começo de uma run nova).
static func reset() -> void:
	level = 0  # Nível inicial.
	xp = 0  # XP inicial.
	resolved_level = 0  # Nenhum nível resolvido.
	owned_ids.clear()  # Sem habilidades.
	rejected_ids.clear()  # Sem rejeitadas.
	command_hint_seen = false  # A dica do modo comando volta a aparecer.
	RunStats.reset()  # Zera também a pontuação da run.


## Chamado pelos componentes do Player ao nascer numa fase (só o primeiro chamado no frame age).
## Decide o que fazer ao nascer numa fase: restaurar o checkpoint (reinício), zerar (primeira fase ou sem checkpoint) ou manter. Depois guarda um novo checkpoint.
static func begin_scene(scene_path: String) -> void:
	var frame: int = Engine.get_process_frames()  # Quadro atual.
	# Vários componentes chamam esta função no mesmo quadro: só o primeiro age.
	if frame == _last_begin_frame:
		return
	_last_begin_frame = frame  # Guarda o quadro.
	if _restart_pending and not _checkpoint.is_empty():  # Reinício de fase: volta ao estado do começo dela.
		_restore_checkpoint()  # Restaura.
	# Primeira fase ou sem checkpoint: run nova.
	elif scene_path == FIRST_LEVEL_SCENE or _checkpoint.is_empty():
		reset()  # Zera.
	_restart_pending = false  # O pedido de reinício foi atendido.
	_save_checkpoint()  # Guarda o estado do começo desta fase.


## A fase vai ser reiniciada (game over, "Tentar de novo" ou Reset da pausa): na próxima fase
## o estado volta ao do início da fase que acabou de ser jogada.
## Marca que a próxima fase deve restaurar o checkpoint (game over, tentar de novo ou reiniciar pela pausa).
static func mark_restart() -> void:
	_restart_pending = true  # Marca o pedido.


## Marca um nível como resolvido (o menu dele já foi respondido).
## Marca um nível como resolvido (o menu dele já foi respondido).
static func resolve_level(novo_nivel: int) -> void:
	resolved_level = maxi(resolved_level, novo_nivel)  # Guarda o maior nível resolvido.


## Marca habilidades como rejeitadas.
## Marca habilidades como rejeitadas (nunca mais aparecem nesta run).
static func reject(ids: Array[StringName]) -> void:
	for ability_id: StringName in ids:  # Para cada id.
		if not rejected_ids.has(ability_id):  # Evita repetição.
			rejected_ids.append(ability_id)  # Guarda.


## Ids que não podem mais ser sorteados (possuídas + rejeitadas).
## Junta as habilidades que não podem mais ser sorteadas (possuídas e rejeitadas).
static func excluded_ids() -> Array[StringName]:
	var result: Array[StringName] = []  # Lista de resultado.
	result.append_array(owned_ids)  # Possuídas.
	result.append_array(rejected_ids)  # Rejeitadas.
	return result


## Guarda uma cópia do estado atual para poder restaurar ao reiniciar a fase.
static func _save_checkpoint() -> void:
	_checkpoint = {  # Copia nível, XP, resolvidas e listas (duplicadas para não mudarem depois).
		"level": level,
		"xp": xp,
		"resolved": resolved_level,
		"owned": owned_ids.duplicate(),
		"rejected": rejected_ids.duplicate(),
	}


## Restaura o estado guardado no checkpoint.
static func _restore_checkpoint() -> void:
	level = int(_checkpoint["level"])  # Nível.
	xp = int(_checkpoint["xp"])  # XP.
	resolved_level = int(_checkpoint["resolved"])  # Nível resolvido.
	owned_ids.assign(_checkpoint["owned"])  # Habilidades possuídas.
	rejected_ids.assign(_checkpoint["rejected"])  # Habilidades rejeitadas.
