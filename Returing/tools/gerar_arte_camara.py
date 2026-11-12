#!/usr/bin/env python3
"""Gera TODA a arte da Câmara de Provas em pixel art, pixel a pixel, com PIL (sem sprites prontos).

Uso (na raiz do projeto):   python tools/gerar_arte_camara.py        ->  assets/camara/*.png

Regras (as mesmas das fases anteriores):
  * 1 px de arte = 2 px de tela (Sprite2D com escala 2, filtro Nearest); contorno preto de 1 px;
    luz do canto superior esquerdo; sem antialiasing, sem degradê, sem ruído aleatório;
  * tudo que é PERIGO (raio, aviso, faísca, explosão, clarão, lente) usa as 6 cores de estilo_ataques.py:
    preto, vermelho escuro, vermelho, vermelho vivo, rosa e branco;
  * a ARENA usa a paleta do tileset (azul-marinho, cinzas de aço, laranja de aviso), como gerar_arte_fase2.py;
  * a geometria vem de camara_layout.py (a mesma que gera as colisões no .tscn e a validação).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import camara_layout as C  # noqa: E402
import estilo_ataques as E  # noqa: E402
import gerar_arte_fase2 as A  # noqa: E402

Canvas = A.Canvas
OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "camara"))
T = (0, 0, 0, 0)

# --- cores do perigo (6) e da arena
BLACK, DK, RED, HI, PINK, WHITE = E.BLACK, E.DK, E.RED, E.HI, E.PINK, E.WHITE
WASH = (252, 39, 39, 46)          # lavagem vermelha chapada (translucida, sem degradê)
OUTLINE, STEEL, STEEL_L, STEEL_D = A.OUTLINE, A.STEEL, A.STEEL_L, A.STEEL_D
GREY, GREY_L, GREY_D = A.GREY, A.GREY_L, A.GREY_D
NAVY, NAVY_SEAM, NAVY_PLATE = A.NAVY, A.NAVY_SEAM, A.NAVY_PLATE
BLUE, BLUE_L, BLUE_D, CYAN = A.BLUE, A.BLUE_L, A.BLUE_D, A.CYAN
ORANGE, ORANGE_D, GREEN_L = A.ORANGE, A.ORANGE_D, A.GREEN_L


def salvar(cv, nome):
    os.makedirs(OUT, exist_ok=True)
    cv.img.save(os.path.join(OUT, nome))
    print("  ", nome, cv.img.size)


def art(v):
    """px de tela -> px de arte."""
    return v // C.ART


def sheet_h(frames):
    """Cola quadros lado a lado (hframes)."""
    w, h = frames[0].w, frames[0].h
    sh = Canvas(w * len(frames), h)
    for i, f in enumerate(frames):
        sh.paste(f, i * w, 0)
    return sh


# --------------------------------------------------------------------------------------------- DÍGITOS
DIGITOS = {
    "0": ["###", "#.#", "#.#", "#.#", "###"], "1": [".#.", "##.", ".#.", ".#.", "###"],
    "2": ["##.", "..#", ".#.", "#..", "###"], "3": ["##.", "..#", "##.", "..#", "##."],
    "4": ["#.#", "#.#", "###", "..#", "..#"], "5": ["###", "#..", "##.", "..#", "##."],
    "6": [".##", "#..", "###", "#.#", "###"], "7": ["###", "..#", ".#.", ".#.", ".#."],
    "8": ["###", "#.#", "###", "#.#", "###"], "9": ["###", "#.#", "###", "..#", "##."],
}


def numero(cv, x, y, n, cor, sombra=None):
    """Escreve o número `n` (fonte 3 x 5) com o canto superior esquerdo em (x, y)."""
    for k, ch in enumerate(str(n)):
        for j, row in enumerate(DIGITOS[ch]):
            for i, c in enumerate(row):
                if c == "#":
                    if sombra:
                        cv.put(x + k * 4 + i + 1, y + j + 1, sombra)
                    cv.put(x + k * 4 + i, y + j, cor)


# --------------------------------------------------------------------------------------------- PISO / PAREDES
def mascaras():
    floor, solid = C.build_masks()
    return solid, floor      # (S, F) na ordem esperada por A.paint_walls / A.paint_floor


def pintar_piso(F):
    cv = A.paint_floor(F)
    return cv


def seta(cv, x, y, d, cor):
    """Seta (chevron) 5 x 7 apontando para a direção d (dx, dy); (x, y) = centro."""
    base = ["#....", "##...", ".##..", "..##.", ".##..", "##...", "#...."]   # aponta para a direita
    for j, row in enumerate(base):
        for i, ch in enumerate(row):
            if ch != "#":
                continue
            u, v = i - 2, j - 3
            if d == (1, 0):
                px, py = u, v
            elif d == (-1, 0):
                px, py = -u, v
            elif d == (0, 1):
                px, py = v, u
            else:
                px, py = v, -u
            cv.put(x + px, y + py, cor)


def pintar_faixas():
    """Faixas no chão: o que cada máquina cobre (contorno tracejado laranja, setas no sentido da varredura)
    e o número da vaga de disparo da Sala 3. Camada translúcida por cima do piso."""
    w, h = art(C.WORLD_W), art(C.WORLD_H)
    cv = Canvas(w, h)
    tint = (255, 178, 51, 26)
    for nome, m in C.MAQUINAS.items():
        g = C.geometria(nome)
        fx, fy, fw, fh = (art(v) for v in m["faixa"])
        par = list(C.MAQUINAS).index(nome) % 2 == 0
        # lavagem alternada só nas faixas VERTICAIS da Sala 3 (T0, T2, T4, ...), para as vizinhas se distinguirem
        if m["sala"] == 3 and g["dir"][0] == 0 and nome in ("T0", "T2", "T4", "B1", "B3", "B5") \
                and ("T0", "B1", "T2", "B3", "T4", "B5").index(nome) % 2 == 0:
            for yy in range(fy, fy + fh):
                for xx in range(fx, fx + fw):
                    cv.put(xx, yy, tint)
        # contorno tracejado (4 on / 4 off) nas bordas da faixa
        for xx in range(fx, fx + fw):
            if ((xx - fx) // 4) % 2 == 0:
                cv.put(xx, fy + 1, ORANGE_D)
                cv.put(xx, fy + fh - 2, ORANGE_D)
        for yy in range(fy, fy + fh):
            if ((yy - fy) // 4) % 2 == 0:
                cv.put(fx + 1, yy, ORANGE_D)
                cv.put(fx + fw - 2, yy, ORANGE_D)
        # setas no sentido da varredura (espaçadas de 28 px de arte, deslocamento próprio por faixa)
        d = g["dir"]
        cxm, cym = fx + fw // 2, fy + fh // 2
        if m["sala"] == 1:      # as duas máquinas do corredor dividem a faixa: setas em trilhos diferentes
            cym += -10 if d[0] > 0 else 10
        if d[0] == 0:
            n = max((fh - 24) // 28, 1)
            for k in range(n):
                yy = fy + 14 + k * 28 + (3 if par else 0)
                if yy < fy + fh - 8:
                    seta(cv, cxm, yy, d, ORANGE)
        else:
            n = max((fw - 24) // 28, 1)
            for k in range(n):
                xx = fx + 14 + k * 28 + (3 if par else 0)
                if xx < fx + fw - 8:
                    seta(cv, xx, cym, d, ORANGE)
        # número da vaga no chão, na frente da máquina (só nas salas com ordem)
        ordem = C.ordem_de(m["sala"])
        if nome in ordem and len(ordem) > 1 and m["sala"] == 3:
            cx, cy = (art(v) for v in g["alvo"])
            ox, oy = {"baixo": (0, 8), "cima": (0, -13), "direita": (8, 0), "esquerda": (-14, 0)}[g["boca"]]
            n = ordem.index(nome) + 1
            wnum = 4 * len(str(n)) - 1
            numero(cv, cx + ox - wnum // 2, cy + oy - 2, n, ORANGE, OUTLINE)
    return cv


def pintar_decoracao():
    """Cabos, ralos, marcas de uso e o terminal da saída. Tudo por listas escritas à mão (px de arte)."""
    cv = Canvas(art(C.WORLD_W), art(C.WORLD_H))
    ac = art
    # --- ralos de ventilação (grelha 12 x 8), posições escolhidas à mão
    grate = ["oooooooooooo", "ogggggggggso", "ogddddddddgo", "ogoooooooogo", "ogddddddddgo", "ogggggggggso",
             "oooooooooooo"]
    pal = {"o": OUTLINE, "g": STEEL, "d": (20, 30, 40, 255), "s": STEEL_D}
    for (x, y) in [(300, 380), (420, 520), (620, 360), (1020, 560), (1250, 300), (1500, 604), (1750, 250),
                   (1830, 470), (1110, 250), (100, 40)]:
        cv.stamp(ac(x), ac(y), grate, pal)
    # --- conduítes de cabos (linha dupla com pontos laranja), um por sala
    def cabo(x0, y0, x1, y1):
        n = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(n + 1):
            px = x0 + round((x1 - x0) * i / max(n, 1))
            py = y0 + round((y1 - y0) * i / max(n, 1))
            cv.put(px, py, STEEL_D)
            if y1 == y0:
                cv.put(px, py + 1, OUTLINE)
            else:
                cv.put(px + 1, py, OUTLINE)
            if i % 13 == 6:
                cv.put(px, py, ORANGE_D)
    cabo(ac(40), ac(96), ac(330), ac(96))
    cabo(ac(420), ac(100), ac(700), ac(100))
    cabo(ac(250), ac(520), ac(250), ac(420))
    cabo(ac(960), ac(640), ac(1200), ac(640))
    cabo(ac(1260), ac(230), ac(1600), ac(230))
    cabo(ac(1900), ac(660), ac(1900), ac(560))
    # --- marcas de queimado (onde os raios passam): elipses escuras por linhas de largura
    marcas = [(ac(480), ac(330), [4, 7, 9, 7, 4]), (ac(640), ac(560), [3, 6, 8, 8, 5, 3]),
              (ac(1500), ac(300), [5, 9, 11, 9, 5]), (ac(1130), ac(620), [4, 8, 9, 6, 3]),
              (ac(1760), ac(520), [3, 7, 9, 7, 3]), (ac(300), ac(60), [3, 6, 8, 6, 3])]
    for (x, y, widths) in marcas:
        for j, wd in enumerate(widths):
            for i in range(wd):
                cv.put(x + i - wd // 2, y + j, (14, 22, 32, 255))
    # --- rachaduras (polilinhas à mão)
    rach = [[(ac(900), ac(500)), (ac(906), ac(504)), (ac(910), ac(512)), (ac(918), ac(516))],
            [(ac(1700), ac(300)), (ac(1696), ac(308)), (ac(1702), ac(316)), (ac(1698), ac(326))],
            [(ac(560), ac(330)), (ac(566), ac(336)), (ac(564), ac(344))],
            [(ac(1300), ac(560)), (ac(1308), ac(564)), (ac(1312), ac(572)), (ac(1322), ac(574))]]
    for pts in rach:
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            n = max(abs(bx - ax), abs(by - ay), 1)
            for i in range(n + 1):
                px = ax + round((bx - ax) * i / n)
                py = ay + round((by - ay) * i / n)
                cv.put(px, py, OUTLINE)
                cv.put(px + 1, py, NAVY_PLATE)
    # --- faixas de perigo em volta do trecho de fogo da Sala 1
    fx, fy, fw, fh = (ac(v) for v in C.FOGO)
    for (bx, by, bw, bh) in [(fx - 5, fy, 4, fh), (fx + fw + 1, fy, 4, fh)]:
        for yy in range(by, by + bh):
            for xx in range(bx, bx + bw):
                cv.put(xx, yy, ORANGE if ((xx + yy) // 3) % 2 == 0 else STEEL_D)
        cv.frame(bx, by, bw, bh, OUTLINE)
    # --- terminal da saída (vestíbulo): console azul-ciano que lembra o quiz
    tx, ty = ac(C.SAIDA[0] + C.SAIDA[2] // 2), ac(C.SAIDA[1] + C.SAIDA[3] // 2)
    cv.rect(tx - 12, ty - 10, 24, 20, STEEL_D)
    cv.frame(tx - 12, ty - 10, 24, 20, OUTLINE)
    cv.rect(tx - 10, ty - 8, 20, 12, (8, 16, 26, 255))
    cv.frame(tx - 10, ty - 8, 20, 12, BLUE_D)
    for j in range(3):
        for i in range(8):
            if (i + j) % 3 != 2:
                cv.put(tx - 8 + i * 2, ty - 6 + j * 3, CYAN)
    cv.put(tx - 8, ty + 6, ORANGE)
    cv.put(tx - 6, ty + 6, GREEN_L)
    for k in range(2):      # setas para a leste no chão do vestíbulo
        seta(cv, ac(C.P3[0]) + 14 + k * 10, ac(C.P3[1] + C.P3[3] // 2), (1, 0), CYAN)
    return cv


def pintar_plataforma():
    """Plataforma de início (28 x 28 px de arte)."""
    cv = Canvas(28, 28)
    for yy in range(28):
        for xx in range(28):
            edge = min(xx, yy, 27 - xx, 27 - yy)
            if edge == 0:
                c = OUTLINE
            elif edge <= 2:
                c = STEEL_D
            elif 5 <= edge <= 6:
                c = BLUE
            else:
                c = BLUE_D
            cv.put(xx, yy, c)
    for k in range(2):
        for j, row in enumerate(["..#..", ".###.", "##.##"]):
            for i, ch in enumerate(row):
                if ch == "#":
                    cv.put(11 + i, 8 + k * 5 + j, BLUE_L)
    for (dx, dy) in ((3, 3), (24, 3), (3, 24), (24, 24)):
        cv.put(dx, dy, ORANGE)
    return cv


# --------------------------------------------------------------------------------------------- MÁQUINA
# Coordenadas locais: u = profundidade a partir da parede (0..23), w = lateral (0..23).
def _mapa(boca):
    if boca == "baixo":
        return lambda u, w: (w, u)
    if boca == "cima":
        return lambda u, w: (w, 23 - u)
    if boca == "direita":
        return lambda u, w: (u, w)
    return lambda u, w: (23 - u, w)      # esquerda


def _caixa(cv, mp, u0, u1, w0, w1, base, claro, escuro, forma=None):
    """Retângulo local com contorno preto e luz do canto superior esquerdo (luz GLOBAL, não local)."""
    cells = set()
    for u in range(u0, u1):
        for w in range(w0, w1):
            if forma is None or forma(u - u0, w - w0, u1 - u0, w1 - w0):
                cells.add(mp(u, w))
    for (x, y) in cells:
        if any((x + ox, y + oy) not in cells for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            cv.put(x, y, BLACK)
        else:
            cv.put(x, y, base)
    # 2ª passada: pixels logo dentro da borda de cima/esquerda ficam claros; de baixo/direita escuros
    for (x, y) in cells:
        if cv.get(x, y) == BLACK:
            continue
        up = (x, y - 1) in cells and cv.get(x, y - 1) == BLACK
        lf = (x - 1, y) in cells and cv.get(x - 1, y) == BLACK
        dn = (x, y + 1) in cells and cv.get(x, y + 1) == BLACK
        rt = (x + 1, y) in cells and cv.get(x + 1, y) == BLACK
        if up or lf:
            cv.put(x, y, claro)
        elif dn or rt:
            cv.put(x, y, escuro)
        else:
            cv.put(x, y, base)
    return cells


def maquina_quadro(boca, quadro, reforcada=False):
    """Um quadro 24 x 24 da máquina. quadro: 0 inativa, 1 e 2 carregando (pisca), 3 disparando,
    4 blindada (faísca), 5 destruída (carcaça com fumaça)."""
    cv = Canvas(24, 24)
    mp = _mapa(boca)
    morta = quadro == 5
    aco = (STEEL, STEEL_L, STEEL_D)
    if morta:
        aco = ((60, 62, 66, 255), (84, 86, 92, 255), (40, 42, 45, 255))
    # placa de fixação na parede
    _caixa(cv, mp, 0, 5, 0, 24, *aco)
    # carcaça principal
    _caixa(cv, mp, 5, 16, 3, 21, *aco)
    # blindagem lateral (só da reforçada): placas com rebites laranja
    if reforcada:
        plate = (GREY, GREY_L, GREY_D) if not morta else aco
        _caixa(cv, mp, 5, 15, 0, 3, *plate)
        _caixa(cv, mp, 5, 15, 21, 24, *plate)
        for (u, w) in ((7, 1), (12, 1), (7, 22), (12, 22)):
            cv.put(*mp(u, w), ORANGE if not morta else (110, 70, 30, 255))
    # faixas de aviso (laranja e escuro) nos flancos da carcaça
    for u in range(6, 15):
        c = (ORANGE if (u // 2) % 2 == 0 else OUTLINE) if not morta else ((110, 70, 30, 255) if (u // 2) % 2 == 0 else OUTLINE)
        cv.put(*mp(u, 4), c)
        cv.put(*mp(u, 19), c)
    # gola e bocal (a boca do raio)
    _caixa(cv, mp, 16, 19, 7, 17, *aco)
    bocal = (STEEL_D, STEEL, (30, 30, 34, 255)) if not morta else ((40, 42, 45, 255), (60, 62, 66, 255), (24, 24, 26, 255))
    _caixa(cv, mp, 19, 24, 8, 16, *bocal)
    # abertura do bocal (escura)
    for u in range(21, 24):
        for w in (11, 12):
            cv.put(*mp(u, w), (10, 6, 8, 255))
    # lente / olho vermelho da carcaça (6 x 6, círculo cortado)
    lente_c = {0: (DK, BLACK), 1: (HI, PINK), 2: (DK, RED), 3: (WHITE, PINK), 4: (DK, RED)}
    if morta:
        for (u, w) in ((8, 10), (8, 11), (9, 11), (9, 12), (10, 12), (10, 13), (11, 13)):
            cv.put(*mp(u, w), BLACK)        # rachadura onde ficava a lente
        cv.put(*mp(9, 10), (30, 20, 20, 255))
        cv.put(*mp(10, 11), (30, 20, 20, 255))
    else:
        fundo, brilho = lente_c[quadro]
        for u in range(7, 13):
            for w in range(9, 15):
                dist = math.hypot(u - 9.5, w - 11.5)
                if dist <= 3.2:
                    cv.put(*mp(u, w), BLACK if dist > 2.5 else fundo)
        cv.put(*mp(8, 10), brilho)
        if quadro in (1, 3):
            cv.put(*mp(9, 11), brilho)
    # efeitos por quadro
    if quadro == 3:      # clarão na boca: cruz branca e rosa
        for k in range(0, 6):
            cv.put(*mp(22 - 0, 12 - k + 3), WHITE if k < 4 else PINK)
        for (u, w) in ((21, 8), (21, 15), (22, 7), (22, 16), (23, 8), (23, 15), (20, 7), (20, 16)):
            cv.put(*mp(u, w), PINK)
        for (u, w) in ((21, 11), (21, 12), (22, 11), (22, 12), (23, 11), (23, 12)):
            cv.put(*mp(u, w), WHITE)
    if quadro == 4:      # blindada: faíscas rosa e brancas rebatidas na frente
        for (u, w, c) in ((18, 4, PINK), (19, 3, WHITE), (20, 2, PINK), (17, 19, PINK), (18, 20, WHITE),
                          (19, 21, PINK), (21, 12, WHITE), (22, 11, PINK), (22, 13, PINK), (20, 12, HI)):
            cv.put(*mp(u, w), c)
    if quadro == 5:      # fumaça: blocos cinza sobre a carcaça
        for (u, w, c) in ((12, 7, (110, 110, 116, 255)), (13, 8, (140, 140, 146, 255)), (14, 7, (110, 110, 116, 255)),
                          (11, 16, (110, 110, 116, 255)), (12, 17, (140, 140, 146, 255)), (13, 16, (110, 110, 116, 255)),
                          (10, 12, (90, 90, 96, 255)), (11, 12, (120, 120, 126, 255))):
            cv.put(*mp(u, w), c)
    return cv


def pintar_maquinas():
    for boca in ("baixo", "cima", "direita", "esquerda"):
        for ref in (False, True):
            frames = [maquina_quadro(boca, q, ref) for q in range(6)]
            salvar(sheet_h(frames), f"maquina_{boca}{'_ref' if ref else ''}.png")
    salvar(sheet_h([E.impacto(k, 16) for k in range(5)]), "maquina_explosao.png")


# --------------------------------------------------------------------------------------------- RAIO
def _feixe_seccao(j, f):
    """Camadas (5 px de espessura) do pixel j (posição ao longo do comprimento) no quadro f.
    Núcleo branco, contorno preto; o brilho (rosa) 'desce' pelo comprimento a cada quadro."""
    fase = (j + 3 * f) % 12
    if fase < 3:
        lado = PINK
    elif fase < 7:
        lado = HI
    else:
        lado = RED
    return [BLACK, lado, WHITE, lado, BLACK]


def feixe(comprimento_art, vertical, f):
    n = comprimento_art
    cv = Canvas(5, n) if vertical else Canvas(n, 5)
    for j in range(n):
        sec = _feixe_seccao(j, f)
        # pontas arredondadas (2 px em cada extremidade)
        if j in (0, n - 1):
            sec = [T, BLACK, BLACK, BLACK, T]
        elif j in (1, n - 2):
            sec = [BLACK, sec[1], sec[2], sec[3], BLACK]
        for k, c in enumerate(sec):
            if c == T:
                continue
            if vertical:
                cv.put(k, j, c)
            else:
                cv.put(j, k, c)
    return cv


def pintar_feixes():
    for nome, comp, vert in (("v96", 96, True), ("h516", 516, False), ("h172", 172, False), ("v236", 236, True)):
        frames = [feixe(art(comp), vert, f) for f in range(4)]
        salvar(sheet_h(frames), f"raio_feixe_{nome}.png")


def tracejado_tile():
    """O ladrilho da tira tracejada: 4 quadros de 6 x 16 px de arte (o traço 'corre' 4 px por quadro)."""
    quadros = []
    for f in range(4):
        cv = Canvas(6, 16)
        for j in range(16):
            ja = (j - 4 * f) % 16
            if ja < 8:
                for i in range(6):
                    c = BLACK if (i in (0, 5) or ja in (0, 7)) else RED
                    if c == RED and (i == 1 or ja == 1):
                        c = PINK if (i == 1 and ja == 1) else HI
                    cv.put(i, j, c)
        quadros.append(cv)
    return quadros


def aviso_faixa(largura_art, altura_art, eixo):
    """Quadros do aviso de uma faixa: lavagem vermelha chapada + trilhos tracejados que 'correm' no sentido
    da varredura. eixo 'v' = a linha anda em y (trilhos verticais); 'h' = anda em x (trilhos horizontais).
    O sentido ('para baixo/direita') é o do quadro; as máquinas do outro lado só espelham o Sprite2D."""
    tiles = tracejado_tile()
    quadros = []
    for f in range(4):
        cv = Canvas(largura_art, altura_art)
        for y in range(altura_art):
            for x in range(largura_art):
                cv.put(x, y, WASH)
        along = altura_art if eixo == "v" else largura_art
        across = largura_art if eixo == "v" else altura_art
        n_trilhos = max(2, round(across / 30))
        for r in range(n_trilhos):
            pos = 3 if r == 0 else (across - 9 if r == n_trilhos - 1 else 3 + r * (across - 12) // (n_trilhos - 1))
            for s in range(0, along, 16):
                t = tiles[f]
                for j in range(16):
                    if s + j >= along:
                        break
                    for i in range(6):
                        c = t.get(i, j)
                        if c[3]:
                            if eixo == "v":
                                cv.put(pos + i, s + j, c)
                            else:
                                cv.put(s + j, pos + i, c)
        # barra de origem (borda de onde a linha parte), mais forte
        quadros.append(cv)
    return quadros


def pintar_avisos():
    salvar(sheet_h(tracejado_tile()), "raio_aviso_tile.png")
    salvar(sheet_h(aviso_faixa(art(720), art(96), "h")), "raio_aviso_corredor.png")
    salvar(sheet_h(aviso_faixa(art(516), art(288), "v")), "raio_aviso_sala2.png")
    salvar(sheet_h(aviso_faixa(art(172), art(472), "v")), "raio_aviso_faixa_v.png")
    salvar(sheet_h(aviso_faixa(art(516), art(236), "h")), "raio_aviso_banda_h.png")


# --------------------------------------------------------------------------------------------- PORTAS
def porta_v(aberta):
    """Porta em pé: 16 x 48 px de arte (32 x 96 de tela). A folha de colisão (16 px de tela) fica no centro."""
    cv = Canvas(16, 48)
    if aberta:
        for y in list(range(0, 7)) + list(range(41, 48)):          # só os batentes ficam
            for x in range(16):
                edge = x in (0, 15) or y in (0, 6, 41, 47)
                cv.put(x, y, OUTLINE if edge else (STEEL_D if x < 3 or x > 12 else STEEL))
            cv.put(7, 3 if y < 7 else 44, GREEN_L)
            cv.put(8, 3 if y < 7 else 44, GREEN_L)
        for y in range(7, 41):                                      # trilho no chão onde a folha corria
            for x in range(5, 11):
                cv.put(x, y, (20, 32, 44, 255) if (x + y) % 8 else (26, 41, 55, 255))
        return cv
    for y in range(48):
        for x in range(16):
            c = STEEL
            if x in (0, 15) or y in (0, 47):
                c = OUTLINE
            elif x in (1, 2) or y in (1, 2):
                c = STEEL_L
            elif x in (13, 14) or y in (45, 46):
                c = STEEL_D
            cv.put(x, y, c)
    for y in (10, 11, 36, 37):                                      # frestas das placas
        for x in range(3, 13):
            cv.put(x, y, STEEL_D)
    for y in range(3, 9):                                           # faixas de aviso em cima e embaixo
        for x in range(3, 13):
            cv.put(x, y, ORANGE if ((x + y) // 2) % 2 == 0 else OUTLINE)
            cv.put(x, y + 36, ORANGE if ((x + y) // 2) % 2 == 0 else OUTLINE)
    # tela do contador (12 x 9): fundo escuro com moldura vermelha; o número é um Label por cima
    cv.rect(2, 19, 12, 10, (8, 6, 8, 255))
    cv.frame(2, 19, 12, 10, BLACK)
    cv.frame(3, 20, 10, 8, DK)
    cv.put(3, 20, RED)
    cv.put(12, 27, RED)
    for (x, y) in ((4, 14), (11, 14), (4, 33), (11, 33)):          # luzes vermelhas da tranca
        cv.put(x, y, HI)
        cv.put(x + 1, y, RED)
    return cv


def transpor(cv):
    """Transpõe (x <-> y): a luz do canto superior esquerdo continua válida (esquerda <-> cima)."""
    out = Canvas(cv.h, cv.w)
    for y in range(cv.h):
        for x in range(cv.w):
            out.put(y, x, cv.get(x, y))
    return out


def pintar_portas():
    for ab in (False, True):
        v = porta_v(ab)
        nome = "aberta" if ab else "trancada"
        salvar(v, f"porta_v_{nome}.png")
        salvar(transpor(v), f"porta_h_{nome}.png")


# --------------------------------------------------------------------------------------------- MAIN
def main():
    print("Arte da Câmara de Provas ->", OUT)
    S, F = mascaras()
    salvar(pintar_piso(F), "camara_piso.png")
    salvar(A.paint_walls(S, F), "camara_paredes.png")
    salvar(pintar_faixas(), "camara_faixas.png")
    salvar(pintar_decoracao(), "camara_decoracao.png")
    salvar(pintar_plataforma(), "plataforma_inicio.png")
    pintar_maquinas()
    pintar_feixes()
    pintar_avisos()
    pintar_portas()


if __name__ == "__main__":
    main()
