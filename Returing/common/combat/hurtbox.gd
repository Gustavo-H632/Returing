class_name Hurtbox
extends Area2D
## Área que RECEBE dano (detectada por uma Hitbox).

signal damage_received(amount: int, source: Variant)  # Avisa que recebeu dano (quantidade e origem).

## Raiz da cena a quem esta Hurtbox pertence.
@export var actor: Node = null
## Opcional: entrega direto na vida, ignorando o ator.
@export var health_component: HealthComponent
@export var active_on_start: bool = true  # Se começa ligada.

var _active: bool = true  # True quando a área pode receber dano.


## Entra no grupo "hurtbox" (para as hitboxes a encontrarem), deixa de detectar e liga/desliga conforme `active_on_start`.
func _ready() -> void:
	add_to_group(CombatUtils.GROUP_HURTBOX)  # O grupo é como as hitboxes reconhecem alvos.
	monitoring = false  # Esta área só é detectada; não precisa detectar.
	set_active(active_on_start)


## API única de dano do projeto.
## Recebe um dano e o entrega ao dono. Devolve false se desligada, dano inválido ou dano recusado.
func take_damage(amount: int, source: Variant = null) -> bool:
	if not _active or amount <= 0:  # Desligada ou dano inválido: recusa.
		return false
	if not _deliver_damage(amount, source):  # Entrega o dano (à vida ou ao ator).
		return false
	damage_received.emit(amount, source)  # Avisa que o dano foi recebido.
	return true


## Liga ou desliga a área (desligada, as hitboxes deixam de enxergá-la).
func set_active(value: bool) -> void:
	_active = value  # Guarda o estado.
	# A física não aceita mudar `monitorable` no meio do quadro: usa a versão adiada.
	set_deferred(&"monitorable", value)


## Diz se a área está recebendo dano.
func is_active() -> bool:
	return _active


## Devolve o ator dono desta área.
func get_actor() -> Node:
	return CombatUtils.get_actor(self)


## Entrega o dano ao componente de vida (se houver) ou ao ator dono.
func _deliver_damage(amount: int, source: Variant) -> bool:
	if CombatUtils.is_valid(health_component):  # Prefere a vida direta.
		return health_component.take_damage(amount, source) > 0  # Dano aceito se tirou algo.
	var owner_actor: Node = get_actor()  # Procura o dono.
	if owner_actor == null or owner_actor == self:  # Sem dono (ou o dono é ela mesma): não há quem receba.
		return false
	return CombatUtils.apply_damage(owner_actor, amount, source)  # Usa a API única de dano.
