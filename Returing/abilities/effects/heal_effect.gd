class_name HealEffect
extends AbilityEffect
## Cura: recupera algumas unidades da barra de vida (a barra tem `bar_total` quadros).
## A cura passa por `Player.curar`, que já aplica o bônus de cura recebida.

@export_group("Cura")  # Quantas unidades da barra são recuperadas.
## Unidades da barra recuperadas e total de unidades da barra.
@export_range(1, 12) var bar_units: int = 3
@export_range(1, 24) var bar_total: int = 12  # Total de unidades da barra de vida.
@export var heal_color: Color = Color(0.4, 1.0, 0.5, 1.0)  # Cor do símbolo de cura.
## Duração (s) do símbolo de cura subindo.
@export_range(0.1, 2.0, 0.05) var show_time: float = 0.7

var _age: float = 0.0  # Tempo de vida do efeito.


## Cura o jogador: unidades da barra vezes a vida máxima, dividido pelo total de unidades.
func _on_activate() -> void:
	# Quantidade proporcional à vida máxima.
	var amount: int = roundi(float(caster.hp_maximo) * float(bar_units) / float(maxi(bar_total, 1)))
	caster.curar(maxi(amount, 1))  # Cura pelo menos 1 ponto.
	queue_redraw()  # Desenha o símbolo.


## A cada quadro anima o símbolo e termina quando acaba o tempo.
func _physics_process(delta: float) -> void:
	_age += delta  # Soma o tempo.
	queue_redraw()  # Redesenha.
	if _age >= show_time:  # Acabou: termina.
		_finish()


## Desenha uma cruz verde que sobe e some.
func _draw() -> void:
	var t: float = clampf(_age / show_time, 0.0, 1.0)  # Progresso (0 a 1).
	var cor: Color = heal_color  # Cor da cruz.
	cor.a = 1.0 - t  # Some com o tempo.
	var centro: Vector2 = Vector2(0.0, -20.0 - 22.0 * t)  # Posição (sobe acima do jogador).
	var braco: float = 7.0  # Meio comprimento do braço.
	var grossura: float = 3.0  # Grossura do traço.
	# Traço horizontal.
	draw_line(centro + Vector2(-braco, 0.0), centro + Vector2(braco, 0.0), cor, grossura)
	draw_line(centro + Vector2(0.0, -braco), centro + Vector2(0.0, braco), cor, grossura)  # Traço vertical.
