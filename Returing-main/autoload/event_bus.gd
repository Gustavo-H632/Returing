extends Node
## Autoload EventBus: canal de sinais global.

# Os sinais são emitidos/escutados em outros scripts.
@warning_ignore_start("unused_signal")

# --- Player ---
signal player_registered(player: Node2D)
signal player_hp_changed(hp: int, hp_max: int)
signal player_damaged(amount: int)
signal player_died
## Carga do tiro de 0.0 a 1.0 (0.0 = não está carregando).
signal player_charge_changed(ratio: float)
signal player_dealt_damage(target: Node, amount: int)
## Pedido de cura ao Player (quem emite não conhece o Player).
signal player_heal_requested(amount: int)
## Pedido de dano ao Player (ex.: erro no quiz).
signal player_damage_requested(amount: int)

# --- Inimigos ---
signal enemy_registered(enemy: Node2D, kind: StringName, max_health: int)
signal enemy_damaged(enemy: Node2D, kind: StringName, amount: int, current_health: int, max_health: int)
signal enemy_died(enemy: Node2D, kind: StringName, world_position: Vector2)

# --- Ondas (WaveManager) ---
signal wave_started(wave: int, total_waves: int, enemy_count: int)
signal wave_cleared(wave: int, total_waves: int)
signal all_waves_cleared

# --- Chefões (ex.: Guide) ---
## O chefão ficou invulnerável e pede a wave da transição de fase.
## A wave deve evitar nascer a menos de `clear_radius` de `boss_position` (paredes do chefão).
signal boss_transition_started(kind: StringName, boss_position: Vector2, clear_radius: float)
## A wave da transição foi eliminada: o chefão pode seguir para a fase seguinte.
signal boss_wave_cleared(kind: StringName)
## O chefão entrou em uma nova fase (1 = inicial).
signal boss_phase_changed(kind: StringName, phase: int)
## O chefão morreu.
signal boss_defeated(kind: StringName)

# --- Fase (LevelManager) ---
signal level_started
signal enemies_remaining_changed(remaining: int)
signal enemies_cleared
## Fase concluída.
signal level_completed(next_scene: String)
signal game_over

# --- UI e navegação (tratados pelo autoload Global) ---
## A HUD pede o estado atual do Player ao nascer.
signal hud_refresh_requested
signal level_restart_requested
signal main_menu_requested
signal scene_change_requested(path: String)
signal quit_requested

# --- Cutscenes ---
signal cutscene_content_registered(step_count: int)
signal cutscene_advance_requested
signal cutscene_step_changed(step: int)
signal cutscene_finished

@warning_ignore_restore("unused_signal")
