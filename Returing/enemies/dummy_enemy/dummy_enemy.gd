class_name DummyEnemy
extends Node2D
## Inimigo de treino invencível (sem vida).

signal dano_recebido(valor: int)
signal acertou_alvo(atingido: Node, dano: int, tipo: StringName)

const GROUP_DUMMY: StringName = &"dummy_enemy"  # Grupo usado para achar o dummy.

@export_group("Dano visual")
## Cena do número de dano.
@export var cena_texto_dano: PackedScene = preload("res://ui/damage_text/DamageText.tscn")
## Onde o número nasce.
@export var deslocamento_texto: Vector2 = Vector2(0.0, -40.0)

@export_group("Combate")
## Desligado = só emite acertou_alvo.
@export var aplicar_dano_direto: bool = true
## Máscara dos ataques (8 = hurtboxes_player)
@export_flags_2d_physics var mascara_alvo: int = 8

@export_group("Projétil")
# Cena do projétil.
@export var cena_projetil: PackedScene = preload("res://enemies/dummy_enemy/projetil.tscn")
@export var dano_projetil: int = 1
@export var velocidade_projetil: float = 320.0
@export var intervalo_projetil: float = 0.3

@export_group("Onda")
@export var cena_onda: PackedScene = preload("res://enemies/dummy_enemy/onda_choque.tscn")
@export var dano_onda: int = 2  # Dano, raio e tempo da onda.
@export var raio_onda: float = 160.0
@export var duracao_onda: float = 0.8
@export var intervalo_onda: float = 1.0  # Intervalo entre ondas.

@export_group("Espada")
# Cena da espada.
@export var cena_espada: PackedScene = preload("res://enemies/dummy_enemy/espada_ataque.tscn")
@export var dano_espada: int = 3  # Dano, tamanho e tempo da espada.
@export var comprimento_espada: float = 48.0
@export var distancia_espada: float = 24.0
@export var duracao_espada: float = 0.25
@export var arco_espada: float = 120.0

## Referências de nós: arraste cada nó no Inspector.
@export_group("Referências (arraste os nós)")
@export var hurtbox: Hurtbox
@export var timer_projetil: Timer  # Se vazio, é criado por código.
@export var timer_onda: Timer  # Se vazio, é criado por código.

var alvo: Node2D = null  # Alvo atual (o jogador).

var _onda_ligada: bool = false  # True enquanto as ondas estão ligadas.
var _onda_atual: DummyOndaChoque = null  # Onda que existe agora (só uma por vez).
var _espada_atual: DummyEspadaAtaque = null  # Espada que existe agora (só uma por vez).


## Entra no grupo dummy_enemy.
func _enter_tree() -> void:
	add_to_group(GROUP_DUMMY)


## Liga a hurtbox e os timers.
func _ready() -> void:
	# A Hurtbox entrega o dano em take_damage() (ator).
	if hurtbox == null:
		push_warning("DummyEnemy '%s': 'hurtbox' não foi atribuído; o Player não consegue acertá-lo." % name)

	# Garante um timer para o projétil.
	timer_projetil = _garantir_timer(timer_projetil, &"TimerProjetil", false)
	timer_onda = _garantir_timer(timer_onda, &"TimerOnda", true)  # Garante um timer para a onda.
	# Timer do projétil: dispara a cada intervalo.
	_configurar_timer(timer_projetil, intervalo_projetil, false, _disparar_projetil)
	# Timer da onda: lança uma onda por vez.
	_configurar_timer(timer_onda, intervalo_onda, true, _lancar_onda)


# --- 1. DANO RECEBIDO (número flutuante) ---

## API de dano: só mostra o número.
func take_damage(amount: int, _source: Variant = null) -> bool:
	if amount <= 0:  # Dano inválido: recusa.
		return false
	receber_dano(amount)  # Mostra o número flutuante.
	return true


## Mostra o número de dano.
func receber_dano(valor: int) -> void:
	if valor <= 0:  # Dano inválido: ignora.
		return
	if cena_texto_dano != null:  # Só mostra se a cena do número existe.
		# Raiz errada é descartada
		# Cria o número validando o tipo da raiz.
		var texto := CombatUtils.instantiate_as(cena_texto_dano, DamageText) as DamageText
		if texto != null:
			add_child(texto)  # posição global; some sozinho
			texto.mostrar(valor, global_position + deslocamento_texto)  # Posiciona e mostra o valor.
	dano_recebido.emit(valor)  # Avisa quem escuta.


# --- 2. ATAQUE PROJÉTIL ---

## Começa a atirar.
func iniciar_ataque_projetil() -> void:
	if timer_projetil == null:  # Sem timer: nada a fazer.
		return
	if timer_projetil.is_stopped():  # Se está parado, atira já e liga o timer.
		_disparar_projetil()
		timer_projetil.start()


## Para de atirar.
func parar_ataque_projetil() -> void:
	if timer_projetil != null:
		timer_projetil.stop()  # Para o timer.


## True se atirando.
func esta_atacando_projetil() -> bool:
	# Está atirando se o timer está rodando.
	return timer_projetil != null and not timer_projetil.is_stopped()


## Atira no player.
func _disparar_projetil() -> void:
	var dir := _direcao_para_alvo()  # Direção até o jogador.
	if dir == Vector2.ZERO:  # Sem jogador: não atira.
		return
	var p := _instanciar(cena_projetil, DummyProjetil) as DummyProjetil  # Cria o projétil validando o tipo.
	if p == null:
		return
	p.direcao = dir  # Direção do tiro.
	p.velocidade = velocidade_projetil  # Velocidade do tiro.
	_configurar_colisao(p)  # Só enxerga hurtboxes do jogador.
	p.top_level = true  # Posição própria no mundo.
	# Ao acertar, aplica o dano configurado.
	p.acertou.connect(_ao_acertar.bind(dano_projetil, &"projetil"))
	add_child(p)  # Entra na cena.
	p.global_position = global_position  # Nasce no dummy.


