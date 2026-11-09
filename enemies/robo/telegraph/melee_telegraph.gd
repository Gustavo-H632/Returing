class_name MeleeTelegraph
extends PooledArea
## Aviso de ataque em área (círculo no chão), reaproveitado pelo PoolHub.

enum Phase { CHARGING, IMPACT }  # Fases do aviso: carregando ou impacto.

@export var radius: float = 80.0  # Raio do círculo de aviso.
@export var warning_color: Color = Color(1.0, 0.2, 0.2, 0.35)  # Cor do aviso (vermelho translúcido).
@export var impact_color: Color = Color(1.0, 1.0, 0.6, 0.6)  # Cor do impacto (amarelo).
@export var impact_duration: float = 0.15  # Duração do impacto.
@export var pulse_amount: float = 0.06  # Intensidade do pulso do círculo.

## Hitbox filha e a forma dela.
@export var hitbox: Hitbox
@export var hitbox_shape: CollisionShape2D  # Forma da hitbox (recebe o raio do aviso).

## Quem criou o telegraph (o dano é atribuído a ele).
var source: Node = null

var _phase: Phase = Phase.CHARGING  # Fase atual.
var _time_left: float = 1.0  # Tempo restante da fase.
var _visual_scale: float = 1.0  # Escala visual do círculo (pulsa).


## Raio próprio (a forma é do telegraph, não da cena) e hitbox desligada.
## Define o raio da hitbox e a deixa desligada (nesta fase só avisa).
func _ready() -> void:
	super._ready()  # Prepara o PooledArea.
	if hitbox == null:  # Sem hitbox não funciona.
		push_error("MeleeTelegraph: 'hitbox' não foi atribuído no Inspector.")  # Avisa o erro.
		set_physics_process(false)  # Desliga a física.
		return
	# Dá à forma da hitbox um círculo próprio do tamanho do aviso.
	CombatUtils.set_unique_circle_radius(hitbox_shape, radius)
	hitbox.set_active(false)  # só avisa


## Começa o aviso em `center`: carrega `charge_time` s e depois causa `damage`.
## Começa o aviso em `center`: carrega por `charge_time` segundos e depois causa o dano.
func launch(center: Vector2, charge_time: float, damage: int, from_source: Node) -> void:
	global_position = center  # Posição do aviso.
	source = from_source  # Quem criou.
	_phase = Phase.CHARGING  # Começa carregando.
	_time_left = maxf(charge_time, 0.0)  # Tempo de carga.
	_visual_scale = 1.0  # Escala inicial.
	if hitbox != null:  # Hitbox existe.
		hitbox.configure(damage, true)  # Um acerto por alvo.
		hitbox.source = source  # Quem causa o dano.
		hitbox.damage_on_contact = true  # Dá dano ao encostar.
		hitbox.set_active(false)  # Continua desligada até o impacto.
	queue_redraw()  # Redesenha.


## Ao voltar ao pool, desliga a hitbox.
func _on_pool_deactivate() -> void:
	if hitbox != null:  # Hitbox existe.
		hitbox.set_active(false)


## Carga com pulso visual e depois o impacto.
## A cada quadro: desconta o tempo e alterna as fases (carga com pulso visual, depois impacto).
func _physics_process(delta: float) -> void:
	_time_left -= delta  # Desconta o tempo.
	match _phase:
		Phase.CHARGING:  # Carregando.
			# Pulso só no desenho
			_visual_scale = 1.0 + sin(Time.get_ticks_msec() / 100.0) * pulse_amount  # O círculo pulsa no desenho.
			queue_redraw()  # Redesenha.
			if _time_left <= 0.0:  # Acabou a carga: impacto.
				_impact()
		Phase.IMPACT:
			if _time_left <= 0.0:  # Fim do impacto.
				# Garante o dano em quem ficou dentro
				hitbox.pulse(false)  # Garante o dano em quem ficou dentro.
				recycle()  # Volta ao pool.


## Desenha o círculo.
## Desenha o círculo de aviso (ou de impacto).
func _draw() -> void:
	var color := warning_color if _phase == Phase.CHARGING else impact_color  # Cor da fase atual.
	draw_circle(Vector2.ZERO, radius * _visual_scale, color)  # Círculo com o pulso aplicado.


## Liga a hitbox no impacto.
## Entra na fase de impacto: liga a hitbox.
func _impact() -> void:
	_phase = Phase.IMPACT  # Fase de impacto.
	_time_left = impact_duration  # Duração do impacto.
	_visual_scale = 1.0  # Tamanho normal.
	# Liga a hitbox: acerta quem está dentro
	hitbox.set_active(true)  # Liga a hitbox para acertar quem está dentro.
	queue_redraw()  # Redesenha.
