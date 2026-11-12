class_name EquilibrioDump
extends RefCounted
## Fotografa tudo o que define a dificuldade do jogo (vida, dano, velocidade, alcance, cooldowns, durações de
## animação, janelas e formas de hitbox, tabelas de waves) num dicionário estável, para comparar com
## `testes/equilibrio_base.json` (gerado ANTES das mudanças desta rodada).
##
## É genérico de propósito: em vez de uma lista escrita à mão (que poderia esquecer um número), varre
## as cenas e scripts de jogador, inimigos, chefão, armas e habilidades e guarda todo valor numérico
## exportado, toda constante numérica, toda forma de colisão, todo Timer e a duração de cada animação.

## Pastas cujas cenas (.tscn) e recursos (.tres) entram na fotografia.
const PASTAS_CENAS: Array[String] = [
	"res://characters", "res://enemies", "res://weapons", "res://abilities/effects", "res://abilities/data",
]
## Pastas/arquivos cujas constantes de script entram na fotografia.
const PASTAS_SCRIPTS: Array[String] = [
	"res://characters", "res://enemies", "res://weapons", "res://abilities/core", "res://abilities/effects",
	"res://common/combat", "res://levels",
]
const SCRIPTS_AVULSOS: Array[String] = [
	"res://Scenes/Defesa/defense_level.gd", "res://Scenes/Defesa/defense_portal.gd",
	"res://Scenes/Defesa/defense_wave_table.gd", "res://Scenes/Tutorial/tutorial_droid.gd",
]
## Fases com WaveManager (ondas escritas como listas de cenas).
const FASES_COM_ONDAS: Array[String] = ["res://Scenes/Fase1/fase_1.tscn", "res://Scenes/Fase3/fase_3.tscn"]
const TABELA_DEFESA: String = "res://Scenes/Defesa/wave_table.tres"
const WAVES_DEFESA_AMOSTRA: int = 12  # Quantas waves da defesa (que cresce sem fim) entram na fotografia.


## Fotografia completa. Chaves: "cenas", "constantes", "ondas".
static func coletar() -> Dictionary:
	var cenas: Dictionary = {}
	for pasta: String in PASTAS_CENAS:
		for caminho: String in _listar(pasta, ["tscn", "tres"]):
			if caminho.ends_with(".tscn"):
				cenas[caminho] = _cena(caminho)
			else:
				cenas[caminho] = _recurso(load(caminho))
	var constantes: Dictionary = {}
	var scripts: Array[String] = []
	for pasta: String in PASTAS_SCRIPTS:
		scripts.append_array(_listar(pasta, ["gd"]))
	scripts.append_array(SCRIPTS_AVULSOS)
	for caminho: String in scripts:
		var mapa: Dictionary = _constantes(caminho)
		if not mapa.is_empty():
			constantes[caminho] = mapa
	return {"cenas": cenas, "constantes": constantes, "ondas": _ondas()}


## Ondas ORIGINAIS (como escritas nas cenas/recursos, antes de qualquer multiplicador).
static func _ondas() -> Dictionary:
	var out: Dictionary = {}
	for caminho: String in FASES_COM_ONDAS:
		var raiz: Node = (load(caminho) as PackedScene).instantiate()
		for no: Node in _todos(raiz):
			if no is WaveManager:
				var lista: Array = []
				for onda: Array in [no.wave_1_enemies, no.wave_2_enemies, no.wave_3_enemies]:
					lista.append(contar_cenas(onda))
				out["%s::%s" % [caminho, raiz.get_path_to(no)]] = {
					"ondas": lista, "boss_kind": String(no.boss_kind),
					"first_wave_delay": no.first_wave_delay, "between_waves_delay": no.between_waves_delay,
					"clear_heal_amount": no.clear_heal_amount, "min_player_distance": no.min_player_distance,
				}
		raiz.free()
	var tabela: DefenseWaveTable = load(TABELA_DEFESA)
	var defesa: Array = []
	for n: int in range(1, WAVES_DEFESA_AMOSTRA + 1):
		defesa.append(tabela.get_original_counts(n) if tabela.has_method(&"get_original_counts") else tabela.get_counts(n))
	out[TABELA_DEFESA] = {"ondas": defesa, "max_active": tabela.max_active}
	return out


