class_name EnemyHealthBar
extends Node2D
## Barra de vida que flutua acima do inimigo.

## Cor da barra cheia.
const COR_CHEIA: Color = Color(0.36, 0.84, 0.39)
## Cor da barra pela metade.
const COR_MEIA: Color = Color(0.95, 0.74, 0.22)
## Cor da barra quase vazia.
const COR_BAIXA: Color = Color(0.89, 0.26, 0.24)
## Cor do trilho de trás.
const COR_TRILHO: Color = Color(0.07, 0.07, 0.10, 0.85)
## Cor do contorno.
const COR_CONTORNO: Color = Color(0.02, 0.02, 0.03, 0.95)
## Cor da lasca que mostra o tamanho do golpe.
const COR_LASCA: Color = Color(0.98, 0.98, 0.98, 0.85)
## Brilho em cima, que dá volume à barra.
const COR_BRILHO: Color = Color(1.0, 1.0, 1.0, 0.22)
## Abaixo disso a barra pulsa.
const RAZAO_BAIXA: float = 0.25
## Velocidade do pulso.
const VELOCIDADE_PULSO: float = 7.0
## Força do pulso.
const FORCA_PULSO: float = 0.25

@export_group("Tamanho")
## Largura da barra.
@export_range(8.0, 200.0, 1.0, "or_greater") var width: float = 34.0
## Altura da barra.
@export_range(2.0, 24.0, 0.5, "or_greater") var height: float = 5.0
## Grossura do contorno.
@export_range(0.0, 6.0, 0.5) var outline_width: float = 1.0

@export_group("Comportamento")
## Liga para a barra ficar sempre na tela, mesmo sem apanhar.
@export var always_visible: bool = false
## Segundos sem levar dano até sumir.
@export_range(0.0, 30.0, 0.5, "or_greater") var hide_delay: float = 3.0
## Tempo do aparecer e do sumir.
@export_range(0.05, 2.0, 0.05) var fade_time: float = 0.25
## Velocidade da lasca branca.
@export_range(0.1, 10.0, 0.1, "or_greater") var chip_speed: float = 0.9
## Espera antes de a lasca começar a escorrer.
@export_range(0.0, 2.0, 0.05) var chip_delay: float = 0.25

var _ratio: float = 1.0
var _chip_ratio: float = 1.0
var _chip_wait: float = 0.0
var _visible_time: float = 0.0
var _alpha: float = 0.0
var _dead: bool = false
var _health: HealthComponent = null


## Começa escondida, a não ser que seja para ficar sempre na tela.
func _ready() -> void:
	if always_visible:
		_alpha = 1.0
		modulate.a = 1.0
		visible = true
		set_process(true)
	else:
		modulate.a = 0.0
		visible = false
		set_process(false)
	queue_redraw()


## Liga a barra a uma vida.
func bind(health: HealthComponent) -> void:
	if _health == health:
		return
	_desligar_vida()
	_health = health
	if _health == null:
		return
	CombatUtils.connect_once(_health.health_changed, _on_health_changed)
	CombatUtils.connect_once(_health.damaged, _on_damaged)
	_ratio = _health.get_ratio()
	_chip_ratio = _ratio
	queue_redraw()


## Solta os sinais ao sair da cena.
func _exit_tree() -> void:
	_desligar_vida()


## Desconecta os sinais da vida.
func _desligar_vida() -> void:
	if not CombatUtils.is_valid(_health):
		_health = null
		return
	if _health.health_changed.is_connected(_on_health_changed):
		_health.health_changed.disconnect(_on_health_changed)
	if _health.damaged.is_connected(_on_damaged):
		_health.damaged.disconnect(_on_damaged)
	_health = null


## Some de vez, quando o inimigo morre.
func dismiss() -> void:
	_dead = true
	set_process(false)
	visible = false
	modulate.a = 0.0


## Mostra a barra e reinicia a contagem para ela sumir.
func show_now() -> void:
	if _dead:
		return
	_visible_time = 0.0
	visible = true
	set_process(true)
	queue_redraw()


## Guarda a vida nova.
func _on_health_changed(current_health: int, max_health: int) -> void:
	_ratio = clampf(float(current_health) / float(maxi(max_health, 1)), 0.0, 1.0)
	if _ratio > _chip_ratio:
		_chip_ratio = _ratio
	queue_redraw()


