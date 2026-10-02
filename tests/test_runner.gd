extends Node
## Testes de integração das transições de estado e de fase dos inimigos.
##
## COMO RODAR
##   Editor:   abra tests/test_runner.tscn e aperte F6 (resultado no painel Output).
##   Terminal: godot --headless --path . res://tests/test_runner.tscn
##             (código de saída 0 = tudo certo, 1 = há falhas)
##
## Quase todos os testes são síncronos: chamam physics_update() dos estados à mão, então não
## dependem de tempo real nem de frames de física. Os dois últimos (v2.7.0) aguardam alguns
## frames porque testam call_deferred e timers. Nada aqui altera o jogo.

const TANK_SCENE: String = "res://enemies/tank_enemy/scenes/TankEnemy.tscn"
const CHASER_SCENE: String = "res://enemies/chaser_enemy/ChaserEnemy.tscn"
const SHOOTER_SCENE: String = "res://enemies/ranged_shooter/enemy/RangedEnemy.tscn"
const DUMMY_SCENE: String = "res://enemies/dummy_enemy/dummy_enemy.tscn"
const FASE_1_SCENE: String = "res://Scenes/Fase1/fase_1.tscn"
const PLAYER_SCENE: String = "res://player/Player.tscn"
const ENEMY_PROJECTILE_SCENE: String = "res://enemies/ranged_shooter/projectile/EnemyProjectile.tscn"
const DAMAGE_TEXT_SCENE: String = "res://ui/damage_text/DamageText.tscn"
const DT: float = 1.0 / 60.0

var _checks: int = 0
var _failures: int = 0
var _died_kinds: Array = []
var _cleared_count: int = 0
var _health_died_count: int = 0


## Estado de teste: registra enter/exit e pode pedir uma transição dentro do enter().
class ProbeState extends BaseState:
	var events: Array = []
	var chain_to: StringName = &""

	func enter() -> void:
		events.append("enter")
		if chain_to != &"":
			var target := chain_to
			chain_to = &""
			request_transition(target)

	func exit() -> void:
		events.append("exit")


## Estado que chama die() da máquina DENTRO do próprio enter() (transição enfileirada).
class DieOnEnterState extends BaseState:
	func enter() -> void:
		(state_machine as StateWarden).die()


## Alvo falso: aceita dano pela API única e soma o total recebido.
class FakeTarget extends Node2D:
	var taken: int = 0

	func take_damage(amount: int, _source: Variant = null) -> void:
		taken += amount


