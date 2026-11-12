class_name HighScoreStore
extends RefCounted
## Recordes locais (só neste computador): melhor total, o rank dele e o melhor tempo.
## Arquivo ausente ou corrompido vale "sem recorde", sem erro.

const ARQUIVO: String = "user://returing_recordes.cfg"  # Arquivo do recorde (pasta do usuário).
const SECAO: String = "recorde"  # Seção do arquivo.
const CHAVE_TOTAL: String = "melhor_total"  # Chaves: melhor total, rank e melhor tempo.
const CHAVE_RANK: String = "rank"
const CHAVE_TEMPO: String = "melhor_tempo_s"

## Caminho em uso (os testes trocam por um arquivo temporário).
static var caminho: String = ARQUIVO


## Recorde salvo: `{total: int, rank: StringName, tempo_s: float}`, ou `{}` se não houver/estiver inválido.
## Lê o recorde salvo. Devolve `{}` se o arquivo não existe, está incompleto ou tem valores inválidos (nunca dá erro).
static func carregar() -> Dictionary:
	var cfg := ConfigFile.new()  # Leitor de arquivos .cfg.
	if cfg.load(caminho) != OK:  # Sem arquivo (primeira vez): sem recorde.
		return {}
	for chave: String in [CHAVE_TOTAL, CHAVE_RANK, CHAVE_TEMPO]:  # As três chaves precisam existir.
		if not cfg.has_section_key(SECAO, chave):
			return {}
	var total: Variant = cfg.get_value(SECAO, CHAVE_TOTAL)  # Valores lidos (sem tipo definido ainda).
	var rank: Variant = cfg.get_value(SECAO, CHAVE_RANK)
	var tempo: Variant = cfg.get_value(SECAO, CHAVE_TEMPO)
	# Confere os tipos de cada valor.
	if typeof(total) != TYPE_INT or typeof(rank) != TYPE_STRING or not (typeof(tempo) == TYPE_FLOAT or typeof(tempo) == TYPE_INT):
		return {}
	# Rank conhecido e números não negativos.
	if not ScoreResult.RANK_NOMES.has(StringName(rank)) or int(total) < 0 or float(tempo) < 0.0:
		return {}
	return {"total": int(total), "rank": StringName(rank), "tempo_s": float(tempo)}  # Recorde válido.


## Compara a run com o recorde, salva o que melhorou e devolve
## `{novo_recorde: bool, anterior: Dictionary, atual: Dictionary}`.
## O melhor total e o melhor tempo são independentes; sem recorde anterior, a run cria um.
## Compara a run com o recorde e salva o que melhorou. O melhor total e o melhor tempo são independentes.
static func registrar(total: int, rank: StringName, tempo_s: float) -> Dictionary:
	var anterior: Dictionary = carregar()  # Recorde anterior.
	# É recorde se não havia anterior ou o total é maior.
	var novo_recorde: bool = anterior.is_empty() or total > int(anterior["total"])
	var atual: Dictionary = anterior.duplicate()  # Começa igual ao anterior.
	if novo_recorde:  # Novo melhor total.
		atual["total"] = total  # Guarda o total.
		atual["rank"] = rank  # Guarda o rank.
	if anterior.is_empty() or tempo_s < float(anterior["tempo_s"]):  # Melhor tempo (menor é melhor).
		atual["tempo_s"] = tempo_s  # Guarda o tempo.
	if atual != anterior:  # Só grava se algo mudou.
		_salvar(atual)  # Grava.
	# Devolve se bateu o recorde, o anterior e o atual.
	return {"novo_recorde": novo_recorde, "anterior": anterior, "atual": atual}


## Grava o recorde em arquivo (avisa no console se falhar).
static func _salvar(dados: Dictionary) -> void:
	var cfg := ConfigFile.new()  # Arquivo de configuração.
	cfg.set_value(SECAO, CHAVE_TOTAL, int(dados["total"]))  # Total.
	cfg.set_value(SECAO, CHAVE_RANK, String(dados["rank"]))  # Rank.
	cfg.set_value(SECAO, CHAVE_TEMPO, float(dados["tempo_s"]))  # Tempo.
	var erro: Error = cfg.save(caminho)  # Grava.
	if erro != OK:  # Falhou: avisa.
		push_warning("HighScoreStore: não foi possível salvar '%s' (erro %d)." % [caminho, erro])
