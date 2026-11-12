class_name PuzzlePanel
extends LabInteractable
## Painel do puzzle. Cada um tem um símbolo (0 triângulo, 1 quadrado, 2 círculo) e liga com [E].

## Símbolo do painel (quadro da spritesheet: 0 triângulo, 1 quadrado, 2 círculo).
@export_range(0, 2) var glyph: int = 0
@export var tex_off: Texture2D  # Spritesheet do painel desligado.
@export var tex_on: Texture2D  # Spritesheet do painel ligado.
@export var sprite: Sprite2D  # Sprite do painel (3 quadros, um por símbolo).

var active: bool = false  # True enquanto o painel está ligado.


## Mostra o painel desligado com o símbolo certo.
func _ready() -> void:
	super._ready()
	add_to_group(&"lab_painel")
	prompt_text = "[E] Ativar painel"
	_refresh()


## Liga ou desliga o painel.
func set_active(on: bool) -> void:
	active = on
	_refresh()


## Pisca em vermelho (ordem errada).
func flash_error() -> void:
	if sprite == null:
		return
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.8, 0.35, 0.35), 0.08)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)


## Atualiza arte e dica conforme o estado.
func _refresh() -> void:
	if sprite != null:
		sprite.texture = tex_on if active else tex_off
		sprite.frame = glyph
	enabled = not active  # Painel ligado não aceita [E].
	refresh_prompt()
