class_name TiltLogic
extends RefCounted
## Lógica PURA do modo comando por inclinação (sem nós, sem relógio): vetor do acelerômetro +
## calibração + plataforma + orientação -> direção (ou nenhuma). Fácil de testar.
##
## Convenções
## - "Gravidade em tela": vetor da gravidade no sistema da tela em paisagem (x = direita da tela,
##   y = em cima da tela, z = para fora da tela). Com o celular em pé em paisagem vale (0, -g, 0).
## - Inclinação (`tilt`): vetor 2D em coordenadas de UI (x para a direita, y para BAIXO), medido a
##   partir da posição neutra calibrada e em unidades de "seno do ângulo" (0,26 ≈ 15 graus).
##   Imagine uma bolinha numa bandeja: ela rola para a borda que desceu.
##     direita  = borda direita desce      esquerda = borda esquerda desce
##     cima     = borda de cima desce (longe do jogador)      baixo = borda de baixo desce
##
## O que o Godot entrega (verificado no código-fonte do Godot 4.x):
## - Android: `GodotInputHandler` gira os valores do sensor pela rotação do display (ROTATION_0/90/180/270)
##   e `InputEventRunnable` os nega: sai a gravidade no sistema da TELA, em m/s².
## - iOS: `godot_view.mm` gira a gravidade+aceleração pela orientação da interface e converte g -> m/s².
## Ou seja, nas duas plataformas, com o Godot atual, o vetor já vem no sistema da tela (`Frame.SCREEN`)
## e a plataforma/orientação não mudam nada. O modo `Frame.RAW` existe como rede de segurança (versão do
## Godot que não gire os eixos): aí o mapeamento por plataforma e orientação abaixo é aplicado.

## Em que sistema de eixos está o vetor recebido.
enum Frame {
	SCREEN,  # Já girado para a tela (comportamento do Godot 4.x no Android e no iOS).
	RAW,  # Sistema natural do aparelho (retrato), sem girar: precisa do mapeamento.
	AUTO,  # Decide sozinho (veja `detect_frame`).
}

## Orientações de paisagem. O nome diz para onde aponta o TOPO NATURAL do aparelho (retrato).
enum Orientation {
	LANDSCAPE,  # topo natural para a esquerda (Android ROTATION_90, iOS LandscapeRight).
	LANDSCAPE_REVERSE,  # topo natural para a direita (Android ROTATION_270, iOS LandscapeLeft).
}

## Valores de `AbilityData.Dir` (cópia local para a lógica não depender do jogo).
const DIR_NONE: int = -1
const DIR_UP: int = 0
const DIR_DOWN: int = 1
const DIR_LEFT: int = 2
const DIR_RIGHT: int = 3

## Inclinação (seno do ângulo) padrão que dispara uma seta e zona morta padrão (volta ao neutro).
const BASE_THRESHOLD: float = 0.26
const BASE_DEADZONE: float = 0.12
## Abaixo desta intensidade o vetor é tratado como "sem sensor".
const MIN_MAGNITUDE: float = 0.0001
## Proporção entre eixos para o eixo dominante vencer (evita diagonais ambíguas).
const DOMINANCE: float = 1.25
## No modo RAW, se a gravidade estiver neste ponto do eixo x natural em repouso, o aparelho está em
## paisagem sem ter sido girado pelo Godot.
const RAW_DETECT_X: float = 0.8


## Gravidade em tela a partir do vetor bruto do sensor, conforme o sistema de eixos.
## `platform`: "android" ou "ios" (só importa no modo RAW). `orientation`: valor de `Orientation`.
static func to_screen_gravity(accel: Vector3, platform: String, orientation: int, frame: int = Frame.SCREEN) -> Vector3:
	if frame == Frame.SCREEN:
		return accel
	# RAW: sistema natural do aparelho. O Android entrega a REAÇÃO do apoio (z = +g com a tela para cima);
	# o iOS entrega a gravidade (z = -g). Convertemos tudo para "gravidade".
	var gravity: Vector3 = -accel if platform == "android" else accel
	# Gira do sistema natural (retrato) para o da tela em paisagem.
	if orientation == Orientation.LANDSCAPE:
		return Vector3(-gravity.y, gravity.x, gravity.z)
	return Vector3(gravity.y, -gravity.x, gravity.z)


