class_name ScrollFit
extends ScrollContainer
## Caixa de rolagem por toque para conteúdo que pode não caber na tela do celular: cresce junto com o conteúdo
## até a altura livre da área segura e, a partir daí, rola. Só é usada no modo celular.

## Altura (px lógicos) que o resto da tela precisa em volta desta caixa (margens e bordas do painel).
var reserve: float = 72.0
## Conteúdo (único filho).
var content: Control = null


func _init(p_content: Control = null, p_reserve: float = 72.0) -> void:
	content = p_content
	reserve = p_reserve
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	follow_focus = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if content != null:
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(content)


func _ready() -> void:
	if content == null:
		return
	content.minimum_size_changed.connect(_refit)
	Platform.safe_area_changed.connect(_refit)
	_refit()


func _exit_tree() -> void:
	if Platform.safe_area_changed.is_connected(_refit):
		Platform.safe_area_changed.disconnect(_refit)


## Altura = a do conteúdo, limitada ao que cabe na área segura.
func _refit() -> void:
	var need: Vector2 = content.get_combined_minimum_size()
	var room: float = maxf(Platform.get_safe_rect().size.y - reserve, 120.0)
	var bar: float = 0.0
	if need.y > room:
		bar = get_v_scroll_bar().get_combined_minimum_size().x + 4.0
	custom_minimum_size = Vector2(need.x + bar, minf(need.y, room))
