class_name CombatUtils
extends RefCounted
## Funções utilitárias de combate: validação de atores, dano, spawn e conexões.

const GROUP_PLAYER: StringName = &"player"
const GROUP_ENEMY: StringName = &"enemy"
const GROUP_HURTBOX: StringName = &"hurtbox"
const GROUP_HITBOX: StringName = &"hitbox"

## Camadas de física (iguais às nomeadas em Project Settings).
const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 2
const LAYER_ENEMY: int = 3
const LAYER_PLAYER_HURTBOX: int = 4
const LAYER_ENEMY_HURTBOX: int = 5

## Profundidade máxima das varreduras recursivas da árvore de nós.
const MAX_TREE_DEPTH: int = 16

## True se o objeto existe e não foi liberado da memória.
static func is_valid(obj: Variant) -> bool:
	return is_instance_valid(obj)


## True se o objeto existe e ainda está na cena.
static func is_alive(obj: Variant) -> bool:
	if not is_valid(obj):
		return false
	if obj is Node:
		var node: Node = obj
		return node.is_inside_tree() and not node.is_queued_for_deletion()
	return true


## True se é o player vivo na árvore.
static func is_player(obj: Variant) -> bool:
	if not is_alive(obj) or not obj is Node:
		return false
	var node: Node = obj
	return node.is_in_group(GROUP_PLAYER)


## True se o ator reporta estar morto.
static func is_dead_actor(obj: Variant) -> bool:
	if not is_valid(obj):
		return true
	var o: Object = obj
	if o.has_method(&"esta_morto"):
		return o.call(&"esta_morto") == true
	if o.has_method(&"is_dead"):
		return o.call(&"is_dead") == true
	return false


## Alvo válido para perseguir e não está morto.
static func is_targetable(obj: Variant) -> bool:
	return is_alive(obj) and not is_dead_actor(obj)


## Primeiro Player vivo do grupo `player` (null se não houver).
static func get_player(context: Node) -> Node2D:
	if not is_valid(context) or not context.is_inside_tree():
		return null
	var player := context.get_tree().get_first_node_in_group(GROUP_PLAYER) as Node2D
	return player if is_targetable(player) else null


## Ator dono do nó.
static func get_actor(node: Node) -> Node:
	if not is_valid(node):
		return null
	var explicit: Variant = node.get(&"actor")
	if is_valid(explicit) and explicit is Node:
		var actor_node: Node = explicit
		return actor_node
	if node.owner != null:
		return node.owner
	return node.get_parent()

## True se o alvo expõe `take_damage` ou `tomar_dano`.
static func can_take_damage(target: Variant) -> bool:
	if not is_alive(target):
		return false
	var obj: Object = target
	return obj.has_method(&"take_damage") or obj.has_method(&"tomar_dano")


## API única de dano.
static func apply_damage(target: Variant, amount: int, source: Variant = null) -> bool:
	if amount <= 0 or not is_alive(target):
		return false
	var obj: Object = target
	if obj.has_method(&"take_damage"):
		return _accepted(obj.call(&"take_damage", amount, source))
	if obj.has_method(&"tomar_dano"):
		return _accepted(obj.call(&"tomar_dano", amount))
	return false


## Traduz o retorno de `take_damage`.
static func _accepted(result: Variant) -> bool:
	match typeof(result):
		TYPE_NIL:
			return true
		TYPE_BOOL:
			return result == true
		TYPE_INT, TYPE_FLOAT:
			return result > 0
	return true

## Nó onde projéteis/efeitos devem ser instanciados.
static func get_spawn_parent(context: Node) -> Node:
	if not is_valid(context) or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	if tree.current_scene != null:
		return tree.current_scene
	return tree.root


## Cria a cena na posição pedida e põe na fase.
static func spawn(scene: PackedScene, context: Node, at: Vector2, required_type: Variant = null) -> Node:
	if scene == null:
		push_warning("CombatUtils.spawn: PackedScene nula (verifique o Inspector).")
		return null
	var parent := get_spawn_parent(context)
	if parent == null:
		push_warning("CombatUtils.spawn: contexto fora da árvore, spawn cancelado.")
		return null

	var instance := instantiate_as(scene, required_type)
	if instance == null:
		return null
	if instance is Node2D:
		var local_pos := at
		if parent is CanvasItem:
			local_pos = (parent as CanvasItem).get_global_transform().affine_inverse() * at
		(instance as Node2D).position = local_pos
	_add_child_deferred.call_deferred(parent, instance)
	return instance


## Instancia `scene` SEM adicioná-la à árvore (valida o tipo da raiz, se pedido).
static func instantiate_as(scene: PackedScene, required_type: Variant = null) -> Node:
	if scene == null:
		push_warning("CombatUtils.instantiate_as: PackedScene nula (verifique o Inspector).")
		return null
	var instance := scene.instantiate()
	if instance == null:
		return null
	if required_type != null and not is_instance_of(instance, required_type):
		push_warning("CombatUtils: a raiz de '%s' não tem o tipo/script esperado." % scene.resource_path)
		instance.free()
		return null
	return instance


