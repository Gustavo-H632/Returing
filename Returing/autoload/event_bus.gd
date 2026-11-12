extends Node
## Autoload EventBus: canal de sinais global.

# Os sinais são emitidos/escutados em outros scripts.
@warning_ignore_start("unused_signal")

# --- Player ---
signal player_registered(player: Node2D)  # O jogador nasceu na cena (HUD e inimigos ligam nele).
signal player_hp_changed(hp: int, hp_max: int)  # A vida do jogador mudou (atual e máxima).
signal player_damaged(amount: int)  # O jogador tomou dano de verdade (quantidade aplicada).
signal player_died  # O jogador morreu.
## Carga do tiro de 0.0 a 1.0 (0.0 = não está carregando).
signal player_charge_changed(ratio: float)
signal player_dealt_damage(target: Node, amount: int)  # O jogador causou dano em um alvo.
## Pedido de cura ao Player (quem emite não conhece o Player).
signal player_heal_requested(amount: int)
## Pedido de dano ao Player (ex.: erro no quiz).
signal player_damage_requested(amount: int)

# --- Inimigos ---
# Um inimigo entrou na fase (tipo e vida máxima).
signal enemy_registered(enemy: Node2D, kind: StringName, max_health: int)
# Um inimigo tomou dano (quanto e quanta vida sobrou).
signal enemy_damaged(enemy: Node2D, kind: StringName, amount: int, current_health: int, max_health: int)
# Um inimigo morreu (tipo e posição).
signal enemy_died(enemy: Node2D, kind: StringName, world_position: Vector2)

# --- Ondas (WaveManager) ---
# Uma onda começou (número, total e quantidade de inimigos).
signal wave_started(wave: int, total_waves: int, enemy_count: int)
signal wave_cleared(wave: int, total_waves: int)  # Uma onda foi eliminada.
signal all_waves_cleared  # Todas as ondas foram eliminadas.

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
signal level_started  # A fase começou.
signal enemies_remaining_changed(remaining: int)  # Mudou a quantidade de inimigos vivos.
signal enemies_cleared  # Não há mais inimigos vivos.
## Fase concluída.
signal level_completed(next_scene: String)
signal game_over  # O jogador morreu e não há mais tentativas: game over.

# --- UI e navegação (tratados pelo autoload Global) ---
## A HUD pede o estado atual do Player ao nascer.
signal hud_refresh_requested
signal level_restart_requested  # Pede para reiniciar a fase atual.
signal main_menu_requested  # Pede para voltar ao menu principal.
signal scene_change_requested(path: String)  # Pede para trocar de cena (caminho do arquivo .tscn).
signal quit_requested  # Pede para fechar o jogo.

# --- Cutscenes ---
signal cutscene_content_registered(step_count: int)  # Uma cutscene registrou quantos passos tem.
signal cutscene_advance_requested  # Pede para avançar o passo da cutscene.
signal cutscene_step_changed(step: int)  # A cutscene mudou de passo.
signal cutscene_finished  # A cutscene terminou.

# Restaura o aviso desligado acima.
@warning_ignore_restore("unused_signal")
