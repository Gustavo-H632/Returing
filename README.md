# Returing
Este é um projeto de jogo para o IFSP - SPO, para todas as disciplinas do núcleo técnico. 

Returing é um jogo topdown de ação e puzzles, onde você joga com Alan Turing em uma Terra devastada por uma IA criada pelo próprio Turing, no ano de 1945.

Projeto feito por: Gustavo Henrique, Alice Bettin, Eduarda Moniz, Icaro Francioni e Ana Beatriz.




## Estrutura (refatoração Godot 4.7)

```
res://
├── autoload/            EventBus e Global
├── common/
│   ├── combat/          Hitbox, Hurtbox, HealthComponent, CombatUtils, EnemyEvents
│   └── state_machine/   BaseState, BaseStateMachine, StateWarden
├── characters/turing/   Player (Alan Turing) + projétil carregado
├── weapons/             Weapon (base) e sword/ (Sword.tscn)
├── enemies/
│   ├── base/            EnemyBase, EnemyState, EnemyPatrolState (patrulha) e ObstacleSteering (desvio de paredes)
│   ├── drone/           Perseguidor melee (drone.png)
│   ├── tank/            Tank pesado (tank.png)
│   ├── robo/            Atirador (robo.png) + projétil, telegraph e armadilha
│   └── dummy_enemy/     Alvo de treino
├── ui/                  HUD (vida em sprite no canto inferior esquerdo, fim de jogo), pausa, debug
├── levels/              LevelManager e WaveManager
├── Scenes/              Menu, cutscenes e Fase 1
└── sprites/             drone.png, tank.png, turing.png, turing_attack.png, robo.png, sword_slash.png
```
