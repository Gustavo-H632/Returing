extends Node
## Autoload Platform: ÚNICO lugar que decide em que plataforma o jogo roda e concentra os ajustes que
## dependem disso. Nenhum outro script deve chamar `OS.has_feature("android")` e afins.
##
## - Computador (Windows, Linux, macOS): teclado e mouse, nada muda no jogo.
## - Celular/tablet (Android, iOS, iPad): controles de toque (veja `MobileControls`).
##
## Para testar o modo celular no PC: abra o jogo com o argumento de usuário `--mobile`
## (ex.: godot --path . -- --mobile). O mouse passa a simular o toque. Notebook com tela de toque
## continua em modo computador (só o argumento liga a simulação).
##
## Outros argumentos de usuário (só para testes/depuração):
##   --platform=ios|android   plataforma simulada para o mapeamento do acelerômetro
##   --landscape-reverse      simula a paisagem invertida
##   --debug-tilt             liga o overlay de depuração do acelerômetro

## Argumento de usuário que liga o modo celular no PC (godot --path . -- --mobile).
const SIM_ARG: String = "--mobile"
const PLATFORM_ARG_PREFIX: String = "--platform="  # Prefixo do argumento que simula Android/iOS.
const REVERSE_ARG: String = "--landscape-reverse"  # Simula a paisagem invertida.
const DEBUG_TILT_ARG: String = "--debug-tilt"  # Liga o overlay do acelerômetro.

# --- Ajustes do modo celular (mexa aqui para calibrar) ---

## Tamanho dos sprites no celular: 1.5 = 150% do tamanho original (personagens, inimigos e tiros).
const MOBILE_SPRITE_SCALE: float = 1.5
## Zoom da câmera no celular: 2.0 = enxerga metade da área (câmera mais próxima, seguindo o player).
const MOBILE_CAMERA_ZOOM: float = 2.0
## Carga mínima de um tiro dado só com um toque rápido (0.0 a 1.0).
const MOBILE_MIN_SHOT_CHARGE: float = 0.2
## Menor lado de um alvo de toque (botões de menu, sliders), em px lógicos: equivale a ~48 dp num celular em
## paisagem (tela lógica de 648 px de altura para ~430 dp => 1 dp ~ 1,5 px lógico).
const MIN_TOUCH: float = 72.0

## Nomes de plataforma devolvidos por `platform_name()`.
const ANDROID: String = "android"
const IOS: String = "ios"
const WINDOWS: String = "windows"
const LINUX: String = "linux"
const MACOS: String = "macos"
const WEB: String = "web"

## True só com `--mobile` no PC: o mouse faz o papel do dedo.
var simulated: bool = false
## True quando o mouse deve funcionar como um dedo nos controles de toque (`--mobile` no PC e navegador).
var mouse_as_finger: bool = false
## Multiplicador de tamanho dos sprites (1.0 no PC).
var sprite_scale: float = 1.0
## Zoom da câmera de seguimento (1.0 no PC).
var camera_zoom: float = 1.0
## Mira assistida (o tiro curva um pouco para o inimigo). Só no celular.
var aim_assist: bool = false
## Carga mínima do tiro (0.0 no PC).
var min_shot_charge: float = 0.0
## Overlay de depuração do acelerômetro (flag `--debug-tilt`).
var debug_tilt: bool = false
## Paisagem invertida simulada (flag `--landscape-reverse`); em aparelho real vem do sistema.
var simulated_reverse_landscape: bool = false

## Avisa quando a área segura muda (girar o aparelho, testes).
signal safe_area_changed

## Recuos da área segura forçados pelos testes, em px da JANELA: esquerda, topo, direita, base (null = usar o sistema).
var _safe_override: Variant = null

var _mobile: bool = false  # True no Android, iOS (ou navegador com toque) e com `--mobile`.
var _name_override: String = ""  # Plataforma forçada por `--platform=` ou pelos testes.


## Roda antes de qualquer outro nó (mesmo antes do _ready) para que os outros scripts já leiam os valores certos.
## Decide se é celular ou PC e preenche todos os ajustes que dependem disso.
func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	simulated = args.has(SIM_ARG)  # O argumento `--mobile` liga a simulação no PC.
	debug_tilt = args.has(DEBUG_TILT_ARG)
	simulated_reverse_landscape = args.has(REVERSE_ARG)
	for arg: String in args:  # `--platform=ios` escolhe a plataforma simulada.
		if arg.begins_with(PLATFORM_ARG_PREFIX):
			_name_override = arg.trim_prefix(PLATFORM_ARG_PREFIX).to_lower()
	# Celular de verdade (Android/iOS) ou simulação.
	_mobile = is_real_device() or simulated
	if not _mobile and OS.has_feature("web"):  # Navegador: confere se o aparelho tem tela de toque.
		# Tela de toque do Godot ou User-Agent de Android/iPhone/iPad.
		_mobile = DisplayServer.is_touchscreen_available() or _web_is_touch_device()
	# No navegador e na simulação o mouse faz o papel do dedo.
	mouse_as_finger = simulated or (_mobile and OS.has_feature("web"))
	_apply_mobile_tuning()


## Chamado quando o autoload entra na cena. No celular impede que a tela apague durante a partida.
func _ready() -> void:
	# Só mexe na tela em aparelhos de verdade, não na simulação do PC.
	if _mobile and not simulated and is_real_device():
		DisplayServer.screen_set_keep_on(true)  # a tela não apaga no meio da partida
	if _mobile:  # a área segura em px lógicos muda quando a janela muda de tamanho
		get_tree().root.size_changed.connect(func() -> void: safe_area_changed.emit())


