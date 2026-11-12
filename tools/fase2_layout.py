"""Layout da Fase 2 (labirinto) -- FONTE ÚNICA da geometria.

Este arquivo é a planta DESENHADA À MÃO do labirinto: lista quais corredores existem e onde ficam
chave, porta, fogo, painéis, drones etc. Nada aqui roda no jogo. Os scripts de /tools leem esta planta
para (1) pintar a arte em pixel art, (2) escrever os nós de colisão / oclusores no .tscn e (3) validar.
Assim a arte e as colisões nunca ficam desalinhadas.

Unidades: pixels de mundo do Godot. A arte é pintada na METADE da resolução (1 pixel de arte = 2 px de
tela) e os Sprite2D usam escala 2 (fator inteiro) com filtro Nearest.
"""

# ----------------------------------------------------------------------------------------------
# Medidas
# ----------------------------------------------------------------------------------------------
CELL = 96            # largura do corredor (cabe a cápsula do Player: 28 x 56; no celular 42 x 84)
WALL = 16            # espessura da parede
PITCH = CELL + WALL  # 112: distância entre centros de células vizinhas
COLS, ROWS = 10, 7
UNIT = 16            # unidade da grade de paredes (px)
ART = 2              # px de tela por pixel de arte

GRID_W = COLS * PITCH + WALL   # 1136
GRID_H = ROWS * PITCH + WALL   # 800

# Vestíbulo atrás da porta (leste da célula 9,0)
VEST = (GRID_W, WALL, CELL, CELL)        # x, y, w, h = 1136, 16, 96, 96
CANVAS_W = GRID_W + CELL + WALL          # 1248 (vestíbulo + parede leste)
CANVAS_H = GRID_H                        # 800

# ----------------------------------------------------------------------------------------------
# Passagens abertas entre células vizinhas (desenhadas à mão).  "c,r c2,r2"
# ----------------------------------------------------------------------------------------------
PASSAGES_TXT = """
0,6 1,6
1,6 2,6
2,6 3,6
3,6 4,6
5,6 6,6
6,6 7,6
7,6 8,6
8,6 9,6
0,6 0,5
0,5 0,4
0,4 1,4
1,4 1,3
1,3 2,3
2,3 3,3
3,3 3,4
2,4 2,5
2,5 1,5
3,5 4,5
4,5 5,5
5,5 5,6
5,5 5,4
5,4 5,3
5,3 6,3
6,3 7,3
7,3 8,3
8,3 8,4
8,4 9,4
8,4 8,5
8,5 7,5
7,5 7,6
1,3 1,2
1,2 0,2
1,2 2,2
0,2 0,1
0,1 0,0
0,0 1,0
2,2 2,1
2,1 1,1
2,1 2,0
3,2 3,1
3,2 4,2
3,1 3,0
3,0 4,0
4,0 5,0
5,0 5,1
5,1 4,1
4,1 4,2
5,2 6,2
5,3 5,2
6,2 6,1
6,1 6,0
6,0 7,0
7,0 8,0
8,0 9,0
7,1 8,1
8,1 8,2
8,2 9,2
8,2 8,3
7,1 7,0
6,4 7,4
7,4 7,3
6,4 6,5
6,5 6,6
4,3 4,4
4,4 3,4
4,3 5,3
4,2 4,3
9,4 9,3
9,3 9,2
0,3 0,4
7,2 7,1
9,5 9,4
1,4 2,4
9,2 9,1
"""


def _parse_passages():
    edges = set()
    for line in PASSAGES_TXT.strip().splitlines():
        a, b = line.split()
        pa = tuple(int(v) for v in a.split(","))
        pb = tuple(int(v) for v in b.split(","))
        edges.add(frozenset((pa, pb)))
    return edges


PASSAGES = _parse_passages()


def is_open(a, b):
    return frozenset((a, b)) in PASSAGES


# ----------------------------------------------------------------------------------------------
# Geometria de células
# ----------------------------------------------------------------------------------------------
def cell_rect(c, r):
    return (WALL + PITCH * c, WALL + PITCH * r, CELL, CELL)


