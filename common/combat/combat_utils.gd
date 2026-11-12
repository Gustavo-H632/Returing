class_name CombatUtils
extends RefCounted
## Funções utilitárias de combate: validação de atores, dano, spawn e conexões.

# Nomes dos grupos usados para achar jogador, inimigos e áreas de dano.
const GROUP_PLAYER: StringName = &"player"
const GROUP_ENEMY: StringName = &"enemy"
const GROUP_HURTBOX: StringName = &"hurtbox"
const GROUP_HITBOX: StringName = &"hitbox"
## Corpos que os inimigos também podem atacar além do jogador (ex.: o portal da fase de defesa).
const GROUP_ENEMY_TARGET: StringName = &"enemy_target"

## Camadas de física (iguais às nomeadas em Project Settings).
const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 2
const LAYER_ENEMY: int = 3
const LAYER_PLAYER_HURTBOX: int = 4
const LAYER_ENEMY_HURTBOX: int = 5

## Profundidade máxima das varreduras recursivas da árvore de nós.
const MAX_TREE_DEPTH: int = 16

## True se o objeto existe e não foi liberado da memória.
## Confere se o objeto ainda existe na memória. Evita bugs ao acessar algum objeto que já foi destruído.
static func is_valid(obj: Variant) -> bool:
	# `is_instance_valid` devolve false para nulo e para objetos já liberados.
	return is_instance_valid(obj)


## True se o objeto existe e ainda está na cena.
## Vai além do is_valid: o nó também precisa estar dentro da cena e não pode estar marcado para ser removido.
static func is_alive(obj: Variant) -> bool:
	if not is_valid(obj):  # Se nem existe, não está vivo.
		return false
	if obj is Node:  # Só nós têm "árvore"; outros objetos contam como vivos se existem.
		var node: Node = obj
		# Dentro da cena e sem remoção agendada.
		return node.is_inside_tree() and not node.is_queued_for_deletion()
	return true


## True se é o player vivo na árvore.
## Confere se o objeto é o jogador vivo (está na árvore e no grupo "player").
static func is_player(obj: Variant) -> bool:
	if not is_alive(obj) or not obj is Node:  # Morto, liberado ou que não é nó: não é o jogador.
		return false
	var node: Node = obj
	return node.is_in_group(GROUP_PLAYER)  # O jogador é identificado pelo grupo.


## True se é o player vivo OU outro alvo dos inimigos (grupo `enemy_target`, ex.: o portal da defesa).
## Os sensores de alcance dos inimigos usam esta checagem, então o mesmo código de ataque serve aos dois alvos.
static func is_enemy_target(obj: Variant) -> bool:
	if is_player(obj):
		return true
	return is_alive(obj) and obj is Node and (obj as Node).is_in_group(GROUP_ENEMY_TARGET)


## True se o ator reporta estar morto.
## Pergunta ao próprio ator se ele morreu, aceitando os dois nomes de método usados no projeto.
static func is_dead_actor(obj: Variant) -> bool:
	if not is_valid(obj):  # Objeto inexistente conta como morto.
		return true
	var o: Object = obj  # Trata o valor como Object para poder perguntar pelos métodos.
	if o.has_method(&"esta_morto"):  # Jogador (português): `esta_morto`.
		return o.call(&"esta_morto") == true
	if o.has_method(&"is_dead"):  # Inimigos e outros (inglês): `is_dead`.
		return o.call(&"is_dead") == true
	return false  # Sem nenhum dos métodos, assume que está vivo.


## Alvo válido para perseguir e não está morto.
## Diz se vale a pena mirar ou perseguir o objeto: ele precisa existir, estar na cena e não estar morto.
static func is_targetable(obj: Variant) -> bool:
	return is_alive(obj) and not is_dead_actor(obj)


