class_name ChaserEnergyWaveState
extends ChaserState
## Solta a Onda de Energia quando o player foge e se recupera.

@export var recovery_time: float = 0.4

var _time_left: float = 0.0


## Solta a onda.
func enter() -> void:
	enemy.velocity = Vector2.ZERO
	enemy.player_ref = null
	enemy.player_fled = false  # uma onda por fuga
	enemy.fire_energy_wave()
	_time_left = recovery_time


## Espera a recuperação e volta ao Idle.
func physics_update(delta: float) -> void:
	enemy.stop_moving()
	_time_left -= delta
	if _time_left <= 0.0:
		request_transition(&"IdleState")