## Levou dano: aparece.
func _on_damaged(_amount: int) -> void:
	_chip_wait = chip_delay
	show_now()


## Cuida do aparecer, do sumir e da lasca.
func _process(delta: float) -> void:
	var aparecendo: bool = always_visible or hide_delay <= 0.0 or _visible_time < hide_delay
	_visible_time += delta
	_alpha = move_toward(_alpha, 1.0 if aparecendo else 0.0, delta / maxf(fade_time, 0.01))
	modulate.a = _alpha

	var lasca_andando: bool = _andar_lasca(delta)
	if _alpha <= 0.0 and not aparecendo:
		visible = false
		set_process(false)
		return
	if lasca_andando or _ratio < RAZAO_BAIXA:
		queue_redraw()


## Escorre a lasca branca até a vida atual.
func _andar_lasca(delta: float) -> bool:
	if is_equal_approx(_chip_ratio, _ratio):
		return false
	if _chip_wait > 0.0:
		_chip_wait -= delta
		return true
	_chip_ratio = move_toward(_chip_ratio, _ratio, chip_speed * delta)
	return true


## Desenha contorno, trilho, lasca e preenchimento.
func _draw() -> void:
	var meia: float = width * 0.5
	var caixa := Rect2(-meia, -height * 0.5, width, height)
	var raio: float = height * 0.5

	if outline_width > 0.0:
		_desenhar_capsula(caixa.grow(outline_width), raio + outline_width, COR_CONTORNO)
	_desenhar_capsula(caixa, raio, COR_TRILHO)
	if _chip_ratio > 0.0:
		_desenhar_preenchimento(caixa, raio, _chip_ratio, COR_LASCA)
	if _ratio > 0.0:
		_desenhar_preenchimento(caixa, raio, _ratio, _cor_atual())
		_desenhar_brilho(caixa, _ratio)


## Desenha a parte preenchida da barra.
func _desenhar_preenchimento(caixa: Rect2, raio: float, razao: float, cor: Color) -> void:
	var cheio: float = caixa.size.x * clampf(razao, 0.0, 1.0)
	if cheio <= 0.0:
		return
	_desenhar_capsula(Rect2(caixa.position, Vector2(maxf(cheio, raio * 2.0), caixa.size.y)), raio, cor)


## Desenha a faixa clara em cima.
func _desenhar_brilho(caixa: Rect2, razao: float) -> void:
	var cheio: float = caixa.size.x * clampf(razao, 0.0, 1.0)
	if cheio <= 2.0:
		return
	draw_rect(Rect2(caixa.position + Vector2(1.0, 1.0),
			Vector2(cheio - 2.0, maxf(caixa.size.y * 0.35, 1.0))), COR_BRILHO)


## Desenha um retângulo de pontas redondas.
func _desenhar_capsula(caixa: Rect2, raio: float, cor: Color) -> void:
	var r: float = minf(raio, caixa.size.y * 0.5)
	if r <= 0.5 or caixa.size.x <= r * 2.0:
		draw_rect(caixa, cor)
		return
	var meio_y: float = caixa.position.y + caixa.size.y * 0.5
	draw_rect(Rect2(caixa.position.x + r, caixa.position.y, caixa.size.x - r * 2.0, caixa.size.y), cor)
	draw_circle(Vector2(caixa.position.x + r, meio_y), r, cor)
	draw_circle(Vector2(caixa.position.x + caixa.size.x - r, meio_y), r, cor)


## Verde, âmbar ou vermelho conforme a vida; pulsa quando está acabando.
func _cor_atual() -> Color:
	var cor: Color = COR_MEIA.lerp(COR_CHEIA, inverse_lerp(0.5, 1.0, _ratio)) if _ratio >= 0.5 \
			else COR_BAIXA.lerp(COR_MEIA, inverse_lerp(0.0, 0.5, _ratio))
	if _ratio >= RAZAO_BAIXA:
		return cor
	var pulso: float = (sin(_visible_time * VELOCIDADE_PULSO) * 0.5 + 0.5) * FORCA_PULSO
	return cor.lerp(Color.WHITE, pulso)
