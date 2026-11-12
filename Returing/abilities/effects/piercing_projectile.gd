class_name PiercingProjectile
extends PlayerProjectile
## Tiro Perfurante: igual ao tiro do Player, mas atravessa inimigos (cada um é atingido uma vez).
## Continua parando nas paredes. Não altera `PlayerProjectile`: só sobrescreve o acerto em hurtbox.

var _already_hit: Dictionary = {}  # Alvos já atingidos (um acerto por alvo).


## Ao voltar a ser usado limpa a lista de alvos atingidos.
func _on_pool_activate() -> void:
	_already_hit.clear()  # Limpa a lista.


## Bateu em uma hurtbox: causa dano e segue em frente.
## Bateu numa hurtbox: causa dano, guarda o alvo e segue em frente (não some, ao contrário do tiro normal).
func _on_area_entered(area: Area2D) -> void:
	# Só hurtboxes e só se o tiro ainda vale.
	if _consumido or not area.is_in_group(CombatUtils.GROUP_HURTBOX):
		return
	var alvo: Node = CombatUtils.get_actor(area)  # Dono da hurtbox.
	if alvo == shooter or alvo == null:  # Ignora o próprio jogador.
		return
	var id: int = alvo.get_instance_id()  # Identificador do alvo.
	if _already_hit.has(id):  # Já foi atingido: ignora.
		return
	_already_hit[id] = true  # Marca como atingido.
	_aplicar_dano(area, alvo)  # Aplica o dano (sem consumir o tiro).
