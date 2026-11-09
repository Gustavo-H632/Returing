class_name AimIndicator
extends Node2D
## Mira do ataque (estilo Brawl Stars), sempre translúcida (~80% de transparência):
## - Tiro: retângulo que sai da boca do cano com a largura do tiro (cresce com a carga) e o
##   comprimento do alcance dele (corta na parede).
## - Espada: a área real do golpe (círculo da hitbox) à frente do player, ligada por uma linha.

# Cores da mira: tiro (azul) e espada (laranja), preenchimento e borda.
const SHOT_FILL: Color = Color(0.4, 0.85, 1.0, 0.2)
const SHOT_EDGE: Color = Color(0.7, 0.95, 1.0, 0.35)
const SWORD_FILL: Color = Color(1.0, 0.65, 0.25, 0.2)
const SWORD_EDGE: Color = Color(1.0, 0.82, 0.55, 0.4)
const EDGE_WIDTH: float = 1.5  # Espessura do contorno.
## Camada de física tratada como parede (igual à do projétil).
const WALL_MASK: int = 1

# Modos de mira: nenhuma, tiro ou espada.
enum Mode { NONE, SHOT, SWORD }

var player: Player = null  # Jogador a quem a mira pertence (definido por quem a cria).

var _mode: Mode = Mode.NONE  # Modo atual.
var _length: float = 0.0  # Comprimento da mira (px).
var _width: float = 0.0  # Largura da barra do tiro (px).
var _radius: float = 0.0  # Raio da área da espada (px).


## Configura o nó: fica solto da escala do jogador, acima do chão e escondido.
func _ready() -> void:
	top_level = true  # ignora a escala/rotação do player: tudo é medido em pixels de mundo
	z_index = 4  # Desenha acima do chão.
	visible = false  # Começa escondida.


## A cada quadro escolhe o modo (tiro, espada ou nenhum) e mostra ou esconde a mira.
func _process(_delta: float) -> void:
	_mode = Mode.NONE  # Por padrão, nada a mostrar.
	if CombatUtils.is_alive(player):  # Só se o jogador ainda existe e está vivo.
		if player.is_aiming_shot():  # Carregando tiro: mostra a barra azul.
			_update_shot()
		elif player.is_aiming_sword():  # Mirando a espada: mostra a área laranja.
			_update_sword()
	if _mode == Mode.NONE:  # Sem mira: esconde e encerra.
		if visible:
			visible = false
		return
	visible = true  # Há mira: aparece e redesenha.
	queue_redraw()


## Calcula a posição, o ângulo, a largura e o comprimento da barra do tiro (cortando na parede).
func _update_shot() -> void:
	_mode = Mode.SHOT
	var origin: Vector2 = player.get_muzzle_position()  # Boca do cano.
	var direction: Vector2 = player.get_shot_direction()  # Direção em que o tiro sairia.
	global_position = origin  # A barra nasce na boca do cano.
	global_rotation = direction.angle()  # E gira para a direção do tiro.
	_width = PlayerProjectile.width_for_charge(player.get_charge_ratio())  # A largura cresce com a carga.
	_length = player.get_shot_range()  # O comprimento é o alcance do tiro.
	# Procura parede no caminho.
	var wall: Dictionary = CombatUtils.trace_wall(player, origin, origin + direction * _length, WALL_MASK)
	if not wall.is_empty():  # Se há parede, a barra termina nela.
		_length = origin.distance_to(wall["position"] as Vector2)


## Calcula a posição e o tamanho da área da espada à frente do jogador.
func _update_sword() -> void:
	var sword := player.weapon as Sword  # Arma do jogador, tratada como espada.
	_mode = Mode.SWORD  # Modo espada.
	var direction: Vector2 = player.get_sword_direction()  # Direção do golpe.
	global_position = sword.global_position  # A área parte da espada.
	global_rotation = direction.angle()  # Gira para a direção do golpe.
	_length = sword.get_zone_distance()  # Distância da espada até o centro da área.
	_radius = sword.get_zone_radius()  # Raio da área do golpe.


## Desenha a barra do tiro ou a área circular da espada, conforme o modo.
func _draw() -> void:
	match _mode:
		Mode.SHOT:
			# Retângulo que sai da origem para a direita (o nó já está girado).
			var rect := Rect2(0.0, -_width * 0.5, _length, _width)
			draw_rect(rect, SHOT_FILL)  # Preenchimento translúcido.
			draw_rect(rect, SHOT_EDGE, false, EDGE_WIDTH)  # Contorno.
		Mode.SWORD:
			var center := Vector2(_length, 0.0)  # Centro da área do golpe.
			draw_line(Vector2.ZERO, center, SWORD_EDGE, EDGE_WIDTH)  # Linha que liga o personagem à área.
			draw_circle(center, _radius, SWORD_FILL)  # Preenchimento do círculo.
			draw_arc(center, _radius, 0.0, TAU, 48, SWORD_EDGE, EDGE_WIDTH, true)  # Contorno do círculo.
