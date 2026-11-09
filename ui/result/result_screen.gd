class_name ResultScreen
extends CanvasLayer
## Tela final no estilo arcade: soma os pontos, mostra o decréscimo do dano tomado, o total e o rank.
## Tudo é montado por código (Label, _draw e Tween); sem shader nem áudio novo.

## Fim da animação (ou do "pular"): os botões já estão ativos.
signal animacao_terminou

const SCENE_PATH: String = "res://ui/result/result_screen.tscn"  # Caminho da cena da tela.

enum Estado { ANIMANDO, RAPIDO, FIM }  # Estados: animando, rápido (depois do primeiro "pular") e fim.

# --- Textos --- (tudo em português, num só lugar).
# --- Textos ---
const TEXTO_TITULO: String = "RUN COMPLETA"
const TEXTO_PONTOS: String = "PONTOS"
const TEXTO_INIMIGOS: String = "INIMIGOS ABATIDOS"
const TEXTO_OUTROS: String = "OUTROS"
const TEXTO_SUBTOTAL: String = "SUBTOTAL"
const TEXTO_DANO_TOMADO: String = "DANO TOMADO"
const TEXTO_TOTAL: String = "TOTAL FINAL"
const TEXTO_RANK: String = "RANK"
const TEXTO_NOVO_RECORDE: String = "NOVO RECORDE!"
const TEXTO_PRESSIONE: String = "PRESSIONE ENTER"
const TEXTO_JOGAR_DE_NOVO: String = "JOGAR DE NOVO"
const TEXTO_MENU: String = "MENU PRINCIPAL"

# --- Animação (constantes que não são tempo) ---
## Deslocamento horizontal inicial (px) de uma linha que entra deslizando.
const DESLOCAMENTO_ENTRADA_PX: float = 48.0
const ESCALA_INICIAL_RANK: float = 3.0  # Escala inicial do rank (cresce até 1).
const AMPLITUDE_TREMOR_DANO_PX: float = 4.0  # Força do tremor ao mostrar o dano tomado.
const AMPLITUDE_TREMOR_RANK_PX: float = 7.0  # Força do tremor ao mostrar o rank.
const ALPHA_FLASH_DANO: float = 0.35  # Opacidade do flash vermelho do dano.
const ALPHA_FLASH_RANK: float = 0.85  # Opacidade do flash do rank.
## Multiplicador de brilho (modulate) do pulso do total; volta a Color.WHITE (neutro).
const COR_PULSO_DOURADO: Color = Color(1.5, 1.3, 0.9, 1.0)
const DURACAO_PULSO_DOURADO_S: float = 0.35  # Duração do pulso.
const PERIODO_PISCA_S: float = 0.5  # Período do pisca ("PRESSIONE ENTER").
const ALPHA_PISCA_MIN: float = 0.25  # Opacidade mínima do pisca.

# --- Visual ---
const PASSO_VARREDURA_PX: int = 2  # Passo das linhas de varredura (px).
## Cores vêm da Palette (DANGER é só para ações destrutivas, então a penalidade usa TEXT_DIM).
const COR_SEPARADOR: Color = Palette.BORDER
const COR_ODOMETRO_APAGADO: Color = Palette.BORDER
const COR_PENALIDADE: Color = Palette.TEXT_DIM
## Tamanhos: múltiplos de 16 (VT323 e Pixelify Sans ficam nítidas assim).
const FONTE_TITULO: int = Palette.FONT_BODY
const FONTE_CORPO: int = Palette.FONT_SMALL
const FONTE_PEQUENA: int = Palette.FONT_SMALL
const FONTE_ODOMETRO: int = Palette.FONT_BODY
const FONTE_TOTAL: int = Palette.FONT_BODY
const FONTE_RANK: int = Palette.FONT_TITLE
const LARGURA_COLUNA: float = 720.0  # Largura da coluna principal.
const MARGEM_TELA: float = 16.0  # Margem da tela.
const ESPACO_LINHAS: int = 3  # Espaço entre linhas.
const LARGURA_DETALHE: float = 160.0  # Largura da coluna de detalhe.
const LARGURA_VALOR: float = 130.0  # Largura da coluna de valor.
const RECUO_TIPO: float = 18.0  # Recuo das linhas de inimigo.
const TAMANHO_ICONE: float = 12.0  # Tamanho do ícone do tipo.
const DIGITOS_ODOMETRO: int = 8  # Dígitos do odômetro.
const MAX_TIPOS: int = 6  # Máximo de tipos mostrados (o resto vira "OUTROS").

@export_group("Animação (s)")
@export var animar: bool = true  # Liga ou desliga a animação.
@export var tempo_fade_tela: float = 0.5  # Tempos das animações (segundos).
@export var tempo_fade_titulo: float = 0.6
@export var tempo_entrada_linha: float = 0.25
@export var tempo_contagem: float = 0.7
@export var tempo_odometro: float = 0.5
@export var pausa_apos_linha: float = 0.25
@export var intervalo_entre_inimigos: float = 0.2
@export var tempo_contagem_inimigo: float = 0.4
@export var tempo_rolagem_inimigos: float = 0.5
@export var tempo_subtotal: float = 0.6
@export var tempo_dano_tomado: float = 0.9
@export var tempo_flash_dano: float = 0.15
@export var tempo_tremor_dano: float = 0.2
@export var tempo_total_final: float = 1.2
@export var pausa_antes_do_rank: float = 0.8
@export var tempo_escala_rank: float = 0.35
@export var tempo_flash_rank: float = 0.1
@export var tempo_tremor_rank: float = 0.25
@export var tempo_por_letra: float = 0.04
## Multiplicador do primeiro "pular" (aperta uma vez: acelera).
@export var velocidade_rapida: float = 4.0
## Entradas nos primeiros segundos não contam como "pular" (cliques de ataque ainda no dedo).
@export var entrada_ignorada_s: float = 0.5

