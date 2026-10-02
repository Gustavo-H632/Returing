class_name DummyEnemy
extends Node2D
## Inimigo de treino invencível (sem vida): mostra o número de dano e ataca o player
## com projétil, onda e espada. Não entra no grupo enemy.

signal dano_recebido(valor: int)
signal acertou_alvo(atingido: Node, dano: int, tipo: StringName)

const GROUP_DUMMY: StringName = &"dummy_enemy"

@export_group("Dano visual")
## Cena do número de dano
@export var cena_texto_dano: PackedScene = preload("res://ui/damage_text/DamageText.tscn")
## Onde o número nasce
@export var deslocamento_texto: Vector2 = Vector2(0.0, -40.0)

@export_group("Combate")
## Desligado = só emite acertou_alvo
@export var aplicar_dano_direto: bool = true
## Máscara dos ataques (8 = hurtboxes_player)
@export_flags_2d_physics var mascara_alvo: int = 8

@export_group("Projétil")
@export var cena_projetil: PackedScene = preload("res://enemies/dummy_enemy/projetil.tscn")
@export var dano_projetil: int = 1
@export var velocidade_projetil: float = 320.0
@export var intervalo_projetil: float = 0.3

@export_group("Onda")
@export var cena_onda: PackedScene = preload("res://enemies/dummy_enemy/onda_choque.tscn")
@export var dano_onda: int = 2
@export var raio_onda: float = 160.0
@export var duracao_onda: float = 0.8
@export var intervalo_onda: float = 1.0

@export_group("Espada")
@export var cena_espada: PackedScene = preload("res://enemies/dummy_enemy/espada_ataque.tscn")
@export var dano_espada: int = 3
@export var comprimento_espada: float = 48.0
@export var distancia_espada: float = 24.0
@export var duracao_espada: float = 0.25
@export var arco_espada: float = 120.0

## Referências de nós: arraste cada nó no Inspector.
@export_group("Referências (arraste os nós)")
@export var hurtbox: Hurtbox
@export var timer_projetil: Timer  ## Se vazio, é criado por código.
@export var timer_onda: Timer  ## Se vazio, é criado por código.

var alvo: Node2D = null

var _onda_ligada: bool = false
var _onda_atual: DummyOndaChoque = null
var _espada_atual: DummyEspadaAtaque = null


## Entra no grupo dummy_enemy.
func _enter_tree() -> void:
	add_to_group(GROUP_DUMMY)


## Liga a hurtbox e os timers.
func _ready() -> void:
	if hurtbox == null:
		push_warning("DummyEnemy '%s': 'hurtbox' não foi atribuído; o Player não consegue acertá-lo." % name)
	else:
		CombatUtils.connect_once(hurtbox.damage_received, _on_hurtbox_damage_received)

	timer_projetil = _garantir_timer(timer_projetil, &"TimerProjetil", false)
	timer_onda = _garantir_timer(timer_onda, &"TimerOnda", true)
	_configurar_timer(timer_projetil, intervalo_projetil, false, _disparar_projetil)
	_configurar_timer(timer_onda, intervalo_onda, true, _lancar_onda)


# ---------- 1. DANO RECEBIDO (número flutuante) ----------

## API de dano: só mostra o número.
func take_damage(amount: int, _source: Variant = null) -> bool:
	if amount <= 0:
		return false
	receber_dano(amount)
	return true


## Levou dano pela hurtbox.
func _on_hurtbox_damage_received(amount: int, _source: Variant) -> void:
	receber_dano(amount)


## Mostra o número de dano.
func receber_dano(valor: int) -> void:
	if valor <= 0:
		return
	if cena_texto_dano != null:
		# Raiz errada é descartada
		var texto := CombatUtils.instantiate_as(cena_texto_dano, DamageText) as DamageText
		if texto != null:
			add_child(texto)  # posição global; some sozinho
			texto.mostrar(valor, global_position + deslocamento_texto)
	dano_recebido.emit(valor)


# ---------- 2. ATAQUE PROJÉTIL ----------

## Começa a atirar.
func iniciar_ataque_projetil() -> void:
	if timer_projetil.is_stopped():
		_disparar_projetil()
		timer_projetil.start()


## Para de atirar.
func parar_ataque_projetil() -> void:
	timer_projetil.stop()


## true se atirando.
func esta_atacando_projetil() -> bool:
	return not timer_projetil.is_stopped()


