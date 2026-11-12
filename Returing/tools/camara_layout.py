"""Planta da CÂMARA DE PROVAS (fase "Linha de Tiro") -- FONTE ÚNICA da geometria e dos tempos.

Este arquivo é a planta DESENHADA À MÃO da fase: salas, corredores, portas, máquinas, faixas, ordem de
disparo. Nada aqui roda no jogo. Os scripts de /tools leem esta planta para (1) pintar a arte em pixel art,
(2) escrever os nós estáticos no .tscn e (3) validar com número (cronograma, dash, linha de tiro).

Unidades: pixels de mundo do Godot (y cresce para baixo). A arte é pintada na METADE da resolução
(1 pixel de arte = 2 px de tela) e os Sprite2D usam escala 2 com filtro Nearest.

COMO OS RAIOS FUNCIONAM (o mesmo modelo no jogo e na validação)
  * Cada máquina tem uma FAIXA do piso. O raio é uma LINHA de 10 px de espessura e comprimento igual à
    largura da faixa. Ela nasce na parede da máquina e VARRE a faixa em linha reta, até a parede oposta.
  * Ciclo de uma máquina: AVISO (1,0 s, a máquina pisca e a faixa mostra tracejado) -> CLARÃO (0,4 s,
    clarão na boca) -> VARREDURA (2,0 s, a linha anda e fere) -> PAUSA (1,6 s). Total de 5,0 s.
  * O jogador só escapa de uma linha com o DASH (invulnerável) e só para uma máquina com o TIRO CARREGADO.
"""
# ----------------------------------------------------------------------------------------------
# Medidas gerais
# ----------------------------------------------------------------------------------------------
WALL = 16           # espessura da parede
ART = 2             # px de tela por pixel de arte
CELL = 96           # largura de corredor/passagem (cápsula do Player 28 x 56; no celular 42 x 84)
BEAM_T = 10         # espessura do raio = espessura da hitbox
MACH = 48           # lado da máquina em px de tela (24 x 24 px de arte)
MACH_DEPTH_WALL = 16   # parte da máquina que fica dentro da parede
MACH_SOLID = 16        # parte sólida (camada 1) logo à frente da parede
MACH_FRONT = 16        # parte da frente: só hurtbox (o tiro acerta aqui antes de bater no sólido)

# Jogador (do projeto)
CAP_W, CAP_H = 28.0, 56.0
HURT_R = 12.341887   # raio real da Hurtbox do Player (menor que a cápsula: a validação usa a cápsula)
WALK = 300.0
DASH_SPEED, DASH_DUR, DASH_CD, IFRAMES = 560.0, 0.30, 1.0, 0.34
DASH_DIST = DASH_SPEED * DASH_DUR          # 168 px
CHARGE_TIME, CHARGE_MOVE = 1.2, 0.4
DANO_BASE, DANO_MAX = 10, 68
SHOT_SPEED, SHOT_LIFE = 300.0, 2.0         # PlayerProjectile.tscn
SHOT_RANGE = SHOT_SPEED * SHOT_LIFE        # 600 px
MUZZLE = 22.776453                         # ProjectileSpawn.x
DANO_MINIMO = 40                           # só aceita dano >= 40
CARGA_MINIMA = (DANO_MINIMO - DANO_BASE) / float(DANO_MAX - DANO_BASE)   # 0,517 -> 52 %

# Ciclo da máquina (segundos)
T_AVISO, T_CLARAO, T_VARREDURA, T_PAUSA = 1.0, 0.4, 2.0, 1.6
T_CICLO = T_AVISO + T_CLARAO + T_VARREDURA + T_PAUSA   # 5,0 s
MIN_GAP = 2.6          # chegadas consecutivas de raios no mesmo ponto
MIN_JANELA_CARGA = 1.4  # janela livre para carregar o tiro

