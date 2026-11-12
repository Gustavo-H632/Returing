class_name CamaraHud
extends CanvasLayer
## HUD própria da Câmara de Provas: objetivo, "Máquinas X/N" e avisos curtos.
## Fica numa CanvasLayer acima da HUD do projeto (vida, carga e game over continuam sendo da ui/hud/hud.tscn).

## Quanto tempo um aviso fica na tela antes de sumir.
@export_range(0.5, 10.0, 0.1) var tempo_aviso: float = 3.0

@export_group("Referências (já ligadas na cena)")
@export var objetivo: Label  # Objetivo atual (canto de cima, à esquerda).
@export var maquinas: Label  # "Máquinas X/N".
@export var aviso: Label  # Aviso curto (centro de baixo).

var _tween: Tween = null  # Animação do aviso (guardada para cancelar).


## Começa limpa.
func _ready() -> void:
	SafeArea.fit(get_node_or_null(^"Raiz") as Control)  # Celular: textos dentro da área segura.
	SafeArea.stack_top_band(get_node_or_null(^"Raiz") as Control, [objetivo, maquinas])  # fora das barras de status
	if aviso != null:
		aviso.modulate.a = 0.0
	if maquinas != null:
		maquinas.hide()


## Texto do objetivo atual.
func definir_objetivo(texto: String) -> void:
	if objetivo != null:
		objetivo.text = texto


## "Máquinas X/N" (X = destruídas). `total` <= 0 esconde o texto.
func definir_maquinas(destruidas: int, total: int) -> void:
	if maquinas == null:
		return
	maquinas.visible = total > 0
	maquinas.text = "Máquinas %d/%d" % [destruidas, total]


## Mostra um aviso curto (some sozinho). `segundos` <= 0 usa `tempo_aviso`.
func mostrar_aviso(texto: String, segundos: float = -1.0) -> void:
	if aviso == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	aviso.text = texto
	aviso.modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(segundos if segundos > 0.0 else tempo_aviso)
	_tween.tween_property(aviso, "modulate:a", 0.0, 0.4)
