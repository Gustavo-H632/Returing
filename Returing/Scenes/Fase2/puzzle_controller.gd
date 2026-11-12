class_name PuzzleController
extends Node2D
## Puzzle da sala nova: ligar os 3 painéis na ordem certa (a dica fica desenhada no chão perto do início).
## Os painéis são filhos deste nó. Ordem errada = tudo apaga e recomeça.

signal puzzle_solved  # Os três painéis foram ligados na ordem certa (emitido uma única vez).
signal puzzle_failed  # Ordem errada: os painéis vão apagar.
signal progress_changed(count: int, total: int)  # Quantos painéis certos já estão ligados.

## Ordem certa, pelo símbolo de cada painel (0 triângulo, 1 quadrado, 2 círculo).
@export var solution: PackedInt32Array = PackedInt32Array([1, 2, 0])
## Tempo com os painéis piscando em vermelho antes de apagarem.
@export_range(0.1, 3.0, 0.1) var reset_delay: float = 0.8

var solved: bool = false  # True depois de resolvido.

var _panels: Array[PuzzlePanel] = []  # Painéis filhos.
var _entered: PackedInt32Array = PackedInt32Array()  # Símbolos ligados até agora, em ordem.
var _resetting: bool = false  # True durante o pisca de erro.


## Junta os painéis filhos e escuta cada [E].
func _ready() -> void:
	for child: Node in get_children():
		var panel := child as PuzzlePanel
		if panel != null:
			_panels.append(panel)
			panel.interacted.connect(_on_panel_interacted.bind(panel))


## Um painel foi acionado.
func _on_panel_interacted(panel: PuzzlePanel) -> void:
	if solved or _resetting or panel.active:
		return
	var step: int = _entered.size()
	panel.set_active(true)
	_entered.append(panel.glyph)
	if step >= solution.size() or panel.glyph != solution[step]:
		_fail()
		return
	progress_changed.emit(_entered.size(), solution.size())
	if _entered.size() == solution.size():
		solved = true  # Resolve uma única vez.
		puzzle_solved.emit()


## Ordem errada: pisca e apaga todos depois de um instante.
func _fail() -> void:
	_resetting = true
	puzzle_failed.emit()
	for panel: PuzzlePanel in _panels:
		panel.flash_error()
	var timer: SceneTreeTimer = CombatUtils.game_timer(self, reset_delay)
	if timer != null:
		timer.timeout.connect(_reset)


## Apaga tudo e libera uma nova tentativa.
func _reset() -> void:
	_entered.clear()
	for panel: PuzzlePanel in _panels:
		panel.set_active(false)
	_resetting = false
	progress_changed.emit(0, solution.size())
