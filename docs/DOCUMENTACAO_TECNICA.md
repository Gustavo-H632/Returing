# Returing — Roteiro da Apresentação Técnica

> Godot 4.7 · GDScript · Arquitetura orientada a sinais (EventBus) + máquinas de estado.
> Este documento explica **o que mudou, onde e por quê**, na ordem sugerida para apresentar.

---

## 0. Visão geral (1 min)

| Camada | Responsabilidade | Arquivos-chave |
|---|---|---|
| **Autoloads** | Comunicação global e navegação de cenas | `autoload/event_bus.gd`, `autoload/global.gd` |
| **Combate** | Dano, hitbox/hurtbox, vida | `common/combat/*` |
| **Máquina de estados** | IA dos inimigos | `common/state_machine/*`, `enemies/*/states/*` |
| **UI** | HUD, pausa, fim de jogo | `ui/hud/*`, `ui/pause.gd` |
| **Fases** | Ondas, regras da fase, Fase 2 (quiz) | `levels/*`, `Scenes/Fase2/*` |

**Princípio central:** quem emite um evento não conhece quem escuta. A HUD não referencia o Player; o Player não referencia a HUD. Tudo passa pelo `EventBus`.

---

## 1. UI — barra de ataque carregado (3 min)

### O que mudou
- A barra de carga deixou de ser um `ProgressBar` solto no topo e passou a ficar **imediatamente abaixo da barra de vida**, no canto inferior esquerdo.
- Ela usa agora um **sprite azul** (`sprites/HUD/Barra-Carga_sprite.png`), gerado a partir da spritesheet vermelha da vida (mesmo layout 8 × 7, 54 quadros).

### Como funciona
- Nova classe `SpriteBar` (`ui/hud/sprite_bar.gd`) — **uma classe, duas barras**:
  - `PlayerHealthBar` usa a sheet vermelha;
  - `ChargeBar` usa a sheet azul (propriedade exportada `sheet`).
- Quadro 0 = cheio, quadro 53 = vazio. O quadro só muda quando o valor muda (sem redesenho desnecessário).
- Regra de borda: nunca mostra "vazio" com valor > 0, nem "cheio" com valor < máximo.
- A `GameHUD` (`ui/hud/hud.gd`) escuta `player_hp_changed` e `player_charge_changed` e chama `set_health()` / `set_ratio()`.

### Layout (`ui/hud/hud.tscn`)
```
Âncora: canto inferior esquerdo
  PlayerHealthBar  264 × 80   (y -160 → -80)
  ChargeBar        198 × 60   (y  -76 → -16)   <- logo abaixo, sem sobreposição
```

**Ponto para a plateia:** reaproveitar uma classe parametrizada evitou duplicar código de atlas.

---

## 2. Fase 2 — alinhamento e lógica (4 min)

### Problemas encontrados
1. Raiz da cena deslocada em `(1, -1)`.
2. `Terminal` na origem, com sprite e colisão deslocados ~(214, 357) por *offset* dos filhos.
3. Câmera sem limites (mostrava o vazio fora do mapa).
4. Marcadores de spawn sem uso (a fase não tem inimigos).
5. Quiz com posições absolutas (quebrava em outras resoluções).

### Correções
| Item | Solução |
|---|---|
| Raiz | Posição `(0, 0)` |
| Terminal | Nó posicionado em `(214, 357)`; filhos na origem; área de interação ampliada para 96 × 64 |
| Câmera | `limit_left/top = 0`, `limit_right = 1152`, `limit_bottom = 704` (tamanho do mapa) |
| Spawn | `SpawnPoints` removido |
| Quiz | `Label` e `RichTextLabel` com âncoras (centralizados em qualquer resolução) |
| Dica | `Label "[E] Terminal"` só aparece com o player por perto (`terminal.gd`) |

