class_name ChaserAttackState
extends ChaserState


@export var hit_window: float = 0.15

var _player_left_attack_range: bool = false
var _player_left_detection_area: bool = false


func enter() -> void:
	actor.velocity = Vector2.ZERO
	_player_left_attack_range = false
	_player_left_detection_area = false
	_run_attack_sequence()


func exit() -> void:
	if is_instance_valid(actor):
		actor.hitbox.deactivate()


func physics_update(_delta: float) -> void:
	actor.velocity = Vector2.ZERO
	actor.move_and_slide()


func on_player_left_attack_range(_player: Node2D) -> void:
	_player_left_attack_range = true

func on_player_lost(_player: Node2D) -> void:
	_player_left_detection_area = true


func _is_still_active() -> bool:
	return is_instance_valid(actor) and actor.state_machine.current_state == self


func _run_attack_sequence() -> void:
	if is_instance_valid(actor.player_ref):
		actor.face_direction(actor.player_ref.global_position - actor.global_position)

	actor.attack_windup_timer.start()
	await actor.attack_windup_timer.timeout
	if not _is_still_active():
		return

	actor.hitbox.activate()
	await actor.get_tree().create_timer(hit_window).timeout
	if not _is_still_active():
		return
	actor.hitbox.deactivate()

	actor.attack_cooldown_timer.start()
	await actor.attack_cooldown_timer.timeout
	if not _is_still_active():
		return

	_decide_next_state()


func _decide_next_state() -> void:
	if _player_left_detection_area:
		transitioned.emit(self, "EnergyWaveState")
	elif _player_left_attack_range or not is_instance_valid(actor.player_ref):
		transitioned.emit(self, "ChaseState")
	else:
		# Player ainda ao alcance
		_run_attack_sequence()
