class_name PainelDummy
extends Control
## Painel de debug que chama as funções do DummyEnemy.

@export var dummy: DummyEnemy  # Dummy controlado pelo painel.

@export_group("Referências (arraste os nós)")
@export var btn_dano: Button  # Botão de dano manual.
@export var spin_dano: SpinBox  # Valor do dano manual.
@export var btn_projetil: Button  # Liga/desliga os tiros.
@export var btn_onda: Button  # Liga/desliga as ondas.
@export var btn_espada: Button  # Dispara um golpe de espada.


## Acha o Dummy e liga os botões.
func _ready() -> void:
	if dummy == null:  # Sem Dummy definido: procura no grupo.
		dummy = get_tree().get_first_node_in_group(DummyEnemy.GROUP_DUMMY) as DummyEnemy
	if dummy == null:  # Nenhum Dummy na cena.
		push_warning("PainelDummy: nenhum DummyEnemy encontrado (grupo 'dummy_enemy').")  # Avisa no console.
		return
	# Falta algum botão.
	if btn_dano == null or spin_dano == null or btn_projetil == null or btn_onda == null or btn_espada == null:
		push_warning("PainelDummy: referências de botões não atribuídas no Inspector.")  # Avisa no console.
		return
	btn_dano.pressed.connect(_ao_dano)  # Dano manual.
	btn_projetil.toggled.connect(_ao_projetil)  # Tiros ligam e desligam.
	btn_onda.toggled.connect(_ao_onda)  # Ondas ligam e desligam.
	btn_espada.pressed.connect(dummy.atacar_espada)  # Golpe de espada.


## Dano manual no Dummy.
func _ao_dano() -> void:
	dummy.receber_dano(int(spin_dano.value))  # Aplica o dano digitado.


## Liga/desliga os tiros do Dummy.
func _ao_projetil(ligado: bool) -> void:
	if ligado:  # Liga os tiros.
		dummy.iniciar_ataque_projetil()
	else:  # Desliga os tiros.
		dummy.parar_ataque_projetil()


## Liga/desliga as ondas do Dummy.
func _ao_onda(ligado: bool) -> void:
	if ligado:  # Liga as ondas.
		dummy.iniciar_ataque_onda()
	else:  # Desliga as ondas.
		dummy.parar_ataque_onda()
