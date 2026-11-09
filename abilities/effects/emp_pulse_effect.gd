class_name EmpPulseEffect
extends AbilityEffect
## Pulso EMP: onda circular ao redor do Player com dano leve, empurrão e atordoamento.
## Os inimigos não têm atordoamento próprio: aqui ele é feito por fora, sem editar nenhum inimigo.
## O inimigo volta ao estado de repouso (cancelando o ataque em curso), a máquina de estados fica
## travada durante o atordoamento e, no fim, ele volta a perseguir se ainda enxerga o Player.

@export_group("Pulso")
@export var radius: float = 140.0  # Raio do pulso.
@export var damage: int = 15  # Dano leve em cada inimigo atingido.
## Distância (px) do empurrão e o tempo (s) que ele leva.
@export var push_distance: float = 90.0
@export_range(0.05, 1.0, 0.01) var push_time: float = 0.18  # Tempo do empurrão (s).
## Duração (s) da animação do anel.
@export_range(0.1, 2.0, 0.05) var ring_time: float = 0.45
@export_flags_2d_physics var wall_mask: int = 1  # Camadas tratadas como parede ao empurrar.
@export var ring_color: Color = Color(0.45, 0.85, 1.0, 1.0)  # Cor do anel.

@export_group("Atordoamento")
## Tempo (s) que os inimigos atingidos ficam parados (0 desliga).
@export_range(0.0, 10.0, 0.1) var stun_time: float = 1.5
## Inimigos que não podem ser atordoados (chefões têm fases próprias).
@export var stun_exclude_kinds: Array[StringName] = [&"guide"]
@export var stun_tint: Color = Color(0.6, 0.85, 1.4, 1.0)  # Cor dos inimigos atordoados.

## Cada item: { "enemy": Node2D, "dir": Vector2, "left": float }.
var _pushes: Array[Dictionary] = []
## Cada item: { "enemy": EnemyBase, "left": float }.
var _stuns: Array[Dictionary] = []
var _age: float = 0.0  # Tempo de vida do efeito.


## Dispara o pulso: dá dano, empurra e atordoa cada inimigo dentro do raio.
func _on_activate() -> void:
	top_level = true  # o anel fica parado no mundo, sem herdar a escala do Player
	global_position = caster.global_position  # Nasce onde o jogador está.
	# Passa por todos os inimigos.
	for node: Node in get_tree().get_nodes_in_group(CombatUtils.GROUP_ENEMY):
		var enemy: Node2D = node as Node2D  # Converte para Node2D.
		if enemy == null or not CombatUtils.is_targetable(enemy):  # Ignora mortos.
			continue
		var offset: Vector2 = enemy.global_position - global_position  # Vetor do jogador até o inimigo.
		if offset.length() > radius:  # Fora do raio: ignora.
			continue
		CombatUtils.apply_damage(enemy, damage, caster)  # Dano leve.
		if CombatUtils.is_dead_actor(enemy):  # Morreu com o dano: não empurra nem atordoa.
			continue
		# Direção do empurrão (para fora do jogador).
		var dir: Vector2 = offset.normalized() if offset.length() > 1.0 else Vector2.RIGHT
		_pushes.append({"enemy": enemy, "dir": dir, "left": push_distance})  # Registra o empurrão.
		_stun(enemy)  # Atordoa.
	queue_redraw()  # Desenha o anel.


## A cada quadro avança empurrões, atordoamentos e a animação; termina quando tudo acabou.
func _physics_process(delta: float) -> void:
	_age += delta  # Soma o tempo.
	_update_pushes(delta)  # Anda os empurrões.
	_update_stuns(delta)  # Conta os atordoamentos.
	queue_redraw()  # Redesenha o anel.
	# O anel terminou e não há mais nada pendente.
	if _age >= ring_time and _pushes.is_empty() and _stuns.is_empty():
		_finish()  # Termina.


## Empurra cada inimigo atingido, parando nas paredes.
func _update_pushes(delta: float) -> void:
	var step_max: float = push_distance / push_time * delta  # Distância máxima por quadro.
	for i: int in range(_pushes.size() - 1, -1, -1):  # De trás para frente, para remover sem pular itens.
		var push: Dictionary = _pushes[i]  # Empurrão atual.
		var left: float = float(push["left"])  # Distância que ainda falta.
		if not is_instance_valid(push["enemy"]) or left <= 0.0:  # Inimigo sumiu ou empurrão acabou.
			_pushes.remove_at(i)  # Remove.
			continue
		var enemy: Node2D = push["enemy"] as Node2D  # Inimigo como Node2D.
		if not CombatUtils.is_alive(enemy):  # Saiu da cena.
			_pushes.remove_at(i)
			continue
		var step: float = minf(step_max, left)  # Passo deste quadro.
		CombatUtils.move_until_wall(enemy, (push["dir"] as Vector2) * step, wall_mask)  # Empurra até a parede.
		push["left"] = left - step  # Desconta o que falta.


