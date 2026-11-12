extends TesteBase
## Fase 1: nenhum inimigo nasce dentro de carro/parede e nenhum fica preso parado atrás de um obstáculo.
## Repete a primeira onda várias vezes com o jogador parado e invulnerável.
## `--antigo`: reproduz o comportamento anterior (marcadores antigos e sem a checagem de colisão), para comparar.

const REPETICOES: int = 12
const SEGUNDOS_POR_REPETICAO: float = 14.0  # tempo de jogo
const VELOCIDADE: float = 4.0  # Engine.time_scale
const JANELA: float = 6.0  # parado nesta janela, longe do jogador, é suspeito
const PARADO_PX: float = 8.0
const LONGE_DO_JOGADOR: float = 70.0

const MARCADORES_ANTIGOS: Dictionary = {
	"SpawnA": Vector2(520, 250), "SpawnB": Vector2(129, 416), "SpawnH": Vector2(420, 120),
}


func _toca_mundo(espaco: PhysicsDirectSpaceState2D, p: Vector2, raio: float) -> bool:
	var forma := CircleShape2D.new()
	forma.radius = raio
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = forma
	q.transform = Transform2D(0.0, p)
	q.collision_mask = 1
	return not espaco.intersect_shape(q, 1).is_empty()


func _inimigos() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for c: Node in get_tree().get_nodes_in_group(&"enemy"):
		if c is Node2D and not c.is_queued_for_deletion():
			out.append(c as Node2D)
	return out


func rodar() -> void:
	var antigo: bool = OS.get_cmdline_user_args().has("--antigo")
	await set_window()
	var nasceram_presos: int = 0
	var total_nascidos: int = 0
	var presos: int = 0  # parados atrás de obstáculo
	var em_posicao: int = 0  # parados com visão livre (atiradores): normal
	for rep: int in REPETICOES:
		load_level("res://Scenes/Fase1/fase_1.tscn")
		await frames(3)
		var wm: Node = level.get_node("WaveManager")
		if antigo:
			wm.set("spawn_clearance", 0.0)
			for nome: String in MARCADORES_ANTIGOS:
				(level.get_node("SpawnPoints/" + nome) as Marker2D).global_position = MARCADORES_ANTIGOS[nome]
		var jogador: Player = player()
		jogador.conceder_invulnerabilidade(9999.0)
		var espaco: PhysicsDirectSpaceState2D = level.get_world_2d().direct_space_state
		Engine.time_scale = VELOCIDADE
		var guarda: int = 0
		while _inimigos().is_empty() and guarda < 600:
			await get_tree().physics_frame
			guarda += 1
		for e: Node2D in _inimigos():
			total_nascidos += 1
			if _toca_mundo(espaco, e.global_position, 9.0):
				nasceram_presos += 1
		var historico: Dictionary = {}  # id -> posições amostradas
		var refs: Dictionary = {}  # id -> inimigo
		var t: float = 0.0
		var ultimo: float = -1.0
		while t < SEGUNDOS_POR_REPETICAO:
			await get_tree().physics_frame
			t += get_physics_process_delta_time() * VELOCIDADE
			if t - ultimo >= 0.5:
				ultimo = t
				for e: Node2D in _inimigos():
					var id: int = e.get_instance_id()
					if not historico.has(id):
						historico[id] = []
					(historico[id] as Array).append(e.global_position)
					refs[id] = e
		var janela: int = int(JANELA / 0.5)
		for id: int in historico:
			var pos: Array = historico[id]
			if pos.size() <= janela:
				continue
			var suspeito: bool = false
			for i: int in range(0, pos.size() - janela):
				var mn: Vector2 = pos[i]
				var mx: Vector2 = pos[i]
				for j: int in range(i, i + janela + 1):
					mn = mn.min(pos[j])
					mx = mx.max(pos[j])
				var perto: bool = (pos[i + janela] as Vector2).distance_to(jogador.global_position) < LONGE_DO_JOGADOR
				if (mx - mn).length() < PARADO_PX and not perto:
					suspeito = true
					break
			if not suspeito:
				continue
			var no: Node2D = refs[id] as Node2D
			if not is_instance_valid(no):
				continue
			var rq: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(no.global_position, jogador.global_position, 1)
			var bloqueada: bool = not espaco.intersect_ray(rq).is_empty()
			print("    parado: %s em %s | visao do jogador %s" % [no.scene_file_path.get_file(), no.global_position.round(), "BLOQUEADA" if bloqueada else "livre"])
			if bloqueada:
				presos += 1
			else:
				em_posicao += 1
		Engine.time_scale = 1.0
		await unload_level()
	print("  modo: %s | nasceram: %d | nasceram encostando no mundo: %d | presos atras de obstaculo: %d | parados com visao livre: %d" % [
			"ANTIGO" if antigo else "NOVO", total_nascidos, nasceram_presos, presos, em_posicao])
	if not antigo:
		check(total_nascidos > 0, "inimigos nasceram nas ondas (%d)" % total_nascidos)
		check(nasceram_presos == 0, "nenhum inimigo nasce dentro de carro, parede ou cerca (%d)" % nasceram_presos)
		check(presos == 0, "nenhum inimigo fica preso atras de obstaculo (%d)" % presos)