## Resultado a mostrar e recorde (`HighScoreStore.registrar`). Defina antes de entrar na árvore.
var resultado: ScoreResult = null
var recorde: Dictionary = {}  # Recorde registrado.

var _raiz: Control = null  # Raiz de tudo o que a tela desenha.
var _coluna: VBoxContainer = null  # Coluna central.
var _odometro: RichTextLabel = null  # Odômetro de pontos.
var _titulo_caixa: Control = null  # Caixa do título.
var _parciais_wrap: Control = null  # Parciais por fase.
var _cabecalho_inimigos: Label = null  # Cabeçalho dos inimigos.
var _linha_tempo_ui: LinhaUi = null  # Linha do tempo.
var _linhas_inimigos_ui: Array[LinhaUi] = []  # Linhas dos inimigos.
var _linhas_extras_ui: Array[LinhaUi] = []  # Linhas extras (variedade, combo, dano, quiz).
var _linha_subtotal: LinhaUi = null  # Linha do subtotal.
var _linha_penalidade: LinhaUi = null  # Linha da penalidade.
var _linha_total: LinhaUi = null  # Linha do total.
var _caixa_rank: Control = null  # Caixa do rank.
var _letra_rank: Label = null  # Letra do rank.
var _nome_rank: Label = null  # Nome do rank.
var _linha_recorde: Label = null  # Linha do recorde.
var _pressione: Label = null  # Texto "PRESSIONE ENTER".
var _botoes: HBoxContainer = null  # Linha dos botões.
var _botao_jogar: Button = null  # Botão "Jogar de novo".
var _botao_menu: Button = null  # Botão "Menu principal".
var _pausou_a_arvore: bool = false  # True se esta tela pausou o jogo.
var _flash: ColorRect = null  # Flash de tela cheia.
var _tween: Tween = null  # Animação principal.
var _tween_tremor: Tween = null  # Animação do tremor.
var _tweens_pisca: Array[Tween] = []  # Animações de pisca.
var _estado: Estado = Estado.ANIMANDO  # Estado atual.
## Velocidade atual da sequência (1.0 normal; `velocidade_rapida` depois do 1º pular).
var _velocidade: float = 1.0
var _aberta_em_ms: int = 0  # Hora em que a tela abriu.
var _posicao_base: Vector2 = Vector2.ZERO  # Posição da coluna sem tremor.


## Uma linha de pontos: rótulo, detalhe (ex.: "x30") e valor.
class LinhaUi extends RefCounted:
	## MarginContainer: a margem esquerda faz a linha "deslizar" ao entrar.
	var raiz: MarginContainer
	var rotulo: Label  # Rótulo.
	var detalhe: Label  # Detalhe (ex.: "x30").
	var valor: Label  # Valor em pontos.
	## Pontos finais da linha (o sinal é aplicado na hora de exibir).
	var pontos: int = 0
	var sinal: String = "+"  # Sinal mostrado antes do valor.


	## Texto do valor com o sinal (zero aparece só como "0").
	func texto_valor(v: int) -> String:
		return "0" if v == 0 else "%s%d" % [sinal, v]


## Linhas de varredura desenhadas por código.
class Varredura extends Control:
	## Não captura cliques e se redesenha ao mudar de tamanho.
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)


	## Desenha linhas horizontais finas em toda a tela (efeito de monitor antigo).
	func _draw() -> void:
		var pontos := PackedVector2Array()  # Pontos das linhas.
		var y: float = 0.0  # Posição vertical.
		while y < size.y:  # Uma linha a cada alguns pixels.
			pontos.append(Vector2(0.0, y))
			pontos.append(Vector2(size.x, y))
			y += float(PASSO_VARREDURA_PX)
		# Desenha todas as linhas de uma vez.
		draw_multiline(pontos, Palette.with_alpha(Palette.TEXT, Palette.SCANLINE_ALPHA), 1.0)


## Ícone simples gerado por código: quadrado com a cor derivada do tipo (estável).
class Icone extends Control:
	var cor: Color = Color.WHITE  # Cor do ícone.


	## Cria o ícone com o tamanho pedido e uma cor estável para o tipo.
	func _init(tipo: StringName, tamanho: float) -> void:
		custom_minimum_size = Vector2(tamanho, tamanho)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Cor estável calculada pelo nome do tipo.
		cor = Color.from_hsv(float(String(tipo).hash() % 360) / 360.0, 0.55, 0.9)


	## Desenha o quadrado com contorno.
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), cor)
		draw_rect(Rect2(Vector2.ZERO, size), Palette.with_alpha(Palette.BG, 0.8), false, 1.0)


## Instancia a tela na cena atual, já com o resultado.
## Cria a tela na cena atual, já com o resultado.
static func abrir(contexto: Node, p_resultado: ScoreResult, p_recorde: Dictionary, p_animar: bool = true) -> ResultScreen:
	var cena := load(SCENE_PATH) as PackedScene  # Carrega a cena.
	var tela := cena.instantiate() as ResultScreen  # Cria a instância.
	tela.resultado = p_resultado  # Entrega o resultado.
	tela.recorde = p_recorde  # Entrega o recorde.
	tela.animar = p_animar  # Define se anima.
	var pai: Node = CombatUtils.get_spawn_parent(contexto)  # Pai onde a tela entra.
	if pai == null:  # Sem pai: descarta.
		tela.free()  # Libera.
		return null
	pai.add_child(tela)  # Entra na cena.
	return tela


