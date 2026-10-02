class_name PlayerHurtbox
extends Hurtbox
## Hurtbox do player: repassa o dano ao Player (i-frames e HP ficam lá).


## Entrega o dano ao Player. true se aceitou.
func _deliver_damage(amount: int, source: Variant) -> bool:
	var player := get_actor()
	if not CombatUtils.is_alive(player) or player == self:
		return false
	# false em i-frames: o ataque não conta acerto
	return CombatUtils.apply_damage(player, amount, source)
