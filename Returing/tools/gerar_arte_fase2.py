#!/usr/bin/env python3
"""Gera a ARTE da Fase 2 (labirinto) em pixel art, pixel a pixel, com PIL.

Uso (na raiz do projeto):   python tools/gerar_arte_fase2.py

- Resolução nativa baixa: 1 pixel de arte = 2 px de tela (Sprite2D com escala 2, filtro Nearest).
- Paleta tirada do tileset_sf.png e do drone do projeto (azul-marinho, cinzas, laranja/vermelho/ciano).
- Luz sempre vinda do canto superior esquerdo: realce em cima/esquerda, sombra embaixo/direita.
- Sem antialiasing, sem degradê, sem ruído aleatório: tudo é desenhado por regras fixas e
  listas escritas à mão (posições dos detalhes).
- A geometria vem de tools/fase2_layout.py (a mesma que gera colisões e oclusores).

Saída em assets/arena/.
"""
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fase2_layout as L  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "arena")

# ------------------------------------------------------------------ paleta
OUTLINE = (15, 18, 28, 255)
NAVY = (37, 54, 68, 255)
NAVY_SEAM = (30, 46, 60, 255)
NAVY_PLATE = (22, 36, 50, 255)
NAVY_HI = (46, 66, 84, 255)
AO1 = (26, 41, 55, 255)
AO2 = (32, 49, 63, 255)
GREY_L = (165, 170, 174, 255)
GREY_M = (150, 156, 160, 255)
GREY = (136, 141, 145, 255)
GREY_D = (115, 120, 123, 255)
STEEL_L = (91, 95, 102, 255)
STEEL = (75, 75, 77, 255)
STEEL_D = (56, 60, 61, 255)
BLUE = (91, 124, 157, 255)
BLUE_L = (143, 172, 202, 255)
BLUE_D = (32, 57, 86, 255)
CYAN = (0, 151, 198, 255)
CYAN_L = (90, 169, 255, 255)
ORANGE = (255, 178, 51, 255)
ORANGE_D = (200, 110, 30, 255)
YELLOW = (255, 226, 120, 255)
WHITE_HOT = (255, 246, 205, 255)
RED = (172, 50, 50, 255)
RED_D = (110, 30, 34, 255)
GREEN = (41, 114, 38, 255)
GREEN_L = (76, 175, 70, 255)
GOLD = (232, 193, 90, 255)
GOLD_L = (254, 226, 134, 255)
GOLD_D = (170, 120, 38, 255)
PURPLE = (112, 46, 139, 255)
T = (0, 0, 0, 0)

GLYPH_COLOR = {0: ORANGE, 1: CYAN_L, 2: GREEN_L}   # triângulo, quadrado, círculo


# ------------------------------------------------------------------ utilidades
class Canvas:
    def __init__(self, w, h, fill=T):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w, h), fill)
        self.px = self.img.load()

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = c

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[x, y]
        return T

    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.put(xx, yy, c)

    def frame(self, x, y, w, h, c):
        for xx in range(x, x + w):
            self.put(xx, y, c)
            self.put(xx, y + h - 1, c)
        for yy in range(y, y + h):
            self.put(x, yy, c)
            self.put(x + w - 1, yy, c)

    def stamp(self, x, y, rows, pal):
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch != "." and ch in pal:
                    self.put(x + i, y + j, pal[ch])

    def paste(self, other, x, y):
        for j in range(other.h):
            for i in range(other.w):
                c = other.px[i, j]
                if c[3]:
                    self.put(x + i, y + j, c)

    def save(self, name):
        os.makedirs(OUT, exist_ok=True)
        path = os.path.join(OUT, name)
        self.img.save(path)
        print("  ", name, self.img.size)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


def disc(cv, cx, cy, r, fill, outline=None):
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if d <= r:
                cv.put(x, y, fill)
            elif outline and d <= r + 1:
                cv.put(x, y, outline)