## Segundos como `mm:ss.cc` (centésimos).
static func formatar_tempo(segundos: float) -> String:
	var centesimos: int = maxi(roundi(segundos * 100.0), 0)  # Total de centésimos.
	# Formata minutos, segundos e centésimos.
	return "%02d:%02d.%02d" % [floori(centesimos / 6000.0), floori(centesimos / 100.0) % 60, centesimos % 100]


## Segundos como `mm:ss` (parciais por fase).
static func formatar_parcial(segundos: float) -> String:
	var total: int = maxi(roundi(segundos), 0)  # Total de segundos.
	return "%02d:%02d" % [floori(total / 60.0), total % 60]  # Formata minutos e segundos.


## Número com vírgula decimal (padrão brasileiro).
static func formatar_decimal(valor: float) -> String:
	return ("%.1f" % valor).replace(".", ",")  # Uma casa decimal com vírgula.


## Abre a tela: pausa o jogo, mostra o cursor, monta os nós e começa a animação (ou o estado final).
func _ready() -> void:
	if resultado == null:  # Sem resultado não há o que mostrar.
		push_warning("ResultScreen: sem resultado; nada a mostrar.")  # Avisa no console.
		return
	Engine.time_scale = 1.0  # Devolve o tempo normal (a câmera lenta não vale aqui).
	if not get_tree().paused:  # Só pausa se ainda não estava pausado.
		get_tree().paused = true  # Pausa.
		_pausou_a_arvore = true  # Guarda que foi esta tela.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # Mostra o cursor.
	_aberta_em_ms = Time.get_ticks_msec()  # Guarda a hora de abertura.
	_construir()  # Monta os nós.
	_reposicionar()  # Posiciona a coluna.
	if animar:  # Com animação?
		_iniciar_animacao()  # Inicia a sequência.
	else:
		_aplicar_estado_final()  # Sem animação: mostra tudo pronto.
	_reposicionar.call_deferred()  # Reposiciona depois do layout.


## Ao sair da cena cancela as animações e despausa o jogo, se foi esta tela que pausou.
func _exit_tree() -> void:
	_parar_tweens()  # Para as animações.
	if _pausou_a_arvore and is_inside_tree():  # Despausa.
		get_tree().paused = false


## Pular: o primeiro toque acelera; o segundo vai direto ao estado final.
## Pular: 1º toque acelera (×velocidade_rapida), 2º vai direto ao estado final.
## Toque na tela chega como clique (o projeto emula mouse a partir do toque).
func _input(event: InputEvent) -> void:
	if _raiz == null or _estado == Estado.FIM:  # Sem raiz ou já terminou: ignora.
		return
	# Ignora os primeiros instantes (cliques de ataque ainda no dedo).
	if float(Time.get_ticks_msec() - _aberta_em_ms) / 1000.0 < entrada_ignorada_s:
		return
	# Teclado (Enter ou espaço).
	var teclado: bool = event.is_action_pressed(&"ui_accept") and not event.is_echo()
	var mouse := event as InputEventMouseButton  # Mouse (o toque vira clique de mouse).
	# Clique esquerdo.
	var clique: bool = mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if not (teclado or clique):  # Outro evento: ignora.
		return
	get_viewport().set_input_as_handled()  # Consome o evento.
	if _estado == Estado.ANIMANDO:  # Primeiro toque: acelera.
		_estado = Estado.RAPIDO  # Estado rápido.
		_velocidade = velocidade_rapida  # Velocidade maior.
		if _tween != null and _tween.is_valid():  # Acelera a animação em andamento.
			_tween.set_speed_scale(_velocidade)
	else:
		_aplicar_estado_final()  # Segundo toque: vai direto ao final.


# --- Construção ---

## Monta a tela por código: fundo, linhas de varredura, coluna com título, odômetro, corpo, rodapé e flash.
func _construir() -> void:
	_raiz = Control.new()  # Raiz.
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)  # Cobre a tela.
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP  # Captura cliques.
	_raiz.theme = Palette.load_theme()  # Tema dos menus.
	add_child(_raiz)
	_raiz.resized.connect(_reposicionar)  # Refaz o posicionamento ao redimensionar.

	var fundo := ColorRect.new()  # Fundo.
	fundo.color = Palette.BG
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(fundo)

	var varredura := Varredura.new()  # Linhas de varredura.
	varredura.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(varredura)

	_coluna = VBoxContainer.new()  # Coluna principal.
	_coluna.add_theme_constant_override(&"separation", ESPACO_LINHAS)
	_coluna.custom_minimum_size.x = LARGURA_COLUNA
	_raiz.add_child(_coluna)

	_titulo_caixa = _montar_titulo()  # Título.
	_coluna.add_child(_titulo_caixa)
	_coluna.add_child(_montar_odometro())  # Odômetro.
	_coluna.add_child(_novo_separador())  # Separador.
	_montar_corpo()  # Linhas de pontos.
	_montar_rodape()  # Rank, recorde e botões.

	_flash = ColorRect.new()  # Flash de tela cheia.
	_flash.color = Palette.with_alpha(Palette.TEXT, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_flash)


## Monta o título "RUN COMPLETA".
func _montar_titulo() -> Control:
	var caixa := HBoxContainer.new()
	caixa.alignment = BoxContainer.ALIGNMENT_CENTER
	caixa.add_theme_constant_override(&"separation", Palette.UNIT * 2)
	var titulo: Label = _novo_rotulo(TEXTO_TITULO, FONTE_TITULO, Palette.TEXT)
	titulo.theme_type_variation = &"PanelTitleLabel"
	caixa.add_child(titulo)
	return caixa


