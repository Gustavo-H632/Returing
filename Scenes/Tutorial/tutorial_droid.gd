class_name TutorialDroid
extends CharacterBody2D
## Droide preto de treino: fraco, lento e sozinho. Anda devagar até o jogador e NÃO ataca.
## Não registra morte no EventBus (não dá XP): o tutorial controla o que acontece depois.
## Monta o corpo, a hurtbox, a vida e a barra de vida por código.

## O droide levou dano (quantidade e posição do golpe no mundo).
signal hit_taken(amount: int, at: Vector2)
## O droide foi destruído (posição no mundo).
signal destroyed(at: Vector2)
## O droide terminou de entrar e começou a andar.
signal activated

## Fases de vida do droide.
enum Phase { SPAWNING, ACTIVE, DEAD }

const SPRITE: Texture2D = preload("res://sprites/Enemies/Black_bot_sprite.png")
## A folha tem 3 x 3 quadros de 368 px. Linha 0: olho vermelho; linha 2: olho azul (ligando).
const SHEET_FRAMES: int = 3
## Escala para o droide ficar com uns 54 px de altura (quadro original: 368 px).
const SPRITE_SCALE: float = 0.2
## Deslocamento que centra o corpo do droide dentro do quadro (px da textura).
const SPRITE_OFFSET: Vector2 = Vector2(27.0, -50.0)
const FRAMES_ARMED: Array[int] = [0, 1, 2]  # Olho vermelho (ativo).
const FRAMES_BOOT: Array[int] = [6, 7, 8]  # Olho azul (ligando).
const FLASH_COLOR: Color = Color(4.0, 4.0, 4.0, 1.0)  # Branco estourado ao levar dano.

@export_group("Treino")
## Vida do droide (pouca: dois golpes de espada bastam).
@export var max_health: int = 100
## Velocidade de caminhada (lenta de propósito).
@export var move_speed: float = 42.0
## Distância em que ele para de se aproximar do jogador (nunca encosta nem ataca).
@export var stop_distance: float = 96.0
## Vida mínima enquanto `protected` estiver ligado (garante que ele sobreviva a um golpe).
@export var protected_floor: int = 1
## Tempo (s) com o olho azul antes de ficar ativo.
@export var boot_time: float = 0.9

## Enquanto ligado, o droide não morre (usado nas lições que ainda não precisam derrotá-lo).
var protected: bool = true
## Alvo que ele segue (o jogador).
var target: Node2D = null
## Fase atual.
var phase: Phase = Phase.SPAWNING

var health: HealthComponent = null  # Vida do droide.
var hurtbox: Hurtbox = null  # Área que recebe os golpes do jogador.
var sprite: Sprite2D = null  # Visual do droide.
var health_bar: EnemyHealthBar = null  # Barra de vida pequena acima da cabeça.

var _knockback: Vector2 = Vector2.ZERO  # Empurrão recebido (decai sozinho).
var _time: float = 0.0  # Relógio da animação.
var _flash_tween: Tween = null  # Animação do flash branco.


## Monta o droide por código: corpo, hurtbox, vida, sprite e barra de vida.
func _enter_tree() -> void:
	add_to_group(CombatUtils.GROUP_ENEMY)  # Mira assistida do celular e buscas por inimigos.


