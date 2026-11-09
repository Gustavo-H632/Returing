class_name FireZone
extends PooledArea
## Chão em chamas deixado pelo Rastro de Fogo: causa dano por tick em quem estiver dentro e some.

@export var flame_color: Color = Color(1.0, 0.45, 0.1, 0.6)  # Cor da chama.
@export var core_color: Color = Color(1.0, 0.85, 0.3, 0.8)  # Cor do miolo da chama.

## Quantos pontos de chama são desenhados dentro da área.
const FLAME_COUNT: int = 6
## Tempo final (s) em que a chama esmaece.
const FADE_TIME: float = 0.6
## Intervalo (s) entre redesenhos da chama.
const REDRAW_INTERVAL: float = 0.08

var _damage: int = 0  # Dano de cada tick.
var _tick_interval: float = 0.5  # Intervalo entre ticks.
var _life_left: float = 0.0  # Vida restante.
var _tick_left: float = 0.0  # Tempo até o próximo tick.
var _radius: float = 30.0  # Raio da chama.
var _source: Node = null  # Quem acendeu (recebe o crédito do dano).
var _redraw_left: float = 0.0  # Tempo até o próximo redesenho.
## Tempo de vida acumulado (anima a chama junto com o tempo do jogo, que congela na pausa).
var _age: float = 0.0
var _overlapping: Array[Area2D] = []  # Áreas que estão dentro da chama.

@onready var _shape: CollisionShape2D = $CollisionShape2D  # Forma de colisão da chama.


## Liga os sinais de entrar e sair da chama.
func _ready() -> void:
	super._ready()  # Prepara o PooledArea.
	area_entered.connect(_on_area_entered)  # Entrou uma área.
	area_exited.connect(_on_area_exited)  # Saiu uma área.


## Acende a chama em `origin`.
## Acende a chama em `origin` e reinicia todo o estado (a instância vem do pool).
func ignite(origin: Vector2, radius: float, damage: int, tick_interval: float, lifetime: float, source: Node) -> void:
	global_position = origin  # Posição.
	_radius = radius  # Raio.
	_damage = damage  # Dano.
	_tick_interval = maxf(tick_interval, 0.05)  # Intervalo mínimo de 0,05 s.
	_life_left = maxf(lifetime, 0.1)  # Vida mínima de 0,1 s.
	_age = 0.0  # Zera o tempo.
	_tick_left = 0.0  # O primeiro tick sai já.
	_source = source  # Guarda quem acendeu.
	_overlapping.clear()  # Esquece as áreas antigas.
	CombatUtils.set_unique_circle_radius(_shape, radius)  # Forma própria com o raio.
	queue_redraw()  # Redesenha.


## Ao voltar ao pool esquece as áreas e quem acendeu.
func _on_pool_deactivate() -> void:
	_overlapping.clear()
	_source = null


## A cada quadro: desconta a vida, dá dano nos ticks e redesenha a chama.
func _physics_process(delta: float) -> void:
	_age += delta  # Soma o tempo.
	_life_left -= delta  # Desconta a vida.
	if _life_left <= 0.0:  # Acabou: volta ao pool.
		recycle()
		return
	_tick_left -= delta  # Desconta o tempo do tick.
	if _tick_left <= 0.0:  # Hora de queimar.
		_tick_left += _tick_interval  # Soma o intervalo (não perde ticks se o quadro for longo).
		_burn()  # Dá o dano.
	_redraw_left -= delta  # Desconta o tempo do redesenho.
	if _redraw_left <= 0.0:  # Hora de redesenhar.
		_redraw_left = REDRAW_INTERVAL
		queue_redraw()


## Causa dano em todo mundo que está dentro da chama.
func _burn() -> void:  # Quem recebe o crédito do dano.
	var origem: Node = _source if CombatUtils.is_alive(_source) else self
	# De trás para frente, para remover sem pular itens.
	for i: int in range(_overlapping.size() - 1, -1, -1):
		var area: Area2D = _overlapping[i]  # Área atual.
		if not CombatUtils.is_alive(area):  # Área sumiu.
			_overlapping.remove_at(i)  # Remove.
			continue
		CombatUtils.apply_damage(area, _damage, origem)  # Dá o dano.


## Uma área entrou: guarda se for uma hurtbox.
func _on_area_entered(area: Area2D) -> void:
	# Só hurtboxes, sem repetir.
	if area.is_in_group(CombatUtils.GROUP_HURTBOX) and not _overlapping.has(area):
		_overlapping.append(area)


## Uma área saiu: esquece.
func _on_area_exited(area: Area2D) -> void:
	_overlapping.erase(area)


## Desenha a chama: base circular e várias labaredas que balançam.
func _draw() -> void:
	var fade: float = clampf(_life_left / FADE_TIME, 0.0, 1.0)  # Esmaece nos últimos instantes.
	var t: float = _age  # Tempo para balançar.
	var base: Color = flame_color  # Cor base.
	base.a *= 0.35 * fade  # Base translúcida.
	draw_circle(Vector2.ZERO, _radius, base)  # Desenha a base.
	for i: int in FLAME_COUNT:  # Uma labareda por ponto.
		var ang: float = TAU * float(i) / float(FLAME_COUNT) + float(i) * 0.7  # Ângulo da labareda.
		var dist: float = _radius * (0.25 + 0.45 * fmod(float(i) * 0.37, 1.0))  # Distância do centro.
		var centro: Vector2 = Vector2.from_angle(ang) * dist  # Posição da labareda.
		# Altura (balança com o tempo).
		var altura: float = _radius * (0.45 + 0.25 * sin(t * 9.0 + float(i) * 1.7))
		var largura: float = _radius * 0.2  # Largura.
		var cor: Color = flame_color  # Cor da labareda.
		cor.a *= fade  # Transparência.
		draw_colored_polygon(PackedVector2Array([  # Triângulo da labareda.
			centro + Vector2(-largura, 0.0),
			centro + Vector2(0.0, -altura),
			centro + Vector2(largura, 0.0),
		]), cor)
		var miolo: Color = core_color  # Cor do miolo.
		miolo.a *= fade  # Transparência.
		draw_colored_polygon(PackedVector2Array([  # Triângulo do miolo.
			centro + Vector2(-largura * 0.5, 0.0),
			centro + Vector2(0.0, -altura * 0.55),
			centro + Vector2(largura * 0.5, 0.0),
		]), miolo)
