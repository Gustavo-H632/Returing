# Integração — Hierarquia, Inspector e Arquitetura de Conexões (Godot 4.x)

> **Estado (v2.7.1):** as cenas `.tscn` **já vêm configuradas** (referências `@export` atribuídas, camadas/máscaras, hitboxes, autoloads, grupos, UIDs). Este guia serve para **conferir** e para **repetir o padrão** em novas cenas.
> Os scripts avisam no painel *Output* (`push_warning`) quando um slot `@export` ficou vazio, e a auditoria (§8) aponta arquivo e nó.

---

## O que muda no editor nesta versão (v2.7.1)

Tudo abaixo **já está aplicado** nos arquivos do zip. A lista existe para você conferir (ou refazer à mão, se preferir não sobrescrever uma cena sua).

| # | Onde (Inspector / arquivo) | O que conferir | Por quê |
|---|---|---|---|
| 1 | **Apague as pastas `Scenes/Tutorial/` e `levels/door/`** do seu projeto (v2.7.1) | — | O Tutorial foi **removido** do jogo. Extrair o zip por cima **não apaga** arquivos antigos: sem apagar, as cenas do Tutorial continuam no projeto. |
| 1b | `Scenes/Cut1/cutscene1.tscn` › nó raiz `Control` › **Next Scene** | `res://Scenes/Fase1/fase_1.tscn` (padrão do script; nada salvo na cena) | Fluxo do jogo: Menu → Cutscene → Fase 1. |
| 2 | `Scenes/Fase1/fase_1.tscn` › `WaveManager` › grupo **Spawn** › **Min Player Distance** | `200` (padrão; nada salvo na cena) | Inimigos não nascem em cima do Player (B57). `0` desliga. Com o mapa maior, aumente. |
| 3 | `enemies/tank_enemy/scenes/TankEnemy.tscn` › **Stomp Pulse Interval** | continua `1.0` s; agora é a **recarga real** do pisoteio | Antes reentrar no alcance zerava o intervalo (B56). `StompHitbox` › *Damage On Contact* é forçado a `false` pelo estado Attack: não precisa mexer. |
| 4 | `ui/damage_text/DamageText.tscn` (número de dano do Dummy de treino) | Cabeçalho com `uid` (abra e salve no editor se criar outra cena por fora) | Mover/renomear arquivos não quebra mais as referências (B64). |
| 5 | **Apague `.godot/`** antes de abrir | — | O cache guarda UIDs e `class_name` das cenas/scripts do Tutorial que não existem mais (`Door`). |
| 6 | Nenhum sinal novo, nenhum autoload novo, nenhuma camada nova | — | A v2.7 só muda contratos de código (dano aceito, troca de cena deferida). |

**Contrato de dano (v2.7, B55)** — vale para qualquer script novo que receba dano:
```gdscript
func take_damage(amount: int, source: Variant = null) -> bool:
	if _dead or amount <= 0:
		return false        # recusado: a Hitbox NÃO conta acerto, o projétil atravessa
	health.take_damage(amount, source)
	return true             # aceito
```
Subclasse de `Hurtbox`: sobrescreva `_deliver_damage(amount, source) -> bool`. Script antigo com `-> void` continua funcionando (conta como aceito).

**Instanciar e temporizar (v2.7, B59/B60):** use `CombatUtils.instantiate_as(cena, Tipo)` em vez de `cena.instantiate() as Tipo`, e `CombatUtils.game_timer(self, t)` em vez de `get_tree().create_timer(t)` em lógica de jogo. A auditoria reprova os dois padrões antigos.

---

## 0. Instalação (faça nesta ordem)

1. **Feche o Godot** e faça backup do projeto.
2. Extraia o zip **por cima** da pasta do projeto (substituir arquivos).
3. **Apague manualmente** (a extração não remove arquivos antigos):
   - `Scenes/Cut1/Global.gd` e `Scenes/Cut1/Global.gd.uid` (substituído por `autoload/global.gd`);
   - `Scenes/Enemies/` e `Scenes/cutscene1.tscn*.tmp`, se ainda existirem (duplicatas → erro de classe duplicada);
   - **`Scenes/Tutorial/` e `levels/door/`** (v2.7.1: Tutorial removido);
   - `enemies/ui/`, `enemies/exemplo/` e `enemies/LEIAME_dummy_enemy.txt` (movidos para `ui/debug/` e `tests/dummy_arena/`);
   - a pasta oculta `.godot/` (cache; o editor recria). **Obrigatório desde a v2.3** (UIDs novos); na v2.7.1 o Tutorial (`Door`) foi removido.
