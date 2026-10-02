extends Node
## Teste de INTEGRAÇÃO ponta a ponta: roda o jogo de verdade (cenas reais,
## física real, autoloads reais) e confere a comunicação entre sistemas.
##
##   Menu --Start--> Cutscene (5 passos) --> Fase 1
##   Player golpeia inimigo --> EventBus.enemy_damaged --> HUD (barra do inimigo)
##   Inimigos atacam Player --> EventBus.player_hp_changed --> HUD (HP)
##   Player morre --> LevelManager --> game_over --> HUD --Tentar de novo--> Global (reload)
##   Fase 1: WaveManager gera 3 ondas (4 / 4 / 7 inimigos), cura o Player a cada onda limpa
##   Última onda limpa --> all_waves_cleared --> enemies_cleared --> level_completed --> HUD --Menu--> Global
##
## COMO RODAR
##   Editor:   abra tests/integration/flow_test.tscn e aperte F6 (resultado no Output).
##   Terminal: godot --headless --fixed-fps 60 --path . res://tests/integration/flow_test.tscn
##             (código de saída 0 = tudo certo)
##
## O script se move para a raiz da árvore (sobrevive às trocas de cena) e
## pede a navegação pelo EventBus, exatamente como os botões do jogo.
## Buscas por nome (find_child) existem SÓ aqui, no teste.

const MENU: String = "res://Scenes/Start/menu_start.tscn"
const CUTSCENE: String = "res://Scenes/Cut1/cutscene1.tscn"
const FASE_1: String = "res://Scenes/Fase1/fase_1.tscn"
const ARENA: String = "res://tests/dummy_arena/teste_dummy.tscn"
const MAX_WAIT_FRAMES: int = 60 * 30

var _checks: int = 0
var _failures: int = 0
var _log: Dictionary = {}          # nome do sinal -> quantidade de emissões
var _last_enemy_damaged: Array = []
var _moved_to_root: bool = false
var _error_logger: ErrorCounter = null


## Conta todo ERROR / SCRIPT ERROR do motor durante o teste (Godot 4.5+).
## Um fluxo que "funciona" mas imprime erro vermelho no Output também reprova.
class ErrorCounter extends Logger:
	var errors: PackedStringArray = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var text := "%s %s (%s:%d %s)" % [code, rationale, file, line, function]
		if text.contains("FAIL:"):
			return  # falhas do próprio teste já são contadas em _check
		_mutex.lock()
		errors.append(text.strip_edges())
		_mutex.unlock()

	func take() -> PackedStringArray:
		_mutex.lock()
		var out := errors.duplicate()
		errors.clear()
		_mutex.unlock()
		return out


func _ready() -> void:
	if _error_logger == null:
		_error_logger = ErrorCounter.new()
		OS.add_logger(_error_logger)
	if not _moved_to_root:
		# Sai da cena atual para não ser liberado por change_scene_to_file.
		_moved_to_root = true
		_move_to_root.call_deferred()


func _move_to_root() -> void:
	var tree := get_tree()
	var old_scene := tree.current_scene
	get_parent().remove_child(self)
	tree.root.add_child(self)
	if old_scene != null and old_scene != self:
		old_scene.queue_free()
	_listen_event_bus()
	_run.call_deferred()


func _listen_event_bus() -> void:
	for sig_name in [
		&"player_registered", &"player_hp_changed", &"player_damaged", &"player_died",
		&"enemy_registered", &"enemy_damaged", &"enemy_died",
		&"level_started", &"enemies_remaining_changed", &"enemies_cleared",
		&"level_completed", &"game_over", &"hud_refresh_requested",
		&"scene_change_requested", &"cutscene_step_changed", &"cutscene_finished",
		&"wave_started", &"wave_cleared", &"all_waves_cleared", &"player_heal_requested",
	]:
		var sig := Signal(EventBus, sig_name)
		var argc := sig_arg_count(sig_name)
		var cb := _count.bind(sig_name)
		sig.connect(cb.unbind(argc) if argc > 0 else cb)
	EventBus.enemy_damaged.connect(
		func(e: Node2D, kind: StringName, amount: int, hp: int, mx: int) -> void:
			_last_enemy_damaged = [e, kind, amount, hp, mx]
	)


