class_name PooledArea
extends Area2D
## Área reaproveitável: nasce desligada, o ObjectPool a liga em acquire() e ela volta em recycle().

## Liga o `monitoring` do próprio nó enquanto está em uso (projéteis que escutam body_entered).
@export var monitor_while_active: bool = false

## Pool dono desta instância (preenchido pelo ObjectPool).
var pool: ObjectPool = null

var _in_use: bool = false  # True enquanto está em uso (fora do pool).


## Ao nascer fica solta do pai e invisível para detecção.
func _ready() -> void:
	# Posição própria no mundo: o pool fica sob o chefão, que se move.
	top_level = true  # Posição própria no mundo (não segue o pai).
	monitorable = false  # Só detecta; ninguém precisa detectá-la.


## Diz se a instância está em uso.
func is_in_use() -> bool:
	return _in_use


## Chamado pelo ObjectPool ao entregar a instância.
## Liga a instância: visível, com física e detecção opcional, e chama o gancho das subclasses.
func pool_activate() -> void:
	_in_use = true  # Marca como em uso.
	visible = true  # Aparece.
	set_physics_process(true)  # Liga a física.
	set_deferred(&"monitoring", monitor_while_active)  # Liga a detecção (adiado, por segurança).
	_on_pool_activate()  # Gancho para as subclasses.


## Chamado pelo ObjectPool ao recolher a instância.
## Desliga a instância: invisível, sem física e sem detecção, e chama o gancho das subclasses.
func pool_deactivate() -> void:
	_in_use = false  # Marca como livre.
	visible = false  # Some.
	# Só desliga o _physics_process: mexer em process_mode de um corpo durante um
	# callback de física (ex.: o acerto que devolve o tiro ao pool) gera erro.
	set_physics_process(false)  # Só desliga a física do nó.
	set_deferred(&"monitoring", false)  # Desliga a detecção (adiado).
	_on_pool_deactivate()  # Gancho para as subclasses.


## Devolve a instância ao pool (sem pool, libera o nó).
## Devolve a instância ao pool. Sem pool, libera o nó.
func recycle() -> void:
	if not _in_use:  # Já estava livre: nada a fazer.
		return
	if CombatUtils.is_valid(pool):  # Com pool: devolve.
		pool.release(self)
	else:
		queue_free()  # Sem pool: remove da cena.


## Gancho para subclasses ligarem o que precisam ao entrar em uso.
## Gancho vazio: as subclasses sobrescrevem para ligar o que precisam ao entrar em uso.
func _on_pool_activate() -> void:
	pass


## Gancho vazio: as subclasses sobrescrevem para desligar o que precisam ao voltar ao pool.
## Gancho para subclasses desligarem hitboxes e estados ao voltar ao pool.
func _on_pool_deactivate() -> void:
	pass