## Primeiro Player vivo do grupo `player` (null se não houver).
## Procura o primeiro nó do grupo "player" que seja um alvo válido. Devolve null se não houver ou se o contexto estiver fora da árvore.
static func get_player(context: Node) -> Node2D:
	# Sem contexto na árvore não há como acessar o grupo.
	if not is_valid(context) or not context.is_inside_tree():
		return null
	# Primeiro nó do grupo, tratado como Node2D.
	var player := context.get_tree().get_first_node_in_group(GROUP_PLAYER) as Node2D
	return player if is_targetable(player) else null  # Só devolve se ainda for um alvo válido.


## Ator dono do nó.
## Descobre quem é o "dono" de um nó (ex.: de uma hurtbox sobe até o inimigo). Ordem: propriedade `actor`, depois `owner`, depois o pai.
static func get_actor(node: Node) -> Node:
	if not is_valid(node):  # Nó inexistente: sem dono.
		return null
	# Tenta a propriedade `actor`, que o nó pode ter definido de propósito.
	var explicit: Variant = node.get(&"actor")
	if is_valid(explicit) and explicit is Node:  # Só aceita se for um nó válido.
		var actor_node: Node = explicit
		return actor_node
	if node.owner != null:  # Sem `actor`, usa o nó raiz da cena onde ele foi criado.
		return node.owner
	return node.get_parent()  # Último recurso: o pai.

## True se o alvo expõe `take_damage` ou `tomar_dano`.
## Diz se o alvo sabe receber dano (tem `take_damage` ou `tomar_dano`).
static func can_take_damage(target: Variant) -> bool:
	if not is_alive(target):  # Alvo morto ou liberado não recebe dano.
		return false
	var obj: Object = target  # Trata como Object para consultar os métodos.
	return obj.has_method(&"take_damage") or obj.has_method(&"tomar_dano")


## API única de dano.
## Ponto único de dano do projeto: chama `take_damage` (inglês) ou `tomar_dano` (português) conforme o que o alvo tiver.
## Devolve true se o dano foi aceito (por exemplo, false se o alvo estava invulnerável).
static func apply_damage(target: Variant, amount: int, source: Variant = null) -> bool:
	if amount <= 0 or not is_alive(target):  # Dano zero ou negativo e alvos mortos são recusados.
		return false
	var obj: Object = target
	if obj.has_method(&"take_damage"):  # Padrão novo: recebe quantidade e origem.
		# Interpreta o retorno do alvo (bool, int ou nada).
		return _accepted(obj.call(&"take_damage", amount, source))
	if obj.has_method(&"tomar_dano"):  # Padrão do jogador: só recebe a quantidade.
		return _accepted(obj.call(&"tomar_dano", amount))
	return false  # Sem nenhum dos dois métodos, o dano não é aplicado.


## Traduz o retorno de `take_damage`.
## Normaliza o retorno de `take_damage`: nada = aceito, bool = o próprio valor, número = aceito se for maior que zero.
static func _accepted(result: Variant) -> bool:
	match typeof(result):  # Olha o tipo do valor devolvido.
		TYPE_NIL:
			return true  # Função sem retorno conta como aceita.
		TYPE_BOOL:
			return result == true  # Retorno booleano: usa como veio.
		TYPE_INT, TYPE_FLOAT:
			return result > 0  # Retorno numérico: positivo = dano aplicado.
	return true  # Qualquer outro tipo: considera aceito.

## Nó onde projéteis/efeitos devem ser instanciados.
## Escolhe onde projéteis e efeitos entram na árvore: a cena atual (ou a raiz, se não houver).
static func get_spawn_parent(context: Node) -> Node:
	# Contexto fora da árvore não tem onde spawnar.
	if not is_valid(context) or not context.is_inside_tree():
		return null
	var tree := context.get_tree()  # Árvore do jogo.
	if tree.current_scene != null:  # Preferência pela cena atual (a fase).
		return tree.current_scene
	return tree.root


