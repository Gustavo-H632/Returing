class_name ScoreConfig
extends Resource
## Todos os números do cálculo de pontuação. Ajuste o balanceamento em `score_config.tres`
## (Inspector); nenhum valor fica solto no código do ScoreCalculator.

const DEFAULT_PATH: String = "res://scoring/score_config.tres"  # Caminho da configuração padrão.

@export_group("Tempo")
## Pontos de tempo com a run igual ou mais rápida que o tempo par.
@export var pontos_tempo_max: int = 5000
## Tempo par de cada fase (s). `tempo_par_s = tempo_par_por_fase_s * numero_de_fases`.
@export_range(1.0, 3600.0, 1.0, "or_greater") var tempo_par_por_fase_s: float = 120.0
## Quantas fases a run tem (Fase 1, Fase 2 e Fase 3).
@export_range(1, 20) var numero_de_fases: int = 3
## `tempo_limite_s = multiplicador_limite * tempo_par_s`: daí em diante o tempo vale 0.
@export_range(1.01, 20.0, 0.01, "or_greater") var multiplicador_limite: float = 4.0

@export_group("Abates")
## Peso de cada faixa de vida (da mais fraca à mais forte).
@export var peso_faixa_1: int = 100
@export var peso_faixa_2: int = 200
@export var peso_faixa_3: int = 400
@export var peso_faixa_4: int = 800
## Razão vida do tipo / vida do mais fraco que separa as faixas (3 limites: 1→2, 2→3, 3→4).
@export var limites_razao_vida: Array[float] = [2.0, 4.0, 8.0]
## Peso de um chefe.
@export var peso_chefe: int = 2000
## Sobrescreve a faixa de um tipo (tipo -> peso). Tem prioridade sobre faixas e chefe.
@export var peso_por_tipo: Dictionary[StringName, int] = {}
## Tipos tratados como chefe.
@export var tipos_chefe: Array[StringName] = [&"guide"]
## Vida máxima de cada tipo de inimigo (lida das cenas em `enemies/`). Base das faixas.
@export var vida_max_por_tipo: Dictionary[StringName, int] = {
	&"drone": 40,
	&"robo": 120,
	&"tank": 500,
	&"guide": 1000,
}
## Nome exibido de um tipo (vazio = o próprio tipo em maiúsculas).
@export var nomes_por_tipo: Dictionary[StringName, String] = {}

@export_group("Variedade")
@export var pontos_por_tipo_distinto: int = 300  # Pontos por tipo diferente abatido.

@export_group("Combo")
## Segundos (de tempo de jogo) entre dois abates para a sequência continuar.
@export_range(0.1, 30.0, 0.1, "or_greater") var janela_combo_s: float = 3.0
## Menor sequência que dá bônus.
@export var combo_minimo: int = 3
## Quantos abates da sequência não pagam bônus.
@export var abates_sem_bonus_combo: int = 2
@export var pontos_por_abate_acima_de_2: int = 50  # Pontos por abate acima disso.
@export var teto_combo: int = 1000  # Teto do bônus de combo.

@export_group("Dano causado")
## Pontos por cada "vida do inimigo mais fraco" de dano efetivo causado.
@export var pontos_por_vida_base_causada: int = 10

@export_group("Dano tomado")
## Penalidade por barra de vida inicial perdida.
@export var penalidade_por_barra: int = 1500
## A penalidade nunca passa dessa fração do bruto.
@export_range(0.0, 1.0, 0.01) var teto_penalidade_pct: float = 0.5

@export_group("Quiz")
## Desliga a linha e o bônus do quiz.
@export var quiz_ativo: bool = true
@export var pontos_por_acerto: int = 300  # Pontos por acerto.

@export_group("Fluxo")
## Segundos (de jogo) entre o fim da última fase e a abertura da tela final.
@export_range(0.0, 20.0, 0.1, "or_greater") var atraso_tela_final_s: float = 3.0

@export_group("Rank")
## Total mínimo de cada rank (abaixo do limite C é D). Provisórios: recalibrar depois de jogar.
@export var limite_s: int = 18000
@export var limite_a: int = 15000
@export var limite_b: int = 10000
@export var limite_c: int = 6500


## Carrega o `score_config.tres` do projeto (cai nos valores padrão se faltar).
## Carrega o `score_config.tres` (usa os valores padrão se o arquivo faltar).
static func carregar() -> ScoreConfig:
	if ResourceLoader.exists(DEFAULT_PATH):  # Arquivo existe.
		var carregado := load(DEFAULT_PATH) as ScoreConfig  # Carrega o recurso.
		if carregado != null:  # Carregou direito.
			return carregado  # Devolve.
	# Sem arquivo: avisa.
	push_warning("ScoreConfig: '%s' não encontrado; usando os valores padrão." % DEFAULT_PATH)
	return ScoreConfig.new()  # Valores padrão.