func sig_arg_count(sig_name: StringName) -> int:
	for s in EventBus.get_signal_list():
		if s.name == sig_name:
			return (s.args as Array).size()
	return 0


func _count(sig_name: StringName) -> void:
	_log[sig_name] = int(_log.get(sig_name, 0)) + 1


func _n(sig_name: StringName) -> int:
	return int(_log.get(sig_name, 0))


# --------------------------------------------------------------------------
# Roteiro
# --------------------------------------------------------------------------

func _run() -> void:
	await _test_menu_to_cutscene()
	await _test_cutscene_to_level()
	await _test_level_boot()
	await _test_player_hits_enemy()
	await _test_enemies_hit_player()
	await _test_player_projectile()
	await _test_dash_iframes()
	await _test_game_over_and_retry()
	await _test_no_signal_leaks_after_reload()
	await _test_victory_and_back_to_menu()
	await _test_cutscene_replay()
	await _test_soak_random_input()
	await _test_dummy_arena()
	_assert_no_engine_errors()

	Input.action_release(&"attack_sword")
	OS.remove_logger(_error_logger)
	print("\n==== INTEGRAÇÃO: %d checagens, %d falhas ====" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_menu_to_cutscene() -> void:
	_section("Menu -> Cutscene")
	EventBus.scene_change_requested.emit(MENU)
	_check(await _wait_scene(MENU), "menu carregado via EventBus.scene_change_requested")
	var start := _find(&"Start_button") as Button
	_check(start != null, "botão Start existe")
	if start == null:
		return
	start.pressed.emit()
	start.pressed.emit()  # clique duplo não pode trocar a cena duas vezes
	_check(await _wait_scene(CUTSCENE), "Start -> cutscene1")


func _test_cutscene_to_level() -> void:
	_section("Cutscene -> Fase 1")
	await _frames(2)
	var label := _find(&"RichTextLabel") as RichTextLabel
	var image := _find(&"TextureRect") as TextureRect
	var button := _find(&"Button") as Button
	_check(label != null and image != null and button != null, "nós da cutscene existem")
	if button == null:
		return
	_check(label.text.begins_with("1942"), "passo 0 mostra o primeiro texto")
	var first_texture := image.texture
	button.pressed.emit()
	await _frames(1)
	_check(label.text != "" and not label.text.begins_with("1942"), "Avançar muda o texto (passo 1)")
	_check(image.texture != first_texture, "Avançar muda a imagem (passo 1)")
	for i in 4:
		button.pressed.emit()
		await _frames(1)
	_check(_n(&"cutscene_finished") == 1, "cutscene_finished emitido 1x após 5 passos")
	_check(await _wait_scene(FASE_1), "último passo -> fase_1")


## Espera a onda 1 da Fase 1 nascer (first_wave_delay + spawn deferido). true se o LevelManager contou `n` inimigos.
func _wait_wave_enemies(n: int, max_frames: int = 60 * 6) -> bool:
	return await _wait(func() -> bool:
		var lm := _find(&"LevelManager") as LevelManager
		return lm != null and lm.get_remaining() == n, max_frames)


func _test_level_boot() -> void:
	_section("Fase 1: inicialização (sem inimigos fixos; onda 1 nasce pelo WaveManager)")
	await _frames(3)
	var lm := _find(&"LevelManager") as LevelManager
	_check(lm != null and lm.get_remaining() == 0, "ao abrir a fase ainda não há inimigos (a onda 1 espera o first_wave_delay)")
	_check(_find(&"WaveManager") is WaveManager, "Fase 1 contém o WaveManager")
	_check(await _wait_wave_enemies(4), "onda 1: LevelManager conta 4 inimigos (2 Chasers + 2 Shooters)")
	_check(_label_text(&"EnemiesLabel") == "Inimigos: 4", "HUD mostra 'Inimigos: 4'")
	_check(_visible(&"WaveLabel") and _label_text(&"WaveLabel") == "Onda 1 / 3", "HUD mostra 'Onda 1 / 3'")
	_check(_label_text(&"PlayerHpLabel") == "HP 100 / 100", "HUD mostra o HP inicial do Player")
	_check(not _visible(&"GameOverPanel") and not _visible(&"LevelCompletePanel"), "painéis de fim ocultos")
	_check(get_tree().get_nodes_in_group(CombatUtils.GROUP_PLAYER).size() == 1, "exatamente 1 nó no grupo 'player'")


func _test_player_hits_enemy() -> void:
	_section("Player -> Inimigo -> HUD")
	var player := _player()
	var chaser := _find(&"ChaserEnemy") as ChaserEnemy
	if player == null or chaser == null:
		_check(false, "Player e ChaserEnemy existem")
		return
	var hp_before := chaser.current_health
	# Encosta o Player à esquerda do Chaser, virado para a direita, e golpeia.
	player.global_position = chaser.global_position + Vector2(-24, 0)
	player.facing_direction = Vector2.RIGHT
	player._sincronizar_facing()
	var damaged_before := _n(&"enemy_damaged")
	await _frames(2)
	await _tap(&"attack_sword")
	var ok := await _wait(func() -> bool: return _n(&"enemy_damaged") > damaged_before, 30)
	_check(ok, "golpe melee do Player gera EventBus.enemy_damaged")
	_check(chaser.current_health < hp_before or not is_instance_valid(chaser), "vida do Chaser diminuiu")
	_check(_last_enemy_damaged.size() == 5 and _last_enemy_damaged[1] == &"chaser", "enemy_damaged informa kind 'chaser'")
	_check(_visible(&"EnemyPanel"), "HUD mostra a barra do inimigo atingido")
	_check(_label_text(&"EnemyNameLabel") == "Perseguidor", "HUD mostra o nome do inimigo")


func _test_enemies_hit_player() -> void:
	_section("Inimigo -> Player -> HUD")
	var player := _player()
	if player == null:
		return
	var hp_before := player.hp
	var damaged_before := _n(&"player_damaged")
	# Fica parado ao lado do Chaser (e dentro da visão dele).
	var ok := await _wait(func() -> bool: return _n(&"player_damaged") > damaged_before, 60 * 8)
	_check(ok, "inimigo acerta o Player (Hitbox -> PlayerHurtbox -> Player)")
	_check(player.hp < hp_before, "HP do Player diminuiu")
	_check(_label_text(&"PlayerHpLabel") == "HP %d / 100" % player.hp, "HUD acompanha o HP do Player")


func _test_player_projectile() -> void:
	_section("Tiro carregado do Player -> Shooter -> HUD")
	var player := _player()
	var shooter := _find(&"RangedEnemy") as RangedEnemy
	if player == null or shooter == null:
		_check(false, "Player e RangedEnemy existem")
		return
	player.curar(999)
	player.global_position = shooter.global_position + Vector2(-110, 0)
	player.facing_direction = Vector2.RIGHT
	player._sincronizar_facing()
	var hp_before := shooter.health.current_health
	var charge_events: Array[float] = []
	var on_charge := func(r: float) -> void: charge_events.append(r)
	EventBus.player_charge_changed.connect(on_charge)
	Input.action_press(&"charge_shoot")
	await _frames(40)
	_check(_visible(&"ChargeBar"), "HUD mostra a barra de carga enquanto segura o tiro")
	Input.action_release(&"charge_shoot")
	var ok := await _wait(func() -> bool: return shooter.health.current_health < hp_before, 60)
	EventBus.player_charge_changed.disconnect(on_charge)
	_check(ok, "projétil do Player causa dano no Shooter (PlayerProjectile -> ShooterHurtbox)")
	_check(charge_events.size() > 2 and charge_events.max() > 0.5, "EventBus.player_charge_changed acompanha a carga")
	await _frames(2)
	_check(not _visible(&"ChargeBar"), "barra de carga some depois do disparo")


func _test_dash_iframes() -> void:
	_section("Dash -> invulnerabilidade")
	var player := _player()
	if player == null:
		return
	player.curar(999)
	await _tap(&"dash")
	_check(player.state == Player.State.DASH, "Player entrou em DASH")
	var hp_before := player.hp
	CombatUtils.apply_damage(player.hurtbox, 10, self)
	_check(player.hp == hp_before, "dano ignorado durante os i-frames")
	await _frames(40)
	var hp_mid := player.hp  # inimigos próximos podem ter acertado nesse meio-tempo
	CombatUtils.apply_damage(player.hurtbox, 10, self)
	_check(not player.esta_invulneravel() and player.hp == hp_mid - 10, "dano volta a valer depois dos i-frames")


## Joga "sozinho" por ~40 s com entradas aleatórias: qualquer erro no Output reprova.
func _test_soak_random_input() -> void:
	_section("Soak: 40 s de jogo com entradas aleatórias")
	var rng := RandomNumberGenerator.new()
	rng.seed = 45
	var actions: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down",
		&"dash", &"attack_sword", &"charge_shoot"]
	for i in 60 * 40:
		if i % 12 == 0:
			for a in actions:
				Input.action_release(a)
			Input.action_press(actions[rng.randi_range(0, 3)])
			var extra := actions[rng.randi_range(0, actions.size() - 1)]
			Input.action_press(extra)
		await get_tree().physics_frame
		if get_tree().current_scene == null or get_tree().current_scene.scene_file_path != FASE_1:
			break
	for a in actions:
		Input.action_release(a)
	_check(get_tree().current_scene != null, "cena continua válida depois do soak")
	print("      eventos no soak: ", _log)


