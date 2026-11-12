#!/usr/bin/env python3
"""Simula a IA dos drones do labirinto (a MESMA lógica de maze_graph.gd + drone_maze_chase_state.gd +
drone_route_patrol_state.gd) contra as paredes reais da planta, para provar que o drone não trava.

Uso (na raiz do projeto):   python tools/simular_drones_fase2.py

O que é simulado: corpo circular de 8,3 px de raio (o do DroneEnemy), velocidade de 170 px/s (perseguição)
e 59,5 px/s (patrulha), 60 quadros/s, colisão com deslizamento (como move_and_slide). Perseguição:
  - linha de visão livre (3 raios, folga de 10 px) -> vai reto ao jogador (o original, com desvio por raycast);
  - parede no meio -> vai de centro de célula em centro de célula pelo caminho dos corredores.
Não simula o raycast de desvio do Godot (ObstacleSteering): o teste prova que, seguindo os pontos que o
MazeGraph entrega, o corpo nunca precisa de desvio nenhum.
"""
import math
import os
import random
import sys
from collections import deque

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fase2_layout as L  # noqa: E402

RADIUS = 8.32
DT = 1.0 / 60.0
CHASE_SPEED = 170.0
PATROL_SPEED = 170.0 * 0.35
CLEARANCE = 10.0
WALLS = [tuple(map(float, r)) for r in L.wall_rects()]
WALLS.append(tuple(map(float, L.DOOR_RECT)))   # porta fechada


# ---------------------------------------------------------------- geometria
def circle_hits(px, py, r=RADIUS):
    for (x, y, w, h) in WALLS:
        cx = min(max(px, x), x + w)
        cy = min(max(py, y), y + h)
        if (px - cx) ** 2 + (py - cy) ** 2 < r * r:
            return True
    return False


def seg_hits_rect(ax, ay, bx, by, rect):
    x, y, w, h = rect
    t0, t1 = 0.0, 1.0
    dx, dy = bx - ax, by - ay
    for p, q in ((-dx, ax - x), (dx, x + w - ax), (-dy, ay - y), (dy, y + h - ay)):
        if p == 0:
            if q < 0:
                return False
        else:
            t = q / p
            if p < 0:
                if t > t1:
                    return False
                t0 = max(t0, t)
            else:
                if t < t0:
                    return False
                t1 = min(t1, t)
    return t0 <= t1


