"""Arena da FASE DE DEFESA ("rota de fuga", um corredor de dados da AEGIS) em pixel art, regra por regra.

Usada por tools/gerar_arte_defesa.py  ->  assets/defesa/arena_defesa.png (1152 x 656, escala 1).

A arena NÃO reaproveita nenhum sprite de outra arena (nem o piso, nem o selo, nem as escotilhas do chefão):
tudo é desenhado aqui. Só a paleta e a resolução de pixel são as do projeto (tileset_sf.png /
gerar_arte_fase2.py), para o conjunto combinar. Sem antialiasing, sem degradê, sem ruído aleatório.

Composição: moldura de aço, fileira de 11 racks de servidor no topo, piso de placas azul-marinho de 32 px com
trilhas de circuito ciano ligando as 8 escotilhas de nascimento à plataforma central, 8 nós brilhantes em volta
e o poço escuro do portal no centro. Contorno tracejado de perigo em volta do piso.
"""
import math

from gerar_arte_fase2 import (
    Canvas, mix, disc, OUTLINE, NAVY, NAVY_SEAM, NAVY_PLATE, NAVY_HI, GREY_L, GREY, GREY_D, STEEL_L, STEEL,
    STEEL_D, BLUE, BLUE_D, CYAN, CYAN_L, ORANGE, ORANGE_D, WHITE_HOT, GREEN_L)

W, H = 1152, 656
FX0, FY0, FX1, FY1 = 48, 104, 1104, 608           # piso jogável (as paredes de colisão ficam fora disso)
CENTER = (576, 356)                                # centro do poço do portal
TRACE = (16, 78, 108, 255)                         # trilha de circuito apagada (ciano escuro)
TRACE_HI = (0, 120, 160, 255)
VOID = (6, 12, 22, 255)

# escotilhas de nascimento: (x, y, orientação)  "d" aponta para baixo, "u" para cima, "r"/"l" para os lados
GATES = [(216, 134, "d"), (576, 134, "d"), (936, 134, "d"),
         (216, 578, "u"), (576, 578, "u"), (936, 578, "u"),
         (78, 356, "r"), (1074, 356, "l")]


def rect_hi(cv, x, y, w, h, fill, hi, lo, edge=OUTLINE):
    """Caixa com contorno, realce em cima/esquerda e sombra embaixo/direita."""
    cv.rect(x, y, w, h, fill)
    for i in range(1, w - 1):
        cv.put(x + i, y + 1, hi)
        cv.put(x + i, y + h - 2, lo)
    for j in range(1, h - 1):
        cv.put(x + 1, y + j, hi)
        cv.put(x + w - 2, y + j, lo)
    cv.frame(x, y, w, h, edge)


