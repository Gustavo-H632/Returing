class_name DebugOverlay
extends CanvasLayer
## Depuração do labirinto (tecla F3 = ação "debug_overlay"). Três modos em ciclo:
##   0 desligado | 1 contornos com o escuro normal (confere vazamento de luz)
##   2 contornos + luz ambiente alta (confere o alinhamento com a arte).
## Verde = colisão de parede, ciano = oclusor de luz, vermelho = fogo, amarelo = porta/chave/painéis,
## magenta = pontos de patrulha, branco = alcance da luz.

enum Mode { OFF, LINHAS, LINHAS_E_LUZ }

## Luz ambiente no modo 2 (o escuro normal fica na cena).
@export var ambient_bright: Color = Color(0.82, 0.86, 0.95, 1.0)

@export_group("Referências (já ligadas na cena)")
@export var colisoes: Node2D  # Nó com as colisões das paredes.
@export var oclusores: Node2D  # Nó com os oclusores de luz.
@export var escuridao: CanvasModulate  # Escuro da fase.
@export var luz: PlayerLight  # Luz do jogador (para desenhar o alcance).
@export var linhas: Node2D  # Nó que desenha os contornos (debug_lines.gd).
@export var rotulo: Label  # Texto do modo atual.

var mode: Mode = Mode.OFF  # Modo atual.
var _dark_color: Color = Color.BLACK  # Cor do escuro da cena (restaurada ao desligar).


## Guarda a cor original do escuro e começa desligado.
func _ready() -> void:
	if escuridao != null:
		_dark_color = escuridao.color
	_apply_mode()


## F3 avança o modo.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_overlay"):
		mode = ((int(mode) + 1) % Mode.size()) as Mode
		_apply_mode()


## Mantém o desenho colado no mundo (acompanha a câmera) enquanto ligado.
func _process(_delta: float) -> void:
	if mode != Mode.OFF and linhas != null:
		linhas.transform = get_viewport().get_canvas_transform()


## Liga ou desliga o desenho, o rótulo e a luz ambiente.
func _apply_mode() -> void:
	if linhas != null:
		linhas.visible = mode != Mode.OFF
		linhas.queue_redraw()
	if rotulo != null:
		rotulo.visible = mode != Mode.OFF
		rotulo.text = "F3 - depuração (%s)" % ["", "contornos", "contornos + luz alta"][int(mode)]
	if escuridao != null:
		escuridao.color = ambient_bright if mode == Mode.LINHAS_E_LUZ else _dark_color
