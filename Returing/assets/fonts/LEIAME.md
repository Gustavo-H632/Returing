# Fontes dos menus

As duas fontes (licença OFL) já estão nesta pasta, baixadas do repositório oficial https://github.com/google/fonts.
O tema (`res://themes/pixel_theme.gd`) carrega a primeira que existir de cada lista. Sem elas o jogo roda com a
fonte padrão do Godot e avisa no console.

| Uso | Família | Arquivo | Página oficial |
|---|---|---|---|
| Títulos | **Pixelify Sans** | `PixelifySans[wght].ttf` (variável; também aceita `PixelifySans-Bold.ttf` ou `-Regular.ttf`) | https://fonts.google.com/specimen/Pixelify+Sans |
| Texto e botões | **VT323** | `VT323-Regular.ttf` | https://fonts.google.com/specimen/VT323 |

As licenças estão em `OFL-PixelifySans.txt` e `OFL-VT323.txt` (devem acompanhar as fontes).

Tamanhos usados (múltiplos de `Palette.FONT_BASE` = 16): 16 (apoio), 32 (texto e botões), 48 (título).
Se a VT323 sair borrada em algum tamanho, teste `FONT_BASE = 20` em `themes/palette.gd`.