## Atira no player.
func _disparar_projetil() -> void:
	var dir := _direcao_para_alvo()
	if dir == Vector2.ZERO:
		return
	var p := _instanciar(cena_projetil, DummyProjetil) as DummyProjetil
	if p == null:
		return
	p.direcao = dir
	p.velocidade = velocidade_projetil
	_configurar_colisao(p)
	p.top_level = true
	p.acertou.connect(_ao_acertar.bind(dano_projetil, &"projetil"))
	add_child(p)
	p.global_position = global_position


# ---------- 3. ATAQUE ONDA (1 por vez, com intervalo) ----------

## Começa as ondas.
func iniciar_ataque_onda() -> void:
	if _onda_ligada:
		return
	_onda_ligada = true
	_lancar_onda()


## Para as ondas.
func parar_ataque_onda() -> void:
	_onda_ligada = false
	timer_onda.stop()


## true se soltando ondas.
func esta_atacando_onda() -> bool:
	return _onda_ligada


## Solta uma onda (uma por vez).
func _lancar_onda() -> void:
	if not _onda_ligada or is_instance_valid(_onda_atual):
		return
	var o := _instanciar(cena_onda, DummyOndaChoque) as DummyOndaChoque
	if o == null:
		return
	o.raio_max = raio_onda
	o.duracao = duracao_onda
	_configurar_colisao(o)
	o.acertou.connect(_ao_acertar.bind(dano_onda, &"onda"))
	o.finalizada.connect(_ao_onda_finalizada)
	_onda_atual = o
	add_child(o)


## Onda acabou: agenda a próxima.
func _ao_onda_finalizada() -> void:
	_onda_atual = null
	if _onda_ligada:
		timer_onda.start()  # intervalo conta depois que a onda some


# ---------- 4. ATAQUE ESPADA ----------

## Golpe de espada na direção do player.
func atacar_espada() -> void:
	if is_instance_valid(_espada_atual):
		return
	var dir := _direcao_para_alvo()
	if dir == Vector2.ZERO:
		return
	var e := _instanciar(cena_espada, DummyEspadaAtaque) as DummyEspadaAtaque
	if e == null:
		return
	e.comprimento = comprimento_espada
	e.duracao = duracao_espada
	e.arco = deg_to_rad(arco_espada)
	e.angulo_central = dir.angle()
	e.position = dir * distancia_espada  # na frente do dummy
	_configurar_colisao(e)
	e.acertou.connect(_ao_acertar.bind(dano_espada, &"espada"))
	_espada_atual = e
	add_child(e)


# ---------- AUXILIARES ----------

## Ataque sem camada própria, só monitora Hurtboxes.
func _configurar_colisao(ataque: Area2D) -> void:
	ataque.collision_layer = 0
	ataque.collision_mask = mascara_alvo


## Instancia o ataque (tipo errado é descartado).
func _instanciar(cena: PackedScene, tipo: Variant) -> Node:
	if cena == null:
		push_warning("DummyEnemy '%s': cena de ataque não atribuída no Inspector." % name)
		return null
	return CombatUtils.instantiate_as(cena, tipo)


## Cria o Timer se faltar.
func _garantir_timer(atual: Timer, nome: StringName, uma_vez: bool) -> Timer:
	if atual != null:
		return atual
	var t := Timer.new()
	t.name = nome
	t.one_shot = uma_vez
	add_child(t)
	return t


## Tempo e callback do Timer.
func _configurar_timer(t: Timer, tempo: float, uma_vez: bool, callback: Callable) -> void:
	t.wait_time = maxf(tempo, 0.01)
	t.one_shot = uma_vez
	t.autostart = false
	CombatUtils.connect_once(t.timeout, callback)


## Direção até o player vivo.
func _direcao_para_alvo() -> Vector2:
	if not CombatUtils.is_targetable(alvo):
		alvo = get_tree().get_first_node_in_group(CombatUtils.GROUP_PLAYER) as Node2D
	if not CombatUtils.is_targetable(alvo):
		return Vector2.ZERO  # sem player vivo
	return global_position.direction_to(alvo.global_position)


## Dano pela API única.
func _ao_acertar(corpo: Node, dano: int, tipo: StringName) -> void:
	if aplicar_dano_direto:
		CombatUtils.apply_damage(corpo, dano, self)
	acertou_alvo.emit(corpo, dano, tipo)
