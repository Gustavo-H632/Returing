extends TesteBase
## Seção 12.5: cada wave do jogo nasce com max(1, ceil(original x 0,5)) inimigos de cada tipo, na mesma ordem de
## aparição; chefes continuam 1. Os números ORIGINAIS vêm de `testes/equilibrio_base.json` (gerado antes da mudança),
## não do código atual — assim o teste não "confia" na conta que ele mesmo está conferindo.

const BASE: String = "res://testes/equilibrio_base.json"


func rodar() -> void:
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE))
	var ondas: Dictionary = base["ondas"]
	check(is_equal_approx(Ondas.MULTIPLICADOR_INIMIGOS, 0.5), "Ondas.MULTIPLICADOR_INIMIGOS = 0,5 (um único lugar)")
	check(Ondas.escalar(1) == 1 and Ondas.escalar(2) == 1 and Ondas.escalar(3) == 2 and Ondas.escalar(4) == 2 and Ondas.escalar(5) == 3 and Ondas.escalar(0) == 0,
			"regra: max(1, ceil(n x 0,5)) e zero continua zero")
	block_scene_changes()

	# --- Defesa do portal: a tabela devolve a quantidade reduzida em todas as waves da amostra.
	var tabela: DefenseWaveTable = load("res://Scenes/Defesa/wave_table.tres")
	var originais: Array = ondas["res://Scenes/Defesa/wave_table.tres"]["ondas"]
	var defesa_ok: bool = true
	for i: int in originais.size():
		var esperado: Dictionary = {}
		for tipo: String in originais[i]:
			esperado[tipo] = _esperado(int(originais[i][tipo]))
		var atual: Dictionary = tabela.get_counts(i + 1)
		var total: int = 0
		for tipo: String in esperado:
			total += int(esperado[tipo])
			if int(atual.get(tipo, -1)) != int(esperado[tipo]):
				defesa_ok = false
				print("       defesa wave %d: %s = %s (esperado %s)" % [i + 1, tipo, atual.get(tipo), esperado[tipo]])
		if atual.size() != esperado.size() or tabela.get_total(i + 1) != total:
			defesa_ok = false
		print("       defesa wave %2d: %s -> %s" % [i + 1, JSON.stringify(originais[i]), JSON.stringify(atual)])
	check(defesa_ok, "defesa do portal: %d waves com max(1, ceil(original x 0,5)) por tipo" % originais.size())
	check(int(ondas["res://Scenes/Defesa/wave_table.tres"]["max_active"]) == tabela.max_active, "defesa: limite de inimigos vivos igual ao original")

	# --- Fases com WaveManager: a lista que o gerenciador usa de verdade, depois do _ready.
	for chave: String in ondas:
		if not chave.contains("::"):
			continue
		var caminho: String = chave.get_slice("::", 0)
		load_level(caminho)
		await frames(5)
		var gerente: WaveManager = level.get_node(chave.get_slice("::", 1)) as WaveManager
		var escritas: Array = ondas[chave]["ondas"].filter(func(o: Array) -> bool: return not o.is_empty())
		check(gerente != null and gerente._waves.size() == escritas.size(), "%s: mesmo número de waves (%d)" % [caminho.get_file(), escritas.size()])
		for i: int in escritas.size():
			var atual: Array = EquilibrioDump.contar_cenas(gerente._waves[i])
			var esperado: Array = []
			for par: Array in escritas[i]:
				esperado.append([par[0], _esperado(int(par[1]))])
			check(JSON.stringify(atual) == JSON.stringify(esperado), "%s wave %d: %s -> %s (mesma ordem de tipos)" % [caminho.get_file(), i + 1, _resumo(escritas[i]), _resumo(atual)])
		check(is_equal_approx(gerente.first_wave_delay, float(ondas[chave]["first_wave_delay"])) and is_equal_approx(gerente.between_waves_delay, float(ondas[chave]["between_waves_delay"])),
				"%s: intervalos entre waves iguais ao original" % caminho.get_file())
		if caminho.contains("Fase3"):
			var chefes: Array[Node] = level.find_children("*", "GuideEnemy", true, false)
			check(chefes.size() == 1, "Fase 3: o chefão continua sendo 1 (%d)" % chefes.size())
		await unload_level()
		await frames(3)

	# --- Fase 1 jogando: a primeira wave nasce com a quantidade reduzida.
	var nascidos: Array[int] = []
	EventBus.wave_started.connect(func(_n: int, _total: int, vivos: int) -> void: nascidos.append(vivos))
	load_level("res://Scenes/Fase1/fase_1.tscn")
	player().conceder_invulnerabilidade(9999.0)
	await seconds(2.0)
	var primeira: Array = ondas["res://Scenes/Fase1/fase_1.tscn::WaveManager"]["ondas"][0]
	var total_esperado: int = 0
	for par: Array in primeira:
		total_esperado += _esperado(int(par[1]))
	check(nascidos.size() == 1 and nascidos[0] == total_esperado, "Fase 1 em jogo: a wave 1 nasce com %d inimigos (%s)" % [total_esperado, nascidos])
	var inimigos: int = get_tree().get_nodes_in_group(&"enemy").size()
	check(inimigos == total_esperado, "Fase 1 em jogo: %d inimigos na cena" % inimigos)
	await unload_level()


## A regra escrita de forma independente do autoload.
func _esperado(original: int) -> int:
	return maxi(1, int(ceil(float(original) * 0.5)))


func _resumo(onda: Array) -> String:
	var partes: PackedStringArray = []
	for par: Array in onda:
		partes.append("%d %s" % [int(par[1]), String(par[0]).get_file().get_basename()])
	return ", ".join(partes)
