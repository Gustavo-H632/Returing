class_name MobileLayout
extends RefCounted
## Posição e tamanho de cada controle do celular, em proporção da tela (centro) e escala. É a fonte
## única de verdade para o `MobileControls`, para o quadro de comandos, para as barras de status e
## para o editor de HUD. Persiste em `MobileSettings` (seção "layout").
##
## Padrão = o print `res://referencias/mobile_layout.png` (paisagem ~1464x648 lógicos).

const MOVE: StringName = &"move"  # Joystick de movimento.
const AIM: StringName = &"aim"  # Joystick de mira: atira ou golpeia com a espada, conforme a arma escolhida no botão de trocar arma.
const DASH: StringName = &"dash"  # Botão de dash.
const WEAPON: StringName = &"weapon"  # Botão de trocar arma.
const COMMAND: StringName = &"command"  # Botão do modo comando.
const PAUSE: StringName = &"pause"  # Botão de pausa.
const INTERACT: StringName = &"interact"  # Botão E temporário (aparece com um objeto interativo ao alcance), logo acima do modo comando.
const STATUS: StringName = &"status"  # Barras de vida e escudo + barra de XP ao lado.
const BOARD: StringName = &"board"  # Quadro de comandos.

## Todos os controles editáveis, na ordem de desenho/teste.
const IDS: Array[StringName] = [MOVE, AIM, DASH, WEAPON, COMMAND, INTERACT, STATUS, BOARD, PAUSE]

## Nome mostrado no editor.
const LABELS: Dictionary = {
	MOVE: "Movimento", AIM: "Mira e ataque", DASH: "Dash", WEAPON: "Trocar arma",
	COMMAND: "Modo comando", INTERACT: "Interagir", STATUS: "Barras de status", BOARD: "Quadro de comandos",
	PAUSE: "Pausa",
}

## Tamanho de referência (px lógicos) onde o print foi tirado.
const REF_VIEW: Vector2 = Vector2(1464.0, 648.0)
## Escala mínima e máxima permitidas para todos os controles.
const MIN_SCALE: float = 0.6
const MAX_SCALE: float = 1.8

## Padrões: `pos` = centro em proporção da tela; `size` = tamanho (px lógicos) com escala 1;
## `circle` = controle redondo (hit-test circular).
const DEFS: Dictionary = {
	MOVE: {"pos": Vector2(0.107, 0.806), "size": Vector2(164.0, 164.0), "circle": true},
	AIM: {"pos": Vector2(0.900, 0.806), "size": Vector2(164.0, 164.0), "circle": true},
	DASH: {"pos": Vector2(0.763, 0.852), "size": Vector2(94.0, 94.0), "circle": true},
	WEAPON: {"pos": Vector2(0.690, 0.660), "size": Vector2(94.0, 94.0), "circle": true},
	COMMAND: {"pos": Vector2(0.725, 0.500), "size": Vector2(94.0, 94.0), "circle": true},
	INTERACT: {"pos": Vector2(0.725, 0.340), "size": Vector2(94.0, 94.0), "circle": true},
	PAUSE: {"pos": Vector2(0.960, 0.070), "size": Vector2(72.0, 72.0), "circle": true},
	STATUS: {"pos": Vector2(0.134, 0.127), "size": Vector2(352.0, 148.0), "circle": false},
	BOARD: {"pos": Vector2(0.898, 0.2785), "size": Vector2(299.0, 361.0), "circle": false},
}

var _pos: Dictionary = {}  # id -> centro (proporção)
var _scale: Dictionary = {}  # id -> escala


func _init() -> void:
	reset()


## Volta tudo ao padrão do print (em memória).
func reset() -> void:
	for id: StringName in IDS:
		_pos[id] = DEFS[id]["pos"]
		_scale[id] = 1.0


## Lê do arquivo de preferências (valores inválidos viram o padrão).
func load_saved() -> void:
	reset()
	for id: StringName in IDS:
		var p: Variant = MobileSettings.get_value(MobileSettings.SECTION_LAYOUT, "%s_pos" % id, null)
		var s: Variant = MobileSettings.get_value(MobileSettings.SECTION_LAYOUT, "%s_scale" % id, null)
		if p is Vector2 and (p as Vector2).x >= 0.0 and (p as Vector2).x <= 1.0 and (p as Vector2).y >= 0.0 and (p as Vector2).y <= 1.0:
			_pos[id] = p
		if s is float or s is int:
			_scale[id] = clampf(float(s), MIN_SCALE, MAX_SCALE)


