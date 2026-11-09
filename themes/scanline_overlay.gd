class_name ScanlineOverlay
extends ColorRect
## Scanlines sutis (opacidade <= 8%) para o fundo dos menus. Adicione como filho cobrindo a tela
## (anchors em tela cheia) acima do fundo e abaixo do conteúdo. Não recebe mouse.

const SHADER: Shader = preload("res://themes/scanlines.gdshader")  # Shader das linhas de varredura.

var _material: ShaderMaterial = null  # Material do shader.


## Prepara o material do shader (cor e opacidade das linhas) e acompanha a altura do nó.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Não captura cliques.
	_material = ShaderMaterial.new()  # Cria o material.
	_material.shader = SHADER  # Define o shader.
	_material.set_shader_parameter(&"line_color", Palette.TEXT)  # Cor das linhas.
	_material.set_shader_parameter(&"line_alpha", Palette.SCANLINE_ALPHA)  # Opacidade das linhas.
	material = _material  # Aplica ao nó.
	CombatUtils.connect_once(resized, _update_height)  # Altura muda: atualiza o shader.
	_update_height()  # Tamanho inicial.


## Informa a altura atual ao shader (para as linhas acompanharem o tamanho da tela).
func _update_height() -> void:
	if _material != null:  # Só se o material existe.
		_material.set_shader_parameter(&"rect_height", maxf(size.y, 1.0))  # Altura mínima de 1 px.