## Cria a cena na posição pedida e põe na fase.
## Instancia a cena, converte a posição global para a local do pai e adiciona na fase (adiado até o fim do quadro).
static func spawn(scene: PackedScene, context: Node, at: Vector2, required_type: Variant = null) -> Node:
	if scene == null:  # Cena nula (esqueceu de arrastar no Inspector).
		push_warning("CombatUtils.spawn: PackedScene nula (verifique o Inspector).")
		return null
	var parent := get_spawn_parent(context)  # Pai onde o objeto será colocado.
	if parent == null:  # Sem pai, cancela.
		push_warning("CombatUtils.spawn: contexto fora da árvore, spawn cancelado.")
		return null

	# Cria a instância sem adicionar ainda (valida o tipo da raiz).
	var instance := instantiate_as(scene, required_type)
	if instance == null:  # Falhou ou tipo errado: cancela.
		return null
	if instance is Node2D:  # Só posiciona nós 2D.
		var local_pos := at
		if parent is CanvasItem:  # Corrige a posição se o pai estiver deslocado ou girado.
			local_pos = (parent as CanvasItem).get_global_transform().affine_inverse() * at
		(instance as Node2D).position = local_pos  # Posição local final.
	# Adicionar no meio da física causa erro: espera o fim do quadro.
	_add_child_deferred.call_deferred(parent, instance)
	return instance  # Devolve já a instância para o chamador configurar.


## Instancia `scene` SEM adicioná-la à árvore (valida o tipo da raiz, se pedido).
## Cria a instância da cena sem colocá-la na árvore. Se pedirem um tipo de raiz e a cena não bater, libera e devolve null.
static func instantiate_as(scene: PackedScene, required_type: Variant = null) -> Node:
	if scene == null:  # Cena nula: avisa e cancela.
		push_warning("CombatUtils.instantiate_as: PackedScene nula (verifique o Inspector).")
		return null
	var instance := scene.instantiate()  # Cria os nós da cena.
	if instance == null:
		return null
	# Confere o tipo/script da raiz.
	if required_type != null and not is_instance_of(instance, required_type):
		push_warning("CombatUtils: a raiz de '%s' não tem o tipo/script esperado." % scene.resource_path)
		instance.free()  # Tipo errado: libera da memória para não vazar.
		return null
	return instance


## Adiciona o filho ao pai.
## Adiciona o filho ao pai, mas só se os dois ainda existirem (o spawn foi adiado e algo pode ter sumido).
static func _add_child_deferred(parent: Variant, instance: Variant) -> void:
	# Parâmetros Variant de propósito: com tipo Node, o GDScript rejeitaria a
	# chamada ANTES do corpo quando o nó já foi liberado, e esta checagem nunca executaria.
	if not is_instance_valid(instance):  # Instância já liberada: nada a fazer.
		return
	var child: Node = instance
	if is_alive(parent):  # Se o pai sumiu, descarta o filho para não vazar memória.
		var parent_node: Node = parent
		parent_node.add_child(child)  # Adiciona o filho.
	else:
		child.free()  # Pai sumiu: libera o filho.


## Procura parede no trecho `from` -> `to`.
## Lança um raio de `from` até `to` procurando parede (só corpos, sem áreas). Devolve o resultado do raio ou um dicionário vazio.
static func trace_wall(context: Node2D, from: Vector2, to: Vector2, mask: int) -> Dictionary:
	# Sem contexto vivo ou com ponto inicial igual ao final não há trecho para testar.
	if not is_alive(context) or from.is_equal_approx(to):
		return {}
	# Cria a consulta de raio na máscara pedida.
	var query := PhysicsRayQueryParameters2D.create(from, to, mask)
	query.collide_with_areas = false  # Áreas não contam como parede.
	query.collide_with_bodies = true  # Só corpos (paredes do mapa).
	# Pede ao espaço de física o primeiro ponto de contato.
	return context.get_world_2d().direct_space_state.intersect_ray(query)