def expand_mask(mask, k):
    h, w = len(mask), len(mask[0])
    return [[mask[y // k][x // k] for x in range(w * k)] for y in range(h * k)]


# ------------------------------------------------------------------ máscaras em pixels de arte
UA = L.UNIT // L.ART   # 8 pixels de arte por unidade


def art_masks():
    solid, floor = L.build_masks()
    return expand_mask(solid, UA), expand_mask(floor, UA)


def run_lengths(S):
    """Para cada pixel sólido: quantos pixels sólidos seguidos existem acima/abaixo/esquerda/direita."""
    h, w = len(S), len(S[0])
    dN = [[0] * w for _ in range(h)]
    dS = [[0] * w for _ in range(h)]
    dW = [[0] * w for _ in range(h)]
    dE = [[0] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if S[y][x]:
                dN[y][x] = dN[y - 1][x] + 1 if y > 0 and S[y - 1][x] else 0
                dW[y][x] = dW[y][x - 1] + 1 if x > 0 and S[y][x - 1] else 0
    for y in range(h - 1, -1, -1):
        for x in range(w - 1, -1, -1):
            if S[y][x]:
                dS[y][x] = dS[y + 1][x] + 1 if y < h - 1 and S[y + 1][x] else 0
                dE[y][x] = dE[y][x + 1] + 1 if x < w - 1 and S[y][x + 1] else 0
    return dN, dS, dW, dE


# ------------------------------------------------------------------ PAREDES (camada por cima do piso)
def paint_walls(S, F):
    h, w = len(S), len(S[0])
    cv = Canvas(w, h)
    dN, dS, dW, dE = run_lengths(S)
    # topo da parede (a "tampa")
    for y in range(h):
        for x in range(w):
            if not S[y][x]:
                continue
            n, s, we, e = dN[y][x], dS[y][x], dW[y][x], dE[y][x]
            hrun, vrun = we + e + 1, n + s + 1
            if n == 0 or we == 0 or e == 0:
                c = OUTLINE
            elif n == 1:
                c = GREY_L
            elif we == 1:
                c = GREY_M
            elif e == 1:
                c = GREY_D
            elif s == 0:
                c = GREY_D
            else:
                c = GREY
                # emendas de placa: verticais nas paredes horizontais, horizontais nas verticais;
                # o deslocamento muda de parede para parede (pequena assimetria intencional).
                if hrun > UA and vrun <= UA * 2 and (x + 5 * (y // UA)) % 24 == 0:
                    c = GREY_D
                    if n == 2:
                        c = GREY_L
                elif vrun > UA and hrun <= UA and (y + 7 * (x // UA)) % 24 == 0:
                    c = GREY_D
                    if we == 2:
                        c = GREY_L
            cv.put(x, y, c)
    # face frontal (parede vista de cima e de frente) nos pixels de piso logo abaixo de uma parede
    face = [[False] * w for _ in range(h)]
    FACE_H = 6
    for y in range(h):
        for x in range(w):
            if S[y][x] or not F[y][x]:
                continue
            up = 0
            for k in range(1, FACE_H + 1):
                if y - k >= 0 and S[y - k][x]:
                    up = k
                    break
                if y - k >= 0 and not F[y - k][x]:
                    break
            if up:
                face[y][x] = True
                k = up - 1
                colors = [STEEL_L, STEEL, STEEL, STEEL, STEEL_D, OUTLINE]
                c = colors[k]
                if 1 <= k <= 3 and (x + 5 * ((y - k - 1) // UA)) % 24 == 0:
                    c = STEEL_D
                cv.put(x, y, c)
    for y in range(h):
        for x in range(w):
            if face[y][x]:
                lx = x > 0 and face[y][x - 1]
                rx = x < w - 1 and face[y][x + 1]
                if not lx or not rx:
                    cv.put(x, y, OUTLINE)
    # sombra de contato no piso logo abaixo da face (2 tons, mesma direção de luz)
    for y in range(h):
        for x in range(w):
            if S[y][x] or face[y][x] or not F[y][x]:
                continue
            for k, c in ((1, AO1), (2, AO2)):
                yy = y - FACE_H - k
                if 0 <= yy < h and face[yy][x] and not face[y][x]:
                    cv.put(x, y, c)
                    break
    return cv


# ------------------------------------------------------------------ PISO
def paint_floor(F):
    h, w = len(F), len(F[0])
    cv = Canvas(w, h)
    for y in range(h):
        for x in range(w):
            if not F[y][x]:
                continue
            c = NAVY
            # ladrilhos de 8 px; placas grandes de 3 x 3 ladrilhos com emenda mais funda
            if x % UA == 0 or y % UA == 0:
                c = NAVY_SEAM
            if x % (UA * 3) == 0 or y % (UA * 3) == 0:
                c = NAVY_PLATE
            if x % UA == 1 and y % UA == 1 and (x // UA + y // UA) % 3 != 1:
                c = NAVY_HI   # realce de canto (luz vem de cima/esquerda); falha de propósito em 1 de 3
            cv.put(x, y, c)
    return cv


def floor_decor(cv):
    ac = lambda px: px // L.ART  # px de tela -> px de arte

    # --- grelhas de ventilação (posições escolhidas à mão: célula + deslocamento em px de arte)
    grate = [
        "oooooooooooooooo",
        "ogggggggggggggso",
        "ogddddddddddddgo",
        "ogdoooooooooodgo",
        "ogddddddddddddgo",
        "ogdoooooooooodgo",
        "ogddddddddddddgo",
        "ogdoooooooooodgo",
        "ogddddddddddddgo",
        "ogdoooooooooodgo",
        "ogddddddddddddgo",
        "ogggggggggggggso",
        "oooooooooooooooo",
    ]
    gp = {"o": OUTLINE, "g": STEEL, "d": (20, 30, 40, 255), "s": STEEL_D}
    for (c, r), (dx, dy) in {(2, 3): (-6, 4), (5, 5): (4, -10), (6, 1): (-14, 8), (8, 5): (2, 6),
                              (4, 0): (-4, -8), (9, 3): (6, -2)}.items():
        x0, y0, _, _ = L.cell_rect(c, r)
        cv.stamp(ac(x0) + 16 + dx, ac(y0) + 16 + dy, grate, gp)

    # --- rachaduras (polilinhas escritas à mão, em px de arte relativos ao canto da célula)
    cracks = {
        (1, 1): [(6, 8), (9, 11), (11, 12), (14, 17), (15, 20), (19, 22)],
        (4, 2): [(30, 6), (28, 10), (31, 14), (30, 18), (33, 23)],
        (6, 4): [(8, 30), (12, 32), (14, 35), (19, 36), (22, 40)],
        (3, 3): [(36, 10), (34, 14), (35, 17), (31, 20)],
        (8, 6): [(10, 12), (13, 14), (14, 18)],
    }
    for (c, r), pts in cracks.items():
        x0, y0, _, _ = L.cell_rect(c, r)
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            steps = max(abs(bx - ax), abs(by - ay))
            for i in range(steps + 1):
                px_ = ac(x0) + ax + round((bx - ax) * i / steps)
                py_ = ac(y0) + ay + round((by - ay) * i / steps)
                cv.put(px_, py_, OUTLINE)
                cv.put(px_ + 1, py_, NAVY_PLATE)

    # --- manchas de óleo (formas em linhas: largura por linha)
    stains = {(7, 6): (14, 30, [3, 6, 8, 9, 8, 6, 3]), (2, 4): (28, 22, [2, 5, 7, 6, 4]),
              (5, 1): (10, 12, [4, 7, 8, 5, 2]), (0, 5): (24, 36, [3, 6, 7, 7, 4, 2])}
    for (c, r), (dx, dy, widths) in stains.items():
        x0, y0, _, _ = L.cell_rect(c, r)
        for j, wd in enumerate(widths):
            for i in range(wd):
                cv.put(ac(x0) + dx + i - wd // 2 + 4, ac(y0) + dy + j, (18, 30, 42, 255))

    # --- conduíte de cabos em um corredor (linha tracejada com pontos laranja)
    x0, y0, _, _ = L.cell_rect(6, 6)
    for i in range(0, 90):
        cv.put(ac(x0) - 8 + i, ac(y0) + 44, STEEL_D)
        cv.put(ac(x0) - 8 + i, ac(y0) + 45, OUTLINE)
        if i % 11 == 5:
            cv.put(ac(x0) - 8 + i, ac(y0) + 44, ORANGE_D)

    # --- plataforma de INÍCIO (célula 0,6)
    sx, sy = (ac(v) for v in L.cell_center(*L.START_CELL))
    for yy in range(-14, 14):
        for xx in range(-14, 14):
            edge = max(abs(xx + 0.5), abs(yy + 0.5))
            if edge <= 13:
                c = STEEL_D if edge > 11 else BLUE_D
                if 9 <= edge <= 10:
                    c = BLUE
                cv.put(sx + xx, sy + yy, c)
    cv.frame(sx - 14, sy - 14, 28, 28, OUTLINE)
    chevron = ["..#..", ".###.", "##.##"]
    for k in range(2):
        for j, row in enumerate(chevron):
            for i, ch in enumerate(row):
                if ch == "#":
                    cv.put(sx - 2 + i, sy - 6 + k * 5 + j, BLUE_L)
    for dx, dy in ((-12, -12), (11, -12), (-12, 11), (11, 11)):
        cv.put(sx + dx, sy + dy, ORANGE)

    # --- pedestal da chave (célula 9,6)
    kx, ky = (ac(v) for v in L.cell_center(*L.KEY_CELL))
    cv.rect(kx - 12, ky - 12, 24, 24, STEEL_D)
    cv.frame(kx - 12, ky - 12, 24, 24, OUTLINE)
    cv.rect(kx - 9, ky - 9, 18, 18, BLUE_D)
    cv.frame(kx - 9, ky - 9, 18, 18, STEEL)
    for dx, dy in ((-11, -11), (10, -11), (-11, 10), (10, 10)):
        cv.put(kx + dx, ky + dy, ORANGE)

    # --- base de cada painel do puzzle (na cor do seu símbolo, apagada)
    for name, p in L.PANELS.items():
        px_, py_ = (ac(v) for v in L.cell_center(*p["cell"]))
        col = mix(STEEL_D, GLYPH_COLOR[p["glyph"]], 0.35)
        cv.rect(px_ - 15, py_ - 15, 30, 30, STEEL_D)
        cv.frame(px_ - 15, py_ - 15, 30, 30, OUTLINE)
        cv.frame(px_ - 13, py_ - 13, 26, 26, col)

    # --- faixas de perigo ao redor de cada trecho de fogo
    for name, (a, b) in L.FIRE_PASSAGES.items():
        (fx, fy, fw, fh), orient = L.fire_rect(a, b)
        fx, fy, fw, fh = fx // 2, fy // 2, fw // 2, fh // 2
        bands = [(fx - 5, fy, 4, fh), (fx + fw + 1, fy, 4, fh)] if orient == "h" else \
                [(fx, fy - 5, fw, 4), (fx, fy + fh + 1, fw, 4)]
        for bx, by, bw, bh in bands:
            for yy in range(by, by + bh):
                for xx in range(bx, bx + bw):
                    if cv.get(xx, yy)[3]:
                        cv.put(xx, yy, ORANGE if ((xx + yy) // 3) % 2 == 0 else STEEL_D)
            cv.frame(bx, by, bw, bh, OUTLINE)

    # --- vestíbulo atrás da porta: setas para leste e plataforma de saída
    vx, vy, vw, vh = L.VEST
    vx, vy, vw, vh = vx // 2, vy // 2, vw // 2, vh // 2
    arrow = ["#.....", "##....", "###...", "####..", "###...", "##....", "#....."]
    for k in range(2):
        for j, row in enumerate(arrow):
            for i, ch in enumerate(row):
                if ch == "#":
                    cv.put(vx + 6 + k * 8 + i, vy + 17 + j, CYAN)
    ex, ey, ew, eh = (v // 2 for v in L.EXIT_RECT)
    for yy in range(eh):
        for xx in range(ew):
            edge = min(xx, yy, ew - 1 - xx, eh - 1 - yy)
            c = BLUE_D if edge > 1 else (CYAN if edge == 1 else OUTLINE)
            if edge > 3 and (xx + yy) % 4 == 0:
                c = (20, 70, 100, 255)
            cv.put(ex + xx, ey + yy, c)


def paint_arena():
    S, F = art_masks()
    floor = paint_floor(F)
    floor_decor(floor)
    # chão do vão da porta (sob o sprite da porta)
    floor.save("arena_piso.png")
    paint_walls(S, F).save("arena_paredes.png")


# ------------------------------------------------------------------ FOGO (4 quadros)
def tongue(cv, cx, base_y, height, width, sway, flip=1):
    """Língua de fogo subindo (para cima na tela) a partir de base_y."""
    for i in range(height):
        t = i / max(height - 1, 1)
        ow = max(1, round(width * (1 - t ** 1.5)))
        off = round(sway * math.sin(t * math.pi) * flip)
        y = base_y - i
        for layer, (shrink, col) in enumerate(((0, RED_D), (1, RED), (3, ORANGE), (5, YELLOW), (7, WHITE_HOT))):
            lw = ow - shrink
            if lw < 1 or (layer >= 3 and t > 0.65 - 0.1 * layer):
                continue
            if layer == 1 and t > 0.9:
                continue
            for dx in range(lw):
                cv.put(cx + off - lw // 2 + dx, y, col)
    # topo escuro (fumaça de brasa) para a ponta não ficar chapada
    # (a ponta já fica vermelha escura pela primeira camada)


def paint_fire():
    # quadros: deslocamento fixo das línguas (não é ruído: tabela escrita à mão)
    sway = [(1, -1, 1, 0), (0, 1, -1, 1), (-1, 0, 1, -1), (1, 1, 0, -1)]
    grow = [(0, 2, 1, 3), (2, 0, 3, 1), (1, 3, 0, 2), (3, 1, 2, 0)]
    # corredor horizontal: faixa em pé 16 x 48 (línguas ao longo do eixo Y)
    sheet = Canvas(16 * 4, 48)
    bases = [(5, 9), (10, 8), (4, 8), (11, 10)]   # (x, comprimento base) escritos à mão por linha
    for f in range(4):
        cv = Canvas(16, 48)
        # leito de brasas
        for j in range(48):
            if j % 3 != 1:
                cv.put(2 + (j * 5 % 3), j, RED_D)
                cv.put(13 - (j * 7 % 3), j, RED_D)
        for n, base_y in enumerate((11, 22, 33, 44, 47)):
            cx = 8 + (-2, 2, -1, 1, 0)[n]
            h = 9 + grow[f][n % 4] + (n % 2)
            tongue(cv, cx, base_y, h, 9 - (n % 2), sway[f][n % 4], 1 if n % 2 == 0 else -1)
        sheet.paste(cv, f * 16, 0)
    sheet.save("fogo_corredor_horizontal.png")
    # corredor vertical: faixa deitada 48 x 16 (línguas ao longo do eixo X)
    sheet = Canvas(48 * 4, 16)
    for f in range(4):
        cv = Canvas(48, 16)
        for i in range(48):
            if i % 3 != 1:
                cv.put(i, 13 - (i * 5 % 2), RED_D)
                cv.put(i, 15 - (i * 7 % 2), RED_D)
        for n, cx in enumerate((9, 19, 28, 38)):          # fileira de trás (mais curta)
            tongue(cv, cx, 8, 6 + grow[f][(n + 1) % 4] // 2, 7, sway[f][(n + 2) % 4], 1 if n % 2 else -1)
        for n, cx in enumerate((5, 14, 23, 32, 41)):
            h = 9 + grow[f][n % 4] + (n % 2)
            tongue(cv, cx + (-1, 1, 0, -1, 1)[n], 14, h, 9 - (n % 2), sway[f][n % 4], 1 if n % 2 == 0 else -1)
        sheet.paste(cv, f * 48, 0)
    sheet.save("fogo_corredor_vertical.png")


# ------------------------------------------------------------------ CHAVE
def paint_key():
    cv = Canvas(16, 16)
    rows = [
        "...oooooo...",
        "..oyyyyyyo..",
        ".oyYYYYYyyo.",
        ".oyY....Yyo.",
        ".oyY....Yyo.",
        ".oyyY..Yyyo.",
        "..oyyyyyyo..",
        "...ooyyoo...",
        ".....oyo....",
        ".....oyo....",
        ".....oyyoo..",
        ".....oyYyo..",
        ".....oyyoo..",
        ".....oyo....",
        ".....oyyo...",
        ".....ooo....",
    ]
    pal = {"o": OUTLINE, "y": GOLD, "Y": GOLD_L, "d": GOLD_D}
    cv.stamp(2, 0, rows, pal)
    # sombra do lado direito/baixo (luz de cima-esquerda)
    for y in range(16):
        for x in range(16):
            if cv.get(x, y) == GOLD and cv.get(x + 1, y) == OUTLINE:
                cv.put(x, y, GOLD_D)
    cv.save("chave.png")


# ------------------------------------------------------------------ PORTA (vertical: 8 x 48)
def paint_door(state):
    cv = Canvas(8, 48)
    if state == "aberta":
        # só os batentes ficam: a porta recolhe para dentro da parede
        for y in list(range(0, 4)) + list(range(44, 48)):
            for x in range(8):
                cv.put(x, y, STEEL_D)
            cv.put(0, y, OUTLINE)
            cv.put(7, y, OUTLINE)
        cv.put(3, 1, GREEN_L)
        cv.put(4, 1, GREEN_L)
        cv.put(3, 46, GREEN_L)
        cv.put(4, 46, GREEN_L)
        for y in range(4, 44):          # tapete escuro onde a porta estava
            for x in range(8):
                cv.put(x, y, (20, 32, 44, 255) if (x + y) % 8 else (26, 41, 55, 255))
        cv.save("porta_aberta.png")
        return
    lamp = {"trancada": RED, "destrancada": ORANGE}[state]
    lamp_hi = {"trancada": (230, 110, 100, 255), "destrancada": YELLOW}[state]
    for y in range(48):
        for x in range(8):
            c = STEEL
            if x == 0 or x == 7:
                c = OUTLINE
            elif x == 1:
                c = STEEL_L
            elif x == 6:
                c = STEEL_D
            if y in (0, 47):
                c = OUTLINE
            elif y in (1, 46):
                c = STEEL_L if x < 6 else STEEL_D
            cv.put(x, y, c)
    for y in (12, 13, 34, 35):      # frestas das placas
        for x in range(2, 6):
            cv.put(x, y, STEEL_D)
    # placa da fechadura (parte de baixo da arte: a luz fica no centro do vão)
    for y in range(19, 30):
        for x in range(2, 6):
            cv.put(x, y, OUTLINE if y in (19, 29) or x in (2, 5) else STEEL_D)
    cv.put(3, 21, lamp_hi)
    cv.put(4, 21, lamp)
    cv.put(3, 22, lamp)
    cv.put(4, 22, lamp)
    # símbolo de cadeado (fechado) / aberto
    cv.put(3, 24, BLUE_L)
    cv.put(4, 24, BLUE_L)
    cv.put(3, 25, BLUE_L if state == "trancada" else T)
    cv.put(4, 25, BLUE_L)
    cv.put(3, 26, GOLD)
    cv.put(4, 26, GOLD)
    cv.put(3, 27, GOLD_D)
    cv.put(4, 27, GOLD_D)
    cv.save(f"porta_{state}.png")


# ------------------------------------------------------------------ PAINÉIS (3 símbolos x 2 estados)
def glyph_pixels(g):
    """Lista de (x, y) de um símbolo 8 x 8."""
    pts = []
    if g == 0:      # triângulo
        for y in range(8):
            wd = 2 + (y // 2) * 2 if y < 6 else 8
            wd = min(8, 2 * ((y // 2) + 1))
            for x in range(4 - wd // 2, 4 + wd // 2):
                pts.append((x, y))
    elif g == 1:    # quadrado vazado
        for y in range(8):
            for x in range(8):
                if x in (0, 1, 6, 7) or y in (0, 1, 6, 7):
                    pts.append((x, y))
    else:           # círculo
        for y in range(8):
            for x in range(8):
                if math.hypot(x - 3.5, y - 3.5) <= 3.9:
                    pts.append((x, y))
    return pts


def paint_panels(on):
    sheet = Canvas(24 * 3, 24)
    for g in range(3):
        cv = Canvas(24, 24)
        col = GLYPH_COLOR[g]
        # sombra no chão
        cv.rect(3, 21, 19, 3, (16, 26, 38, 255))
        # corpo (face de cima + face da frente)
        cv.rect(1, 2, 22, 13, STEEL)
        cv.frame(1, 2, 22, 13, OUTLINE)
        for x in range(2, 22):
            cv.put(x, 3, STEEL_L)
        cv.rect(1, 15, 22, 6, STEEL_D)
        cv.frame(1, 15, 22, 6, OUTLINE)
        for x in range(2, 22):
            cv.put(x, 16, STEEL)
        # tela
        bg = mix((8, 16, 26), col, 0.30 if on else 0.0)
        cv.rect(4, 5, 16, 9, bg)
        cv.frame(4, 5, 16, 9, OUTLINE)
        glyph = col if on else mix((8, 16, 26), col, 0.32)
        for (x, y) in glyph_pixels(g):
            cv.put(8 + x, 5 + y - 0, glyph) if y < 8 else None
        if on:
            for (x, y) in glyph_pixels(g):
                if (x, y) in ((1, 1),):
                    cv.put(8 + x, 5 + y, WHITE_HOT)
        # luzes da face da frente
        for i in range(3):
            lc = col if (on and i <= g) else mix(STEEL_D, col, 0.25)
            cv.put(6 + i * 5, 18, lc)
            cv.put(7 + i * 5, 18, lc)
        sheet.paste(cv, g * 24, 0)
    sheet.save("painel_ligado.png" if on else "painel_desligado.png")


DIGITS = {
    "1": [".#.", "##.", ".#.", ".#.", "###"],
    "2": ["##.", "..#", ".#.", "#..", "###"],
    "3": ["##.", "..#", "##.", "..#", "##."],
}


def paint_hint():
    """Projeção holográfica no chão: a ordem certa dos três símbolos (46 px de arte = 92 px: cabe no corredor de 96)."""
    cv = Canvas(46, 30)
    cv.rect(0, 0, 46, 30, (12, 24, 38, 255))
    cv.frame(0, 0, 46, 30, OUTLINE)
    cv.frame(1, 1, 44, 28, BLUE_D)
    for x in range(3, 43, 4):       # moldura tracejada
        cv.put(x, 2, CYAN)
        cv.put(x, 27, CYAN)
    for n, g in enumerate(L.SOLUTION):
        x0 = 3 + n * 14
        dig = DIGITS[str(n + 1)]
        for j, row in enumerate(dig):
            for i, ch in enumerate(row):
                if ch == "#":
                    cv.put(x0 + 4 + i, 4 + j, BLUE_L)
        for (x, y) in glyph_pixels(g):
            cv.put(x0 + 2 + x, 12 + y, GLYPH_COLOR[g])
        cv.frame(x0, 10, 12, 12, BLUE_D)
        if n < 2:                    # seta ">" no vão de 2 px entre os quadros
            cv.put(x0 + 12, 15, CYAN)
            cv.put(x0 + 13, 16, CYAN)
            cv.put(x0 + 12, 17, CYAN)
    cv.save("dica_ordem.png")


# ------------------------------------------------------------------ PROPS (4 decalques 16 x 16, sem colisão)
def paint_props():
    sheet = Canvas(64, 16)
    # 0: sucata
    cv = Canvas(16, 16)
    scrap = [
        "................",
        "....ooo.........",
        "...oGGGoo..oo...",
        "..oGgggGGooGGo..",
        "..oGggdddGGgGo..",
        ".ooGgddooGggdo..",
        ".oGGgdooRoGgdo..",
        ".oGggdoRRoodoo..",
        ".ooGdddoRRoo....",
        "..ooddddooRo....",
        "....oooooo.o....",
        "................",
    ]
    pal = {"o": OUTLINE, "G": GREY_L, "g": GREY, "d": GREY_D, "R": RED}
    cv.stamp(0, 2, scrap, pal)
    sheet.paste(cv, 0, 0)
    # 1: bobina de cabo
    cv = Canvas(16, 16)
    disc(cv, 8, 8, 6, STEEL_D, OUTLINE)
    disc(cv, 8, 8, 4, ORANGE_D)
    disc(cv, 8, 8, 2, STEEL, OUTLINE)
    for dx in range(0, 6):
        cv.put(8 + dx, 8, OUTLINE)
        cv.put(13, 8 + dx // 2, OUTLINE)
    cv.put(6, 6, ORANGE)
    cv.put(7, 5, ORANGE)
    sheet.paste(cv, 16, 0)
    # 2: peça de drone (hélice vermelha)
    cv = Canvas(16, 16)
    drone = [
        "................",
        "..oo............",
        ".oRRo...........",
        ".oRRRoooo.......",
        "..ooGGGGGoo.....",
        "....oGggggGo....",
        "....oGgddggo....",
        "....oGgooggo....",
        ".....oGgggdo....",
        ".....ooddddo....",
        ".......oooo.....",
    ]
    pal2 = {"o": OUTLINE, "R": RED, "G": GREY_L, "g": GREY, "d": GREY_D}
    cv.stamp(0, 2, drone, pal2)
    sheet.paste(cv, 32, 0)
    # 3: barril tombado
    cv = Canvas(16, 16)
    barrel = [
        "................",
        "..oooooooooo....",
        ".oBBBBBBBBBBo...",
        ".oBbbbbbbbbbo...",
        ".oCCCCCCCCCCo...",
        ".oBbbbbbbbbbo...",
        ".oBbbbbbbbbbo...",
        ".oCCCCCCCCCCo...",
        ".oddddddddddo...",
        "..oooooooooo....",
    ]
    pal3 = {"o": OUTLINE, "B": BLUE, "b": BLUE_D, "C": CYAN, "d": STEEL_D}
    cv.stamp(0, 3, barrel, pal3)
    sheet.paste(cv, 48, 0)
    sheet.save("props.png")


# ------------------------------------------------------------------ SALA NOVA
SALA_W, SALA_H = 72, 41        # unidades de 16 px  (1152 x 656)


def sala_masks():
    solid = [[False] * SALA_W for _ in range(SALA_H)]
    floor = [[False] * SALA_W for _ in range(SALA_H)]
    for uy in range(SALA_H):
        for ux in range(SALA_W):
            border = ux in (0, SALA_W - 1) or uy in (0, SALA_H - 1) or uy == 1
            solid[uy][ux] = border
            floor[uy][ux] = not border
    for (px_, py_, pw, ph) in L_SALA_PILLARS:
        for uy in range(py_, py_ + ph):
            for ux in range(px_, px_ + pw):
                solid[uy][ux] = True
                floor[uy][ux] = False
    return solid, floor


L_SALA_PILLARS = [(14, 10, 2, 2), (14, 28, 2, 2), (30, 10, 2, 2), (30, 28, 2, 2), (46, 10, 2, 2), (46, 28, 2, 2)]
SALA_START = (112, 328)
SALA_NUCLEO = (1008, 328)


def paint_sala():
    solid, floor = sala_masks()
    S, F = expand_mask(solid, UA), expand_mask(floor, UA)
    fl = paint_floor(F)
    # trilho de luz no centro (faixa clara com setas)
    h, w = len(F), len(F[0])
    for x in range(40, w - 56):
        for y in (h // 2 - 1, h // 2):
            if F[y][x]:
                fl.put(x, y, BLUE_D if (x // 4) % 2 else BLUE)
    for x0 in range(70, w - 80, 56):
        for j, row in enumerate(["#..", "##.", "###", "##.", "#.."]):
            for i, ch in enumerate(row):
                if ch == "#":
                    fl.put(x0 + i, h // 2 - 3 + j, CYAN)
    # plataforma de partida
    sx, sy = SALA_START[0] // 2, SALA_START[1] // 2
    for yy in range(-14, 14):
        for xx in range(-14, 14):
            edge = max(abs(xx + 0.5), abs(yy + 0.5))
            c = STEEL_D if edge > 11 else BLUE_D
            if 9 <= edge <= 10:
                c = BLUE
            fl.put(sx + xx, sy + yy, c)
    fl.frame(sx - 14, sy - 14, 28, 28, OUTLINE)
    # plataforma do núcleo
    nx, ny = SALA_NUCLEO[0] // 2, SALA_NUCLEO[1] // 2
    for yy in range(-22, 22):
        for xx in range(-22, 22):
            edge = max(abs(xx + 0.5), abs(yy + 0.5))
            if edge > 21:
                continue
            c = STEEL_D if edge > 18 else BLUE_D
            if 15 <= edge <= 17:
                c = BLUE
            if edge <= 14 and (xx + yy) % 6 == 0:
                c = (20, 40, 60, 255)
            fl.put(nx + xx, ny + yy, c)
    fl.frame(nx - 22, ny - 22, 44, 44, OUTLINE)
    fl.save("sala_piso.png")
    paint_walls(S, F).save("sala_paredes.png")
    # núcleo (3 quadros de 32 x 32): pilar com cristal ciano pulsando
    sheet = Canvas(32 * 3, 32)
    for f in range(3):
        cv = Canvas(32, 32)
        cv.rect(4, 24, 24, 6, (16, 26, 38, 255))
        cv.rect(6, 18, 20, 8, STEEL_D)
        cv.frame(6, 18, 20, 8, OUTLINE)
        cv.rect(8, 10, 16, 9, STEEL)
        cv.frame(8, 10, 16, 9, OUTLINE)
        for x in range(9, 23):
            cv.put(x, 11, STEEL_L)
        rr = (6, 7, 6)[f]
        glow = (CYAN, CYAN_L, CYAN)[f]
        disc(cv, 16, 8, rr, mix((8, 16, 26), CYAN, 0.35), OUTLINE)
        disc(cv, 16, 8, rr - 2, glow)
        disc(cv, 15, 7, max(1, rr - 5), WHITE_HOT)
        sheet.paste(cv, f * 32, 0)
    sheet.save("sala_nucleo.png")


def main():
    print("Gerando arte da Fase 2 em", os.path.normpath(OUT))
    paint_arena()
    paint_fire()
    paint_key()
    for s in ("trancada", "destrancada", "aberta"):
        paint_door(s)
    paint_panels(False)
    paint_panels(True)
    paint_hint()
    paint_props()
    paint_sala()
    print("pronto.")


if __name__ == "__main__":
    main()
