class_name AbilityCatalog
extends Resource
## Catálogo único com todas as habilidades. Para criar uma nova, duplique um `.tres` e adicione aqui.

## Quantas cartas o menu de level-up oferece.
const OFFER_SIZE: int = 3

@export var abilities: Array[AbilityData] = []  # Lista de todas as habilidades do jogo.

@export_group("Oferta")
## Peso de uma lendária no sorteio (1.0 = igual às demais; menor = mais rara).
@export_range(0.0, 10.0, 0.05) var legendary_weight: float = 1.0
## Menor nível em que lendárias podem aparecer.
@export_range(1, 10) var legendary_min_level: int = 3

# True depois de validar o catálogo (a validação roda uma vez por execução).
static var _validated: bool = false


## Roda o validador uma vez por execução do jogo.
func validate_once() -> void:
	if _validated:  # Só valida uma vez.
		return
	_validated = true  # Marca como validada.
	AbilityData.validate(abilities)  # Avisa no console sequências repetidas ou inválidas.


## Procura uma habilidade pelo id (null se não existir).
func find_by_id(ability_id: StringName) -> AbilityData:
	for data: AbilityData in abilities:  # Procura pelo id.
		if data != null and data.id == ability_id:  # Ignora itens nulos.
			return data
	return null


## Sorteia até 3 habilidades para o nível, sem repetir e sem as ids excluídas
## (já possuídas ou rejeitadas). Lendárias só entram a partir de `legendary_min_level`.
func draw_offer(level: int, excluded_ids: Array[StringName]) -> Array[AbilityData]:
	var pool: Array[AbilityData] = []  # Candidatas ao sorteio.
	for data: AbilityData in abilities:  # Passa por todas as habilidades.
		if data == null or excluded_ids.has(data.id):  # Ignora nulas, possuídas e rejeitadas.
			continue
		# Lendárias só a partir do nível mínimo.
		if data.rarity == AbilityData.Rarity.LENDARIA and level < legendary_min_level:
			continue
		pool.append(data)  # Entra na lista de candidatas.

	var result: Array[AbilityData] = []  # Cartas sorteadas.
	# Sorteia até completar a oferta ou acabarem as candidatas.
	while result.size() < OFFER_SIZE and not pool.is_empty():
		var total: float = 0.0  # Soma dos pesos.
		for data: AbilityData in pool:
			total += _weight_of(data)  # Cada candidata tem seu peso.
		var pick: int = pool.size() - 1  # Por padrão a última (se o total for zero).
		if total > 0.0:  # Há peso para sortear.
			var roll: float = randf() * total  # Número sorteado entre 0 e o total.
			var acumulado: float = 0.0  # Peso acumulado.
			for i: int in pool.size():  # Anda pela lista somando pesos.
				acumulado += _weight_of(pool[i])
				if roll < acumulado:  # O sorteio caiu nesta candidata.
					pick = i  # Guarda o índice.
					break
		result.append(pool[pick])  # Adiciona à oferta.
		pool.remove_at(pick)  # Remove da lista (não repete na mesma oferta).
	return result  # Devolve as cartas.


## Peso de uma habilidade no sorteio: lendárias usam `legendary_weight`, as demais valem 1.
func _weight_of(data: AbilityData) -> float:
	return legendary_weight if data.rarity == AbilityData.Rarity.LENDARIA else 1.0