func _test_dummy_arena() -> void:
	_section("Arena do Dummy: painel -> Dummy -> Player -> HUD")
	EventBus.scene_change_requested.emit(ARENA)
	_check(await _wait_scene(ARENA), "arena carregada")
	var player := _player()
	var painel := _find(&"PainelDummy") as PainelDummy
	if player == null or painel == null:
		_check(false, "Player e PainelDummy existem")
		return
	_check(painel.dummy != null and painel.dummy == _find(&"DummyEnemy"), "PainelDummy.dummy atribuído por @export (sem busca por grupo)")
	var hp0 := player.hp
	painel.btn_projetil.button_pressed = true   # toggled -> iniciar_ataque_projetil
	painel.btn_onda.button_pressed = true       # toggled -> iniciar_ataque_onda
	var hit := await _wait(func() -> bool: return player.hp < hp0, 60 * 5)
	painel.btn_projetil.button_pressed = false
	painel.btn_onda.button_pressed = false
	_check(hit, "ataques do Dummy atingem o Player")
	_check(_label_text(&"PlayerHpLabel") == "HP %d / 100" % player.hp, "HUD da arena acompanha o HP")
	await _frames(60)


func _test_game_over_and_retry() -> void:
	_section("Derrota -> Game Over -> Tentar de novo")
	var player := _player()
	if player == null:
		return
	# Tiro de misericórdia pela Hurtbox (mesmo caminho dos inimigos).
	# B49: posiciona o Player dentro da visão de um Chaser antes de morrer.
	var chaser := _find(&"ChaserEnemy") as ChaserEnemy
	if chaser != null:
		player.global_position = chaser.global_position + Vector2(-60, 0)
		await _wait(func() -> bool: return chaser.player_in_detection, 30)
	var waves_after_death: Array[int] = [0]
	var on_added := func(n: Node) -> void:
		if n is EnergyWave:
			waves_after_death[0] += 1
	get_tree().node_added.connect(on_added)
	player._iframes_left = 0.0
	CombatUtils.apply_damage(player.hurtbox, 9999, self)
	_check(player.esta_morto(), "Player morreu")
	_check(_n(&"player_died") == 1, "EventBus.player_died emitido 1x")
	_check(await _wait(func() -> bool: return _n(&"game_over") == 1, 60 * 3), "LevelManager emite game_over após o atraso")
	await _frames(1)
	_check(_visible(&"GameOverPanel"), "HUD mostra o painel Game Over")
	# Inimigos esquecem o alvo morto.
	var tank := _find(&"TankEnemy") as TankEnemy
	_check(tank == null or not tank.has_target(), "Tank esquece o Player morto")
	get_tree().node_added.disconnect(on_added)
	_check(waves_after_death[0] == 0, "B49: nenhum Chaser dispara Onda de Energia no Player morto")
	var retry := _find(&"RetryButton") as Button
	var old_id := get_tree().current_scene.get_instance_id()
	retry.pressed.emit()
	var reloaded := await _wait(func() -> bool:
		var cs := get_tree().current_scene
		return cs != null and cs.get_instance_id() != old_id and cs.scene_file_path == FASE_1, 120)
	_check(reloaded, "Tentar de novo recarrega a fase")
	await _frames(3)
	_check(await _wait_wave_enemies(4), "após recarregar: a onda 1 recomeça com 4 inimigos")
	_check(_label_text(&"PlayerHpLabel") == "HP 100 / 100", "após recarregar: HP cheio na HUD")
	_check(not _visible(&"GameOverPanel"), "após recarregar: painel Game Over oculto")


