class_name ArrowSequenceView
extends Control
## Desenha uma sequência de setas por código. Usado pela HUD de comando e pelo menu de level-up.
## Estados: normal, apagada (não combina) e em cooldown (cinza). Setas acertadas ficam acesas.

enum State { NORMAL, DIMMED, COOLDOWN }  # Estados: normal, apagada (não combina) e em recarga.

const COLOR_NORMAL: Color = Color(0.86, 0.88, 0.92, 1.0)  # Cor normal.
const COLOR_HIT: Color = Color("#e8c15a")  # Cor das setas já acertadas (dourado).
const COLOR_DIMMED: Color = Color(0.86, 0.88, 0.92, 0.22)  # Cor apagada.
const COLOR_COOLDOWN: Color = Color(0.42, 0.43, 0.47, 0.85)  # Cor em recarga.
const COLOR_PULSE: Color = Color(1.0, 1.0, 1.0, 1.0)  # Cor do brilho (habilidade pronta).
## Contorno do formato da seta apontando para cima (unidades de meia-célula).
const ARROW_SHAPE: Array[Vector2] = [
	Vector2(0.0, -1.0), Vector2(1.0, 0.0), Vector2(0.42, 0.0), Vector2(0.42, 1.0),
	Vector2(-0.42, 1.0), Vector2(-0.42, 0.0), Vector2(-1.0, 0.0),
]
## Ângulo de cada direção (a forma base aponta para cima).
const DIR_ANGLE: Dictionary = {
	AbilityData.Dir.UP: 0.0,
	AbilityData.Dir.RIGHT: PI * 0.5,
	AbilityData.Dir.DOWN: PI,
	AbilityData.Dir.LEFT: PI * 1.5,
}
const SHAKE_PIXELS: float = 5.0  # Quanto a seta treme ao errar (px).
const SHAKE_TIME: float = 0.3  # Duração do tremor.
const PULSE_TIME: float = 0.45  # Duração do brilho.

## Tamanho de cada seta e espaço entre elas (px).
@export var arrow_size: float = 18.0:
	set(value):
		arrow_size = value
		update_minimum_size()
		queue_redraw()
@export var arrow_gap: float = 5.0:  # Espaço entre as setas.
	set(value):
		arrow_gap = value
		update_minimum_size()
		queue_redraw()

var _sequence: Array[int] = []  # Sequência desenhada.
var _progress: int = 0  # Quantas setas já foram acertadas.
var _state: State = State.NORMAL  # Estado visual.
var _shake_offset: float = 0.0  # Deslocamento do tremor.
var _pulse: float = 0.0  # Intensidade do brilho (0 a 1).
var _shake_tween: Tween = null  # Animação do tremor.
var _pulse_tween: Tween = null  # Animação do brilho.


## Não captura cliques (só desenha).
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Define a sequência a desenhar e recalcula o tamanho.
func set_sequence(new_sequence: Array[int]) -> void:
	_sequence = new_sequence.duplicate()  # Copia a lista.
	_progress = 0  # Nenhuma seta acertada ainda.
	update_minimum_size()
	queue_redraw()


## Quantas setas já foram acertadas (ficam acesas).
func set_progress(count: int) -> void:
	_progress = clampi(count, 0, _sequence.size())
	queue_redraw()


## Muda o estado visual (normal, apagado ou em recarga).
func set_state(new_state: State) -> void:
	if new_state == _state:  # Mesmo estado: nada a fazer.
		return
	_state = new_state
	queue_redraw()


## Treme as setas (erro de digitação).
## Treme as setas (erro de digitação).
func shake() -> void:
	if _shake_tween != null and _shake_tween.is_valid():  # Cancela o tremor anterior.
		_shake_tween.kill()
	_shake_tween = UiTween.create_pausable(self)  # Animação que roda mesmo com o jogo pausado.
	_shake_tween.tween_method(_apply_shake, 0.0, 1.0, SHAKE_TIME)  # Anima de 0 a 1 em `SHAKE_TIME`.


## Pequeno brilho (habilidade ficou pronta).
## Faz um brilho rápido (a habilidade ficou pronta).
func pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():  # Cancela o brilho anterior.
		_pulse_tween.kill()
	_pulse_tween = UiTween.create_pausable(self)  # Animação que para com a pausa.
	_pulse_tween.tween_method(_apply_pulse, 1.0, 0.0, PULSE_TIME)  # Anima de 1 a 0.


## Passo da animação do tremor: seno que vai diminuindo.
func _apply_shake(t: float) -> void:
	_shake_offset = sin(t * 40.0) * SHAKE_PIXELS * (1.0 - t)  # Deslocamento no tempo t.
	queue_redraw()  # Redesenha.


## Passo da animação do brilho.
func _apply_pulse(value: float) -> void:
	_pulse = value  # Guarda o valor.
	queue_redraw()  # Redesenha.


## Tamanho mínimo: soma das setas e dos espaços.
func _get_minimum_size() -> Vector2:
	var count: int = _sequence.size()
	if count == 0:  # Sem setas: só a altura.
		return Vector2(0.0, arrow_size)
	return Vector2(float(count) * (arrow_size + arrow_gap) - arrow_gap, arrow_size)  # Largura total.


## Desenha cada seta como polígono girado para a direção dela.
func _draw() -> void:
	var half: float = arrow_size * 0.5  # Metade do tamanho (raio).
	for i: int in _sequence.size():
		# Centro da seta i (com o tremor).
		var center: Vector2 = Vector2(float(i) * (arrow_size + arrow_gap) + half + _shake_offset, half)
		var angle: float = float(DIR_ANGLE.get(_sequence[i], 0.0))  # Ângulo da direção.
		var points: PackedVector2Array = PackedVector2Array()  # Pontos do polígono.
		for corner: Vector2 in ARROW_SHAPE:  # Gira e escala cada ponto da forma base.
			points.append(center + corner.rotated(angle) * half * 0.92)
		draw_colored_polygon(points, _color_for(i))  # Pinta com a cor certa.


## Escolhe a cor da seta: acesa se já foi acertada, senão pela situação, e mistura com o brilho.
func _color_for(index: int) -> Color:
	var base: Color = COLOR_NORMAL  # Cor base.
	if index < _progress:  # Já acertada: dourada.
		base = COLOR_HIT
	else:
		match _state:  # Senão pelo estado.
			State.DIMMED:
				base = COLOR_DIMMED
			State.COOLDOWN:
				base = COLOR_COOLDOWN
	return base.lerp(COLOR_PULSE, _pulse * 0.8)  # Mistura com o brilho.
