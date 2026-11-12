class_name FollowCamera
extends Camera2D
## Câmera que segue o player com zoom (modo celular). Se a fase já tem uma Camera2D no player
## (Fase 1), ela é reaproveitada e só ganha zoom e suavização; nas outras fases uma nova é criada.

## Área de jogo padrão das fases (todas são telas de 1152 x 648).
const DEFAULT_LIMITS: Rect2i = Rect2i(0, 0, 1152, 648)
## Suavização do seguimento (maior = mais colada no player).
const FOLLOW_SPEED: float = 9.0

var _target: Node2D = null  # Quem a câmera segue.


## Liga uma câmera de seguimento ao `player`.
static func attach_to(player: Node2D, zoom_factor: float) -> void:
	var cam: Camera2D = null  # Câmera que já existia no jogador.
	for child: Node in player.get_children():  # Procura uma Camera2D entre os filhos.
		if child is Camera2D:
			cam = child as Camera2D  # Guarda a câmera antiga.
			break
	var limits: Rect2i = DEFAULT_LIMITS  # Sem câmera antiga usa o limite padrão.
	if cam != null:  # Copia os limites da câmera antiga.
		limits = Rect2i(cam.limit_left, cam.limit_top, cam.limit_right - cam.limit_left,
				cam.limit_bottom - cam.limit_top)
		cam.queue_free()  # troca pela FollowCamera, com os mesmos limites da cena
	var follow := FollowCamera.new()  # Cria a nova.
	follow.name = "FollowCamera"
	follow._target = player  # Define o alvo.
	follow.zoom = Vector2.ONE * zoom_factor  # Aplica o zoom do celular.
	follow.set_limits(limits)  # Aplica os limites.
	player.add_child(follow)  # Liga ao jogador.


## Define os limites da câmera a partir de um retângulo.
func set_limits(rect: Rect2i) -> void:
	limit_left = rect.position.x
	limit_top = rect.position.y
	limit_right = rect.end.x
	limit_bottom = rect.end.y


## Configura a câmera ao entrar na cena: solta da escala do jogador, segue pela física e suavizada.
func _ready() -> void:
	# Fora da hierarquia de transformação do player (que no celular é escalado).
	top_level = true  # Fora da transformação do jogador (que é escalada no celular).
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS  # Atualiza junto com a física para não tremer.
	position_smoothing_enabled = true  # Liga a suavização.
	position_smoothing_speed = FOLLOW_SPEED  # Velocidade da suavização.
	limit_smoothed = true  # A suavização também respeita os limites.
	if is_instance_valid(_target):
		global_position = _target.global_position  # Começa já em cima do alvo.
	make_current()  # Esta passa a ser a câmera do jogo.
	reset_smoothing()  # Evita o "deslize" do primeiro quadro.


## Cola a câmera na posição do jogador a cada quadro de física.
func _physics_process(_delta: float) -> void:
	if is_instance_valid(_target):
		global_position = _target.global_position
