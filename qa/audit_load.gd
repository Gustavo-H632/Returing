extends Node
## Auditoria de carga: carrega todo script, cena e recurso do projeto (fora de addons) e conta
## o que falha. Erros e avisos do GDScript saem no console durante a carga.
## Rodar: godot --headless --path . res://qa/audit_load.tscn

# Pastas ignoradas (terceiros, cache e entregas).
const PULAR: PackedStringArray = ["res://addons", "res://.godot", "res://entrega"]
# Extensões carregadas: scripts, cenas e recursos.
const EXTENSOES: PackedStringArray = ["gd", "tscn", "tres"]


## Agenda a auditoria para o fim do quadro.
func _ready() -> void:
	_rodar.call_deferred()  # Roda depois da criação dos nós.


## Carrega cada arquivo do projeto e conta o que falha ao carregar.
func _rodar() -> void:
	var arquivos: PackedStringArray = []  # Lista de arquivos.
	_listar("res://", arquivos)  # Procura a partir da raiz.
	arquivos.sort()  # Ordem alfabética.
	var falhas: PackedStringArray = []  # Arquivos que falharam.
	var contagem: Array[int] = [0, 0, 0]  # Contagem por extensão (gd, tscn, tres).
	for caminho: String in arquivos:  # Cada arquivo.
		contagem[EXTENSOES.find(caminho.get_extension())] += 1  # Conta pela extensão.
		var recurso: Resource = ResourceLoader.load(caminho)  # Tenta carregar.
		if recurso == null:  # Falhou.
			falhas.append(caminho)  # Guarda o caminho.
	for f: String in falhas:  # Mostra cada falha.
		printerr("FALHA_DE_CARGA: ", f)
	print("audit_load: %d arquivos (%d gd, %d tscn, %d tres), %d falhas de carga" % [  # Resultado.
			arquivos.size(), contagem[0], contagem[1], contagem[2], falhas.size()])
	get_tree().quit(1 if not falhas.is_empty() else 0)  # Sai com código de erro se algo falhou.


## Lista recursivamente os arquivos de interesse, pulando as pastas ignoradas.
func _listar(pasta: String, saida: PackedStringArray) -> void:
	for p: String in PULAR:  # Pastas ignoradas.
		if pasta.begins_with(p):  # Esta pasta é ignorada.
			return
	for arquivo: String in DirAccess.get_files_at(pasta):  # Arquivos desta pasta.
		if EXTENSOES.has(arquivo.get_extension()):  # Só as extensões da lista.
			saida.append(pasta.path_join(arquivo))  # Guarda o caminho.
	for sub: String in DirAccess.get_directories_at(pasta):  # Subpastas.
		_listar(pasta.path_join(sub), saida)  # Desce na subpasta.