func _ready() -> void:
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.enemies_cleared.connect(_on_enemies_cleared)

	_test_health_component()
	_test_combat_utils()
	_test_state_machine_basics()
	_test_state_machine_chained_transition()
	_test_state_machine_initial_enter_queues_transition()
	_test_state_machine_stop_and_lock()
	_test_hitbox_deactivated_during_tick()
	_test_tank_phases()
	_test_tank_hurtbox_reaches_health()
	_test_chaser_phases()
	_test_shooter_phases()
	_test_dummy_enemy()
	_test_dummy_damage_text()
	_test_scene_paths()
	_test_level_manager_counts_deaths()
	_test_state_warden_vocabulary()
	_test_state_warden_death()
	_test_state_warden_enemies()
	_test_wave_manager_flow()
	_test_wave_manager_player_death()
	_test_level_manager_wave_mode()
	_test_player_heal_request()
	_test_fase_1_waves_setup()
	# v2.7.0
	_test_damage_acceptance()
	_test_enemy_projectile_iframes()
	_test_player_heal_noop()
	_test_tank_stomp_cooldown()
	_test_wave_spawn_far_from_player()
	_test_instantiate_as()
	# v2.7.0: precisam de frames reais (call_deferred / timers)
	await _test_vanished_enemy_does_not_softlock()
	await _test_game_timer_respects_pause()

	print("\n==== %d checagens, %d falhas ====" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


# --------------------------------------------------------------------------
# Infra dos testes
# --------------------------------------------------------------------------

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("ok:   ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
		push_error("FAIL: " + label)


func _spawn(path: String, pos: Vector2 = Vector2.ZERO) -> Node2D:
	var scene := load(path) as PackedScene
	var inst := scene.instantiate() as Node2D
	inst.position = pos
	add_child(inst)
	return inst


func _make_player(pos: Vector2) -> Node2D:
	var p := Node2D.new()
	p.name = "FakePlayer"
	p.position = pos
	add_child(p)
	p.add_to_group(CombatUtils.GROUP_PLAYER)
	return p


## Libera o nó na hora (sem esperar o fim do frame). Inimigos mortos chamam queue_free() e
## continuariam na árvore/grupo "enemy" até lá, contaminando o teste seguinte.
func _cleanup(node: Node) -> void:
	if is_instance_valid(node):
		node.free()


## Avança o estado atual da máquina como se fosse um frame de física.
func _step(sm: BaseStateMachine, delta: float = DT) -> void:
	sm.current_state.physics_update(delta)


func _on_enemy_died(_enemy: Node2D, kind: StringName, _pos: Vector2) -> void:
	_died_kinds.append(kind)


func _on_enemies_cleared() -> void:
	_cleared_count += 1


func _on_health_died() -> void:
	_health_died_count += 1


func _build_machine(state_names: Array, configure: Callable = Callable(), machine: BaseStateMachine = null) -> Dictionary:
	var actor := Node.new()
	actor.name = "ProbeActor"
	var sm: BaseStateMachine = machine if machine != null else BaseStateMachine.new()
	sm.name = "ProbeMachine"
	actor.add_child(sm)
	var states: Dictionary = {}
	for state_name in state_names:
		var s := ProbeState.new()
		s.name = state_name
		sm.add_child(s)
		states[state_name] = s
	if configure.is_valid():
		configure.call(sm, states)
	add_child(actor)  # _ready da máquina -> ready do ator -> start()
	return {"actor": actor, "sm": sm, "states": states}


# --------------------------------------------------------------------------
# Componentes comuns
# --------------------------------------------------------------------------

func _test_health_component() -> void:
	print("\n-- HealthComponent --")
	_health_died_count = 0
	var h := HealthComponent.new()
	add_child(h)
	h.died.connect(_on_health_died)
	h.setup(50)
	_check(h.current_health == 50, "setup(50) enche a vida")
	_check(h.take_damage(30) == 30, "dano de 30 aplicado por inteiro")
	_check(h.take_damage(100) == 20, "dano acima da vida restante é limitado")
	_check(h.is_dead() and _health_died_count == 1, "morreu e 'died' emitido uma vez")
	_check(h.take_damage(10) == 0 and _health_died_count == 1, "dano após a morte é ignorado")
	h.heal(10)
	_check(h.current_health == 0, "cura após a morte é ignorada")
	_cleanup(h)


func _test_combat_utils() -> void:
	print("\n-- CombatUtils --")
	var plain := Node.new()
	add_child(plain)
	_check(not CombatUtils.apply_damage(plain, 10), "apply_damage em nó sem take_damage retorna false")
	_check(not CombatUtils.apply_damage(null, 10), "apply_damage em null retorna false")
	var h := HealthComponent.new()
	add_child(h)
	h.setup(10)
	_check(not CombatUtils.apply_damage(h, 0), "apply_damage com dano 0 retorna false")
	_check(CombatUtils.apply_damage(h, 4) and h.current_health == 6, "apply_damage entrega o dano")
	_cleanup(plain)
	_cleanup(h)


# --------------------------------------------------------------------------
# BaseStateMachine
# --------------------------------------------------------------------------

func _test_state_machine_basics() -> void:
	print("\n-- BaseStateMachine: básico --")
	var built := _build_machine([&"A", &"B", &"C"])
	var sm := built["sm"] as BaseStateMachine
	var st: Dictionary = built["states"]
	var a := st[&"A"] as ProbeState
	var b := st[&"B"] as ProbeState
	_check(sm.is_in_state(&"a") and a.events == ["enter"], "inicia no primeiro estado filho")
	_check(sm.transition_to(&"b"), "transição case-insensitive ('b' -> B)")
	_check(a.events == ["enter", "exit"] and b.events == ["enter"], "exit do antigo, enter do novo")
	_check(not sm.transition_to(&"b"), "transição para o estado atual é ignorada")
	_check(not sm.transition_to(&"inexistente"), "estado inexistente retorna false")
	(st[&"C"] as ProbeState).request_transition(&"A")
	_check(sm.is_in_state(&"b"), "request_transition de um estado que não é o atual é ignorado")
	_cleanup(built["actor"])


func _test_state_machine_chained_transition() -> void:
	print("\n-- BaseStateMachine: transição pedida dentro de enter() --")
	var built := _build_machine([&"A", &"B", &"C"])
	var sm := built["sm"] as BaseStateMachine
	var st: Dictionary = built["states"]
	var b := st[&"B"] as ProbeState
	b.chain_to = &"C"
	sm.transition_to(&"B")
	_check(sm.is_in_state(&"c"), "B pediu C no enter(): termina em C")
	_check(b.events == ["enter", "exit"], "B entrou e saiu exatamente uma vez")
	_check((st[&"C"] as ProbeState).events == ["enter"], "C entrou exatamente uma vez")
	_cleanup(built["actor"])


func _test_state_machine_initial_enter_queues_transition() -> void:
	print("\n-- BaseStateMachine: enter() do estado inicial --")
	var changes: Array = []
	var configure := func(machine: BaseStateMachine, states: Dictionary) -> void:
		(states[&"A"] as ProbeState).chain_to = &"B"
		machine.state_changed.connect(func(prev: StringName, nxt: StringName) -> void:
			changes.append([String(prev), String(nxt)]))
	var built := _build_machine([&"A", &"B"], configure)
	var sm := built["sm"] as BaseStateMachine
	_check(sm.is_in_state(&"b"), "A pediu B no enter() inicial: termina em B")
	_check(changes == [["", "A"], ["A", "B"]], "state_changed sai na ordem ('' -> A, depois A -> B)")
	_cleanup(built["actor"])


func _test_state_machine_stop_and_lock() -> void:
	print("\n-- BaseStateMachine: stop() e locked --")
	var built := _build_machine([&"A", &"B"])
	var sm := built["sm"] as BaseStateMachine
	var a := (built["states"] as Dictionary)[&"A"] as ProbeState
	sm.locked = true
	_check(not sm.transition_to(&"B"), "locked bloqueia transições")
	sm.locked = false
	_check(sm.transition_to(&"B"), "destravada, a transição funciona")
	sm.stop()
	_check(sm.current_state == null and sm.locked, "stop() zera o estado e trava a máquina")
	_check(not sm.transition_to(&"A"), "após stop() nenhuma transição é aceita")
	_check(a.events == ["enter", "exit"], "estado A não recebeu eventos extras")
	_cleanup(built["actor"])


# --------------------------------------------------------------------------
# Hitbox
# --------------------------------------------------------------------------

func _test_hitbox_deactivated_during_tick() -> void:
	print("\n-- Hitbox: desativar durante um tick --")
	var hb := Hitbox.new()
	hb.tick_interval = 0.5
	add_child(hb)

	var other_actor := Node2D.new()
	add_child(other_actor)
	var hurt := Hurtbox.new()
	hurt.actor = other_actor
	add_child(hurt)

	hb._tick_cooldowns[hurt] = 0.0  # simula um alvo dentro da área com o tick vencido
	hb.hit_landed.connect(func(_target: Node, _dealt: int) -> void: hb.set_active(false))
	hb._physics_process(0.01)
	_check(not hb.is_active(), "o acerto desativou a hitbox")
	_check(hb._tick_cooldowns.is_empty(), "nenhum cooldown residual depois de desativar")
	_cleanup(hb)
	_cleanup(hurt)
	_cleanup(other_actor)


# --------------------------------------------------------------------------
# Tank: Idle -> Chase -> Special_Attack (telegraph -> dash) -> Chase -> Attack -> morte
# --------------------------------------------------------------------------

func _test_tank_phases() -> void:
	print("\n-- Tank --")
	_died_kinds.clear()
	var player := _make_player(Vector2(400, 0))
	var tank := _spawn(TANK_SCENE) as TankEnemy
	var sm := tank.state_machine

	_check(sm.is_in_state(&"idle"), "começa em Idle")
	_check(tank.health_component.max_health == tank.max_health, "vida máxima vem do export do Tank")

	tank.player = player
	_step(sm)
	_check(sm.is_in_state(&"chase"), "viu o player: Idle -> Chase")

	_step(sm)
	_check(sm.is_in_state(&"special_attack"), "player longe e dash liberado: Chase -> Special_Attack")
	var special := sm.get_state(&"special_attack")
	_check(int(special.get(&"_phase")) == 0, "investida começa no TELEGRAPH")
	_check(not tank.dash_hitbox.is_active(), "hitbox da investida desligada durante o telégrafo")

	_step(sm, tank.dash_prepare_time + DT)
	_check(int(special.get(&"_phase")) == 1, "fim do telégrafo: TELEGRAPH -> DASHING")
	_check(tank.dash_hitbox.is_active() and tank.dash_hitbox.damage == tank.dash_damage,
		"hitbox da investida ligada com o dano configurado")

	_step(sm, tank.dash_duration + DT)
	_check(sm.is_in_state(&"chase"), "fim da investida: Special_Attack -> Chase")
	_check(not tank.dash_hitbox.is_active(), "hitbox da investida desligada ao sair")
	_check(not tank.can_dash(), "cooldown da investida ativo depois de investir")

	player.position = tank.global_position + Vector2(10, 0)
	_step(sm)
	_check(sm.is_in_state(&"attack"), "player ao alcance: Chase -> Attack")
	_check(tank.stomp_hitbox.is_active() and tank.stomp_hitbox.damage == tank.stomp_damage,
		"hitbox do pisoteio ligada com o dano configurado")

	player.position = tank.global_position + Vector2(500, 0)
	_step(sm)
	_check(sm.is_in_state(&"chase"), "player saiu do alcance: Attack -> Chase")
	_check(not tank.stomp_hitbox.is_active(), "hitbox do pisoteio desligada ao sair")

	tank.take_damage(tank.max_health + 1000)
	_check(tank.is_dead(), "Tank morreu")
	_check(sm.current_state == null and sm.locked, "máquina parada e travada na morte")
	_check(not sm.transition_to(&"chase"), "nenhuma transição depois da morte")
	_check(not tank.hurtbox.is_active(), "hurtbox desligada na morte")
	_check(_died_kinds == [&"tank"], "EventBus.enemy_died emitido uma vez com kind 'tank'")
	_cleanup(tank)
	_cleanup(player)


func _test_tank_hurtbox_reaches_health() -> void:
	print("\n-- Tank: Hurtbox -> HealthComponent (regressão B04) --")
	var tank := _spawn(TANK_SCENE) as TankEnemy
	var before := tank.health_component.current_health
	tank.hurtbox.take_damage(10, null)
	_check(tank.health_component.current_health == before - 10, "dano na Hurtbox reduz a vida do Tank")
	_cleanup(tank)


# --------------------------------------------------------------------------
# Chaser: Idle -> Chase -> Attack (WINDUP -> ACTIVE -> COOLDOWN) -> EnergyWave -> Idle -> morte
# --------------------------------------------------------------------------

func _test_chaser_phases() -> void:
	print("\n-- Chaser --")
	_died_kinds.clear()
	var player := _make_player(Vector2(50, 0))
	var chaser := _spawn(CHASER_SCENE) as ChaserEnemy
	var sm := chaser.state_machine

	_check(sm.is_in_state(&"IdleState"), "começa em IdleState")
	chaser.player_ref = player
	chaser.player_in_detection = true
	_step(sm)
	_check(sm.is_in_state(&"ChaseState"), "viu o player: Idle -> Chase")

	chaser.player_in_attack_range = true
	_step(sm)
	_check(sm.is_in_state(&"AttackState"), "player ao alcance: Chase -> Attack")

	var atk := sm.get_state(&"AttackState") as ChaserAttackState
	_check(atk._phase == ChaserAttackState.Phase.WINDUP, "golpe começa no WINDUP")
	_check(not chaser.hitbox.is_active(), "hitbox desligada no WINDUP")

	_step(sm, chaser.attack_windup_time + DT)
	_check(atk._phase == ChaserAttackState.Phase.ACTIVE and chaser.hitbox.is_active(),
		"WINDUP -> ACTIVE liga a hitbox")

	_step(sm, chaser.attack_hit_window + DT)
	_check(atk._phase == ChaserAttackState.Phase.COOLDOWN and not chaser.hitbox.is_active(),
		"ACTIVE -> COOLDOWN desliga a hitbox")

	_step(sm, chaser.attack_cooldown_time + DT)
	_check(sm.is_in_state(&"AttackState") and atk._phase == ChaserAttackState.Phase.WINDUP,
		"player ainda ao alcance: novo golpe (COOLDOWN -> WINDUP)")

	chaser.player_in_attack_range = false
	_step(sm, chaser.attack_windup_time + DT)
	_step(sm, chaser.attack_hit_window + DT)
	_step(sm, chaser.attack_cooldown_time + DT)
	_check(sm.is_in_state(&"ChaseState"), "player saiu do alcance: fim do golpe volta ao Chase")
	_check(not chaser.hitbox.is_active(), "hitbox desligada ao sair do Attack")

	chaser._on_detection_body_exited(player)  # mesmo caminho do sinal body_exited
	_step(sm)
	_check(sm.is_in_state(&"EnergyWaveState"), "player fugiu da visão: Chase -> EnergyWave")
	_check(chaser.player_ref == null, "EnergyWave esquece o alvo")
	var wave_state := sm.get_state(&"EnergyWaveState") as ChaserEnergyWaveState
	_step(sm, wave_state.recovery_time + DT)
	_check(sm.is_in_state(&"IdleState"), "fim da recuperação: EnergyWave -> Idle")

	# B49: morte do player (EventBus) não pode disparar a onda contra o cadáver.
	chaser.player_ref = player
	chaser.player_in_detection = true
	_step(sm)
	_check(sm.is_in_state(&"ChaseState"), "viu o player de novo: Idle -> Chase")
	EventBus.player_died.emit()
	_step(sm)
	_check(sm.is_in_state(&"IdleState"), "B49: player_died -> Chase volta ao Idle (sem onda)")
	chaser.player_ref = player
	chaser.player_in_detection = true
	chaser.player_in_attack_range = true
	_step(sm)
	_step(sm)
	_check(sm.is_in_state(&"AttackState"), "de volta ao Attack")
	EventBus.player_died.emit()
	_step(sm, chaser.attack_windup_time + DT)
	_step(sm, chaser.attack_hit_window + DT)
	_step(sm, chaser.attack_cooldown_time + DT)
	_check(sm.is_in_state(&"IdleState"), "B49: player_died durante o golpe -> Idle (sem onda)")

	chaser.take_damage(chaser.max_health + 1000)
	_check(chaser.is_dead(), "Chaser morreu")
	_check(sm.current_state == null and sm.locked, "máquina parada e travada na morte")
	_check(not sm.transition_to(&"ChaseState"), "nenhuma transição depois da morte")
	_check(_died_kinds == [&"chaser"], "EventBus.enemy_died emitido uma vez com kind 'chaser'")
	_cleanup(chaser)
	_cleanup(player)


# --------------------------------------------------------------------------
# Shooter: Idle -> Chase -> AttackRanged -> AttackMelee (CHARGING -> COOLDOWN) -> AttackRanged -> Death
# --------------------------------------------------------------------------

func _test_shooter_phases() -> void:
	print("\n-- Shooter --")
	_died_kinds.clear()
	var player := _make_player(Vector2(100, 0))
	var shooter := _spawn(SHOOTER_SCENE) as RangedEnemy
	var sm := shooter.state_machine

	_check(sm.is_in_state(&"idle"), "começa em Idle")
	_step(sm)
	_check(sm.is_in_state(&"idle"), "sem aggro, continua em Idle")

	shooter.target = player
	shooter.has_aggro = true
	_step(sm)
	_check(sm.is_in_state(&"chase"), "ganhou aggro: Idle -> Chase")

	_step(sm)
	_check(sm.is_in_state(&"attackranged"), "player no alcance de tiro: Chase -> AttackRanged")

	shooter.is_player_in_melee_range = true
	_step(sm)
	_check(sm.is_in_state(&"attackmelee"), "player colou: AttackRanged -> AttackMelee")
	var melee := sm.get_state(&"attackmelee") as ShooterAttackMeleeState
	_check(melee._phase == ShooterAttackMeleeState.Phase.CHARGING, "ataque em área começa em CHARGING")

	_step(sm, shooter.melee_telegraph_time + DT)
	_check(melee._phase == ShooterAttackMeleeState.Phase.COOLDOWN, "CHARGING -> COOLDOWN")

	shooter.is_player_in_melee_range = false
	_step(sm, shooter.melee_attack_cooldown + DT)
	_check(sm.is_in_state(&"attackranged"), "player afastou: fim do cooldown volta ao AttackRanged")

	shooter.take_damage(100000)
	_check(shooter.is_dead(), "Shooter morreu")
	_check(sm.is_in_state(&"death") and sm.locked, "morte: estado Death e máquina travada")
	_check(not sm.transition_to(&"idle"), "nada tira o Shooter do Death")
	_check(not shooter.hurtbox.is_active(), "hurtbox desligada na morte")
	shooter.take_damage(10)
	_check(_died_kinds == [&"shooter"], "EventBus.enemy_died emitido uma vez com kind 'shooter'")
	_cleanup(shooter)
	_cleanup(player)


# --------------------------------------------------------------------------
# DummyEnemy (inimigo de treino): mesma API de dano e mesmas camadas do resto
# --------------------------------------------------------------------------

func _test_dummy_enemy() -> void:
	print("\n-- DummyEnemy --")
	var dummy := _spawn(DUMMY_SCENE) as DummyEnemy
	_check(dummy.is_in_group(DummyEnemy.GROUP_DUMMY), "DummyEnemy entra no grupo 'dummy_enemy'")
	_check(not dummy.is_in_group(CombatUtils.GROUP_ENEMY), "DummyEnemy não conta como inimigo da fase")
	_check(dummy.hurtbox != null and dummy.hurtbox.is_in_group(CombatUtils.GROUP_HURTBOX),
		"Hurtbox do dummy está atribuída e no grupo 'hurtbox'")

	# Dano recebido: Hurtbox -> número flutuante (sinal dano_recebido).
	var received: Array = []
	dummy.dano_recebido.connect(func(value: int) -> void: received.append(value))
	_check(CombatUtils.apply_damage(dummy.hurtbox, 7, null), "apply_damage na Hurtbox do dummy é aceito")
	_check(received == [7], "Hurtbox -> dano_recebido(7)")
	dummy.take_damage(3)
	_check(received == [7, 3], "take_damage(amount, source) do dummy também mostra o dano")

	# Dano causado: sempre pela API única.
	var target := FakeTarget.new()
	add_child(target)
	var hits: Array = []
	dummy.acertou_alvo.connect(func(_t: Node, dealt: int, kind: StringName) -> void: hits.append([dealt, kind]))
	dummy._ao_acertar(target, 3, &"espada")
	_check(target.taken == 3, "ataque do dummy entrega o dano por take_damage")
	_check(hits == [[3, &"espada"]], "acertou_alvo emitido com o dano e o tipo do ataque")
	dummy.aplicar_dano_direto = false
	dummy._ao_acertar(target, 5, &"onda")
	_check(target.taken == 3, "aplicar_dano_direto = false só emite o sinal")

	# Regra de camadas: ataque sem layer própria, máscara só nas Hurtboxes do player.
	var proj := dummy.cena_projetil.instantiate() as DummyProjetil
	dummy._configurar_colisao(proj)
	_check(proj.collision_layer == 0 and proj.collision_mask == dummy.mascara_alvo,
		"ataques do dummy: layer 0 e máscara nas Hurtboxes do player")
	_cleanup(proj)

	# Alvo: sem player não ataca; com player ataca e só uma espada por vez.
	dummy.alvo = null
	dummy.atacar_espada()
	_check(not is_instance_valid(dummy._espada_atual), "sem player na cena o dummy não ataca")
	var player := _make_player(Vector2(100, 0))
	dummy.atacar_espada()
	_check(is_instance_valid(dummy._espada_atual), "com player na cena o dummy ataca com a espada")
	var sword := dummy._espada_atual
	dummy.atacar_espada()
	_check(dummy._espada_atual == sword, "uma espada por vez")

	_cleanup(target)
	_cleanup(player)
	_cleanup(dummy)


# --------------------------------------------------------------------------
# Dummy: número de dano flutuante (DamageText)
# --------------------------------------------------------------------------

func _test_dummy_damage_text() -> void:
	print("\n-- Dummy: número de dano --")
	# Um DamageText por golpe, com o valor exato; dano 0 não cria nada.
	var dummy := _spawn(DUMMY_SCENE) as DummyEnemy
	dummy.receber_dano(12)
	dummy.receber_dano(0)
	var textos: Array = dummy.get_children().filter(func(n: Node) -> bool: return n is DamageText)
	_check(textos.size() == 1 and (textos[0] as DamageText).text == "12",
		"dano 12 cria 1 DamageText com o valor exato (dano 0 não cria)")
	_check(textos.size() > 0 and (textos[0] as DamageText).top_level,
		"DamageText é top_level (posição global)")
	_cleanup(dummy)


## Regressão: cenas movidas de pasta apontavam para res:// que não existiam.
func _test_scene_paths() -> void:
	print("\n-- Cenas de debug / arena de teste --")
	for path: String in [
		"res://ui/debug/painel_dummy.tscn",
		"res://tests/dummy_arena/teste_dummy.tscn",
		"res://enemies/dummy_enemy/projetil.tscn",
		"res://enemies/dummy_enemy/onda_choque.tscn",
		"res://enemies/dummy_enemy/espada_ataque.tscn",
		"res://ui/damage_text/DamageText.tscn",
	]:
		var scene := load(path) as PackedScene
		_check(scene != null and scene.can_instantiate(), "carrega e instancia: " + path)


# --------------------------------------------------------------------------
# LevelManager (integração inimigos -> EventBus -> regras da fase)
# --------------------------------------------------------------------------

func _test_level_manager_counts_deaths() -> void:
	print("\n-- LevelManager --")
	_cleared_count = 0
	var lm := LevelManager.new()
	lm.complete_delay = 60.0  # não deixa o timer de vitória disparar durante o teste
	add_child(lm)             # _enter_tree conecta no EventBus antes dos inimigos nascerem

	var a := _spawn(CHASER_SCENE, Vector2(0, 0)) as ChaserEnemy
	var b := _spawn(CHASER_SCENE, Vector2(100, 0)) as ChaserEnemy
	_check(lm.get_remaining() == 2, "2 inimigos registrados")

	a.take_damage(a.max_health + 1000)
	_check(lm.get_remaining() == 1 and _cleared_count == 0, "1 morte: resta 1 e a fase não terminou")
	a.take_damage(10)
	_check(lm.get_remaining() == 1, "dano no inimigo já morto não altera a contagem")

	b.take_damage(b.max_health + 1000)
	_check(lm.get_remaining() == 0 and _cleared_count == 1, "última morte: 0 restantes e 'enemies_cleared' uma vez")
	_cleanup(a)
	_cleanup(b)
	_cleanup(lm)


# --------------------------------------------------------------------------
# StateWarden (vocabulário canônico Idle / Chase / Attack / Dead)
# --------------------------------------------------------------------------

func _test_state_warden_vocabulary() -> void:
	print("\n-- StateWarden: vocabulário canônico --")
	var changes: Array = []
	var configure := func(machine: BaseStateMachine, _states: Dictionary) -> void:
		(machine as StateWarden).warden_state_changed.connect(
			func(prev: StateWarden.State, cur: StateWarden.State) -> void: changes.append([prev, cur]))
	var built := _build_machine([&"Idle", &"Chase", &"AttackRanged", &"Death"], configure, StateWarden.new())
	var sm := built["sm"] as StateWarden
	_check(sm.has_canonical(StateWarden.State.IDLE) and sm.has_canonical(StateWarden.State.CHASE)
			and sm.has_canonical(StateWarden.State.ATTACK) and sm.has_canonical(StateWarden.State.DEAD),
		"nós Idle / Chase / AttackRanged / Death resolvem para IDLE / CHASE / ATTACK / DEAD")
	_check(sm.is_canonical(StateWarden.State.IDLE), "começa em IDLE (vocabulário canônico)")
	_check(sm.request(StateWarden.State.CHASE) and sm.is_in_state(&"chase") and sm.is_canonical(StateWarden.State.CHASE),
		"request(CHASE) leva ao nó Chase")
	_check(sm.request(StateWarden.State.ATTACK) and sm.is_in_state(&"attackranged"),
		"request(ATTACK) leva ao nó AttackRanged")
	_check(changes == [[StateWarden.State.NONE, StateWarden.State.IDLE],
			[StateWarden.State.IDLE, StateWarden.State.CHASE],
			[StateWarden.State.CHASE, StateWarden.State.ATTACK]],
		"warden_state_changed traduz as trocas para o vocabulário canônico")
	_cleanup(built["actor"])

	# Nomes de nó -> canônico (estados extras dos inimigos contam como ATTACK).
	_check(StateWarden.to_canonical(&"IdleState") == StateWarden.State.IDLE, "to_canonical: IdleState -> IDLE")
	_check(StateWarden.to_canonical(&"Special_Attack") == StateWarden.State.ATTACK, "to_canonical: Special_Attack -> ATTACK")
	_check(StateWarden.to_canonical(&"EnergyWaveState") == StateWarden.State.ATTACK, "to_canonical: EnergyWaveState -> ATTACK")
	_check(StateWarden.to_canonical(&"DeathState") == StateWarden.State.DEAD, "to_canonical: DeathState -> DEAD")
	_check(StateWarden.to_canonical(&"Voar") == StateWarden.State.NONE and StateWarden.to_canonical(&"") == StateWarden.State.NONE,
		"to_canonical: nome desconhecido ou vazio -> NONE")

	# Máquina sem estado de ataque: request(ATTACK) falha sem quebrar.
	var partial := _build_machine([&"Idle", &"Chase"], Callable(), StateWarden.new())
	var psm := partial["sm"] as StateWarden
	_check(not psm.has_canonical(StateWarden.State.ATTACK) and not psm.request(StateWarden.State.ATTACK),
		"request de estado canônico inexistente retorna false")
	_check(psm.is_canonical(StateWarden.State.IDLE), "...e a máquina continua no estado atual")
	_cleanup(partial["actor"])


func _test_state_warden_death() -> void:
	print("\n-- StateWarden: die() --")
	var deaths: Array = [0]
	var configure := func(machine: BaseStateMachine, _states: Dictionary) -> void:
		(machine as StateWarden).warden_died.connect(func() -> void: deaths[0] += 1)
	var built := _build_machine([&"Idle", &"Chase", &"Dead"], configure, StateWarden.new())
	var sm := built["sm"] as StateWarden
	sm.die()
	sm.die()
	_check(sm.is_dead() and sm.is_canonical(StateWarden.State.DEAD) and sm.locked,
		"die(): entra em Dead e trava a máquina")
	_check(deaths[0] == 1, "warden_died emitido uma única vez (die() é idempotente)")
	_check(not sm.transition_to(&"idle") and not sm.request(StateWarden.State.CHASE),
		"nada tira o inimigo do estado Dead")
	_cleanup(built["actor"])

	# Sem estado Dead: die() só encerra a máquina.
	deaths[0] = 0
	var plain := _build_machine([&"Idle", &"Chase", &"Attack"], configure, StateWarden.new())
	var psm := plain["sm"] as StateWarden
	psm.die()
	_check(psm.is_dead() and psm.current_state == null and psm.locked and deaths[0] == 1,
		"sem nó Dead: die() equivale a stop() e emite warden_died")
	_cleanup(plain["actor"])

	# die() dentro de um enter(): a transição é enfileirada e o Dead ainda é alcançado e travado.
	var queued := _build_machine([&"Idle", &"Dead"], Callable(), StateWarden.new())
	var qsm := queued["sm"] as StateWarden
	var trap := DieOnEnterState.new()
	trap.name = "Chase"
	qsm.add_child(trap)
	trap.setup(qsm, queued["actor"])
	qsm._states[&"chase"] = trap  # registra o estado criado depois do _ready da máquina
	qsm.transition_to(&"chase")
	_check(qsm.is_canonical(StateWarden.State.DEAD) and qsm.locked,
		"die() chamado dentro de enter(): termina em Dead e travado")
	_cleanup(queued["actor"])


func _test_state_warden_enemies() -> void:
	print("\n-- StateWarden: inimigos reais --")
	var tank := _spawn(TANK_SCENE) as TankEnemy
	var chaser := _spawn(CHASER_SCENE) as ChaserEnemy
	var shooter := _spawn(SHOOTER_SCENE) as RangedEnemy
	for enemy: Node in [tank, chaser, shooter]:
		var sm := enemy.get("state_machine") as StateWarden
		_check(sm != null, "%s: a máquina de estados é um StateWarden" % enemy.name)
		if sm == null:
			continue
		_check(sm.has_canonical(StateWarden.State.IDLE) and sm.has_canonical(StateWarden.State.CHASE)
				and sm.has_canonical(StateWarden.State.ATTACK), "%s: tem Idle, Chase e Attack canônicos" % enemy.name)
		_check(sm.is_canonical(StateWarden.State.IDLE), "%s: nasce em IDLE" % enemy.name)

	_check(tank.state_machine.get_state(&"special_attack") != null
			and StateWarden.to_canonical(&"Special_Attack") == StateWarden.State.ATTACK,
		"Tank: Special_Attack conta como ATTACK")
	_check(chaser.state_machine.is_canonical(StateWarden.State.IDLE) and chaser.state_machine.request(StateWarden.State.CHASE)
			and chaser.state_machine.is_in_state(&"chasestate"),
		"Chaser: request(CHASE) -> ChaseState")
	_check(shooter.state_machine.has_canonical(StateWarden.State.DEAD), "Shooter: tem estado Dead (Death)")

	tank.take_damage(tank.max_health + 1000)
	_check(tank.state_machine.is_dead() and tank.state_machine.locked and tank.state_machine.current_state == null,
		"Tank morto: Warden encerrado (die() sem nó Dead = stop)")
	chaser.take_damage(chaser.max_health + 1000)
	_check(chaser.state_machine.is_dead() and chaser.state_machine.locked, "Chaser morto: Warden encerrado")
	shooter.take_damage(100000)
	_check(shooter.state_machine.is_dead() and shooter.state_machine.is_canonical(StateWarden.State.DEAD)
			and shooter.state_machine.locked, "Shooter morto: Warden em DEAD e travado")
	_cleanup(tank)
	_cleanup(chaser)
	_cleanup(shooter)


# --------------------------------------------------------------------------
# WaveManager (ondas) + LevelManager em modo ondas + cura do Player
# --------------------------------------------------------------------------

## Monta um WaveManager de teste: timers longos (o teste dispara as ondas à mão) e 3 marcadores.
func _build_wave_manager(waves: Array) -> Dictionary:
	var root := Node2D.new()
	root.name = "SpawnPointsTeste"
	for i in 3:
		var marker := Marker2D.new()
		marker.position = Vector2(100.0 * (i + 1), 50.0)
		root.add_child(marker)
	add_child(root)
	var chaser := load(CHASER_SCENE) as PackedScene
	var wm := WaveManager.new()
	wm.first_wave_delay = 600.0
	wm.between_waves_delay = 600.0
	wm.spawn_jitter = 0.0
	wm.spawn_points_root = root
	var arrays: Array[Array] = [wm.wave_1_enemies, wm.wave_2_enemies, wm.wave_3_enemies]
	for i in arrays.size():
		for _n in int(waves[i]):
			arrays[i].append(chaser)
	add_child(wm)
	return {"wm": wm, "root": root}


## Os inimigos de CombatUtils.spawn só entram na árvore no fim do frame; como o teste é
## síncrono, "mata" cada um emitindo enemy_died (como o EnemyEvents faria) e depois os libera.
func _kill_wave(wm: WaveManager) -> Array:
	var spawned: Array = []
	for id: int in wm._alive.keys():
		spawned.append(instance_from_id(id))
	for e: Node2D in spawned:
		EventBus.enemy_died.emit(e, &"chaser", Vector2.ZERO)
	return spawned


func _test_wave_manager_flow() -> void:
	print("\n-- WaveManager: fluxo das ondas --")
	var rec: Dictionary = {"started": [], "cleared": [], "all": 0, "heal": []}
	var on_started := func(w: int, t: int, n: int) -> void: rec["started"].append([w, t, n])
	var on_cleared := func(w: int, t: int) -> void: rec["cleared"].append([w, t])
	var on_all := func() -> void: rec["all"] += 1
	var on_heal := func(a: int) -> void: rec["heal"].append(a)
	EventBus.wave_started.connect(on_started)
	EventBus.wave_cleared.connect(on_cleared)
	EventBus.all_waves_cleared.connect(on_all)
	EventBus.player_heal_requested.connect(on_heal)

	var built := _build_wave_manager([2, 1, 3])
	var wm := built["wm"] as WaveManager
	_check(wm.get_total_waves() == 3 and wm.get_current_wave_number() == 0 and wm.get_alive_count() == 0,
		"antes da onda 1: 3 ondas, onda atual 0, nenhum vivo")

	wm._start_wave(0)
	_check(rec["started"] == [[1, 3, 2]] and wm.get_alive_count() == 2 and wm.get_current_wave_number() == 1,
		"onda 1 nasce com 2 inimigos e emite wave_started(1, 3, 2)")
	var stray := Node2D.new()
	EventBus.enemy_died.emit(stray, &"chaser", Vector2.ZERO)
	_check(wm.get_alive_count() == 2 and rec["cleared"].is_empty(), "morte de inimigo que não é da onda é ignorada")
	var spawned: Array = []
	for id: int in wm._alive.keys():
		spawned.append(instance_from_id(id))
	EventBus.enemy_died.emit(spawned[0], &"chaser", Vector2.ZERO)
	EventBus.enemy_died.emit(spawned[0], &"chaser", Vector2.ZERO)
	_check(wm.get_alive_count() == 1 and rec["cleared"].is_empty(), "morte repetida do mesmo inimigo não conta duas vezes")
	EventBus.enemy_died.emit(spawned[1], &"chaser", Vector2.ZERO)
	_check(rec["cleared"] == [[1, 3]] and rec["heal"] == [30] and rec["all"] == 0,
		"última morte da onda 1: wave_cleared(1, 3) + cura de 30, sem all_waves_cleared")
	for e: Node2D in spawned:
		_cleanup(e)

	wm._start_wave(1)
	var wave2 := _kill_wave(wm)
	_check(rec["cleared"] == [[1, 3], [2, 3]] and rec["heal"] == [30, 30] and rec["all"] == 0,
		"onda 2 limpa: wave_cleared(2, 3), outra cura, ainda sem all_waves_cleared")
	for e: Node2D in wave2:
		_cleanup(e)

	wm._start_wave(2)
	_check(rec["started"].size() == 3 and rec["started"][2] == [3, 3, 3], "onda 3 emite wave_started(3, 3, 3)")
	var wave3 := _kill_wave(wm)
	_check(rec["cleared"].size() == 3 and rec["all"] == 1 and rec["heal"] == [30, 30, 30],
		"onda 3 limpa: all_waves_cleared emitido uma única vez e 3 curas no total")
	for e: Node2D in wave3:
		_cleanup(e)

	EventBus.wave_started.disconnect(on_started)
	EventBus.wave_cleared.disconnect(on_cleared)
	EventBus.all_waves_cleared.disconnect(on_all)
	EventBus.player_heal_requested.disconnect(on_heal)
	_cleanup(stray)
	_cleanup(wm)
	_cleanup(built["root"])


func _test_wave_manager_player_death() -> void:
	print("\n-- WaveManager: Player morto --")
	var heals: Array = []
	var on_heal := func(a: int) -> void: heals.append(a)
	var cleared: Array = [0]
	var on_cleared := func(_w: int, _t: int) -> void: cleared[0] += 1
	EventBus.player_heal_requested.connect(on_heal)
	EventBus.wave_cleared.connect(on_cleared)

	var built := _build_wave_manager([2, 1, 1])
	var wm := built["wm"] as WaveManager
	wm._start_wave(0)
	EventBus.player_died.emit()
	var spawned := _kill_wave(wm)
	_check(heals.is_empty() and cleared[0] == 0, "Player morto: matar a onda não cura nem emite wave_cleared")
	wm._start_wave(1)
	_check(wm.get_current_wave_number() == 1, "Player morto: nenhuma onda nova começa")
	for e: Node2D in spawned:
		_cleanup(e)

	EventBus.player_heal_requested.disconnect(on_heal)
	EventBus.wave_cleared.disconnect(on_cleared)
	_cleanup(wm)
	_cleanup(built["root"])

	# Configuração incompleta não quebra: sem spawn_points_root nada nasce.
	var broken := WaveManager.new()
	broken.first_wave_delay = 600.0
	add_child(broken)
	_check(broken.get_alive_count() == 0, "sem spawn_points_root: o WaveManager não faz nada (só avisa)")
	_cleanup(broken)


func _test_level_manager_wave_mode() -> void:
	print("\n-- LevelManager: modo ondas --")
	_cleared_count = 0
	var lm := LevelManager.new()
	lm.complete_delay = 60.0
	add_child(lm)

	EventBus.wave_started.emit(1, 2, 2)  # liga o modo ondas
	var a := _spawn(CHASER_SCENE, Vector2(0, 0)) as ChaserEnemy
	var b := _spawn(CHASER_SCENE, Vector2(100, 0)) as ChaserEnemy
	_check(lm.get_remaining() == 2, "modo ondas: inimigos da onda são contados")
	a.take_damage(a.max_health + 1000)
	b.take_damage(b.max_health + 1000)
	_check(lm.get_remaining() == 0 and _cleared_count == 0,
		"modo ondas: limpar uma onda intermediária NÃO encerra a fase")
	EventBus.all_waves_cleared.emit()
	_check(_cleared_count == 1, "all_waves_cleared encerra a fase (enemies_cleared uma vez)")
	EventBus.all_waves_cleared.emit()
	_check(_cleared_count == 1, "all_waves_cleared repetido não encerra de novo")
	_cleanup(a)
	_cleanup(b)
	_cleanup(lm)


func _test_player_heal_request() -> void:
	print("\n-- Player: cura pedida pelo EventBus --")
	var player := _spawn(PLAYER_SCENE) as Player
	player.hp = 50
	EventBus.player_heal_requested.emit(30)
	_check(player.hp == 80, "player_heal_requested(30): 50 -> 80 HP")
	EventBus.player_heal_requested.emit(999)
	_check(player.hp == player.hp_maximo, "a cura nunca passa do HP máximo")
	_cleanup(player)


## A Fase 1 deixou de ter inimigos colocados à mão: eles nascem pelo WaveManager.
func _test_fase_1_waves_setup() -> void:
	print("\n-- Fase 1: configuração das ondas --")
	var fase := (load(FASE_1_SCENE) as PackedScene).instantiate()
	var wm := fase.find_child("WaveManager", true, false) as WaveManager
	_check(wm != null, "Fase 1 contém o WaveManager")
	if wm != null:
		var counts := func(scenes: Array[PackedScene]) -> Array:
			var out: Array = [0, 0, 0]  # chaser, shooter, tank
			for sc in scenes:
				match sc.resource_path:
					CHASER_SCENE: out[0] += 1
					SHOOTER_SCENE: out[1] += 1
					TANK_SCENE: out[2] += 1
			return out
		_check(counts.call(wm.wave_1_enemies) == [2, 2, 0], "onda 1: 2 Chasers + 2 Shooters")
		_check(counts.call(wm.wave_2_enemies) == [0, 2, 2], "onda 2: 2 Tanks + 2 Shooters")
		_check(counts.call(wm.wave_3_enemies) == [3, 2, 2], "onda 3: 2 Tanks + 2 Shooters + 3 Chasers")
		_check(wm.spawn_points_root != null and wm.spawn_points_root.get_children().filter(
				func(n: Node) -> bool: return n is Marker2D).size() >= 7,
			"SpawnPoints tem marcadores suficientes para a maior onda (7 inimigos)")
	var placed := fase.get_children().filter(
		func(n: Node) -> bool: return n is TankEnemy or n is ChaserEnemy or n is RangedEnemy)
	_check(placed.is_empty(), "nenhum inimigo colocado à mão na raiz da Fase 1")
	_check(fase.find_child("LevelManager", true, false) is LevelManager, "Fase 1 contém o LevelManager")
	var hud := fase.find_child("HUD", true, false) as GameHUD
	_check(hud != null and hud.wave_label != null, "HUD da Fase 1 tem o wave_label atribuído")
	fase.free()



# --------------------------------------------------------------------------
# v2.7.0 — regressões dos bugs B55..B65
# --------------------------------------------------------------------------

## Alvo no formato antigo (take_damage sem retorno): continua contando como acerto.
class LegacyTarget extends Node2D:
	var taken: int = 0

	func take_damage(amount: int, _source: Variant = null) -> void:
		taken += amount


## B55: apply_damage só retorna true quando o alvo ACEITA o dano.
func _test_damage_acceptance() -> void:
	print("\n-- B55: dano aceito x recusado --")
	var player := _spawn(PLAYER_SCENE) as Player
	var received: Array = [0]
	var on_received := func(_a: int, _s: Variant) -> void: received[0] += 1
	player.hurtbox.damage_received.connect(on_received)

	player._iframes_left = 1.0
	_check(not CombatUtils.apply_damage(player.hurtbox, 10), "i-frames: apply_damage(PlayerHurtbox) retorna false")
	_check(player.hp == player.hp_maximo and received[0] == 0, "i-frames: HP intacto e damage_received NÃO emitido")
	player._iframes_left = 0.0
	_check(CombatUtils.apply_damage(player.hurtbox, 10), "sem i-frames: apply_damage retorna true")
	_check(player.hp == player.hp_maximo - 10 and received[0] == 1, "sem i-frames: HP -10 e damage_received 1x")

	var tank := _spawn(TANK_SCENE, Vector2(500, 0)) as TankEnemy
	_check(CombatUtils.apply_damage(tank.hurtbox, 5), "Tank vivo aceita dano pela Hurtbox")
	tank.take_damage(tank.max_health + 1000)
	_check(not CombatUtils.apply_damage(tank, 5), "Tank morto recusa dano no corpo (take_damage -> false)")
	var hc := HealthComponent.new()
	add_child(hc)
	hc.setup(1)
	hc.take_damage(1)
	var hb := Hurtbox.new()
	hb.health_component = hc
	add_child(hb)
	_check(not hb.take_damage(5), "Hurtbox com HealthComponent morto recusa o dano")
	hb.set_active(false)
	_check(not CombatUtils.apply_damage(hb, 5), "Hurtbox desligada recusa o dano")

	var legacy := LegacyTarget.new()
	add_child(legacy)
	_check(CombatUtils.apply_damage(legacy, 3) and legacy.taken == 3, "alvo antigo (take_damage -> void) ainda conta como acerto")
	_check(not CombatUtils.apply_damage(legacy, 0), "dano 0 nunca é aplicado")

	_cleanup(legacy)
	_cleanup(hb)
	_cleanup(hc)
	_cleanup(tank)
	_cleanup(player)


## B55: o projétil do Shooter atravessa o Player em dash (antes era consumido sem causar dano).
func _test_enemy_projectile_iframes() -> void:
	print("\n-- B55: projétil inimigo x i-frames --")
	var player := _spawn(PLAYER_SCENE) as Player
	var proj := _spawn(ENEMY_PROJECTILE_SCENE, Vector2(5, 0)) as EnemyProjectile
	player._iframes_left = 1.0
	var hit := proj.hitbox._try_hit(player.hurtbox, false)
	_check(not hit and not proj._consumed, "i-frames: projétil NÃO acerta e NÃO é consumido")
	player._iframes_left = 0.0
	hit = proj.hitbox._try_hit(player.hurtbox, false)
	_check(hit and proj._consumed, "sem i-frames: projétil acerta e é consumido")
	_check(player.hp < player.hp_maximo, "sem i-frames: Player perde HP")
	_cleanup(proj)
	_cleanup(player)


## B62: curar com HP cheio não emite hp_changed.
func _test_player_heal_noop() -> void:
	print("\n-- B62: cura com HP cheio --")
	var player := _spawn(PLAYER_SCENE) as Player
	var emitted: Array = [0]
	var on_hp := func(_a: int, _b: int) -> void: emitted[0] += 1
	player.hp_changed.connect(on_hp)
	_check(player.curar(30) == 0 and emitted[0] == 0, "HP cheio: curar() retorna 0 e não emite hp_changed")
	player.hp = 90
	_check(player.curar(30) == 10 and player.hp == player.hp_maximo and emitted[0] == 1,
		"HP 90: curar(30) devolve 10 (limitado ao máximo) e emite 1x")
	_cleanup(player)


## B56: entrar/sair do alcance não reinicia a recarga do pisoteio.
func _test_tank_stomp_cooldown() -> void:
	print("\n-- B56: recarga do pisoteio do Tank --")
	var player := _make_player(Vector2(10, 0))
	var tank := _spawn(TANK_SCENE) as TankEnemy
	var sm := tank.state_machine
	tank.player = player
	_step(sm)  # Idle -> Chase
	_step(sm)  # Chase -> Attack (player a 10 px)
	_check(sm.is_in_state(&"attack"), "player colado: Chase -> Attack")
	_check(tank.can_stomp(), "pisoteio pronto antes do primeiro acerto")
	_check(not tank.stomp_hitbox.damage_on_contact, "pisoteio sem dano por contato (cadência só por pulso)")

	tank.stomp_hitbox.hit_landed.emit(player, tank.stomp_damage)  # um acerto aceito
	_check(not tank.can_stomp(), "acerto aceito inicia a recarga")
	player.position = Vector2(500, 0)
	_step(sm)
	_check(sm.is_in_state(&"chase"), "player saiu: Attack -> Chase")
	player.position = Vector2(10, 0)
	_step(sm)
	_check(sm.is_in_state(&"attack"), "player voltou: Chase -> Attack")
	_check(not tank.can_stomp(), "reentrar no alcance NÃO zera a recarga (antes: acerto imediato)")
	tank._physics_process(tank.stomp_pulse_interval + DT)
	_check(tank.can_stomp(), "recarga libera após stomp_pulse_interval")
	_cleanup(tank)
	_cleanup(player)


## B57: o WaveManager não faz inimigos nascerem em cima do Player.
func _test_wave_spawn_far_from_player() -> void:
	print("\n-- B57: spawn longe do Player --")
	var built := _build_wave_manager([3, 0, 0])  # marcadores em x = 100, 200, 300 (y = 50)
	var wm := built["wm"] as WaveManager
	var player := _make_player(Vector2(100, 50))
	wm.min_player_distance = 150.0
	wm._start_wave(0)
	var all_far := true
	for id: int in wm._alive.keys():
		var e := instance_from_id(id) as Node2D
		if e.position.distance_to(player.position) < 150.0:
			all_far = false
	_check(wm._alive.size() == 3 and all_far, "Player sobre um marcador: os 3 inimigos nascem a >= 150 px")
	for id: int in wm._alive.keys():
		_cleanup(instance_from_id(id))

	wm.min_player_distance = 5000.0  # nenhum marcador serve: usa do mais longe ao mais perto
	wm._order_spawn_points()
	_check(wm._wave_points.size() == 3 and wm._wave_points[0].position == Vector2(300, 50),
		"todos perto demais: ordem do mais distante para o mais próximo (sem travar)")
	_cleanup(player)
	_cleanup(wm)
	_cleanup(built["root"])


## B59: instantiate_as libera a instância de tipo errado (sem nó órfão).
func _test_instantiate_as() -> void:
	print("\n-- B59: instantiate_as --")
	var scene := load(DAMAGE_TEXT_SCENE) as PackedScene
	var orphans_before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var wrong := CombatUtils.instantiate_as(scene, DummyProjetil)
	var orphans_after := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	_check(wrong == null and orphans_after == orphans_before, "tipo errado: retorna null e não deixa nó órfão")
	var right := CombatUtils.instantiate_as(scene, DamageText)
	_check(right is DamageText, "tipo certo: devolve a instância")
	right.free()


## B58: inimigo removido sem enemy_died não trava a onda nem a contagem da fase.
func _test_vanished_enemy_does_not_softlock() -> void:
	print("\n-- B58: inimigo removido sem morrer --")
	var lm := LevelManager.new()
	lm.complete_delay = 600.0
	add_child(lm)
	var built := _build_wave_manager([2, 1, 0])
	var wm := built["wm"] as WaveManager
	var cleared: Array = [0]
	var on_cleared := func(_w: int, _t: int) -> void: cleared[0] += 1
	EventBus.wave_cleared.connect(on_cleared)

	wm._start_wave(0)
	await get_tree().process_frame  # o spawn é deferido: agora os inimigos estão na árvore
	var enemies: Array = []
	for id: int in wm._alive.keys():
		enemies.append(instance_from_id(id))
	_check(lm.get_remaining() == 2, "LevelManager contou os 2 inimigos da onda")
	(enemies[0] as Node).queue_free()  # some sem emitir enemy_died
	(enemies[1] as ChaserEnemy).take_damage(9999)  # morte normal
	for i in 3:
		await get_tree().process_frame
	_check(cleared[0] == 1, "onda concluída mesmo com 1 inimigo removido sem morrer")
	_check(lm.get_remaining() == 0, "LevelManager também descontou o inimigo removido")

	EventBus.wave_cleared.disconnect(on_cleared)
	_cleanup(wm)
	_cleanup(built["root"])
	_cleanup(lm)


## B60: timers de gameplay respeitam a pausa.
func _test_game_timer_respects_pause() -> void:
	print("\n-- B60: timer de jogo x pausa --")
	var fired: Array = [false]
	var timer := CombatUtils.game_timer(self, 0.01)
	timer.timeout.connect(func() -> void: fired[0] = true)
	get_tree().paused = true
	for i in 5:
		await get_tree().process_frame
	_check(not fired[0], "pausado: game_timer não dispara")
	get_tree().paused = false
	for i in 5:
		await get_tree().process_frame
	_check(fired[0], "despausado: game_timer dispara")
	var loose := Node.new()
	_check(CombatUtils.game_timer(loose, 1.0) == null, "contexto fora da árvore: game_timer retorna null")
	loose.free()