4. Abra o projeto no **Godot 4.7** (não abre no 4.0/4.1/4.2: usa `TileMapLayer`, arquivos `.uid`, `unique_id` e a classe `Logger`). Em **Project › Project Settings › Globals (Autoload)** confirme, **nesta ordem**: `EventBus` → `Global`.
5. Em **Project › Project Settings › Globals › Groups** confirme: `player`, `enemy`, `hurtbox`, `hitbox`.
6. Confirme **Run › Main Scene** = `Scenes/Start/menu_start.tscn`. Desde a v2.3 o botão "Menu" da HUD volta para **esta** cena (não há mais caminho fixo no `Global`).
7. Mova `Sprites/Sword-asset/` (107 MB, arquivos do Unity) para fora do projeto. **Ele não está neste zip.**
8. Rode os três testes (seção 8) — comece pela **auditoria**, que aponta qualquer slot vazio/camada errada/cena sem UID com arquivo e nó — e depois `Scenes/Start/menu_start.tscn` (F5): Menu → Cutscene (5 telas) → Fase 1.

---

## [HIERARQUIA E INSPECTOR]

### 1. Camadas de física (Project Settings › Layer Names › 2D Physics)

| # | Nome | Valor no Inspector |
|---|---|---|
| 1 | Mundo | 1 |
| 2 | Player | 2 |
| 3 | Inimigo | 4 |
| 4 | hurtboxes_player | 8 |
| 5 | hurtbox_inimigos | 16 |

Regra do projeto: **Hitbox só monitora (mask); Hurtbox só é monitorada (layer)**. Hitbox nunca tem layer própria.

| Nó | Layer | Mask |
|---|---|---|
| Player (CharacterBody2D) | 2 | 1 |
| Player › Hurtbox | 8 (4) | 0 |
| Player › AttackPivot › MeleeHitbox | 0 | 16 (5) |
| PlayerProjectile | 0 | 1 + 5 = 17 |
| Corpo de Chaser / Shooter | 4 (3) | 1 |
| `Hurtbox` do DummyEnemy | 16 (5) | 0 |
| Ataques do Dummy (projétil, onda, espada) | **0** | 8 (4) |
| Corpo do Tank | 4 (3) | 1 + 2 = 3 (a investida para ao bater no Player) |
| Qualquer `*Hurtbox` de inimigo | 16 (5) | 0 |
| Qualquer `*Hitbox` de inimigo (Stomp, Dash, Chaser, Shooter) | **0** | 8 (4) |
| `DetectionArea`, `AttackRange`, `AttackRangeArea`, `MeleeRangeArea` | 0 | 2 (2) |
| `EnemyProjectile` (raiz) | 0 | 1 |
| `EnergyWave` | 0 | 8 (4) |
| Paredes (`Bounds` na Fase 1) | 1 | 0 |

### 1.1. Máquina de estados dos inimigos: `StateWarden` (v2.6)

`TankStateMachine`, `ChaserStateMachine` e `ShooterStateMachine` estendem `StateWarden` (`common/state_machine/state_warden.gd`), que estende `BaseStateMachine`. Nada muda na cena: o nó continua com o mesmo script. O Warden resolve, **por nome de nó** (sem arrastar nada), o vocabulário comum de todo inimigo:

| Canônico | Nomes de nó aceitos |
|---|---|
| `IDLE` | `Idle`, `IdleState` |
| `CHASE` | `Chase`, `ChaseState` |
| `ATTACK` | `Attack`, `AttackState`, `AttackRanged`, `AttackMelee` (e `Special_Attack`/`EnergyWaveState` contam como ATTACK ao traduzir) |
| `DEAD` (opcional) | `Dead`, `DeadState`, `Death`, `DeathState` |

API: `request(StateWarden.State.CHASE)`, `get_canonical()`, `is_canonical(...)`, `die()`, `is_dead()`; sinais `warden_state_changed(prev, cur)` e `warden_died`. **Inimigo novo = nomear os nós de estado dentro da convenção** (falta Idle/Chase/Attack → `push_warning`).

### 2. Como atribuir recursos no Inspector (padrão do projeto)

