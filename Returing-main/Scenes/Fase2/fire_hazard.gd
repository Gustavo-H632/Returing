class_name FireHazard
extends Area2D
## Trecho de fogo num corredor estreito. Quem fica dentro leva dano a cada "tick".
## O dash dá invulnerabilidade (Player.esta_invulneravel): atravessando em dash, o dano é recusado.

@export_group("Dano")
## Dano por tick. Andar através custa pelo menos um tick; 3 travessias a pé matam (100 de vida).
@export_range(1, 200) var damage: int = 34
## Segundos entre dois danos seguidos.
@export_range(0.05, 3.0, 0.05) var tick_interval: float = 0.4
## Se o dano foi recusado (jogador invulnerável no dash), tenta de novo depois deste tempo.
## É a folga para o jogador sair do fogo quando o dash termina perto da borda.
@export_range(0.0, 1.0, 0.01) var retry_delay: float = 0.12

@export_group("Animação")
@export_range(1.0, 30.0, 0.5) var animation_fps: float = 8.0  # Quadros por segundo.
@export var sprite: Sprite2D  # Sprite com os 4 quadros do fogo (hframes).

var _inside: Dictionary[Node2D, float] = {}  # Jogador dentro do fogo -> segundos até o próximo dano.
var _time: float = 0.0  # Relógio da animação.


## Liga a detecção do jogador.
func _ready() -> void:
	add_to_group(&"lab_fogo")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## Anima os quadros do fogo.
func _process(delta: float) -> void:
	_time += delta
	if sprite != null and sprite.hframes > 1:
		sprite.frame = int(_time * animation_fps) % sprite.hframes


## Aplica o dano em quem está dentro (a primeira vez é no mesmo quadro em que entrou).
func _physics_process(delta: float) -> void:
	for body: Node2D in _inside.keys():
		if not CombatUtils.is_alive(body) or CombatUtils.is_dead_actor(body):
			_inside.erase(body)
			continue
		var left: float = _inside[body] - delta
		if left > 0.0:
			_inside[body] = left
			continue
		# Em dash o Player recusa o dano (invulnerável): tenta de novo logo depois.
		var hit: bool = CombatUtils.apply_damage(body, damage, self)
		_inside[body] = tick_interval if hit else retry_delay


## O jogador entrou no fogo.
func _on_body_entered(body: Node2D) -> void:
	if CombatUtils.is_player(body):
		_inside[body] = 0.0


## O jogador saiu do fogo.
func _on_body_exited(body: Node2D) -> void:
	_inside.erase(body)