def clear_line(a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    d = math.hypot(dx, dy) or 1.0
    ox, oy = -dy / d * CLEARANCE, dx / d * CLEARANCE
    for k in (0, 1, -1):
        for rect in WALLS:
            if seg_hits_rect(a[0] + ox * k, a[1] + oy * k, b[0] + ox * k, b[1] + oy * k, rect):
                return False
    return True


# ---------------------------------------------------------------- MazeGraph (igual ao .gd)
NEIGH = {}
for e in L.PASSAGES:
    (c1, r1), (c2, r2) = tuple(e)
    a, b = r1 * L.COLS + c1, r2 * L.COLS + c2
    NEIGH.setdefault(a, []).append(b)
    NEIGH.setdefault(b, []).append(a)
_DIST = {}


def cell_index(p):
    c = min(max(int((p[0] - L.WALL) // L.PITCH), 0), L.COLS - 1)
    r = min(max(int((p[1] - L.WALL) // L.PITCH), 0), L.ROWS - 1)
    return r * L.COLS + c


def cell_center(i):
    return (L.WALL + (i % L.COLS) * L.PITCH + L.CELL / 2, L.WALL + (i // L.COLS) * L.PITCH + L.CELL / 2)


def dist_to(t):
    if t not in _DIST:
        d = {t: 0}
        q = deque([t])
        while q:
            u = q.popleft()
            for v in NEIGH.get(u, ()):
                if v not in d:
                    d[v] = d[u] + 1
                    q.append(v)
        _DIST[t] = d
    return _DIST[t]


def next_step(frm, to):
    a, b = cell_index(frm), cell_index(to)
    if a == b:
        return to
    d = dist_to(b)
    best = a
    for n in NEIGH[a]:
        if d[n] < d[best]:
            best = n
    return to if best == a else cell_center(best)


# ---------------------------------------------------------------- movimento com deslizamento
def move(pos, target, speed):
    dx, dy = target[0] - pos[0], target[1] - pos[1]
    d = math.hypot(dx, dy)
    if d < 1e-6:
        return pos, False
    step = min(speed * DT, d)
    vx, vy = dx / d * step, dy / d * step
    for mx, my in ((vx, vy), (vx, 0.0), (0.0, vy)):
        if (mx or my) and not circle_hits(pos[0] + mx, pos[1] + my):
            return (pos[0] + mx, pos[1] + my), False
    return pos, True   # bloqueado


def random_free(rng):
    while True:
        c, r = rng.randrange(L.COLS), rng.randrange(L.ROWS)
        x0, y0, w, h = L.cell_rect(c, r)
        p = (rng.uniform(x0 + 14, x0 + w - 14), rng.uniform(y0 + 14, y0 + h - 14))
        if not circle_hits(*p):
            return p


def simulate(seed=7, n_chase=3000, n_patrol=600):
    rng = random.Random(seed)
    fails = []
    worst = 0
    blocked_total = 0
    # --- perseguição (jogador parado em qualquer ponto; o drone parte de qualquer ponto)
    for i in range(n_chase):
        drone, player = random_free(rng), random_free(rng)
        stuck_frames, longest = 0, 0
        reached = False
        for f in range(6000):
            if math.hypot(drone[0] - player[0], drone[1] - player[1]) < 30:
                reached = True
                worst = max(worst, f)
                break
            goal = player if clear_line(drone, player) else next_step(drone, player)
            drone, blocked = move(drone, goal, CHASE_SPEED)
            stuck_frames = stuck_frames + 1 if blocked else 0
            longest = max(longest, stuck_frames)
            blocked_total += blocked
        if not reached or longest > 3:
            fails.append(("perseguição", i, drone, player, longest))
    # --- patrulha: de qualquer ponto até o ponto de rota mais próximo e depois ida e volta
    for i in range(n_patrol):
        name = rng.choice(list(L.DRONES))
        pts = L.DRONES[name]["route"]
        drone = random_free(rng)
        idx = min(range(len(pts)), key=lambda k: len(dist_path(drone, pts[k])))
        legs, frames = 0, 0
        stuck_frames, longest = 0, 0
        while legs < 4 and frames < 40000:
            dest = pts[idx]
            if math.hypot(drone[0] - dest[0], drone[1] - dest[1]) <= 8:
                legs += 1
                idx = (idx + 1) % len(pts)
                continue
            drone, blocked = move(drone, next_step(drone, dest), PATROL_SPEED)
            stuck_frames = stuck_frames + 1 if blocked else 0
            longest = max(longest, stuck_frames)
            blocked_total += blocked
            frames += 1
        if legs < 4 or longest > 3:
            fails.append(("patrulha", i, drone, name, longest))
    return fails, worst, blocked_total


def dist_path(frm, to):
    a, b = cell_index(frm), cell_index(to)
    return [0] * dist_to(b).get(a, 10 ** 6)


def main():
    fails, worst, blocked = simulate()
    print(f"perseguição: 3000 pares aleatórios drone/jogador; pior caso {worst} quadros ({worst / 60:.1f} s)")
    print("patrulha: 600 partidas aleatórias, 4 trechos de rota cada")
    print(f"quadros com o corpo bloqueado por parede: {blocked}")
    if fails:
        print("FALHAS:", len(fails))
        for f in fails[:8]:
            print("  ", f)
        return 1
    print("OK: nenhum drone travou.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
