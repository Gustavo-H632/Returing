class_name SalaNova
extends Node2D
## Sala nova (destino da porta do labirinto): uma sala simples e iluminada. Tocar no cristal do núcleo
## dispara a transição (glitch -> chiado -> falas em azul sobre tela preta, no estilo da voz do tutorial, ver
## CrystalTransition) e leva à fase de defesa (Defesa.tscn), que por fim segue para o quiz (Fase2.tscn).

## Próxima cena depois da transição do cristal (vazio = última fase).
@export_file("*.tscn") var next_scene: String = "res://Scenes/Defesa/Defesa.tscn"
## Velocidade da animação do núcleo (quadros por segundo).
@export_range(1.0, 20.0, 0.5) var core_fps: float = 4.0

@export_group("Nós da cena")
@export var nucleo: Area2D  # Gatilho no centro da plataforma do núcleo.
@export var nucleo_sprite: Sprite2D  # Sprite do núcleo (3 quadros).

var _done: bool = false  # True depois de concluída (não conclui duas vezes).
var _time: float = 0.0  # Relógio da animação.


## Liga o gatilho do núcleo e avisa que a fase começou.
func _ready() -> void:
	if nucleo == null:
		push_error("SalaNova: 'nucleo' não atribuído no Inspector.")
		return
	nucleo.body_entered.connect(_on_nucleo_body_entered)
	EventBus.level_started.emit()


## Anima o cristal do núcleo.
func _process(delta: float) -> void:
	_time += delta
	if nucleo_sprite != null and nucleo_sprite.hframes > 1:
		nucleo_sprite.frame = int(_time * core_fps) % nucleo_sprite.hframes


## O jogador pisou no cristal: congela o jogador, esconde a HUD, fecha o tempo da fase e roda a transição.
## (Não emite level_completed: a HUD mostraria "Continuar" e a transição já leva à próxima cena.)
func _on_nucleo_body_entered(body: Node2D) -> void:
	if _done or not CombatUtils.is_player(body):
		return
	_done = true
	RunStats.registrar_fim_de_fase()  # Mesmo registro de tempo que o level_completed faria.
	body.set_physics_process(false)  # O jogador fica parado durante a transição.
	var hud: CanvasLayer = get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	var pausa: Node = get_node_or_null("Pause")  # ESC (segurar) pula a transição: o menu de pausa não pode abrir junto.
	if pausa != null:
		pausa.process_mode = Node.PROCESS_MODE_DISABLED
	var aviso: CanvasLayer = get_node_or_null("Aviso") as CanvasLayer
	if aviso != null:
		aviso.visible = false
	var transition: CrystalTransition = CrystalTransition.new()
	transition.next_scene = next_scene
	add_child(transition)
	transition.start()