### Lógica (`Scenes/Fase2/fase_2.gd`)
```
Terminal (tecla E) -> abre Quiz (jogo pausado)
Quiz termina       -> despausa -> espera complete_delay
                   -> EventBus.level_completed("")  -> HUD mostra "FIM DE JOGO"
```
O quiz (`levels/Quiz/quiz.gd`) usa a classe `QuizQuestion` (Resource) com perguntas padrão embutidas e editáveis no Inspector.

---

## 3. Inimigos — State Machine com Warden (6 min)

### StateWarden em uma frase
Máquina de estados que traduz qualquer nome de nó (`Idle`, `AttackRanged`, `Dead`…) em **estados canônicos**: `IDLE`, `CHASE`, `ATTACK`, `DEAD`.

### Correção em Shooter (Robo) e Follower (Drone)
- Antes: as cenas **não tinham o estado `Dead`**. Ao morrer, o Warden só *desligava* a máquina — o inimigo ficava "sem estado".
- Agora: ambos têm o nó `StateMachine/Dead` com `EnemyDeadState` (`enemies/base/enemy_dead_state.gd`).
- Resultado: `die()` faz a **transição real para DEAD**, executa o `exit()` do estado anterior (fecha hitboxes) e **trava** a máquina (`locked = true`).

Verificado em teste: `drone.state_machine.get_canonical() == DEAD` e `robo ... == DEAD` após `take_damage(9999)`.

### Follower (Drone) — `enemies/drone/drone_enemy.gd`

**Velocidade:** `move_speed` 125 → **170**.

**Range 2** — nova `Area2D` (`Range2Area`, círculo de **110 px**), entre a *AttackRange* (26 px) e a *DetectionArea* (190 px):

```
Player ENTRA na Range 2 ─┐
                         ├─> _launch_wave(posição do player)
Player SAI da Range 2  ──┘
```

**Onda (`ShockWave`)** — `enemies/drone/wave/shock_wave.gd` + `DroneWave.tscn`
- Instanciada com `CombatUtils.spawn()` no centro do drone, direção ao player.
- `launch(direção, distância = raio da Range 2, dano, atirador)`.
- **Alcance exato:** a cada frame `step = min(speed * delta, restante)`; o último passo é encurtado, então a onda para **exatamente** em 110 px.
- Dano via `Hitbox` (1 acerto por alvo), nunca atinge o próprio drone (`source`).
- Para ao bater em parede; `wave_cooldown` (0,4 s) evita rajada se o player oscilar na borda.
- Sprite: `Laser1_sprite.png` (quadros 3–9 em *loop*, 12 fps).

Teste automatizado: onda nasce em (900, 400), percorre ≈ 110 px, causa 8 de dano.

| Parâmetro (Inspector) | Padrão |
|---|---|
| `wave_scene` | `DroneWave.tscn` |
| `wave_damage` | 8 |
| `wave_cooldown` | 0,4 s |
| raio da Range 2 | forma da `Range2Area` (110) |

---

## 4. Documentação e qualidade de código (2 min)

### Padrão único de comentários
| Tipo | Uso | Exemplo |
|---|---|---|
| `##` | Documenta classe, função, constante, variável exportada | `## Raio atual da Range 2.` |
| `#` | Explica uma decisão no corpo do código | `# Último passo encurtado.` |
| `# --- Título ---` | Divide seções de um arquivo | `# --- Range 2 ---` |

Regras aplicadas em **todos** os `.gd`: espaço após `#`, dois espaços antes de comentário na mesma linha, inicial maiúscula e ponto final em `##`, sem espaços no fim da linha. Erros de digitação e frases quebradas foram reescritos (ex.: `combat_utils.gd`, `base_state_machine.gd`, `state_warden.gd`).

### Outros ganhos já presentes
- Cache de animação do Player (sem montar strings a cada frame).
- `EventBus` com `@warning_ignore_start/restore` (um bloco em vez de dezenas de anotações).
- Navegação de cenas centralizada em `Global` (fade + carregamento em thread).

---

## 5. Validação (1 min)

