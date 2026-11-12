class_name DashDust
extends Sprite2D
## Nuvem de poeira do dash: 4 quadros de 64 x 64 px desenhados no mesmo canvas do Turing.
## Toca uma vez e se remove. A arte olha para a direita; vira (flip) quando o dash vai para a esquerda.

## Deslocamento do centro do canvas (64 x 64) até o centro visual do boneco, em px do mundo.
const CANVAS_TO_BODY: Vector2 = Vector2(3.5, 5.0)

## Duração de cada quadro.
@export_range(0.02, 0.5, 0.01) var frame_time: float = 0.1


## Posiciona a poeira em volta de `body_center` (centro visual do jogador) e toca a animação.
func play(body_center: Vector2, flip_left: bool) -> void:
	top_level = true  # fica no mundo enquanto o jogador se afasta
	show_behind_parent = true  # atrás do boneco
	flip_h = flip_left  # Vira para o lado do dash.
	# Posiciona perto dos pés (o deslocamento X inverte junto com o espelho).
	global_position = body_center + Vector2(-CANVAS_TO_BODY.x if flip_left else CANVAS_TO_BODY.x, CANVAS_TO_BODY.y)
	frame = 0  # Começa no primeiro quadro.
	var tween: Tween = create_tween()  # Cria a animação por código.
	for i: int in range(1, hframes):  # Um passo por quadro restante da spritesheet.
		# Troca para o quadro i depois de `frame_time`.
		tween.tween_callback(set_frame.bind(i)).set_delay(frame_time)
	tween.tween_callback(queue_free).set_delay(frame_time)  # No fim some da cena.
