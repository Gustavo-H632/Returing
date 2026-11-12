extends TesteBase
## Cutscene da história: o finalzinho do rolamento acelera. Mede, sem ninguém pular, quanto tempo de jogo passa
## entre o começo do rolamento e o aparecimento do logo, com e sem a aceleração do final.

const SPEEDUP: float = 8.0  # Engine.time_scale do teste (só para não esperar minutos).


func _medir(multiplicador: float) -> float:
	var cena: Node = load("res://Scenes/Cut1/cutscene1.tscn").instantiate()
	cena.set("tail_speed_multiplier", multiplicador)
	get_tree().root.add_child(cena)
	get_tree().current_scene = cena
	Engine.time_scale = SPEEDUP
	var inicio: int = Time.get_ticks_msec()
	while cena.get("_logo") == null and Time.get_ticks_msec() - inicio < 150000:
		await get_tree().process_frame
	var jogo: float = float(Time.get_ticks_msec() - inicio) / 1000.0 * SPEEDUP
	Engine.time_scale = 1.0
	cena.queue_free()
	await get_tree().process_frame
	return jogo


func rodar() -> void:
	await set_window()
	var sem: float = await _medir(1.0)
	var com: float = await _medir(4.0)
	print("  tempo até o logo: sem aceleração ~%.0f s | com aceleração ~%.0f s" % [sem, com])
	check(com < sem - 10.0, "o final acelerado termina bem antes (%.0f s -> %.0f s)" % [sem, com])
	check(com > 20.0, "o começo e o meio continuam lentos (%.0f s no total)" % com)