- Carregamento de **87** scripts/cenas no Godot 4.7.2 (headless): **0 erros**.
- Fluxo simulado: dano → HUD, game over, Fase 1 → Fase 2, quiz, fim de jogo.
- Capturas de tela conferidas: HUD (vida + carga), onda do Drone, Terminal da Fase 2, Quiz.

---

## 6. Arquivos novos e alterados

**Novos**
- `ui/hud/sprite_bar.gd` · `sprites/HUD/Barra-Carga_sprite.png`
- `enemies/base/enemy_dead_state.gd`
- `enemies/drone/wave/shock_wave.gd` · `enemies/drone/wave/DroneWave.tscn`

**Alterados**
- `ui/hud/hud.gd`, `ui/hud/hud.tscn`
- `enemies/drone/drone_enemy.gd`, `DroneEnemy.tscn`, `RoboEnemy.tscn`
- `Scenes/Fase2/Fase2.tscn`, `fase_2.gd`, `terminal.gd`, `levels/Quiz/Quiz.tscn`
- Comentários: todos os `.gd`

**Removido**
- `ui/hud/player_hp_bar.gd` (substituído por `SpriteBar`)

---

## Roteiro de fala (resumo)

1. *"Uma classe, duas barras"* — `SpriteBar`.
2. *"Fase 2 estava desalinhada"* — raiz, terminal, câmera, quiz com âncoras.
3. *"Warden incompleto"* — faltava o estado Dead; agora a morte é uma transição real.
4. *"Range 2"* — evento de entrar/sair gera uma onda que para exatamente no raio.
5. *"Um padrão de comentários"* — `##`, `#`, `# ---`.

---

## 7. Controles de mouse (v4)

| Tema | O que mudou | Arquivos |
|---|---|---|
| Mira | Golpe da espada, tiro carregado e projétil apontam para o cursor. A espada acompanha o cursor durante o golpe (preparação e acerto). | `characters/turing/player.gd`, `weapons/weapon.gd`, `weapons/sword/sword.gd` |
| Projétil | Depois de disparado, curva para a posição atual do cursor e segue reto ao chegar a `arrival_radius` (10 px). | `characters/turing/player_projectile.gd` |
| Dash | Andando: vetor de movimento. Parado: direção do cursor. Cursor sobre o jogador: último vetor de movimento. Export `dash_aim` (`SEMPRE_MOUSE` = sempre ao cursor). | `characters/turing/player.gd` |
| Quiz (Fase 2) | Botão "Confirmar" clicável, clique no painel devolve o foco ao campo, clique durante o feedback pula a espera. | `levels/Quiz/quiz.gd` |
| Terminal (Fase 2) | Clique esquerdo no terminal (com o player por perto) abre o quiz; cursor de mãozinha ao passar por cima. | `Scenes/Fase2/terminal.gd` |

**Ajustes no Inspector (Player):** `dash_aim`, `projectile_follows_cursor`, `aim_deadzone`.
**Ajustes no Inspector (PlayerProjectile):** `follow_cursor`, `turn_rate_deg` (0 = vira na hora), `arrival_radius`.

---

## 8. IA dos inimigos: patrulha, desvio de paredes e perseguição (v5)

Vale para o **Follower (Drone)** e o **Shooter (Robo)**. Tank e Dummy não mudam.

### Fluxo da máquina de estados

```
            player ENTRA no raio de detecção
  Patrol ─────────────────────────────────────► Chase ──► Attack
 (wander) ◄───────────────────────────────────── │          │
            player SAI do raio (ou morre)         │          │
  Patrol ◄────────────────────────────────────────┴──────────┘
                      perdeu o alvo
```

