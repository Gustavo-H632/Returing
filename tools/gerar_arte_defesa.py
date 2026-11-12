#!/usr/bin/env python3
"""Gera a arte da FASE DE DEFESA em pixel art (PIL): arena, portal animado e barras da HUD.

Uso (na raiz do projeto):   python tools/gerar_arte_defesa.py

Saídas (todas em assets/defesa/, escala 1, sem antialiasing, sem ruído aleatório):
  arena_defesa.png        1152 x 656   arena NOVA (ver arte_defesa_arena.py): nenhum sprite de outra arena é reaproveitado
  portal.png              6 colunas x 2 linhas de 48 x 80 (linha 0 = carregando, linha 1 = pronto)
  barra_fundo.png         moldura dourada das barras (240 x 22)
  barra_hp.png / barra_hp_baixo.png / barra_carga.png / barra_pronto.png   preenchimentos (232 x 14)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from arte_defesa_arena import paint_arena  # noqa: E402
from gerar_arte_fase2 import (  # noqa: E402
    Canvas, mix, OUTLINE, NAVY_PLATE, BLUE_D, BLUE, CYAN, CYAN_L, ORANGE, ORANGE_D, YELLOW, WHITE_HOT, RED,
    RED_D, GREEN_L, GOLD, GOLD_L, GOLD_D, T)

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "defesa")


# ============================================================================ PORTAL
FW, FH, FRAMES = 48, 80, 6


SPIKES = [0, 2, 1, 3, 0, 2, 3, 1, 2, 0, 3, 1]      # dentes da borda da fenda (escritos à mão; giram a cada quadro)


def portal_frame(f, ready):
    """Fenda vertical irregular: 4 faixas de cor sem meia-tinta, contorno escuro, núcleo claro que oscila."""
    cv = Canvas(FW, FH, T)
    cx = FW / 2.0
    amp = 15.0 if ready else 10.0               # meia-largura máxima da fenda
    bands = [                                    # (limite de d, cor)  d = distância normalizada ao centro
        (0.20, WHITE_HOT if ready else CYAN_L),
        (0.46, CYAN_L if ready else CYAN),
        (0.74, CYAN if ready else BLUE),
        (1.00, BLUE_D if ready else (24, 42, 70, 255)),
    ]
    for y in range(FH):
        t = (y + 0.5) / FH
        env = math.sin(math.pi * t) ** 0.9                         # fina nas pontas, larga no meio
        tooth = SPIKES[(y // 3 + f * 2) % len(SPIKES)]             # borda serrilhada que "queima"
        half = amp * env + tooth * env
        if half < 1.0:
            continue
        core = cx + (1 if (y // 6 + f) % 3 == 0 else (-1 if (y // 6 + f) % 3 == 1 else 0))   # núcleo oscila
        for x in range(FW):
            dx = x + 0.5 - core
            d = abs(dx) / half
            if d > 1.0:
                if d <= 1.0 + 1.5 / half:                           # contorno escuro de 1 px
                    cv.put(x, y, OUTLINE)
                continue
            col = bands[-1][1]
            for lim, c in bands:
                if d <= lim:
                    col = c
                    break
            cv.put(x, y, col)
    # faíscas: 3 por quadro, em cruz, em posições escritas à mão
    sparks = [(7, 56), (40, 30), (10, 20), (38, 62), (5, 38), (42, 46), (13, 70), (35, 10)]
    for k in range(3):
        sx, sy = sparks[(f * 3 + k) % len(sparks)]
        c = WHITE_HOT if ready else CYAN_L
        cv.put(sx, sy, c)
        cv.put(sx - 1, sy, CYAN)
        cv.put(sx + 1, sy, CYAN)
        cv.put(sx, sy - 1, CYAN)
        cv.put(sx, sy + 1, CYAN)
    if ready:                                                        # pronto: raios dourados nas pontas
        for yy, xx in ((4, 0), (FH - 6, 0)):
            for k in range(-1, 2):
                cv.put(int(cx) + k + xx, yy, YELLOW)
        for k in range(2):
            a = f * (math.pi / 3) + k * math.pi
            bx, by = int(cx + math.cos(a) * 20), int(FH * 0.5 + math.sin(a) * 26)
            cv.rect(bx - 1, by - 1, 3, 3, OUTLINE)
            cv.put(bx, by, YELLOW)
    return cv


def paint_portal():
    sheet = Canvas(FW * FRAMES, FH * 2, T)
    for row, ready in enumerate((False, True)):
        for f in range(FRAMES):
            sheet.paste(portal_frame(f, ready), f * FW, row * FH)
    return sheet


# ============================================================================ BARRAS DA HUD
BAR_W, BAR_H, FILL_W, FILL_H = 240, 22, 232, 14


def paint_bar_frame():
    cv = Canvas(BAR_W, BAR_H, T)
    cv.rect(0, 0, BAR_W, BAR_H, OUTLINE)
    cv.rect(1, 1, BAR_W - 2, BAR_H - 2, GOLD_D)
    cv.rect(2, 2, BAR_W - 4, BAR_H - 4, GOLD)
    for x in range(2, BAR_W - 2):
        cv.put(x, 2, GOLD_L)
    cv.rect(4, 4, FILL_W, FILL_H, OUTLINE)
    cv.rect(5, 5, FILL_W - 2, FILL_H - 2, NAVY_PLATE)
    for (x, y) in ((1, 1), (BAR_W - 2, 1), (1, BAR_H - 2), (BAR_W - 2, BAR_H - 2)):
        cv.put(x, y, OUTLINE)
    return cv


def paint_fill(base, light, dark):
    cv = Canvas(FILL_W, FILL_H, T)
    cv.rect(0, 0, FILL_W, FILL_H, base)
    for x in range(FILL_W):
        cv.put(x, 0, light)
        cv.put(x, 1, light)
        cv.put(x, FILL_H - 2, dark)
        cv.put(x, FILL_H - 1, dark)
    for x in range(8, FILL_W, 16):                                   # divisórias discretas
        for y in range(2, FILL_H - 2):
            cv.put(x, y, mix(base, dark, 0.35))
    return cv


def save(cv, name):
    os.makedirs(OUT, exist_ok=True)
    cv.img.save(os.path.join(OUT, name))
    print("   assets/defesa/%s" % name, cv.img.size)


def main():
    save(paint_arena(), "arena_defesa.png")
    save(paint_portal(), "portal.png")
    save(paint_bar_frame(), "barra_fundo.png")
    save(paint_fill(RED, (255, 105, 106, 255), RED_D), "barra_hp.png")
    save(paint_fill(ORANGE, YELLOW, ORANGE_D), "barra_hp_baixo.png")
    save(paint_fill(CYAN, CYAN_L, BLUE_D), "barra_carga.png")
    save(paint_fill((60, 150, 70, 255), GREEN_L, (30, 90, 40, 255)), "barra_pronto.png")


if __name__ == "__main__":
    main()
