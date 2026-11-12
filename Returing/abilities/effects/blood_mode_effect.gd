class_name BloodModeEffect
extends StatBuffEffect
## Modo Sanguinário (lendária): cada inimigo morto durante o efeito dá aumento temporário de ataque
## (acumula até o teto) e recupera vida.

@export_group("Sanguinário")
## Bônus de ataque por abate (0.05 = +5%).
@export_range(0.0, 1.0, 0.01) var damage_per_kill: float = 0.05
## Máximo de abates acumulados (teto de bônus = damage_per_kill x max_stacks).
@export_range(1, 50) var max_stacks: int = 10
## Vida recuperada por abate.
@export_range(0, 50) var heal_per_kill: int = 2

var _stacks: int = 0  # Abates acumulados até agora.


## Ao ativar escuta as mortes de inimigos e aplica o buff base de duração.
func _on_activate() -> void:
	# Cada inimigo morto aumenta o ataque e cura.
	CombatUtils.connect_once(EventBus.enemy_died, _on_enemy_died)
	super._on_activate()  # Registra os bônus iniciais e a duração (classe base).


## Registra os bônus base e, se já há abates, soma o bônus de ataque acumulado.
func _apply_stats() -> void:
	super._apply_stats()  # Bônus base da habilidade.
	var stats: StatModifiers = get_stats()  # Gerenciador de bônus.
	if stats != null and _stacks > 0:  # Só soma depois do primeiro abate.
		# Multiplicador de ataque: 1 + bônus por abate vezes os abates acumulados.
		stats.add(StatModifiers.DAMAGE, 1.0 + damage_per_kill * float(_stacks), StatModifiers.Mode.MULT, self)


## Um inimigo morreu: acumula um abate (com teto), atualiza o bônus e cura o jogador.
func _on_enemy_died(_enemy: Node2D, _kind: StringName, _world_position: Vector2) -> void:
	if not is_instance_valid(caster) or caster.esta_morto():  # Jogador removido ou morto: ignora.
		return
	_stacks = mini(_stacks + 1, max_stacks)  # Mais um abate, sem passar do teto.
	_refresh_stats()  # Recalcula os bônus.
	if heal_per_kill > 0:  # Cura por abate.
		caster.curar(heal_per_kill)  # Cura o jogador.


## Ao terminar desliga a escuta de mortes e remove os bônus.
func _on_cleanup() -> void:
	CombatUtils.disconnect_if_connected(EventBus.enemy_died, _on_enemy_died)  # Para de escutar.
	super._on_cleanup()  # Remove os bônus (classe base).
