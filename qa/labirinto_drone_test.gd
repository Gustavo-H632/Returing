extends Node
## Teste dos drones do labirinto (Fase 2 nova): confere que patrulham pelas rotas e que perseguem o jogador
## DEPOIS DE UMA PAREDE sem travar. Rodar: godot --headless --path . res://qa/labirinto_drone_test.tscn

const FASE: String = "res://Scenes/Fase2/Labirinto.tscn"  # Fase do labirinto.
const PATRULHA_SEGUNDOS: float = 10.0  # Tempo observando a patrulha.
const PERSEGUICAO_SEGUNDOS: float = 20.0  # Tempo máximo para o drone alcançar o jogador atrás da parede.
const ALCANCE_PX: float = 70.0  # Distância que conta como "alcançou".

var _falhas: int = 0  # Falhas.
var _total: int = 0  # Total de verificações.
var _fase: Node = null  # Fase aberta.


## Agenda o teste para depois da criação dos nós.
func _ready() -> void:
	_rodar.call_deferred()


## Confere uma condição e conta a falha.
func _confere(condicao: bool, nome: String) -> void:
	_total += 1
	if not condicao:
		_falhas += 1
		printerr("FALHOU: ", nome)


## Espera `n` quadros de física.
func _fisica(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


## Abre o labirinto, roda os testes e sai com código de erro se algo falhou.
func _rodar() -> void:
	_fase = (load(FASE) as PackedScene).instantiate()
	get_tree().root.add_child(_fase)
	get_tree().current_scene = _fase
	await _fisica(10)
	var player := _fase.get_node("Player") as Player
	player.conceder_invulnerabilidade(100000.0)  # O teste não quer o Player morrendo.
	var drones: Array[DroneEnemy] = []
	for nome: String in ["Drone1", "Drone2", "Drone3"]:
		drones.append(_fase.get_node(nome) as DroneEnemy)
	for d: DroneEnemy in drones:
		_confere(d.state_machine.get_state(&"Patrol") is DroneRoutePatrolState, "%s: Patrol é o estado de rota" % d.name)
		_confere(d.state_machine.get_state(&"Chase") is DroneMazeChaseState, "%s: Chase é o estado do labirinto" % d.name)

	# 1) Patrulha: o jogador fica longe; cada drone tem que sair do lugar e seguir a rota.
	player.global_position = Vector2(64.0, 736.0)
	var inicio: Array[Vector2] = []
	for d: DroneEnemy in drones:
		inicio.append(d.global_position)
	await _fisica(int(PATRULHA_SEGUNDOS * 60.0))
	for i: int in drones.size():
		_confere(drones[i].global_position.distance_to(inicio[i]) > 20.0 or drones[i].velocity.length() > 0.0,
				"%s: patrulhou (saiu do lugar)" % drones[i].name)

	# 2) Perseguição atrás da parede: o Drone1 está na linha 3; o jogador aparece na célula (6,2), logo acima,
	# separado por uma parede. O caminho pelos corredores tem 3 células.
	var drone1: DroneEnemy = drones[0]
	drone1.global_position = Vector2(736.0, 400.0)
	player.global_position = Vector2(736.0, 288.0)
	var alcancou: bool = false
	for i: int in int(PERSEGUICAO_SEGUNDOS * 60.0):
		await get_tree().physics_frame
		if drone1.global_position.distance_to(player.global_position) < ALCANCE_PX:
			alcancou = true
			break
	_confere(alcancou, "Drone1 contornou a parede e alcançou o jogador (distância final %d px)"
			% int(drone1.global_position.distance_to(player.global_position)))

	# 3) Depois que o jogador some longe, o drone volta a patrulhar (não fica preso perseguindo).
	player.global_position = Vector2(64.0, 736.0)
	await _fisica(int(8.0 * 60.0))
	_confere(not drone1.has_target(), "Drone1 esqueceu o jogador distante")

	_fase.queue_free()
	await _fisica(3)
	print("labirinto_drone_test: %d verificações, %d falhas" % [_total, _falhas])
	get_tree().quit(1 if _falhas > 0 else 0)