Em vez de `get_node("../../X")` / `$Caminho`, todo script expõe **slots tipados**. Selecione o nó raiz da cena → Inspector → grupo **"Referências (arraste os nós)"** → arraste o nó da aba *Scene* para o slot.
Para slots do tipo `Node` (ex.: `actor`, `source`), o Godot aceita qualquer nó da cena; use a **raiz do ator**.

### 3. Hierarquia exata por cena e o que atribuir

**`player/Player.tscn`**
```
Player (CharacterBody2D · Player.gd · layer 2 · mask 1)
│   Referências: attack_pivot=AttackPivot · melee_hitbox=AttackPivot/MeleeHitbox
│                projectile_spawn=AttackPivot/ProjectileSpawn · hurtbox=Hurtbox · anim_tree=AnimationTree
│   Ataque Ranged › projectile_scene = player/player_projectile.tscn
├─ Sprite2D
├─ CollisionShape2D            (Capsule)
├─ Hurtbox (Area2D · player_hurtbox.gd · layer 8 · mask 0)   actor = Player
│  └─ CollisionShape2D
├─ AttackPivot (Marker2D)
│  ├─ MeleeHitbox (Area2D · layer 0 · mask 16)   ← posicione à frente (x≈26)
│  │  └─ CollisionShape2D
│  └─ ProjectileSpawn (Marker2D)                 ← x≈30
├─ AnimationPlayer
└─ AnimationTree   (opcional; sem Tree Root o jogo roda sem animação e avisa)
```
AnimationTree (quando for animar): `Anim Player` → `../AnimationPlayer`; `Tree Root` = *AnimationNodeStateMachine* com estados **Idle, Walk, Dash, AttackMelee, AttackRanged** (nomes exatos; cada um pode ser um BlendSpace2D).

**`enemies/tank_enemy/scenes/TankEnemy.tscn`**
```
TankEnemy (CharacterBody2D · tank_enemy.gd · layer 4 · mask 3)
│   state_machine=TankStateMachine · health_component=TankHealthComponent · hurtbox=TankHurtbox
│   detection_area=DetectionArea · detection_shape=DetectionArea/CollisionShape2D
│   attack_range_area=AttackRangeArea · attack_range_shape=AttackRangeArea/CollisionShape2D
│   stomp_hitbox=StompHitbox · stomp_shape=StompHitbox/CollisionShape2D
│   dash_hitbox=DashHitbox · sprite=VisualSprite
├─ VisualSprite (Sprite2D) · CollisionShape2D
├─ DetectionArea (layer 0 · mask 2) › CollisionShape2D
├─ AttackRangeArea (layer 0 · mask 2) › CollisionShape2D
├─ TankHurtbox (layer 16 · mask 0)   actor=TankEnemy · health_component=TankHealthComponent
├─ StompHitbox (layer 0 · mask 8 · tank hitbox.gd)   source=TankEnemy
├─ DashHitbox  (layer 0 · mask 8 · tank hitbox.gd)   source=TankEnemy
├─ TankHealthComponent (Node)
└─ TankStateMachine (Node)   actor=TankEnemy · initial_state=Idle
   ├─ Idle · Chase · Attack · Special_Attack        (nomes exatos)
```
Os raios vêm dos `@export` do Tank (`detection_radius`, `attack_range_radius`), não das formas.
**Pisoteio (v2.7):** o `TankEnemy` conecta `StompHitbox.hit_landed` → `start_stomp_cooldown()` por código. A recarga (`stomp_pulse_interval`) só reinicia com acerto aceito; o estado `Attack` pulsa a hitbox quando `can_stomp()`.

**`enemies/chaser_enemy/ChaserEnemy.tscn`** (nova)
```
ChaserEnemy (CharacterBody2D · enemy.gd · layer 4 · mask 1)
│   energy_wave_scene = EnergyWave.tscn
│   state_machine=ChaserStateMachine · health=HealthComponent · hurtbox=ChaserHurtbox · hitbox=ChaserHitbox
│   detection_area=DetectionArea · detection_shape=DetectionArea/CollisionShape2D · attack_range=AttackRange
│   sprite=AnimatedSprite2D
├─ AnimatedSprite2D · CollisionShape2D
├─ DetectionArea (0 / 2) › CollisionShape2D (raio 150 = raio da onda)
├─ AttackRange   (0 / 2) › CollisionShape2D
├─ ChaserHurtbox (16 / 0 · hurtbox.gd)   actor=ChaserEnemy
├─ ChaserHitbox  (0 / 8 · hitbox.gd)     source=ChaserEnemy
├─ HealthComponent (Node)
└─ ChaserStateMachine   actor=ChaserEnemy · initial_state=IdleState
   └─ IdleState · ChaseState · AttackState · EnergyWaveState
```
**`enemies/chaser_enemy/EnergyWave.tscn`:** `EnergyWave (Area2D · 0 / 8) › CollisionShape2D` · slot `collision_shape` = o CollisionShape2D.

