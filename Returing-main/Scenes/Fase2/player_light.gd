class_name PlayerLight
extends PointLight2D
## Luz do jogador no labirinto: a única fonte de visão. O alcance é um @export em pixels de tela;
## a cintilação é leve e usa só senos (nada aleatório).

@export_group("Alcance")
## Raio da luz em pixels (distância do jogador até onde a luz chega a zero).
@export_range(32.0, 600.0, 1.0, "or_greater") var light_range: float = 160.0:
	set(value):
		light_range = value
		_apply_range()

@export_group("Cintilação")
## Variação da intensidade (0.07 = 7 %).
@export_range(0.0, 0.5, 0.005) var flicker_energy: float = 0.07
## Variação do raio (0.025 = 2,5 %).
@export_range(0.0, 0.2, 0.005) var flicker_range: float = 0.025
## Velocidade da cintilação.
@export_range(0.1, 30.0, 0.1) var flicker_speed: float = 9.0

var _base_energy: float = 1.0  # Intensidade original da cena.
var _wobble: float = 1.0  # Fator atual do raio (cintilação).
var _time: float = 0.0  # Relógio da cintilação.


## Guarda a intensidade da cena e aplica o alcance.
func _ready() -> void:
	_base_energy = energy
	_apply_range()


## Cintila: três senos de frequências diferentes somados.
func _process(delta: float) -> void:
	_time += delta
	var f: float = sin(_time * flicker_speed) * 0.5 \
			+ sin(_time * flicker_speed * 2.31 + 1.7) * 0.3 \
			+ sin(_time * flicker_speed * 0.43 + 0.6) * 0.2
	energy = _base_energy * (1.0 + flicker_energy * f)
	_wobble = 1.0 + flicker_range * f
	_apply_range()


## Converte o alcance em px para a escala da textura (a luz compensa a escala do jogador no celular).
func _apply_range() -> void:
	if texture == null or not is_inside_tree():
		return
	var parent_scale: float = 1.0
	var parent_node := get_parent() as Node2D
	if parent_node != null:
		parent_scale = maxf(absf(parent_node.global_scale.x), 0.01)
	var radius_px: float = float(texture.get_width()) * 0.5
	texture_scale = (light_range * _wobble) / (radius_px * parent_scale)
