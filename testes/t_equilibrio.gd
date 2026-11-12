extends TesteBase
## TESTE DE EQUILÍBRIO: a dificuldade do jogo não pode mudar.
## Compara a fotografia atual (`EquilibrioDump.coletar()`) com `testes/equilibrio_base.json`, gerada antes das
## mudanças desta rodada. A ÚNICA diferença permitida é a quantidade de inimigos por wave, que passa a ser
## `max(1, ceil(original x 0,5))` (conferida em `t_ondas.gd`); as ondas ORIGINAIS, de onde a conta parte,
## continuam iguais à base.
##
##   Gerar a base (só uma vez, antes de mexer no jogo):
##   godot --headless --path . res://testes/executor.tscn -- --teste=res://testes/t_equilibrio.gd --gerar-base

const BASE: String = "res://testes/equilibrio_base.json"


func rodar() -> void:
	var atual: Dictionary = JSON.parse_string(JSON.stringify(EquilibrioDump.coletar()))
	if "--gerar-base" in OS.get_cmdline_user_args():
		var arquivo: FileAccess = FileAccess.open(BASE, FileAccess.WRITE)
		arquivo.store_string(JSON.stringify(atual, "\t", true) + "\n")
		arquivo.close()
		check(true, "base gravada em %s" % BASE)
		return
	check(FileAccess.file_exists(BASE), "a base de equilíbrio existe")
	var base: Variant = JSON.parse_string(FileAccess.get_file_as_string(BASE))
	check(base is Dictionary, "a base de equilíbrio é um JSON válido")
	if not (base is Dictionary):
		return
	check(base["cenas"].size() > 30 and base["constantes"].size() > 30, "a base cobre jogador, inimigos, chefão, armas e habilidades")
	for parte: String in ["cenas", "constantes", "ondas"]:
		var lista: Array[String] = EquilibrioDump.diferencas(base[parte], atual[parte], parte)
		check(lista.is_empty(), "%s: nenhuma diferença em relação à base (%d encontradas)" % [parte, lista.size()])
		for linha: String in lista.slice(0, 40):
			print("       ", linha)
