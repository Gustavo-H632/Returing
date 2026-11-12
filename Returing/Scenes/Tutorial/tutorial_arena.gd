class_name TutorialArena
extends Node2D
## Sala de treino: piso metálico com marcações, paredes com painéis tecnológicos, neon nas bordas,
## luzes de chão que acendem em sequência e uma escotilha no teto por onde o droide entra.
## Tudo é desenhado por código; as paredes têm colisão (camada 1, "Mundo").

## O aviso sai quando uma luz do chão acende (índice da luz).
signal light_turned_on(index: int)

## Tamanho da sala (igual à tela do jogo).
const SIZE: Vector2 = Vector2(1152.0, 648.0)
## Espessura das paredes.
const WALL: float = 48.0
## Lado de cada placa do piso.
const TILE: float = 48.0
## Centro do piso (onde o jogador aparece).
const CENTER: Vector2 = Vector2(576.0, 324.0)
## Posição da escotilha do teto (por onde o droide entra).
const HATCH_POS: Vector2 = Vector2(576.0, 0.0)
## Largura da escotilha.
const HATCH_WIDTH: float = 112.0

const COLOR_VOID: Color = Color("#05070a")  # Fora da sala.
const COLOR_FLOOR_A: Color = Color("#1c2330")  # Placa clara do piso.
const COLOR_FLOOR_B: Color = Color("#181e29")  # Placa escura do piso.
const COLOR_SEAM: Color = Color("#0d1117")  # Emendas entre as placas.
const COLOR_RIVET: Color = Color("#2f3a4b")  # Rebites.
const COLOR_MARK: Color = Color("#3b8fb5")  # Marcações do chão.
const COLOR_WALL: Color = Color("#10151d")  # Parede.
const COLOR_WALL_PANEL: Color = Color("#171e29")  # Painel da parede.
const COLOR_WALL_EDGE: Color = Color("#2a3445")  # Borda dos painéis.
const COLOR_HAZARD_A: Color = Color("#d9a21b")  # Listra de aviso amarela.
const COLOR_HAZARD_B: Color = Color("#14110a")  # Listra de aviso preta.
const COLOR_NEON: Color = Color("#3ad6ff")  # Neon da sala.
const COLOR_LIGHT: Color = Color("#7fe8ff")  # Luzes do chão.

## Brilho do piso e das paredes (0 = escuro total, 1 = normal).
var brightness: float = 1.0:
	set(value):
		brightness = clampf(value, 0.0, 1.5)
		if _static_layer != null:
			_static_layer.modulate = Color(brightness, brightness, brightness)
## Intensidade do neon e das luzes (1 = normal; sobe quando o inimigo entra).
var intensity: float = 1.0:
	set(value):
		intensity = value
		if _lights_layer != null:
			_lights_layer.queue_redraw()
## Abertura da escotilha, de 0 (fechada) a 1 (aberta).
var hatch_open: float = 0.0:
	set(value):
		hatch_open = clampf(value, 0.0, 1.0)
		if _lights_layer != null:
			_lights_layer.queue_redraw()

var _static_layer: Node2D = null  # Piso e paredes (desenhados uma vez).
var _lights_layer: Node2D = null  # Neon, luzes e escotilha (animados).
var _light_points: Array[Vector2] = []  # Posição de cada luz do chão.
var _light_levels: Array[float] = []  # Quanto cada luz está acesa (0 a 1).
var _pad_level: float = 0.0  # Brilho do círculo central.
var _time: float = 0.0  # Relógio da animação do neon.


## Monta as camadas, as luzes e as colisões das paredes.
func _ready() -> void:
	_build_light_points()
	_static_layer = _StaticLayer.new()
	_static_layer.name = &"Static"
	add_child(_static_layer)
	_lights_layer = _LightsLayer.new()
	_lights_layer.name = &"Lights"
	(_lights_layer as _LightsLayer).arena = self
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD  # Luz soma ao piso.
	_lights_layer.material = additive
	add_child(_lights_layer)
	_build_walls()
	brightness = brightness  # Reaplica o brilho agora que a camada existe.


