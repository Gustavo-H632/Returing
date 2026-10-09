class_name Weapon
extends Node2D
## Base de armas empunhadas por personagens.
## Contrato com o portador (wielder):
##   1. equip(portador)          -> a arma passa a ignorar a Hurtbox do portador
##   2. attack(direção) -> bool  -> inicia um ataque (false = ocupado / em recarga)
##   3. attack_finished(ok)      -> SEMPRE emitido uma vez por ataque iniciado,
##                                  inclusive quando cancel() interrompe o golpe
##   4. hit_landed(alvo, dano)   -> cada acerto confirmado

signal attack_started
signal attack_finished(completed: bool)
signal hit_landed(target: Node, damage_dealt: int)

@export var damage: int = 10
## Espera mínima entre o fim de um ataque e o próximo.
@export_range(0.0, 5.0, 0.01, "or_greater") var cooldown: float = 0.0

var wielder: Node = null

var _attacking: bool = false
var _cooldown_until_msec: int = 0


## Associa a arma ao portador.
func equip(new_wielder: Node) -> void:
	wielder = new_wielder
	_on_equipped()


func is_attacking() -> bool:
	return _attacking


func can_attack() -> bool:
	return not _attacking and Time.get_ticks_msec() >= _cooldown_until_msec


## Inicia um ataque na direção dada. Subclasses implementam _start_attack().
func attack(direction: Vector2) -> bool:
	if not can_attack():
		return false
	_attacking = true
	attack_started.emit()
	_start_attack(direction if direction != Vector2.ZERO else Vector2.RIGHT)
	return true


## Interrompe o ataque atual (morte, stun, dash...). Seguro chamar a qualquer momento.
func cancel() -> void:
	if not _attacking:
		return
	_stop_attack()
	_finish(false)


## Duração total de um ataque (usada para sincronizar a animação do portador).
func get_attack_duration() -> float:
	return 0.0


## Chamado pelas subclasses ao concluir (ou abortar) o golpe.
func _finish(completed: bool) -> void:
	if not _attacking:
		return
	_attacking = false
	_cooldown_until_msec = Time.get_ticks_msec() + roundi(cooldown * 1000.0)
	attack_finished.emit(completed)


func _on_equipped() -> void:
	pass


func _start_attack(_direction: Vector2) -> void:
	_finish(true)


func _stop_attack() -> void:
	pass
