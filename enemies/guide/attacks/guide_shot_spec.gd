class_name GuideShotSpec
extends RefCounted
## Receita de um tiro do Guide. `child` é a receita dos tiros em que ele se divide (null = não divide).

## Raio do tiro (largura = 2 x raio).
var radius: float = 5.0
var speed: float = 220.0
var damage: int = 10
## Vida máxima do tiro em segundos.
var lifetime: float = 3.0
## Segundos até dividir (só vale se houver `child`; a parede também divide).
var split_delay: float = 0.9
## Receita dos tiros filhos (recursiva).
var child: GuideShotSpec = null