# ----------------------------------------------------------------------------------------------
# Pisos (retângulos x, y, w, h). As paredes são o contorno de 16 px ao redor da união dos pisos.
# ----------------------------------------------------------------------------------------------
R1 = (16, 16, 720, 96)        # Sala 1 "Passagem": corredor
P1 = (624, 112, 96, 192)      # passagem que desce da Sala 1 para a Sala 2
R2 = (224, 304, 516, 288)     # Sala 2 "Calibração"
P2 = (740, 400, 176, 96)      # passagem para a Sala 3
R3 = (916, 212, 1032, 472)    # Sala 3 "Câmara Principal" (piso de 1032 x 472)
P3 = (1948, 400, 208, 96)     # vestíbulo depois da porta final
FLOORS = {"R1": R1, "P1": P1, "R2": R2, "P2": P2, "R3": R3, "P3": P3}

WORLD_W = P3[0] + P3[2] + WALL     # 2172
WORLD_H = R3[1] + R3[3] + WALL     # 700

START = (96, 64)              # plataforma de início (Sala 1)
FOGO = (368, 16, 32, 96)      # trecho de fogo da Sala 1 (x, y, w, h), 32 x 96 em pé

# Portas: centro, orientação do vão e rótulo. "v" = porta em pé (vão de 16 x 96 numa parede vertical),
# "h" = deitada (96 x 16 numa parede horizontal).
PORTAS = {
    "Porta1": {"c": (672, 208), "o": "h", "aberta": True, "contador": 0},     # Sala 1 -> Sala 2
    "Porta2": {"c": (828, 448), "o": "v", "aberta": False, "contador": 1},    # Sala 2 -> Sala 3
    "PortaFinal": {"c": (2004, 448), "o": "v", "aberta": False, "contador": 10},   # Sala 3 -> quiz
}
ENTRADAS = {   # gatilhos que ligam o cronograma da sala (x, y, w, h)
    "EntradaSala1": (16, 16, 160, 96),
    "EntradaSala2": (624, 312, 96, 48),
    "EntradaSala3": (924, 400, 48, 96),
}
SAIDA = (2084, 400, 64, 96)   # gatilho no fundo do vestíbulo (leva ao quiz)

# ----------------------------------------------------------------------------------------------
# Máquinas.  boca: "baixo" (parede de cima), "cima" (parede de baixo), "direita" (parede esquerda),
# "esquerda" (parede direita).  Cada uma varre a faixa `faixa` (x, y, w, h) na direção da boca.
# ----------------------------------------------------------------------------------------------
DIR = {"baixo": (0, 1), "cima": (0, -1), "direita": (1, 0), "esquerda": (-1, 0)}


def _faixa_v(room, x0, w):
    _, y, _, h = room
    return (x0, y, w, h)


def _maquina(sala, boca, c, faixa, destrutivel=True, reforcada=False):
    """c = coordenada da máquina ao longo da parede (x nas paredes de cima/baixo, y nas laterais)."""
    return {"sala": sala, "boca": boca, "c": c, "faixa": faixa, "destrutivel": destrutivel, "reforcada": reforcada}


_W3 = R3[2] // 6          # 172: largura de cada faixa vertical da Sala 3
_X3 = R3[0]
_YM = R3[1] + R3[3] // 2  # 448: meio da sala (divide as bandas laterais)
_XM = R3[0] + R3[2] // 2  # 1432: meio da sala
_HB = R3[3] // 2          # 236: altura de cada banda lateral

