class_name HealthComponent
extends Node
## Vida reutilizável.

signal health_changed(current_health: int, max_health: int)  # Vida mudou (atual e máxima).
signal damaged(amount: int)  # Levou dano (quantidade realmente tirada).
signal healed(amount: int)  # Foi curado (quantidade realmente curada).
signal died  # Vida chegou a zero.

@export var max_health: int = 100  # Vida máxima (editável no Inspector).

var current_health: int = 0  # Vida atual.
var _initialized: bool = false  # True depois que setup() rodou.


## Ao entrar na cena, se ninguém configurou a vida ainda, usa a vida máxima do Inspector.
func _ready() -> void:
	if not _initialized:  # Só configura uma vez.
		setup(max_health)


## Define a vida máxima (refill = enche a vida).
## Define a vida máxima (mínimo 1) e, se `refill`, enche a vida. Avisa quem escuta.
func setup(new_max_health: int, refill: bool = true) -> void:
	max_health = maxi(new_max_health, 1)  # Vida máxima nunca menor que 1.
	# Enche ou apenas limita à nova vida máxima.
	current_health = max_health if refill else clampi(current_health, 0, max_health)
	_initialized = true  # Marca como inicializada.
	health_changed.emit(current_health, max_health)  # Avisa a barra de vida e outros.


## Retorna o dano efetivamente aplicado (0 = recusado).
## Tira vida, nunca mais do que existe. Emite damaged, health_changed e, se zerou, died. Devolve o dano aplicado.
func take_damage(amount: int, _source: Variant = null) -> int:
	if not _initialized:  # Garante que a vida esteja inicializada.
		setup(max_health)
	if is_dead() or amount <= 0:  # Morto ou dano inválido: recusa.
		return 0
	var applied: int = mini(amount, current_health)  # Não tira mais do que a vida atual.
	current_health -= applied  # Desconta.
	damaged.emit(applied)  # Avisa o dano.
	health_changed.emit(current_health, max_health)  # Avisa a nova vida.
	if current_health == 0:  # Zerou: o inimigo morre.
		died.emit()
	return applied


## Retorna o quanto foi curado.
## Recupera vida até o máximo. Devolve quanto foi curado de fato (0 se estava cheio ou morto).
func heal(amount: int) -> int:
	# Morto, valor inválido ou cheia: nada a curar.
	if is_dead() or amount <= 0 or current_health >= max_health:
		return 0
	var before: int = current_health  # Vida antes da cura.
	current_health = mini(current_health + amount, max_health)  # Não passa do máximo.
	var applied: int = current_health - before  # Quanto realmente foi curado.
	healed.emit(applied)  # Avisa a cura.
	health_changed.emit(current_health, max_health)  # Avisa a nova vida.
	return applied


## Diz se a vida acabou. Antes do setup() não conta como morto.
func is_dead() -> bool:
	return _initialized and current_health <= 0


## Vida de 0 a 1.
## Vida atual dividida pela máxima (0.0 a 1.0), usada pelas barras.
func get_ratio() -> float:
	return float(current_health) / float(maxi(max_health, 1))  # Evita divisão por zero.