| Tema | O que mudou | Arquivos |
|---|---|---|
| Patrulha | Novo estado `Patrol` (wander): descansa, sorteia um destino em torno da âncora, caminha, repete. Vai para `Chase` ao ganhar alvo. | `enemies/base/enemy_patrol_state.gd`, `DroneEnemy.tscn`, `RoboEnemy.tscn` |
| Desvio de paredes | `ObstacleSteering`: 16 raycasts por varredura (*context steering*), sem NavMesh e sem nós extras. `EnemyBase.navigate_towards()` substitui `move_towards()` na perseguição e na patrulha. | `enemies/base/obstacle_steering.gd`, `enemies/base/enemy_base.gd` |
| Perseguição | `Chase` do Drone e do Robo usam `navigate_towards()`. Sem alvo, qualquer estado volta para `Patrol` (ou `Idle`, se a cena não tiver o nó). | `drone_chase_state.gd`, `robo_chase_state.gd`, `enemy_state.gd` |
| Warden | Novo estado canônico `PATROL` (nomes aceitos: `Patrol`, `PatrolState`, `Wander`). Não é obrigatório. | `common/state_machine/state_warden.gd` |
| Robo | Export `permanent_aggro` (padrão `false`): com `true` o Robo mantém o comportamento antigo e nunca esquece o player. | `enemies/robo/robo_enemy.gd` |

### Como o desvio funciona

1. Lança raios em círculo (alcance = raio do corpo + `avoid_probe_distance`) na camada `obstacle_mask` (padrão: 1, "Mundo").
2. Se a direção do objetivo está livre, segue **reto** (sem desvio, sem custo de curva).
3. Se está bloqueada, pontua cada direção (`interesse no objetivo - perigo`) e escolhe a melhor. O inimigo **se compromete com um lado** da parede até o caminho abrir, o que evita ficar oscilando de um lado para o outro.
4. **Rede de segurança:** se o corpo quase não sai do lugar (ex.: preso em outro inimigo), força uma saída lateral. Na patrulha, o inimigo sorteia outro destino.

Os destinos da patrulha são encurtados no primeiro obstáculo (`trim_to_free_space`), então nunca apontam para dentro de uma parede.

### Ajustes no Inspector

| Onde | Propriedade | Padrão | Efeito |
|---|---|---|---|
| EnemyBase | `avoid_obstacles` | ligado | Desligado = linha reta (comportamento antigo). |
| EnemyBase | `obstacle_mask` | camada 1 | Camadas tratadas como parede. |
| EnemyBase | `avoid_ray_count` / `avoid_probe_distance` | 16 / 56 px | Mais raios = desvio mais fino; mais alcance = contorna mais cedo. |
| EnemyBase | `debug_steering` | desligado | Desenha os raios (verde = livre, vermelho = parede) e o rumo. |
| Patrol | `patrol_radius`, `min_leg_distance` | 140 / 40 px | Tamanho da área e dos trajetos. |
| Patrol | `speed_multiplier` | 0,4 (Drone: 0,35) | Fração da `move_speed` ao patrulhar. |
| Patrol | `rest_time_min` / `rest_time_max` | 0,6 / 1,8 s | Pausa entre trajetos. |
| Patrol | `anchor` | `ENTRY_POINT` | `SPAWN_POINT` faz o inimigo vagar sempre em torno de onde nasceu. |
| Robo | `permanent_aggro` | desligado | Ligado = nunca esquece o player. |

### Limitações conhecidas

- É um desvio **local**: contorna paredes, pilares, cantos e corredores, mas não resolve becos côncavos (um "U" fechado com o player atrás do fundo). Para labirintos, troque por `NavigationAgent2D` + `NavigationRegion2D`.
- A detecção continua sendo o círculo da `DetectionArea` (não exige linha de visão).
- O Robo ainda atira ao entrar no alcance mesmo com uma parede no meio.
- Os valores foram calibrados em simulação 2D fora do Godot: confirme no editor com `debug_steering` ligado.

### Arquivos novos e alterados

**Novos:** `enemies/base/enemy_patrol_state.gd`, `enemies/base/obstacle_steering.gd` (+ `.uid`).

