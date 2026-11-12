class_name ShieldEffect
extends AbilityEffect
## Escudo: invulnerabilidade pela duração da habilidade, com um círculo ao redor do personagem.

const DEFAULT_TIME: float = 3.0  # Duração padrão se a habilidade não define.
## Nos últimos segundos o círculo pisca para avisar que vai acabar.
const BLINK_TIME: float = 0.6

@export var radius: float = 26.0  # Raio do círculo.
@export var shield_color: Color = Color(0.45, 0.8, 1.0, 1.0)  # Cor do escudo.

var _time_left: float = DEFAULT_TIME  # Tempo restante.
var _age: float = 0.0  # Tempo de vida (anima o círculo).


## Ativa o escudo: concede invulnerabilidade pela duração.
func _on_activate() -> void:
	# Duração da habilidade.
	_time_left = data.duration if data != null and data.duration > 0.0 else DEFAULT_TIME
	caster.conceder_invulnerabilidade(_time_left)  # Invulnerável pelo mesmo tempo.
	queue_redraw()  # Desenha o círculo.


## A cada quadro desconta o tempo e termina quando acaba.
func _physics_process(delta: float) -> void:
	_age += delta  # Soma o tempo.
	_time_left -= delta  # Desconta o tempo.
	queue_redraw()  # Redesenha.
	if _time_left <= 0.0:  # Acabou: termina.
		_finish()


## Cancelado antes do fim (ex.: lendária apagando as outras): a invulnerabilidade também termina.
func _on_cleanup() -> void:  # Se cancelado antes do fim, tira a invulnerabilidade.
	if _time_left > 0.0 and is_instance_valid(caster):  # Cancelado antes do fim.
		caster.remover_invulnerabilidade()  # Remove a invulnerabilidade.


## Desenha o círculo do escudo: preenchimento, borda pulsante e anel interno.
func _draw() -> void:
	var pulso: float = 0.5 + 0.5 * sin(_age * 8.0)  # Pulso (0 a 1).
	var alpha: float = 1.0  # Transparência normal.
	if _time_left < BLINK_TIME:  # Nos últimos instantes pisca.
		alpha = 0.35 + 0.65 * pulso  # Pisca.
	var fill: Color = shield_color  # Preenchimento.
	fill.a = 0.10 * alpha  # Muito transparente.
	draw_circle(Vector2.ZERO, radius, fill)  # Preenchimento.
	var borda: Color = shield_color  # Borda.
	borda.a = (0.55 + 0.35 * pulso) * alpha  # Pulsa.
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, borda, 2.0)  # Borda.
	var interna: Color = shield_color  # Anel interno.
	interna.a = 0.3 * alpha  # Mais transparente.
	draw_arc(Vector2.ZERO, radius - 4.0, 0.0, TAU, 48, interna, 1.0)  # Anel interno.