## Monta o odômetro: rótulo "PONTOS" e o número.
func _montar_odometro() -> Control:
	var caixa := HBoxContainer.new()
	var rotulo := _novo_rotulo(TEXTO_PONTOS, FONTE_CORPO + 2, Palette.TEXT)
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotulo.size_flags_vertical = Control.SIZE_SHRINK_END
	caixa.add_child(rotulo)
	_odometro = RichTextLabel.new()
	_odometro.bbcode_enabled = true
	_odometro.fit_content = true
	_odometro.scroll_active = false
	_odometro.autowrap_mode = TextServer.AUTOWRAP_OFF
	_odometro.custom_minimum_size = Vector2(300.0, 0.0)
	_odometro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_odometro.add_theme_font_size_override(&"normal_font_size", FONTE_ODOMETRO)
	caixa.add_child(_odometro)
	definir_odometro(0)
	return caixa


## Odômetro de 8 dígitos: zeros à esquerda apagados, o número em dourado.
## Odômetro de 8 dígitos: zeros à esquerda apagados e o número em dourado.
func definir_odometro(valor: int) -> void:
	# Número com zeros à esquerda.
	var texto: String = "%0*d" % [DIGITOS_ODOMETRO, clampi(valor, 0, 99999999)]
	var apagados: int = 0  # Quantos zeros ficam apagados.
	# Conta os zeros iniciais (o último dígito nunca apaga).
	while apagados < DIGITOS_ODOMETRO - 1 and texto[apagados] == "0":
		apagados += 1
	# Texto com cores (BBCode).
	_odometro.text = "[right][color=#%s]%s[/color][color=#%s]%s[/color][/right]" % [
		COR_ODOMETRO_APAGADO.to_html(true), texto.substr(0, apagados),
		Palette.ACCENT.to_html(false), texto.substr(apagados)]


## Monta as linhas de pontos: tempo, parciais, inimigos, extras (variedade, combo, dano, quiz), subtotal, penalidade e total.
func _montar_corpo() -> void:
	var tempo: ScoreResult.Linha = resultado.linha_tempo  # Linha do tempo.
	# Linha de tempo de jogo.
	_linha_tempo_ui = _nova_linha(tempo.rotulo, formatar_tempo(tempo.valor), tempo.pontos)
	_adicionar(_linha_tempo_ui)
	var parciais := _novo_rotulo(_texto_parciais(), FONTE_PEQUENA, Palette.TEXT_DIM)  # Parciais por fase.
	parciais.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var recuo := MarginContainer.new()
	recuo.add_theme_constant_override(&"margin_left", int(RECUO_TIPO))
	recuo.add_child(parciais)
	_parciais_wrap = recuo
	_coluna.add_child(recuo)  # Entra na coluna.

	# Cabeçalho dos inimigos.
	_cabecalho_inimigos = _novo_rotulo(TEXTO_INIMIGOS, FONTE_CORPO, Palette.TEXT_DIM)
	_cabecalho_inimigos.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_coluna.add_child(_cabecalho_inimigos)
	for d: Dictionary in _linhas_de_inimigos():  # Uma linha por tipo de inimigo.
		var linha_inimigo: LinhaUi = _nova_linha(d["rotulo"], "x%d" % d["qtd"], d["pontos"], d["tipo"])
		_linhas_inimigos_ui.append(linha_inimigo)
		_adicionar(linha_inimigo)

	var variedade: ScoreResult.Linha = resultado.linha_variedade  # Variedade.
	var n_tipos: int = roundi(variedade.valor)
	_extra(_nova_linha(variedade.rotulo, "%d %s" % [n_tipos, "TIPO" if n_tipos == 1 else "TIPOS"], variedade.pontos))
	var combo: ScoreResult.Linha = resultado.linha_combo  # Combo.
	_extra(_nova_linha(combo.rotulo, "x%d" % roundi(combo.valor), combo.pontos))
	var dano: ScoreResult.Linha = resultado.linha_dano  # Dano causado.
	_extra(_nova_linha(dano.rotulo, str(roundi(dano.valor)), dano.pontos))
	if resultado.linha_quiz != null:  # Quiz (só se existe).
		var quiz: ScoreResult.Linha = resultado.linha_quiz
		var acertos: int = roundi(quiz.valor)
		_extra(_nova_linha(quiz.rotulo, "%d %s" % [acertos, "ACERTO" if acertos == 1 else "ACERTOS"], quiz.pontos))

	_coluna.add_child(_novo_separador())  # Separador antes do subtotal.
	_linha_subtotal = _nova_linha(TEXTO_SUBTOTAL, "", resultado.bruto, &"", "")  # Subtotal.
	_adicionar(_linha_subtotal)
	var barras: String = "%s %s" % [formatar_decimal(resultado.barras_perdidas),  # Texto "x BARRAS".
			"BARRA" if is_equal_approx(resultado.barras_perdidas, 1.0) else "BARRAS"]
	# Penalidade (valor negativo).
	_linha_penalidade = _nova_linha(TEXTO_DANO_TOMADO, barras, resultado.penalidade, &"", "-")
	# Cor apagada para a penalidade.
	for l: Label in [_linha_penalidade.rotulo, _linha_penalidade.detalhe, _linha_penalidade.valor]:
		l.add_theme_color_override(&"font_color", COR_PENALIDADE)
	_adicionar(_linha_penalidade)
	_coluna.add_child(_novo_separador())  # Separador antes do total.
	_linha_total = _nova_linha(TEXTO_TOTAL, "", resultado.total, &"", "")  # Total final.
	for l: Label in [_linha_total.rotulo, _linha_total.valor]:
		l.add_theme_font_size_override(&"font_size", FONTE_TOTAL)
		l.add_theme_color_override(&"font_color", Palette.TEXT)
	_adicionar(_linha_total)


