# Returing
Este é um projeto de jogo para o IFSP - SPO, para todas as disciplinas do núcleo técnico. 

Returing é um jogo topdown de ação e puzzles, onde você joga com Alan Turing em uma Terra devastada por uma IA criada pelo próprio Turing, no ano de 1945.

Projeto feito por: Gustavo Henrique, Alice Bettin, Eduarda Moniz, Icaro Francioni e Ana Beatriz.

## Fases
1. **Fase 1** (`Scenes/Fase1/fase_1.tscn`): 3 ondas de inimigos (WaveManager).
2. **Fase 2** (`Scenes/Fase2/Fase2.tscn`): terminal com quiz.
3. **Fase 3** (`Scenes/Fase3/fase_3.tscn`): chefão **Guide** (`enemies/guide/`), 1000 HP e 2 fases.
   Aos 50% de vida ele fica invulnerável, levanta paredes em volta de si e chama uma wave
   (2 Tank, 3 Drones, 3 Robôs); ao eliminá-la, as paredes somem e começa a fase 2.
