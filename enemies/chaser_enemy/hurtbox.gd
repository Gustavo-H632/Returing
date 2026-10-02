class_name ChaserHurtbox
extends Hurtbox
## Hurtbox do Chaser: repassa o dano ao ChaserEnemy.

## Dano aceito (para efeitos)
signal damaged(amount: int)


## Entrega o dano ao Chaser. true se aceitou.
func _deliver_damage(amount: int, source: Variant) -> bool:
	var owner_actor := get_actor()
	if owner_actor == null or owner_actor == self:
		return false
	if not CombatUtils.apply_damage(owner_actor, amount, source):
		return false
	damaged.emit(amount)  # só dano aceito
	return true
