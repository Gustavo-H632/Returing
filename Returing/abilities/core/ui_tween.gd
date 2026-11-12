class_name UiTween
extends RefCounted
## Tween de interface: roda com o jogo pausado e, se a versão do Godot permitir, ignora a câmera lenta.

## Cria um tween de interface: roda mesmo com o jogo pausado e, se a versão do Godot permitir, ignora a câmera lenta.
static func create(node: Node) -> Tween:
	var tween: Tween = node.create_tween()  # Cria o tween no nó.
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # Continua rodando com o jogo pausado.
	if tween.has_method(&"set_ignore_time_scale"):  # Só existe em versões novas do Godot.
		tween.call(&"set_ignore_time_scale", true)  # Ignora o time_scale (câmera lenta do modo comando).
	return tween


## Tween que PARA com o jogo pausado (animações da HUD de cooldown: o tempo das habilidades congela
## junto com tudo enquanto um menu está aberto). Também ignora a câmera lenta, se a versão permitir.
static func create_pausable(node: Node) -> Tween:
	var tween: Tween = node.create_tween()
	if tween.has_method(&"set_ignore_time_scale"):  # Cria o tween no nó (pára com a pausa).
		tween.call(&"set_ignore_time_scale", true)  # Ignora a câmera lenta, se possível.
	return tween