def cell_center(c, r):
    x, y, w, h = cell_rect(c, r)
    return (x + w // 2, y + h // 2)


# ----------------------------------------------------------------------------------------------
# Marcos do jogo
# ----------------------------------------------------------------------------------------------
START_CELL = (0, 6)
KEY_CELL = (9, 6)
DOOR_RECT = (GRID_W - WALL, WALL, WALL, CELL)     # vão na parede leste da linha 0
EXIT_RECT = (GRID_W + 48, WALL, 48, CELL)         # gatilho no fundo do vestíbulo

# Fogo: passagens que exigem DASH. (a, b) = células ligadas pela passagem.
FIRE_PASSAGES = {
    "Fogo1": ((8, 6), (9, 6)),   # protege a chave
    "Fogo2": ((8, 0), (9, 0)),   # protege a porta
    "Fogo3": ((7, 1), (7, 2)),   # protege o painel do círculo
}
FIRE_LEN = 32          # comprimento do trecho de fogo ao longo do corredor (px)


def fire_rect(a, b):
    """Retângulo (x, y, w, h) do trecho de fogo centrado no vão da parede entre a e b."""
    (c1, r1), (c2, r2) = a, b
    if r1 == r2:   # corredor horizontal: faixa em pé (32 x 96)
        gap_x = PITCH * (min(c1, c2) + 1)
        return (gap_x - (FIRE_LEN - WALL) // 2, WALL + PITCH * r1, FIRE_LEN, CELL), "h"
    gap_y = PITCH * (min(r1, r2) + 1)           # corredor vertical: faixa deitada (96 x 32)
    return (WALL + PITCH * c1, gap_y - (FIRE_LEN - WALL) // 2, CELL, FIRE_LEN), "v"


# Puzzle: 3 painéis (glifo 0 = triângulo, 1 = quadrado, 2 = círculo)
PANELS = {
    "PainelTriangulo": {"cell": (2, 0), "glyph": 0},
    "PainelQuadrado":  {"cell": (3, 5), "glyph": 1},
    "PainelCirculo":   {"cell": (7, 2), "glyph": 2},
}
SOLUTION = [1, 2, 0]        # quadrado -> círculo -> triângulo (a dica no chão mostra esta ordem)
HINT_CELL = (1, 5)

# Drones: rota = pontos (px). O drone nasce no primeiro ponto do meio.
DRONES = {
    "Drone1": {"spawn": cell_center(6, 3), "route": [cell_center(5, 3), cell_center(8, 3)]},  # corredor leste
    "Drone2": {"spawn": cell_center(1, 2), "route": [cell_center(0, 2), cell_center(2, 2)]},  # corredor noroeste
    "Drone3": {"spawn": cell_center(6, 6), "route": [cell_center(5, 6), cell_center(7, 6)]},  # acesso à chave
}


# ----------------------------------------------------------------------------------------------
# Máscara de paredes (grade de 16 px) -> retângulos de colisão / oclusor
# ----------------------------------------------------------------------------------------------
UW = CANVAS_W // UNIT   # 78
UH = CANVAS_H // UNIT   # 50


def build_masks():
    """Devolve (solid, floor): matrizes [uy][ux] de bool na grade de 16 px."""
    solid = [[False] * UW for _ in range(UH)]
    floor = [[False] * UW for _ in range(UH)]
    step = CELL // UNIT + 1   # 7 unidades por célula (1 parede + 6 piso)
    for uy in range(0, GRID_H // UNIT):
        for ux in range(0, GRID_W // UNIT):
            lx, ly = ux % step, uy % step
            gx, gy = ux // step, uy // step
            if lx == 0 and ly == 0:
                solid[uy][ux] = True
            elif lx == 0:      # coluna de parede entre (gx-1, gy-1?) -> linha de células = gy
                r = gy
                if gx == 0 or gx == COLS:
                    if gx == COLS and r == 0:
                        floor[uy][ux] = True       # vão da porta (a Porta tem o próprio corpo)
                    else:
                        solid[uy][ux] = True
                elif is_open((gx - 1, r), (gx, r)):
                    floor[uy][ux] = True
                else:
                    solid[uy][ux] = True
            elif ly == 0:
                c = gx
                if gy == 0 or gy == ROWS:
                    solid[uy][ux] = True
                elif is_open((c, gy - 1), (c, gy)):
                    floor[uy][ux] = True
                else:
                    solid[uy][ux] = True
            else:
                floor[uy][ux] = True
    # vestíbulo
    vx0, vy0 = VEST[0] // UNIT, VEST[1] // UNIT
    for uy in range(0, 8):
        for ux in range(GRID_W // UNIT, UW):
            inner = (vx0 <= ux < vx0 + CELL // UNIT) and (vy0 <= uy < vy0 + CELL // UNIT)
            if inner:
                floor[uy][ux] = True
            else:
                solid[uy][ux] = True
    return solid, floor


def wall_rects(solid=None):
    """Mescla as unidades sólidas em retângulos (x, y, w, h) em px (guloso, por linhas)."""
    if solid is None:
        solid, _ = build_masks()
    uh, uw = len(solid), len(solid[0])
    used = [[False] * uw for _ in range(uh)]
    rects = []
    for uy in range(uh):
        for ux in range(uw):
            if not solid[uy][ux] or used[uy][ux]:
                continue
            w = 1
            while ux + w < uw and solid[uy][ux + w] and not used[uy][ux + w]:
                w += 1
            h = 1
            while uy + h < uh and all(solid[uy + h][ux + i] and not used[uy + h][ux + i] for i in range(w)):
                h += 1
            for yy in range(uy, uy + h):
                for xx in range(ux, ux + w):
                    used[yy][xx] = True
            rects.append((ux * UNIT, uy * UNIT, w * UNIT, h * UNIT))
    return rects


# ----------------------------------------------------------------------------------------------
# Grafo para validação
# ----------------------------------------------------------------------------------------------
def adjacency(include_fire=False):
    fire_edges = {frozenset(v) for v in FIRE_PASSAGES.values()}
    adj = {}
    for e in PASSAGES:
        if not include_fire and e in fire_edges:
            continue
        a, b = tuple(e)
        adj.setdefault(a, set()).add(b)
        adj.setdefault(b, set()).add(a)
    return adj


def bfs(start, adj):
    from collections import deque
    dist = {start: 0}
    q = deque([start])
    while q:
        u = q.popleft()
        for v in adj.get(u, ()):
            if v not in dist:
                dist[v] = dist[u] + 1
                q.append(v)
    return dist


if __name__ == "__main__":
    s, f = build_masks()
    rows = []
    for uy in range(UH):
        rows.append("".join("#" if s[uy][ux] else ("." if f[uy][ux] else " ") for ux in range(UW)))
    print("\n".join(rows))
    print(len(wall_rects(s)), "retângulos de parede")
