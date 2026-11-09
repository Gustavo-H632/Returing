extends Node
## Player falso dos testes de qa/: só expõe o que o RunRecorder consulta.

var morto: bool = false  # Marca se o jogador falso "morreu".
var hp_maximo: int = 100  # Vida máxima do jogador falso.


## Responde se o jogador falso está morto (o gravador de tempo pergunta isso).
func esta_morto() -> bool:
	return morto  # Devolve o estado.
