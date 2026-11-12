class_name MeleeTelegraph
extends PooledArea
## Aviso de ataque em área (círculo no chão), reaproveitado pelo PoolHub.

enum Phase { CHARGING, IMPACT }  # Fases do aviso: carregando ou impacto.

@export var radius: float = 80.0  # Raio do círculo de aviso.
@export var warning_color: Color = Color(1.0, 0.2, 0.2, 0.35)  # Cor do aviso (vermelho translúcido).
@export var impact_color: Color = Color(1.0, 1.0, 0.6, 0.6)  # Cor do impacto (amarelo).
@export var impact_duration: float = 0.15  # Duração do impacto.
@export var pulse_amount: float = 0.06  # Intensidade do pulso do círculo.

@export_group("Sprites (opcional: sem textura desenha o círculo de antes)")
## Aviso: spritesheet horizontal; cada quadro mostra o progresso da carga (0 a 100 %).
@export var warning_sheet: Texture2D
## Impacto: spritesheet horizontal; os quadros passam durante `impact_duration`.
@export var impact_sheet: Texture2D
@export_range(1, 32) var warning_frames: int = 6  # Quadros da sheet de aviso.
@export_range(1, 32) var impact_frames: int = 5  # Quadros da sheet de impacto.

## Hitbox filha e a forma dela.
@export var hitbox: Hitbox
@export var hitbox_shape: CollisionShape2D  # Forma da hitbox (recebe o raio do aviso).

## Quem criou o telegraph (o dano é atribuído a ele).
var source: Node = null

var _phase: Phase = Phase.CHARGING  # Fase atual.
var _time_left: float = 1.0  # Tempo restante da fase.
var _visual_scale: float = 1.0  # Escala visual do círculo (pulsa).
var _charge_total: float = 1.0  # Duração total da carga (para o quadro do aviso).
var _impact_total: float = 0.15  # Duração total do impacto (para o quadro do impacto).


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
	_charge_total = maxf(charge_time, 0.001)  # Guarda a duração para animar o aviso.
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
			if impact_sheet != null:  # Com sprite, o impacto também precisa redesenhar a cada quadro.
				queue_redraw()
			if _time_left <= 0.0:  # Fim do impacto.
				# Garante o dano em quem ficou dentro
				hitbox.pulse(false)  # Garante o dano em quem ficou dentro.
				recycle()  # Volta ao pool.


## Desenha o círculo.
## Desenha o círculo de aviso (ou de impacto).
func _draw() -> void:
	var sheet: Texture2D = warning_sheet if _phase == Phase.CHARGING else impact_sheet
	if sheet != null:  # Com sprite: desenha o quadro (sem círculo).
		_draw_sheet_frame(sheet)
		return
	var color := warning_color if _phase == Phase.CHARGING else impact_color  # Cor da fase atual.
	draw_circle(Vector2.ZERO, radius * _visual_scale, color)  # Círculo com o pulso aplicado.


## Desenha o quadro da spritesheet pelo progresso da fase, do tamanho exato do círculo de dano.
func _draw_sheet_frame(sheet: Texture2D) -> void:
	var charging: bool = _phase == Phase.CHARGING
	var frames: int = warning_frames if charging else impact_frames
	var total: float = _charge_total if charging else _impact_total
	var progress: float = clampf(1.0 - _time_left / total, 0.0, 1.0)
	var index: int = clampi(int(progress * float(frames)), 0, frames - 1)
	var frame_w: float = float(sheet.get_width()) / float(frames)
	var source := Rect2(frame_w * float(index), 0.0, frame_w, float(sheet.get_height()))
	var dest := Rect2(Vector2(-radius, -radius), Vector2(radius * 2.0, radius * 2.0))
	draw_texture_rect_region(sheet, dest, source)


## Liga a hitbox no impacto.
## Entra na fase de impacto: liga a hitbox.
func _impact() -> void:
	_phase = Phase.IMPACT  # Fase de impacto.
	_time_left = impact_duration  # Duração do impacto.
	_impact_total = maxf(impact_duration, 0.001)  # Guarda a duração para animar o impacto.
	_visual_scale = 1.0  # Tamanho normal.
	# Liga a hitbox: acerta quem está dentro
	hitbox.set_active(true)  # Liga a hitbox para acertar quem está dentro.
	queue_redraw()  # Redesenha.
