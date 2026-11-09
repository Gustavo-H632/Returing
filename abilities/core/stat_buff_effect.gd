class_name StatBuffEffect
extends AbilityEffect
## Buff genérico de atributos. Os valores vêm do `.tres` da habilidade (`stat_mult` e `stat_add`),
## então várias habilidades reaproveitam esta mesma cena. Dura `data.duration` segundos.

var _time_left: float = 0.0  # Tempo restante do buff.


## Aplica os bônus da habilidade e começa a contar a duração (duração zero = efeito instantâneo).
func _on_activate() -> void:
	_apply_stats()  # Registra os bônus.
	_time_left = data.duration if data != null else 0.0  # Duração vinda do .tres da habilidade.
	if _time_left <= 0.0:  # Sem duração: termina já.
		_finish()  # Termina e remove os bônus.


## A cada quadro de física desconta a duração e termina o buff quando acaba.
func _physics_process(delta: float) -> void:
	if _time_left <= 0.0:  # Já acabou (ou instantâneo).
		return
	_time_left -= delta  # Desconta o tempo.
	if _time_left <= 0.0:  # Acabou: termina.
		_finish()  # Remove os bônus.


## Ao terminar remove todos os bônus que este efeito registrou.
func _on_cleanup() -> void:
	var stats: StatModifiers = get_stats()  # Gerenciador de bônus.
	if stats != null:  # Ainda existe.
		stats.remove_source(self)  # Remove os bônus desta fonte.


## Registra os modificadores da habilidade (filhas podem acrescentar outros).
func _apply_stats() -> void:
	var stats: StatModifiers = get_stats()  # Gerenciador de bônus.
	if stats == null or data == null:  # Sem gerenciador ou sem dados: nada a aplicar.
		return
	for key: Variant in data.stat_mult:  # Bônus multiplicativos (ex.: 1.2 = +20%).
		# Registra cada um.
		stats.add(StringName(key), float(data.stat_mult[key]), StatModifiers.Mode.MULT, self)
	for key: Variant in data.stat_add:  # Bônus aditivos (ex.: 0.05 = +5 pontos).
		# Registra cada um.
		stats.add(StringName(key), float(data.stat_add[key]), StatModifiers.Mode.ADD, self)


## Remove e registra de novo os modificadores (usado quando o valor muda durante o efeito).
func _refresh_stats() -> void:
	var stats: StatModifiers = get_stats()  # Gerenciador de bônus.
	if stats == null:  # Sem gerenciador: nada a fazer.
		return
	stats.remove_source(self)  # Remove os bônus antigos.
	_apply_stats()  # Registra os valores novos.
