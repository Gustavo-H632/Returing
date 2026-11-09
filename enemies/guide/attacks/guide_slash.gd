class_name GuideSlash
extends GuideAttack
## Golpe de espada em área ao redor do Guide: avisa, corta uma vez e some.

enum Phase { WINDUP, ACTIVE }  # Fases do golpe: aviso e corte.

const COLOR_WINDUP: Color = Color(1.0, 0.15, 0.15, 0.3)  # Cor do aviso.
const COLOR_FILL: Color = Color(1.0, 0.15, 0.15, 0.3)  # Cor do preenchimento que cresce.
const COLOR_ACTIVE: Color = Color(0.9, 0.95, 1.0, 0.7)  # Cor do corte.
const COLOR_OUTLINE: Color = Color(0.1, 0.0, 0.0, 0.8)  # Cor do contorno.
const OUTLINE_WIDTH: float = 3.0  # Espessura do contorno.
const ARC_POINTS: int = 64  # Pontos do círculo.
## Riscos radiais desenhados no golpe (efeito de lâminas).
const BLADE_COUNT: int = 8
const BLADE_WIDTH: float = 3.0  # Largura dos riscos.

var _radius: float = 84.0  # Raio do golpe.
var _phase: Phase = Phase.WINDUP  # Fase atual.
var _windup_time: float = 0.6  # Duração do aviso.
var _active_time: float = 0.15  # Duração do corte.
var _time_left: float = 0.0  # Tempo restante da fase.
var _damage: int = 0  # Dano.
## Nó que o círculo acompanha durante o aviso (o corpo do chefão).
var _anchor: Node2D = null


## Prepara o golpe: o círculo acompanha `anchor` até o impacto.
func launch(anchor: Node2D, radius: float, windup_time: float, active_time: float, damage: int,
		from_source: Node) -> void:
	_anchor = anchor  # Guarda o chefão.
	global_position = anchor.global_position  # Nasce em cima dele.
	source = from_source  # Quem lançou.
	_radius = maxf(radius, 1.0)  # Raio mínimo.
	_windup_time = maxf(windup_time, 0.01)  # Aviso mínimo.
	_active_time = maxf(active_time, 0.01)  # Corte mínimo.
	_damage = damage  # Dano.
	_phase = Phase.WINDUP  # Começa avisando.
	_time_left = _windup_time  # Tempo do aviso.
	set_hit_radius(_radius)  # Raio da hitbox.
	queue_redraw()  # Redesenha.


## Duração total do golpe (aviso + janela de dano).
## Soma o tempo do aviso com o do corte.
func get_total_time() -> float:
	return _windup_time + _active_time  # Duração total.


## A cada quadro: acompanha o chefão no aviso, liga o dano no fim dele e volta ao pool depois do corte.
func _physics_process(delta: float) -> void:
	_time_left -= delta  # Desconta o tempo.
	if _phase == Phase.WINDUP and CombatUtils.is_alive(_anchor):  # No aviso, o círculo segue o chefão.
		global_position = _anchor.global_position  # Acompanha.
	if _time_left > 0.0:  # Fase ainda em andamento.
		if _phase == Phase.WINDUP:  # Redesenha o preenchimento.
			queue_redraw()
		return
	match _phase:  # A fase terminou.
		Phase.WINDUP:  # Aviso terminou: começa o corte.
			_phase = Phase.ACTIVE  # Entra no corte.
			_time_left = _active_time  # Tempo do corte.
			arm(_damage)  # Liga a hitbox.
			queue_redraw()  # Redesenha.
		Phase.ACTIVE:  # Corte terminou.
			recycle()  # Volta ao pool.


## Desenha o círculo (aviso com preenchimento crescente ou corte com riscos de lâmina) e o contorno.
func _draw() -> void:
	if _phase == Phase.ACTIVE:  # Corte.
		draw_circle(Vector2.ZERO, _radius, COLOR_ACTIVE)  # Círculo do corte.
		for i: int in BLADE_COUNT:  # Riscos radiais.
			# Um risco por lâmina.
			draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(TAU * float(i) / float(BLADE_COUNT)) * _radius,
					COLOR_OUTLINE, BLADE_WIDTH)
	else:  # Aviso.
		draw_circle(Vector2.ZERO, _radius, COLOR_WINDUP)  # Círculo do aviso.
		var progress: float = clampf(1.0 - _time_left / _windup_time, 0.0, 1.0)  # Progresso do aviso (0 a 1).
		draw_circle(Vector2.ZERO, _radius * progress, COLOR_FILL)  # Preenchimento cresce com o progresso.
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, ARC_POINTS, COLOR_OUTLINE, OUTLINE_WIDTH)  # Contorno.
