class_name EnemyEvents
extends RefCounted
## Liga um inimigo ao EventBus e ao grupo `enemy`.

## Entra no grupo `enemy` e repassa dano/morte ao EventBus.
## Registra o inimigo no grupo "enemy" e liga os sinais de dano e morte dele ao EventBus.
static func bind(enemy: Node2D, kind: StringName, health: HealthComponent) -> void:
	if not CombatUtils.is_valid(enemy):  # Inimigo já liberado: nada a fazer.
		return
	# O grupo permite achar todos os inimigos (mira automática, ondas).
	enemy.add_to_group(CombatUtils.GROUP_ENEMY)
	if not CombatUtils.is_valid(health):  # Sem componente de vida os eventos não existem.
		# Avisa o desenvolvedor que algo não foi ligado na cena.
		push_warning("EnemyEvents.bind: '%s' sem HealthComponent; eventos de dano/morte desativados." % enemy.name)
		return

	# Quando a vida tomar dano, repassa ao EventBus (função anônima).
	health.damaged.connect(
		func(amount: int) -> void:
			if CombatUtils.is_valid(enemy):  # Só repassa se o inimigo ainda existe.
				# Avisa tipo, dano, vida atual e vida máxima.
				EventBus.enemy_damaged.emit(enemy, kind, amount, health.current_health, health.max_health)
	)
	# Quando a vida zerar, avisa o EventBus (pontuação, XP e ondas escutam).
	health.died.connect(
		func() -> void:
			if CombatUtils.is_valid(enemy):
				# Avisa a posição onde o inimigo morreu.
				EventBus.enemy_died.emit(enemy, kind, enemy.global_position)
	)
	# Avisa que o inimigo nasceu (barras e contadores).
	EventBus.enemy_registered.emit(enemy, kind, health.max_health)
