# Pontuação, relógio e tela final

A pontuação é **oculta**: durante a fase o jogo só guarda números brutos (`RunStats`). Os pontos são
calculados uma única vez, no fim da última fase (`ScoreCalculator`), e mostrados em `ui/result/`.

## Fluxo

```
Player (player.gd, +1 linha) -> RunRecorder  -- escuta o EventBus -->  RunStats (números brutos)
EventBus.level_completed("")  (última fase)  ->  RunStats.finalizar()
                                              ->  ScoreCalculator.calcular(RunStats.capturar(), ScoreConfig)
                                              ->  HighScoreStore.registrar(...)
                                              ->  ResultScreen.abrir(...)   (após `atraso_tela_final_s`)
```

- `RunStats.reset()` roda dentro de `RunState.reset()` (início de uma run nova), nunca na troca de fase.
- O relógio só corre com a árvore despausada, o Player vivo e a fase em curso. Pause, menus de escolha/build
  e quiz pausam a árvore; cutscene e tutorial são cenas sem Player; a transição entre fases e o game over não contam.
- Dados: abates = `enemy_died`, dano causado = `enemy_damaged` (já efetivo), dano tomado = `player_damaged`
  (já depois de i-frames e escudo), acertos do quiz = `QuizScreen.resposta_registrada`.

## Ajustar o balanceamento

Tudo está em `scoring/score_config.tres` (abra no Inspector; grupos Tempo, Abates, Variedade, Combo, Dano causado,
Dano tomado, Quiz, Fluxo e Rank). Os tempos da animação da tela final são `@export` do `result_screen.tscn`
(grupo "Animação (s)"). Para um tipo novo de inimigo, acrescente a vida dele em `vida_max_por_tipo` (o peso sai da faixa);
para fixar o peso de um tipo, use `peso_por_tipo`.

## Adicionar um componente de pontuação (3 passos)

1. **Dado bruto:** um campo em `RunStats` (e em `RunSnapshot` + `RunStats.capturar()`), alimentado no `RunRecorder`.
2. **Cálculo:** os números no `ScoreConfig`, a conta em `ScoreCalculator.calcular` (somada ao `bruto`) e uma
   `ScoreResult.Linha` no `ScoreResult`.
3. **Exibição:** uma linha nova em `ResultScreen._montar_corpo` (use `_extra(...)`, que já entra na animação).

Depois, atualize `qa/score_test.gd`.

## Testes (pasta `qa/`)

```
godot --headless --path . --import
godot --headless --path . --script qa/score_test.gd        # cálculo exato, bordas e simulação de ranks
godot --headless --path . --script qa/highscore_test.gd    # recordes locais
godot --headless --path . res://qa/clock_test.tscn          # relógio e ganchos de eventos
godot --headless --path . res://qa/result_test.tscn         # tela final (leva ~25 s: mede tempo real)
godot --headless --path . res://qa/flow_test.tscn           # integração com as fases reais
godot --headless --path . res://qa/regressao_test.tscn     # defeitos corrigidos na auditoria de QA
godot --headless --path . res://qa/audit_load.tscn          # carrega todo script, cena e recurso (conta falhas)
godot --headless --path . res://qa/ctrl_test.tscn           # modo comando (Ctrl) com teclas simuladas
godot --headless --path . res://qa/ctrl_real_test.tscn      # Ctrl em fluxo real: ondas, XP, menu de level-up, Fases 1-3 (~20 s)
godot --path . res://qa/result_shot.tscn -- shot.png 1152 648 media 1.0 0   # captura da tela (precisa de janela)
```

Testes que precisam dos autoloads (`EventBus` etc.) rodam como cena; `--script` não os enxerga.
