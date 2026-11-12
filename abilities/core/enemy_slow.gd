class_name EnemySlow
extends RefCounted
## Lentidão aplicada em tempo de execução na `move_speed` dos inimigos, sem editar nenhum inimigo.
## Cada efeito (Pulso Gélido, Máquina Enigma) é uma "fonte". O primeiro efeito guarda a velocidade
## ORIGINAL do inimigo num metadado; enquanto houver alguma fonte vale a MAIS FORTE (menor fator).
## Quando a última fonte sai, a velocidade original é devolvida exatamente (nada de dividir de volta,
## que acumularia erro). Ao acabar uma fonte, a outra continua valendo.

## Velocidade original, guardada pela primeira fonte.
const META_BASE: StringName = &"slow_base_speed"
## Dictionary: id da fonte -> fator (0.5 = 50% mais lento).
const META_SOURCES: StringName = &"slow_sources"
## Cor do sprite antes da lentidão.
const META_MODULATE: StringName = &"slow_prev_modulate"


## Liga (ou atualiza) a lentidão da `source` no inimigo. `factor` multiplica a velocidade original.
static func apply(foe: EnemyBase, source: Object, factor: float, tint: Color = Color.WHITE) -> void:
	if not CombatUtils.is_alive(foe) or source == null:
		return
	var sources: Dictionary = foe.get_meta(META_SOURCES, {}) as Dictionary
	if sources.is_empty():
		foe.set_meta(META_BASE, foe.move_speed)
		if foe.sprite != null:
			foe.set_meta(META_MODULATE, foe.sprite.modulate)
			foe.sprite.modulate = tint
	sources[source.get_instance_id()] = clampf(factor, 0.0, 1.0)
	foe.set_meta(META_SOURCES, sources)
	_refresh(foe)


## Tira a lentidão da `source`. Sem mais nenhuma fonte, devolve a velocidade original exata.
static func remove(foe: EnemyBase, source: Object) -> void:
	if not is_instance_valid(foe) or source == null:
		return
	var sources: Dictionary = foe.get_meta(META_SOURCES, {}) as Dictionary
	if not sources.erase(source.get_instance_id()):
		return
	if not sources.is_empty():
		foe.set_meta(META_SOURCES, sources)
		_refresh(foe)
		return
	foe.move_speed = float(foe.get_meta(META_BASE, foe.move_speed))
	if foe.sprite != null and foe.has_meta(META_MODULATE):
		foe.sprite.modulate = foe.get_meta(META_MODULATE) as Color
	foe.remove_meta(META_SOURCES)
	foe.remove_meta(META_BASE)
	foe.remove_meta(META_MODULATE)


## True se a `source` já está deixando este inimigo lento.
static func has_source(foe: EnemyBase, source: Object) -> bool:
	if not is_instance_valid(foe) or source == null:
		return false
	var sources: Dictionary = foe.get_meta(META_SOURCES, {}) as Dictionary
	return sources.has(source.get_instance_id())


## True se alguma fonte está deixando o inimigo lento.
static func is_slowed(foe: EnemyBase) -> bool:
	return is_instance_valid(foe) and not (foe.get_meta(META_SOURCES, {}) as Dictionary).is_empty()


## Recalcula a velocidade a partir da original e do fator mais forte.
static func _refresh(foe: EnemyBase) -> void:
	var sources: Dictionary = foe.get_meta(META_SOURCES, {}) as Dictionary
	var strongest: float = 1.0
	for factor: Variant in sources.values():
		strongest = minf(strongest, float(factor))
	foe.move_speed = float(foe.get_meta(META_BASE, foe.move_speed)) * strongest