## Cria os componentes e começa a ligar (aparece com um "pop").
func _ready() -> void:
	collision_layer = 4  # Camada "Inimigo".
	collision_mask = 1  # Só esbarra no mundo (paredes).
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	var body_shape: CollisionShape2D = CollisionShape2D.new()
	var body_circle: CircleShape2D = CircleShape2D.new()
	body_circle.radius = 14.0
	body_shape.shape = body_circle
	body_shape.position = Vector2(0.0, 6.0)
	add_child(body_shape)

	sprite = Sprite2D.new()
	sprite.texture = SPRITE
	sprite.hframes = SHEET_FRAMES
	sprite.vframes = SHEET_FRAMES
	sprite.offset = SPRITE_OFFSET
	sprite.scale = Vector2.ONE * SPRITE_SCALE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.frame = FRAMES_BOOT[0]
	add_child(sprite)

	health = HealthComponent.new()
	health.max_health = max_health
	add_child(health)  # O _ready dele já enche a vida.
	health.died.connect(_on_died)

	hurtbox = Hurtbox.new()
	hurtbox.actor = self
	hurtbox.collision_layer = 16  # "hurtbox_inimigos": onde o tiro e a espada acertam.
	hurtbox.collision_mask = 0
	var hurt_shape: CollisionShape2D = CollisionShape2D.new()
	var hurt_circle: CircleShape2D = CircleShape2D.new()
	hurt_circle.radius = 22.0
	hurt_shape.shape = hurt_circle
	hurt_shape.position = Vector2(0.0, -2.0)
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)

	health_bar = EnemyHealthBar.new()
	health_bar.name = &"HealthBar"
	health_bar.width = 40.0
	health_bar.height = 6.0
	health_bar.always_visible = true  # Pequena e sempre visível, para o jogador acompanhar.
	health_bar.position = Vector2(0.0, -46.0)
	add_child(health_bar)
	health_bar.bind(health)

	# Aparece crescendo (o tutorial toca o som e o clarão).
	sprite.scale = Vector2.ONE * SPRITE_SCALE * 0.1
	var pop: Tween = create_tween()
	pop.tween_property(sprite, ^"scale", Vector2.ONE * SPRITE_SCALE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(boot_time, false).timeout.connect(_activate)


## Anda devagar até o jogador, flutua e toca a animação.
func _physics_process(delta: float) -> void:
	_time += delta
	_knockback = _knockback.move_toward(Vector2.ZERO, 700.0 * delta)
	var walk: Vector2 = Vector2.ZERO
	if phase == Phase.ACTIVE and CombatUtils.is_targetable(target):
		var to_target: Vector2 = target.global_position - global_position
		if to_target.length() > stop_distance:
			walk = to_target.normalized() * move_speed
	velocity = walk + _knockback
	move_and_slide()
	# Flutuação leve e animação do propulsor.
	sprite.position.y = sin(_time * 3.0) * 2.0
	var frames: Array[int] = FRAMES_ARMED if phase != Phase.SPAWNING else FRAMES_BOOT
	sprite.frame = frames[int(_time * 8.0) % frames.size()]


## Diz se o droide morreu (a API de alvo do projeto pergunta isso).
func is_dead() -> bool:
	return phase == Phase.DEAD


## API única de dano do projeto (a Hurtbox entrega aqui). `source` é quem causou o dano.
func take_damage(amount: int, source: Variant = null) -> bool:
	if phase == Phase.DEAD or amount <= 0:
		return false
	var allowed: int = amount
	if protected:  # Nunca passa de `protected_floor` de vida enquanto protegido.
		allowed = mini(amount, maxi(health.current_health - protected_floor, 0))
	if allowed <= 0:
		_flash()  # Ainda mostra que o golpe acertou.
		hit_taken.emit(amount, global_position)
		return true
	var applied: int = health.take_damage(allowed)
	if applied <= 0:
		return false
	var from: Node2D = source as Node2D
	if from != null:  # Empurrãozinho para longe de quem bateu.
		_knockback = (global_position - from.global_position).normalized() * 220.0
	_flash()
	hit_taken.emit(applied, global_position)
	return true


## Fica ativo: troca o olho azul pelo vermelho e começa a andar.
func _activate() -> void:
	if phase != Phase.SPAWNING:
		return
	phase = Phase.ACTIVE
	activated.emit()


## Flash branco no sprite.
func _flash() -> void:
	if sprite == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	sprite.modulate = FLASH_COLOR
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, ^"modulate", Color.WHITE, 0.14)


## A vida chegou a zero: some e avisa (o tutorial faz a explosão).
func _on_died() -> void:
	if phase == Phase.DEAD:
		return
	phase = Phase.DEAD
	hurtbox.set_active(false)
	collision_layer = 0
	if health_bar != null:
		health_bar.dismiss()
	destroyed.emit(global_position)
	hide()
	get_tree().create_timer(0.1, false).timeout.connect(queue_free)