## Conexões no EventBus não podem acumular a cada recarga (vazamento = HUD
## atualizando 2x, LevelManager contando mortes em dobro etc.).
func _test_no_signal_leaks_after_reload() -> void:
	_section("Sem vazamento de conexões no EventBus")
	var before := _snapshot_connections()
	var old_id := get_tree().current_scene.get_instance_id()
	EventBus.level_restart_requested.emit()
	await _wait(func() -> bool:
		var cs := get_tree().current_scene
		return cs != null and cs.get_instance_id() != old_id and cs.is_node_ready(), 120)
	# A fase recarregada começa SEM inimigos (onda 1 nasce após first_wave_delay). Sem esperar a
	# onda, as 4 conexões de player_died dos inimigos ainda não existem e a comparação acusava
	# um "vazamento" ao contrário (7 -> 3), que não é vazamento.
	_check(await _wait_wave_enemies(4), "após recarregar: onda 1 presente antes de contar as conexões")
	await _frames(3)
	var after := _snapshot_connections()
	var leaks: PackedStringArray = []
	for k: StringName in after:
		if int(after[k]) != int(before.get(k, 0)):
			leaks.append("%s: %d -> %d" % [k, before.get(k, 0), after[k]])
	_check(leaks.is_empty(), "número de conexões igual antes/depois do reload %s" % ("" if leaks.is_empty() else str(leaks)))


