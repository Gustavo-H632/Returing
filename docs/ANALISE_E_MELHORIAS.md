# Returing — Análise, correções, mobile e novas ideias

> Leitura feita sobre o código (Godot 4.7, ~18 mil linhas de GDScript). Nada aqui foi executado no editor:
> os pontos marcados como **bug provável** foram achados lendo o código e devem ser confirmados jogando.
> As adequações de celular abaixo são **recomendações**; nenhuma foi implementada.

## 1. Pontos positivos

- **Arquitetura limpa.** `EventBus` desacopla HUD, fases e jogador; inimigos usam máquina de estados (`StateWarden`) com
  estados canônicos; dano passa por um ponto único (`CombatUtils.apply_damage`).
- **Sistema de habilidades por dados.** Uma habilidade é um `.tres` (sequência, recarga, duração, efeito). Criar uma nova
  é copiar um arquivo e acrescentar ao catálogo; o validador (`AbilityData.validate`) avisa de sequências repetidas ou
  que sejam o começo de outra.
- **Performance cuidada.** `ObjectPool`/`PoolHub` para tiros, ondas e ataques do chefão; cache de animações; `set_physics_process`
  desligado quando não há o que contar.
- **Mecânica central boa.** Digitar setas com a ação continuando (modo comando em câmera lenta) é uma ideia forte e
  diferente; o "colinha" de setas acima de cada slot ajuda a aprender.
- **Já existe base mobile** (`Platform`, `MobileControls`, mira assistida, área segura, zoom de câmera) e testes em `qa/` e `tests/`.
- **Documentação interna** (LEIAME de habilidades, pontuação e documentação técnica) acima da média para um projeto escolar.

## 2. Pontos negativos e como corrigir

| # | Problema (onde) | Por que importa | Como corrigir |
|---|---|---|---|
| 1 | `AbilityComponent.command_time_scale` vale **0.2** no código, mas `abilities/LEIAME.md` diz que o padrão é **1.0** ("sem câmera lenta"). `qa/ctrl_test.gd` testa 0.2. | A documentação ensina o contrário do que o jogo faz. | Decidir o valor e atualizar o LEIAME (ou o código). |
| 2 | **Bug provável:** durante o modo comando `Engine.time_scale = 0.2`, e as recargas das habilidades e a duração dos buffs são descontadas com o `delta` de física (`ability_component.gd::_physics_process`, `stat_buff_effect.gd`). O `delta` também é reduzido. | Cada segundo de modo comando custa só 0,2 s de recarga: a câmera lenta "congela" os buffs e as recargas, o que muda o equilíbrio sem ninguém ter decidido isso. | Escolher: (a) contar recargas em tempo real (`delta / Engine.time_scale`) ou (b) manter `time_scale = 1.0` e deixar só inimigos/projéteis lentos via um grupo. |
| 3 | `Platform` liga o **modo celular** também em navegador quando `DisplayServer.is_touchscreen_available()` é verdadeiro. | Um notebook com tela de toque (Windows) no navegador passa a rodar com sprites 1,5x, zoom 2x e mira assistida. | Em Web exigir o User-Agent móvel **ou** oferecer um interruptor "Controles de toque" nas configurações. |
| 4 | `TouchCommandPad`: botões de seta com raio 24 px (48 px de diâmetro lógico) **no meio do topo** da tela. | Em um celular de 6" isso dá ~5 mm: pequeno, e longe dos polegares (que ficam nos analógicos). | Ver seção 3. |
| 5 | `XpBar._on_player_registered` chama `_unbind()`, que **desconecta o próprio** `EventBus.player_registered`. | Se o jogador for recriado (reiniciar fase mantendo a HUD), a barra deixa de escutar. | Em `_unbind()` só soltar o componente de XP, não o sinal do EventBus. |
| 6 | Código duplicado: `_block_if_spawned_behind_wall` (jogador e Robô), padrão `_consume()` + `recycle()` (onda, tiro, projétil do Robô, ataques do Guide). | Correção em um lugar não chega nos outros. | Subir para `PooledArea`/`CombatUtils` (ex.: `PooledProjectile` base). |
| 7 | Estado global estático em `RunState` e `RunStats`. | Difícil de testar e de salvar. | Transformar em um `Resource` guardado por um autoload. |
| 8 | Arena do chefão e limites de câmera com **1152 x 648 fixos** (`GuideEnemy.arena_rect`, `FollowCamera.DEFAULT_LIMITS`). | Qualquer fase com outro tamanho precisa lembrar de mudar os dois. | Ler o tamanho do `TileMap`/`ReferenceRect` da fase. |
| 9 | `MobileControls` tem 750+ linhas misturando entrada, desenho e tutorial. | Difícil de manter. | Separar em `TouchInput`, `TouchHud` (desenho) e `MobileTutorial`. |
| 10 | Sem save de progresso (só recorde); testes de `qa/` rodam à mão. | Regressões passam. | Um `run_tests.sh`/CI que rode `qa/*` e `tests/*` com `godot --headless`. |
| 11 | Áudio em **WAV** (BossMusic 6,1 MB, Fase1_theme 6,6 MB, Concerto 4,1 MB) e um SVG de 870 KB. | Pacote grande para Android/Web. | Converter música para OGG (~10x menor) e o SVG para PNG pixelado no tamanho real. |

