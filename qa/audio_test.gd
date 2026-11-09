extends Node
## Teste do AudioSettings: buses existem, 0 = mudo, conversão linear -> dB e salvar/carregar.
## Guarda os volumes do jogador e os restaura no fim.
## Rodar: godot --headless --path . res://qa/audio_test.tscn

var _falhas: int = 0  # Quantidade de verificações que falharam.


## Agenda o teste para o fim do quadro (os autoloads já estarão prontos).
func _ready() -> void:
	_rodar.call_deferred()  # Roda depois da criação dos nós.


## Roda o teste: confere buses, mudo em zero, conversão para decibéis e salvar/carregar; restaura os volumes do jogador no fim.
func _rodar() -> void:
	var musica_original: float = AudioSettings.get_volume(&"Music")  # Guarda o volume original da música.
	var sfx_original: float = AudioSettings.get_volume(&"SFX")  # Guarda o volume original dos efeitos.

	_checar(AudioServer.get_bus_index(&"Music") != -1, "bus Music existe")  # O bus Music precisa existir.
	_checar(AudioServer.get_bus_index(&"SFX") != -1, "bus SFX existe")  # O bus SFX precisa existir.

	var sfx: int = AudioServer.get_bus_index(&"SFX")  # Índice do bus de efeitos.
	AudioSettings.set_volume(&"SFX", 0.0)  # Volume zero.
	_checar(AudioServer.is_bus_mute(sfx), "volume 0 silencia o bus")  # Zero silencia o bus.
	AudioSettings.set_volume(&"SFX", 0.5)  # Volume 0,5.
	_checar(not AudioServer.is_bus_mute(sfx), "volume 0,5 não silencia")  # Meio volume não silencia.
	# 0,5 vira o valor em decibéis esperado.
	_checar(absf(AudioServer.get_bus_volume_db(sfx) - linear_to_db(0.5)) < 0.01, "0,5 vira %.2f dB" % linear_to_db(0.5))

	# Salvar e carregar: muda, grava, bagunça na memória e recarrega do arquivo.
	AudioSettings.set_volume(&"Music", 0.25)  # Muda a música.
	AudioSettings.save_settings()  # Grava.
	AudioSettings.set_volume(&"Music", 1.0)  # Bagunça na memória.
	AudioSettings.load_settings()  # Recarrega do arquivo.
	AudioSettings.apply_all()  # Aplica.
	# Voltou ao valor gravado.
	_checar(is_equal_approx(AudioSettings.get_volume(&"Music"), 0.25), "volume da música volta de user://settings.cfg")

	# Restaura o que o jogador tinha.
	AudioSettings.set_volume(&"Music", musica_original)
	AudioSettings.set_volume(&"SFX", sfx_original)
	AudioSettings.save_settings()

	print("audio_test: %d falha(s)" % _falhas)  # Resultado.
	get_tree().quit(1 if _falhas > 0 else 0)  # Sai com código de erro se algo falhou.


## Confere uma condição e conta a falha.
func _checar(condicao: bool, descricao: String) -> void:
	if condicao:  # Passou.
		print("ok      ", descricao)  # Mostra "ok".
	else:
		printerr("FALHOU  ", descricao)  # Falhou.
		_falhas += 1  # Soma a falha.