## True em celular/tablet (Android, iOS, iPad) ou com `--mobile`.
func is_mobile() -> bool:
	return _mobile


## True só em aparelho de verdade (Android ou iOS), nunca na simulação `--mobile` do PC. É onde existem
## sensores, área segura (notch) e a tela não pode apagar.
func is_real_device() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios")


## False onde o jogo não deve oferecer "Sair" (iOS e navegador não fecham o app por botão).
func can_quit() -> bool:
	return not (OS.has_feature("ios") or OS.has_feature("web"))


## True em Windows, Linux e macOS (tudo que não é celular).
func is_desktop() -> bool:
	return not _mobile


## Nome da plataforma: "android", "ios", "windows", "linux", "macos" ou "web".
func platform_name() -> String:
	if not _name_override.is_empty():
		return _name_override
	if OS.has_feature("android"):
		return ANDROID
	if OS.has_feature("ios"):
		return IOS
	if OS.has_feature("web"):
		return WEB
	if OS.has_feature("windows"):
		return WINDOWS
	if OS.has_feature("macos"):
		return MACOS
	return LINUX


## True no Android (ou simulando Android).
func is_android() -> bool:
	return platform_name() == ANDROID


## True no iOS/iPadOS (ou simulando iOS).
func is_ios() -> bool:
	return platform_name() == IOS


## Orientação de paisagem atual (valores de `TiltLogic.Orientation`): paisagem normal ou invertida.
func landscape_orientation() -> int:
	if simulated_reverse_landscape:
		return TiltLogic.Orientation.LANDSCAPE_REVERSE
	if not is_real_device():
		return TiltLogic.Orientation.LANDSCAPE
	var current: int = DisplayServer.screen_get_orientation()
	if current == DisplayServer.SCREEN_REVERSE_LANDSCAPE:
		return TiltLogic.Orientation.LANDSCAPE_REVERSE
	return TiltLogic.Orientation.LANDSCAPE


## Área segura da tela em coordenadas LÓGICAS do jogo (as mesmas dos Controls): o retângulo que não fica sob o
## notch, os cantos arredondados, a barra de gestos do Android ou a barra home do iOS. No computador é a tela toda.
func get_safe_rect() -> Rect2:
	var view: Vector2 = _view_size()
	var m: Vector4 = get_safe_margins()
	return Rect2(m.x, m.y, maxf(view.x - m.x - m.z, 1.0), maxf(view.y - m.y - m.w, 1.0))


## Recuos da área segura em px lógicos: esquerda, topo, direita, base.
func get_safe_margins() -> Vector4:
	var view: Vector2 = _view_size()
	var window: Vector2 = _window_size()
	if window.x <= 0.0 or window.y <= 0.0:
		return Vector4.ZERO
	var k: Vector2 = view / window  # px da janela -> px lógicos
	if _safe_override != null:
		var o: Vector4 = _safe_override
		return Vector4(o.x * k.x, o.y * k.y, o.z * k.x, o.w * k.y)
	if not is_real_device():
		return Vector4.ZERO
	var screen: Vector2 = Vector2(DisplayServer.screen_get_size())
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if screen.x <= 0.0 or safe.size.x <= 0:
		return Vector4.ZERO
	return Vector4(float(safe.position.x) * k.x, float(safe.position.y) * k.y,
			maxf(screen.x - float(safe.end.x), 0.0) * k.x, maxf(screen.y - float(safe.end.y), 0.0) * k.y)


## Testes: simula notch/barras com recuos em px da janela (esquerda, topo, direita, base). `null` volta ao sistema.
func set_safe_insets_override(insets: Variant) -> void:
	_safe_override = insets
	safe_area_changed.emit()


## Tamanho da janela em px reais (a raiz da árvore; vale também em headless, onde não há janela do sistema).
func _window_size() -> Vector2:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return Vector2(DisplayServer.window_get_size())
	return Vector2(tree.root.size)


func _view_size() -> Vector2:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return Vector2(1152.0, 648.0)
	return tree.root.get_visible_rect().size


## Liga/desliga o modo celular em tempo de execução (só para os testes automáticos e o editor).
## Os scripts que já leram o valor no `_ready` não são refeitos: troque antes de criar as cenas.
func force_mobile(value: bool) -> void:
	_mobile = value
	simulated = value
	mouse_as_finger = value
	_apply_mobile_tuning()


## Força o nome da plataforma (testes do mapeamento do acelerômetro). Vazio = detectar de novo.
func force_platform_name(value: String) -> void:
	_name_override = value


## Aplica os ajustes de sprite, câmera e mira conforme o modo atual.
func _apply_mobile_tuning() -> void:
	if _mobile:  # Só no celular os ajustes mudam; no PC ficam os valores originais.
		sprite_scale = MOBILE_SPRITE_SCALE  # Sprites maiores.
		camera_zoom = MOBILE_CAMERA_ZOOM  # Câmera mais próxima.
		aim_assist = true  # Liga a mira assistida do tiro.
		min_shot_charge = MOBILE_MIN_SHOT_CHARGE  # Tiro mínimo para o toque rápido.
	else:
		sprite_scale = 1.0
		camera_zoom = 1.0
		aim_assist = false
		min_shot_charge = 0.0


## Navegador de celular/tablet (inclui iPad, que o Safari anuncia como Mac com tela de toque).
func _web_is_touch_device() -> bool:
	if not OS.has_feature("web"):
		return false
	var script: String = "(/Android|iPhone|iPad|iPod/i.test(navigator.userAgent)) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)"
	return JavaScriptBridge.eval(script, true) == true