## Anima o neon.
func _process(delta: float) -> void:
	_time += delta
	if _lights_layer != null:
		_lights_layer.queue_redraw()


## Número de luzes do chão.
func light_count() -> int:
	return _light_points.size()


## Quantas luzes já estão totalmente acesas (usado nos testes).
func lights_on() -> int:
	var total: int = 0
	for level: float in _light_levels:
		if level >= 0.99:
			total += 1
	return total


## Acende as luzes do chão uma a uma, o piso vai revelando e por fim o círculo central acende.
## Devolve quando termina. `step` é o intervalo (s) entre as luzes.
func light_up_sequence(step: float = 0.13) -> void:
	for i: int in _light_points.size():
		var tween: Tween = create_tween()
		tween.tween_method(func(v: float) -> void: _set_light(i, v), 0.0, 1.0, 0.18)
		light_turned_on.emit(i)
		# Revela o piso aos poucos junto com as luzes.
		var target: float = lerpf(0.06, 0.9, float(i + 1) / float(_light_points.size()))
		create_tween().tween_property(self, ^"brightness", target, step)
		await get_tree().create_timer(step, false).timeout
	var pad: Tween = create_tween()
	pad.tween_method(func(v: float) -> void: _pad_level = v, 0.0, 1.0, 0.4)
	create_tween().tween_property(self, ^"brightness", 1.0, 0.5)
	await pad.finished


## Abre a escotilha do teto e devolve quando termina.
func open_hatch(time: float = 0.7) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, ^"hatch_open", 1.0, time).set_trans(Tween.TRANS_SINE)
	await tween.finished


## Fecha a escotilha do teto e devolve quando termina.
func close_hatch(time: float = 0.6) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, ^"hatch_open", 0.0, time).set_trans(Tween.TRANS_SINE)
	await tween.finished


## Deixa as luzes mais intensas (o inimigo entrou na sala).
func intensify(target: float = 1.45, time: float = 0.8) -> void:
	create_tween().tween_property(self, ^"intensity", target, time)


## Acende o nível de uma luz (usado pela animação).
func _set_light(index: int, value: float) -> void:
	_light_levels[index] = value
	if _lights_layer != null:
		_lights_layer.queue_redraw()


## Define onde ficam as luzes: um anel de 12 ao redor do centro e uma em cada canto.
func _build_light_points() -> void:
	_light_points.clear()
	_light_levels.clear()
	for k: int in 12:  # Anel, começando no topo e girando no sentido horário.
		var angle: float = -PI * 0.5 + TAU * float(k) / 12.0
		_light_points.append(CENTER + Vector2(cos(angle) * 290.0, sin(angle) * 190.0))
	var inset: float = WALL + 34.0  # Cantos.
	_light_points.append(Vector2(inset, inset))
	_light_points.append(Vector2(SIZE.x - inset, inset))
	_light_points.append(Vector2(SIZE.x - inset, SIZE.y - inset))
	_light_points.append(Vector2(inset, SIZE.y - inset))
	for i: int in _light_points.size():
		_light_levels.append(0.0)


## Cria as quatro paredes sólidas (a escotilha não tem colisão: é só visual).
func _build_walls() -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = &"Walls"
	body.collision_layer = 1  # "Mundo".
	body.collision_mask = 0
	var rects: Array[Rect2] = [
		Rect2(-200.0, -200.0, SIZE.x + 400.0, 200.0 + WALL),  # Topo.
		Rect2(-200.0, SIZE.y - WALL, SIZE.x + 400.0, 200.0 + WALL),  # Base.
		Rect2(-200.0, -200.0, 200.0 + WALL, SIZE.y + 400.0),  # Esquerda.
		Rect2(SIZE.x - WALL, -200.0, 200.0 + WALL, SIZE.y + 400.0),  # Direita.
	]
	for rect: Rect2 in rects:
		var shape: CollisionShape2D = CollisionShape2D.new()
		var box: RectangleShape2D = RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.get_center()
		body.add_child(shape)
	add_child(body)


