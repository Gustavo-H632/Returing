class_name TankStateMachine
extends StateWarden
## State do Tank (lógica no StateWarden). Estados: Idle, Chase, Attack, Special_Attack.


## Compatibilidade com o setup(self) antigo.
func setup(_owner_actor: CharacterBody2D = null) -> void:
	start()
