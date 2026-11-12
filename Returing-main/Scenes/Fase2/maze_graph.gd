class_name MazeGraph
extends Node2D
## Mapa de corredores do labirinto (dados ESTÁTICOS gravados em Labirinto.tscn): quais células vizinhas
## têm passagem aberta. Os drones usam isto para contornar paredes (o desvio por raycast do drone não
## enxerga o caminho de um labirinto e travava na parede). Não gera nada: só responde "qual o próximo
## ponto para chegar lá?". Nada é montado em tempo de execução além da tabela de distâncias em cache.

## Grupo pelo qual os estados dos drones acham este nó.
const GROUP: StringName = &"lab_grafo"

## Canto superior esquerdo da célula (0,0), em px de mundo.
@export var origin: Vector2 = Vector2(16.0, 16.0)
## Largura/altura de uma célula (o corredor).
@export var cell_size: float = 96.0
## Espessura da parede entre células.
@export var wall_size: float = 16.0
@export var cols: int = 10  # Células na horizontal.
@export var rows: int = 7  # Células na vertical.
## Passagens abertas: pares de índices de célula (índice = linha * cols + coluna).
@export var links: PackedInt32Array = PackedInt32Array()

var _neighbors: Array[PackedInt32Array] = []  # Vizinhos de cada célula.
var _dist_cache: Dictionary[int, PackedInt32Array] = {}  # Destino -> distância (em células) de todas as células.


## Entra no grupo antes de qualquer _ready (os drones procuram no _ready deles).
func _enter_tree() -> void:
	add_to_group(GROUP)


## Monta a lista de vizinhos a partir dos pares de `links`.
func _ready() -> void:
	_neighbors.clear()
	for i: int in cols * rows:
		_neighbors.append(PackedInt32Array())
	for i: int in range(0, links.size() - 1, 2):
		_neighbors[links[i]].append(links[i + 1])
		_neighbors[links[i + 1]].append(links[i])


## Índice da célula que contém `pos` (a faixa de parede conta para a célula à esquerda/acima).
func cell_index(pos: Vector2) -> int:
	var pitch: float = cell_size + wall_size
	var c: int = clampi(floori((pos.x - origin.x) / pitch), 0, cols - 1)
	var r: int = clampi(floori((pos.y - origin.y) / pitch), 0, rows - 1)
	return r * cols + c


## Centro da célula `index`.
func cell_center(index: int) -> Vector2:
	var pitch: float = cell_size + wall_size
	return origin + Vector2(float(index % cols) * pitch, float(index / cols) * pitch) + Vector2.ONE * cell_size * 0.5


## Próximo ponto (centro de célula) para ir de `from` até `to` sem atravessar parede.
## Na mesma célula devolve o próprio `to`. Dentro de uma célula e da vizinha o trajeto reto é livre
## (os dois formam um retângulo sem parede no meio), então basta ir de centro em centro.
func next_step(from: Vector2, to: Vector2) -> Vector2:
	var a: int = cell_index(from)
	var b: int = cell_index(to)
	if a == b:
		return to
	var dist: PackedInt32Array = _distances_to(b)
	var best: int = a
	for n: int in _neighbors[a]:
		if dist[n] < dist[best]:
			best = n
	if best == a:  # Sem caminho (não deveria acontecer): vai direto.
		return to
	return cell_center(best)


## Comprimento aproximado (px) do trajeto de `from` até `to` pelas passagens.
func path_length(from: Vector2, to: Vector2) -> float:
	var a: int = cell_index(from)
	var b: int = cell_index(to)
	if a == b:
		return from.distance_to(to)
	var steps: int = _distances_to(b)[a]
	return float(steps) * (cell_size + wall_size) if steps < 1000000 else from.distance_to(to)


## Distância em células de todas as células até `target` (busca em largura, guardada em cache).
func _distances_to(target: int) -> PackedInt32Array:
	if _dist_cache.has(target):
		return _dist_cache[target]
	var dist := PackedInt32Array()
	dist.resize(cols * rows)
	dist.fill(1000000)
	dist[target] = 0
	var queue: Array[int] = [target]
	var head: int = 0
	while head < queue.size():
		var cur: int = queue[head]
		head += 1
		for n: int in _neighbors[cur]:
			if dist[n] == 1000000:
				dist[n] = dist[cur] + 1
				queue.append(n)
	_dist_cache[target] = dist
	return dist
