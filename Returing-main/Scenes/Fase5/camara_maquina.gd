class_name CamaraMaquina
extends Node2D
## Máquina geradora de raios da Câmara de Provas (a IA "Aegis" só responde a quem prova que pensa).
##
## Cada disparo é um ciclo FIXO:  AVISO (pisca, a faixa mostra tracejado) -> CLARÃO (a boca acende)
## -> VARREDURA (a linha de 10 px anda pela faixa e fere) -> PAUSA.  Nada é aleatório.
## O Player só escapa da linha com o DASH (invulnerável). Para parar a máquina, só o TIRO CARREGADO com
## dano >= `dano_minimo`: tiro fraco é rebatido (faísca) e a espada nem a enxerga (a Hurtbox fica na
## camada 1 "Mundo", que só o tiro lê; a espada só lê a camada 5).
## Sprite, aviso, feixe e hurtbox já estão posicionados de forma ESTÁTICA no .tscn; este script só liga os tempos.

## A máquina foi destruída (já parou de emitir).
signal destruida(maquina: CamaraMaquina)
## Um tiro forte acertou, mas a máquina reforçada ainda está de pé.
signal acertada(maquina: CamaraMaquina, vida_restante: int)
## Um golpe fraco foi rebatido (BLINDADA + faísca).
signal rebatida(maquina: CamaraMaquina, dano: int)

enum Estado { INATIVA, AVISO, CLARAO, VARREDURA, PAUSA, DESTRUIDA }

## Quadros da spritesheet da máquina.
const QUADRO_INATIVA: int = 0
const QUADRO_CARREGANDO_A: int = 1
const QUADRO_CARREGANDO_B: int = 2
const QUADRO_DISPARANDO: int = 3
const QUADRO_BLINDADA: int = 4
const QUADRO_DESTRUIDA: int = 5
## Quadros por segundo das animações (feixe, tracejado do aviso e explosão).
const FPS_ANIMACAO: float = 12.0
## Troca da lente em AVISO (s): a máquina "pisca".
const PERIODO_PISCA: float = 0.14
## Quanto tempo o quadro BLINDADA fica na tela depois de um golpe fraco (s).
const TEMPO_BLINDADA: float = 0.22
## Duração da explosão (s): 5 quadros.
const TEMPO_EXPLOSAO: float = 0.5

@export_group("Ciclo do raio (s)")
## Aviso antes do feixe: a máquina pisca e a faixa mostra o tracejado.
@export_range(0.1, 5.0, 0.05) var tempo_aviso: float = 1.0
## Clarão na boca, logo antes de a linha começar a andar.
@export_range(0.0, 2.0, 0.05) var tempo_clarao: float = 0.4
## Tempo que a linha leva para varrer a faixa inteira.
@export_range(0.2, 6.0, 0.05) var tempo_varredura: float = 2.0
## Pausa depois da varredura (a máquina volta a ficar inativa).
@export_range(0.0, 10.0, 0.1, "or_greater") var tempo_pausa: float = 1.6

@export_group("Raio")
## Dano de cada tick da linha (o dash recusa o dano: o Player fica invulnerável).
@export_range(1, 1000) var dano_raio: int = 120
## Segundos entre dois danos seguidos se o jogador continuar tocando a linha.
@export_range(0.05, 2.0, 0.05) var intervalo_dano: float = 0.15
## Sentido em que a linha anda (um dos 4 eixos).
@export var direcao: Vector2 = Vector2.DOWN
## Distância que a linha percorre na varredura (px).
@export_range(16.0, 4000.0, 1.0, "or_greater") var distancia: float = 400.0

