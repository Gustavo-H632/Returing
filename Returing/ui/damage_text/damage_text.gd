class_name DamageText
extends Label
## Número de dano flutuante: pop, sobe, some e se libera sozinho.

@export_group("Aparência")
## Fonte opcional (vazio = padrão do tema)
@export var fonte: Font
@export var tamanho_fonte: int = 24  # Tamanho da fonte.
@export var cor: Color = Color(1.0, 0.9, 0.2)  # Cor do número (amarelo).
@export var cor_contorno: Color = Color.BLACK  # Cor do contorno.
@export_range(0, 16) var espessura_contorno: int = 4  # Espessura do contorno.

@export_group("Animação")
## Quanto o número sobe (px)
@export var subida: float = 40.0
## Duração total; o fade usa a segunda metade.
@export_range(0.1, 3.0, 0.05, "or_greater") var duracao: float = 0.7
## Desvio horizontal para não sobrepor números.
@export var espalhamento_x: float = 8.0
## Escala inicial do pop.
@export_range(1.0, 2.0, 0.05) var escala_inicial: float = 1.4


## Chame depois do add_child (o Tween precisa da árvore).
## Mostra o número: configura texto e aparência, posiciona em cima do alvo e anima (pop, sobe, some e se remove).
func mostrar(valor: int, posicao_global: Vector2) -> void:
	text = str(valor)  # Texto do número.
	if fonte != null:  # Fonte própria, se houver.
		add_theme_font_override(&"font", fonte)  # Aplica.
	add_theme_font_size_override(&"font_size", tamanho_fonte)  # Tamanho da fonte.
	add_theme_color_override(&"font_color", cor)  # Cor do número.
	add_theme_color_override(&"font_outline_color", cor_contorno)  # Cor do contorno.
	add_theme_constant_override(&"outline_size", espessura_contorno)  # Espessura do contorno.

	reset_size()  # Recalcula o tamanho para o novo texto.
	pivot_offset = size / 2.0  # Giro e escala a partir do centro.
	# Centraliza em cima do alvo com um desvio aleatório.
	global_position = posicao_global + Vector2(-size.x / 2.0 + randf_range(-espalhamento_x, espalhamento_x), -size.y)

	scale = Vector2.ONE * escala_inicial  # Começa maior (efeito de pop).
	modulate.a = 1.0  # Começa opaco.
	var topo_y: float = global_position.y - subida  # Altura final.

	# Tween do próprio rótulo: morre junto com ele
	var tween := create_tween().set_parallel(true)  # Várias animações ao mesmo tempo.
	# Pop: volta ao tamanho normal.
	tween.tween_property(self, ^"scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Sobe.
	tween.tween_property(self, ^"global_position:y", topo_y, duracao).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Some na segunda metade.
	tween.tween_property(self, ^"modulate:a", 0.0, duracao * 0.5).set_delay(duracao * 0.5)
	tween.chain().tween_callback(queue_free)  # No fim remove o rótulo.
