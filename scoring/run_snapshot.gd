class_name RunSnapshot
extends RefCounted
## Cópia imutável dos números brutos da run. O ScoreCalculator só lê isto (e o ScoreConfig),
## o que o mantém puro e testável com qualquer combinação de valores.

var tempo_s: float = 0.0  # Tempo de jogo total (s).
var tempos_por_fase: Array[float] = []  # Tempo de cada fase.
var abates_por_tipo: Dictionary = {}  # Abates por tipo de inimigo.
var dano_causado: float = 0.0  # Dano causado aos inimigos.
var dano_tomado: float = 0.0  # Dano tomado pelo jogador.
var maior_sequencia_abates: int = 0  # Maior sequência de abates.
var acertos_quiz: int = 0  # Acertos do quiz.
var vida_max_inicial_jogador: float = 0.0  # Vida máxima inicial do jogador.
