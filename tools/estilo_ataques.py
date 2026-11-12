"""Linguagem visual ÚNICA dos ataques (chefão Guide e Robô atirador). Importado por
gerar_arte_ataques_chefao.py e gerar_arte_chefao.py.

Regras (iguais para todo ataque):
  * 6 cores só: preto (contorno), vermelho escuro, vermelho, vermelho vivo, rosa e branco.
  * contorno preto de 1 px em tudo; luz do canto superior esquerdo (realce rosa/branco em cima à esquerda);
  * formas grandes e simples (anéis de 4 px, discos, 4 triângulos ou 4 lâminas), sem pontinhos nem xadrez;
  * 1 px de arte = 2 px de tela (as cenas desenham o quadro com o dobro do tamanho);
  * TODA marcação de área é igual: anel + preenchimento que cresce do centro + 4 marcas.
    Aviso:   anel escuro -> vermelho -> vivo (último quadro), preenchimento cresce, marcas acendem.
    Impacto: clarão branco -> disco vermelho com miolo claro -> anel largo -> anel fino -> 4 fagulhas.
"""
import math

from gerar_arte_fase2 import Canvas, disc

BLACK = (0, 0, 0, 255)
DK = (102, 6, 6, 255)
RED = (208, 33, 33, 255)
HI = (252, 39, 39, 255)
PINK = (255, 170, 171, 255)
WHITE = (254, 254, 254, 255)


def band(cv, c, r0, r1, col):
    """Anel de raio r0..r1 centrado em (c, c)."""
    n = int(round(c * 2))
    for y in range(n):
        for x in range(n):
            d = math.hypot(x + 0.5 - c, y + 0.5 - c)
            if r0 <= d < r1:
                cv.put(x, y, col)


def solid_disc(cv, c, r, col, alpha=None):
    n = int(round(c * 2))
    colr = col if alpha is None else (col[0], col[1], col[2], alpha)
    for y in range(n):
        for x in range(n):
            if math.hypot(x + 0.5 - c, y + 0.5 - c) < r:
                cv.put(x, y, colr)


def lit_ring_color(p):
    return DK if p < 0.4 else (RED if p < 0.99 else HI)


TRI = ["#######", ".#####.", "..###..", "...#..."]


def triangle(cv, cx, cy, direction, fill):
    """Triângulo de 7 x 4 com contorno, ponta voltada para o centro da área."""
    pts = set()
    for j, row in enumerate(TRI):
        for i, ch in enumerate(row):
            if ch == "#":
                u, v = i - 3, j          # u: lado, v: profundidade (0 = base)
                if direction == "N":     # base em cima, ponta para baixo
                    pts.add((cx + u, cy + v))
                elif direction == "S":
                    pts.add((cx + u, cy - v))
                elif direction == "W":
                    pts.add((cx + v, cy + u))
                else:
                    pts.add((cx - v, cy + u))
    for (x, y) in pts:
        for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + ox, y + oy) not in pts:
                cv.put(x + ox, y + oy, BLACK)
    for (x, y) in pts:
        cv.put(x, y, fill)