## Anda `step` a partir da posição atual e para na primeira parede do trecho. True se bateu.
## `margin` alonga o raio à frente (ex.: raio do projétil) para parar com a borda na parede.
## Move o corpo `step` pixels, mas para na primeira parede. Útil para projéteis rápidos que atravessariam uma parede fina em um só quadro.
static func move_until_wall(body: Node2D, step: Vector2, mask: int, margin: float = 0.0) -> bool:
	var origin: Vector2 = body.global_position  # Posição inicial.
	var heading: Vector2 = step.normalized()  # Direção do movimento.
	# Raio do ponto atual até o ponto final, com a margem.
	var wall: Dictionary = trace_wall(body, origin, origin + step + heading * margin, mask)
	if not wall.is_empty():  # Bateu em algo.
		# Distância até a parede, descontando a margem.
		var travelled: float = origin.distance_to(wall["position"] as Vector2) - margin
		# Para exatamente na parede (nunca anda para trás).
		body.global_position = origin + heading * maxf(travelled, 0.0)
		return true  # Avisa que bateu.
	body.global_position = origin + step  # Caminho livre: anda o passo todo.
	return false


## Confere o ponto onde um disparo nasce. `from` é o corpo de quem atira e `muzzle` é a boca da arma.
## A boca costuma ficar ~20 px à frente do corpo: com uma parede fina (1 tile = 16 px) encostada em
## quem atira, ela cai dentro ou atrás da parede, e o raio de `move_until_wall` (que começa dentro
## da forma e por isso não a enxerga) deixaria o tiro atravessar. Aqui o trecho corpo -> boca é
## varrido: se há parede no caminho, devolve o ponto de contato com `blocked = true` (o tiro deve
## morrer ali); senão devolve a própria boca com `blocked = false`.
static func trace_spawn(context: Node2D, from: Vector2, muzzle: Vector2, mask: int) -> Dictionary:
	# Raio da posição do corpo até a boca da arma.
	var wall: Dictionary = trace_wall(context, from, muzzle, mask)
	if wall.is_empty():  # Livre: o tiro nasce na boca.
		return {"blocked": false, "position": muzzle}  # Sem parede: tiro normal.
	# Parede no caminho: o tiro nasce e morre no ponto de contato.
	return {"blocked": true, "position": wall["position"] as Vector2}


# --- Árvore de nós (recursivo) ---

## Varre os descendentes de `root` e devolve os nós aceitos por `predicate` (Callable(Node) -> bool).
## Procura dentro de `root` (e dos filhos dos filhos, até `max_depth`) todos os nós que o filtro `predicate` aceitar.
static func find_descendants(root: Node, predicate: Callable, max_depth: int = MAX_TREE_DEPTH) -> Array[Node]:
	var found: Array[Node] = []  # Lista de resultados.
	_collect_descendants(root, predicate, max_depth, found)  # Percorre a árvore preenchendo a lista.
	return found


## Recursão de find_descendants: para ao esgotar `depth_left` ou ao chegar numa folha.
## Parte recursiva da busca: visita cada filho, guarda os aceitos e desce até o limite de profundidade.
static func _collect_descendants(node: Node, predicate: Callable, depth_left: int, out: Array[Node]) -> void:
	if depth_left < 0 or not is_valid(node):  # Passou da profundidade ou o nó sumiu: para.
		return
	for child: Node in node.get_children():  # Passa por cada filho direto.
		if predicate.call(child):  # O filtro decide se o filho entra na lista.
			out.append(child)
		_collect_descendants(child, predicate, depth_left - 1, out)  # Desce mais um nível.


## Valor de uma propriedade da raiz gravada na cena (sem instanciá-la) ou `fallback`.
## Lê uma propriedade da raiz da cena sem instanciá-la (útil para saber velocidade e vida do projétil antes de criá-lo).
static func get_scene_root_property(scene: PackedScene, property: StringName, fallback: Variant) -> Variant:
	if scene == null:  # Sem cena, usa o valor padrão.
		return fallback
	var state: SceneState = scene.get_state()  # Estado guardado dentro do arquivo .tscn.
	for i: int in state.get_node_property_count(0):  # O nó 0 é a raiz da cena.
		if state.get_node_property_name(0, i) == property:  # Achou a propriedade pelo nome.
			return state.get_node_property_value(0, i)  # Devolve o valor gravado na cena.
	return fallback  # Não estava gravada: usa o valor padrão.


# --- Sprites ---