## 3. Adequação mobile (sem implementar)

**O que já está bom:** analógicos flutuante (mover) e fixo (mirar), mira assistida, toque rápido mira no inimigo mais
próximo, área segura (notch), botão voltar do Android, câmera com zoom.

**O que melhorar (ordem de impacto):**

1. **Setas do modo comando ao alcance do polegar.** Hoje: CMD + 4 botões pequenos no topo. Alternativas, da mais simples à melhor:
   - cruzeta grande (raio ≥ 36 px lógicos) no lado direito, acima do analógico de mira, só visível com o modo aberto;
   - **gestos de deslizar** no lado direito (cima/baixo/esquerda/direita viram as setas): sem botões e rápido;
   - botão CMD mantido, mas posicionado junto ao polegar direito.
2. **Alvos de toque ≥ 48 dp** (~9 mm). Os botões de arma, dash e pausa estão perto disso; o `TouchCommandPad` não.
3. **Feedback tátil:** `Input.vibrate_handheld(20)` em cada seta, 60 ms no erro, 40 ms ao ativar.
4. **Orientação e razão de aspecto:** o projeto usa `expand`; conferir em 20:9 e em iPad (4:3) se HUD e barras não saem da tela.
5. **Tamanho do texto:** fontes pixeladas de 12–16 px ficam pequenas; dica do modo comando e rodapé devem crescer no celular.
6. **Desempenho:** renderer `gl_compatibility` já é a escolha certa; evitar muitos `_draw()` por quadro (o `MobileControls` redesenha todo quadro).
7. **Opção de "jogar sem ver o modo comando":** botão de silenciar a câmera lenta para quem acha enjoativo.

### Dá para usar o acelerômetro?

**Resposta curta: dá, mas não para andar nem mirar. Funciona melhor como entrada opcional das setas do modo comando.**

| Uso | Viável? | Motivo |
|---|---|---|
| Andar inclinando o celular | Não recomendado | O jogo é top-down com dash e esquivas; inclinação é imprecisa, cansa o braço e conflita com o analógico de mira. |
| Mirar inclinando | Não | Precisa de precisão fina; o analógico e a mira assistida já resolvem. |
| **Setas do modo comando por "inclinar/estalar" o aparelho** | **Sim, com ressalvas** | São 4 gestos discretos (cima/baixo/esquerda/direita), combinam com o tema "jogo de setas" e a câmera lenta dá tempo para executar. |
| Dash/golpe "balançando" o celular | Possível | Um gesto simples, mas sensível a falsos positivos ao andar. |

**Como seria (resumo técnico):**

- Godot: `Input.get_gravity()` (inclinação estável, sem a aceleração do movimento) ou `Input.get_gyroscope()` (velocidade
  de giro: melhor para "estalar"); `Input.get_accelerometer()` mistura gravidade e movimento.
- O projeto está em **paisagem** (`orientation=4`, sensor): os eixos do sensor seguem o aparelho, não a tela. É preciso
  trocar/inverter X e Y conforme `DisplayServer.screen_get_orientation()` (paisagem normal x invertida).
- **Zona neutra + histerese:** um gesto só conta quando o eixo passa de ~25° e só pode repetir depois de voltar a ~10°;
  senão uma inclinação gera várias setas.
- **Calibrar** o "ponto zero" quando o modo comando abre (cada pessoa joga com o celular em um ângulo diferente) e aplicar um
  filtro passa-baixa para tirar o tremor.
