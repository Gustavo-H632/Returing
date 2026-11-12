# Sistema de habilidades (sequência de setas + XP + amuletos)

Tudo fica em `res://abilities/`. Os únicos arquivos fora daqui que foram tocados são
`characters/turing/player.gd`, `characters/turing/Turing.tscn` e `project.godot` (ações novas; Ctrl direito nas mesmas ações).
O Pulso EMP também atordoa (1,5 s) os inimigos, sem editar nenhum inimigo; chefões (`guide`) são imunes.

## Como jogar
- Aperte **Ctrl** (esquerdo ou direito, ação `command_mode`) para abrir o modo comando; não precisa segurar.
  Aperte o Ctrl de novo para cancelar. Sem nenhuma habilidade, o Ctrl só mostra um aviso curto.
- Com o modo aberto, digite a sequência com as **setas** (ações `cmd_up/down/left/right`) e confirme com
  **Enter** (`cmd_confirm`). **Backspace** (`cmd_back`) apaga a última seta. Enter com sequência errada, ou com a
  habilidade em recarga, conta como erro e zera o que foi digitado; o modo continua aberto.
  Acertou: a habilidade dispara e o modo fecha.
- O Alan continua livre com o modo aberto (andar, esquivar, atacar). O movimento é só **W/A/S/D**: as setas
  não movem o personagem, servem apenas para digitar sequências (os menus seguem usando as setas via `ui_*`).
- Cada slot da faixa de cooldown mostra a sequência em miniatura (a "colinha") logo acima do amuleto.
- **Celular:** toque no botão **CMD** (faixa do topo) para abrir/fechar o modo; as 4 setas aparecem ao lado e a
  habilidade dispara ao completar a sequência (não há Enter).
- **Menu "SUA BUILD"** (só leitura): clique (ou toque) num amuleto da faixa de cooldown. Mostra nível, XP,
  as habilidades que você tem, os slots ainda bloqueados e os efeitos ativos. Fecha com clique fora, `Esc`
  (`ui_cancel`) ou o botão "Fechar". Não abre durante quiz, pause, escolha de habilidade ou com o Alan morto.
- Matar inimigos dá XP (20 a 30 cada). Níveis: 100 / 250 / 400 de XP acumulado (nível máximo 3).
- Cada nível abre um menu com 3 cartas sorteadas. As não escolhidas nunca mais aparecem na run.
- As lendárias só podem aparecer no nível 3 e apagam todas as outras habilidades (o menu avisa e pede confirmação).
- Com qualquer menu aberto (pause, escolha, build) o tempo das habilidades (recargas, buffs, Escudo, efeitos
  e pulsos da HUD) fica congelado, porque todos pausam a árvore e as animações da HUD são pausáveis.

## Barra de XP (`res://ui/hud/xp_bar.tscn`)
- Vertical por padrão: fica à direita do bloco vida + carga, com o topo na barra de vida e a base na de carga
  (acompanha o tamanho do bloco sozinha). O emblema do nível fica centrado na borda de cima.
- `orientation = XpBar.BarLayout.HORIZONTAL` dá a versão horizontal (usada no cabeçalho do menu de build).
  Para usar fora da HUD: `auto_bind = false`, `follow_health_block = false` e `set_xp()` / `set_xp_instant()`.

## Estrutura
| Pasta | Conteúdo |
|---|---|
| `core/` | `AbilityData`, `AbilityCatalog`, `StatModifiers`, `AbilityEffect`, `StatBuffEffect`, `AbilityComponent`, `ExperienceComponent`, `RunState`, `UiTween` |
| `data/` | um `.tres` por habilidade + `ability_catalog.tres` (as 12) |
| `effects/` | cenas e scripts dos efeitos |
| `ui/` | `ArrowSequenceView`, `AmuletIcon`, `CooldownSlot` (clicável), HUD de habilidades, menu de level-up, menu de build (`build_menu`) e a barra de XP em `res://ui/hud/xp_bar.tscn` |

## Criar uma habilidade nova em 3 passos
1. Duplique um `.tres` de `data/` (ex.: `tiro_rapido.tres`) e troque `id`, `display_name`, `description`.
2. Defina a `sequence` (3 a 6 setas; `0` cima, `1` baixo, `2` esquerda, `3` direita), `cooldown`, `duration`,
   `rarity`, `glyph` e a `effect_scene`. Para um buff simples use `effects/StatBuffEffect.tscn` e preencha
   `stat_mult` / `stat_add` (atributos: `move_speed`, `dash_distance`, `projectile_speed`, `sword_area`,
   `life_steal`, `max_health`, `heal_received`, `damage`). Para algo novo, crie uma cena cuja raiz herde de `AbilityEffect`.
3. Adicione o `.tres` na lista `abilities` de `data/ability_catalog.tres`. O validador avisa (`push_warning`)
   se a sequência repetir ou for prefixo completo de outra.

## Ajustes rápidos (Inspector)
- `AbilityComponent` (no Player): `command_time_scale` (1.0, padrão, sem câmera lenta; use < 1.0 para ligar).
- `ExperienceComponent` (no Player): `xp_por_nivel`, `xp_min`, `xp_max`.
- `ability_catalog.tres`: `legendary_weight` (raridade das lendárias) e `legendary_min_level`.
- `level_up_menu.tscn`: `input_delay` (entrada ignorada ao abrir) e `fade_time`.
- Cada cena de `effects/`: raio, dano, empurrão, ticks etc.