**`enemies/ranged_shooter/enemy/RangedEnemy.tscn`** (nova)
```
RangedEnemy (CharacterBody2D · ranged_enemy.gd · layer 4 · mask 1)
│   projectile_scene=EnemyProjectile.tscn · melee_telegraph_scene=MeleeTelegraph.tscn · electric_trap_scene=ElectricTrap.tscn
│   state_machine=ShooterStateMachine · health=ShooterHealthComponent · hurtbox=ShooterHurtbox
│   detection_area=DetectionArea · melee_range_area=MeleeRangeArea
│   projectile_spawn_point=ProjectileSpawnPoint · body_collision=CollisionShape2D · animation_player=AnimationPlayer
├─ Sprite2D · CollisionShape2D
├─ DetectionArea (0 / 2) · MeleeRangeArea (0 / 2)
├─ ShooterHurtbox (16 / 0)   actor=RangedEnemy · health_component=ShooterHealthComponent   (v2.4: explícito)
├─ ShooterHealthComponent · ProjectileSpawnPoint (Marker2D) · AnimationPlayer (opcional; animação "death")
└─ ShooterStateMachine   actor=RangedEnemy · initial_state=Idle
   └─ Idle · Chase · AttackRanged · AttackMelee · Death
```
**Auxiliares do Shooter** (já criadas):

| Cena | Raiz | Slots `@export` na raiz |
|---|---|---|
| `projectile/EnemyProjectile.tscn` | Area2D (0 / 1) · `projectile.gd` | `hitbox` = `ShooterHitbox` (0 / 8) |
| `melee_telegraph/MeleeTelegraph.tscn` | Node2D · `melee_telegraph.gd` | `hitbox` = `ShooterHitbox`, `hitbox_shape` = seu CollisionShape2D |
| `death_trap/ElectricTrap.tscn` | Node2D · `electric_trap.gd` | `hitbox` = `ShooterHitbox`, `hitbox_shape` = seu CollisionShape2D |

**`enemies/dummy_enemy/dummy_enemy.tscn`** (inimigo de treino; não conta para o LevelManager)
```
DummyEnemy (Node2D · dummy_enemy.gd · grupo dummy_enemy)
│   hurtbox=Hurtbox · timer_projetil=TimerProjetil · timer_onda=TimerOnda
├─ TimerProjetil (Timer, 0.3 s) · TimerOnda (Timer, one_shot)
└─ Hurtbox (Area2D · common/components/hurtbox.gd · layer 16 · mask 0)   actor = DummyEnemy
   └─ CollisionShape2D (círculo r=16)
```
Ataques (`projetil`, `onda_choque`, `espada_ataque`): raiz `Area2D` com **layer 0 / mask 8** e o slot `collision_shape` = seu `CollisionShape2D`.
O Dummy só tem `Visual` (ColorRect) na cena de teste; instanciado em outra fase, ele é invisível.

**`ui/damage_text/DamageText.tscn`** (v2.5, número de dano flutuante)
```
DamageText (Label · damage_text.gd · top_level ligado · z_index 100 · mouse_filter Ignore)
```
Aparência e animação nos `@export` da raiz (`fonte`, `tamanho_fonte`, `cor`, `subida`, `duracao`...). `fonte` é opcional. Quem usa: `DummyEnemy.cena_texto_dano` → `add_child(texto)` → `texto.mostrar(valor, posicao_global)`; o rótulo se libera sozinho.


**`ui/debug/painel_dummy.tscn`:** `PainelDummy (HBoxContainer)`; slots `btn_dano`, `spin_dano`, `btn_projetil`, `btn_onda`, `btn_espada` já atribuídos. O slot `dummy` é preenchido **na cena que instancia o painel** (v2.4: na arena, `dummy = ../../DummyEnemy` na instância `UI/PainelDummy`). Vazio = fallback pelo grupo `dummy_enemy`.

**`tests/dummy_arena/teste_dummy.tscn`** (F6): Player real + HUD + Dummy + painel. Golpe (botão esq.) e tiro (botão dir.) mostram o número de dano no Dummy; os botões do painel fazem o Dummy atacar o Player (HP na HUD).

