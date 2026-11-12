extends Node
## Autoload Ondas: ÚNICO lugar que decide quantos inimigos cada wave tem em relação ao que está escrito nas cenas
## e tabelas. Vale para todas as waves do jogo (Fase 1, wave de transição do chefão, defesa do portal).
##
## Regra: quantidade por tipo = max(1, ceil(original x MULTIPLICADOR_INIMIGOS)). Chefes não passam por aqui
## (continuam 1). Vida, dano, velocidade, ordem de aparição e intervalos de spawn não mudam.

## Fração dos inimigos de cada wave que realmente nasce (0.5 = metade, arredondando para cima, mínimo 1).
@export_range(0.05, 1.0, 0.05) var MULTIPLICADOR_INIMIGOS: float = 0.5


## Quantidade de um tipo depois do multiplicador. Zero continua zero (tipo que não aparece na wave).
func escalar(original: int) -> int:
	if original <= 0:
		return 0
	return maxi(1, ceili(float(original) * MULTIPLICADOR_INIMIGOS - 0.000001))


## Wave escrita como lista de cenas (WaveManager): mantém as primeiras `escalar(n)` ocorrências de cada tipo,
## na ordem em que aparecem, preservando a ordem de aparição e a proporção entre os tipos.
func escalar_cenas(onda: Array[PackedScene]) -> Array[PackedScene]:
	var total: Dictionary = {}
	for cena: PackedScene in onda:
		if cena != null:
			total[cena] = int(total.get(cena, 0)) + 1
	var usados: Dictionary = {}
	var out: Array[PackedScene] = []
	for cena: PackedScene in onda:
		if cena == null:
			continue
		var ja: int = int(usados.get(cena, 0))
		if ja < escalar(int(total[cena])):
			out.append(cena)
			usados[cena] = ja + 1
	return out


## Wave escrita como dicionário tipo -> quantidade (defesa do portal).
func escalar_contagens(contagens: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for tipo: Variant in contagens:
		out[tipo] = escalar(int(contagens[tipo]))
	return out
