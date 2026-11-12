extends TesteBase
## As 9 habilidades novas (do zip habilidades-extras) funcionando no jogo atual: catálogo com 21, sequências
## válidas, buffs de atributo, lentidão, mina, drone, leque e a penalidade do Overclock.

const NOVAS: Array[StringName] = [
	&"reflexos", &"carga_rapida", &"pele_de_ferro", &"overclock", &"pulso_gelido",
	&"mina_binaria", &"drone_aliado", &"tiro_em_leque", &"maquina_enigma",
]


func _ativar(ab: AbilityComponent, id: StringName) -> AbilityData:
	var data: AbilityData = load("res://abilities/data/%s.tres" % id) as AbilityData
	ab.call("_activate", data)
	return data


func rodar() -> void:
	await set_window()
	var catalogo: AbilityCatalog = load("res://abilities/data/ability_catalog.tres") as AbilityCatalog
	check(catalogo.abilities.size() == 21, "o catálogo tem 21 habilidades (%d)" % catalogo.abilities.size())
	check(AbilityData.validate(catalogo.abilities), "o catálogo é válido (sequências únicas, recargas, penalidade)")
	var ids: Array[StringName] = []
	for a: AbilityData in catalogo.abilities:
		ids.append(a.id)
	for id: StringName in NOVAS:
		check(ids.has(id), "o catálogo inclui %s" % id)

	load_level("res://Scenes/Fase1/fase_1.tscn")
	await frames(20)
	var p: Player = player()
	p.conceder_invulnerabilidade(9999.0)
	var ab: AbilityComponent = p.get_node("AbilityComponent") as AbilityComponent
	check(p.hp_maximo == 100, "vida do Turing = 100 (%d)" % p.hp_maximo)

	# Buffs de atributo (Reflexos, Carga Rápida, Pele de Ferro).
	var base_carga: float = p._tempo_de_carga()
	_ativar(ab, &"carga_rapida")
	await frames(3)
	check(is_equal_approx(p._tempo_de_carga(), base_carga * 0.7), "Carga Rápida: tempo de carga x0,7 (%.2f -> %.2f)" % [base_carga, p._tempo_de_carga()])
	_ativar(ab, &"reflexos")
	await frames(3)
	check(is_equal_approx(p._stat_mult(StatModifiers.DASH_COOLDOWN), 0.6), "Reflexos: recarga do dash x0,6")
	_ativar(ab, &"pele_de_ferro")
	await frames(3)
	check(is_equal_approx(p._stat_mult(StatModifiers.DAMAGE_TAKEN), 0.8), "Pele de Ferro: dano recebido x0,8")
	p.conceder_invulnerabilidade(0.0)
	await frames(2)
	var antes: int = p.hp
	p.tomar_dano(10, true)
	check(antes - p.hp == 8, "Pele de Ferro: 10 de dano vira 8 (%d)" % (antes - p.hp))
	p.conceder_invulnerabilidade(9999.0)

	# Reativar renova (não acumula).
	_ativar(ab, &"pele_de_ferro")
	await frames(3)
	check(is_equal_approx(p._stat_mult(StatModifiers.DAMAGE_TAKEN), 0.8), "reativar Pele de Ferro não acumula (x%.2f)" % p._stat_mult(StatModifiers.DAMAGE_TAKEN))

	# Lentidão: Pulso Gélido e Máquina Enigma.
	var inimigos: Array[Node] = get_tree().get_nodes_in_group(&"enemy")
	check(true, "inimigos na cena antes da onda: %d" % inimigos.size())
	var cena: PackedScene = load("res://enemies/robo/RoboEnemy.tscn") as PackedScene
	var robo: EnemyBase = cena.instantiate() as EnemyBase
	level.add_child(robo)
	robo.global_position = p.global_position + Vector2(60.0, 0.0)
	await frames(5)
	var vel0: float = robo.move_speed
	_ativar(ab, &"pulso_gelido")
	await frames(8)
	check(robo.move_speed < vel0, "Pulso Gélido deixa o inimigo mais lento (%.0f -> %.0f)" % [vel0, robo.move_speed])
	_ativar(ab, &"maquina_enigma")
	await frames(8)
	check(robo.move_speed < vel0, "Máquina Enigma deixa o inimigo mais lento (%.0f -> %.0f)" % [vel0, robo.move_speed])

	# Mina, Drone e Leque criam objetos na cena.
	var antes_n: int = level.get_child_count()
	_ativar(ab, &"mina_binaria")
	await frames(6)
	var minas: Array[Node] = level.find_children("*", "BinaryMine", true, false)
	check(not minas.is_empty(), "Mina Binária planta uma mina (%d)" % minas.size())
	_ativar(ab, &"drone_aliado")
	await frames(10)
	var drones: Array[Node] = get_tree().root.find_children("*", "AllyDrone", true, false)
	check(not drones.is_empty(), "Drone Aliado aparece (%d)" % drones.size())
	_ativar(ab, &"tiro_em_leque")
	await frames(6)
	var tiros: Array[PlayerProjectile] = active_projectiles()
	check(tiros.size() >= 5, "Tiro em Leque dispara 5 projéteis (%d)" % tiros.size())

	# Overclock: bônus e depois penalidade.
	var oc: AbilityData = _ativar(ab, &"overclock")
	await frames(3)
	var dano_bonus: float = p._stat_mult(StatModifiers.DAMAGE)
	check(dano_bonus > 1.0, "Overclock: +dano durante o bônus (x%.2f)" % dano_bonus)
	check(not oc.is_penalty_at(5.0) and oc.is_penalty_at(12.0), "Overclock: penalidade nos últimos 5 s da duração")
	print("  (observações: %d objetos novos na fase)" % (level.get_child_count() - antes_n))
