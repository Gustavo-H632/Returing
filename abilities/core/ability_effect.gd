class_name AbilityEffect
extends Node2D
## Base dos efeitos de habilidade. A cena do efeito é instanciada como filha do Player.
## As filhas sobrescrevem `_on_activate()` e `_on_cleanup()`; o efeito se remove sozinho ao terminar.

## Dados da habilidade que gerou o efeito (preenchido antes de `activate`).
var data: AbilityData = null
var caster: Player = null  # Jogador que usou a habilidade.

var _cleaned: bool = false  # True depois de limpar (a limpeza roda uma vez só).


## Liga o efeito.
## Liga o efeito: guarda quem usou e chama o gancho das subclasses.
func activate(new_caster: Player) -> void:
	caster = new_caster  # Guarda o jogador.
	_on_activate()  # Gancho `_on_activate` das subclasses.


## Interrompe o efeito (morte do Player, lendária apagando as outras) e desfaz o que ele aplicou.
## Interrompe o efeito antes do fim (jogador morreu ou lendária apagou as outras): desfaz tudo e remove o nó.
func cancel() -> void:
	_cleanup()  # Desfaz o que o efeito aplicou.
	queue_free()  # Remove da cena.


## Ao sair da cena garante a limpeza (evita deixar bônus presos).
func _exit_tree() -> void:
	_cleanup()  # Limpeza.


## Termina normalmente: desfaz o que aplicou e some.
## Termina normalmente: desfaz o que aplicou e some.
func _finish() -> void:
	_cleanup()  # Limpeza.
	queue_free()  # Remove da cena.


## Modificadores de atributo do Player (null se o componente já não existe).
## Acesso aos bônus de atributo do jogador; devolve null se o jogador ou o componente já não existem.
func get_stats() -> StatModifiers:
	if not is_instance_valid(caster):  # Jogador removido: sem bônus.
		return null
	var component: AbilityComponent = caster.abilities  # Componente de habilidades do jogador.
	if not is_instance_valid(component):  # Sem componente: sem bônus.
		return null
	return component.stats  # Entrega o gerenciador de bônus.


## Roda `_on_cleanup` uma única vez, mesmo se for chamada várias vezes.
func _cleanup() -> void:
	if _cleaned:  # Já limpou.
		return
	_cleaned = true  # Marca como limpa.
	_on_cleanup()  # Gancho das subclasses.


## Gancho: começa o efeito.
func _on_activate() -> void:
	pass


## Gancho: desfaz tudo que o efeito aplicou (roda uma única vez).
func _on_cleanup() -> void:
	pass