# --- 3. ATAQUE ONDA (1 por vez, com intervalo) ---

## Começa as ondas.
func iniciar_ataque_onda() -> void:
	if _onda_ligada:  # Já está ligado: ignora.
		return
	_onda_ligada = true  # Liga o modo onda.
	_lancar_onda()  # Lança a primeira onda agora.


## Para as ondas.
func parar_ataque_onda() -> void:
	_onda_ligada = false  # Desliga o modo onda.
	if timer_onda != null:
		timer_onda.stop()


## True se soltando ondas.
func esta_atacando_onda() -> bool:
	return _onda_ligada


## Solta uma onda (uma por vez).
func _lancar_onda() -> void:
	# Só uma onda por vez e só se o modo está ligado.
	if not _onda_ligada or is_instance_valid(_onda_atual):
		return
	var o := _instanciar(cena_onda, DummyOndaChoque) as DummyOndaChoque  # Cria a onda validando o tipo.
	if o == null:
		return
	o.raio_max = raio_onda  # Raio máximo.
	o.duracao = duracao_onda  # Duração.
	_configurar_colisao(o)  # Configura a colisão.
	o.acertou.connect(_ao_acertar.bind(dano_onda, &"onda"))  # Ao acertar, aplica o dano da onda.
	o.finalizada.connect(_ao_onda_finalizada)  # Quando acabar, agenda a próxima.
	_onda_atual = o  # Guarda a onda atual.
	add_child(o)  # Entra na cena.


## Onda acabou: agenda a próxima.
func _ao_onda_finalizada() -> void:
	_onda_atual = null  # Libera para uma nova onda.
	if _onda_ligada and timer_onda != null:  # Só continua se o modo onda está ligado.
		timer_onda.start()  # intervalo conta depois que a onda some


# --- 4. ATAQUE ESPADA ---

## Golpe de espada na direção do player.
func atacar_espada() -> void:
	if is_instance_valid(_espada_atual):  # Já há uma espada no ar: ignora.
		return
	var dir := _direcao_para_alvo()  # Direção até o jogador.
	if dir == Vector2.ZERO:  # Sem jogador: não ataca.
		return
	# Cria a espada validando o tipo.
	var e := _instanciar(cena_espada, DummyEspadaAtaque) as DummyEspadaAtaque
	if e == null:
		return
	e.comprimento = comprimento_espada  # Comprimento.
	e.duracao = duracao_espada  # Duração.
	e.arco = deg_to_rad(arco_espada)  # Arco do golpe em radianos.
	e.angulo_central = dir.angle()  # Ângulo central do golpe.
	e.position = dir * distancia_espada  # na frente do dummy
	_configurar_colisao(e)  # Configura a colisão.
	e.acertou.connect(_ao_acertar.bind(dano_espada, &"espada"))  # Ao acertar, aplica o dano da espada.
	_espada_atual = e  # Guarda a espada atual.
	add_child(e)  # Entra na cena.


# --- AUXILIARES ---

## Ataque sem camada própria, só monitora Hurtboxes.
func _configurar_colisao(ataque: Area2D) -> void:
	ataque.collision_layer = 0  # O ataque não pertence a nenhuma camada.
	ataque.collision_mask = mascara_alvo  # Só enxerga as hurtboxes do jogador.


## Instancia o ataque (tipo errado é descartado).
func _instanciar(cena: PackedScene, tipo: Variant) -> Node:
	if cena == null:  # Sem cena configurada: avisa.
		push_warning("DummyEnemy '%s': cena de ataque não atribuída no Inspector." % name)
		return null
	return CombatUtils.instantiate_as(cena, tipo)


## Cria o Timer se faltar.
func _garantir_timer(atual: Timer, nome: StringName, uma_vez: bool) -> Timer:
	if atual != null:  # Já existe: devolve.
		return atual
	var t := Timer.new()  # Cria o timer novo.
	t.name = nome  # Dá o nome.
	t.one_shot = uma_vez  # Define se dispara uma vez só.
	add_child(t)  # Entra na cena.
	return t


## Tempo e callback do Timer.
func _configurar_timer(t: Timer, tempo: float, uma_vez: bool, callback: Callable) -> void:
	t.wait_time = maxf(tempo, 0.01)  # Tempo mínimo de 0,01 s.
	t.one_shot = uma_vez  # Uma vez só ou repetido.
	t.autostart = false  # Não inicia sozinho.
	CombatUtils.connect_once(t.timeout, callback)  # Liga o sinal ao callback.


## Direção até o player vivo.
func _direcao_para_alvo() -> Vector2:
	if not CombatUtils.is_targetable(alvo):  # Alvo inválido: procura o jogador de novo.
		alvo = CombatUtils.get_player(self)  # Procura o jogador no grupo.
	if not CombatUtils.is_targetable(alvo):  # Ainda sem alvo.
		return Vector2.ZERO  # sem player vivo
	return global_position.direction_to(alvo.global_position)  # Vetor unitário até o jogador.


## Dano pela API única.
func _ao_acertar(corpo: Node, dano: int, tipo: StringName) -> void:
	if aplicar_dano_direto:  # Aplica o dano pela API única, se configurado.
		CombatUtils.apply_damage(corpo, dano, self)
	acertou_alvo.emit(corpo, dano, tipo)  # Avisa quem acertou, o dano e o tipo de ataque.