@export_group("Vida")
## False = decoração indestrutível (Sala 1): não tem Hurtbox.
@export var destrutivel: bool = true
## True = reforçada (precisa de mais de um tiro carregado).
@export var reforcada: bool = false
## Tiros carregados que a máquina normal aguenta.
@export_range(1, 10) var vida_normal: int = 1
## Tiros carregados que a reforçada aguenta.
@export_range(1, 10) var vida_reforcada: int = 2
## Dano mínimo que a máquina aceita (carga >= 52 %: 10 + 58 x 0,517 = 40). Abaixo disso o golpe é rebatido.
@export_range(1, 200) var dano_minimo: int = 40

@export_group("Referências (já ligadas na cena)")
@export var corpo: Sprite2D  # Spritesheet da máquina (6 quadros).
@export var aviso: Sprite2D  # Faixa tracejada que aparece durante o AVISO.
@export var feixe: Hitbox  # A linha do raio (a Hitbox do projeto, camada de dano do Player).
@export var feixe_forma: CollisionShape2D  # Forma retangular do feixe (10 px de espessura).
@export var feixe_imagem: Sprite2D  # Arte do feixe (4 quadros).
@export var hurtbox: Hurtbox  # Área que o tiro carregado acerta (só nas destrutíveis).
@export var saude: HealthComponent  # Vida da máquina (só nas destrutíveis).
@export var explosao: Sprite2D  # 5 quadros de explosão.

var estado: Estado = Estado.INATIVA  # Fase atual do ciclo.
var tempo_no_estado: float = 0.0  # Segundos desde que a fase atual começou.

var _feixe_inicio: Vector2 = Vector2.ZERO  # Posição local de partida do feixe (vem do .tscn).
var _relogio: float = 0.0  # Tempo corrido desde o disparo (anima o feixe e o tracejado).
var _blindada_restante: float = 0.0  # Tempo restante do quadro BLINDADA.
var _flash: Tween = null  # Pisca ao levar um tiro forte (guardado para cancelar).


## Guarda o ponto de partida do feixe, liga a vida e deixa tudo apagado.
func _ready() -> void:
	add_to_group(&"camara_maquina")
	var faltando: PackedStringArray = []
	if corpo == null: faltando.append("corpo")
	if feixe == null: faltando.append("feixe")
	if feixe_forma == null: faltando.append("feixe_forma")
	if destrutivel and (hurtbox == null or saude == null):
		faltando.append("hurtbox/saude")
	if not faltando.is_empty():
		push_error("CamaraMaquina '%s': referências não atribuídas: %s" % [name, ", ".join(faltando)])
		set_physics_process(false)
		return
	_feixe_inicio = feixe.position
	feixe.damage = dano_raio
	feixe.configure(dano_raio, false, intervalo_dano)  # dano contínuo enquanto tocar a linha
	feixe.source = self
	_desligar_feixe()
	if aviso != null:
		aviso.visible = false
	if explosao != null:
		explosao.visible = false
	if saude != null:
		saude.setup(vida_reforcada if reforcada else vida_normal)
		CombatUtils.connect_once(saude.died, _on_saude_morreu)
	_mostrar_quadro(QUADRO_INATIVA)
	set_physics_process(false)  # só roda enquanto há ciclo, golpe rebatido ou explosão


## Começa um ciclo (AVISO -> CLARÃO -> VARREDURA -> PAUSA). Devolve false se já está ocupada ou destruída.
func disparar() -> bool:
	if estado != Estado.INATIVA:
		return false
	_relogio = 0.0
	tempo_no_estado = 0.0
	_entrar(Estado.AVISO)
	set_physics_process(true)
	return true


## Interrompe o ciclo e apaga aviso e feixe (a máquina destruída não volta).
func parar() -> void:
	if estado == Estado.DESTRUIDA:
		return
	_apagar_efeitos()
	estado = Estado.INATIVA
	tempo_no_estado = 0.0
	_mostrar_quadro(QUADRO_INATIVA)
	if _blindada_restante <= 0.0:
		set_physics_process(false)


## True enquanto a máquina está em algum ponto do ciclo (não aceita novo disparo).
func ocupada() -> bool:
	return estado != Estado.INATIVA


