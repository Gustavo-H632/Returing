extends Node
## AUDITORIA DE ARQUITETURA (estática): guarda as regras de integração do projeto.
## Não roda o jogo: lê os scripts, carrega/instancia cada cena FORA da árvore
## (nenhum _ready é executado) e confere o que foi configurado no editor.
##
## O que reprova (FAIL):
##   1. Lint dos scripts de jogo (fora de tests/): get_node(), $Caminho, %NomeUnico,
##      NodePath("../"), find_child(), get_parent() fora dos fallbacks documentados,
##      troca de cena/quit fora do autoload Global, chamada direta a Global.*.
##   2. Slot @export de nó/cena VAZIO no Inspector (exceto os opcionais listados abaixo),
##      @export_file apontando para arquivo inexistente, Array exportado com item vazio.
##   3. Regra de camadas: Hitbox (layer 0 / mask 8 ou 16), Hurtbox (layer 8 ou 16 / mask 0),
##      corpos (Player 2, inimigos 4), sensores (layer 0 / mask 2), ataques sem layer própria.
##   4. Conexões feitas no painel Node › Signals apontando para sinal/método inexistente.
##   5. EventBus: sinal declarado e nunca emitido, escutado e nunca emitido, ou usado sem declarar.
##   6. Project Settings: ordem dos autoloads, grupos globais, nomes das camadas, ações de input,
##      Main Scene.
## Também imprime o GRAFO do EventBus (quem emite -> quem escuta) gerado do código real.
##
## COMO RODAR
##   Editor:   abra tests/audit/architecture_audit.tscn e aperte F6 (resultado no Output).
##   Terminal: godot --headless --path . res://tests/audit/architecture_audit.tscn
##             (código de saída 0 = nenhuma violação)
##
## Ao criar um script/cena nova, rode este teste: ele aponta o arquivo e a linha exata.
## Exceção justificada (ex.: get_node() de um AnimationNodeStateMachine, que é Resource):
## termine a linha com "# audit-ok: motivo".

const LINT_SKIP_DIRS: PackedStringArray = ["res://.godot", "res://tests", "res://addons"]
const SCENE_SKIP_DIRS: PackedStringArray = ["res://.godot", "res://tests/_probe", "res://addons"]

## Slots @export que podem ficar vazios por design ("Classe.propriedade").
## Classe = class_name do script ou de qualquer ancestral.
const OPTIONAL_EXPORTS: Dictionary = {
	"Player.anim_tree": "sem AnimationTree o Player roda sem animação",
	"TankEnemy.attack_range_area": "o alcance é calculado por distância",
	"TankEnemy.attack_range_shape": "idem",
	"TankEnemy.sprite": "só flash/fade visual",
	"ChaserEnemy.health": "criado por código se vazio",
	"ChaserEnemy.sprite": "só visual",
	"RangedEnemy.projectile_spawn_point": "usa a posição do inimigo",
	"RangedEnemy.body_collision": "só é desligado na morte",
	"RangedEnemy.animation_player": "sem animação 'death' o inimigo some na hora",
	"Hurtbox.health_component": "PlayerHurtbox/ChaserHurtbox entregam o dano ao actor",
	"Hitbox.source": "projéteis/armadilhas definem por código (atirador)",
	"DamageText.fonte": "usa a fonte padrão do tema",
	"DummyEnemy.timer_projetil": "criado por código se vazio",
	"DummyEnemy.timer_onda": "criado por código se vazio",
	"PainelDummy.dummy": "atribuído na cena que instancia o painel (arena)",
}
## Mais específico que OPTIONAL_EXPORTS: obrigatório nesta subclasse.
const REQUIRED_EXPORTS: PackedStringArray = [
	"TankHurtbox.health_component",
	"ShooterHurtbox.health_component",
]

const MASK_PLAYER_HURTBOX: int = 1 << (CombatUtils.LAYER_PLAYER_HURTBOX - 1)  # 8
const MASK_ENEMY_HURTBOX: int = 1 << (CombatUtils.LAYER_ENEMY_HURTBOX - 1)    # 16
const MASK_PLAYER: int = 1 << (CombatUtils.LAYER_PLAYER - 1)                  # 2
const MASK_ENEMY: int = 1 << (CombatUtils.LAYER_ENEMY - 1)                    # 4
const MASK_WORLD: int = 1 << (CombatUtils.LAYER_WORLD - 1)                    # 1

var _checks: int = 0
var _failures: int = 0
var _reported: Dictionary = {}  # evita repetir a mesma violação (subcenas instanciadas várias vezes)