## Adiciona o filho ao pai.
static func _add_child_deferred(parent: Variant, instance: Variant) -> void:
	# Parâmetros Variant de propósito: com tipo Node, o GDScript rejeitaria a
	# chamada ANTES do corpo quando o nó já foi liberado, e esta checagem nunca executaria.
	if not is_instance_valid(instance):
		return
	var child: Node = instance
	if is_alive(parent):
		var parent_node: Node = parent
		parent_node.add_child(child)
	else:
		child.free()


## Procura parede no trecho `from` -> `to`.
static func trace_wall(context: Node2D, from: Vector2, to: Vector2, mask: int) -> Dictionary:
	if not is_alive(context) or from.is_equal_approx(to):
		return {}
	var query := PhysicsRayQueryParameters2D.create(from, to, mask)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return context.get_world_2d().direct_space_state.intersect_ray(query)


## Anda `step` a partir da posição atual e para na primeira parede do trecho. True se bateu.
## `margin` alonga o raio à frente (ex.: raio do projétil) para parar com a borda na parede.
static func move_until_wall(body: Node2D, step: Vector2, mask: int, margin: float = 0.0) -> bool:
	var origin: Vector2 = body.global_position
	var heading: Vector2 = step.normalized()
	var wall: Dictionary = trace_wall(body, origin, origin + step + heading * margin, mask)
	if not wall.is_empty():
		var travelled: float = origin.distance_to(wall["position"] as Vector2) - margin
		body.global_position = origin + heading * maxf(travelled, 0.0)
		return true
	body.global_position = origin + step
	return false


# --- Árvore de nós (recursivo) ---

## Varre os descendentes de `root` e devolve os nós aceitos por `predicate` (Callable(Node) -> bool).
static func find_descendants(root: Node, predicate: Callable, max_depth: int = MAX_TREE_DEPTH) -> Array[Node]:
	var found: Array[Node] = []
	_collect_descendants(root, predicate, max_depth, found)
	return found


## Recursão de find_descendants: para ao esgotar `depth_left` ou ao chegar numa folha.
static func _collect_descendants(node: Node, predicate: Callable, depth_left: int, out: Array[Node]) -> void:
	if depth_left < 0 or not is_valid(node):
		return
	for child: Node in node.get_children():
		if predicate.call(child):
			out.append(child)
		_collect_descendants(child, predicate, depth_left - 1, out)


## Valor de uma propriedade da raiz gravada na cena (sem instanciá-la) ou `fallback`.
static func get_scene_root_property(scene: PackedScene, property: StringName, fallback: Variant) -> Variant:
	if scene == null:
		return fallback
	var state: SceneState = scene.get_state()
	for i: int in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == property:
			return state.get_node_property_value(0, i)
	return fallback


# --- Sprites ---

## Espelha o sprite mantendo o conteúdo centralizado (`base_offset_x` = offset sem espelho).
static func set_sprite_flip(sprite: Sprite2D, flipped: bool, base_offset_x: float) -> void:
	sprite.flip_h = flipped
	sprite.offset.x = -base_offset_x if flipped else base_offset_x


## Pisca o sprite em `color` e volta ao normal; devolve o Tween para cancelar com kill_flash().
static func flash_sprite(sprite: CanvasItem, previous: Tween, color: Color, duration: float,
		while_paused: bool = false) -> Tween:
	kill_flash(sprite, previous)
	if not is_valid(sprite):
		return null
	sprite.self_modulate = color
	var tween: Tween = sprite.create_tween()
	if while_paused:
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # o dano do quiz chega com o jogo pausado
	tween.tween_property(sprite, ^"self_modulate", Color.WHITE, duration)
	return tween


## Corta o pisca e devolve a cor normal.
static func kill_flash(sprite: CanvasItem, tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
	if is_valid(sprite):
		sprite.self_modulate = Color.WHITE


# --- Sinais e timers ---

## Timer de jogo: respeita a pausa e some junto com o contexto.
static func game_timer(context: Node, seconds: float) -> SceneTreeTimer:
	if not is_alive(context):
		return null
	return context.get_tree().create_timer(maxf(seconds, 0.0), false)


## Conecta só se ainda não estiver conectado.
static func connect_once(sig: Signal, callable: Callable, flags: int = 0) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable, flags)


## Desconecta só se estiver conectado.
static func disconnect_if_connected(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


## Dá ao nó uma forma circular própria.
static func set_unique_circle_radius(shape_node: CollisionShape2D, radius: float) -> bool:
	if not is_valid(shape_node):
		return false
	var circle := shape_node.shape as CircleShape2D
	circle = CircleShape2D.new() if circle == null else circle.duplicate() as CircleShape2D
	circle.radius = maxf(radius, 0.0)
	shape_node.shape = circle
	return true


## Raio do círculo da forma ou `fallback` se a forma não for um círculo.
static func get_circle_radius(shape_node: CollisionShape2D, fallback: float) -> float:
	if is_valid(shape_node) and shape_node.shape is CircleShape2D:
		return (shape_node.shape as CircleShape2D).radius
	return fallback