def stripes(cv, x, y, w, h, a=ORANGE, b=OUTLINE, period=8):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            cv.put(xx, yy, a if ((xx - yy) // (period // 2)) % 2 == 0 else b)


def line(cv, x0, y0, x1, y1, col):
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        cv.put(x0 + round((x1 - x0) * i / n), y0 + round((y1 - y0) * i / n), col)


def paint_walls(cv):
    """Moldura externa, racks de servidor no topo, canaleta de cabos embaixo e contorno de perigo do piso."""
    cv.rect(0, 0, W, H, STEEL_D)
    cv.frame(0, 0, W, H, OUTLINE)
    for i in range(1, 7):                                           # chanfro da moldura
        c = GREY_L if i == 1 else (GREY if i < 5 else GREY_D)
        for x in range(i, W - i):
            cv.put(x, i, c)
        for y in range(i, H - i):
            cv.put(i, y, c if i < 3 else GREY_D)
        low = GREY_D if i < 5 else STEEL_L
        for x in range(i, W - i):
            cv.put(x, H - 1 - i, low)
        for y in range(i, H - i):
            cv.put(W - 1 - i, y, low)
    cv.rect(8, 8, W - 16, H - 16, NAVY_PLATE)
    cv.frame(8, 8, W - 16, H - 16, OUTLINE)
    for r in range(11):                                             # racks (parede de cima)
        rx = 24 + r * 96
        rect_hi(cv, rx, 16, 84, 80, STEEL_D, STEEL, NAVY_PLATE)
        for d in range(5):
            dy = 22 + d * 14
            cv.rect(rx + 6, dy, 72, 11, OUTLINE)
            cv.rect(rx + 7, dy + 1, 70, 9, NAVY)
            cv.rect(rx + 7, dy + 1, 70, 1, NAVY_HI)
            for k in range(3):                                      # luzes: um padrão fixo por gaveta
                on = (r * 7 + d * 3 + k) % 4 != 0
                col = (CYAN_L if (r + d + k) % 3 == 0 else GREEN_L) if on else NAVY_SEAM
                cv.rect(rx + 11 + k * 6, dy + 4, 3, 3, col)
            for g in range(7):                                      # grelha de ventilação
                cv.rect(rx + 40 + g * 5, dy + 3, 2, 5, NAVY_SEAM)
    for (yy, striped) in ((616, True), (630, False)):               # canaleta de cabos (embaixo)
        for x in range(16, W - 16):
            cv.put(x, yy, OUTLINE)
            cv.put(x, yy + 9, OUTLINE)
            for j in range(1, 9):
                c = STEEL_L if j == 1 else (STEEL_D if j >= 7 else STEEL)
                if striped and (x // 12) % 6 == 0 and j < 7:
                    c = ORANGE
                cv.put(x, yy + j, c)
        for x in range(32, W - 32, 112):
            rect_hi(cv, x, yy - 3, 6, 16, GREY, GREY_L, GREY_D)
    for x in range(FX0 - 4, FX1 + 4):                               # contorno de perigo tracejado
        for k in (FY0 - 5, FY1 + 2):
            c = ORANGE if (x // 8) % 2 == 0 else OUTLINE
            cv.put(x, k, c)
            cv.put(x, k + 1, c)
    for y in range(FY0 - 5, FY1 + 4):
        for k in (FX0 - 5, FX1 + 2):
            c = ORANGE if (y // 8) % 2 == 0 else OUTLINE
            cv.put(k, y, c)
            cv.put(k + 1, y, c)


def paint_floor(cv):
    """Placas de 32 x 32 azul-marinho; algumas trocadas (um tom acima) e rebites nos cantos."""
    swapped = {(1, 4), (2, 12), (4, 20), (5, 7), (7, 25), (9, 15), (10, 3), (12, 28), (13, 10), (14, 22), (15, 17)}
    for y in range(FY0, FY1):
        row, ly = (y - FY0) // 32, (y - FY0) % 32
        for x in range(FX0, FX1):
            col_i, lx = (x - FX0) // 32, (x - FX0) % 32
            c = NAVY_HI if (row, col_i) in swapped else NAVY
            if ly == 0 or lx == 0:
                c = NAVY_SEAM
            elif ly == 1 or lx == 1:
                c = mix(c, NAVY_HI, 0.35)
            elif ly == 31 or lx == 31:
                c = mix(c, NAVY_PLATE, 0.5)
            cv.put(x, y, c)
    for row in range((FY1 - FY0) // 32):
        for col in range((FX1 - FX0) // 32):
            for dx, dy in ((4, 4), (27, 4), (4, 27), (27, 27)):
                x, y = FX0 + col * 32 + dx, FY0 + row * 32 + dy
                cv.put(x, y, NAVY_SEAM)
                cv.put(x - 1, y - 1, BLUE_D)
    for x in range(FX0, FX1):                                       # sombra de contato das paredes
        cv.put(x, FY0, (14, 24, 38, 255))
        cv.put(x, FY0 + 1, NAVY_PLATE)
    for y in range(FY0, FY1):
        cv.put(FX0, y, (14, 24, 38, 255))
        cv.put(FX0 + 1, y, NAVY_PLATE)


def paint_traces(cv):
    """Trilhas de circuito (ciano apagado) das escotilhas até a plataforma, em L, com nós nas dobras."""
    cx, cy = CENTER
    for (gx, gy, o) in GATES:
        if o in ("d", "u"):
            sign = -1 if o == "d" else 1
            pts = [(gx, gy + (-sign) * 26), (gx, cy + sign * 120), (cx + (gx - cx) // 3, cy + sign * 120), (cx, cy)]
        else:
            tx = gx + (30 if o == "r" else -30)
            pts = [(tx, gy), (cx + (-190 if o == "r" else 190), gy), (cx, gy)]
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            line(cv, ax, ay, bx, by, TRACE)
            line(cv, ax, ay + 1, bx, by + 1, OUTLINE)
        for (nx, ny) in pts[1:-1]:
            cv.rect(nx - 2, ny - 2, 5, 5, OUTLINE)
            cv.rect(nx - 1, ny - 1, 3, 3, TRACE_HI)
            cv.put(nx, ny, CYAN_L)


def paint_nodes(cv):
    """Oito nós brilhantes em volta da plataforma (discos com anel ciano)."""
    cx, cy = CENTER
    for k in range(8):
        a = math.radians(k * 45 + 22.5)
        nx, ny = int(cx + math.cos(a) * 250), int(cy + math.sin(a) * 180)
        disc(cv, nx, ny, 14, (10, 24, 40, 255), OUTLINE)
        disc(cv, nx, ny, 10, BLUE_D)
        disc(cv, nx, ny, 6, CYAN)
        disc(cv, nx, ny, 3, CYAN_L)
        cv.put(nx - 1, ny - 1, WHITE_HOT)


def paint_pad(cv):
    """Plataforma central: anel de placas com divisórias, aro luminoso e o poço escuro onde o portal nasce."""
    cx, cy = CENTER
    for y in range(cy - 130, cy + 130):
        for x in range(cx - 130, cx + 130):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            ang = (math.degrees(math.atan2(y + 0.5 - cy, x + 0.5 - cx)) + 360) % 360
            c = None
            if 118 <= d < 121:
                c = OUTLINE
            elif 116 <= d < 118:
                c = STEEL_L
            elif 96 <= d < 116:
                c = NAVY_PLATE
                if abs(((ang + 15) % 30) - 15) < 1.5:               # 12 divisórias radiais
                    c = NAVY_SEAM
                elif 100 <= d < 112 and abs(((ang + 7.5) % 15) - 7.5) < 1.2 and int(ang // 30) % 2 == 0:
                    c = TRACE_HI
            elif 92 <= d < 96:
                c = CYAN if int(ang // 10) % 2 == 0 else TRACE_HI
            elif 90 <= d < 92:
                c = OUTLINE
            elif 70 <= d < 90:
                c = NAVY_SEAM if (int(ang // 45) % 2 == 0) else NAVY_PLATE
            if c is not None:
                cv.put(x, y, c)
    for y in range(cy - 60, cy + 60):                               # poço do portal (elipse achatada)
        for x in range(cx - 70, cx + 70):
            d = math.hypot(x + 0.5 - cx, (y + 0.5 - cy) / 0.6)
            c = None
            if 62 <= d < 66:
                c = OUTLINE
            elif 58 <= d < 62:
                c = BLUE
            elif 54 <= d < 58:
                c = BLUE_D
            elif 30 <= d < 54:
                c = NAVY_PLATE
            elif 14 <= d < 30:
                c = (12, 22, 38, 255)
            elif d < 14:
                c = VOID
            if c is not None:
                cv.put(x, y, c)
    for k in range(4):                                              # ancoragens de energia
        a = math.radians(45 + k * 90)
        ax, ay = int(cx + math.cos(a) * 74), int(cy + math.sin(a) * 46)
        cv.rect(ax - 3, ay - 3, 7, 7, OUTLINE)
        cv.rect(ax - 2, ay - 2, 5, 5, BLUE_D)
        cv.rect(ax - 1, ay - 1, 3, 3, CYAN_L)


def paint_gate(cv, gx, gy, o):
    """Escotilha de nascimento: moldura de aço, faixa de perigo, miolo escuro e três setas para dentro da arena."""
    horiz = o in ("d", "u")
    w, h = (72, 34) if horiz else (34, 72)
    x0, y0 = gx - w // 2, gy - h // 2
    rect_hi(cv, x0, y0, w, h, STEEL_D, STEEL_L, OUTLINE)
    if horiz:
        stripes(cv, x0 + 3, y0 + (h - 7 if o == "d" else 3), w - 6, 4)
        ix, iy, iw, ih = x0 + 6, y0 + (4 if o == "d" else 11), w - 12, h - 15
    else:
        stripes(cv, x0 + (w - 7 if o == "r" else 3), y0 + 3, 4, h - 6)
        ix, iy, iw, ih = x0 + (4 if o == "r" else 11), y0 + 6, w - 15, h - 12
    cv.rect(ix, iy, iw, ih, VOID)
    cv.frame(ix, iy, iw, ih, OUTLINE)
    for k in range(3):
        col = ORANGE if k == 1 else ORANGE_D
        for j in range(4):
            for i in range(-3 + j, 4 - j):
                if horiz:
                    cv.put(ix + 14 + k * 20 + i, iy + ih // 2 + (j - 2 if o == "d" else 1 - j), col)
                else:
                    cv.put(ix + iw // 2 + (j - 2 if o == "r" else 1 - j), iy + 14 + k * 20 + i, col)
    for dx, dy in ((3, 3), (w - 4, 3), (3, h - 4), (w - 4, h - 4)):
        cv.put(x0 + dx, y0 + dy, GREY_L)


def paint_arena():
    cv = Canvas(W, H, NAVY)
    paint_walls(cv)
    paint_floor(cv)
    paint_traces(cv)
    paint_nodes(cv)
    paint_pad(cv)
    for (gx, gy, o) in GATES:
        paint_gate(cv, gx, gy, o)
    return cv
