extends Node
#Sinais autoloade

# Sinais emitidos pelo Player
@warning_ignore("unused_signal")
signal player_registered(player: Node2D)
@warning_ignore("unused_signal")
signal player_hp_changed(hp: int, hp_max: int)
@warning_ignore("unused_signal")
signal player_damaged(amount: int)
@warning_ignore("unused_signal")
signal player_died
@warning_ignore("unused_signal")
signal player_charge_changed(ratio: float)
@warning_ignore("unused_signal")
signal player_dealt_damage(target: Node, amount: int)

# Sinais emitidos pelos inimigos
@warning_ignore("unused_signal")
signal enemy_registered(enemy: Node2D, kind: StringName, max_health: int)
@warning_ignore("unused_signal")
signal enemy_damaged(enemy: Node2D, kind: StringName, amount: int, current_health: int, max_health: int)
@warning_ignore("unused_signal")
signal enemy_died(enemy: Node2D, kind: StringName, world_position: Vector2)

# Pedidos ao Player (quem emite não conhece o Player)
## Cura  HP 
@warning_ignore("unused_signal")
signal player_heal_requested(amount: int)

# Sinais de ondas (WaveManager)
## Ui que mostra o número de inimigos na tela
@warning_ignore("unused_signal")
signal wave_started(wave: int, total_waves: int, enemy_count: int)
@warning_ignore("unused_signal")
signal wave_cleared(wave: int, total_waves: int)
@warning_ignore("unused_signal")
signal all_waves_cleared

#Sinais de Fase
@warning_ignore("unused_signal")
signal level_started
@warning_ignore("unused_signal")
signal enemies_remaining_changed(remaining: int)
@warning_ignore("unused_signal")
signal enemies_cleared
@warning_ignore("unused_signal")
signal level_completed(next_scene: String)
@warning_ignore("unused_signal")
signal game_over

#Sinais Ui
## requisição do estado atual do Player
@warning_ignore("unused_signal")
signal hud_refresh_requested
@warning_ignore("unused_signal")
signal level_restart_requested
@warning_ignore("unused_signal")
signal main_menu_requested
@warning_ignore("unused_signal")
signal scene_change_requested(path: String)
@warning_ignore("unused_signal")
signal quit_requested

#Sinais cutscenes
@warning_ignore("unused_signal")
signal cutscene_content_registered(step_count: int)
@warning_ignore("unused_signal")
signal cutscene_advance_requested
@warning_ignore("unused_signal")
signal cutscene_step_changed(step: int)
@warning_ignore("unused_signal")
signal cutscene_finished
