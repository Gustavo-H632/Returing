class_name FireTrailEffect
extends AbilityEffect
## Rastro de Fogo: o próximo golpe de espada deixa chamas no chão, na direção do golpe.
## Espera o golpe por até `data.duration` segundos (8 s se a duração não estiver definida).

const DEFAULT_WAIT: float = 8.0  # Espera padrão se a habilidade não define a duração.

@export var zone_scene: PackedScene  # Cena da chama.

@export_group("Rastro")
## Quantas chamas o rastro tem.
@export_range(1, 8) var segments: int = 3
## Distância (px) do Player até a primeira chama.
@export var first_offset: float = 24.0
## Distância (px) entre as chamas.
@export var spacing: float = 30.0
@export var zone_radius: float = 30.0  # Raio de cada chama.
## Quanto tempo (s) cada chama fica no chão.
@export var zone_lifetime: float = 4.0
## Dano de cada tick e intervalo entre ticks (s).
@export var tick_damage: int = 6
@export var tick_interval: float = 0.5  # Intervalo entre ticks.

var _time_left: float = DEFAULT_WAIT  # Tempo restante de espera pelo golpe.
var _zones: Array[FireZone] = []  # Chamas já acesas.
var _consumed: bool = false  # True depois que o golpe usou o efeito.


## Prepara o efeito: cria as chamas no pool e espera o próximo golpe de espada.
func _on_activate() -> void:
	if caster.weapon == null or zone_scene == null:  # Sem arma ou sem chama: termina.
		_finish()
		return
	# Tempo de espera (a duração da habilidade).
	_time_left = data.duration if data != null and data.duration > 0.0 else DEFAULT_WAIT
	PoolHub.prewarm(zone_scene, caster, segments)  # cria as chamas antes do golpe
	# Escuta o começo do próximo golpe.
	CombatUtils.connect_once(caster.weapon.attack_started, _on_attack_started)


## Conta o tempo de espera; se o golpe não vier, o efeito termina.
func _physics_process(delta: float) -> void:
	_time_left -= delta  # Desconta o tempo.
	if _time_left <= 0.0 and not _consumed:  # Acabou o tempo sem golpe.
		_finish()


## O golpe de espada começou: acende as chamas na direção da mira e termina.
func _on_attack_started() -> void:
	if _consumed:  # Só uma vez.
		return
	_consumed = true  # Marca como usado.
	var dir: Vector2 = caster.aim_direction  # Direção da mira.
	for i: int in segments:  # Uma chama por segmento.
		# Pega uma chama do pool.
		var zone: FireZone = PoolHub.acquire(zone_scene, caster, FireZone) as FireZone
		if zone == null:  # Pool cheio: pula.
			continue
		# Acende a chama à frente do jogador.
		zone.ignite(caster.global_position + dir * (first_offset + spacing * float(i)),
				zone_radius, tick_damage, tick_interval, zone_lifetime, caster)
		_zones.append(zone)  # Guarda para poder cancelar.
	_finish()  # Termina o efeito (as chamas continuam queimando).


## Cancelar (ex.: lendária apagando as outras) também apaga as chamas já acesas.
## Cancelar também apaga as chamas já acesas.
func cancel() -> void:
	for zone: FireZone in _zones:  # Cada chama.
		if is_instance_valid(zone):  # Só se ainda existe.
			zone.recycle()  # Devolve ao pool.
	_zones.clear()  # Esvazia a lista.
	super.cancel()  # Cancela o efeito (classe base).


## Ao terminar desliga a escuta do golpe.
func _on_cleanup() -> void:
	if is_instance_valid(caster) and caster.weapon != null:  # Só se o jogador e a arma ainda existem.
		CombatUtils.disconnect_if_connected(caster.weapon.attack_started, _on_attack_started)