func _test_victory_and_back_to_menu() -> void:
	_section("Vitória: 3 ondas -> Fase concluída -> Menu")
	var lm := _find(&"LevelManager") as LevelManager
	_check(await _wait_wave_enemies(4), "onda 1 presente (4 inimigos) antes de começar")
	var expected: Array[int] = [4, 4, 7]
	var started_base := _n(&"wave_started")  # já conta a onda 1 desta cena
	var cleared_base := _n(&"wave_cleared")
	var heal_base := _n(&"player_heal_requested")
	var all_base := _n(&"all_waves_cleared")
	var player := _player()

	for wave in expected.size():
		var want: int = expected[wave]
		if wave > 0:
			var spawned := await _wait(func() -> bool:
				return _n(&"wave_started") == started_base + wave and lm.get_remaining() == want, 60 * 8)
			_check(spawned, "onda %d nasceu com %d inimigos (wave_started)" % [wave + 1, want])
			_check(_label_text(&"WaveLabel") == "Onda %d / 3" % (wave + 1), "HUD mostra 'Onda %d / 3'" % (wave + 1))
		var died_before := _n(&"enemy_died")
		for e in get_tree().get_nodes_in_group(CombatUtils.GROUP_ENEMY):
			if CombatUtils.is_dead_actor(e):
				continue  # sobra da onda anterior ainda sumindo (fade do Tank)
			CombatUtils.apply_damage(e.get(&"hurtbox"), 9999, player)
		var killed := await _wait(func() -> bool: return _n(&"enemy_died") - died_before == want, 60)
		_check(killed, "onda %d: %dx EventBus.enemy_died" % [wave + 1, want])
		_check(_n(&"wave_cleared") == cleared_base + wave + 1, "onda %d limpa: wave_cleared emitido" % (wave + 1))
		_check(_n(&"player_heal_requested") == heal_base + wave + 1, "onda %d limpa: cura pedida ao Player" % (wave + 1))
		if wave < expected.size() - 1:
			_check(_n(&"level_completed") == 0, "onda %d limpa: a fase NÃO termina (ainda há ondas)" % (wave + 1))

	_check(_n(&"all_waves_cleared") == all_base + 1, "última onda limpa: all_waves_cleared emitido uma vez")
	_check(await _wait(func() -> bool: return _n(&"level_completed") >= 1, 60 * 3), "level_completed emitido")
	await _frames(1)
	_check(_visible(&"LevelCompletePanel"), "HUD mostra 'Fase concluída'")
	var cont := _find(&"ContinueButton") as Button
	_check(cont != null and not cont.visible, "sem next_scene: botão Continuar oculto")
	# Com os Shooters mortos, a armadilha elétrica deve ter nascido na cena.
	_check(_find_by_script(ElectricTrap) != null, "Shooter deixou a armadilha elétrica")
	(_find(&"CompleteMenuButton") as Button).pressed.emit()
	_check(await _wait_scene(MENU), "Menu (fim de fase) -> menu_start")


