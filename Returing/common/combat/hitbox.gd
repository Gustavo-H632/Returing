class_name Hitbox
extends Area2D
## Área que CAUSA dano.

# Avisa quando o golpe acerta uma área de dano (alvo e dano causado).
signal hit_landed(target: Area2D, damage_dealt: int)

@export var damage: int = 10  # Dano de cada acerto.
@export var active_on_start: bool = true  # Se começa ligada ao entrar na cena.
## Causa dano assim que uma Hurtbox entra na área.
@export var damage_on_contact: bool = true
## Impede que o mesmo alvo seja atingido mais de uma vez por ativação.
@export var one_hit_per_target: bool = true
## > 0 ativa dano contínuo.
@export_range(0.0, 10.0, 0.05, "or_greater") var tick_interval: float = 0.0
## Ignora Hurtboxes que pertencem ao mesmo ator.
@export var ignore_same_actor: bool = true
## Origem do dano (quem ataca).
@export var source: Node = null

var _active: bool = false  # True quando a hitbox está ligada.
## Alvos já atingidos nesta ativação.
var _already_hit: Dictionary[int, bool] = {}
var _tick_cooldowns: Dictionary[Area2D, float] = {}  # Area2D -> segundos até o próximo tick
## Alvos cujo cooldown venceu neste frame.
var _expired: Array[Area2D] = []
## pulse() pedido antes de `monitoring` entrar em vigor.
var _pending_pulse: bool = false
var _pending_pulse_reset: bool = false  # Se o pulso adiado deve limpar a lista de alvos já atingidos.


## Ao entrar na cena entra no grupo "hitbox", deixa de ser detectável e liga os sinais de entrar/sair de áreas.
func _ready() -> void:
	add_to_group(CombatUtils.GROUP_HITBOX)  # O grupo permite achar todas as áreas de dano.
	monitorable = false  # A hitbox só detecta; ninguém precisa detectá-la.
	CombatUtils.connect_once(area_entered, _on_area_entered)  # Quando uma área entra, tenta causar dano.
	# Quando uma área sai, para o dano contínuo nela.
	CombatUtils.connect_once(area_exited, _on_area_exited)
	if source == null:  # Sem origem definida, usa o dono da cena.
		source = CombatUtils.get_actor(self)
	set_active(active_on_start)  # Liga ou desliga conforme `active_on_start`.


## Dano contínuo por alvo e pulsos adiados.
## Roda só quando há dano contínuo ou um pulso adiado: executa o pulso e desconta os tempos de tick.
func _physics_process(delta: float) -> void:
	if _pending_pulse:  # Pulso pedido antes da detecção ligar: executa agora.
		_flush_pending_pulse()
	# Sem dano contínuo, desliga o processamento (economiza CPU).
	if not _active or tick_interval <= 0.0 or _tick_cooldowns.is_empty():
		_update_physics_process()
		return
	_advance_tick_cooldowns(delta)  # Desconta o tempo e aplica os ticks vencidos.


## Diz se a hitbox está ligada.
func is_active() -> bool:
	return _active


## Liga/desliga a hitbox.
## Liga ou desliga a hitbox. Ligar limpa os alvos já atingidos; desligar para o dano contínuo e cancela pulsos.
func set_active(value: bool) -> void:
	_active = value  # Guarda o novo estado.
	if value:  # Nova ativação: todos os alvos podem ser atingidos de novo.
		_already_hit.clear()
	else:
		_tick_cooldowns.clear()  # Para o dano contínuo.
		_pending_pulse = false  # Cancela o pulso adiado.
	# A física não deixa mudar `monitoring` no meio do quadro: usa a versão adiada.
	set_deferred(&"monitoring", value)
	for child: Node in get_children():  # Desliga também as formas de colisão.
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred(&"disabled", not value)  # Forma desativada não detecta nada.
	_update_physics_process()  # Liga ou desliga a física conforme precisar.


## Atalho para ligar a hitbox.
func activate() -> void:
	set_active(true)


## Atalho para desligar a hitbox.
func deactivate() -> void:
	set_active(false)


## One_shot true = um acerto por alvo; false = dano a cada tick.
## Reconfigura em tempo real: dano, um golpe por alvo (true) ou dano contínuo (false) e o intervalo dos ticks.
func configure(new_damage: int, new_one_shot: bool, new_tick_interval: float = 0.5) -> void:
	damage = new_damage  # Novo dano.
	one_hit_per_target = new_one_shot  # Um acerto por alvo?
	# Sem tick se for um acerto só; senão, o tick tem no mínimo 0,05 s.
	tick_interval = 0.0 if new_one_shot else maxf(new_tick_interval, 0.05)
	if is_node_ready():  # Só mexe na física se o nó já está pronto.
		_update_physics_process()


## Aplica dano imediatamente a tudo que está sobreposto.
## Dá dano agora em tudo que está sobreposto à área (usado por ataques instantâneos, como explosões).
func pulse(reset_hit_list: bool = true) -> void:
	if not _active:  # Desligada não causa dano.
		return
	if not monitoring:  # A detecção ainda não ligou: guarda o pedido para o próximo quadro.
		_pending_pulse = true
		_pending_pulse_reset = reset_hit_list
		_update_physics_process()
		return
	_do_pulse(reset_hit_list)  # Detecção ligada: executa na hora.