## Monta o rodapé: rank, recorde, "PRESSIONE ENTER" e os botões.
func _montar_rodape() -> void:
	var caixa := HBoxContainer.new()
	caixa.alignment = BoxContainer.ALIGNMENT_CENTER
	caixa.add_theme_constant_override(&"separation", Palette.UNIT * 2)
	caixa.add_child(_novo_rotulo(TEXTO_RANK, FONTE_CORPO + 2, Palette.TEXT))  # Texto "RANK".
	_caixa_rank = caixa
	var moldura := PanelContainer.new()  # Moldura da letra.
	# Letra do rank.
	_letra_rank = _novo_rotulo(String(resultado.rank), FONTE_RANK, resultado.cor_do_rank())
	_letra_rank.custom_minimum_size.x = float(FONTE_RANK)
	moldura.add_child(_letra_rank)
	caixa.add_child(moldura)
	# Nome do rank.
	_nome_rank = _novo_rotulo(resultado.nome_do_rank(), FONTE_TOTAL, resultado.cor_do_rank())
	_nome_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_nome_rank.custom_minimum_size.x = 150.0
	caixa.add_child(_nome_rank)
	_coluna.add_child(caixa)

	_linha_recorde = _novo_rotulo(_texto_recorde(), FONTE_CORPO, Palette.ACCENT)  # Linha do recorde.
	_coluna.add_child(_linha_recorde)

	_pressione = _novo_rotulo(TEXTO_PRESSIONE, FONTE_CORPO, Palette.TEXT_DIM)  # "PRESSIONE ENTER".
	_coluna.add_child(_pressione)

	_botoes = HBoxContainer.new()  # Botões.
	_botoes.alignment = BoxContainer.ALIGNMENT_CENTER
	_botoes.add_theme_constant_override(&"separation", Palette.UNIT * 2)
	_botao_jogar = PixelButton.new()
	_botao_jogar.text = TEXTO_JOGAR_DE_NOVO
	_botao_menu = PixelButton.new()
	_botao_menu.text = TEXTO_MENU
	_botoes.add_child(_botao_jogar)
	_botoes.add_child(_botao_menu)
	_coluna.add_child(_botoes)
	_botao_jogar.pressed.connect(_on_jogar_de_novo)  # Jogar de novo.
	_botao_menu.pressed.connect(_on_menu)  # Menu.


# --- Dados exibidos ---

## Até MAX_TIPOS linhas (ordem decrescente de pontos); o restante vira "OUTROS".
## Até MAX_TIPOS linhas (ordem decrescente de pontos); o restante vira uma linha "OUTROS".
func _linhas_de_inimigos() -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var outros_qtd: int = 0
	var outros_pontos: int = 0
	for i: int in resultado.linhas_inimigos.size():
		var l: ScoreResult.Linha = resultado.linhas_inimigos[i]
		if i < MAX_TIPOS:
			saida.append({"rotulo": l.rotulo, "qtd": roundi(l.valor), "pontos": l.pontos, "tipo": l.tipo})
		else:
			outros_qtd += roundi(l.valor)
			outros_pontos += l.pontos
	if outros_qtd > 0:
		saida.append({"rotulo": TEXTO_OUTROS, "qtd": outros_qtd, "pontos": outros_pontos, "tipo": &"outros"})
	return saida


## Texto das parciais por fase (ex.: "F1 02:10   F2 01:05").
func _texto_parciais() -> String:
	var partes: PackedStringArray = []
	for i: int in resultado.tempos_por_fase.size():
		partes.append("F%d %s" % [i + 1, formatar_parcial(resultado.tempos_por_fase[i])])
	return "   ".join(partes)


## Texto da linha de recorde: novo recorde (com o anterior), o melhor atual ou vazio.
func _texto_recorde() -> String:
	var anterior: Dictionary = recorde.get("anterior", {})
	var atual: Dictionary = recorde.get("atual", {})
	if recorde.get("novo_recorde", false):
		if anterior.is_empty():
			return TEXTO_NOVO_RECORDE
		return "%s    ANTERIOR %d (%s)" % [TEXTO_NOVO_RECORDE, anterior["total"], anterior["rank"]]
	if atual.is_empty():
		return ""
	return "MELHOR %d (%s)" % [atual["total"], atual["rank"]]


# --- Estado final (sem animação) ---

## Mostra tudo já concluído (também é o destino do segundo "pular").
## Mostra tudo já concluído (também é o destino do segundo "pular").
func _aplicar_estado_final() -> void:
	_parar_tweens()  # Cancela as animações.
	_raiz.modulate.a = 1.0  # Tela visível.
	_flash.color.a = 0.0  # Sem flash.
	_coluna.position = _posicao_base  # Coluna sem tremor.
	_titulo_caixa.modulate.a = 1.0  # Título visível.
	for l: LinhaUi in _todas_as_linhas():  # Cada linha.
		l.raiz.modulate.a = 1.0  # Visível.
		_definir_recuo(0.0, l)  # Sem recuo.
		l.valor.text = l.texto_valor(l.pontos)  # Valor final.
	for c: Control in [_parciais_wrap, _cabecalho_inimigos, _caixa_rank]:  # Parciais, cabeçalho e rank.
		c.modulate.a = 1.0
	_letra_rank.scale = Vector2.ONE  # Letra do rank no tamanho final.
	_nome_rank.visible_ratio = 1.0  # Nome do rank inteiro.
	definir_odometro(resultado.total)  # Odômetro no total.
	_mostrar_final()  # Rodapé final.