# --- Camadas de desenho ---

## Piso e paredes: desenhados uma única vez.
class _StaticLayer extends Node2D:
	## Desenha o piso, as marcações, as listras de aviso e as paredes.
	func _draw() -> void:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 42  # Painéis sempre iguais.
		draw_rect(Rect2(-600.0, -600.0, SIZE.x + 1200.0, SIZE.y + 1200.0), COLOR_VOID)
		_draw_floor()
		_draw_markings()
		_draw_hazard_frame()
		_draw_walls(rng)

	## Placas xadrez com emendas e rebites.
	func _draw_floor() -> void:
		var cols: int = int(SIZE.x / TILE)
		var rows: int = int(SIZE.y / TILE)
		for row: int in rows:
			for col: int in cols:
				var color: Color = COLOR_FLOOR_A if (row + col) % 2 == 0 else COLOR_FLOOR_B
				draw_rect(Rect2(Vector2(col, row) * TILE, Vector2(TILE, TILE)), color)
		for col: int in cols + 1:  # Emendas verticais.
			draw_line(Vector2(col * TILE, 0.0), Vector2(col * TILE, SIZE.y), COLOR_SEAM, 2.0)
		for row: int in rows + 1:  # Emendas horizontais.
			draw_line(Vector2(0.0, row * TILE), Vector2(SIZE.x, row * TILE), COLOR_SEAM, 2.0)
		for row: int in rows + 1:  # Rebites nos cruzamentos.
			for col: int in cols + 1:
				var p: Vector2 = Vector2(col, row) * TILE
				for corner: Vector2 in [Vector2(5, 5), Vector2(-5, 5), Vector2(5, -5), Vector2(-5, -5)]:
					draw_rect(Rect2(p + corner - Vector2.ONE, Vector2(2, 2)), COLOR_RIVET)

	## Círculos e linhas de treino no chão.
	func _draw_markings() -> void:
		var mark: Color = COLOR_MARK
		mark.a = 0.55
		draw_arc(CENTER, 78.0, 0.0, TAU, 64, mark, 3.0)
		draw_arc(CENTER, 84.0, 0.0, TAU, 64, mark * Color(1, 1, 1, 0.5), 1.0)
		for k: int in 24:  # Círculo externo tracejado.
			var a: float = TAU * float(k) / 24.0
			draw_arc(CENTER, 176.0, a, a + TAU / 48.0, 6, mark, 3.0)
		draw_arc(CENTER, 280.0, 0.0, TAU, 96, mark * Color(1, 1, 1, 0.35), 2.0)
		# Cruz de mira e faixas até as bordas.
		for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(CENTER + dir * 96.0, CENTER + dir * 150.0, mark, 3.0)
			draw_line(CENTER + dir * 196.0, CENTER + dir * 262.0, mark * Color(1, 1, 1, 0.6), 2.0)
		# Marcas de posição (cantos de colchete) nos quatro lados.
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				var corner: Vector2 = CENTER + Vector2(sx * 380.0, sy * 215.0)
				draw_line(corner, corner + Vector2(-sx * 36.0, 0.0), mark, 3.0)
				draw_line(corner, corner + Vector2(0.0, -sy * 36.0), mark, 3.0)

	## Faixa de aviso (listras diagonais) encostada nas paredes.
	func _draw_hazard_frame() -> void:
		var band: float = 8.0
		var bands: Array[Rect2] = [
			Rect2(WALL, WALL, SIZE.x - WALL * 2.0, band),
			Rect2(WALL, SIZE.y - WALL - band, SIZE.x - WALL * 2.0, band),
			Rect2(WALL, WALL + band, band, SIZE.y - WALL * 2.0 - band * 2.0),
			Rect2(SIZE.x - WALL - band, WALL + band, band, SIZE.y - WALL * 2.0 - band * 2.0),
		]
		for rect: Rect2 in bands:
			draw_rect(rect, COLOR_HAZARD_B)
			var stripe: float = 16.0
			var horizontal: bool = rect.size.x > rect.size.y
			var length: float = rect.size.x if horizontal else rect.size.y
			var n: int = int(length / stripe)
			for k: int in n:
				if k % 2 == 0:
					var a: Vector2 = rect.position + (Vector2(k * stripe, 0.0) if horizontal else Vector2(0.0, k * stripe))
					var sz: Vector2 = Vector2(stripe, rect.size.y) if horizontal else Vector2(rect.size.x, stripe)
					draw_rect(Rect2(a, sz), COLOR_HAZARD_A)

	## Paredes com painéis, ventilações e telas.
	func _draw_walls(rng: RandomNumberGenerator) -> void:
		draw_rect(Rect2(-600.0, -600.0, SIZE.x + 1200.0, 600.0 + WALL), COLOR_WALL)
		draw_rect(Rect2(-600.0, SIZE.y - WALL, SIZE.x + 1200.0, 600.0 + WALL), COLOR_WALL)
		draw_rect(Rect2(-600.0, 0.0, 600.0 + WALL, SIZE.y), COLOR_WALL)
		draw_rect(Rect2(SIZE.x - WALL, 0.0, 600.0 + WALL, SIZE.y), COLOR_WALL)
		var panel: float = 96.0
		for col: int in int(SIZE.x / panel):  # Topo e base.
			_wall_panel(Rect2(col * panel + 4.0, 4.0, panel - 8.0, WALL - 8.0), rng)
			_wall_panel(Rect2(col * panel + 4.0, SIZE.y - WALL + 4.0, panel - 8.0, WALL - 8.0), rng)
		for row: int in int(SIZE.y / panel) + 1:  # Lados.
			_wall_panel(Rect2(4.0, row * panel + 4.0, WALL - 8.0, panel - 8.0), rng)
			_wall_panel(Rect2(SIZE.x - WALL + 4.0, row * panel + 4.0, WALL - 8.0, panel - 8.0), rng)

	## Um painel: moldura, ventilação ou tela, e luzinhas de status.
	func _wall_panel(rect: Rect2, rng: RandomNumberGenerator) -> void:
		draw_rect(rect, COLOR_WALL_PANEL)
		draw_rect(rect, COLOR_WALL_EDGE, false, 2.0)
		var horizontal: bool = rect.size.x > rect.size.y
		match rng.randi() % 3:
			0:  # Ventilação: fendas paralelas.
				for k: int in 4:
					var off: float = 8.0 + float(k) * 7.0
					if horizontal:
						draw_rect(Rect2(rect.position + Vector2(off, 10.0), Vector2(3.0, rect.size.y - 20.0)), COLOR_SEAM)
					else:
						draw_rect(Rect2(rect.position + Vector2(10.0, off), Vector2(rect.size.x - 20.0, 3.0)), COLOR_SEAM)
			1:  # Tela apagada com uma linha de dados.
				var screen: Rect2 = rect.grow(-9.0)
				draw_rect(screen, Color("#0a2630"))
				draw_rect(screen, Color("#1c5f73"), false, 1.0)
				var mid: Vector2 = screen.get_center()
				if horizontal:
					draw_line(Vector2(screen.position.x + 3.0, mid.y), Vector2(screen.end.x - 3.0 - rng.randf() * 20.0, mid.y), Color("#2aa6c4"), 2.0)
				else:
					draw_line(Vector2(mid.x, screen.position.y + 3.0), Vector2(mid.x, screen.end.y - 3.0 - rng.randf() * 20.0), Color("#2aa6c4"), 2.0)
			_:  # Luzes de status.
				for k: int in 3:
					var led: Color = [Color("#1f8f4a"), Color("#c9962a"), Color("#a13a3a")][k]
					var pos: Vector2 = rect.position + (Vector2(12.0 + k * 12.0, rect.size.y * 0.5) if horizontal else Vector2(rect.size.x * 0.5, 12.0 + k * 12.0))
					draw_rect(Rect2(pos - Vector2(2, 2), Vector2(4, 4)), led)


