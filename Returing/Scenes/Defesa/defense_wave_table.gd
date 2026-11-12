class_name DefenseWaveTable
extends Resource
## Tabela das waves da defesa (edite aqui ou no `wave_table.tres`, sem mexer no código).
## Tipos: "drone" (Drone), "robo" (Atirador) e "tank" (Tank).
##   Wave 1: só Drones. Wave 2: Drones + Atiradores. Wave 3 em diante: os três tipos, crescendo a cada wave.

## Waves escritas à mão, na ordem (índice 0 = wave 1): tipo -> quantidade.
@export var waves: Array[Dictionary] = [
	{"drone": 3},
	{"drone": 4, "robo": 2},
	{"drone": 4, "robo": 2, "tank": 1},
]
## Depois da última wave escrita: quanto cada tipo cresce POR WAVE (fração acumula: 0.5 = +1 a cada 2 waves).
@export var growth_per_wave: Dictionary = {"drone": 1.0, "robo": 1.0, "tank": 0.5}
## Limite de inimigos vivos ao mesmo tempo (os que sobrarem esperam espaço).
@export_range(1, 64, 1) var max_active: int = 20


## Quantidade de cada tipo que NASCE na wave `wave_number` (1 = primeira), já com o multiplicador de inimigos
## do autoload `Ondas`: max(1, ceil(original x 0,5)). Ex.: {"drone": 2, "robo": 1}.
func get_counts(wave_number: int) -> Dictionary:
	return Ondas.escalar_contagens(get_original_counts(wave_number))


## Quantidade ESCRITA na tabela (antes do multiplicador). Ex.: {"drone": 4, "robo": 2}.
func get_original_counts(wave_number: int) -> Dictionary:
	var result: Dictionary = {}
	if waves.is_empty():
		return result
	var index: int = clampi(wave_number - 1, 0, waves.size() - 1)
	var extra_waves: int = maxi(wave_number - waves.size(), 0)
	var base: Dictionary = waves[index]
	for kind: Variant in base:
		result[kind] = int(base[kind])
	if extra_waves > 0:
		for kind: Variant in growth_per_wave:
			result[kind] = int(result.get(kind, 0)) + int(floor(float(growth_per_wave[kind]) * float(extra_waves)))
	return result


## Total de inimigos de uma wave.
func get_total(wave_number: int) -> int:
	var total: int = 0
	var counts: Dictionary = get_counts(wave_number)
	for kind: Variant in counts:
		total += int(counts[kind])
	return total