**`ui/hud/hud.tscn`** — `HUD (CanvasLayer · hud.gd)`; todos os slots já apontam para `Root/PlayerBox/...`, `Root/EnemyPanel/...`, `Root/GameOverPanel/...`, `Root/LevelCompletePanel/...`.
`wave_label` (v2.6): `Onda N / M` — oculto até o primeiro `wave_started`, então a arena do Dummy não mostra nada.
`kind_names` (v2.4, Dictionary no Inspector): `tank → Tank`, `chaser → Perseguidor`, `shooter → Atirador`. **Inimigo novo = uma linha aqui**, sem editar `hud.gd` (a chave é o `kind` passado em `EnemyEvents.bind`).

**`Scenes/Fase1/fase_1.tscn`** (v2.6: ondas)
```
Fase_1 (Node2D)
├─ TileMapLayer
├─ Bounds (StaticBody2D · layer 1)  ← 4 paredes invisíveis ao redor do mapa (provisório)
├─ Player   (instância)
├─ LevelManager (Node · level_manager.gd)   next_scene = (vazio = só "menu principal")
├─ SpawnPoints (Node2D) › SpawnA … SpawnH (Marker2D ×8)   ← pontos de nascimento dos inimigos
├─ WaveManager (Node · levels/wave_manager.gd)
│     spawn_points_root = SpawnPoints
│     wave_1_enemies = Chaser ×2 + RangedEnemy ×2
│     wave_2_enemies = TankEnemy ×2 + RangedEnemy ×2
│     wave_3_enemies = TankEnemy ×2 + RangedEnemy ×2 + Chaser ×3   (7 inimigos)
│     first_wave_delay 1 s · between_waves_delay 2 s · clear_heal_amount 30 · spawn_jitter 16 px
│     min_player_distance 200 px (v2.7: marcador perto do Player só é usado se não houver outro)
└─ HUD (instância de ui/hud/hud.tscn)
```
**Não há mais inimigos colocados à mão na fase**: eles nascem pelo `WaveManager` na raiz da cena (`CombatUtils.spawn`). Os arrays aceitam qualquer `PackedScene` de inimigo (arraste do FileSystem; repita a cena para repetir o inimigo). Com mais inimigos que marcadores, os pontos se repetem. Para outra fase com ondas: instancie `SpawnPoints` + `WaveManager` e atribua os 4 slots; o `LevelManager` entra no modo ondas sozinho.
Ordem dos filhos importa pouco: os sinais são conectados em `_enter_tree`. **Para colisão real nos tiles:** TileSet › *Physics Layers* › Add → `collision layer = 1`; desenhe o polígono nos tiles de parede (aba *Paint*).

**`Scenes/Cut1/cutscene1.tscn`:** raiz `Control` com `cutscene_controller.gd` (`next_scene` = `fase_1.tscn`). Filhos: `TextureRect` (`Back_cut1.gd`, slot `images`), `RichTextLabel` (`text.scene.gd`, slot `texts`), `Button` (`button_cut1.gd`). **Nenhuma conexão de sinal no painel Node** — tudo via EventBus.

**`Scenes/Start/menu_start.tscn`:** sem conexões no painel. `Start_button.target_scene` define o destino; `reenable_delay` (1 s) reativa o botão se a troca falhar.
Esta cena é a **Main Scene** do projeto e, por isso, o destino de todo `main_menu_requested`.

### 4. Passo a passo: inimigo novo dentro do padrão (exemplo `Bomber`)