def blade(cv, c, ang_deg, r0, r1, base_w, fill, hi):
    """Lâmina que afina de base_w até 1 px, com contorno preto e um lado mais claro."""
    a = math.radians(ang_deg)
    ux, uy = math.cos(a), math.sin(a)
    px, py = -uy, ux
    cells = {}
    for t in range(r0, r1):
        w = max(1, round(base_w * (1 - (t - r0) / (r1 - r0))))
        for s in range(-(w // 2), w - w // 2):
            cells[(round(c + ux * t + px * s), round(c + uy * t + py * s))] = (s == -(w // 2) and w > 2)
    for (x, y) in cells:
        for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + ox, y + oy) not in cells:
                cv.put(x + ox, y + oy, BLACK)
    for (x, y), light in cells.items():
        cv.put(x, y, hi if light else fill)


# ----------------------------------------------------------------------------------------------- AVISO
def aviso(k, n, R, estilo="circulo"):
    """Quadro k de n do aviso de uma área circular de raio R (px de arte; o quadro tem 2R x 2R)."""
    cv = Canvas(2 * R, 2 * R)
    c = R
    p = k / float(n - 1)
    col = lit_ring_color(p)
    last = k == n - 1
    # preenchimento que cresce do centro (cor chapada com transparência; a frente do preenchimento é uma linha viva)
    rf = (R - 5) * p
    if rf > 0:
        solid_disc(cv, c, rf, HI if last else RED, 150 if last else 95)
        if not last:
            band(cv, c, rf - 1, rf, HI)
    # anel: contorno preto + 2 px de cor + contorno preto
    band(cv, c, R - 4, R, BLACK)
    band(cv, c, R - 3, R - 1, col)
    band(cv, c, R - 3, R - 2, PINK if last else col)   # realce fino na borda de fora
    # marcas
    mark = DK if p < 0.4 else (RED if p < 0.99 else PINK)
    if estilo == "circulo":
        d = R - 9
        triangle(cv, c, c - d, "N", mark)
        triangle(cv, c, c + d - 1, "S", mark)
        triangle(cv, c - d, c, "W", mark)
        triangle(cv, c + d - 1, c, "E", mark)
    else:   # lâminas em X (golpe de espada)
        bl = WHITE if last else (PINK if p >= 0.6 else (RED if p >= 0.3 else DK))
        for a in (45, 135, 225, 315):
            blade(cv, c, a, 8, R - 7, 8, bl, PINK if p >= 0.3 else RED)
    # miolo
    solid_disc(cv, c, 3, BLACK)
    cv.put(c - 1, c - 1, PINK)
    cv.put(c, c - 1, col)
    cv.put(c - 1, c, col)
    cv.put(c, c, col)
    return cv


# ----------------------------------------------------------------------------------------------- IMPACTO
def impacto(k, R):
    """Quadro k (0..4) do impacto de área circular de raio R."""
    cv = Canvas(2 * R, 2 * R)
    c = R
    if k == 0:
        solid_disc(cv, c, R * 0.58 + 1, BLACK)
        solid_disc(cv, c, R * 0.58, WHITE)
        solid_disc(cv, c - 1, R * 0.36, (255, 226, 226, 255))
    elif k == 1:
        solid_disc(cv, c, R - 1, BLACK)
        solid_disc(cv, c, R - 2, HI)
        solid_disc(cv, c, R * 0.72, RED)
        solid_disc(cv, c - 1, R * 0.52, PINK)
        solid_disc(cv, c - 2, R * 0.28, WHITE)
    elif k == 2:
        band(cv, c, R - 8, R, BLACK)
        band(cv, c, R - 7, R - 1, RED)
        band(cv, c, R - 7, R - 5, HI)
        band(cv, c, R * 0.46, R * 0.46 + 4, BLACK)
        band(cv, c, R * 0.46 + 1, R * 0.46 + 3, PINK)
    elif k == 3:
        band(cv, c, R - 5, R, BLACK)
        band(cv, c, R - 4, R - 1, DK)
        band(cv, c, R - 4, R - 3, RED)
    else:
        for n in range(4):
            a = math.radians(n * 90 + 45)
            x, y = round(c + math.cos(a) * (R - 6)), round(c + math.sin(a) * (R - 6))
            cv.rect(x - 3, y - 3, 6, 6, BLACK)
            cv.rect(x - 2, y - 2, 4, 4, RED)
            cv.put(x - 2, y - 2, PINK)
    return cv


def corte(k, R):
    """Corte do golpe de espada: 4 lâminas em crescente que giram e abrem."""
    cv = Canvas(2 * R, 2 * R)
    c = R
    col = [WHITE, WHITE, PINK, RED][k]
    edge = [PINK, PINK, HI, DK][k]
    r_mid = [R * 0.42, R * 0.62, R * 0.80, R * 0.88][k]
    span = 74
    max_t = [12, 11, 9, 6][k]
    rot = [0, 14, 28, 42][k]
    cells = set()
    for y in range(2 * R):
        for x in range(2 * R):
            dx, dy = x + 0.5 - c, y + 0.5 - c
            d = math.hypot(dx, dy)
            ang = (math.degrees(math.atan2(dy, dx)) - rot + 360) % 360
            for n in range(4):
                t = ((ang - n * 90) % 360) / span
                if 0.0 <= t <= 1.0:
                    half = max_t * 0.5 * math.sin(math.pi * t)
                    if abs(d - (r_mid - 3 * math.sin(math.pi * t))) <= half:
                        cells.add((x, y))
    for (x, y) in cells:
        for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + ox, y + oy) not in cells:
                cv.put(x + ox, y + oy, BLACK)
    for (x, y) in cells:
        inner = all((x + ox, y + oy) in cells for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        cv.put(x, y, col if inner else edge)
    if k == 0:
        solid_disc(cv, c, R * 0.26 + 1, BLACK)
        solid_disc(cv, c, R * 0.26, WHITE)
    return cv


# ----------------------------------------------------------------------------------------------- TIROS
def shot_head(cv, cx, cy, r):
    """Orbe do tiro: camadas concentricas que se deslocam para cima/esquerda (luz de cima-esquerda)."""
    disc(cv, cx, cy, r, DK, BLACK)
    layers = [(r - 1.6, RED, 0.5), (r - 3.4, HI, 1.0), (r - 5.4, PINK, 1.5), (r - 7.4, WHITE, 2.0)]
    for rad, col, sh in layers:
        if rad > 0.6:
            disc(cv, cx - sh, cy - sh, rad, col)


def beam_frame(f):
    """Tiro principal do chefão: cabeça redonda de 22 px apontada para cima e cauda de chama (quadro 64 x 64)."""
    cv = Canvas(64, 64)
    sway = [0, 1, 1, 0, -1, -1, 0, 1][f]
    length = [17, 18, 17, 15, 17, 18, 16, 15][f]
    ax = 29.5
    # cauda: faixa que afina, com 3 camadas e contorno
    cells = {}
    for j in range(length):
        t = j / float(length)
        w = max(1, round(5.5 * (1 - t) ** 1.15))        # cauda mais fina que a cabeça (cometa)
        off = round(sway * math.sin(t * math.pi))
        for dx in range(-w, w + 1):
            x = 29 + dx + off                      # eixo no centro do pixel 29 (= 29,5 em coordenadas contínuas)
            level = 0 if abs(dx) > w - 2 else (1 if abs(dx) > w - 4 else 2)
            cells[(x, 46 + j)] = level
    for (x, y) in cells:
        for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + ox, y + oy) not in cells:
                cv.put(x + ox, y + oy, BLACK)
    for (x, y), level in cells.items():
        cv.put(x, y, [DK, RED, HI][level])
    shot_head(cv, 29.5, 37.5, 9.5)
    return cv


def orb_frame(f):
    """Orbe pequeno (tiros que se dividem): 15 px, centro no pixel (28, 36) do quadro 64 x 64 (ORB_OFFSET do guide_shot.gd)."""
    cv = Canvas(64, 64)
    r = [6.5, 6.5, 6.5, 6.3][f]
    shot_head(cv, 28.5, 36.5, r)
    return cv
