class_name CrystalTransition
extends Node
## Transição do cristal (fim da sala nova -> fase de defesa). Roda em cima da cena atual:
##   1. glitch curto (tremida + aberração de cor, como nas cutscenes)
##   2. tela de chiado (ruído procedural) que revela o fundo preto
##   3. todas as falas em sequência, direto sobre a tela preta, no visual da voz do tutorial
##      (texto azul, sem trocar para uma cutscene)
## Segurar ESC pula tudo. No fim emite `finished` e pede a próxima cena ao EventBus (o Global faz o fade).

signal finished  # A sequência acabou (a troca de cena já foi pedida).

# ===== BALANCEAMENTO =====
const GLITCH_TIME: float = 0.9  # Duração do glitch inicial (s).
const STATIC_TIME_1: float = 1.2  # Primeiro chiado (s).
const STATIC_FADE: float = 0.3  # Tempo do chiado sumindo (s).

@export_file("*.tscn") var next_scene: String = "res://Scenes/Defesa/Defesa.tscn"
## Falas, em sequência, no estilo da voz do tutorial (texto azul sobre a tela preta).
@export var lines: PackedStringArray = [
	"Você conseguiu!",
	"Na verdade não... isso era uma armadilha.",
	"Descobri uma rota de fuga. Defenda-a até ela ligar.",
]

var _fx: ScreenGlitch = null  # Efeitos de tela.
var _running: bool = false  # True depois de start() (não roda duas vezes).


## Dispara a sequência. Devolve na hora; use `await transition.finished` para esperar.
func start() -> void:
	if _running:
		return
	_running = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fx = ScreenGlitch.new()
	add_child(_fx)
	_run()


## Sequência completa (corrotina).
func _run() -> void:
	await _fx.glitch(GLITCH_TIME)
	await _fx.play_static(STATIC_TIME_1, true)  # O chiado fica ligado enquanto o fundo preto aparece por baixo.
	await _fx.fade_black(1.0, 0.01)
	_fx.stop_static(STATIC_FADE)
	await _say(lines)
	finished.emit()
	if not next_scene.is_empty():
		EventBus.scene_change_requested.emit(next_scene)


## Mostra as falas no estilo da voz do tutorial e espera terminar.
func _say(spoken: PackedStringArray) -> void:
	var dialogue: Dialogue = Dialogue.show_lines(self, spoken, Dialogue.Style.VOICE)
	await dialogue.finished
