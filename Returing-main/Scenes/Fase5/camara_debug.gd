class_name CamaraDebug
extends CanvasLayer
## Depuração da Câmara de Provas (tecla F3 = ação "debug_overlay"). Liga/desliga o desenho de:
## colisões (verde), faixas de cada máquina (laranja), hurtboxes (amarelo), a linha do raio na varredura (vermelho),
## linhas de tiro do Player até cada máquina (verde = livre, vermelho = bloqueada) e a lista das janelas dos
## raios (fase de cada máquina e segundos até o próximo aviso).

## Quanto tempo (s) o texto das janelas demora para atualizar.
@export_range(0.02, 1.0, 0.01) var periodo_texto: float = 0.1

@export_group("Referências (já ligadas na cena)")
@export var colisoes: Node2D  # Nó com as colisões das paredes.
@export var linhas: Node2D  # Nó que desenha os contornos (camara_debug_linhas.gd).
@export var rotulo: Label  # Texto com as janelas dos raios.

var ligado: bool = false  # True enquanto o desenho está ativo.

var _acumulado: float = 0.0  # Tempo desde a última atualização do texto.


## Começa desligado.
func _ready() -> void:
	_aplicar()


## F3 liga e desliga.
func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed(&"debug_overlay"):
		ligado = not ligado
		_aplicar()


## Mantém o desenho colado no mundo (acompanha a câmera) e atualiza o texto das janelas.
func _process(delta: float) -> void:
	if not ligado:
		return
	if linhas != null:
		linhas.transform = get_viewport().get_canvas_transform()
		linhas.queue_redraw()
	_acumulado += delta
	if _acumulado >= periodo_texto:
		_acumulado = 0.0
		_atualizar_texto()


## Liga ou desliga o desenho e o rótulo.
func _aplicar() -> void:
	set_process(ligado)
	if linhas != null:
		linhas.visible = ligado
		linhas.queue_redraw()
	if rotulo != null:
		rotulo.visible = ligado
		_atualizar_texto()


## Lista cada máquina: fase atual e tempo até o próximo aviso.
func _atualizar_texto() -> void:
	if rotulo == null or not ligado:
		return
	var texto: PackedStringArray = ["F3 - depuração (colisões, faixas, linhas de tiro, janelas dos raios)"]
	for seq_node: Node in get_tree().get_nodes_in_group(&"camara_sequenciador"):
		var seq := seq_node as CamaraSequenciador
		if seq == null:
			continue
		texto.append("%s  (intervalo %.2f s, %s)" % [seq.name, seq.intervalo_disparos, "ativa" if seq.ativo else "parada"])
		for m: CamaraMaquina in seq.maquinas():
			var falta: float = seq.tempo_para_disparo(m)
			var proximo: String = "-" if falta < 0.0 else "%.1f s" % falta
			texto.append("  %-4s %-10s fase %.1f s   próximo aviso em %s" % [
				m.name, CamaraMaquina.Estado.keys()[m.estado], m.tempo_no_estado, proximo])
	rotulo.text = "\n".join(texto)
