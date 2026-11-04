class_name PooledArea
extends Area2D
## Área reaproveitável: nasce desligada, o ObjectPool a liga em acquire() e ela volta em recycle().

## Liga o `monitoring` do próprio nó enquanto está em uso (projéteis que escutam body_entered).
@export var monitor_while_active: bool = false

## Pool dono desta instância (preenchido pelo ObjectPool).
var pool: ObjectPool = null

var _in_use: bool = false


func _ready() -> void:
	# Posição própria no mundo: o pool fica sob o chefão, que se move.
	top_level = true
	monitorable = false


func is_in_use() -> bool:
	return _in_use


## Chamado pelo ObjectPool ao entregar a instância.
func pool_activate() -> void:
	_in_use = true
	visible = true
	set_physics_process(true)
	set_deferred(&"monitoring", monitor_while_active)
	_on_pool_activate()


## Chamado pelo ObjectPool ao recolher a instância.
func pool_deactivate() -> void:
	_in_use = false
	visible = false
	# Só desliga o _physics_process: mexer em process_mode de um corpo durante um
	# callback de física (ex.: o acerto que devolve o tiro ao pool) gera erro.
	set_physics_process(false)
	set_deferred(&"monitoring", false)
	_on_pool_deactivate()


## Devolve a instância ao pool (sem pool, libera o nó).
func recycle() -> void:
	if not _in_use:
		return
	if CombatUtils.is_valid(pool):
		pool.release(self)
	else:
		queue_free()


## Gancho para subclasses ligarem o que precisam ao entrar em uso.
func _on_pool_activate() -> void:
	pass


## Gancho para subclasses desligarem hitboxes e estados ao voltar ao pool.
func _on_pool_deactivate() -> void:
	pass
