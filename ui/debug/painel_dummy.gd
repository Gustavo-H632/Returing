class_name PainelDummy
extends Control
## Painel de debug que chama as funções do DummyEnemy.

@export var dummy: DummyEnemy

@export_group("Referências (arraste os nós)")
@export var btn_dano: Button
@export var spin_dano: SpinBox
@export var btn_projetil: Button
@export var btn_onda: Button
@export var btn_espada: Button


## Acha o Dummy e liga os botões.
func _ready() -> void:
	if dummy == null:
		dummy = get_tree().get_first_node_in_group(DummyEnemy.GROUP_DUMMY) as DummyEnemy
	if dummy == null:
		push_warning("PainelDummy: nenhum DummyEnemy encontrado (grupo 'dummy_enemy').")
		return
	if btn_dano == null or spin_dano == null or btn_projetil == null or btn_onda == null or btn_espada == null:
		push_warning("PainelDummy: referências de botões não atribuídas no Inspector.")
		return
	btn_dano.pressed.connect(_ao_dano)
	btn_projetil.toggled.connect(_ao_projetil)
	btn_onda.toggled.connect(_ao_onda)
	btn_espada.pressed.connect(dummy.atacar_espada)


## Dano manual no Dummy.
func _ao_dano() -> void:
	dummy.receber_dano(int(spin_dano.value))


## Liga/desliga os tiros do Dummy.
func _ao_projetil(ligado: bool) -> void:
	if ligado:
		dummy.iniciar_ataque_projetil()
	else:
		dummy.parar_ataque_projetil()


## Liga/desliga as ondas do Dummy.
func _ao_onda(ligado: bool) -> void:
	if ligado:
		dummy.iniciar_ataque_onda()
	else:
		dummy.parar_ataque_onda()