**Alterados:** `enemies/base/enemy_base.gd`, `enemies/base/enemy_state.gd`, `common/state_machine/state_warden.gd`, `enemies/drone/drone_enemy.gd`, `enemies/drone/states/drone_chase_state.gd`, `enemies/drone/states/drone_attack_state.gd`, `enemies/drone/DroneEnemy.tscn`, `enemies/robo/robo_enemy.gd`, `enemies/robo/states/robo_chase_state.gd`, `enemies/robo/states/robo_attack_ranged_state.gd`, `enemies/robo/states/robo_attack_melee_state.gd`, `enemies/robo/RoboEnemy.tscn`.

---

## 9. Unificação v6 (v5 completo + quiz com timer e vida)

**Base:** `Returing-v5-completo` (IA com patrulha e desvio de paredes) + patch `quiz-timer-vida`.

**Integração por cenas e sinais**
- `Quiz.tscn` agora contém `SubmitButton`, `CountdownBox`, `FeedbackTimer` e `QuestionTimer`; `quiz.gd` recebe todos por `@export` (antes criava a UI em código).
- `Fase2.tscn` liga `quiz` e `terminal` por `node_paths` (antes `$CanvasLayer/Quiz`).
- Fluxo do quiz: `QuizScreen.resposta_registrada` / `quiz_terminado` / `quiz_falhou`; erro ou tempo esgotado emite `EventBus.player_damage_requested`; o Player aplica o dano (ignora i-frames) e `player_died` segue para LevelManager e HUD.
- `PlayerProjectile` avisa o dano por `damage_dealt`; o Player repassa a `EventBus.player_dealt_damage`. Removida a chamada dinâmica `shooter.call("causar_dano")` e o método `Player.causar_dano`.
- `WaveManager` obtém o Player por `EventBus.player_registered` (antes buscava no grupo).

**Verificação:** 87 scripts/cenas carregam sem erro; teste do quiz (dano por erro = ⌈vida máx ÷ 3⌉, timeout, morte → `quiz_falhou`, jogo despausado); teste do projétil com sinal.

---

## 10. Fluxo Waves → Quiz, regeneração e Game Over (v7)

- **Cena primária:** `run/main_scene` = Fase 1 (Waves). `Global.MENU_SCENE` fixa o menu (o botão "Menu principal" não depende mais da cena primária).
- **Transição Waves → Quiz:** `LevelManager.auto_advance_delay` (3 s) emite `scene_change_requested(next_scene)`; o botão "Continuar" continua funcionando.
- **Regeneração (`player.gd`):** `regen_delay` = 10 s sem dano, depois `regen_per_second` = 1 HP/s; `tomar_dano` reinicia a contagem.
- **Game Over (`hud.gd` + `hud.tscn`):** painel em tela cheia com o sprite "Fim de Jogo"; "Tentar de novo" aparece após `retry_delay` = 5 s.

---

## 11. Novos sprites pixel art (barras, tiro, dash)

Os sprites vieram de vídeos (64 × 64 px nativos, ampliados 5,75×); foram reconstruídos na grade nativa e com a paleta limpa (sem a compressão do vídeo). Cada pixel do asset = 1 px de mundo, e o `texture_filter` é *nearest*.

| Asset | Uso |
|---|---|
| `sprites/HUD/Barra-Vida_pixel.png` | Tira de 12 quadros de 63 × 16 (cheia → vazia). `SpriteBar` com `frame_count = 12`. |
| `sprites/HUD/Barra-Carga_pixel.png` | Tira de 44 quadros de 63 × 16 (carga). `SpriteBar` com `frame_count = 44`. |
| `sprites/Player/turing_shoot.png` | 4 quadros de 80 × 104 virados à esquerda (o Player espelha). Animação `shoot_side` (1,2 s em *loop* = `charge_time`), tocada em `ATTACK_RANGED`. O quadro é maior que o boneco para o `offset` (20, 28,5) do `Sprite2D` continuar valendo. |
| `sprites/Effects/dash_dust.png` + `characters/turing/DashDust.tscn` | Poeira do dash (4 quadros de 64 × 64, 0,1 s cada), criada em `Player._spawn_dash_dust()`. |
| `sprites/Enemies/Attacks/guide_beam.png` | Orbe (quadro 0, usado pelos tiros divididos do chefão, ver seção 12) + feixe (quadros 1–3, livres para o laser). |