## Espelha o sprite mantendo o conteúdo centralizado (`base_offset_x` = offset sem espelho).
## Espelha o sprite horizontalmente e ajusta o `offset` para o desenho não pular de lugar.
static func set_sprite_flip(sprite: Sprite2D, flipped: bool, base_offset_x: float) -> void:
	sprite.flip_h = flipped  # Espelha ou desespelha.
	# Inverte o deslocamento junto com o espelho.
	sprite.offset.x = -base_offset_x if flipped else base_offset_x


## Pisca o sprite em `color` e volta ao normal; devolve o Tween para cancelar com kill_flash().
## Faz o sprite piscar na cor dada e voltar ao normal, devolvendo o Tween (para cancelar depois com kill_flash).
static func flash_sprite(sprite: CanvasItem, previous: Tween, color: Color, duration: float,
		while_paused: bool = false) -> Tween:
	kill_flash(sprite, previous)  # Cancela um pisca anterior para não acumular.
	if not is_valid(sprite):  # Sprite sumiu: nada a fazer.
		return null
	sprite.self_modulate = color  # Pinta o sprite com a cor do pisca.
	var tween: Tween = sprite.create_tween()  # Cria a animação no próprio sprite.
	if while_paused:  # Se pedido, a animação roda mesmo com o jogo pausado.
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # o dano do quiz chega com o jogo pausado
	tween.tween_property(sprite, ^"self_modulate", Color.WHITE, duration)  # Volta suavemente à cor normal.
	return tween


## Corta o pisca e devolve a cor normal.
## Cancela um pisca em andamento e devolve a cor normal.
static func kill_flash(sprite: CanvasItem, tween: Tween) -> void:
	if tween != null and tween.is_valid():  # Mata a animação se ainda estiver rodando.
		tween.kill()
	if is_valid(sprite):  # Restaura a cor branca (sem alteração).
		sprite.self_modulate = Color.WHITE


# --- Sinais e timers ---

## Timer de jogo: respeita a pausa e some junto com o contexto.
## Cria um timer que respeita a pausa e a câmera lenta (o `false` é o parâmetro process_always).
static func game_timer(context: Node, seconds: float) -> SceneTreeTimer:
	if not is_alive(context):  # Contexto morto: sem timer.
		return null
	# Garante que o tempo nunca seja negativo.
	return context.get_tree().create_timer(maxf(seconds, 0.0), false)


## Conecta só se ainda não estiver conectado.
## Liga um sinal a uma função somente se ainda não estiver ligado (evita conexões duplicadas).
static func connect_once(sig: Signal, callable: Callable, flags: int = 0) -> void:
	if not sig.is_connected(callable):  # Só conecta se ainda não estiver conectado.
		sig.connect(callable, flags)


## Desconecta só se estiver conectado.
## Desliga um sinal de uma função somente se estiver ligado (evita erro ao desconectar duas vezes).
static func disconnect_if_connected(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):  # Só desconecta se estiver conectado.
		sig.disconnect(callable)


## Dá ao nó uma forma circular própria.
## Dá ao nó um círculo próprio (cópia), para mudar o raio sem afetar os outros que compartilham o mesmo recurso.
static func set_unique_circle_radius(shape_node: CollisionShape2D, radius: float) -> bool:
	if not is_valid(shape_node):  # Nó inexistente: falha.
		return false
	var circle := shape_node.shape as CircleShape2D  # Forma atual, se for círculo.
	# Sem círculo cria um novo; com círculo copia (cópia única).
	circle = CircleShape2D.new() if circle == null else circle.duplicate() as CircleShape2D
	circle.radius = maxf(radius, 0.0)  # Raio nunca negativo.
	shape_node.shape = circle  # Aplica a forma ao nó.
	return true


## Raio do círculo da forma ou `fallback` se a forma não for um círculo.
## Lê o raio do círculo do nó (ou o valor `fallback` se a forma não for um círculo).
static func get_circle_radius(shape_node: CollisionShape2D, fallback: float) -> float:
	if is_valid(shape_node) and shape_node.shape is CircleShape2D:  # Só círculos têm raio.
		return (shape_node.shape as CircleShape2D).radius
	return fallback
