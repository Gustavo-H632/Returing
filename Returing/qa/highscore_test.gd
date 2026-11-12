extends SceneTree
## Testes dos recordes locais (usa um arquivo temporário, nunca o do jogador).
## Rodar: godot --headless --path . --script qa/highscore_test.gd

# Arquivo temporário (nunca o do jogador).
const ARQUIVO_TESTE: String = "user://returing_recordes_teste.cfg"

var _falhas: int = 0  # Falhas.
var _total: int = 0  # Total de verificações.


## Usa um arquivo temporário, roda o teste, limpa e mostra o resultado.
func _initialize() -> void:
	HighScoreStore.caminho = ARQUIVO_TESTE  # Troca o arquivo.
	_limpar()  # Começa sem arquivo.
	_rodar()  # Roda os testes.
	_limpar()  # Limpa depois.
	print("highscore_test: %d verificações, %d falhas" % [_total, _falhas])  # Resultado.
	quit(1 if _falhas > 0 else 0)  # Sai com código de erro se algo falhou.


## Confere uma condição e conta a falha.
func _confere(condicao: bool, nome: String) -> void:
	_total += 1
	if not condicao:
		_falhas += 1
		printerr("FALHOU: ", nome)


## Apaga o arquivo temporário.
func _limpar() -> void:
	if FileAccess.file_exists(ARQUIVO_TESTE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ARQUIVO_TESTE))


## Escreve um texto no arquivo temporário (para simular arquivo corrompido).
func _escrever(texto: String) -> void:
	var f := FileAccess.open(ARQUIVO_TESTE, FileAccess.WRITE)
	f.store_string(texto)
	f.close()


## Testa os recordes: criar, melhorar total e tempo de forma independente, arquivo corrompido e valores inválidos.
func _rodar() -> void:
	# Sem arquivo não há recorde.
	_confere(HighScoreStore.carregar().is_empty(), "sem arquivo = sem recorde")

	var r: Dictionary = HighScoreStore.registrar(11333, &"B", 1020.0)  # Primeira run cria o recorde.
	_confere(r["novo_recorde"] == true, "primeira run cria recorde")
	var salvo: Dictionary = HighScoreStore.carregar()  # Recorde salvo e relido.
	_confere(salvo["total"] == 11333 and salvo["rank"] == &"B" and salvo["tempo_s"] == 1020.0, "recorde salvo e relido")

	r = HighScoreStore.registrar(9000, &"C", 900.0)  # Total menor: não é recorde.
	_confere(r["novo_recorde"] == false, "total menor não é recorde")
	salvo = HighScoreStore.carregar()  # Total e rank mantidos.
	_confere(salvo["total"] == 11333 and salvo["rank"] == &"B", "total e rank mantidos")
	_confere(salvo["tempo_s"] == 900.0, "melhor tempo atualiza sozinho")  # O melhor tempo atualiza sozinho.

	r = HighScoreStore.registrar(11333, &"B", 1000.0)  # Total igual não é recorde.
	_confere(r["novo_recorde"] == false, "total igual não é recorde")

	r = HighScoreStore.registrar(18000, &"S", 1500.0)  # Total maior é recorde.
	_confere(r["novo_recorde"] == true and r["anterior"]["total"] == 11333, "total maior é recorde")
	salvo = HighScoreStore.carregar()  # O melhor tempo não piora.
	_confere(salvo["total"] == 18000 and salvo["rank"] == &"S" and salvo["tempo_s"] == 900.0, "novo recorde não piora o melhor tempo")

	_escrever("isto não é um arquivo de configuração {{{")  # Arquivo corrompido.
	# Vale "sem recorde".
	_confere(HighScoreStore.carregar().is_empty(), "arquivo corrompido = sem recorde")
	r = HighScoreStore.registrar(5000, &"D", 2000.0)  # É sobrescrito sem erro.
	_confere(r["novo_recorde"] == true and HighScoreStore.carregar()["total"] == 5000, "corrompido é sobrescrito sem erro")

	# Tipos e rank inválidos.
	_escrever("[recorde]\nmelhor_total=\"abc\"\nrank=\"Z\"\nmelhor_tempo_s=10.0\n")
	# Vale "sem recorde".
	_confere(HighScoreStore.carregar().is_empty(), "tipos/rank inválidos = sem recorde")
