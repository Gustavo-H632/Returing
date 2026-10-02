class_name ShooterHitbox
extends Hitbox
## Hitbox do projétil, do telegraph e da armadilha (lógica em Hitbox).


## Aplica dano imediatamente a tudo que está sobreposto.
func apply_burst_damage() -> void:
	pulse()


## one_shot true = um acerto por alvo; false = dano a cada tick.
func configure(new_damage: int, new_one_shot: bool, new_tick_interval: float = 0.5) -> void:
	damage = new_damage
	one_hit_per_target = new_one_shot
	tick_interval = 0.0 if new_one_shot else maxf(new_tick_interval, 0.05)
	if is_node_ready():
		set_physics_process(is_active() and tick_interval > 0.0)
