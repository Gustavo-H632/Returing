class_name EnemyEvents
extends RefCounted
## Liga um inimigo ao EventBus e ao grupo enemy

## Grupo enemy + sinais de dano/morte no EventBus.
static func bind(enemy: Node2D, kind: StringName, health: HealthComponent) -> void:
	if not CombatUtils.is_valid(enemy):
		return
	enemy.add_to_group(CombatUtils.GROUP_ENEMY)
	if not CombatUtils.is_valid(health):
		push_warning("EnemyEvents.bind: '%s' sem HealthComponent; eventos de dano/morte desativados." % enemy.name)
		return

	health.damaged.connect(
		func(amount: int) -> void:
			if CombatUtils.is_valid(enemy):
				EventBus.enemy_damaged.emit(enemy, kind, amount, health.current_health, health.max_health)
	)
	health.died.connect(
		func() -> void:
			if CombatUtils.is_valid(enemy):
				EventBus.enemy_died.emit(enemy, kind, enemy.global_position)
	)
	EventBus.enemy_registered.emit(enemy, kind, health.max_health)
