#!/usr/bin/env python3
"""Gera a ARENA DO CHEFÃO (Fase 3) e o ataque de perto do ROBÔ ATIRADOR em pixel art, pixel a pixel (PIL).

Uso (na raiz do projeto):   python tools/gerar_arte_chefao.py

Saídas
  assets/arena/arena_chefao.png        1152 x 656, escala 1 (como o tileset_sf.png do projeto)
  sprites/robo_melee_aviso.png         6 quadros de 80 x 80 (progresso da carga do golpe)
  sprites/robo_melee_impacto.png       5 quadros de 80 x 80 (explosão do golpe)

Estilo: o mesmo do projeto (paleta do tileset_sf.png e do robô: azul-marinho, cinzas de aço, azul de
painel, laranja de aviso, vermelho do olho do robô, contorno quase preto). Luz sempre do canto superior
esquerdo. Sem antialiasing, sem degradê, sem ruído aleatório: tudo sai de regras fixas e de listas de
posições escritas à mão (as pequenas assimetrias são intencionais).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gerar_arte_fase2 import (  # noqa: E402
    Canvas, mix, disc, OUTLINE, NAVY, NAVY_SEAM, NAVY_PLATE, NAVY_HI, GREY_L, GREY_M, GREY, GREY_D,
    STEEL_L, STEEL, STEEL_D, BLUE, BLUE_L, BLUE_D, CYAN, CYAN_L, ORANGE, ORANGE_D, YELLOW, WHITE_HOT, RED,
    RED_D, GREEN_L, T, DIGITS)

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
W, H = 1152, 656

# Cores extras só desta arena (derivadas da paleta do projeto)
PLATE = (115, 120, 123, 255)       # chapa do piso (= GREY_D do tileset)
PLATE_LO = (102, 107, 111, 255)    # chapa trocada, um tom abaixo
PLATE_SH = (96, 101, 105, 255)     # sombra na borda de baixo de cada chapa
GROOVE = (40, 44, 48, 255)         # fresta funda
ROBO_RED = (252, 39, 39, 255)      # vermelho do olho do robô
ROBO_RED_HI = (255, 105, 106, 255)
WHITE = (231, 231, 231, 255)       # branco do corpo do robô
BLACK = (0, 0, 0, 255)

FONT = {
    "A": [".#.", "#.#", "###", "#.#", "#.#"], "L": ["#..", "#..", "#..", "#..", "###"],
    "E": ["###", "#..", "##.", "#..", "###"], "R": ["##.", "#.#", "##.", "#.#", "#.#"],
    "T": ["###", ".#.", ".#.", ".#.", ".#."], "G": ["###", "#..", "#.#", "#.#", "###"],
    "I": ["###", ".#.", ".#.", ".#.", "###"], "S": ["###", "#..", "###", "..#", "###"],
    ".": ["...", "...", "...", "...", ".#."],
}


def text(cv, x, y, s, col, scale=1, shade=None):
    for k, ch in enumerate(s):
        for j, row in enumerate(FONT[ch]):
            for i, c in enumerate(row):
                if c == "#":
                    cv.rect(x + (k * 4 + i) * scale, y + j * scale, scale, scale, col)
                    if shade:
                        cv.rect(x + (k * 4 + i) * scale + scale, y + j * scale + scale, scale, scale, shade)


def beveled(cv, x, y, w, h, fill, hi, lo, edge=OUTLINE):
    """Caixa com contorno, realce em cima/esquerda e sombra embaixo/direita."""
    cv.rect(x, y, w, h, fill)
    for i in range(1, w - 1):
        cv.put(x + i, y + 1, hi)
        cv.put(x + i, y + h - 2, lo)
    for j in range(1, h - 1):
        cv.put(x + 1, y + j, hi)
        cv.put(x + w - 2, y + j, lo)
    cv.frame(x, y, w, h, edge)


def hazard(cv, x, y, w, h, a=ORANGE, b=OUTLINE, period=8):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            cv.put(xx, yy, a if ((xx - yy) // (period // 2)) % 2 == 0 else b)


# ============================================================================ ARENA
def paint_arena():
    cv = Canvas(W, H, NAVY)

    # ---------------------------------------------------------------- faixa de serviço (fora da arena)
    for y in range(8, H - 8):
        for x in range(8, W - 8):
            if x % 32 == 0 or y % 32 == 0:
                cv.put(x, y, NAVY_SEAM)
            elif x % 32 == 1 and y % 32 == 1:
                cv.put(x, y, NAVY_HI)

    def pipe_h(x0, x1, y, th=8, stripe=None, offset=0):
        for x in range(x0, x1):
            cv.put(x, y, OUTLINE)
            cv.put(x, y + th - 1, OUTLINE)
            for j in range(1, th - 1):
                col = STEEL_L if j == 1 else (STEEL_D if j >= th - 3 else STEEL)
                if stripe and (x + offset) % stripe[0] < stripe[1]:
                    col = ORANGE if j < th - 3 else ORANGE_D
                cv.put(x, y + j, col)
        for x in range(x0, x1, 96):            # flanges
            cv.rect(x, y - 2, 4, th + 4, GREY)
            cv.frame(x, y - 2, 4, th + 4, OUTLINE)

    def pipe_v(x, y0, y1, th=8, stripe=None, offset=0):
        for y in range(y0, y1):
            cv.put(x, y, OUTLINE)
            cv.put(x + th - 1, y, OUTLINE)
            for i in range(1, th - 1):
                col = STEEL_L if i == 1 else (STEEL_D if i >= th - 3 else STEEL)
                if stripe and (y + offset) % stripe[0] < stripe[1]:
                    col = ORANGE if i < th - 3 else ORANGE_D
                cv.put(x + i, y, col)
        for y in range(y0, y1, 96):
            cv.rect(x - 2, y, th + 4, 4, GREY)
            cv.frame(x - 2, y, th + 4, 4, OUTLINE)

    pipe_h(16, W - 16, 22, 8, (96, 12), 30)
    pipe_h(16, W - 16, 34, 8)
    pipe_h(16, W - 16, 618, 8, (96, 12), 60)
    pipe_h(16, W - 16, 630, 8)
    pipe_v(18, 48, 616, 8, (96, 12), 10)
    pipe_v(30, 48, 616, 8)
    pipe_v(W - 26, 48, 616, 8, (96, 12), 50)
    pipe_v(W - 38, 48, 616, 8)

    # caixas de junção nos cantos (uma lâmpada âmbar acesa, outra apagada: assimetria intencional)
    for (bx, by, lit) in ((10, 10, True), (W - 42, 10, False), (10, H - 42, False), (W - 42, H - 42, True)):
        beveled(cv, bx, by, 32, 32, STEEL, STEEL_L, STEEL_D)
        for dx, dy in ((4, 4), (25, 4), (4, 25), (25, 25)):
            cv.put(bx + dx, by + dy, GREY_L)
            cv.put(bx + dx + 1, by + dy + 1, STEEL_D)
        cv.rect(bx + 12, by + 12, 8, 8, OUTLINE)
        cv.rect(bx + 13, by + 13, 6, 6, ORANGE if lit else (96, 60, 30, 255))
        if lit:
            cv.put(bx + 14, by + 14, YELLOW)

    # ---------------------------------------------------------------- moldura externa
    cv.frame(0, 0, W, H, OUTLINE)
    for i in range(1, 8):
        col = GREY_L if i == 1 else (GREY if i < 6 else GREY_D)
        for x in range(i, W - i):
            cv.put(x, i, col)
        for y in range(i, H - i):
            cv.put(i, y, col if i < 4 else GREY_M if i < 6 else GREY_D)
        col2 = GREY_D if i < 6 else STEEL_D
        for x in range(i, W - i):
            cv.put(x, H - 1 - i, col2)
        for y in range(i, H - i):
            cv.put(W - 1 - i, y, col2)
    cv.frame(8, 8, W - 16, H - 16, OUTLINE)

    # ---------------------------------------------------------------- aro da arena
    RX0, RY0, RX1, RY1 = 56, 64, 1096, 600       # retângulo externo do aro
    FX0, FY0, FX1, FY1 = 64, 120, 1088, 592      # piso
    cv.rect(RX0, RY0, RX1 - RX0, RY1 - RY0, STEEL_D)

    # ---------------------------------------------------------------- piso (chapas de 128 x 32, em tijolo)
    swapped = {(1, 3), (2, 8), (5, 1), (6, 6), (9, 4), (11, 7), (12, 2), (13, 5)}      # chapas trocadas
    for y in range(FY0, FY1):
        row = (y - FY0) // 32
        ly = (y - FY0) % 32
        shift = 64 if row % 2 else 0
        for x in range(FX0, FX1):
            col_i = (x - FX0 + shift) // 128
            lx = (x - FX0 + shift) % 128
            base = PLATE_LO if (row, col_i) in swapped else PLATE
            c = base
            if ly == 0:
                c = GROOVE
            elif ly == 1:
                c = GREY if base == PLATE else PLATE
            elif ly == 31:
                c = PLATE_SH if base == PLATE else (90, 95, 99, 255)
            if lx == 0:
                c = GROOVE
            elif lx == 1 and ly > 1:
                c = GREY if base == PLATE else PLATE
            elif lx == 127 and 1 < ly < 31:
                c = PLATE_SH
            cv.put(x, y, c)
    # rebites (4 por chapa; faltam alguns de propósito)
    missing = {(0, 2, 1), (3, 0, 0), (4, 5, 1), (6, 3, 0), (7, 7, 1), (9, 1, 1), (10, 4, 0), (12, 6, 1)}
    for row in range((FY1 - FY0) // 32):
        shift = 64 if row % 2 else 0
        for col in range(-1, 9):
            for k, (dx, dy) in enumerate(((6, 6), (121, 6), (6, 25), (121, 25))):
                if (row, col, k % 2) in missing and k < 2:
                    continue
                x = FX0 + col * 128 - shift + dx
                y = FY0 + row * 32 + dy
                if FX0 + 2 <= x < FX1 - 2 and y < FY1 - 2:
                    cv.put(x, y, GROOVE)
                    cv.put(x - 1, y - 1, GREY_L)

    # ---------------------------------------------------------------- selo central (sob o chefão e o jogador)
    cx, cy = 576, 356
    ring_edge = lambda d, a, b: a <= d < b
    for y in range(cy - 160, cy + 160):
        for x in range(cx - 160, cx + 160):
            if not (FX0 <= x < FX1 and FY0 <= y < FY1):
                continue
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            ang = (math.degrees(math.atan2(dy, dx)) + 360) % 360
            c = None
            if ring_edge(d, 148, 151):
                c = GROOVE
            elif ring_edge(d, 151, 152):
                c = GREY
            elif ring_edge(d, 126, 146):
                c = BLUE_D
                if ring_edge(d, 126, 128):
                    c = BLUE
                if ring_edge(d, 130, 138) and abs(((ang + 7.5) % 15) - 7.5) < 1.6:
                    c = BLUE_L if int(ang // 15) % 6 == 0 else BLUE
            elif ring_edge(d, 122, 124):
                c = (0, 105, 145, 255)
            elif ring_edge(d, 96, 118):
                c = STEEL_D
                if abs(((ang + 22.5) % 45) - 22.5) < 3.2:
                    c = PLATE_SH
                elif ring_edge(d, 96, 98):
                    c = STEEL
            elif ring_edge(d, 92, 95):
                c = BLUE
            elif ring_edge(d, 90, 92):
                c = GROOVE
            elif d < 88:
                c = (100, 105, 110, 255)
            if c is not None:
                cv.put(x, y, c)
    # hexágono e olho do centro
    hexr = 54
    for y in range(cy - hexr, cy + hexr):
        for x in range(cx - hexr, cx + hexr):
            dx, dy = abs(x + 0.5 - cx), abs(y + 0.5 - cy)
            inside = dy <= hexr * 0.866 and dx * 0.866 + dy * 0.5 <= hexr * 0.866
            if inside:
                edge = dy > hexr * 0.866 - 3 or dx * 0.866 + dy * 0.5 > hexr * 0.866 - 3
                cv.put(x, y, BLUE if edge else BLUE_D)
    disc(cv, cx, cy, 24, (10, 25, 45, 255), OUTLINE)
    disc(cv, cx, cy, 17, RED_D)
    disc(cv, cx, cy, 11, (172, 50, 50, 255))
    disc(cv, cx - 2, cy - 2, 5, ROBO_RED)
    cv.put(cx - 4, cy - 4, ROBO_RED_HI)
    cv.put(cx - 3, cy - 4, ROBO_RED_HI)

    # ---------------------------------------------------------------- plataforma de entrada (jogador) e do chefão
    px, py = 131, 335
    beveled(cv, px - 28, py - 28, 56, 56, STEEL_D, STEEL, GROOVE)
    cv.rect(px - 22, py - 22, 44, 44, BLUE_D)
    cv.frame(px - 22, py - 22, 44, 44, BLUE)
    for k in range(2):                                   # setas para a direita (rumo ao chefão)
        for j, row in enumerate(["#..", "##.", "###", "##.", "#.."]):
            for i, ch in enumerate(row):
                if ch == "#":
                    cv.put(px - 9 + k * 9 + i * 2, py - 5 + j * 2, BLUE_L)
                    cv.put(px - 8 + k * 9 + i * 2, py - 5 + j * 2, BLUE_L)
    for dx, dy in ((-26, -26), (24, -26), (-26, 24), (24, 24)):
        cv.put(px + dx, py + dy, ORANGE)
    bx, by = 860, 335
    disc(cv, bx, by, 64, GROOVE)
    for y in range(by - 62, by + 62):
        for x in range(bx - 62, bx + 62):
            d = math.hypot(x + 0.5 - bx, y + 0.5 - by)
            if 52 <= d < 61:
                ang = (math.degrees(math.atan2(y - by, x - bx)) + 360) % 360
                cv.put(x, y, ORANGE if int(ang // 15) % 2 == 0 else OUTLINE)
            elif d < 52:
                cv.put(x, y, (70, 40, 42, 255) if d > 46 else (62, 36, 38, 255))
    for k in range(6):                                   # raios do desenho
        a = math.radians(k * 60 + 15)
        for t in range(10, 44):
            cv.put(int(bx + math.cos(a) * t), int(by + math.sin(a) * t), RED_D)
    disc(cv, bx, by, 9, RED_D, OUTLINE)
    disc(cv, bx - 1, by - 1, 4, RED)

    # ---------------------------------------------------------------- ralos (4 cantos) e lâmpadas
    def drain(x, y):
        beveled(cv, x - 20, y - 20, 40, 40, STEEL, STEEL_L, STEEL_D)
        for yy in range(y - 15, y + 15):
            for xx in range(x - 15, x + 15):
                d = math.hypot(xx + 0.5 - x, yy + 0.5 - y)
                if d < 15:
                    bar = (xx - x) % 5 == 0 or (yy - y) % 5 == 0
                    cv.put(xx, yy, OUTLINE if d > 13 else ((75, 90, 110, 255) if bar else (14, 26, 38, 255)))
        for dx, dy in ((-17, -17), (16, -17), (-17, 16), (16, 16)):
            cv.put(x + dx, y + dy, GREY_L)
    for (dx_, dy_) in ((144, 244), (1008, 244), (144, 500), (1008, 500)):
        drain(dx_, dy_)

    def beacon(x, y, lit):
        cv.rect(x - 11, y + 6, 22, 6, OUTLINE)
        cv.rect(x - 10, y + 6, 20, 4, STEEL_D)
        cv.put(x - 10, y + 6, STEEL_L)
        dome = (ORANGE, YELLOW, ORANGE_D) if lit else ((150, 90, 40, 255), (190, 130, 60, 255), (100, 60, 30, 255))
        for yy in range(y - 14, y + 7):
            for xx in range(x - 9, x + 10):
                d = math.hypot((xx + 0.5 - x) / 9.0, (yy + 0.5 - (y + 4)) / 18.0)
                if d <= 1.0:
                    c = dome[0]
                    if d > 0.82:
                        c = dome[2]
                    cv.put(xx, yy, c)
                elif d <= 1.13:
                    cv.put(xx, yy, OUTLINE)
        cv.rect(x - 5, y - 9, 3, 7, dome[1])
        cv.put(x - 5, y - 10, WHITE_HOT if lit else dome[1])
    for (x, y, lit) in ((124, 176, True), (1040, 176, False), (108, 566, False), (1044, 566, True)):
        beacon(x, y, lit)

    # ---------------------------------------------------------------- marcas de uso (escritas à mão)
    scorch = [(470, 300, [4, 8, 11, 12, 10, 7, 3]), (700, 430, [3, 7, 9, 9, 6, 3]), (330, 450, [2, 5, 7, 6, 3]),
              (905, 250, [3, 6, 8, 7, 4]), (560, 520, [4, 9, 12, 11, 7, 3])]
    for (x, y, widths) in scorch:
        for j, wd in enumerate(widths):
            for i in range(wd * 2):
                xx, yy = x + i - wd, y + j
                if cv.get(xx, yy)[3] and cv.get(xx, yy) not in (GROOVE,):
                    cv.put(xx, yy, (62, 66, 70, 255) if (i + j) % 3 else (74, 78, 82, 255))
    cracks = [[(280, 220), (284, 226), (283, 232), (290, 240), (291, 247)], [(780, 480), (776, 486), (780, 492), (777, 499)],
              [(640, 190), (645, 196), (643, 203), (650, 210), (652, 216), (658, 220)],
              [(960, 400), (955, 405), (957, 412), (952, 418)]]
    for pts in cracks:
        for (ax, ay), (bx2, by2) in zip(pts, pts[1:]):
            n = max(abs(bx2 - ax), abs(by2 - ay))
            for i in range(n + 1):
                xx, yy = ax + round((bx2 - ax) * i / n), ay + round((by2 - ay) * i / n)
                cv.put(xx, yy, GROOVE)
                cv.put(xx + 1, yy, GREY)

    # ---------------------------------------------------------------- sombras de contato no piso (2 tons)
    for x in range(FX0, FX1):
        for k, c in enumerate(((60, 64, 68, 255), (84, 89, 93, 255), (98, 103, 107, 255))):
            cv.put(x, FY0 + k, c) if cv.get(x, FY0 + k) not in (GROOVE,) else None
    for y in range(FY0, FY1):
        for k, c in enumerate(((66, 70, 74, 255), (90, 95, 99, 255))):
            cv.put(FX0 + k, y, c)
    for y in range(FY0, FY1):
        cv.put(FX1 - 1, y, (96, 101, 105, 255))

    # ---------------------------------------------------------------- aro: topo/laterais/base
    for y in range(RY0, RY1):                          # laterais (tampa do aro)
        for k in range(8):
            cl = GREY_L if k == 1 else (GREY if k < 6 else GREY_D)
            cv.put(RX0 + k, y, OUTLINE if k == 0 else cl)
            cr = GREY if k == 6 else (GREY_D if k < 3 else GREY_L if k == 7 else GREY_M)
            cv.put(RX1 - 1 - k, y, OUTLINE if k == 0 else (GREY_D if k >= 5 else GREY))
    for x in range(RX0, RX1):                          # base: tampa + face frontal + sombra
        for k in range(8):
            cv.put(x, FY1 + k, OUTLINE if k == 7 else (GREY_L if k == 0 else GREY if k < 5 else GREY_D))
        for k, c in enumerate((STEEL_L, STEEL, STEEL, STEEL_D, OUTLINE)):
            cv.put(x, RY1 + k - 0, c)
        cv.put(x, RY1 + 5, NAVY_PLATE)
        cv.put(x, RY1 + 6, NAVY_PLATE)
        if (x - RX0) % 96 == 48:
            for k in range(1, 4):
                cv.put(x, RY1 + k, STEEL_D)

    # ---------------------------------------------------------------- parede do fundo (painel de controle)
    WX0, WY0, WX1, WY1 = RX0, RY0, RX1, FY0
    cv.rect(WX0, WY0, WX1 - WX0, WY1 - WY0, BLUE_D)
    for x in range(WX0, WX1):                                 # tampa de cima
        for k in range(8):
            cv.put(x, WY0 + k, OUTLINE if k == 0 else (GREY_L if k == 1 else GREY if k < 6 else GREY_D))
    for y in range(WY0 + 8, WY1):                             # faixas de azul (3 tons, sem degradê)
        for x in range(WX0, WX1):
            yy = y - WY0
            c = BLUE_D
            if 10 <= yy < 12:
                c = CYAN_L                                    # fita luminosa
            elif 12 <= yy < 14:
                c = CYAN
            elif 14 <= yy < 38:
                c = BLUE
            elif 38 <= yy < 40:
                c = BLUE_L
            elif yy >= 52:
                c = STEEL_D
            if (x - WX0) % 64 == 0 and 14 <= yy < 52:
                c = BLUE_D
            elif (x - WX0) % 64 == 1 and 14 <= yy < 52:
                c = BLUE_L
            cv.put(x, y, c)
    for x in range(WX0, WX1):                                 # base da parede
        cv.put(x, WY1 - 4, OUTLINE)
        cv.put(x, WY1 - 3, STEEL_L)
        cv.put(x, WY1 - 2, STEEL)
        cv.put(x, WY1 - 1, OUTLINE)
    for k in range(WY0, WY1):                                 # cantos laterais
        for i in range(2):
            cv.put(WX0 + i, k, GREY_L if i == 0 else GREY)
            cv.put(WX1 - 1 - i, k, GREY_D)

    def monitor(x, bars):
        beveled(cv, x, WY0 + 22, 64, 32, STEEL_D, STEEL, GROOVE)
        cv.rect(x + 4, WY0 + 26, 56, 22, (10, 25, 45, 255))
        cv.frame(x + 4, WY0 + 26, 56, 22, OUTLINE)
        for n, (ln, col) in enumerate(bars):
            cv.rect(x + 7, WY0 + 29 + n * 4, ln, 2, col)
        cv.put(x + 57, WY0 + 45, GREEN_L)
    monitor(152, [(30, CYAN_L), (44, CYAN), (22, CYAN_L), (38, CYAN)])
    monitor(352, [(18, ORANGE), (46, CYAN), (36, CYAN_L), (12, ORANGE)])
    monitor(736, [(40, CYAN), (20, CYAN_L), (50, CYAN), (28, CYAN_L)])
    monitor(936, [(26, CYAN_L), (34, ORANGE), (14, CYAN), (48, CYAN)])

    def plaque(x):                                            # aviso "ALERTA" (borda de perigo + letras)
        hazard(cv, x, WY0 + 18, 84, 38, ORANGE, OUTLINE, 8)
        cv.rect(x + 6, WY0 + 24, 72, 26, OUTLINE)
        for k, ch in enumerate("ALERTA"):
            text(cv, x + 9 + k * 10, WY0 + 32, ch, WHITE, 2, shade=(100, 100, 100, 255))
        cv.frame(x, WY0 + 18, 84, 38, OUTLINE)
    plaque(262)
    plaque(806)

    # portão do chefão (centro)
    gx = 504
    beveled(cv, gx, WY0 + 8, 144, 48, STEEL, STEEL_L, STEEL_D)
    cv.rect(gx + 8, WY0 + 14, 128, 42, STEEL_D)
    cv.frame(gx + 8, WY0 + 14, 128, 42, OUTLINE)
    cv.rect(gx + 12, WY0 + 18, 58, 38, STEEL)
    cv.rect(gx + 74, WY0 + 18, 58, 38, STEEL)
    for half in (gx + 12, gx + 74):
        cv.frame(half, WY0 + 18, 58, 38, OUTLINE)
        for x in range(half + 2, half + 56):
            cv.put(x, WY0 + 19, STEEL_L)
        for k in range(4):
            cv.put(half + 6, WY0 + 24 + k * 8, GROOVE)
            cv.put(half + 51, WY0 + 24 + k * 8, GROOVE)
    hazard(cv, gx + 12, WY0 + 48, 120, 8, ORANGE, OUTLINE, 8)
    cv.rect(gx + 38, WY0 + 2, 68, 12, OUTLINE)
    for k, ch in enumerate("AEGIS"):
        text(cv, gx + 48 + k * 11, WY0 + 4, ch, WHITE, 2, shade=(100, 100, 100, 255))
    for lx in (gx + 2, gx + 136):
        cv.rect(lx, WY0 + 26, 6, 10, OUTLINE)
        cv.rect(lx + 1, WY0 + 27, 4, 8, RED)
        cv.put(lx + 1, WY0 + 27, ROBO_RED_HI)

    return cv


# ============================================================================ ROBÔ: golpe de perto
def line(cv, x0, y0, x1, y1, col):
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        cv.put(x0, y0, col)
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def outlined_line(cv, pts, col, outline=BLACK):
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
            line(cv, x0 + ox, y0 + oy, x1 + ox, y1 + oy, outline)
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        line(cv, x0, y0, x1, y1, col)


C = 40   # centro do quadro (80 x 80)


def warning_frame(k, frames=6):
    """Aviso (carga): anel de 24 segmentos que vão acendendo; o centro marca o robô."""
    cv = Canvas(80, 80)
    lit_n = [0, 4, 8, 12, 17, 24][k]
    for y in range(80):
        for x in range(80):
            dx, dy = x + 0.5 - C, y + 0.5 - C
            d = math.hypot(dx, dy)
            ang = (math.degrees(math.atan2(dy, dx)) + 90 + 360) % 360
            seg = int(ang // 15)
            if 36 <= d < 40:
                gap = (ang % 15) < 1.6
                if gap:
                    cv.put(x, y, BLACK)
                    continue
                on = seg < lit_n
                if d < 37:
                    c = ROBO_RED_HI if on else RED_D
                elif d < 39:
                    c = ROBO_RED if on else (150, 40, 44, 255)
                else:
                    c = (170, 30, 30, 255) if on else (70, 20, 24, 255)
                cv.put(x, y, c)
            elif 35 <= d < 36 or 40 <= d < 41:
                cv.put(x, y, BLACK)
    # setas internas apontando para o centro (N, L, S, O)
    for ang in (0, 90, 180, 270):
        a = math.radians(ang)
        ux, uy = math.sin(a), -math.cos(a)
        for t in range(26, 33):
            w = 6 - (t - 26)
            for s in range(-w // 2, w // 2 + 1):
                cv.put(int(C + ux * t - uy * s), int(C + uy * t + ux * s), ROBO_RED if k >= 2 else RED_D)
    # preenchimento quadriculado (regular, não aleatório) cresce com a carga
    fill_r = [0, 8, 15, 22, 28, 34][k]
    for y in range(80):
        for x in range(80):
            d = math.hypot(x + 0.5 - C, y + 0.5 - C)
            if d < fill_r and (x + y) % 2 == 0 and not cv.get(x, y)[3]:
                cv.put(x, y, (252, 39, 39, 120 if k < 5 else 170))
    # marca no centro
    for t in range(-3, 4):
        cv.put(C + t, C, BLACK)
        cv.put(C, C + t, BLACK)
    cv.put(C, C, ROBO_RED_HI)
    return cv


def impact_frame(k):
    """Impacto: explosão elétrica que sai do robô, chega ao raio total (80 px) e se desfaz (5 quadros)."""
    cv = Canvas(80, 80)
    ring_r = [14, 27, 38, 39, 39][k]
    ring_col = [WHITE_HOT, YELLOW, ORANGE, ROBO_RED, RED_D][k]
    body_col = [None, (255, 226, 120, 150), (255, 178, 51, 120), (252, 39, 39, 70), None][k]
    # corpo da explosão: preenchimento quadriculado (regular) dentro do anel
    if body_col:
        for y in range(80):
            for x in range(80):
                if math.hypot(x + 0.5 - C, y + 0.5 - C) < ring_r and (x + y) % 2 == 0:
                    cv.put(x, y, body_col)
    # raios: nascem perto do centro e vão em zigue-zague até o anel (listas escritas à mão)
    angles = [8, 38, 66, 97, 128, 158, 187, 219, 247, 276, 306, 336]
    lengths = [34, 28, 36, 30, 35, 27, 36, 31, 34, 28, 35, 30]
    zig = [0, 3, -2, 3, -3, 2, -2, 3]
    if k in (1, 2, 3):
        scale = [0.62, 1.0, 0.78][k - 1]
        start = [4, 6, 16][k - 1]
        col = [YELLOW, ORANGE, ROBO_RED][k - 1]
        for n, (ang0, ln) in enumerate(zip(angles, lengths)):
            a = math.radians(ang0)
            end = int(ln * scale) + (3 if k == 2 else 0)
            pts = []
            for t in range(start, end + 1, 4):
                off = zig[(t // 4 + n) % len(zig)] if t > start else 0
                pts.append((round(C + math.cos(a) * t - math.sin(a) * off),
                            round(C + math.sin(a) * t + math.cos(a) * off)))
            if len(pts) >= 2:
                outlined_line(cv, pts, col)
                outlined_line(cv, [(x + 1, y) for x, y in pts], col, outline=col)   # raio com 2 px de largura
    # anel de choque (contorno preto + 2 cores)
    for y in range(80):
        for x in range(80):
            d = math.hypot(x + 0.5 - C, y + 0.5 - C)
            thick = [3, 4, 4, 2, 1][k]
            if ring_r - thick <= d < ring_r:
                cv.put(x, y, ring_col if d >= ring_r - thick + 1 or k == 4 else mix(ring_col, (255, 255, 255, 255), 0.0))
            elif ring_r <= d < ring_r + 1 or (k >= 1 and ring_r - thick - 1 <= d < ring_r - thick):
                cv.put(x, y, BLACK)
    # núcleo branco-quente no começo
    if k <= 1:
        disc(cv, C, C, [8, 10][k], WHITE_HOT, BLACK)
        disc(cv, C, C, [4, 6][k], YELLOW)
    # fagulhas (pontos 2x2, posições escritas à mão) nos últimos quadros
    sparks = {2: [(14, 20), (66, 18), (12, 60), (68, 62)], 3: [(10, 28), (70, 30), (22, 70), (58, 10), (36, 74), (44, 6)],
              4: [(8, 36), (72, 44), (30, 72), (52, 8), (66, 66)]}
    for (x, y) in sparks.get(k, []):
        cv.rect(x, y, 2, 2, [None, None, YELLOW, ORANGE, ROBO_RED][k])
    return cv


def paint_robo():
    sheet = Canvas(80 * 6, 80)
    for k in range(6):
        sheet.paste(warning_frame(k), k * 80, 0)
    sheet.img.save(os.path.join(ROOT, "sprites", "robo_melee_aviso.png"))
    print("   sprites/robo_melee_aviso.png", sheet.img.size)
    sheet = Canvas(80 * 5, 80)
    for k in range(5):
        sheet.paste(impact_frame(k), k * 80, 0)
    sheet.img.save(os.path.join(ROOT, "sprites", "robo_melee_impacto.png"))
    print("   sprites/robo_melee_impacto.png", sheet.img.size)


def main():
    out = os.path.join(ROOT, "assets", "arena")
    os.makedirs(out, exist_ok=True)
    cv = paint_arena()
    cv.img.save(os.path.join(out, "arena_chefao.png"))
    print("   assets/arena/arena_chefao.png", cv.img.size)
    print('   (o golpe de perto do Robô agora é gerado por tools/gerar_arte_ataques_chefao.py)')


if __name__ == "__main__":
    main()