## Executa o pulso: opcionalmente limpa a lista de alvos e tenta acertar cada área sobreposta.
func _do_pulse(reset_hit_list: bool) -> void:
	if reset_hit_list:  # Pedido de limpar a lista.
		_already_hit.clear()
	for area: Area2D in get_overlapping_areas():  # Todas as áreas que já estão dentro.
		_try_hit(area, false)  # Tenta acertar cada uma (não é tick).


## Executa o pulso que ficou adiado, se a hitbox ainda estiver ligada e detectando.
func _flush_pending_pulse() -> void:
	_pending_pulse = false  # Limpa o pedido.
	if _active and monitoring:
		_do_pulse(_pending_pulse_reset)


## Desconta o tempo de cada alvo dentro da área e aplica o dano dos que venceram.
## Desconta o tempo de cada alvo dentro da área e aplica o dano dos que venceram.
func _advance_tick_cooldowns(delta: float) -> void:
	_expired.clear()  # Esvazia a lista de vencidos do quadro anterior.
	for area: Area2D in _tick_cooldowns:  # Para cada alvo dentro da área.
		if not CombatUtils.is_alive(area):  # Alvo que sumiu: marca para remover.
			_expired.append(area)
			continue
		var remaining: float = _tick_cooldowns[area] - delta  # Tempo que ainda falta para o próximo tick.
		_tick_cooldowns[area] = remaining  # Guarda o novo tempo.
		if remaining <= 0.0:  # Venceu: entra na lista de ticks.
			_expired.append(area)

	for area: Area2D in _expired:  # Aplica os ticks vencidos.
		if not CombatUtils.is_alive(area):  # Alvo sumiu no meio do caminho: tira da lista.
			_tick_cooldowns.erase(area)
			continue
		_try_hit(area, true)  # Causa o dano do tick.
		if not _active:  # O acerto pode ter desligado a hitbox (ex.: matou o alvo).
			return
		# O acerto pode ter matado o alvo (e disparado area_exited): só re-arma
		# quem ainda está na lista. O intervalo é somado (não zerado), assim
		# um frame longo não "come" ticks.
		if _tick_cooldowns.has(area):  # O alvo ainda está dentro?
			# Soma o intervalo (em vez de zerar) para um quadro longo não perder ticks.
			_tick_cooldowns[area] = _tick_cooldowns[area] + tick_interval


## _physics_process só roda quando há dano contínuo ou um pulso adiado.
## Liga a física só quando é preciso (dano contínuo ou pulso adiado).
func _update_physics_process() -> void:
	# Dano contínuo ativo ou pulso aguardando.
	set_physics_process(_pending_pulse or (_active and tick_interval > 0.0))


## Uma área entrou: se é um alvo válido, causa dano ou começa a contar os ticks.
func _on_area_entered(area: Area2D) -> void:
	if not _active or not _is_valid_target(area):  # Ignora quando desligada ou com alvo inválido.
		return
	if tick_interval > 0.0:  # Dano contínuo: registra o alvo.
		if damage_on_contact:  # Já dá o primeiro dano ao encostar.
			_try_hit(area, true)
		_tick_cooldowns[area] = tick_interval  # Programa o próximo tick.
		_update_physics_process()  # Liga a física para contar.
	elif damage_on_contact:  # Dano de um golpe só.
		_try_hit(area, false)  # Acerta uma vez.


## Uma área saiu: para o dano contínuo nela.
func _on_area_exited(area: Area2D) -> void:
	_tick_cooldowns.erase(area)  # Esquece o alvo.


## Só Hurtboxes ativas de outro ator.
## Só aceita Hurtboxes vivas, e de outro ator (a menos que `ignore_same_actor` esteja desligado).
func _is_valid_target(area: Area2D) -> bool:
	# Precisa estar viva e no grupo de áreas que recebem dano.
	if not CombatUtils.is_alive(area) or not area.is_in_group(CombatUtils.GROUP_HURTBOX):
		return false
	# Não acerta o próprio dono.
	if ignore_same_actor and source != null and CombatUtils.get_actor(area) == source:
		return false
	return true


## Aplica o dano.
## Tenta acertar a área. Devolve true se o dano foi aplicado.
func _try_hit(area: Area2D, is_tick: bool) -> bool:
	if not _active or not _is_valid_target(area):  # Desligada ou alvo inválido: não acerta.
		return false
	var target_id: int = area.get_instance_id()  # Identificador do alvo.
	# Golpes únicos não repetem no mesmo alvo.
	if not is_tick and one_hit_per_target and _already_hit.has(target_id):
		return false
	if not CombatUtils.apply_damage(area, damage, source):  # Dano recusado (ex.: invulnerável).
		return false
	if not is_tick:  # Registra o acerto (ticks podem repetir).
		_already_hit[target_id] = true
	hit_landed.emit(area, damage)  # Avisa quem escuta.
	return true