MAQUINAS = {
    # --- Sala 1: duas máquinas indestrutíveis (só decoração) nas pontas do corredor
    "M1A": _maquina(1, "direita", 64, R1, destrutivel=False),
    "M1B": _maquina(1, "esquerda", 64, R1, destrutivel=False),
    # --- Sala 2: uma máquina destrutível no meio da parede de cima
    "M2": _maquina(2, "baixo", R2[0] + R2[2] // 2, R2),
    # --- Sala 3: 10 máquinas (6 em cima/baixo, 4 nas laterais), faixas marcadas no chão
    "T0": _maquina(3, "baixo", _X3 + _W3 * 0 + _W3 // 2, (_X3 + _W3 * 0, R3[1], _W3, R3[3])),
    "B1": _maquina(3, "cima", _X3 + _W3 * 1 + _W3 // 2, (_X3 + _W3 * 1, R3[1], _W3, R3[3])),
    "T2": _maquina(3, "baixo", _X3 + _W3 * 2 + _W3 // 2, (_X3 + _W3 * 2, R3[1], _W3, R3[3])),
    "B3": _maquina(3, "cima", _X3 + _W3 * 3 + _W3 // 2, (_X3 + _W3 * 3, R3[1], _W3, R3[3]), reforcada=True),
    "T4": _maquina(3, "baixo", _X3 + _W3 * 4 + _W3 // 2, (_X3 + _W3 * 4, R3[1], _W3, R3[3])),
    "B5": _maquina(3, "cima", _X3 + _W3 * 5 + _W3 // 2, (_X3 + _W3 * 5, R3[1], _W3, R3[3])),
    "LU": _maquina(3, "direita", R3[1] + _HB // 2, (_X3, R3[1], R3[2] // 2, _HB)),
    "LL": _maquina(3, "direita", _YM + _HB // 2, (_X3, _YM, R3[2] // 2, _HB), reforcada=True),
    "RU": _maquina(3, "esquerda", R3[1] + _HB // 2, (_XM, R3[1], R3[2] // 2, _HB)),
    "RL": _maquina(3, "esquerda", _YM + _HB // 2, (_XM, _YM, R3[2] // 2, _HB)),
}

# Ordem FIXA de disparo da Sala 3 (índice = vaga no ciclo). Escolhida com tools/camara_cronograma.py:
# máquinas cujas faixas se cruzam ficam em vagas distantes no ciclo.
ORDEM_SALA3 = ["T0", "RL", "B1", "B3", "LL", "T4", "LU", "B5", "T2", "RU"]
# Intervalo entre disparos de cada sala. Sala 3: 2,4 s (o mínimo que cumpre a folga de 2,6 s com a ordem acima
# é ~2,35 s; ver tools/camara_cronograma.py e tools/validar_camara.py).
INTERVALO_SALA3 = 2.4
INTERVALO_SALA1 = 5.0      # 2 máquinas -> ciclo de 10 s
INTERVALO_SALA2 = 5.0      # 1 máquina  -> ciclo de 5 s
ORDEM_SALA1 = ["M1A", "M1B"]
ORDEM_SALA2 = ["M2"]
ATRASO_INICIAL = {1: 3.0, 2: 3.0, 3: 3.5}   # segundos entre entrar na sala e o 1º aviso


def piso_da_maquina(m):
    """Retângulo do piso da sala da máquina."""
    return {1: R1, 2: R2, 3: R3}[MAQUINAS[m]["sala"]]


def geometria(nome):
    """Tudo que o jogo e a validação precisam saber de uma máquina, derivado da planta."""
    m = MAQUINAS[nome]
    fl, ft, fw, fh = piso_da_maquina(nome)
    fr, fb = fl + fw, ft + fh
    boca, c = m["boca"], m["c"]
    h = MACH // 2
    if boca == "baixo":
        centro = (c, ft + 8)                 # centro da sprite de 48 x 48 (16 dentro da parede, 32 no piso)
        sol = (c - h, ft, MACH, MACH_SOLID)
        hurt = (c - h + 2, ft + 10, MACH - 4, MACH_SOLID + MACH_FRONT - 10)
        alvo = (c, ft + MACH_SOLID + MACH_FRONT)   # ponto da frente onde se mira
    elif boca == "cima":
        centro = (c, fb - 8)
        sol = (c - h, fb - MACH_SOLID, MACH, MACH_SOLID)
        hurt = (c - h + 2, fb - MACH_SOLID - MACH_FRONT, MACH - 4, MACH_SOLID + MACH_FRONT - 10)
        alvo = (c, fb - MACH_SOLID - MACH_FRONT)
    elif boca == "direita":
        centro = (fl + 8, c)
        sol = (fl, c - h, MACH_SOLID, MACH)
        hurt = (fl + 10, c - h + 2, MACH_SOLID + MACH_FRONT - 10, MACH - 4)
        alvo = (fl + MACH_SOLID + MACH_FRONT, c)
    else:  # esquerda
        centro = (fr - 8, c)
        sol = (fr - MACH_SOLID, c - h, MACH_SOLID, MACH)
        hurt = (fr - MACH_SOLID - MACH_FRONT, c - h + 2, MACH_SOLID + MACH_FRONT - 10, MACH - 4)
        alvo = (fr - MACH_SOLID - MACH_FRONT, c)
    fx, fy, fw2, fh2 = m["faixa"]
    dx, dy = DIR[boca]
    if dx == 0:   # linha horizontal que anda em y (máquinas de cima/baixo): varre a altura da faixa
        comprimento = fw2
        inicio = ft if dy > 0 else fb               # coordenada y de partida (borda do piso)
        distancia = fh2
        linha_centro_perp = fx + fw2 / 2.0
    else:         # linha vertical que anda em x (laterais): varre a largura da faixa
        comprimento = fh2
        inicio = fl if dx > 0 else fr               # coordenada x de partida (borda do piso)
        distancia = fw2
        linha_centro_perp = fy + fh2 / 2.0
    return {"nome": nome, "boca": boca, "dir": (dx, dy), "centro": centro, "solido": sol, "hurt": hurt,
            "alvo": alvo, "faixa": m["faixa"], "comprimento": comprimento, "inicio": inicio,
            "distancia": distancia, "perp": linha_centro_perp, "velocidade": distancia / T_VARREDURA,
            "destrutivel": m["destrutivel"], "reforcada": m["reforcada"], "sala": m["sala"]}


# ----------------------------------------------------------------------------------------------
# Paredes: contorno de 16 px ao redor dos pisos, mesclado em retângulos (grade de 2 px = 1 px de arte)
# ----------------------------------------------------------------------------------------------
GRID = 2   # px por célula da máscara (1 px de arte)


def build_masks():
    """Devolve (floor, solid): matrizes [gy][gx] de bytearray (0/1) na grade de 2 px. Sem numpy."""
    gw, gh = WORLD_W // GRID, WORLD_H // GRID
    floor = [bytearray(gw) for _ in range(gh)]
    solid = [bytearray(gw) for _ in range(gh)]
    for (x, y, w, h) in FLOORS.values():
        for gy in range(y // GRID, (y + h) // GRID):
            row = floor[gy]
            for gx in range(x // GRID, (x + w) // GRID):
                row[gx] = 1
    # parede = tudo a até 16 px (dilatação quadrada, cantos preenchidos) de algum piso e que não seja piso
    for (x, y, w, h) in FLOORS.values():
        g0x, g1x = max((x - WALL) // GRID, 0), min((x + w + WALL) // GRID, gw)
        g0y, g1y = max((y - WALL) // GRID, 0), min((y + h + WALL) // GRID, gh)
        for gy in range(g0y, g1y):
            srow, frow = solid[gy], floor[gy]
            for gx in range(g0x, g1x):
                if not frow[gx]:
                    srow[gx] = 1
    return floor, solid


def merge_rects(mask):
    """Mescla células marcadas em retângulos (x, y, w, h) em px. Guloso, por linhas."""
    gh, gw = len(mask), len(mask[0])
    used = [bytearray(gw) for _ in range(gh)]
    rects = []
    for gy in range(gh):
        gx = 0
        while gx < gw:
            if not mask[gy][gx] or used[gy][gx]:
                gx += 1
                continue
            w = 1
            while gx + w < gw and mask[gy][gx + w] and not used[gy][gx + w]:
                w += 1
            h = 1
            while gy + h < gh and all(mask[gy + h][gx + i] and not used[gy + h][gx + i] for i in range(w)):
                h += 1
            for yy in range(gy, gy + h):
                for xx in range(gx, gx + w):
                    used[yy][xx] = 1
            rects.append((gx * GRID, gy * GRID, w * GRID, h * GRID))
            gx += w
    return rects


def wall_rects():
    _, solid = build_masks()
    return merge_rects(solid)


def solid_rects_all():
    """Todos os sólidos (camada 1): paredes + reforço das máquinas + portas fechadas ficam à parte."""
    rects = list(wall_rects())
    for n in MAQUINAS:
        rects.append(geometria(n)["solido"])
    return rects


def door_blocker(nome):
    """Retângulo (x, y, w, h) que a porta fechada ocupa."""
    p = PORTAS[nome]
    cx, cy = p["c"]
    if p["o"] == "v":
        return (cx - WALL // 2, cy - CELL // 2, WALL, CELL)
    return (cx - CELL // 2, cy - WALL // 2, CELL, WALL)


# ----------------------------------------------------------------------------------------------
# Modelo do raio (igual ao do jogo)
# ----------------------------------------------------------------------------------------------
def tempo_ate_varredura():
    return T_AVISO + T_CLARAO


def intervalo_de(sala):
    return {1: INTERVALO_SALA1, 2: INTERVALO_SALA2, 3: INTERVALO_SALA3}[sala]


def ordem_de(sala):
    return {1: ORDEM_SALA1, 2: ORDEM_SALA2, 3: ORDEM_SALA3}[sala]


def disparos(sala, intervalo=None, ordem=None, atraso=0.0):
    """Cronograma fixo: nome -> tempo do início do AVISO dentro do ciclo, e o período do ciclo."""
    intervalo = intervalo_de(sala) if intervalo is None else intervalo
    ordem = ordem_de(sala) if ordem is None else ordem
    return {n: atraso + i * intervalo for i, n in enumerate(ordem)}, intervalo * len(ordem)


def intervalo_de_contato(g, px, py, cap_w=CAP_W, cap_h=CAP_H):
    """Para um ponto (px, py) (centro da cápsula parada): (tau_in, tau_out) em segundos desde o INÍCIO da
    varredura em que a linha toca a cápsula, ou None se a linha nunca a alcança."""
    dx, dy = g["dir"]
    fx, fy, fw, fh = g["faixa"]
    v = g["velocidade"]
    T = T_VARREDURA
    if dx == 0:   # linha horizontal que anda em y
        if not (fx - cap_w / 2 <= px <= fx + fw + cap_w / 2):
            return None
        hm = cap_h / 2 + BEAM_T / 2
        a_p = py
        a0 = g["inicio"]
        s = dy
    else:         # linha vertical que anda em x
        if not (fy - cap_h / 2 <= py <= fy + fh + cap_h / 2):
            return None
        hm = cap_w / 2 + BEAM_T / 2
        a_p = px
        a0 = g["inicio"]
        s = dx
    if s > 0:
        t0, t1 = (a_p - hm - a0) / v, (a_p + hm - a0) / v
    else:
        t0, t1 = (a0 - a_p - hm) / v, (a0 - a_p + hm) / v
    t0, t1 = max(t0, 0.0), min(t1, T)
    if t1 < t0:
        return None
    return (t0, t1)


def posicao_da_linha(g, tau):
    """Retângulo (x, y, w, h) da linha `tau` segundos depois do início da varredura."""
    dx, dy = g["dir"]
    fx, fy, fw, fh = g["faixa"]
    v = g["velocidade"]
    tau = min(max(tau, 0.0), T_VARREDURA)
    if dx == 0:
        y = g["inicio"] + dy * v * tau
        return (fx, y - BEAM_T / 2, fw, BEAM_T)
    x = g["inicio"] + dx * v * tau
    return (x - BEAM_T / 2, fy, BEAM_T, fh)


if __name__ == "__main__":
    f, s = build_masks()
    print(len(wall_rects()), "retângulos de parede;", "mundo", WORLD_W, "x", WORLD_H)
    for n in MAQUINAS:
        g = geometria(n)
        print(n, g["boca"], "centro", g["centro"], "compr", g["comprimento"], "dist", g["distancia"],
              "vel %.1f" % g["velocidade"])