## Rodapé final: recorde, "PRESSIONE ENTER", botões e foco.
## Rodapé final: recorde, "PRESSIONE ENTER", botões e foco.
func _mostrar_final() -> void:
	_estado = Estado.FIM  # Estado final.
	for c: Control in [_linha_recorde, _pressione, _botoes]:  # Mostra recorde, "PRESSIONE ENTER" e botões.
		c.modulate.a = 1.0
	for b: Button in [_botao_jogar, _botao_menu]:  # Botões passam a receber foco e cliques.
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_filter = Control.MOUSE_FILTER_STOP
	_iniciar_pisca(_pressione)  # "PRESSIONE ENTER" pisca.
	if recorde.get("novo_recorde", false):  # Novo recorde também pisca.
		_iniciar_pisca(_linha_recorde)
	_botao_jogar.grab_focus()  # Foco em "Jogar de novo".
	animacao_terminou.emit()  # Avisa que terminou.


## Lista todas as linhas de pontos (para esconder, revelar e preencher de uma vez).
func _todas_as_linhas() -> Array[LinhaUi]:
	var todas: Array[LinhaUi] = [_linha_tempo_ui]
	todas.append_array(_linhas_inimigos_ui)
	todas.append_array(_linhas_extras_ui)
	todas.append_array([_linha_subtotal, _linha_penalidade, _linha_total])
	return todas


# --- Animação ---

## Esconde tudo e zera os valores: a sequência revela cada parte na hora dela.
## Esconde tudo e zera os valores: a sequência revela cada parte na hora dela.
func _preparar_animacao() -> void:
	_estado = Estado.ANIMANDO  # Começa a animar.
	_raiz.modulate.a = 0.0  # Tela transparente.
	_titulo_caixa.modulate.a = 0.0  # Título transparente.
	for l: LinhaUi in _todas_as_linhas():  # Cada linha.
		l.raiz.modulate.a = 0.0  # Transparente.
		_definir_recuo(DESLOCAMENTO_ENTRADA_PX, l)  # Recuada.
		l.valor.text = l.texto_valor(0)  # Valor zerado.
	# Esconde o resto.
	for c: Control in [_parciais_wrap, _cabecalho_inimigos, _caixa_rank, _linha_recorde, _pressione, _botoes]:
		c.modulate.a = 0.0
	for b: Button in [_botao_jogar, _botao_menu]:  # Botões ainda não funcionam.
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nome_rank.visible_ratio = 0.0  # Nome do rank vazio.
	definir_odometro(0)  # Odômetro zerado.


## Monta a sequência inteira de animação: fade, linhas, odômetro, dano tomado, total, rank e botões.
func _iniciar_animacao() -> void:
	_preparar_animacao()  # Esconde tudo antes.
	var t: Tween = UiTween.create(self)  # roda pausado e ignora a câmera lenta
	_tween = t
	var acumulado: int = 0  # Pontos já mostrados no odômetro.

	t.tween_property(_raiz, ^"modulate:a", 1.0, tempo_fade_tela)  # Aparece a tela.
	t.tween_property(_titulo_caixa, ^"modulate:a", 1.0, tempo_fade_titulo)  # Aparece o título.

	var extras_tempo: Array = [_parciais_wrap]  # Itens que entram junto com a primeira linha.
	if _linhas_inimigos_ui.is_empty():
		extras_tempo.append(_cabecalho_inimigos)  # sem linhas de inimigo ninguém mais o revelaria
	acumulado = _passo_pontos(t, _linha_tempo_ui, acumulado, extras_tempo)  # Linha do tempo.

	# Inimigos: cada linha conta sozinha; o odômetro rola uma vez só no fim do grupo.
	var soma_inimigos: int = 0  # Soma dos pontos dos inimigos.
	for i: int in _linhas_inimigos_ui.size():  # Cada linha de inimigo.
		var l: LinhaUi = _linhas_inimigos_ui[i]
		t.tween_interval(intervalo_entre_inimigos)  # Pequena pausa.
		_entrar(t, l, [_cabecalho_inimigos] if i == 0 else [])  # Entra (o cabeçalho junto da primeira).
		_contar(t, l, tempo_contagem_inimigo, true)  # Conta o valor.
		soma_inimigos += l.pontos
	if not _linhas_inimigos_ui.is_empty():
		_rolar(t, acumulado, acumulado + soma_inimigos, tempo_rolagem_inimigos, false)  # Odômetro sobe.
		t.tween_interval(pausa_apos_linha)
		acumulado += soma_inimigos  # Soma ao acumulado.

	for l: LinhaUi in _linhas_extras_ui:  # Linhas extras.
		acumulado = _passo_pontos(t, l, acumulado, [])

	_entrar(t, _linha_subtotal, [])  # Subtotal.
	_contar(t, _linha_subtotal, tempo_subtotal, true)

	# Dano tomado: o valor conta, o odômetro rola para baixo, com flash vermelho e tremor.
	var tempo_contagem_dano: float = maxf(tempo_dano_tomado - tempo_entrada_linha, 0.01)
	_entrar(t, _linha_penalidade, [])  # Entra a linha.
	t.tween_callback(_impacto_dano)  # Flash vermelho e tremor.
	_contar(t, _linha_penalidade, tempo_contagem_dano, false)  # Valor da penalidade conta.
	_rolar(t, resultado.bruto, resultado.total, tempo_contagem_dano, true)  # Odômetro desce até o total.

	_entrar(t, _linha_total, [])  # Total final.
	_contar(t, _linha_total, tempo_total_final, true)
	t.tween_callback(_pulso_dourado)  # Pulso dourado.

	t.tween_interval(pausa_antes_do_rank)  # Pausa antes do rank.
	t.tween_callback(_preparar_rank)  # Prepara o rank (grande e invisível).
	t.tween_property(_letra_rank, ^"scale", Vector2.ONE, tempo_escala_rank) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(_impacto_rank)  # Impacto do rank.
	t.tween_interval(maxf(tempo_tremor_rank, tempo_flash_rank))  # Espera o impacto.
	# Nome do rank aparece letra por letra.
	t.tween_property(_nome_rank, ^"visible_ratio", 1.0, tempo_por_letra * float(_nome_rank.text.length()))
	t.tween_callback(_mostrar_final)  # Mostra o rodapé final.