`SpriteBar`: `frame_count > 0` usa a tira horizontal; `0` mantém a grade antiga 8 × 7. O tiro (`shoot_side`) só existe de lado e vale para qualquer direção da mira; o `Player` espelha o sprite pelo lado do cursor.

### Ajustes seguintes
- **Tiro do chefão (`GuideShot`) — substituído na seção 12 (tiro principal agora usa `guide_shot.png`; o orbe ficou só nos divididos):** o círculo desenhado por código foi trocado pelo orbe de `guide_beam.png` (quadro 0), com escala inteira ≈ diâmetro da hitbox. Os quadros 1–3 (feixe) ficam livres para o laser.
- **Barra de vida do chefão:** `health_bar_margin` = 80 em `GuideEnemy.tscn` (antes 24, a barra cobria a cabeça do sprite).
- **Tela de Game Over:** novo `Starfield` (`ui/hud/starfield.gd`) preenche a tela toda com estrelas na paleta do letreiro; o letreiro quadrado continua inteiro no centro (sem barras pretas nas laterais).

---

## 12. Novos sprites (chefão e player) e correção de tiros atravessando parede

| Asset | Uso |
|---|---|
| `sprites/Enemies/Attacks/guide_shot.png` | Projétil do chefão: 8 quadros de 64 × 64 em uma linha. Ponta (cabeça) voltada para cima no quadro. |
| `sprites/Player/turing_shoot.png` | Troca do sprite do player carregando/atirando (4 quadros, 80 × 104, virados à esquerda; o Player espelha). Mesma animação `shoot_side`. |
| `sprites/Enemies/Attacks/guide_beam.png` (quadro 0) | Orbe usado agora só pelos **tiros divididos**. |

**Chefão (`guide_shot.gd`, `GuideShot.tscn`, `guide_shot_spec.gd`)**
- `GuideShotSpec.style`: `BEAM` (tiro principal, animado a `beam_fps` = 12) ou `ORB` (filhos da divisão). `guide_enemy.gd` marca a receita `split` como `ORB`.
- O projétil gira para a direção do voo; o nó (centro da hitbox) fica 1 raio atrás da ponta, então a cabeça encosta no alvo primeiro. Escala inteira (corpo ≈ diâmetro da hitbox).
- Constantes de ajuste: `BEAM_WIDTH_PX`, `BEAM_AXIS_X`, `BEAM_HEAD_TOP_Y`.

**Bug: tiro atravessava a parede interna do labirinto (Fase 1)**
- Causa: a boca da arma nasce ~22,8 px à frente do corpo. Encostado numa parede de 1 tile (16 px), o ponto de nascimento ficava dentro da parede; o raio de `move_until_wall` começa dentro da forma e não a enxerga, então o tiro saía do outro lado.
- Correção: `CombatUtils.trace_spawn()` varre corpo → boca no disparo; se há parede, o tiro morre no ponto de contato. Aplicado em `PlayerProjectile.launch` e `EnemyProjectile.launch`. O projétil do Dummy (debug), que ignorava paredes, agora também para nelas (`DummyProjetil`).
- Verificado no Godot 4.7.2 (headless): antes, 6 de 6 tiros atravessavam; depois, 0 de 6 (e tiros a distância continuam parando na parede).
- **Cone do projétil (quadros 7 e 8 de `guide_shot.png`):** no desenho original o cone rosa era cortado reto na borda do quadro. A ponta final agora se dissolve em *dithering* (a partir da linha 46; os respingos rosa dos quadros 4 e 5, também cortados na borda, recebem o mesmo tratamento a partir da linha 58), então o cone some gradualmente em vez de terminar num corte seco; o contorno vermelho não foi alterado.


---