## Neon, luzes do chão, círculo central e escotilha: redesenhados a cada quadro.
class _LightsLayer extends Node2D:
	var arena: TutorialArena = null  # Dono dos valores de animação.

	## Desenha as luzes por cima do piso (modo aditivo).
	func _draw() -> void:
		if arena == null:
			return
		var pulse: float = 0.85 + 0.15 * sin(arena._time * 2.2)
		var power: float = arena.intensity * pulse
		_draw_neon(power)
		_draw_pad(power)
		for i: int in arena._light_points.size():
			_draw_light(arena._light_points[i], arena._light_levels[i], power)
		_draw_hatch()

	## Faixas de neon na borda interna das paredes (ficam acesas com o brilho da sala).
	func _draw_neon(power: float) -> void:
		var level: float = clampf(arena.brightness, 0.0, 1.0) * power
		if level <= 0.01:
			return
		var inner: Rect2 = Rect2(Vector2(WALL, WALL), SIZE - Vector2(WALL, WALL) * 2.0)
		var corners: PackedVector2Array = PackedVector2Array([
			inner.position, Vector2(inner.end.x, inner.position.y), inner.end,
			Vector2(inner.position.x, inner.end.y), inner.position,
		])
		for pass_index: int in 3:  # Três passadas: halo largo e fraco até o fio forte.
			var width: float = [10.0, 5.0, 2.0][pass_index]
			var alpha: float = [0.10, 0.2, 0.9][pass_index] * level
			var color: Color = COLOR_NEON
			color.a = clampf(alpha, 0.0, 1.0)
			draw_polyline(corners, color, width)

	## Círculo central (a "plataforma" do jogador).
	func _draw_pad(power: float) -> void:
		if arena._pad_level <= 0.01:
			return
		var color: Color = COLOR_NEON
		color.a = 0.5 * arena._pad_level * power
		draw_arc(CENTER, 78.0, 0.0, TAU, 64, color, 5.0)
		color.a = 0.12 * arena._pad_level * power
		draw_circle(CENTER, 76.0, color)

	## Uma luz do chão com halo.
	func _draw_light(at: Vector2, level: float, power: float) -> void:
		if level <= 0.01:
			return
		var color: Color = COLOR_LIGHT
		for layer: int in 3:
			var radius: float = [34.0, 20.0, 8.0][layer] * (0.8 + 0.2 * level)
			color.a = [0.07, 0.14, 0.9][layer] * level * power
			draw_circle(at, radius, color)

	## Escotilha: duas folhas que se afastam e uma luz alaranjada por trás.
	func _draw_hatch() -> void:
		var open: float = arena.hatch_open
		var half: float = HATCH_WIDTH * 0.5
		if open > 0.01:  # Interior aceso.
			var glow: Color = Color("#ff8a3a")
			glow.a = 0.55 * open
			draw_rect(Rect2(HATCH_POS.x - half, 0.0, HATCH_WIDTH, WALL), glow)
			glow.a = 0.15 * open
			draw_rect(Rect2(HATCH_POS.x - half - 12.0, WALL, HATCH_WIDTH + 24.0, 40.0 * open), glow)
		var slide: float = half * open
		var leaf: Color = Color("#3a4558")
		leaf.a = (0.0 if open >= 0.99 else 0.9) * clampf(arena.brightness, 0.0, 1.0)  # Só um contorno (a luz vem de trás).
		draw_rect(Rect2(HATCH_POS.x - half - slide, 4.0, half, WALL - 8.0), leaf, false, 2.0)
		draw_rect(Rect2(HATCH_POS.x + slide, 4.0, half, WALL - 8.0), leaf, false, 2.0)
