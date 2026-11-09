class_name WarningCircle
extends GuideAttack
## Círculo de aviso no chão: vermelho enquanto carrega e amarelo (com dano) quando dispara.

enum Phase { WARNING, ACTIVE }  # Fases do círculo: aviso e dano.

## Cor do aviso (vermelho).
const COLOR_WARNING: Color = Color(1.0, 0.15, 0.15, 0.35)
## Cor do preenchimento que mostra quanto falta para disparar.
const COLOR_FILL: Color = Color(1.0, 0.15, 0.15, 0.35)
## Cor do círculo que causa dano (amarelo).
const COLOR_ACTIVE: Color = Color(1.0, 0.9, 0.15, 0.6)
## Cor do contorno.
const COLOR_OUTLINE: Color = Color(0.1, 0.0, 0.0, 0.8)
const OUTLINE_WIDTH: float = 2.0  # Espessura do contorno.
const ARC_POINTS: int = 48  # Pontos do círculo.

var _radius: float = 56.0  # Raio.
var _phase: Phase = Phase.WARNING  # Fase atual.
var _warning_time: float = 2.0  # Duração do aviso.
var _active_time: float = 0.3  # Duração do dano.
var _time_left: float = 0.0  # Tempo restante da fase.
var _damage: int = 0  # Dano.


## Posiciona o círculo e começa a contagem do aviso.
func launch(center: Vector2, radius: float, warning_time: float, active_time: float, damage: int,
		from_source: Node) -> void:
	global_position = center  # Posição do círculo.
	source = from_source  # Quem lançou.
	_radius = maxf(radius, 1.0)  # Raio mínimo.
	_warning_time = maxf(warning_time, 0.01)  # Aviso mínimo.
	_active_time = maxf(active_time, 0.01)  # Dano mínimo.
	_damage = damage  # Dano.
	_phase = Phase.WARNING  # Começa avisando.
	_time_left = _warning_time  # Tempo do aviso.
	set_hit_radius(_radius)  # Raio da hitbox.
	queue_redraw()  # Redesenha.


## Conta o aviso, liga o dano e devolve o círculo ao pool.
func _physics_process(delta: float) -> void:
	_time_left -= delta  # Desconta o tempo.
	if _time_left > 0.0:  # Fase ainda em andamento.
		if _phase == Phase.WARNING:  # No aviso, o preenchimento cresce.
			queue_redraw()  # o preenchimento cresce com o tempo
		return
	match _phase:  # A fase terminou.
		Phase.WARNING:
			_phase = Phase.ACTIVE  # Aviso terminou: começa o dano.
			_time_left = _active_time  # Entra na fase de dano.
			arm(_damage)  # Tempo do dano.
			queue_redraw()  # Liga a hitbox.
		Phase.ACTIVE:  # Redesenha.
			recycle()  # Fase de dano acabou.


## Vermelho com preenchimento crescente; amarelo no disparo.
func _draw() -> void:
	if _phase == Phase.ACTIVE:
		draw_circle(Vector2.ZERO, _radius, COLOR_ACTIVE)
	else:
		draw_circle(Vector2.ZERO, _radius, COLOR_WARNING)
		var progress: float = clampf(1.0 - _time_left / _warning_time, 0.0, 1.0)
		draw_circle(Vector2.ZERO, _radius * progress, COLOR_FILL)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, ARC_POINTS, COLOR_OUTLINE, OUTLINE_WIDTH)