1. **Cena:** `CharacterBody2D` raiz `Bomber` → *Attach Script* `bomber.gd` (`class_name Bomber`). Layer **3 (Inimigo)**, mask **1 (Mundo)**.
2. **Filhos:** `CollisionShape2D`; `DetectionArea` (Area2D, layer 0 / mask 2) com forma; `BomberHurtbox` (script `common/components/hurtbox.gd`, layer **5** / mask 0) com forma; `HealthComponent` (Node, `common/components/health_component.gd`); `BomberHitbox` (script `common/components/hitbox.gd`, layer 0 / mask **4**, `Active On Start` desligado) com forma.
3. **Inspector da Hurtbox:** `Actor` = `Bomber`, `Health Component` = `HealthComponent`. **Da Hitbox:** `Source` = `Bomber`.
4. **Máquina de estados:** Node `StateMachine` com script que estende `StateWarden` (ou o próprio `state_warden.gd`); filhos `Idle`, `Chase`, `Attack` (scripts que estendem `BaseState`) e, opcional, `Dead`. `Actor` = `Bomber`, `Initial State` = `Idle`.
5. **Script do ator:** `@export` tipados para cada nó acima (grupo "Referências (arraste os nós)") e, no `_ready`:
```gdscript
EnemyEvents.bind(self, &"bomber", health)          # grupo enemy + enemy_registered/damaged/died
health.died.connect(_on_died)                       # _on_died: state_machine.die(), hurtbox.set_active(false), queue_free()
EventBus.player_died.connect(_on_player_died)       # esquecer o alvo

# fora do _ready, no corpo do script:
func take_damage(amount: int, source: Variant = null) -> bool:   # contrato v2.7
	return not _dead and health.take_damage(amount, source) > 0
```
6. **HUD:** `ui/hud/hud.tscn` › `Kind Names` › adicionar `bomber → "Bombardeiro"`.
7. **Fase:** arraste `Bomber.tscn` para um dos arrays `Wave N Enemies` do `WaveManager` (Fase 1). O `LevelManager` e a HUD contam sozinhos.
8. **Validar:** rode a auditoria (slots vazios, camadas, UID) e ajuste as contagens esperadas no `flow_test.gd` se mudou uma onda.

---

## [ARQUITETURA DE CONEXÕES]

### Autoloads (Project Settings › Globals)

| Nome | Arquivo | Papel |
|---|---|---|
| `EventBus` | `autoload/event_bus.gd` | **Só declara sinais.** Sem lógica, sem estado. |
| `Global` | `autoload/global.gd` | Único dono da navegação: escuta `scene_change_requested`, `main_menu_requested`, `level_restart_requested`, `quit_requested`. Menu principal = *Run › Main Scene* (`get_main_menu_path()`); nenhum caminho de cena fixo no código. Valida e trava o pedido **na hora**, mas executa a troca **no fim do frame** (v2.7, B63: seguro dentro de `body_entered`). Ignora pedidos repetidos até 2 frames depois da troca. |

### Grupos

| Grupo | Quem entra | Quem consulta |
|---|---|---|
| `player` | `Player` (`_enter_tree`) | Sensores dos inimigos (`CombatUtils.is_player`) |
| `enemy` | Tank, Chaser, Shooter (`_enter_tree`) | `LevelManager` (varredura inicial) |
| `hurtbox` | todo `Hurtbox` | `Hitbox`, projétil e golpe do Player (só acertam hurtboxes) |
| `hitbox` | todo `Hitbox` | — |

### Sinais do EventBus — quem emite → quem recebe

| Sinal | Emite | Recebe |
|---|---|---|
| `player_registered(player)` | Player | (livre p/ câmera/IA futura) |
| `player_hp_changed(hp, hp_max)` | Player | HUD |
| `player_damaged(amount)` | Player | HUD (flash da barra) |
| `player_charge_changed(ratio)` | Player | HUD (barra de carga) |
| `player_dealt_damage(target, amount)` | Player | (livre: combo, pontuação) |
| `player_died` | Player | LevelManager, **WaveManager** (nenhuma onda nova, nenhuma cura), HUD (via game_over), **Tank/Chaser/Shooter** (esquecem o alvo; o Chaser volta ao Idle **sem** soltar a onda — B49) |
| `player_heal_requested(amount)` | WaveManager | Player (`curar()`; com HP cheio não emite nada — v2.7) |
| `wave_started(wave, total_waves, enemy_count)` | WaveManager | LevelManager (liga o modo ondas), HUD (`Onda N / M`) |
| `wave_cleared(wave, total_waves)` | WaveManager | HUD |
| `all_waves_cleared` | WaveManager | LevelManager (encerra a fase), HUD |
| `enemy_registered(enemy, kind, max_hp)` | `EnemyEvents.bind()` | LevelManager |
| `enemy_damaged(enemy, kind, amount, hp, max_hp)` | `EnemyEvents.bind()` | HUD (barra do inimigo atingido) |
| `enemy_died(enemy, kind, pos)` | `EnemyEvents.bind()` | LevelManager, **WaveManager** (conta os vivos da onda), HUD |
| `level_started` | LevelManager | (livre) |
| `enemies_remaining_changed(n)` | LevelManager | HUD |
| `enemies_cleared` | LevelManager | (livre: abrir porta, música) |
| `level_completed(next_scene)` | LevelManager | HUD (painel "Fase concluída") |
| `game_over` | LevelManager | HUD (painel "Game Over") |
| `hud_refresh_requested` | HUD (`_ready`) | Player (reenvia HP/carga) |
| `level_restart_requested` | HUD (Tentar de novo) | Global (`reload_current_scene`) |
| `main_menu_requested` | HUD | Global |
| `scene_change_requested(path)` | Start_button, HUD (Continuar), CutsceneController | Global (troca deferida) |
| `quit_requested` | Quit_button | Global |
| `cutscene_content_registered(n)` | Back_cut1, text.scene | CutsceneController |
| `cutscene_advance_requested` | Button (Avançar) | CutsceneController |
| `cutscene_step_changed(step)` | CutsceneController | Back_cut1, text.scene |
| `cutscene_finished` | CutsceneController | Button (desabilita) |

