class_name StatModifiers
extends RefCounted
## Único ponto de bônus de atributo das habilidades.
## Efeitos registram modificadores com `fonte = self` e removem tudo com `remove_source(self)`.

## Avisa quando qualquer modificador entra ou sai (o AbilityComponent reaplica o que depende disso).
signal changed

## MULT: `valor` é o multiplicador final (1.2 = +20%). Vários MULT se multiplicam.
## ADD: `valor` é somado (0.05 = +5 pontos percentuais, ou +N unidades).
enum Mode { MULT, ADD }

const MOVE_SPEED: StringName = &"move_speed"  # Nomes dos atributos que as habilidades podem alterar.
const DASH_DISTANCE: StringName = &"dash_distance"
const PROJECTILE_SPEED: StringName = &"projectile_speed"
const SWORD_AREA: StringName = &"sword_area"
const LIFE_STEAL: StringName = &"life_steal"
const MAX_HEALTH: StringName = &"max_health"
const HEAL_RECEIVED: StringName = &"heal_received"
const DAMAGE: StringName = &"damage"
## Multiplicador da recarga do dash (0.6 = recarga 40% menor).
const DASH_COOLDOWN: StringName = &"dash_cooldown"
## Multiplicador do tempo de carga do tiro (0.7 = carrega 30% mais rápido).
const CHARGE_TIME: StringName = &"charge_time"
## Multiplicador do dano recebido pelo Player (0.8 = recebe 20% menos).
const DAMAGE_TAKEN: StringName = &"damage_taken"

## Cada item: { "stat": StringName, "value": float, "mode": Mode, "source": int (instance id) }.
var _entries: Array[Dictionary] = []


## Registra um modificador. `fonte` identifica quem o criou (para remover depois).
## Registra um bônus. A `fonte` identifica quem o criou, para remover depois.
func add(stat: StringName, valor: float, modo: Mode, fonte: Object) -> void:
	if fonte == null:  # Sem fonte o bônus nunca poderia ser removido.
		# Avisa o erro no console.
		push_warning("StatModifiers.add: 'fonte' nula; o modificador não poderá ser removido.")
		return
	_entries.append({  # Guarda o bônus.
		"stat": stat,
		"value": valor,
		"mode": modo,
		"source": fonte.get_instance_id(),
	})
	changed.emit()  # Avisa que mudou.


## Remove todos os modificadores registrados pela fonte.
## Remove todos os bônus criados pela fonte (usado quando um efeito termina).
func remove_source(fonte: Object) -> void:
	if fonte == null:  # Sem fonte: nada a fazer.
		return
	var id: int = fonte.get_instance_id()  # Identificador da fonte.
	var removeu: bool = false  # True se removeu algo.
	for i: int in range(_entries.size() - 1, -1, -1):  # De trás para frente, para remover sem pular itens.
		if _entries[i]["source"] == id:  # Bônus da mesma fonte.
			_entries.remove_at(i)  # Remove.
			removeu = true
	if removeu:  # Só avisa se algo mudou.
		changed.emit()


## Remove tudo (ex.: lendária apagando as outras habilidades).
## Remove todos os bônus (ex.: lendária apagando as outras habilidades).
func clear() -> void:
	if _entries.is_empty():  # Já vazio: nada a fazer.
		return
	_entries.clear()  # Esvazia.
	changed.emit()


## Produto de todos os modificadores MULT do atributo (1.0 se não houver).
## Multiplica todos os bônus MULT do atributo (1.0 se não houver nenhum).
func get_mult(stat: StringName) -> float:
	var total: float = 1.0  # Começa em 1.0 (sem bônus).
	for entry: Dictionary in _entries:  # Passa por todos os bônus.
		if entry["stat"] == stat and entry["mode"] == Mode.MULT:  # Só os multiplicativos do atributo pedido.
			total *= float(entry["value"])  # Multiplica.
	return total


## Soma de todos os modificadores ADD do atributo (0.0 se não houver).
## Soma todos os bônus ADD do atributo (0.0 se não houver nenhum).
func get_add(stat: StringName) -> float:
	var total: float = 0.0  # Começa em 0.0.
	for entry: Dictionary in _entries:  # Passa por todos os bônus.
		if entry["stat"] == stat and entry["mode"] == Mode.ADD:  # Só os aditivos do atributo pedido.
			total += float(entry["value"])  # Soma.
	return total