## Lista de cenas -> lista ordenada [[caminho, quantidade], ...] na ordem da primeira aparição.
static func contar_cenas(onda: Array) -> Array:
	var ordem: Array = []
	var total: Dictionary = {}
	for cena: PackedScene in onda:
		if cena == null:
			continue
		if not total.has(cena.resource_path):
			ordem.append(cena.resource_path)
			total[cena.resource_path] = 0
		total[cena.resource_path] += 1
	var out: Array = []
	for caminho: String in ordem:
		out.append([caminho, total[caminho]])
	return out


static func _cena(caminho: String) -> Dictionary:
	var out: Dictionary = {}
	var raiz: Node = (load(caminho) as PackedScene).instantiate()
	for no: Node in _todos(raiz):
		var dados: Dictionary = _no(no)
		if not dados.is_empty():
			out[String(raiz.get_path_to(no))] = dados
	raiz.free()
	return out


static func _no(no: Node) -> Dictionary:
	var out: Dictionary = _exportados(no)
	if no is CollisionShape2D:
		out["pos"] = _valor(no.position)
		out["rot"] = _valor(no.rotation)
		out["escala"] = _valor(no.scale)
		out["desligada"] = no.disabled
		out["forma"] = _forma(no.shape)
	elif no is CollisionPolygon2D:
		out["pos"] = _valor(no.position)
		out["poligono"] = _valor(no.polygon)
		out["desligada"] = no.disabled
	elif no is CollisionObject2D:
		out["pos"] = _valor(no.position)
		out["escala"] = _valor(no.scale)
		out["camada"] = no.collision_layer
		out["mascara"] = no.collision_mask
		if no is Area2D:
			out["monitoring"] = no.monitoring
			out["monitorable"] = no.monitorable
	elif no is Timer:
		out["wait_time"] = _valor(no.wait_time)
		out["one_shot"] = no.one_shot
		out["autostart"] = no.autostart
	elif no is AnimatedSprite2D and no.sprite_frames != null:
		out["animacoes"] = _sprite_frames(no.sprite_frames, no.speed_scale)
	elif no is AnimationPlayer:
		var anims: Dictionary = {}
		for nome: StringName in no.get_animation_list():
			var a: Animation = no.get_animation(nome)
			anims[String(nome)] = {"duracao": _valor(a.length / maxf(no.speed_scale, 0.0001)), "loop": a.loop_mode != Animation.LOOP_NONE}
		out["animacoes"] = anims
	elif no is RayCast2D:
		out["alvo"] = _valor(no.target_position)
	elif no is NavigationAgent2D:
		out["raio"] = _valor(no.radius)
		out["distancia_alvo"] = _valor(no.target_desired_distance)
	return out


## Duração total (s) de cada animação: é o que importa para o equilíbrio (o número de quadros pode mudar
## quando um sprite ganha quadros, desde que a duração total fique igual).
static func _sprite_frames(frames: SpriteFrames, escala: float) -> Dictionary:
	var out: Dictionary = {}
	for nome: StringName in frames.get_animation_names():
		var soma: float = 0.0
		for i: int in frames.get_frame_count(nome):
			soma += frames.get_frame_duration(nome, i)
		var fps: float = frames.get_animation_speed(nome) * escala
		out[String(nome)] = {"duracao": _valor(soma / fps if fps > 0.0 else 0.0), "loop": frames.get_animation_loop(nome)}
	return out


static func _forma(forma: Shape2D) -> Dictionary:
	if forma == null:
		return {}
	var out: Dictionary = {"tipo": forma.get_class()}
	for prop: String in ["radius", "height", "size", "a", "b", "points", "length", "normal", "distance"]:
		if prop in forma:
			out[prop] = _valor(forma.get(prop))
	return out


## Variáveis exportadas do script (as que o Inspector grava) com valor numérico, lógico ou vetorial.
static func _exportados(objeto: Object) -> Dictionary:
	var out: Dictionary = {}
	if objeto.get_script() == null:
		return out
	const USO: int = PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_STORAGE
	for prop: Dictionary in objeto.get_property_list():
		if (int(prop["usage"]) & USO) != USO:
			continue
		var valor: Variant = objeto.get(prop["name"])
		if _numerico(valor):
			out[String(prop["name"])] = _valor(valor)
		elif valor is Resource and not (valor is Texture2D or valor is AudioStream or valor is PackedScene or valor is Script or valor is Font or valor is SpriteFrames or valor is Material):
			var interno: Dictionary = _recurso(valor)
			if not interno.is_empty():
				out[String(prop["name"])] = interno
		elif valor is Array:
			var lista: Array = []
			var util: bool = false
			for item: Variant in valor:
				if _numerico(item):
					lista.append(_valor(item))
					util = true
				elif item is Resource and not (item is PackedScene or item is Texture2D or item is AudioStream):
					lista.append(_recurso(item))
					util = true
				elif item is PackedScene:
					lista.append(item.resource_path)
					util = true
			if util:
				out[String(prop["name"])] = lista
	return out