## Duração total de um ciclo (s).
func duracao_do_ciclo() -> float:
	return tempo_aviso + tempo_clarao + tempo_varredura + tempo_pausa


## Instante (s desde o início do aviso) em que a linha começa a andar e a ferir.
func inicio_da_varredura() -> float:
	return tempo_aviso + tempo_clarao


## API de dano do projeto (Hurtbox -> ator). Só o tiro carregado forte conta; devolve false se foi ignorado.
func take_damage(amount: int, _source: Variant = null) -> bool:
	if not destrutivel or is_dead():
		return false
	if amount < dano_minimo:
		_rebater(amount)
		return false
	var aplicado: int = saude.take_damage(1)  # cada tiro forte tira 1 ponto de vida
	if aplicado <= 0:
		return false
	if not saude.is_dead():
		acertada.emit(self, saude.current_health)
		_flash = CombatUtils.flash_sprite(corpo, _flash, Color(2.0, 1.5, 0.7, 1.0), 0.18)
	return true


## True depois de destruída (o projeto pergunta isto a qualquer alvo).
func is_dead() -> bool:
	return estado == Estado.DESTRUIDA


## Retângulo global da linha neste instante (vazio fora da varredura). Usado pela depuração e pelos testes.
func segmento_global() -> Rect2:
	if feixe == null or feixe_forma == null or not feixe.is_active():
		return Rect2()
	var tamanho: Vector2 = (feixe_forma.shape as RectangleShape2D).size
	return Rect2(feixe.global_position - tamanho * 0.5, tamanho)


## Ponto global onde o tiro deve acertar (centro da Hurtbox). Sem Hurtbox devolve o centro da máquina.
func alvo_global() -> Vector2:
	return hurtbox.global_position if hurtbox != null else global_position


## Corre o ciclo, o quadro BLINDADA e a explosão (a física só fica ligada enquanto algo disso acontece).
func _physics_process(delta: float) -> void:
	_relogio += delta
	if _blindada_restante > 0.0:
		_blindada_restante -= delta
		if _blindada_restante <= 0.0:
			_mostrar_quadro(_quadro_do_estado())
	if estado == Estado.INATIVA or estado == Estado.DESTRUIDA:
		if _blindada_restante <= 0.0:
			set_physics_process(false)
		return
	tempo_no_estado += delta
	while estado != Estado.INATIVA and tempo_no_estado >= _duracao(estado):
		tempo_no_estado -= _duracao(estado)
		_proxima_fase()
	_atualizar_visual()


# --- Fases ---

## Duração de cada fase do ciclo (s).
func _duracao(e: Estado) -> float:
	match e:
		Estado.AVISO: return tempo_aviso
		Estado.CLARAO: return tempo_clarao
		Estado.VARREDURA: return tempo_varredura
		Estado.PAUSA: return tempo_pausa
	return 0.0


## Passa para a fase seguinte (depois da PAUSA a máquina volta a INATIVA).
func _proxima_fase() -> void:
	match estado:
		Estado.AVISO: _entrar(Estado.CLARAO)
		Estado.CLARAO: _entrar(Estado.VARREDURA)
		Estado.VARREDURA: _entrar(Estado.PAUSA)
		_: _entrar(Estado.INATIVA)


## Liga o que a fase pede: aviso, clarão, feixe ferindo ou tudo apagado.
func _entrar(novo: Estado) -> void:
	estado = novo
	match novo:
		Estado.AVISO:
			_apagar_efeitos()
			if aviso != null:
				aviso.visible = true
		Estado.CLARAO:
			if aviso != null:
				aviso.visible = false
			_posicionar_feixe(0.0)
			feixe.visible = true  # aparece na boca, mas só fere na VARREDURA
		Estado.VARREDURA:
			_posicionar_feixe(0.0)
			feixe.visible = true
			feixe.set_active(true)
		Estado.PAUSA:
			_desligar_feixe()
		Estado.INATIVA:
			_apagar_efeitos()
	_mostrar_quadro(_quadro_do_estado())
	_atualizar_visual()


