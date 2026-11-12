class_name PixelButton
extends Button
## Botão de menu com o comportamento da identidade visual:
##  - hover ou foco: sobe 2 px e cresce 4% (Tween curto); borda e texto vão para a cor de destaque;
##  - apertado: afunda 2 px;
##  - o foco de teclado/gamepad tem EXATAMENTE o mesmo visual do hover e fica sempre visível;
##  - passar o mouse move o foco para o botão, então só um botão fica destacado por vez.
## As cores e bordas de cada estado vêm do tema (PixelTheme). Scripts de botões específicos
## devem estender esta classe e chamar `super()` no `_ready`.

## Quanto o botão sobe (px) com hover/foco.
@export_range(0.0, 8.0, 0.5) var lift_px: float = 2.0
## Quanto o botão afunda (px) ao ser apertado.
@export_range(0.0, 8.0, 0.5) var sink_px: float = 2.0
## Escala com hover/foco.
@export_range(1.0, 1.2, 0.01) var hover_scale: float = 1.04

## Deslocamento vertical que ESTE script aplicou (negativo = sobe).
var _lift_applied: float = 0.0
var _last_y: float = 0.0  # Última posição vertical conhecida.
var _applying: bool = false  # True enquanto o próprio script move o botão.
var _tween: Tween = null  # Animação atual.


## Prepara o botão: remove o estilo de foco do tema e liga os sinais que atualizam o visual.
func _ready() -> void:
	if Platform.is_mobile():  # alvo de toque confortável (~48 dp); no computador nada muda
		custom_minimum_size.y = maxf(custom_minimum_size.y, Platform.MIN_TOUCH)
	# O destaque de foco é feito por este script; o estilo "focus" do tema ficaria por cima do "pressed".
	add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())  # Foco invisível no tema.
	_update_pivot()  # Pivô no centro (para crescer a partir do meio).
	_last_y = position.y  # Guarda a posição.
	CombatUtils.connect_once(resized, _update_pivot)  # Redimensionar atualiza o pivô.
	# Se um Container mover o botão, recalcula.
	CombatUtils.connect_once(item_rect_changed, _on_item_rect_changed)
	CombatUtils.connect_once(mouse_entered, _on_mouse_entered)  # Mouse em cima: passa o foco.
	CombatUtils.connect_once(mouse_exited, _refresh)  # Mouse saiu: atualiza.
	CombatUtils.connect_once(focus_entered, _refresh)  # Foco entrou: atualiza.
	CombatUtils.connect_once(focus_exited, _refresh)  # Foco saiu: atualiza.
	CombatUtils.connect_once(button_down, _refresh)  # Botão apertado: atualiza.
	CombatUtils.connect_once(button_up, _refresh)  # Botão solto: atualiza.
	# Depois do clique o botão pode ter sido desabilitado (ex.: Start): reavalia no quadro seguinte.
	# Depois do clique o botão pode ter sido desabilitado.
	CombatUtils.connect_once(pressed, _refresh_deferred)
	_refresh(true)  # Aplica o visual já no começo.


## Ao sair da cena cancela a animação.
func _exit_tree() -> void:
	_kill_tween()


## Quando o botão aparece, aplica o visual sem animar.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree():
		_refresh(true)


## Mantém o pivô no centro do botão.
func _update_pivot() -> void:
	pivot_offset = size * 0.5


## Mouse entrou: dá o foco ao botão (só um fica destacado por vez).
func _on_mouse_entered() -> void:
	# Só se estiver ativo e puder receber foco.
	if not disabled and focus_mode != Control.FOCUS_NONE and not has_focus():
		grab_focus()  # Dá o foco.
	_refresh()  # Atualiza o visual.


## Reavalia o visual no quadro seguinte.
func _refresh_deferred() -> void:
	_refresh.call_deferred()


## Aplica o visual do estado atual. `instant` pula a animação (abertura da tela, botão escondido).
## Aplica o visual do estado atual: apertado afunda; hover ou foco sobe e cresce. `instant` pula a animação.
func _refresh(instant: bool = false) -> void:
	_update_focus_look()  # Foco sem mouse usa o mesmo visual do hover.
	var target_lift: float = 0.0  # Posição alvo.
	var target_scale: float = 1.0  # Escala alvo.
	var mode: DrawMode = get_draw_mode()  # Estado de desenho do botão.
	if not disabled and is_visible_in_tree():  # Só se ativo e visível.
		if mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED:  # Apertado: afunda.
			target_lift = sink_px
		elif has_focus() or is_hovered():  # Hover ou foco: sobe e cresce.
			target_lift = -lift_px
			target_scale = hover_scale
	_animate_to(target_lift, target_scale, instant)  # Anima até o alvo.


## Foco sem mouse por cima: o estado "normal" passa a usar o visual de hover.
## Foco sem mouse por cima: o estado "normal" passa a usar o visual de hover.
func _update_focus_look() -> void:
	if has_focus() and not disabled:  # Com foco e ativo.
		add_theme_stylebox_override(&"normal", get_theme_stylebox(&"hover"))  # Usa o estilo de hover.
		# Usa a cor do texto de hover.
		add_theme_color_override(&"font_color", get_theme_color(&"font_hover_color"))
	else:
		remove_theme_stylebox_override(&"normal")  # Sem foco: volta ao estilo do tema.
		remove_theme_color_override(&"font_color")  # Volta à cor do tema.


## Anima o botão (posição e escala) até o alvo, ou aplica direto se `instant`.
func _animate_to(target_lift: float, target_scale: float, instant: bool) -> void:
	_kill_tween()  # Cancela a animação anterior.
	if instant or not is_inside_tree():  # Sem animação: aplica já.
		_set_lift(target_lift)  # Posição.
		scale = Vector2.ONE * target_scale  # Escala.
		return
	var pressing: bool = target_lift > 0.0  # Apertando?
	# Clique é mais rápido que hover.
	var time: float = Palette.PRESS_TIME if pressing else Palette.HOVER_TIME
	_tween = UiTween.create(self)  # roda com o jogo pausado (pause) e ignora a câmera lenta
	_tween.set_parallel(true)  # Posição e escala ao mesmo tempo.
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)  # Curva suave.
	_tween.tween_method(_set_lift, _lift_applied, target_lift, time)  # Move.
	_tween.tween_property(self, ^"scale", Vector2.ONE * target_scale, time)  # Escala.


## Move o botão na vertical sem mexer no layout: guarda quanto já foi aplicado.
## Move o botão na vertical sem mexer no layout, guardando quanto já foi aplicado.
func _set_lift(value: float) -> void:
	_applying = true  # Evita tratar o próprio movimento como mudança de layout.
	position.y += value - _lift_applied  # Aplica só a diferença.
	_lift_applied = value  # Guarda o valor aplicado.
	_last_y = position.y  # Guarda a posição.
	_applying = false  # Fim do movimento.


## Se um Container reposicionou o botão (reordenou), o deslocamento aplicado deixou de valer.
## Se um Container reposicionou o botão, o deslocamento aplicado deixou de valer.
func _on_item_rect_changed() -> void:
	if _applying:  # Foi este script que moveu.
		return
	if absf(position.y - _last_y) > 0.01:  # Mudou de lugar por fora.
		_lift_applied = 0.0  # Zera o deslocamento.
		_last_y = position.y  # Guarda a nova posição.


## Cancela a animação, se existir.
func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():  # Só se está rodando.
		_tween.kill()  # Cancela.
	_tween = null  # Esquece.
