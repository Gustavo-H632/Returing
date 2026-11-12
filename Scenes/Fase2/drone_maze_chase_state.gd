class_name DroneMazeChaseState
extends DroneChaseState
## Perseguição do drone DENTRO DO LABIRINTO. Com linha de visão livre é a perseguição original (inclusive o
## ataque). Atrás de uma parede, em vez de empurrar contra ela (o desvio por raycast trava em beco de
## labirinto), segue o caminho pelos corredores usando o MazeGraph. Substitui o script do estado "Chase"
## SOMENTE nas instâncias do labirinto; o DroneEnemy.tscn e os scripts originais não foram alterados.

## Camadas tratadas como parede na linha de visão (1 = Mundo).
@export_flags_2d_physics var wall_mask: int = 1
## Folga lateral (px) dos raios de visão: o corpo todo precisa passar, não só o centro.
@export_range(0.0, 40.0, 1.0) var clearance: float = 10.0

var _graph: MazeGraph = null  # Mapa de corredores da fase (null = comportamento original).


## Acha o mapa de corredores da fase.
func _on_enemy_setup() -> void:
	super._on_enemy_setup()
	_graph = get_tree().get_first_node_in_group(MazeGraph.GROUP) as MazeGraph


## Linha de visão livre: persegue e ataca como no resto do jogo. Atrás de parede: segue os corredores.
func physics_update(delta: float) -> void:
	if not drone.has_target():  # Sem alvo: volta a patrulhar.
		request_no_target_state()
		return
	var target_pos: Vector2 = drone.target.global_position
	if _graph == null or _has_clear_line(target_pos):
		super.physics_update(delta)
		return
	# Parede no meio: o ataque corpo a corpo não vale através dela; só anda pelo caminho.
	var step: Vector2 = _graph.next_step(drone.global_position, target_pos)
	drone.navigate_towards(step, drone.move_speed * drone.chase_speed_multiplier, delta)


## Três raios (centro e dois lados) sem parede entre o drone e `target_pos`.
func _has_clear_line(target_pos: Vector2) -> bool:
	var space: PhysicsDirectSpaceState2D = drone.get_world_2d().direct_space_state
	var from: Vector2 = drone.global_position
	var side: Vector2 = from.direction_to(target_pos).orthogonal() * clearance
	var exclude: Array[RID] = [drone.get_rid()]
	for offset: Vector2 in [Vector2.ZERO, side, -side]:
		var query := PhysicsRayQueryParameters2D.create(from + offset, target_pos + offset, wall_mask)
		query.exclude = exclude
		if not space.intersect_ray(query).is_empty():
			return false
	return true