## 13. Versão celular (Android e iPhone) — v8

Um único projeto roda em PC e celular. O autoload `Platform` (`autoload/platform.gd`) decide o modo:
celular = `OS.has_feature("mobile")` **ou** argumento de usuário `--mobile` (no PC, o mouse simula o dedo).
No PC todos os ajustes de celular ficam desligados (escala 1.0, sem câmera nova, sem mira assistida).

### Ajustes só do celular (todos em `Platform`)

| Ajuste | Valor | Onde |
|---|---|---|
| Tamanho dos sprites | 1.5x (personagens, inimigos, tiros) | `Player._ready`, `EnemyBase._ready`, `PlayerProjectile.apply_charge`, `EnemyProjectile.launch` |
| Câmera | zoom 2x, segue o player, respeita os limites da fase | `characters/turing/follow_camera.gd` |
| Mira assistida | o tiro curva até 85°/s para o inimigo mais alinhado (cone de 30°, até 520 px) | `PlayerProjectile._steer_towards_assist_target` |
| Tiro de toque rápido | carga mínima de 20% | `Player._disparar_projetil` |

### Mudanças de combate (PC e celular)

* Tiro carregado: dano máximo 40 -> **68** (+70%).
* Espada: dano 25 -> **50** (dobro) e hitbox/alcance **+40%** (`Sword.hitbox_scale`). O golpe do chefão Guide continua usando `Sword.HITBOX_RADIUS` puro.
* Barra de mira (`characters/turing/aim_indicator.gd`): retângulo ~80% transparente que sai da boca do cano, com a largura do tiro (cresce com a carga) e o comprimento do alcance (corta na parede). Aparece enquanto o tiro carrega.

### Controles de toque (`autoload/mobile_controls.gd`)

Layout igual ao do APK anterior: analógico esquerdo (mover), analógico direito (mirar/atacar), botões de arma, dash, interagir (E) e pausa.

* **Tiro**: segurar o analógico direito carrega; soltar atira na direção apontada. **Espada**: segurar bate repetidamente.
* A direção de mira **persiste** depois de soltar o dedo (era a causa do tiro errado ao dar só um toque).
* **Toque rápido** (1 quadro): mira no inimigo mais próximo (até 420 px) e, se o player estava ocupado (dash/golpe), o ataque fica pendente por ~0.33 s em vez de se perder.
* O clique de mouse "emulado" do toque é engolido durante o jogo (tocar um botão por cima do terminal não abre mais o quiz).
* Margens de área segura (notch do iPhone) aplicadas aos analógicos, botões e barras da HUD.

### Testes automatizados (`tests/`)

```
godot --headless --path . res://tests/mobile_test.tscn -- --mobile   # toque, tiro em 10 ângulos, assistência, espada, câmera, escala
godot --headless --path . res://tests/pc_test.tscn                   # PC continua igual (+ dano/hitbox novos)
godot --headless --path . res://tests/soak_test.tscn -- --mobile res://Scenes/Fase1/fase_1.tscn 40 god   # toques aleatórios por 40 s
```

### Mira da espada e outras plataformas (v8.1)

* `AimIndicator` agora tem dois modos: barra azul do tiro e **área laranja da espada** (o círculo real da hitbox, `Sword.get_zone_radius/get_zone_distance`), também ~80% transparente. A da espada aparece enquanto o dedo segura o analógico e durante o golpe (também no PC, só durante o golpe).
* Espada no celular: **mira segurando e golpeia ao soltar**, igual ao tiro (`MobileControls.MELEE_ON_RELEASE`).
* Web: `Platform` detecta Android/iPhone/iPad pelo navegador (`JavaScriptBridge`) e liga o modo celular; no navegador o mouse também funciona como dedo (`mouse_as_finger`); o botão "Sair" some em iOS e Web.
* Presets de exportação: Android, iOS, Web (sem threads, PWA), Windows, Linux, macOS.

Veja `MOBILE.md` para gerar cada plataforma.