func _ready() -> void:
	var scripts := _list_files("res://", "gd", LINT_SKIP_DIRS)
	var scenes := _list_files("res://", "tscn", SCENE_SKIP_DIRS)

	_section("1. Lint: nenhuma referência rígida por caminho (%d scripts)" % scripts.size())
	_lint_scripts(scripts)

	_section("2-4. Cenas: @export, camadas e conexões do editor (%d cenas)" % scenes.size())
	for path in scenes:
		_audit_scene(path)

	_section("5. EventBus: grafo emissor -> ouvinte")
	_audit_event_bus(scripts)

	_section("6. Project Settings")
	_audit_project_settings()

	print("\n==== AUDITORIA: %d checagens, %d violações ====" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


# --------------------------------------------------------------------------
# 1. Lint
# --------------------------------------------------------------------------

## [regex, mensagem, arquivos liberados]
func _lint_rules() -> Array:
	return [
		[r"\bget_node(_or_null)?\s*\(", "get_node(): use @export tipado", []],
		[r"\$[A-Za-z_\"%]", "$Caminho: use @export tipado", []],
		[r"(?<![\w\)\]\"'])%[A-Za-z_]\w*", "%NomeUnico: use @export tipado", []],
		[r"\bfind_child(ren)?\s*\(", "find_child(): use @export, grupo ou EventBus", []],
		[r"get_parent\s*\(\s*\)\s*\.\s*get_parent", "get_parent().get_parent(): use @export", []],
		[r"\bget_parent\s*\(", "get_parent() fora dos fallbacks documentados",
			["res://common/components/hurtbox.gd", "res://common/state_machine/base_state_machine.gd",
			"res://common/combat_utils.gd"]],
		[r"change_scene_to_(file|packed)|reload_current_scene|\.quit\s*\(",
			"navegação fora do Global: emita EventBus.*_requested", ["res://autoload/global.gd"]],
		[r"\bGlobal\s*\.", "chamada direta ao Global: emita um pedido no EventBus", ["res://autoload/global.gd"]],
		# v2.7: cast de instantiate() que falha deixa o nó órfão (B59).
		[r"\binstantiate\s*\(\s*\)\s+as\b", "instantiate() as Tipo: use CombatUtils.instantiate_as(cena, Tipo)",
			["res://common/combat_utils.gd"]],
		# v2.7: create_timer(t) ignora a pausa (process_always = true por padrão) (B60).
		[r"\bcreate_timer\s*\(\s*[^,()]+\)", "create_timer(t) ignora a pausa: use CombatUtils.game_timer(self, t)", []],
	]


func _lint_scripts(scripts: PackedStringArray) -> void:
	var rules: Array = []
	for r: Array in _lint_rules():
		var re := RegEx.new()
		if re.compile(r[0]) != OK:
			_check(false, "regex inválida no teste: " + r[0])
			continue
		rules.append([re, r[1], r[2]])
	var nodepath_up := RegEx.create_from_string(r"(\^|NodePath\s*\(\s*)\"\.\.")

	var violations := 0
	for path in scripts:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		var in_triple := [false]
		for i in lines.size():
			var raw: String = lines[i]
			var code := _strip_strings_and_comments(raw, in_triple)
			if raw.contains("# audit-ok"):
				continue  # exceção justificada na própria linha (ex.: get_node de um Resource)
			for rule: Array in rules:
				if path in (rule[2] as Array):
					continue
				if (rule[0] as RegEx).search(code) != null:
					violations += 1
					_fail_once("%s:%d  %s  ->  %s" % [path, i + 1, rule[1], raw.strip_edges()])
			if nodepath_up.search(_strip_comment_only(raw)) != null:
				violations += 1
				_fail_once("%s:%d  NodePath relativo ao pai: use @export  ->  %s" % [path, i + 1, raw.strip_edges()])
	_check(violations == 0, "scripts de jogo sem referência rígida por caminho (%d violações)" % violations)


## Troca o conteúdo de strings por "" e remove comentários (mantém a estrutura da linha).
func _strip_strings_and_comments(line: String, in_triple: Array) -> String:
	var out := ""
	var i := 0
	var quote := ""
	if in_triple[0]:
		var end := line.find("\"\"\"")
		if end < 0:
			return ""
		in_triple[0] = false
		i = end + 3
	while i < line.length():
		var c := line[i]
		if quote.is_empty():
			if line.substr(i, 3) == "\"\"\"":
				var close := line.find("\"\"\"", i + 3)
				out += "\"\""
				if close < 0:
					in_triple[0] = true
					return out
				i = close + 3
				continue
			if c == "#":
				break
			if c == "\"" or c == "'":
				quote = c
				out += c
			else:
				out += c
		else:
			if c == "\\":
				i += 2
				continue
			if c == quote:
				out += c
				quote = ""
		i += 1
	return out


func _strip_comment_only(line: String) -> String:
	var q := ""
	for i in line.length():
		var c := line[i]
		if q.is_empty():
			if c == "#":
				return line.substr(0, i)
			if c == "\"" or c == "'":
				q = c
		elif c == q and (i == 0 or line[i - 1] != "\\"):
			q = ""
	return line


# --------------------------------------------------------------------------
# 2-4. Cenas
# --------------------------------------------------------------------------

func _audit_scene(path: String) -> void:
	var packed := load(path) as PackedScene
	if packed == null or not packed.can_instantiate():
		_check(false, "carrega e instancia: " + path)
		return
	var root := packed.instantiate()
	if root == null:
		_check(false, "instancia: " + path)
		return
	var before := _failures
	for node in _all_nodes(root):
		_audit_exports(path, root, node)
		_audit_collision(path, root, node)
	_audit_editor_connections(path, packed, root)
	_audit_scene_uids(path)
	root.free()
	_check(_failures == before, "cena OK: " + path)


## v2.7: cena sem `uid` no cabeçalho ou ext_resource só por caminho quebra ao mover/renomear
## arquivos fora do editor ("Missing dependencies"). Regressão de B47 (B64).
func _audit_scene_uids(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	var first_line := text.get_slice("\n", 0)
	if not first_line.contains("uid=\""):
		_fail_once("%s: cabeçalho [gd_scene] sem uid (abra e salve a cena no editor)" % path)
	for line in text.split("\n"):
		if line.begins_with("[ext_resource") and not line.contains(" uid=\""):
			_fail_once("%s: ext_resource sem uid -> %s" % [path, line.get_slice("path=\"", 1).get_slice("\"", 0)])


func _audit_exports(scene_path: String, root: Node, node: Node) -> void:
	var script := node.get_script() as Script
	if script == null:
		return
	var chain := _class_chain(script)
	for p: Dictionary in node.get_property_list():
		var usage: int = p.usage
		if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (usage & PROPERTY_USAGE_EDITOR):
			continue
		var prop: String = p.name
		var value: Variant = node.get(prop)
		var where := "%s  %s.%s" % [scene_path, _rel(root, node), prop]
		match int(p.type):
			TYPE_OBJECT:
				if value == null and _is_required(chain, prop):
					_fail_once("%s  slot @export vazio (arraste no Inspector; tipo %s)" % [where, p.hint_string])
			TYPE_STRING:
				if int(p.hint) == PROPERTY_HINT_FILE and not str(value).is_empty() \
						and not ResourceLoader.exists(str(value)):
					_fail_once("%s  @export_file aponta para '%s', que não existe" % [where, value])
			TYPE_ARRAY:
				for item: Variant in (value as Array):
					if item == null:
						_fail_once("%s  Array exportado com item vazio" % where)
						break


func _is_required(chain: PackedStringArray, prop: String) -> bool:
	for cls in chain:  # do mais específico para o mais genérico
		var key := "%s.%s" % [cls, prop]
		if key in REQUIRED_EXPORTS:
			return true
		if OPTIONAL_EXPORTS.has(key):
			return false
	return true


func _audit_collision(scene_path: String, root: Node, node: Node) -> void:
	if not node is CollisionObject2D:
		return
	var co := node as CollisionObject2D
	var L := co.collision_layer
	var M := co.collision_mask
	var where := "%s  %s (layer %d / mask %d)" % [scene_path, _rel(root, node), L, M]

	if node is Hurtbox:
		var want := MASK_PLAYER_HURTBOX if node is PlayerHurtbox else MASK_ENEMY_HURTBOX
		if L != want or M != 0:
			_fail_once("%s  Hurtbox deve ser layer %d / mask 0" % [where, want])
		return
	if node is Hitbox:
		if L != 0 or M == 0 or (M & ~(MASK_PLAYER_HURTBOX | MASK_ENEMY_HURTBOX)) != 0:
			_fail_once("%s  Hitbox deve ser layer 0 / mask 8 (ataca Player) ou 16 (ataca inimigo)" % where)
		return
	# Áreas comuns: layer de hurtbox é exclusiva das Hurtboxes.
	if node is Area2D and (L & (MASK_PLAYER_HURTBOX | MASK_ENEMY_HURTBOX)) != 0:
		_fail_once("%s  Area2D sem script Hurtbox usando a camada de hurtbox" % where)

	if node is Player:
		var pl := node as Player
		if (L & MASK_PLAYER) == 0 or (M & MASK_WORLD) == 0:
			_fail_once("%s  Player deve estar na layer 2 e colidir com o Mundo (mask 1)" % where)
		if pl.melee_hitbox != null and (pl.melee_hitbox.collision_layer != 0 or pl.melee_hitbox.collision_mask != MASK_ENEMY_HURTBOX):
			_fail_once("%s  MeleeHitbox do Player deve ser layer 0 / mask 16" % where)
	elif node is TankEnemy or node is ChaserEnemy or node is RangedEnemy:
		if L != MASK_ENEMY:
			_fail_once("%s  corpo de inimigo deve ser layer 4" % where)
		for sensor_prop: StringName in [&"detection_area", &"attack_range", &"attack_range_area", &"melee_range_area"]:
			var sensor := node.get(sensor_prop) as Area2D
			if sensor != null and (sensor.collision_layer != 0 or sensor.collision_mask != MASK_PLAYER):
				_fail_once("%s  sensor '%s' deve ser layer 0 / mask 2" % [where, sensor_prop])
	elif node is PlayerProjectile:
		if L != 0 or (M & MASK_ENEMY_HURTBOX) == 0 or (M & MASK_PLAYER_HURTBOX) != 0:
			_fail_once("%s  PlayerProjectile deve ser layer 0 / mask 1+16" % where)
	elif node is EnergyWave or node is EnemyProjectile or node is DummyProjetil \
			or node is DummyOndaChoque or node is DummyEspadaAtaque:
		if L != 0:
			_fail_once("%s  ataque não pode ter layer própria (layer 0)" % where)
		if (M & MASK_ENEMY_HURTBOX) != 0:
			_fail_once("%s  ataque inimigo não pode mirar hurtbox de inimigo (mask 16)" % where)


func _audit_editor_connections(scene_path: String, packed: PackedScene, root: Node) -> void:
	var state := packed.get_state()
	for i in state.get_connection_count():
		var src := root.get_node_or_null(state.get_connection_source(i))  # busca por caminho: permitida SÓ em teste
		var dst := root.get_node_or_null(state.get_connection_target(i))
		var sig := state.get_connection_signal(i)
		var method := state.get_connection_method(i)
		var desc := "%s  conexão do editor %s.%s -> %s.%s()" % [scene_path, state.get_connection_source(i), sig,
			state.get_connection_target(i), method]
		if src == null or dst == null:
			_fail_once(desc + ": nó inexistente")
		elif not src.has_signal(sig):
			_fail_once(desc + ": sinal inexistente")
		elif not dst.has_method(method):
			_fail_once(desc + ": método inexistente")


# --------------------------------------------------------------------------
# 5. EventBus
# --------------------------------------------------------------------------

func _audit_event_bus(scripts: PackedStringArray) -> void:
	var declared: Dictionary = {}
	for s: Dictionary in EventBus.get_signal_list():
		declared[String(s.name)] = true
	# Sinais herdados de Node (ready, tree_entered...) não são do barramento.
	for s: Dictionary in ClassDB.class_get_signal_list(&"Node"):
		declared.erase(String(s.name))

	var re_emit := RegEx.create_from_string(r"EventBus\.(\w+)\.emit\b")
	var re_conn := RegEx.create_from_string(r"EventBus\.(\w+)\.connect\b|connect_once\(\s*EventBus\.(\w+)")
	var emitters: Dictionary = {}   # sinal -> PackedStringArray de arquivos
	var listeners: Dictionary = {}
	for path in scripts:
		if path == "res://autoload/event_bus.gd":
			continue
		var in_triple := [false]
		for raw in FileAccess.get_file_as_string(path).split("\n"):
			var code := _strip_strings_and_comments(raw, in_triple)
			for m in re_emit.search_all(code):
				_add_to(emitters, m.get_string(1), path)
			for m in re_conn.search_all(code):
				_add_to(listeners, m.get_string(1) if not m.get_string(1).is_empty() else m.get_string(2), path)

	var names := declared.keys()
	names.sort()
	for sig: String in names:
		var e: PackedStringArray = emitters.get(sig, PackedStringArray())
		var l: PackedStringArray = listeners.get(sig, PackedStringArray())
		print("      %-28s %s  ->  %s" % [sig, _short(e), _short(l) if not l.is_empty() else "(livre: ninguém escuta ainda)"])
		if e.is_empty():
			_fail_once("EventBus.%s é declarado mas ninguém emite (remova ou emita)" % sig)
	for sig: String in emitters:
		if not declared.has(sig):
			_fail_once("EventBus.%s é emitido mas não está declarado em event_bus.gd" % sig)
	for sig: String in listeners:
		if not declared.has(sig):
			_fail_once("EventBus.%s é escutado mas não está declarado em event_bus.gd" % sig)
		elif not emitters.has(sig):
			_fail_once("EventBus.%s é escutado mas ninguém emite (ouvinte morto)" % sig)
	_check(true, "grafo do EventBus gerado (%d sinais)" % names.size())


func _add_to(dict: Dictionary, key: String, path: String) -> void:
	var arr: PackedStringArray = dict.get(key, PackedStringArray())
	var short := path.get_file().get_basename()
	if not short in arr:
		arr.append(short)
	dict[key] = arr


func _short(arr: PackedStringArray) -> String:
	return ", ".join(arr) if not arr.is_empty() else "(ninguém)"


# --------------------------------------------------------------------------
# 6. Project Settings
# --------------------------------------------------------------------------

func _audit_project_settings() -> void:
	var autoloads: PackedStringArray = []
	for p: Dictionary in ProjectSettings.get_property_list():
		var n: String = p.name
		if n.begins_with("autoload/"):
			autoloads.append(n.trim_prefix("autoload/"))
	var i_bus := autoloads.find("EventBus")
	var i_global := autoloads.find("Global")
	_check(i_bus >= 0 and i_global >= 0 and i_bus < i_global,
		"autoloads na ordem EventBus -> Global (atual: %s)" % ", ".join(autoloads))

	for g: StringName in [CombatUtils.GROUP_PLAYER, CombatUtils.GROUP_ENEMY, CombatUtils.GROUP_HURTBOX, CombatUtils.GROUP_HITBOX]:
		_check(ProjectSettings.has_setting("global_group/%s" % g), "grupo global '%s' declarado" % g)

	var layer_names := {
		CombatUtils.LAYER_WORLD: "Mundo", CombatUtils.LAYER_PLAYER: "Player", CombatUtils.LAYER_ENEMY: "Inimigo",
		CombatUtils.LAYER_PLAYER_HURTBOX: "hurtboxes_player", CombatUtils.LAYER_ENEMY_HURTBOX: "hurtbox_inimigos",
	}
	for idx: int in layer_names:
		var got := str(ProjectSettings.get_setting("layer_names/2d_physics/layer_%d" % idx, ""))
		_check(got == layer_names[idx], "camada 2D %d = '%s' (atual '%s')" % [idx, layer_names[idx], got])

	for action: StringName in [Player.ACTION_LEFT, Player.ACTION_RIGHT, Player.ACTION_UP, Player.ACTION_DOWN,
			Player.ACTION_DASH, Player.ACTION_MELEE, Player.ACTION_SHOOT]:
		_check(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(),
			"ação de input '%s' existe e tem tecla" % action)

	var main := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	_check(not main.is_empty() and ResourceLoader.exists(main), "Main Scene configurada e existente (%s)" % main)


# --------------------------------------------------------------------------
# Utilitários
# --------------------------------------------------------------------------

func _class_chain(script: Script) -> PackedStringArray:
	var out: PackedStringArray = []
	var s := script
	while s != null:
		var n := s.get_global_name()
		out.append(String(n) if n != &"" else s.resource_path.get_file().get_basename())
		s = s.get_base_script()
	return out


func _all_nodes(root: Node) -> Array[Node]:
	var out: Array[Node] = [root]
	var i := 0
	while i < out.size():
		for c in out[i].get_children():
			out.append(c)
		i += 1
	return out


func _rel(root: Node, node: Node) -> String:
	return String(root.name) if node == root else "%s/%s" % [root.name, root.get_path_to(node)]


func _list_files(dir_path: String, ext: String, skip: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = []
	for s in skip:
		if dir_path.trim_suffix("/") == s:
			return out
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.get_extension() == ext:
			out.append(dir_path.path_join(f))
	for d in dir.get_directories():
		if d.begins_with("."):
			continue
		out.append_array(_list_files(dir_path.path_join(d), ext, skip))
	return out


func _section(title: String) -> void:
	print("\n-- %s --" % title)


func _fail_once(msg: String) -> void:
	if _reported.has(msg):
		return
	_reported[msg] = true
	_check(false, msg)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("ok:   ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
		push_error("FAIL: " + label)