## Uma linha de pontos completa: entra, conta, o odômetro sobe e há uma pausa.
## Uma linha completa: entra, o valor conta, o odômetro sobe e há uma pausa. Devolve o novo acumulado.
func _passo_pontos(t: Tween, l: LinhaUi, acumulado: int, extras: Array) -> int:
	_entrar(t, l, extras)
	_contar(t, l, tempo_contagem, false)
	_rolar(t, acumulado, acumulado + l.pontos, tempo_odometro, false)
	t.tween_interval(pausa_apos_linha)
	return acumulado + l.pontos


## A linha (e os extras) entra deslizando e aparecendo.
## A linha (e os extras) entra deslizando e aparecendo.
func _entrar(t: Tween, l: LinhaUi, extras: Array) -> void:
	t.tween_property(l.raiz, ^"modulate:a", 1.0, tempo_entrada_linha)
	t.parallel().tween_method(_definir_recuo.bind(l), DESLOCAMENTO_ENTRADA_PX, 0.0, tempo_entrada_linha) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for extra: Control in extras:
		t.parallel().tween_property(extra, ^"modulate:a", 1.0, tempo_entrada_linha)


## O valor conta de 0 até o número (ease out). `junto` = roda junto com a entrada da linha.
## O valor conta de 0 até o número (curva de desaceleração).
func _contar(t: Tween, l: LinhaUi, duracao: float, junto: bool) -> void:
	if junto:  # Junto com o passo anterior?
		t.parallel()
	t.tween_method(_definir_valor.bind(l), 0.0, float(l.pontos), duracao) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## O odômetro vai de `de` a `para` (sobe ou desce). `junto` = roda junto com o passo anterior.
## O odômetro vai de um valor a outro (sobe ou desce).
func _rolar(t: Tween, de: int, para: int, duracao: float, junto: bool) -> void:
	if junto:
		t.parallel()
	t.tween_method(_definir_odometro_f, float(de), float(para), duracao) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Passo da contagem: mostra o valor atual da linha.
func _definir_valor(v: float, l: LinhaUi) -> void:
	l.valor.text = l.texto_valor(roundi(v))


## Passo do odômetro: mostra o valor atual.
func _definir_odometro_f(v: float) -> void:
	definir_odometro(roundi(v))


## Passo da entrada: muda o recuo da linha.
func _definir_recuo(px: float, l: LinhaUi) -> void:
	l.raiz.add_theme_constant_override(&"margin_left", roundi(px))


## Impacto do dano tomado: flash vermelho e tremor da coluna.
func _impacto_dano() -> void:
	_flash_tela(COR_PENALIDADE, ALPHA_FLASH_DANO, tempo_flash_dano)
	_tremor(tempo_tremor_dano, AMPLITUDE_TREMOR_DANO_PX)


## Pulso dourado no valor do total.
func _pulso_dourado() -> void:
	_linha_total.valor.modulate = COR_PULSO_DOURADO  # Mais claro.
	var tw: Tween = UiTween.create(self)  # Animação.
	# Volta à cor normal.
	tw.tween_property(_linha_total.valor, ^"modulate", Color.WHITE, DURACAO_PULSO_DOURADO_S)


## Rank entra grande (escala 3 -> 1) e a letra aparece.
## Prepara o rank: a letra aparece grande para depois encolher.
func _preparar_rank() -> void:
	_letra_rank.pivot_offset = _letra_rank.size * 0.5  # Pivô no centro.
	_letra_rank.scale = Vector2.ONE * ESCALA_INICIAL_RANK  # Escala inicial grande.
	_caixa_rank.modulate.a = 1.0  # Mostra a caixa.


## Impacto do rank: flash claro e tremor mais forte.
func _impacto_rank() -> void:
	_flash_tela(Palette.TEXT, ALPHA_FLASH_RANK, tempo_flash_rank)
	_tremor(tempo_tremor_rank, AMPLITUDE_TREMOR_RANK_PX)


## Flash de tela cheia que some em `duracao`.
func _flash_tela(cor: Color, alpha: float, duracao: float) -> void:
	_flash.color = Color(cor.r, cor.g, cor.b, alpha)  # Cor e opacidade iniciais.
	var tw: Tween = UiTween.create(self)  # Animação.
	tw.tween_property(_flash, ^"color:a", 0.0, duracao)  # Some.


## Tremor da coluna: a força cai de 1 a 0 em `duracao`.
## Tremor da coluna: a força cai de 1 a 0 em `duracao`.
func _tremor(duracao: float, amplitude: float) -> void:
	if _tween_tremor != null and _tween_tremor.is_valid():  # Cancela o tremor anterior.
		_tween_tremor.kill()
	_tween_tremor = UiTween.create(self)  # Nova animação.
	# Aplica o tremor a cada passo.
	_tween_tremor.tween_method(_aplicar_tremor.bind(amplitude), 1.0, 0.0, duracao)


## Passo do tremor: desloca a coluna de forma aleatória, proporcional à força.
func _aplicar_tremor(forca: float, amplitude: float) -> void:
	_coluna.position = _posicao_base + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amplitude * forca