func _test_cutscene_replay() -> void:
	_section("Reabrir a cutscene (regressão B06)")
	var finished_before := _n(&"cutscene_finished")
	(_find(&"Start_button") as Button).pressed.emit()
	_check(await _wait_scene(CUTSCENE), "menu -> cutscene de novo")
	await _frames(2)
	var label := _find(&"RichTextLabel") as RichTextLabel
	_check(label != null and label.text.begins_with("1942"), "cutscene reinicia no passo 0")
	var button := _find(&"Button") as Button
	for i in 5:
		button.pressed.emit()
		await _frames(1)
	_check(_n(&"cutscene_finished") == finished_before + 1, "cutscene termina de novo sem erro de índice")
	_check(await _wait_scene(FASE_1), "cutscene -> fase_1 (2ª vez)")


# --------------------------------------------------------------------------
# Utilitários
# --------------------------------------------------------------------------

func _snapshot_connections() -> Dictionary:
	var snap: Dictionary = {}
	for s in EventBus.get_signal_list():
		snap[StringName(s.name)] = EventBus.get_signal_connection_list(s.name).size()
	return snap


func _section(title: String) -> void:
	_assert_no_engine_errors()
	print("\n-- %s --" % title)


## Reprova se o motor registrou algum erro desde a última seção.
func _assert_no_engine_errors() -> void:
	if _error_logger == null:
		return
	var errs := _error_logger.take()
	_check(errs.is_empty(), "nenhum ERROR/SCRIPT ERROR no Output%s" % ("" if errs.is_empty() else ": " + " | ".join(errs)))


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("ok:   ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
		push_error("FAIL: " + label)


## Aperta e solta uma ação. Uma entrada feita no meio do frame de física só é
## vista no frame seguinte, então a tecla fica apertada por 2 frames.
func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait(cond: Callable, max_frames: int = MAX_WAIT_FRAMES) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().physics_frame
	return bool(cond.call())


func _wait_scene(path: String) -> bool:
	var ok: bool = await _wait(func() -> bool:
		var cs := get_tree().current_scene
		return cs != null and cs.scene_file_path == path and cs.is_node_ready(), 180)
	# O Global trava novos pedidos por 2 frames após cada troca (anti clique duplo).
	await _frames(4)
	return ok


func _find(node_name: StringName) -> Node:
	var cs := get_tree().current_scene
	return cs.find_child(node_name, true, false) if cs != null else null


func _find_by_script(type: Variant) -> Node:
	var cs := get_tree().current_scene
	if cs == null:
		return null
	for n in cs.get_children():
		if is_instance_of(n, type):
			return n
	return null


func _player() -> Player:
	return get_tree().get_first_node_in_group(CombatUtils.GROUP_PLAYER) as Player


func _label_text(node_name: StringName) -> String:
	var l := _find(node_name) as Label
	return l.text if l != null else "<sem nó %s>" % node_name


func _visible(node_name: StringName) -> bool:
	var c := _find(node_name) as CanvasItem
	return c != null and c.is_visible_in_tree()