### Fluxos completos

- **Inimigo → UI → Player:** golpe do Player (`MeleeHitbox.area_entered` → `Hurtbox` do inimigo → `HealthComponent.take_damage`) → `damaged` → `EnemyEvents` → `EventBus.enemy_damaged` → **HUD** mostra a barra. Ataque do inimigo (`Hitbox.area_entered` → `PlayerHurtbox` → `Player.take_damage`) → `hp_changed`/`tomou_dano` → `EventBus.player_hp_changed`/`player_damaged` → **HUD** atualiza e pisca. Nenhum dos três tem referência direta aos outros.
- **Ondas (Fase 1):** `first_wave_delay` → `WaveManager` nasce a onda 1 e emite `wave_started` → último `enemy_died` da onda → `wave_cleared` + `player_heal_requested(30)` → `between_waves_delay` → próxima onda … → última onda limpa → `all_waves_cleared`.
- **Vitória:** sem ondas, o último `enemy_died` → LevelManager emite `enemies_cleared` e, após `complete_delay`, `level_completed` → HUD. **Com ondas**, quem decide é `all_waves_cleared` (limpar uma onda intermediária não vence).
- **Derrota:** `player_died` → LevelManager (após `game_over_delay`) emite `game_over` → HUD → botão → `level_restart_requested` → Global.
- **Dano (Hitbox → Hurtbox):** sempre por `CombatUtils.apply_damage(alvo, dano, origem)`. Assinatura única `take_damage(amount: int, source: Variant = null) -> bool` (v2.7: `false` = recusado). Fluxo de um acerto:
  `Hitbox._try_hit` → `apply_damage(Hurtbox)` → `Hurtbox._deliver_damage` → `HealthComponent.take_damage` (inimigo) **ou** `Player.take_damage` (i-frames/morte → `false`) → só com `true`: `Hurtbox.damage_received`, `Hitbox.hit_landed` (projétil inimigo é consumido aqui), `_already_hit`.

### Conexões por código (não há nenhuma no painel *Node › Signals*)

| Onde | Conexão |
|---|---|
| `_enter_tree` de HUD, LevelManager, CutsceneController, Back_cut1, text.scene, Button | `EventBus.*.connect(...)` (antes de qualquer `_ready`, para não perder o primeiro evento) |
| `Player._ready` | espelha os sinais do Player no EventBus; escuta `hud_refresh_requested` |
| Inimigos `_ready` | `EnemyEvents.bind(self, kind, health)`; `EventBus.player_died.connect(...)` |
| HUD `_ready` | botões `pressed` → `EventBus.*_requested.emit()` |
| Hitbox / Projétil / Onda | `area_entered` / `body_entered` (filhos da própria cena) |
| `TankEnemy._ready` (v2.7) | `stomp_hitbox.hit_landed` → `_on_stomp_hit_landed` (recarga do pisoteio) |
| `WaveManager._start_wave` / `LevelManager._track` (v2.7) | `inimigo.tree_exited` → checagem **deferida**: inimigo removido sem `enemy_died` sai da contagem (onda nunca trava) |

### Checklist de teste

