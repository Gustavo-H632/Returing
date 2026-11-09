class_name Weapon
extends Node2D
## Base de armas empunhadas por personagens.

signal attack_started  # Avisa que um ataque começou.
# Avisa que o ataque terminou (true = completo, false = interrompido).
signal attack_finished(completed: bool)
## Emitido pelas subclasses (ex.: Sword) quando o golpe acerta.
@warning_ignore("unused_signal")
signal hit_landed(target: Node, damage_dealt: int)  # Avisa que o golpe acertou (alvo e dano).

@export var damage: int = 10  # Dano de cada ataque.
## Espera mínima entre o fim de um ataque e o próximo.
@export_range(0.0, 5.0, 0.01, "or_greater") var cooldown: float = 0.0

var wielder: Node = null  # Quem empunha a arma.

var _attacking: bool = false  # True durante um ataque.
## Recarga restante em segundos de jogo.
var _cooldown_left: float = 0.0


## Desliga a física: ela só liga enquanto houver recarga para contar.
func _ready() -> void:
	set_physics_process(false)  # só conta enquanto houver recarga pendente


## Desconta a recarga; desliga o processamento assim que ela termina.
## Desconta a recarga e desliga a física quando ela termina.
func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)  # Desconta sem passar de zero.
	if _cooldown_left <= 0.0:  # Acabou a recarga.
		set_physics_process(false)  # Para de processar.


## Associa a arma ao portador.
## Entrega a arma a um portador e roda o gancho das subclasses.
func equip(new_wielder: Node) -> void:
	wielder = new_wielder  # Guarda o portador.
	_on_equipped()  # Gancho.


## Diz se há um ataque em andamento.
func is_attacking() -> bool:
	return _attacking


## Diz se a arma pode atacar agora: não pode estar atacando nem em recarga.
func can_attack() -> bool:
	return not _attacking and _cooldown_left <= 0.0  # Livre e sem recarga.


## Inicia um ataque na direção dada.
## Inicia um ataque na direção dada. Devolve false se a arma não pode atacar agora.
func attack(direction: Vector2) -> bool:
	if not can_attack():  # Atacando ou em recarga: recusa.
		return false
	_attacking = true  # Marca como atacando.
	attack_started.emit()  # Avisa o começo.
	_start_attack(direction if direction != Vector2.ZERO else Vector2.RIGHT)  # Direção zero vira direita.
	return true  # Aceitou.


## Reorienta a arma durante o ataque (ex.: acompanhar o cursor do mouse).
## Gancho vazio: as subclasses giram a arma durante o ataque (ex.: seguir o cursor).
func aim_at(_direction: Vector2) -> void:
	pass


## Interrompe o ataque atual (morte, stun, dash...).
## Interrompe o ataque atual (morte, atordoamento, dash...).
func cancel() -> void:
	if not _attacking:  # Sem ataque: nada a fazer.
		return
	_stop_attack()  # Desfaz o que a subclasse criou.
	_finish(false)  # Termina como interrompido.


## Duração total de um ataque (usada para sincronizar a animação do portador).
## Duração total de um ataque (as subclasses informam, para sincronizar a animação).
func get_attack_duration() -> float:
	return 0.0


## Chamado pelas subclasses ao concluir (ou abortar) o golpe.
## Termina o ataque: começa a recarga e avisa quem escuta.
func _finish(completed: bool) -> void:
	if not _attacking:  # Já terminou: ignora.
		return
	_attacking = false  # Livre de novo.
	_cooldown_left = maxf(cooldown, 0.0)  # Começa a recarga.
	set_physics_process(_cooldown_left > 0.0)  # Liga a física só se há recarga.
	attack_finished.emit(completed)  # Avisa o fim.


## Gancho vazio: as subclasses preparam a arma ao serem equipadas.
func _on_equipped() -> void:
	pass


## Gancho padrão: a arma base termina o ataque na hora (as subclasses fazem o golpe de verdade).
func _start_attack(_direction: Vector2) -> void:
	_finish(true)  # Termina como completo.


## Gancho vazio: as subclasses desfazem o que o ataque criou.
func _stop_attack() -> void:
	pass