static func _recurso(recurso: Resource) -> Dictionary:
	if recurso == null:
		return {}
	return _exportados(recurso)


static func _constantes(caminho: String) -> Dictionary:
	var out: Dictionary = {}
	var script: GDScript = load(caminho) as GDScript
	if script == null:
		return out
	var mapa: Dictionary = script.get_script_constant_map()
	for nome: Variant in mapa:
		var valor: Variant = mapa[nome]
		if _numerico(valor):
			out[String(nome)] = _valor(valor)
		elif valor is Array or valor is Dictionary:
			var texto: Variant = _valor(valor)
			if texto != null:
				out[String(nome)] = texto
	return out


static func _numerico(valor: Variant) -> bool:
	return typeof(valor) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_RECT2,
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_FLOAT64_ARRAY,
		TYPE_PACKED_INT64_ARRAY]


## Converte para algo que o JSON guarda sem perder a comparação (floats arredondados em 5 casas).
static func _valor(valor: Variant) -> Variant:
	match typeof(valor):
		TYPE_BOOL, TYPE_INT:
			return valor
		TYPE_FLOAT:
			return snappedf(valor, 0.00001)
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [snappedf(valor.x, 0.00001), snappedf(valor.y, 0.00001)]
		TYPE_RECT2:
			return [_valor(valor.position), _valor(valor.size)]
		TYPE_STRING, TYPE_STRING_NAME:
			return String(valor)
		TYPE_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, \
		TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_INT64_ARRAY:
			var lista: Array = []
			for item: Variant in valor:
				var v: Variant = _valor(item)
				if v == null:
					return null
				lista.append(v)
			return lista
		TYPE_DICTIONARY:
			var d: Dictionary = {}
			for chave: Variant in valor:
				var v: Variant = _valor(valor[chave])
				if v == null:
					return null
				d[str(chave)] = v
			return d
	return null


static func _todos(raiz: Node) -> Array[Node]:
	var out: Array[Node] = [raiz]
	var i: int = 0
	while i < out.size():
		out.append_array(out[i].get_children(true))
		i += 1
	return out


static func _listar(pasta: String, extensoes: Array) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(pasta)
	if dir == null:
		return out
	var nomes: PackedStringArray = dir.get_files()
	nomes.sort()
	for nome: String in nomes:
		var limpo: String = nome.trim_suffix(".remap")
		if limpo.get_extension() in extensoes:
			out.append(pasta.path_join(limpo))
	var subs: PackedStringArray = dir.get_directories()
	subs.sort()
	for sub: String in subs:
		out.append_array(_listar(pasta.path_join(sub), extensoes))
	return out


## Lista as diferenças entre duas fotografias (caminho: base -> atual). `prefixo` é o caminho acumulado.
static func diferencas(base: Variant, atual: Variant, prefixo: String = "") -> Array[String]:
	var out: Array[String] = []
	if base is Dictionary and atual is Dictionary:
		var chaves: Dictionary = {}
		for c: Variant in base:
			chaves[c] = true
		for c: Variant in atual:
			chaves[c] = true
		var ordenadas: Array = chaves.keys()
		ordenadas.sort()
		for c: Variant in ordenadas:
			var caminho: String = "%s/%s" % [prefixo, c]
			if not atual.has(c):
				out.append("%s: sumiu (base = %s)" % [caminho, JSON.stringify(base[c])])
			elif not base.has(c):
				out.append("%s: novo (atual = %s)" % [caminho, JSON.stringify(atual[c])])
			else:
				out.append_array(diferencas(base[c], atual[c], caminho))
	elif base is Array and atual is Array and base.size() == atual.size():
		for i: int in base.size():
			out.append_array(diferencas(base[i], atual[i], "%s[%d]" % [prefixo, i]))
	elif not _igual(base, atual):
		out.append("%s: %s -> %s" % [prefixo, JSON.stringify(base), JSON.stringify(atual)])
	return out


static func _igual(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) < 0.00002
	return typeof(a) == typeof(b) and a == b