## Decide se um vetor parado já está no sistema da tela (SCREEN) ou no natural (RAW).
## Em paisagem, segurando o aparelho de forma normal, a gravidade quase não tem componente em x da
## tela; no sistema natural ela fica toda em x. Só vale para o instante da calibração.
static func detect_frame(accel: Vector3) -> int:
	var n: Vector3 = _unit(accel)
	if absf(n.x) > RAW_DETECT_X:
		return Frame.RAW
	return Frame.SCREEN


## Paisagem (normal ou invertida) a partir do vetor BRUTO parado: em paisagem a gravidade natural fica toda no eixo x.
## Com o topo natural à esquerda (`LANDSCAPE`) a gravidade natural tem x < 0; com o topo à direita, x > 0.
static func detect_orientation(raw: Vector3, platform: String) -> int:
	var gravity_x: float = -raw.x if platform == "android" else raw.x
	return Orientation.LANDSCAPE if gravity_x <= 0.0 else Orientation.LANDSCAPE_REVERSE


## Vetor unitário da gravidade em tela (ZERO se o sensor não existir).
static func screen_unit(accel: Vector3, platform: String, orientation: int, frame: int = Frame.SCREEN) -> Vector3:
	return _unit(to_screen_gravity(accel, platform, orientation, frame))


## Inclinação calibrada (UI: x direita, y para baixo) em relação à posição neutra `calibration`
## (um vetor unitário em tela, obtido com `screen_unit` na hora de calibrar).
static func tilt(accel: Vector3, calibration: Vector3, platform: String, orientation: int, frame: int = Frame.SCREEN) -> Vector2:
	return tilt_from_unit(screen_unit(accel, platform, orientation, frame), calibration)


## Mesma coisa a partir de um vetor unitário em tela. Usa a DIFERENÇA DE ÂNGULOS (não de componentes):
## a resposta fica igual com o celular quase em pé ou quase deitado.
static func tilt_from_unit(n: Vector3, calibration: Vector3) -> Vector2:
	if n == Vector3.ZERO or calibration == Vector3.ZERO:
		return Vector2.ZERO
	var now: Vector2 = angles(n)
	var neutral: Vector2 = angles(calibration)
	# Borda direita desce -> `roll` cresce. Borda de cima desce (longe do jogador) -> `pitch` cresce -> seta para cima.
	return Vector2(sin(now.x - neutral.x), -sin(wrapf(now.y - neutral.y, -PI, PI)))


## Ângulos (roll, pitch) em radianos de uma gravidade unitária em tela.
## roll = para que lado a tela está "caindo" (gx); pitch = inclinação para frente/trás em torno do eixo x.
static func angles(n: Vector3) -> Vector2:
	var roll: float = atan2(n.x, sqrt(n.y * n.y + n.z * n.z))
	var pitch: float = atan2(n.y, -n.z)
	return Vector2(roll, pitch)


## Direção de uma inclinação já calibrada: `DIR_*` ou `DIR_NONE` (zona morta, abaixo do limiar ou diagonal ambígua).
## `sensitivity` multiplica a inclinação (2 = metade do ângulo para disparar).
static func direction(tilt_vec: Vector2, sensitivity: float = 1.0, threshold: float = BASE_THRESHOLD) -> int:
	var t: Vector2 = tilt_vec * maxf(sensitivity, 0.01)
	var ax: float = absf(t.x)
	var ay: float = absf(t.y)
	if maxf(ax, ay) < threshold:
		return DIR_NONE
	if ax >= ay * DOMINANCE:
		return DIR_RIGHT if t.x > 0.0 else DIR_LEFT
	if ay >= ax * DOMINANCE:
		return DIR_DOWN if t.y > 0.0 else DIR_UP
	return DIR_NONE  # diagonal: espera o jogador decidir


## A função pura pedida: vetor do acelerômetro + calibração + plataforma + orientação -> direção ou `DIR_NONE`.
static func detect(accel: Vector3, calibration: Vector3, platform: String, orientation: int,
		sensitivity: float = 1.0, frame: int = Frame.SCREEN) -> int:
	return direction(tilt(accel, calibration, platform, orientation, frame), sensitivity)


## True se o vetor parece de um sensor que não existe (tudo zero).
static func is_missing(accel: Vector3) -> bool:
	return accel.length() < MIN_MAGNITUDE


## Normaliza (ZERO se o vetor for nulo).
static func _unit(v: Vector3) -> Vector3:
	if v.length() < MIN_MAGNITUDE:
		return Vector3.ZERO
	return v.normalized()