## Atualiza posição do feixe, tracejado do aviso e lente conforme a fase.
func _atualizar_visual() -> void:
	match estado:
		Estado.AVISO:
			var piscar: int = int(tempo_no_estado / PERIODO_PISCA) % 2
			if _blindada_restante <= 0.0:
				_mostrar_quadro(QUADRO_CARREGANDO_A if piscar == 0 else QUADRO_CARREGANDO_B)
			if aviso != null:
				aviso.frame = int(_relogio * FPS_ANIMACAO) % maxi(aviso.hframes, 1)
				aviso.modulate.a = 1.0 if piscar == 0 else 0.55
		Estado.CLARAO, Estado.VARREDURA:
			var progresso: float = 0.0
			if estado == Estado.VARREDURA:
				progresso = clampf(tempo_no_estado / maxf(tempo_varredura, 0.01), 0.0, 1.0)
			_posicionar_feixe(progresso)
			if feixe_imagem != null:
				feixe_imagem.frame = int(_relogio * FPS_ANIMACAO) % maxi(feixe_imagem.hframes, 1)


## Põe o feixe no ponto `progresso` (0 a 1) do caminho.
func _posicionar_feixe(progresso: float) -> void:
	feixe.position = _feixe_inicio + direcao.normalized() * distancia * progresso


## Apaga aviso e feixe.
func _apagar_efeitos() -> void:
	if aviso != null:
		aviso.visible = false
	_desligar_feixe()


## Desliga a Hitbox do feixe e esconde a arte.
func _desligar_feixe() -> void:
	feixe.set_active(false)
	feixe.visible = false
	feixe.position = _feixe_inicio


## Quadro da máquina para a fase atual.
func _quadro_do_estado() -> int:
	match estado:
		Estado.CLARAO, Estado.VARREDURA: return QUADRO_DISPARANDO
		Estado.AVISO: return QUADRO_CARREGANDO_A
		Estado.DESTRUIDA: return QUADRO_DESTRUIDA
	return QUADRO_INATIVA


## Mostra um quadro da spritesheet (o golpe rebatido tem prioridade enquanto durar).
func _mostrar_quadro(quadro: int) -> void:
	if corpo != null:
		corpo.frame = QUADRO_BLINDADA if _blindada_restante > 0.0 and estado != Estado.DESTRUIDA else quadro


# --- Dano ---

## Golpe fraco: quadro BLINDADA com faísca por um instante.
func _rebater(dano: int) -> void:
	_blindada_restante = TEMPO_BLINDADA
	_mostrar_quadro(_quadro_do_estado())
	set_physics_process(true)
	rebatida.emit(self, dano)


## A vida chegou a zero.
func _on_saude_morreu() -> void:
	_destruir()


## Para de emitir, desliga a Hurtbox, mostra a carcaça e toca a explosão.
func _destruir() -> void:
	if estado == Estado.DESTRUIDA:
		return
	_apagar_efeitos()
	estado = Estado.DESTRUIDA
	tempo_no_estado = 0.0
	_blindada_restante = 0.0
	if hurtbox != null:
		hurtbox.set_active(false)
	CombatUtils.kill_flash(corpo, _flash)
	_mostrar_quadro(QUADRO_DESTRUIDA)
	_tocar_explosao()
	set_physics_process(false)
	destruida.emit(self)


## Explosão de 5 quadros por cima da carcaça.
func _tocar_explosao() -> void:
	if explosao == null:
		return
	explosao.visible = true
	explosao.frame = 0
	var tween: Tween = create_tween()
	var quadros: int = maxi(explosao.hframes, 1)
	tween.tween_method(func(t: float) -> void: explosao.frame = mini(int(t), quadros - 1), 0.0, float(quadros),
			TEMPO_EXPLOSAO)
	tween.tween_callback(func() -> void: explosao.visible = false)