- **Sempre manter os botões/gestos de toque** como alternativa (acessibilidade, jogar andando de ônibus).
- **Plataformas:** Android e iOS expõem os sensores; no PC não há sensor (testar com teclas simuladas); no navegador (Safari/iOS)
  o acesso exige permissão do usuário e depende da versão do Godot/exportação web — **confira na sua exportação** antes de prometer.
- **Esforço estimado:** um autoload `MotionInput` de ~150 linhas que emite `AbilityComponent.press_arrow(dir)` (o mesmo ponto de
  entrada que os botões de toque já usam). Como `press_arrow` já existe, o resto do jogo não muda.
- **Riscos:** cansaço do pulso, falsos positivos (andar), e o jogador perder a mira se mexer no aparelho com o dedo no analógico.
  Por isso: opcional, desligado por padrão, com sensibilidade ajustável nas configurações.

Esqueleto (referência, não incluído no projeto):

```gdscript
# Converte a inclinação em setas do modo comando (ideia de implementação).
extends Node

const ARM_DEG: float = 25.0     # inclinação para contar como seta
const REARM_DEG: float = 10.0   # volta ao centro para poder repetir

var _armed: bool = true
var _neutral: Vector3 = Vector3.ZERO

func calibrate() -> void:
	_neutral = Input.get_gravity()

func _physics_process(_delta: float) -> void:
	var g: Vector3 = Input.get_gravity() - _neutral
	var tilt: Vector2 = Vector2(g.x, g.y)  # ajustar eixos conforme a orientação da tela
	if _armed and tilt.length() > _threshold(ARM_DEG):
		_armed = false
		var dir: int = _direction_of(tilt)  # AbilityData.Dir.UP/DOWN/LEFT/RIGHT
		# player.abilities.press_arrow(dir)
	elif not _armed and tilt.length() < _threshold(REARM_DEG):
		_armed = true
```

## 4. Novas mecânicas (ideias)

1. **Combo de habilidades:** usar duas habilidades em sequência (ex.: Escudo e depois Pulso EMP) dá um bônus "sincronizado".
2. **Sequências aprendidas na fase:** terminais/itens escondidos ensinam setas novas (misturar puzzle e ação, como a Fase 2).
3. **Risco e recompensa na digitação:** errar a sequência causa um pequeno "curto-circuito" (atordoa o jogador 0,5 s); acertar sem errar
   dá bônus de recarga.
4. **Ritmo:** setas que precisam ser digitadas no tempo de uma batida (música da fase) para dar efeito dobrado.
5. **Fusão de amuletos:** duas habilidades comuns iguais viram uma avançada (substitui a lendária que "apaga tudo").
6. **Fases com regra própria:** apagão (só a luz do jogador), chão elétrico alternado, inimigos que copiam sua última habilidade.
7. **Modo desafio diário** com sementes fixas e ranking local usando o `HighScoreStore` que já existe.
8. **Armadilhas do cenário** ativadas pelo tiro (terminais, torres de energia).
9. **Reviver uma vez por run** gastando XP acumulado (dá tensão sem punir demais).

## 5. Nove novas melhorias (habilidades)

As sequências abaixo foram conferidas contra as 12 atuais: **nenhuma é prefixo de outra** (regra do validador).
Direções: `C` cima, `B` baixo, `E` esquerda, `D` direita.

| # | Nome | Raridade | Sequência | Efeito proposto | Como implementar |
|---|---|---|---|---|---|
| 1 | Reflexos | Comum | C E C | Recarga do dash −40% por 10 s | Novo atributo `dash_cooldown` em `StatModifiers`; `Player._enter_state(DASH)` usa `dash_cooldown * mult`. `StatBuffEffect`. |
| 2 | Carga Rápida | Comum | B C B | Tempo de carga do tiro −30% por 10 s | Atributo `charge_time`; `Player._state_attack_ranged` divide pelo bônus. `StatBuffEffect`. |
| 3 | Pele de Ferro | Comum | D B D | Dano recebido −20% por 10 s | Atributo `damage_taken`; `Player.tomar_dano` multiplica. `StatBuffEffect`. |
| 4 | Pulso Gélido | Avançada | E E C D | Inimigos no raio ficam 50% mais lentos por 4 s | Cópia do `EmpPulseEffect` trocando o atordoamento por `move_speed *= 0.5` e tinta azul. |
| 5 | Mina Binária | Avançada | D B B E | Planta uma mina nos pés; explode ao primeiro inimigo | Nova cena `PooledArea` + `Hitbox.pulse()`; efeito curto com `PoolHub`. |
| 6 | Drone Aliado | Avançada | C C D E | Um drone orbita o jogador por 12 s e atira no inimigo mais próximo | Cena filha do jogador; usa `PlayerProjectile` e o grupo `enemy`. |
| 7 | Tiro em Leque | Avançada | D D B E | Dispara 5 projéteis em arco de 40° | Igual ao `PiercingShotEffect`, lançando 5 vezes com ângulos diferentes. |
| 8 | Máquina Enigma | Lendária | E C E C B B | Inimigos comuns ficam 70% mais lentos por 8 s (chefões 30%) | Efeito global sobre o grupo `enemy`; mesma regra da lendária (apaga as outras). |
| 9 | Overclock | Lendária | C D C D B E | +50% de dano e +30% de velocidade por 10 s, depois −20% por 5 s | `StatBuffEffect` com dois estágios (padrão do `BloodModeEffect`). |