## Pisca (cursor): alpha vai e volta sem parar.
## Pisca (cursor): a opacidade vai e volta sem parar.
func _iniciar_pisca(c: Control) -> void:
	var tw: Tween = UiTween.create(self)  # Animação.
	tw.set_loops()  # Repete para sempre.
	tw.tween_property(c, ^"modulate:a", ALPHA_PISCA_MIN, PERIODO_PISCA_S)  # Esmaece.
	tw.tween_property(c, ^"modulate:a", 1.0, PERIODO_PISCA_S)  # Volta.
	_tweens_pisca.append(tw)  # Guarda para cancelar depois.


## Cancela todas as animações e deixa os textos que piscam visíveis.
func _parar_tweens() -> void:
	for tw: Tween in [_tween, _tween_tremor]:  # Animações principais.
		if tw != null and tw.is_valid():
			tw.kill()
	for tw: Tween in _tweens_pisca:  # Piscas.
		if tw != null and tw.is_valid():
			tw.kill()
	_tweens_pisca.clear()  # Esvazia a lista.
	for c: Control in [_pressione, _linha_recorde]:  # Textos que piscavam.
		if is_instance_valid(c):
			c.modulate.a = 1.0  # Visíveis.


# --- Ações ---

## Fluxo já existente: a Fase 1 reinicia a run sozinha (RunState.begin_scene -> reset).
## Fluxo existente: a Fase 1 reinicia a run sozinha.
func _on_jogar_de_novo() -> void:
	EventBus.scene_change_requested.emit(RunState.FIRST_LEVEL_SCENE)  # Pede a troca de cena.


## Menu principal: pede a volta ao menu.
func _on_menu() -> void:
	EventBus.main_menu_requested.emit()  # Pede o menu.


# --- Ajuda de layout ---

## Adiciona uma linha à coluna.
func _adicionar(l: LinhaUi) -> void:
	_coluna.add_child(l.raiz)


## Linha de bônus (variedade, combo, dano causado, quiz).
## Linha de bônus (variedade, combo, dano causado, quiz).
func _extra(l: LinhaUi) -> void:
	_linhas_extras_ui.append(l)  # Guarda a linha.
	_adicionar(l)  # Entra na coluna.


## Cria um rótulo centralizado com texto, tamanho e cor.
func _novo_rotulo(texto: String, tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override(&"font_size", tamanho)
	l.add_theme_color_override(&"font_color", cor)
	return l


## Cria uma linha fina separadora.
func _novo_separador() -> Control:
	var s := ColorRect.new()
	s.color = COR_SEPARADOR
	s.custom_minimum_size.y = 1.0
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


## Linha: [ícone] RÓTULO ....... detalhe ....... valor.
## Cria uma linha: [ícone] RÓTULO ... detalhe ... valor.
func _nova_linha(rotulo: String, detalhe: String, pontos: int, tipo: StringName = &"", sinal: String = "+") -> LinhaUi:
	var l := LinhaUi.new()  # Linha nova.
	l.pontos = pontos  # Pontos finais.
	l.sinal = sinal  # Sinal.
	var caixa := HBoxContainer.new()  # Caixa horizontal.
	caixa.add_theme_constant_override(&"separation", Palette.UNIT)
	l.raiz = MarginContainer.new()  # Contêiner (a margem esquerda faz a linha deslizar).
	l.raiz.add_child(caixa)
	if tipo != &"":  # Linhas de inimigo ganham recuo e ícone.
		var recuo := Control.new()
		recuo.custom_minimum_size.x = RECUO_TIPO
		caixa.add_child(recuo)
		caixa.add_child(Icone.new(tipo, TAMANHO_ICONE))
	l.rotulo = _novo_rotulo(rotulo, FONTE_CORPO, Palette.TEXT)  # Rótulo.
	l.rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caixa.add_child(l.rotulo)
	l.detalhe = _novo_rotulo(detalhe, FONTE_CORPO, Palette.TEXT_DIM)  # Detalhe.
	l.detalhe.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.detalhe.custom_minimum_size.x = LARGURA_DETALHE
	caixa.add_child(l.detalhe)
	l.valor = _novo_rotulo(l.texto_valor(pontos), FONTE_CORPO, Palette.TEXT)  # Valor.
	l.valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.valor.custom_minimum_size.x = LARGURA_VALOR
	caixa.add_child(l.valor)
	return l  # Devolve a linha.


## Centraliza a coluna e a reduz o quanto precisar para caber (16:9, 4:3 e ultra-wide).
## Centraliza a coluna e a reduz o quanto precisar para caber em qualquer proporção de tela (16:9, 4:3, ultra-wide).
func _reposicionar() -> void:
	if _raiz == null or _coluna == null:  # Sem raiz ou coluna: nada a fazer.
		return
	var area: Vector2 = _raiz.size  # Área disponível.
	var tamanho: Vector2 = _coluna.get_combined_minimum_size()  # Tamanho mínimo da coluna.
	tamanho.x = maxf(tamanho.x, LARGURA_COLUNA)  # Largura mínima.
	_coluna.size = tamanho  # Tamanho da coluna.
	# Escala que cabe na tela.
	var escala: float = minf(1.0, minf((area.x - 2.0 * MARGEM_TELA) / tamanho.x, (area.y - 2.0 * MARGEM_TELA) / tamanho.y))
	escala = maxf(escala, 0.1)  # Nunca menor que 10%.
	_coluna.pivot_offset = Vector2.ZERO  # Pivô no canto.
	_coluna.scale = Vector2.ONE * escala  # Escala.
	_posicao_base = (area - tamanho * escala) * 0.5  # Centraliza.
	_coluna.position = _posicao_base  # Posição.