- [ ] `tests/integration/flow_test.tscn` (F6) termina com `0 falhas`.
- [ ] Output sem erros vermelhos ao abrir e ao rodar (avisos de `AnimationTree` são esperados até você montar as animações).
- [ ] Menu → Start → 5 telas → Fase 1, **sem ERROR no Output** (reabrir a cutscene não trava).
- [ ] HUD mostra HP; ao bater num inimigo aparece a barra dele; "Inimigos: N" diminui ao matar.
- [ ] Tank persegue, pisoteia a cada 1 s e investe de longe; a investida para na parede e no Player.
- [ ] Chaser golpeia; se você sai do raio ele solta a onda. Shooter atira, usa o círculo vermelho de perto e deixa armadilha elétrica ao morrer.
- [ ] Dash dá invulnerabilidade **e atravessa os projéteis do Shooter** (v2.7). Morrer → "Game Over" → "Tentar de novo" recarrega a fase (a onda 1 recomeça).
- [ ] Ficar na borda do pisoteio do Tank, entrando e saindo: no máximo 1 dano por segundo.
- [ ] Em pé sobre um marcador de spawn quando a onda 2 começa: ninguém nasce em cima do Player.
- [ ] Fase 1: ~1 s após abrir, nasce a onda 1 (HUD "Onda 1 / 3", "Inimigos: 4"); cada onda limpa cura 30 HP; a onda 3 tem 7 inimigos; só a última limpa mostra "Fase concluída".

---

## 8. Testes automáticos

Há **três** testes. Nenhum deles é a cena principal: não altere *Run › Main Scene*.

| Teste | O que cobre | Editor | Terminal (código de saída 0 = tudo certo) |
|---|---|---|---|
| `tests/audit/architecture_audit.tscn` (v2.4) | **Regras de integração, sem rodar o jogo:** lint (`get_node`, `$`, `%Unico`, `NodePath("../")`, `find_child`, `get_parent` fora dos fallbacks, troca de cena fora do `Global`, `instantiate() as Tipo` e `create_timer(t)` sem pausa — v2.7), todo slot `@export` de nó/cena preenchido em todas as 26 cenas, **UID no cabeçalho e em todo `ext_resource`** (v2.7), `@export_file` existente, regra Hitbox/Hurtbox/sensores/corpos por camada, conexões do painel *Node* válidas, grafo do EventBus (sinal sem emissor ou ouvinte morto reprova) e Project Settings (autoloads, grupos, camadas, inputs, Main Scene). Imprime o grafo emissor → ouvinte. | abra e **F6** (1 s) | `godot --headless --path . res://tests/audit/architecture_audit.tscn` |
| `tests/test_runner.tscn` | **198** checagens de unidade: `HealthComponent`, `CombatUtils`, `BaseStateMachine`, `StateWarden`, `Hitbox`, fases de Tank/Chaser/Shooter, Dummy (número de dano), `LevelManager`, `WaveManager`, e as regressões B55–B62 da v2.7. Quase todo síncrono (os 2 últimos blocos aguardam alguns frames). | abra e **F6** | `godot --headless --path . res://tests/test_runner.tscn` |
| `tests/integration/flow_test.tscn` (v2.3) | **89** checagens **ponta a ponta** com as cenas reais, física real e os autoloads: Menu → Cutscene → Fase 1; golpe e tiro do Player → HUD; inimigo → Player → HUD; dash/i-frames; morte → Game Over → Tentar de novo; vazamento de conexões no EventBus após recarregar; vitória → Menu; reabrir a cutscene; 40 s de entradas aleatórias; arena do Dummy. **Reprova se aparecer qualquer ERROR/SCRIPT ERROR no Output** (via `Logger`, Godot 4.5+). | abra e **F6** (~1–2 min em tempo real) | `godot --headless --fixed-fps 60 --path . res://tests/integration/flow_test.tscn` |

- O resultado aparece no *Output* (`ok:` / `FAIL:`).
- O aviso amarelo `Player: AnimationTree sem AnimationNodeStateMachine...` é esperado até você montar as animações (não reprova o teste).
- Se aparecer "Could not find type ... in the current scope", feche e abra o projeto uma vez (ou rode `godot --headless --import`) para o Godot registrar os `class_name`.
- Ao criar um inimigo novo: copie um bloco `_test_*_phases` do `test_runner.gd`. Se ele entrar numa onda da Fase 1, ajuste as contagens esperadas em `flow_test.gd` (`expected` em `_test_victory_and_back_to_menu`, `_wait_wave_enemies` em `_test_level_boot`) e em `_test_fase_1_waves_setup`.
- O `flow_test.gd` usa `find_child` para localizar nós: isso é permitido **só** em testes (a auditoria não varre `tests/`).
- Slot opcional novo? Acrescente `"Classe.propriedade": "motivo"` em `OPTIONAL_EXPORTS` no topo de `architecture_audit.gd`. Exceção de lint justificada: termine a linha com `# audit-ok: motivo`.
