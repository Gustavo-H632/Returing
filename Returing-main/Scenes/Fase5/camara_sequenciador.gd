class_name CamaraSequenciador
extends Node
## Cronograma FIXO de uma sala: dispara as máquinas FILHAS, uma de cada vez, na ordem dos filhos
## (a ordem do .tscn é a ordem de disparo; o jogador aprende a sequência).
##
## A vaga de cada máquina é fixa: a vaga n dispara em  atraso_inicial + n x intervalo_disparos  e de novo a
## cada ciclo (nº de máquinas x intervalo). Ao destruir uma máquina a vaga dela fica vazia (a sala fica mais
## fácil a cada acerto) e NADA das outras se desloca: por isso a folga mínima de 2,6 s entre chegadas de
## raios, provada em tools/validar_camara.py com todas as máquinas vivas, vale com qualquer subconjunto.

## O cronograma começou (ou voltou a correr).
signal iniciado
## Todas as máquinas da sala foram destruídas: nada mais dispara.
signal esvaziado

## Segundos entre o início do aviso de uma máquina e o da seguinte. Com 10 máquinas isto é limitado pela
## folga de 2,6 s entre chegadas de raios no mesmo ponto (tools/camara_cronograma.py calcula o mínimo).
@export_range(0.5, 20.0, 0.05, "or_greater") var intervalo_disparos: float = 2.4
## Segundos entre ligar o cronograma (jogador entrou na sala) e o primeiro aviso.
@export_range(0.0, 10.0, 0.1, "or_greater") var atraso_inicial: float = 3.0
## True pula as vagas vazias. Deixa a sala mais viva, mas as chegadas deixam de ter a folga provada.
@export var compactar_vagas: bool = false

var ativo: bool = false  # True enquanto o cronograma corre.

var _relogio: float = 0.0  # Tempo desde que o cronograma ligou.
var _vaga: int = 0  # Próxima vaga a disparar.
var _proximo: float = 0.0  # Instante (no relógio) do próximo disparo.


## O cronograma só roda depois de `iniciar()`.
func _ready() -> void:
	add_to_group(&"camara_sequenciador")
	set_physics_process(false)


## Liga o cronograma do zero.
func iniciar() -> void:
	if ativo:
		return
	ativo = true
	_relogio = 0.0
	_vaga = 0
	_proximo = atraso_inicial
	set_physics_process(true)
	iniciado.emit()


## Desliga o cronograma e apaga todas as máquinas (aviso e feixe).
func parar() -> void:
	ativo = false
	set_physics_process(false)
	for m: CamaraMaquina in maquinas():
		m.parar()


## Máquinas da sala, na ordem de disparo.
func maquinas() -> Array[CamaraMaquina]:
	var lista: Array[CamaraMaquina] = []
	for filho: Node in get_children():
		if filho is CamaraMaquina:
			lista.append(filho as CamaraMaquina)
	return lista


## Quantas máquinas ainda estão de pé.
func vivas() -> int:
	var n: int = 0
	for m: CamaraMaquina in maquinas():
		if not m.is_dead():
			n += 1
	return n


## Segundos até o próximo AVISO da máquina (para a depuração). -1 se o cronograma está parado ou ela morreu.
func tempo_para_disparo(maquina: CamaraMaquina) -> float:
	if not ativo or maquina.is_dead():
		return -1.0
	var lista: Array[CamaraMaquina] = maquinas()
	var indice: int = lista.find(maquina)
	if indice < 0:
		return -1.0
	var ciclo: float = intervalo_disparos * lista.size()
	var alvo: float = atraso_inicial + indice * intervalo_disparos
	var falta: float = alvo - _relogio
	if falta < 0.0:
		falta = fposmod(falta, ciclo)
	return falta


## Dispara a vaga da vez quando o relógio chega nela.
func _physics_process(delta: float) -> void:
	_relogio += delta
	while ativo and _relogio >= _proximo:
		_disparar_vaga()


## Dispara a máquina da vaga atual e agenda a seguinte.
func _disparar_vaga() -> void:
	var lista: Array[CamaraMaquina] = maquinas()
	if lista.is_empty() or vivas() == 0:
		ativo = false
		set_physics_process(false)
		esvaziado.emit()
		return
	var maquina: CamaraMaquina = lista[_vaga % lista.size()]
	if compactar_vagas and maquina.is_dead():
		_vaga = (_vaga + 1) % lista.size()
		return  # pula a vaga vazia sem gastar intervalo
	maquina.disparar()  # devolve false se já destruída: a vaga fica vazia
	_vaga = (_vaga + 1) % lista.size()
	_proximo += intervalo_disparos