Para cada uma: um `.tres` em `abilities/data/`, a linha no `ability_catalog.tres` e um ícone (seção 6).

## 6. Sprites

O que existe: personagens em pixel art limpa (robôs brancos com olho vermelho/azul), mas **estilos misturados** (o Turing em
`turing_shoot.png` é um boneco "chibi" pequeno; os robôs têm contorno preto grosso e sombreado liso).

Sugestões:

1. **Padronizar a paleta** (16–24 cores) e o contorno: usar `themes/palette.gd` como referência única para HUD *e* sprites.
2. **Recortar margens vazias** das sheets (a do Robô tem uma grande área transparente por quadro) e agrupar em atlas: menos memória.
3. **Animação do Robô:** os 8 primeiros quadros são quase iguais (só o jato muda); ganhar vida com 2 quadros de "respiração" e um de "carregando tiro".
4. **Ícones de habilidade em pixel art 32x32** no campo `icon` do `AbilityData` (hoje são glifos desenhados por código; o campo já aceita textura).
   Um ícone por habilidade existente e uma moldura por raridade (comum cinza, avançada azul, lendária dourada).
5. **Efeitos:** `FireZone`, `ShieldEffect` e `EmpPulseEffect` são desenhados com `draw_*`; trocar por spritesheets de 4–6 quadros deixa o visual mais coeso.
6. **Mobile:** exportar os sprites em múltiplos inteiros (2x/3x) e manter `texture_filter = nearest` para não borrar com o zoom 2x.

## 7. Melhorias nas habilidades atuais

| Habilidade | Ajuste sugerido |
|---|---|
| Passo Ágil / Tiro Rápido / Golpe Amplo / Roubo de Vida (comuns) | Recarga 12–15 s com duração 10 s deixa o buff ligado quase sempre; subir a recarga para 20 s ou reduzir a duração para 6 s. |
| Cura | 3 de 12 unidades da barra a cada 36 s é pouco perto da regeneração (1 HP/s após 10 s); considerar 4 unidades ou recarga 28 s. |
| Escudo | Bom, mas sem sinal sonoro/visual forte ao acabar: o círculo já pisca nos últimos 0,6 s; adicionar som. |
| Pulso EMP | Chefões imunes é bom; mostrar o raio antes (círculo fraco) ajuda a posicionar. |
| Rastro de Fogo | Só funciona no próximo golpe e some em 8 s: mostrar um ícone/halo na espada enquanto armado. |
| Tiro Perfurante | Usa a direção do cursor; no celular a mira assistida pode puxar o tiro para fora da linha — desligar a assistência nele. |
| Lendárias | "Apagar todas as outras" é arriscado; permitir confirmar com prévia do que será perdido (já existe) e oferecer 1 reroll por run. |

## 8. Sobre os comentários

Os **159 scripts `.gd`** do projeto (fora de `addons/`, que é de terceiros) foram recomentados no estilo pedido:

- `##` **acima de cada função** explicando o que ela faz e quando recusa ou falha (1.303 funções; todas têm comentário acima);
- `#` **acima ou no fim das linhas** explicando o que cada passo faz (linhas longas recebem o comentário acima, para não passarem de ~105 colunas).

O código **não foi alterado**: um verificador (comentários removidos, strings preservadas) compara, arquivo por arquivo, o código
antes e depois, e os 159 arquivos deram **0 diferenças**. Como o Godot não estava instalado na máquina onde isso foi feito,
**abra o projeto no editor uma vez** (ou rode `godot --headless --path . res://qa/audit_load.tscn`) para conferir que tudo carrega.
