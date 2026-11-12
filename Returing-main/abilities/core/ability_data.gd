class_name AbilityData
extends Resource
## Dados de uma habilidade (amuleto). Um `.tres` por habilidade em `res://abilities/data/`.

enum Dir { UP, DOWN, LEFT, RIGHT }  # Direções das setas usadas nas sequências.
# Raridades: comum, avançada e lendária (a lendária apaga as outras habilidades).
enum Rarity { COMUM, AVANCADA, LENDARIA }
## Símbolo desenhado dentro do hexágono do amuleto (ignorado se `icon` estiver preenchido).
enum Glyph {
	NONE,
	DOUBLE_CHEVRON,
	SPEED_LINES,
	BLADE_ARC,
	DROP,
	FLAME,
	CONCENTRIC,
	SHIELD,
	CROSS,
	PIERCE_ARROW,
	HELM,
	BLOOD_BLADE,
	MASK,
}

const MIN_SEQUENCE: int = 3  # Mínimo de setas de uma sequência.
const MAX_SEQUENCE: int = 6  # Máximo de setas de uma sequência.

@export var id: StringName = &""  # Identificador único da habilidade.
## Nome do amuleto: curto (até ~20 caracteres), em português, direto.
@export var display_name: String = ""
## Efeito em no máximo 2 frases curtas.
@export_multiline var description: String = ""
## Sequência de setas (valores de `Dir`), de 3 a 6 setas.
@export var sequence: Array[int] = []
@export_group("Tempo")
## Recarga em segundos, contada a partir da ativação.
@export_range(0.0, 300.0, 0.5, "or_greater") var cooldown: float = 12.0
## Duração do efeito em segundos (0 = instantâneo).
@export_range(0.0, 120.0, 0.5, "or_greater") var duration: float = 0.0
@export_group("Visual")
@export var rarity: Rarity = Rarity.COMUM  # Raridade (define a cor do amuleto).
@export var glyph: Glyph = Glyph.NONE  # Símbolo desenhado dentro do amuleto.
## Opcional: se preenchido, substitui o glifo desenhado.
@export var icon: Texture2D
@export_group("Efeito")
## Cena do efeito (raiz herda de AbilityEffect).
@export var effect_scene: PackedScene
## Bônus multiplicativos do `StatBuffEffect`: atributo -> multiplicador final (1.2 = +20%).
@export var stat_mult: Dictionary = {}
## Bônus aditivos do `StatBuffEffect`: atributo -> valor somado (0.05 = +5%).
@export var stat_add: Dictionary = {}


## Validação do catálogo: emite `push_warning` e devolve false se algo estiver errado.
## Regras: 3 a 6 setas, sequências únicas e nenhuma sequência pode ser prefixo completo de outra
## (a mais longa nunca poderia ser digitada, pois a curta dispararia antes).
## Confere o catálogo inteiro: 3 a 6 setas, recarga maior que a duração, sem sequências repetidas e sem uma sequência ser o começo de outra.
static func validate(lista: Array[AbilityData]) -> bool:
	var ok: bool = true  # Resultado geral (vira false ao primeiro problema).
	for i: int in lista.size():  # Para cada habilidade da lista.
		var a: AbilityData = lista[i]  # Habilidade atual.
		if a == null:  # Item nulo no catálogo.
			push_warning("AbilityCatalog: item nulo na posição %d." % i)
			ok = false
			continue
		# Tamanho da sequência fora do permitido.
		if a.sequence.size() < MIN_SEQUENCE or a.sequence.size() > MAX_SEQUENCE:
			push_warning("AbilityData '%s': a sequência tem %d setas (permitido: %d a %d)." % [
					a.id, a.sequence.size(), MIN_SEQUENCE, MAX_SEQUENCE])
			ok = false
		if a.cooldown <= a.duration:  # A recarga precisa ser maior que a duração, senão o efeito nunca esfria.
			push_warning("AbilityData '%s': o cooldown (%s s) precisa ser maior que a duração (%s s)." % [a.id, a.cooldown, a.duration])
			ok = false
		for j: int in range(i + 1, lista.size()):  # Compara com todas as habilidades seguintes.
			var b: AbilityData = lista[j]  # Outra habilidade.
			if b == null:
				continue
			if a.sequence == b.sequence:  # Mesma sequência: impossível distinguir.
				push_warning("AbilityData '%s' e '%s' têm a mesma sequência." % [a.id, b.id])
				ok = false
			elif _is_prefix(a.sequence, b.sequence):  # Uma é o começo da outra (a menor dispararia antes).
				push_warning("AbilityData '%s' é prefixo completo de '%s': a mais longa nunca poderia ser digitada." % [a.id, b.id])
				ok = false
			elif _is_prefix(b.sequence, a.sequence):  # Mesma regra no sentido contrário.
				push_warning("AbilityData '%s' é prefixo completo de '%s': a mais longa nunca poderia ser digitada." % [b.id, a.id])
				ok = false
	return ok


## True se `curta` é o começo de `longa` (e é menor que ela).
## Diz se `curta` é o começo de `longa` (e é menor que ela).
static func _is_prefix(curta: Array[int], longa: Array[int]) -> bool:
	if curta.size() >= longa.size():  # Só é começo se for mais curta.
		return false
	for k: int in curta.size():  # Compara seta por seta.
		if curta[k] != longa[k]:  # Setas diferentes: não é começo.
			return false
	return true