## Grava no arquivo de preferências. Devolve true se deu certo.
func save_to_disk() -> bool:
	for id: StringName in IDS:
		MobileSettings.set_value(MobileSettings.SECTION_LAYOUT, "%s_pos" % id, _pos[id])
		MobileSettings.set_value(MobileSettings.SECTION_LAYOUT, "%s_scale" % id, _scale[id])
	return MobileSettings.save()


## Copia o estado de outro layout (usado pelo editor para trabalhar num rascunho).
func copy_from(other: MobileLayout) -> void:
	for id: StringName in IDS:
		_pos[id] = other._pos[id]
		_scale[id] = other._scale[id]


## True se todos os controles estão no padrão.
func is_default() -> bool:
	for id: StringName in IDS:
		if not (_pos[id] as Vector2).is_equal_approx(DEFS[id]["pos"]) or not is_equal_approx(_scale[id], 1.0):
			return false
	return true


func get_proportion(id: StringName) -> Vector2:
	return _pos[id]


func get_scale(id: StringName) -> float:
	return _scale[id]


## Escala efetiva: a do layout, e o quadro de comandos ainda encolhe quando a área segura é mais estreita que o
## print (ex.: tablet 4:3, notch) para continuar dentro da região x >= 0,78 da largura.
func effective_scale(id: StringName, view: Vector2 = REF_VIEW, margins: Vector4 = Vector4.ZERO) -> float:
	var s: float = float(_scale[id])
	if id == BOARD:
		s *= minf(1.0, (view.x - margins.x - margins.z) / REF_VIEW.x)
	return s


## Tamanho em px com a escala atual (e a proporção da tela `view`).
func get_size(id: StringName, view: Vector2 = REF_VIEW, margins: Vector4 = Vector4.ZERO) -> Vector2:
	return (DEFS[id]["size"] as Vector2) * effective_scale(id, view, margins)


## Raio (px) dos controles redondos.
func get_radius(id: StringName) -> float:
	return get_size(id).x * 0.5  # só controles redondos (a escala deles não depende da proporção)


func is_circle(id: StringName) -> bool:
	return DEFS[id]["circle"]


## Centro em px da tela lógica `view`. A proporção guardada vale DENTRO da área segura `margins` (esquerda, topo,
## direita, base): com notch ou barras o conjunto inteiro encolhe junto, sem um controle ser empurrado sobre outro.
func get_center(id: StringName, view: Vector2, margins: Vector4 = Vector4.ZERO) -> Vector2:
	var origin: Vector2 = Vector2(margins.x, margins.y)
	var safe: Vector2 = view - origin - Vector2(margins.z, margins.w)
	var raw: Vector2 = origin + (_pos[id] as Vector2) * safe
	return _clamp_center(raw, get_size(id, view, margins), view, margins)


## Retângulo em px do controle.
func get_rect(id: StringName, view: Vector2, margins: Vector4 = Vector4.ZERO) -> Rect2:
	var size: Vector2 = get_size(id, view, margins)
	return Rect2(get_center(id, view, margins) - size * 0.5, size)


## Move o controle para `center_px` (limitado para não sair da área segura).
func set_center(id: StringName, center_px: Vector2, view: Vector2, margins: Vector4 = Vector4.ZERO) -> void:
	var c: Vector2 = _clamp_center(center_px, get_size(id, view, margins), view, margins)
	var origin: Vector2 = Vector2(margins.x, margins.y)
	var safe: Vector2 = view - origin - Vector2(margins.z, margins.w)
	_pos[id] = Vector2((c.x - origin.x) / maxf(safe.x, 1.0), (c.y - origin.y) / maxf(safe.y, 1.0))


## Muda a escala (limites mínimo/máximo) e mantém o controle dentro da área segura.
func set_scale_value(id: StringName, value: float, view: Vector2, margins: Vector4 = Vector4.ZERO) -> void:
	var center: Vector2 = get_center(id, view, margins)
	_scale[id] = clampf(value, MIN_SCALE, MAX_SCALE)
	set_center(id, center, view, margins)


## Garante que o controle inteiro fique dentro da área segura.
static func _clamp_center(center: Vector2, size: Vector2, view: Vector2, margins: Vector4) -> Vector2:
	var half: Vector2 = size * 0.5
	var min_c: Vector2 = Vector2(margins.x, margins.y) + half
	var max_c: Vector2 = view - Vector2(margins.z, margins.w) - half
	return Vector2(clampf(center.x, min_c.x, maxf(min_c.x, max_c.x)), clampf(center.y, min_c.y, maxf(min_c.y, max_c.y)))
