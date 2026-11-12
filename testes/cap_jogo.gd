extends TesteBase
## Captura do jogo em modo celular (1500x664) para comparar com referencias/mobile_layout.png.

func rodar() -> void:
	await set_window()
	load_level("res://Scenes/Fase1/fase_1.tscn")
	await frames(90)
	await snap("01_jogo")