# --- Atordoamento ---

## Atordoa o inimigo: manda para o repouso, trava a máquina de estados e pinta de azul. Chefões são imunes.
func _stun(enemy: Node2D) -> void:
	var foe: EnemyBase = enemy as EnemyBase  # Só inimigos comuns têm máquina de estados.
	# Sem tempo, sem máquina ou imune: nada a fazer.
	if stun_time <= 0.0 or foe == null or foe.state_machine == null or stun_exclude_kinds.has(foe.enemy_kind):
		return
	for entry: Dictionary in _stuns:  # Já está atordoado?
		if entry["enemy"] == foe:  # Compara com cada atordoado.
			entry["left"] = stun_time  # já atordoado: renova o tempo
			return
	foe.state_machine.request(StateWarden.State.IDLE)  # sai do ataque (o exit() fecha as hitboxes)
	foe.state_machine.locked = true  # Trava a máquina.
	foe.velocity = Vector2.ZERO  # Para o corpo.
	if foe.sprite != null:  # Tem sprite.
		foe.sprite.modulate = stun_tint  # Pinta de azul.
	CombatUtils.connect_once(foe.died, _on_stunned_died)  # Se morrer atordoado, destrava a máquina.
	_stuns.append({"enemy": foe, "left": stun_time})  # Guarda o atordoamento.


## Desconta o tempo de cada atordoamento e solta quem terminou.
func _update_stuns(delta: float) -> void:
	for i: int in range(_stuns.size() - 1, -1, -1):  # De trás para frente, para remover sem pular itens.
		var entry: Dictionary = _stuns[i]  # Atordoamento atual.
		entry["left"] = float(entry["left"]) - delta  # Desconta o tempo.
		if not is_instance_valid(entry["enemy"]):  # Inimigo sumiu.
			_stuns.remove_at(i)  # Remove.
			continue
		var foe: EnemyBase = entry["enemy"] as EnemyBase  # Inimigo como EnemyBase.
		if not CombatUtils.is_alive(foe):  # Saiu da cena.
			_stuns.remove_at(i)  # Remove.
		elif float(entry["left"]) <= 0.0:  # Acabou o tempo.
			_release(foe)  # Devolve o controle ao inimigo.
			_stuns.remove_at(i)  # Remove.


## Morreu atordoado: destrava a máquina antes de ela receber `die()` (que `EnemyBase` chama logo depois).
func _on_stunned_died(enemy: EnemyBase) -> void:
	if enemy.state_machine != null:  # Destrava.
		enemy.state_machine.locked = false
	if enemy.sprite != null:  # Tira a cor azul.
		enemy.sprite.modulate = Color.WHITE
	for i: int in range(_stuns.size() - 1, -1, -1):  # Remove da lista de atordoados.
		if _stuns[i]["enemy"] == enemy:  # Mesmo inimigo.
			_stuns.remove_at(i)  # Remove.


## Devolve o controle ao inimigo.
func _release(foe: EnemyBase) -> void:
	CombatUtils.disconnect_if_connected(foe.died, _on_stunned_died)  # Desliga o aviso de morte.
	if foe.sprite != null:  # Tem sprite.
		foe.sprite.modulate = Color.WHITE  # Tira a cor azul.
	var warden: StateWarden = foe.state_machine  # Máquina de estados.
	if warden == null:  # Sem máquina: nada a fazer.
		return
	warden.locked = false  # Destrava.
	if not foe.is_dead() and foe.has_target():  # Vivo e com alvo: volta a perseguir.
		warden.request(StateWarden.State.CHASE)  # Persegue.


## Cancelar (ou sair da árvore) também solta quem ainda está atordoado.
func _on_cleanup() -> void:
	for entry: Dictionary in _stuns:  # Cada atordoado.
		if not is_instance_valid(entry["enemy"]):  # Inimigo sumiu.
			continue
		var foe: EnemyBase = entry["enemy"] as EnemyBase  # Inimigo como EnemyBase.
		if CombatUtils.is_alive(foe):  # Ainda vivo.
			_release(foe)  # Solta.
	_stuns.clear()  # Esvazia a lista.


## Desenha o anel que cresce e some, com um leve preenchimento.
func _draw() -> void:
	var t: float = clampf(_age / ring_time, 0.0, 1.0)  # Progresso (0 a 1).
	var eased: float = 1.0 - pow(1.0 - t, 3.0)  # Curva de suavização (começa rápido).
	var fade: float = 1.0 - t  # Transparência (some no fim).
	var cor: Color = ring_color  # Cor do contorno.
	cor.a = fade  # Transparência.
	draw_arc(Vector2.ZERO, radius * eased, 0.0, TAU, 64, cor, 3.0)  # Contorno do anel.
	var interno: Color = ring_color  # Cor do preenchimento.
	interno.a = fade * 0.12  # Muito transparente.
	draw_circle(Vector2.ZERO, radius * eased, interno)  # Preenchimento do anel.
