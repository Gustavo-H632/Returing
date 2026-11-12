# Tema dos menus (identidade "terminal de criptografia, anos 1940")

| Arquivo | Para quê |
|---|---|
| `palette.gd` (`Palette`) | **Única** fonte das cores, tamanhos de fonte e tempos de animação. Não escreva cor à mão em cenas ou scripts. |
| `main_theme.tres` | O tema usado por TODOS os menus. Só aponta para `pixel_theme.gd`. |
| `pixel_theme.gd` (`PixelTheme`) | Monta todos os estilos a partir da `Palette`. Para mudar um estilo, edite aqui (não salve o tema pelo editor). |
| `pixel_box.gd` (`PixelBox`) | StyleBox pixelado: sombra dura, contorno, borda e cantos cortados. |
| `pixel_button.gd` (`PixelButton`) | Botão com hover/foco (sobe 2 px, escala 1,04) e pressionado (afunda 2 px). |
| `scanline_overlay.gd` (`ScanlineOverlay`) | Scanlines sutis (<= 8%) para o fundo. |

## Como criar um menu novo
1. Na raiz do menu, `theme = res://themes/main_theme.tres` (ou `Palette.load_theme()` em código).
2. Botões: nó `Button` com o script `res://themes/pixel_button.gd` (ou `PixelButton.new()`). Ação destrutiva: `Theme Type Variation = DangerButton`.
3. Caixas: `PanelContainer` (ou `PanelRaised`). Fundo de tela: `Panel` com `BackdropPanel`.
4. Textos: `Label` normal; `TitleLabel` (título grande), `PanelTitleLabel` (título de caixa), `HintLabel` (apoio).
5. Fundo escurecido sobre o jogo: `Palette.dim_color()`.

## Regras
- Só `ACCENT` como cor de destaque. `DANGER` só em ações destrutivas.
- Tamanhos de fonte são múltiplos de `Palette.FONT_BASE`; espaçamentos, múltiplos de `Palette.UNIT` (8 px).
- Contraste mínimo do texto: 4,5:1. `godot --headless --path . --script res://qa/palette_audit.gd` confere.
