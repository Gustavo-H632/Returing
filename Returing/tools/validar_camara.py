#!/usr/bin/env python3
"""Valida a Câmara de Provas com NÚMEROS (sem precisar do editor). Uso (na raiz do projeto):

    python tools/validar_camara.py            # tudo, menos o teste no motor
    python tools/validar_camara.py --motor    # também roda o Godot (check-only dos .gd + qa/camara_test.tscn)

Confere:
  A. cronograma: em QUALQUER ponto de cada sala, chegadas consecutivas de raios >= 2,6 s (grade de pontos x
     cronograma; raios de direções diferentes se cruzam) e janela livre para carregar o tiro >= 1,4 s;
  B. dash: de qualquer ponto seguro o dash (168 px, 0,30 s, recarga 1,0 s, iframes 0,34 s) atravessa a linha de
     10 px com folga de tempo para reagir; quem está na "zona de largada" tem o aviso (1,4 s) para sair;
  C. linha de tiro: toda máquina tem um ponto seguro com linha livre (raycast simulado, alcance do tiro 600 px);
  D. caminho início -> máquinas -> portas -> saída existe (cápsula 28 x 56 em grade de 8 px) e nenhuma parede prende;
  E. SIMULAÇÃO de um jogador-robô (anda a 300 px/s, dash, carga de 1,2 s a 40 %, tiro a 300 px/s) que limpa cada
     sala sem tomar dano, com o cronograma real;
  F. .tscn íntegro (recursos existentes, NodePath resolvem, sem TileMap), planta == cena, arte alinhada, .gd coerentes.
"""
import math
import os
import re
import subprocess
import sys
from collections import deque

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import camara_cronograma as K  # noqa: E402
import camara_layout as L  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
FALHAS, N_OK = [], 0
GEOS = {n: L.geometria(n) for n in L.MAQUINAS}


def check(ok, msg):
    global N_OK
    if ok:
        N_OK += 1
        print("  ok   ", msg)
    else:
        FALHAS.append(msg)
        print("  FALHA", msg)


def secao(t):
    print("\n== " + t)


# ----------------------------------------------------------------------------------------------- geometria
def rects_intersect(a, b):
    return a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3]


def seg_rect(p, q, r):
    """O segmento p->q cruza o retângulo r (x, y, w, h)? Devolve a menor fração t em [0, 1] ou None (slab)."""
    t0, t1 = 0.0, 1.0
    for ax in (0, 1):
        d = q[ax] - p[ax]
        lo, hi = r[ax], r[ax] + r[2 + ax]
        if abs(d) < 1e-9:
            if p[ax] < lo or p[ax] > hi:
                return None
        else:
            a, b = (lo - p[ax]) / d, (hi - p[ax]) / d
            if a > b:
                a, b = b, a
            t0, t1 = max(t0, a), min(t1, b)
            if t0 > t1:
                return None
    return t0


def solidos(portas_fechadas=()):
    rs = list(L.solid_rects_all())
    for p in portas_fechadas:
        rs.append(L.door_blocker(p))
    return rs


def cap_rect(x, y):
    return (x - L.CAP_W / 2, y - L.CAP_H / 2, L.CAP_W, L.CAP_H)


def livre(x, y, rs):
    c = cap_rect(x, y)
    for r in rs:
        if rects_intersect(c, r):
            return False
    return True


def sala_de_ponto(x, y):
    for n, (fx, fy, fw, fh) in (("R1", L.R1), ("R2", L.R2), ("R3", L.R3)):
        if fx <= x <= fx + fw and fy <= y <= fy + fh:
            return n
    return None


# ----------------------------------------------------------------------------------------------- A. cronograma
def teste_cronograma():
    secao("A. Cronograma dos raios (grade de pontos x cronograma)")
    for sala, nome in ((1, "Sala 1"), (2, "Sala 2"), (3, "Sala 3")):
        a = K.analisar(sala, passo=4)
        check(a["folga_min"] >= L.MIN_GAP,
              "%s: menor distância entre chegadas consecutivas = %.2f s (>= %.1f) em %d pontos, ciclo %.1f s" % (
                  nome, a["folga_min"], L.MIN_GAP, a["pontos"], a["ciclo"]))
        check(a["janela_min"] >= L.MIN_JANELA_CARGA,
              "%s: janela livre para carregar o tiro = %.2f s (>= %.1f; carga 1,2 s)" % (nome, a["janela_min"], L.MIN_JANELA_CARGA))
        check(a["cobertura_min"] >= 1, "%s: todo ponto do piso é varrido por pelo menos uma máquina" % nome)
    nomes = L.ORDEM_SALA3
    check(sorted(nomes) == sorted([n for n in L.MAQUINAS if L.MAQUINAS[n]["sala"] == 3]) and len(nomes) == 10,
          "Sala 3: a ordem fixa lista as 10 máquinas uma vez cada")
    # o menor intervalo possível (para o relatório) e a margem do valor exportado
    res, _ = K.procurar(3, folga=L.MIN_GAP + 0.0)
    if res:
        print("         menor intervalo que cumpre 2,6 s com esta grade: %.2f s; exportado: %.2f s" % (res[0][0], L.INTERVALO_SALA3))
        check(L.INTERVALO_SALA3 >= res[0][0], "intervalo exportado (%.2f s) >= mínimo calculado (%.2f s)" % (L.INTERVALO_SALA3, res[0][0]))
    # vagas fixas: tirar máquinas só REMOVE chegadas, então as folgas nunca diminuem (conferido em 40 subconjuntos)
    inicio, ciclo = L.disparos(3)
    geos = {n: GEOS[n] for n in L.ORDEM_SALA3}
    pts = K.pontos_da_sala(3, 8)
    cob = K.chegadas(geos, pts)
    import random
    rnd = random.Random(7)   # só para escolher subconjuntos de teste; o jogo não usa aleatório
    pior = 1e9
    for _ in range(40):
        vivas = {n for n in geos if rnd.random() < 0.6} or {"T0"}
        for c in cob:
            sub = {k: v for k, v in c.items() if k in vivas}
            if sub:
                ev = K.cronograma_ponto(sub, inicio, ciclo)
                pior = min(pior, K.menor_folga_circular(ev, ciclo))
    check(pior >= L.MIN_GAP, "Sala 3: com máquinas destruídas (40 subconjuntos) a folga mínima continua %.2f s" % pior)


# ----------------------------------------------------------------------------------------------- B. dash
def janela_de_dash(g, px, py):
    """(folga disponível antes do contato em px, janela de tempo útil em s) para atravessar a linha em dash."""
    dx, dy = g["dir"]
    v = g["velocidade"]
    if dx == 0:
        hm = L.CAP_H / 2 + L.BEAM_T / 2
        a_p, a0, s = py, g["inicio"], dy
    else:
        hm = L.CAP_W / 2 + L.BEAM_T / 2
        a_p, a0, s = px, g["inicio"], dx
    disponivel = (a_p - a0) * s - hm          # distância entre a borda da linha na largada e a cápsula
    vc = L.DASH_SPEED + v                     # fechamento (dash EM DIREÇÃO à linha)
    g_max = vc * L.DASH_DUR - 2 * hm          # começa o dash a no máx. g_max px da linha e termina de atravessar no dash
    util = min(disponivel, g_max)
    return disponivel, max(util, 0.0) / v


def teste_dash():
    secao("B. Dash x linha (cápsula 28 x 56, linha de 10 px)")
    for sala, nome in ((1, "Sala 1"), (2, "Sala 2"), (3, "Sala 3")):
        pior = (1e9, None, None)
        zona = 0.0
        for n, g in GEOS.items():
            if g["sala"] != sala:
                continue
            for (px, py) in K.pontos_da_sala(sala, 8):
                if L.intervalo_de_contato(g, px, py) is None:
                    continue
                disp, jan = janela_de_dash(g, px, py)
                if disp < 0:           # zona de largada: a linha já nasce em cima do jogador
                    zona = max(zona, -disp)
                    continue
                if jan < pior[0]:
                    pior = (jan, n, (px, py))
        check(pior[0] >= 0.0, "%s: fora da zona de largada, a janela para o dash começa em %.2f s (%s em %s)" % (
            nome, pior[0], pior[1], pior[2]))
        # perto da parede da máquina (janela de dash < 0,3 s) o aviso dá tempo de caminhar para fora
        prof = 0.0
        for n, g in GEOS.items():
            if g["sala"] == sala:
                hm = (L.CAP_H if g["dir"][0] == 0 else L.CAP_W) / 2 + L.BEAM_T / 2
                prof = max(prof, 0.3 * g["velocidade"] + hm)
        check(prof / L.WALK < L.T_AVISO + L.T_CLARAO - 0.5,
              "%s: a faixa junto à parede (janela de dash < 0,3 s) tem no máx. %.0f px: sair a pé leva %.2f s < aviso+clarão %.1f s" % (
                  nome, prof, prof / L.WALK, L.T_AVISO + L.T_CLARAO))
    check(L.DASH_DIST >= L.BEAM_T + L.CAP_H + 40, "o dash (168 px) cobre a linha (10) + a cápsula (56) com sobra")
    check(L.IFRAMES >= L.DASH_DUR, "iframes (0,34 s) cobrem o dash inteiro (0,30 s)")
    # no PIOR caso, atravessar a linha em dash dura (g+2hm)/vc: tem de caber nos iframes
    for n, g in GEOS.items():
        hm = (L.CAP_H if g["dir"][0] == 0 else L.CAP_W) / 2 + L.BEAM_T / 2
        vc = L.DASH_SPEED + g["velocidade"]
        assert 2 * hm / vc < L.IFRAMES
    check(True, "atravessar uma linha (mesmo parado perto dela) cabe nos iframes em todas as 13 máquinas")
    check(L.DASH_CD + L.DASH_DUR < L.MIN_GAP, "recarga do dash (1,0 s + 0,30 s) < 2,6 s: o dash volta antes da próxima chegada")


# ----------------------------------------------------------------------------------------------- C. linha de tiro
def ponto_seguro(sala, px, py):
    """Seguro = fora da zona de largada de todas as máquinas da sala (a janela do dash existe)."""
    for n, g in GEOS.items():
        if g["sala"] != sala or L.intervalo_de_contato(g, px, py) is None:
            continue
        disp, jan = janela_de_dash(g, px, py)
        if disp < 0 or jan < 0.3:
            return False
    return True


def tem_linha(px, py, g, rs):
    """Raycast simulado: boca do cano (P + 22,8 px na direção da mira) -> alvo da Hurtbox, só contra as paredes."""
    alvo = g["alvo"]
    d = (alvo[0] - px, alvo[1] - py)
    dist = math.hypot(*d)
    if dist < 1 or dist > L.SHOT_RANGE - 40:
        return False
    u = (d[0] / dist, d[1] / dist)
    muzzle = (px + u[0] * L.MUZZLE, py + u[1] * L.MUZZLE)
    if math.hypot(alvo[0] - muzzle[0], alvo[1] - muzzle[1]) < 2:
        return False
    # o corpo -> boca também precisa estar livre (CombatUtils.trace_spawn)
    for r in rs:
        if seg_rect((px, py), muzzle, r) is not None or seg_rect(muzzle, alvo, r) is not None:
            return False
    return True


def teste_linha_de_tiro():
    secao("C. Linha de tiro (raycast simulado contra paredes e reforços)")
    rs = solidos()
    for n, g in GEOS.items():
        if not g["destrutivel"]:
            continue
        melhores = []
        for (px, py) in K.pontos_da_sala(g["sala"], 16):
            if not livre(px, py, rs) or not ponto_seguro(g["sala"], px, py):
                continue
            if tem_linha(px, py, g, rs):
                melhores.append((px, py))
        check(len(melhores) >= 1, "%s: %d pontos seguros com linha de tiro livre até a máquina" % (n, len(melhores)))


# ----------------------------------------------------------------------------------------------- D. caminho
def bfs_grid(inicio, rs, passo=8):
    sx, sy = inicio
    visto = {(0, 0): 0}
    fila = deque([(0, 0)])
    pai = {(0, 0): None}
    while fila:
        i, j = fila.popleft()
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            k = (i + di, j + dj)
            if k in visto:
                continue
            x, y = sx + k[0] * passo, sy + k[1] * passo
            if not (0 <= x <= L.WORLD_W and 0 <= y <= L.WORLD_H) or not livre(x, y, rs):
                continue
            if di and dj and (not livre(sx + (i + di) * passo, sy + j * passo, rs)
                              or not livre(sx + i * passo, sy + (j + dj) * passo, rs)):
                continue
            visto[k] = visto[(i, j)] + (1.414 if di and dj else 1.0)
            pai[k] = (i, j)
            fila.append(k)
    return visto, pai


def teste_caminho():
    secao("D. Caminho início -> máquinas -> portas -> saída")
    s = L.START
    # estágio 1: portas 2 e final fechadas
    rs1 = solidos(("Porta2", "PortaFinal"))
    v1, _ = bfs_grid(s, rs1)
    alc1 = lambda p: (round((p[0] - s[0]) / 8), round((p[1] - s[1]) / 8)) in v1
    check(alc1((672, 330)), "início alcança a Sala 2 (porta 1 aberta)")
    check(not alc1((1000, 448)), "com a porta 2 fechada a Sala 3 NÃO é alcançável (a porta de fato fecha)")
    g2 = GEOS["M2"]
    ok2 = [p for p in K.pontos_da_sala(2, 16) if alc1(p) and ponto_seguro(2, *p) and tem_linha(p[0], p[1], g2, rs1)]
    check(bool(ok2), "Sala 2: o início alcança um ponto de tiro da máquina (%d pontos)" % len(ok2))
    # estágio 2: porta 2 aberta
    rs2 = solidos(("PortaFinal",))
    v2, _ = bfs_grid(s, rs2)
    alc2 = lambda p: (round((p[0] - s[0]) / 8), round((p[1] - s[1]) / 8)) in v2
    check(alc2((1000, 448)) and not alc2((2100, 448)), "com a porta 2 aberta chega-se à Sala 3 e a porta final ainda fecha")
    for n in L.ORDEM_SALA3:
        g = GEOS[n]
        ok = [p for p in K.pontos_da_sala(3, 16) if alc2(p) and ponto_seguro(3, *p) and tem_linha(p[0], p[1], g, rs2)]
        check(bool(ok), "Sala 3: o início alcança um ponto de tiro de %s (%d pontos)" % (n, len(ok)))
    # estágio 3: tudo aberto
    rs3 = solidos()
    v3, _ = bfs_grid(s, rs3)
    alc3 = lambda p: (round((p[0] - s[0]) / 8), round((p[1] - s[1]) / 8)) in v3
    sx, sy, sw, sh = L.SAIDA
    check(alc3((sx + sw / 2, sy + sh / 2)), "tudo aberto: o início alcança o gatilho de saída para o quiz")
    # nenhuma parede prende: todo ponto livre do piso está na mesma região conectada (e há folga de dash)
    livres = []
    for sala in (1, 2, 3):
        for (x, y) in K.pontos_da_sala(sala, 16):
            gx, gy = s[0] + round((x - s[0]) / 8) * 8, s[1] + round((y - s[1]) / 8) * 8   # ponto da malha de 8 px
            if livre(gx, gy, rs3):
                livres.append((gx, gy))
    presos = [p for p in livres if not alc3(p)]
    check(not presos, "nenhum ponto livre do piso fica isolado/preso (%d pontos testados)" % len(livres))
    # corredores com 96 px
    for nome, r in (("Sala 1", L.R1), ("passagem 1", L.P1), ("passagem 2", L.P2), ("vestíbulo", L.P3)):
        check(min(r[2], r[3]) >= L.CELL, "%s: corredor com %d px (>= 96 px para a cápsula 28 x 56; no celular 42 x 84)" % (nome, min(r[2], r[3])))


# ----------------------------------------------------------------------------------------------- E. robô
class Robo:
    """Jogador simulado: anda a 300 px/s por BFS, faz dash em direção à linha, carrega 1,2 s parado e atira."""
    DT = 1.0 / 30.0

    def __init__(self, sala, rs, inicio, mortos_ini=()):
        self.sala, self.rs = sala, rs
        self.x, self.y = inicio
        self.t = 0.0
        self.dash_pronto = 0.0
        self.dash_fim = -1.0
        self.imune_ate = -1.0
        self.dir_dash = (0, 0)
        self.hits = 0
        self.dashes = 0
        self.tiros = 0
        self.morte = {}                 # máquina -> instante em que morreu
        self.vida = {n: (2 if GEOS[n]["reforcada"] else 1) for n in L.MAQUINAS if GEOS[n]["sala"] == sala and GEOS[n]["destrutivel"]}
        self.voos = []                  # (instante de impacto, máquina)
        self.inicio_sala = 0.0
        self.disp, self.ciclo = L.disparos(sala, atraso=L.ATRASO_INICIAL[sala])
        self.perigos_fixos = [(L.FOGO, None)] if sala == 1 else []   # fogo: sem "origem"; atravessa-se no sentido do caminho

    # --- perigos no instante t: lista de (retângulo, direção "para a origem")
    def perigos(self, t):
        out = list(self.perigos_fixos)
        for n, t0 in self.disp.items():
            if n in self.morte and self.morte[n] <= t:
                continue
            g = GEOS[n]
            k = math.floor((t - t0) / self.ciclo) if t >= t0 else -1
            if k < 0:
                continue
            tau = t - (t0 + k * self.ciclo) - L.tempo_ate_varredura()
            if 0.0 <= tau <= L.T_VARREDURA:
                out.append((L.posicao_da_linha(g, tau), (-g["dir"][0], -g["dir"][1])))
        return out

    def toca(self, x, y, t, folga=0.0):
        c = cap_rect(x, y)
        c = (c[0] - folga, c[1] - folga, c[2] + 2 * folga, c[3] + 2 * folga)
        return [d for (r, d) in self.perigos(t) if rects_intersect(c, r)]

    def ameaca(self, x, y, t0, horizonte, passo=0.05):
        k = 0.0
        while k <= horizonte:
            m = self.toca(x, y, t0 + k)
            if m:
                return k, m[0]
            k += passo
        return None

    # --- passo de tempo: faz o dash em andamento, conta dano
    def avancar(self, dx=0.0, dy=0.0):
        d = self.DT
        if self.t < self.dash_fim:
            nx, ny = self.x + self.dir_dash[0] * L.DASH_SPEED * d, self.y + self.dir_dash[1] * L.DASH_SPEED * d
            if livre(nx, ny, self.rs):
                self.x, self.y = nx, ny
        else:
            nx, ny = self.x + dx, self.y + dy
            if (dx or dy) and livre(nx, ny, self.rs):
                self.x, self.y = nx, ny
        self.t += d
        if self.t >= self.imune_ate and self.toca(self.x, self.y, self.t):
            self.hits += 1
            self.imune_ate = self.t + 0.5       # evita contar o mesmo contato várias vezes
        for v in list(self.voos):
            if v[0] <= self.t:
                self.voos.remove(v)
                self.vida[v[1]] -= 1
                if self.vida[v[1]] <= 0:
                    self.morte[v[1]] = self.t

    def tentar_dash(self, direcao):
        if self.t < self.dash_pronto or self.t < self.dash_fim:
            return False
        for cand in (direcao, (-direcao[0], -direcao[1])):
            if livre(self.x + cand[0] * 20, self.y + cand[1] * 20, self.rs):
                self.dir_dash = cand
                self.dash_fim = self.t + L.DASH_DUR
                self.imune_ate = self.t + L.IFRAMES
                self.dash_pronto = self.dash_fim + L.DASH_CD
                self.dashes += 1
                return True
        return False

    def ocupado(self):
        return self.t < self.dash_fim

    # --- ações
    def reagir(self, folga_reacao=0.22):
        """Dash se a ameaça chega logo. Devolve True se está fazendo dash."""
        if self.ocupado():
            return True
        a = self.ameaca(self.x, self.y, self.t, folga_reacao)
        if a and a[1] is not None and self.t >= self.imune_ate:
            return self.tentar_dash(a[1])
        return False

    def andar_ate(self, alvo, limite=400.0):
        """Segue o caminho BFS até `alvo`, esperando quando a linha vem; faz dash para atravessá-la."""
        passo = 8

        def tracar():
            vis, pai = bfs_grid((self.x, self.y), self.rs, passo)
            melhor = min(vis, key=lambda k: math.hypot(self.x + k[0] * passo - alvo[0], self.y + k[1] * passo - alvo[1]))
            r, k = [], melhor
            while k is not None:
                r.append((self.x + k[0] * passo, self.y + k[1] * passo))
                k = pai[k]
            r.reverse()
            return r
        rota = tracar()
        idx = 0
        t_ini = self.t
        while idx < len(rota) and self.t - t_ini < limite:
            if self.reagir():
                self.avancar()
                continue
            px, py = rota[idx]
            dist = math.hypot(px - self.x, py - self.y)
            if dist > 40.0 and not self.ocupado():    # o dash tirou o robô da rota: traça de novo daqui
                rota, idx = tracar(), 0
                continue
            if dist < 2.0:
                idx += 1
                continue
            ux, uy = (px - self.x) / dist, (py - self.y) / dist
            vel = L.WALK * self.DT
            # trajetória prevista andando (0,5 s): se cruza fogo ou uma linha, atravessa em dash (na direção da
            # origem da linha; no fogo, no sentido do caminho) ou espera quando o dash está em recarga
            ameaca = None
            k = 0.0
            while k <= 0.5 and ameaca is None:
                m = self.toca(self.x + ux * L.WALK * k, self.y + uy * L.WALK * k, self.t + k)
                if m:
                    ameaca = (k, m[0])
                k += 0.05
            if ameaca and self.t >= self.imune_ate and ameaca[0] <= 0.2:
                if self.t >= self.dash_pronto:
                    self.tentar_dash(ameaca[1] if ameaca[1] is not None else (ux, uy))
                self.avancar()      # espera a recarga do dash (ou continua o dash em andamento)
                continue
            self.avancar(ux * min(vel, dist), uy * min(vel, dist))
        return idx >= len(rota) - 1

    def carregar_e_atirar(self, nome):
        g = GEOS[nome]
        d = math.hypot(g["alvo"][0] - self.x, g["alvo"][1] - self.y)
        inicio = self.t
        # começa a carga só se nenhuma linha chega no pior caso (carga 1,2 s + folga) -- senão espera/dash
        while True:
            if self.reagir():
                self.avancar()
                continue
            if not self.ameaca(self.x, self.y, self.t, L.CHARGE_TIME + 0.1):
                break
            self.avancar()
            if self.t - inicio > 120:
                return False
        for _ in range(int(round(L.CHARGE_TIME / self.DT))):
            if self.reagir():          # dash cancela a carga (não deveria acontecer)
                return False
            self.avancar()
        self.tiros += 1
        self.voos.append((self.t + d / L.SHOT_SPEED, nome))
        return True


def melhores_pontos(sala, rs, g, de, n=6):
    cand = [(px, py) for (px, py) in K.pontos_da_sala(sala, 16)
            if livre(px, py, rs) and ponto_seguro(sala, px, py) and tem_linha(px, py, g, rs)]
    cand.sort(key=lambda p: math.hypot(p[0] - de[0], p[1] - de[1]) + 0.4 * math.hypot(p[0] - g["alvo"][0], p[1] - g["alvo"][1]))
    return cand[:n]


def simular_sala(sala, inicio, portas_fechadas, destino):
    rs = solidos(portas_fechadas)
    r = Robo(sala, rs, inicio)
    pendentes = [n for n in L.ordem_de(sala) if GEOS[n]["destrutivel"]]
    while pendentes and r.t < 900:
        # alvo mais próximo do robô
        n = min(pendentes, key=lambda m: math.hypot(GEOS[m]["alvo"][0] - r.x, GEOS[m]["alvo"][1] - r.y))
        g = GEOS[n]
        pts = melhores_pontos(sala, rs, g, (r.x, r.y))
        if not pts:
            return None
        ok = r.andar_ate(pts[0])
        while n in pendentes and r.t < 900:
            if n in r.morte and r.morte[n] <= r.t:
                pendentes.remove(n)
                break
            falta = r.vida[n] - sum(1 for v in r.voos if v[1] == n)
            if falta <= 0:
                r.avancar()
                continue
            # pode ter sido empurrado pelo dash: volta ao ponto
            if math.hypot(r.x - pts[0][0], r.y - pts[0][1]) > 24:
                r.andar_ate(pts[0])
            r.carregar_e_atirar(n)
        for v in list(r.voos):
            pass
    # espera os tiros pousarem e anda até a saída da sala
    while r.voos and r.t < 900:
        r.avancar()
    r.rs = solidos(())   # a porta da sala abriu
    r.andar_ate(destino)
    return r


def teste_robo():
    secao("E. Simulação do jogador-robô com o cronograma real (anda, dash, carga 1,2 s, tiro)")
    casos = (
        (1, L.START, ("Porta2", "PortaFinal"), (672, 160), "Sala 1 (só dash)"),
        (2, (672, 330), ("Porta2", "PortaFinal"), (800, 448), "Sala 2 (dash + 1 tiro)"),
        (3, (960, 448), ("PortaFinal",), (2040, 448), "Sala 3 (10 máquinas)"),
    )
    for sala, ini, portas, dest, nome in casos:
        r = simular_sala(sala, ini, portas, dest)
        if r is None:
            check(False, "%s: sem ponto de tiro" % nome)
            continue
        mortas = len(r.morte)
        total = sum(1 for n in L.ordem_de(sala) if GEOS[n]["destrutivel"])
        check(mortas == total, "%s: o robô destruiu %d/%d máquinas" % (nome, mortas, total))
        check(r.hits == 0, "%s: sem tomar dano (contatos com a linha: %d) em %.0f s, %d dashes, %d tiros carregados" % (
            nome, r.hits, r.t, r.dashes, r.tiros))
        if sala == 1:
            check(r.dashes >= 1, "Sala 1: atravessar exige o dash (o robô usou %d)" % r.dashes)
        d = math.hypot(r.x - dest[0], r.y - dest[1])
        check(d < 40, "%s: o robô chegou à porta de saída da sala (a %.0f px)" % (nome, d))


# ----------------------------------------------------------------------------------------------- F. arquivos
def ler(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        return f.read()


def parse_tscn(txt):
    ext, nodes = {}, []
    cur = None
    for linha in txt.splitlines():
        if linha.startswith("[ext_resource"):
            m = re.search(r'path="([^"]+)" id="([^"]+)"', linha)
            ext[m.group(2)] = m.group(1)
        elif linha.startswith("[node"):
            nome = re.search(r'name="([^"]*)"', linha).group(1)
            tipo = (re.search(r'type="([^"]*)"', linha) or [None, None])[1]
            pai = (re.search(r'parent="([^"]*)"', linha) or [None, None])[1]
            cur = {"nome": nome, "tipo": tipo, "pai": pai, "inst": "instance=" in linha, "props": {},
                   "paths": re.findall(r'"(\w+)"', (re.search(r'node_paths=PackedStringArray\(([^)]*)\)', linha) or ["", ""])[1])}
            nodes.append(cur)
        elif linha.startswith("["):
            cur = None
        elif cur is not None and " = " in linha:
            k, v = linha.split(" = ", 1)
            cur["props"][k.strip()] = v.strip()
    for nd in nodes:
        nd["caminho"] = "." if nd["pai"] is None else (nd["nome"] if nd["pai"] == "." else nd["pai"] + "/" + nd["nome"])
    return ext, nodes


def resolver(base, rel):
    partes = [] if base == "." else base.split("/")
    for p in rel.split("/"):
        if p == "..":
            if not partes:
                return None
            partes.pop()
        elif p not in (".", ""):
            partes.append(p)
    return "/".join(partes) if partes else "."


def teste_arquivos():
    secao("F. Arquivos (.tscn, planta == cena, arte, .gd)")
    txt = ler("Scenes/Fase5/Camara.tscn")
    ext, nodes = parse_tscn(txt)
    check(not re.search(r"TileMap|TileSet|tile_set|tile_map_data", txt), "Camara.tscn não usa TileMap/TileSet")
    faltam = [p for p in ext.values() if not os.path.exists(os.path.join(ROOT, p.replace("res://", "")))]
    check(not faltam, "todos os %d recursos externos existem %s" % (len(ext), faltam[:3]))
    caminhos = {nd["caminho"] for nd in nodes}
    check(len(caminhos) == len(nodes), "nomes de nós únicos por pai (%d nós)" % len(nodes))
    orfaos = [nd["caminho"] for nd in nodes if nd["pai"] not in (None, ".") and nd["pai"] not in caminhos]
    check(not orfaos, "todo nó tem pai declarado antes %s" % orfaos[:3])
    quebrados = []
    for nd in nodes:
        for p in nd["paths"]:
            v = nd["props"].get(p, "")
            m = re.search(r'NodePath\("([^"]*)"\)', v)
            if m and resolver(nd["caminho"], m.group(1)) not in caminhos:
                quebrados.append((nd["caminho"], p, m.group(1)))
    check(not quebrados, "todo NodePath exportado resolve para um nó existente %s" % quebrados[:3])
    # planta == cena
    por = {nd["caminho"]: nd for nd in nodes}
    filhos3 = [nd["nome"] for nd in nodes if nd["pai"] == "Sala3"]
    check(filhos3 == L.ORDEM_SALA3, "ordem dos filhos de Sala3 == ordem de disparo da planta")
    for n, g in GEOS.items():
        nd = por.get("Sala%d/%s" % (g["sala"], n))
        pos = re.search(r"Vector2\(([-\d.]+), ([-\d.]+)\)", nd["props"]["position"])
        check(abs(float(pos.group(1)) - g["centro"][0]) < 0.01 and abs(float(pos.group(2)) - g["centro"][1]) < 0.01,
              "%s: posição na cena == planta %s" % (n, g["centro"]))
    ini = por["Sala3"]["props"]["intervalo_disparos"]
    check(abs(float(ini) - L.INTERVALO_SALA3) < 1e-6, "Sala3.intervalo_disparos == planta (%s)" % ini)
    nw = sum(1 for nd in nodes if nd["pai"] == "Colisoes" and nd["nome"].startswith("Parede"))
    check(nw == len(L.wall_rects()), "%d colisões de parede == planta" % nw)
    # arte alinhada
    for arq, (w, h) in {"camara_piso.png": (L.WORLD_W // 2, L.WORLD_H // 2), "camara_paredes.png": (L.WORLD_W // 2, L.WORLD_H // 2),
                        "camara_faixas.png": (L.WORLD_W // 2, L.WORLD_H // 2), "camara_decoracao.png": (L.WORLD_W // 2, L.WORLD_H // 2)}.items():
        check(Image.open(os.path.join(ROOT, "assets/camara", arq)).size == (w, h), "%s tem %dx%d px (mundo / 2)" % (arq, w, h))
    floor, solid = L.build_masks()
    paredes = Image.open(os.path.join(ROOT, "assets/camara/camara_paredes.png")).convert("RGBA")
    piso = Image.open(os.path.join(ROOT, "assets/camara/camara_piso.png")).convert("RGBA")
    pw, pp = paredes.load(), piso.load()
    sem_parede = sum(1 for y in range(len(solid)) for x in range(len(solid[0])) if solid[y][x] and pw[x, y][3] == 0)
    sem_piso = sum(1 for y in range(len(floor)) for x in range(len(floor[0])) if floor[y][x] and pp[x, y][3] == 0)
    check(sem_parede == 0 and sem_piso == 0, "arte alinhada às colisões (células sólidas sem arte: %d; piso sem arte: %d)" % (sem_parede, sem_piso))
    for n, g in GEOS.items():
        t = ("v" if g["dir"][0] != 0 else "h") + str(g["comprimento"])
        im = Image.open(os.path.join(ROOT, "assets/camara/raio_feixe_%s.png" % t))
        vert = g["dir"][0] != 0
        esperado = (5 * 4, g["comprimento"] // 2) if vert else (g["comprimento"] // 2 * 4, 5)
        if im.size != esperado:
            check(False, "feixe %s tem %s, esperado %s" % (t, im.size, esperado))
    check(True, "feixes: espessura 5 px de arte = 10 px da hitbox, comprimento == faixa")
    # .gd: pares () [] {} e funções tipadas
    gds = [f for f in os.listdir(os.path.join(ROOT, "Scenes/Fase5")) if f.endswith(".gd")]
    for f in gds:
        src = ler("Scenes/Fase5/" + f)
        pilha, ok = [], True
        em_str = None
        for ch in re.sub(r"#.*", "", src):
            if em_str:
                if ch == em_str:
                    em_str = None
            elif ch in "\"'":
                em_str = ch
            elif ch in "([{":
                pilha.append(ch)
            elif ch in ")]}":
                if not pilha or "([{"[")]}".index(ch)] != pilha.pop():
                    ok = False
        check(ok and not pilha and "\t" in src and not re.search(r"^ +\S", src, re.M), "%s: delimitadores balanceados e indentação com TAB" % f)
    # InputMap: as ações usadas existem
    pg = ler("project.godot")
    for acao in ("debug_overlay", "dash", "charge_shoot", "attack_sword", "move_left"):
        check(re.search(r"^%s=" % acao, pg, re.M) is not None, "InputMap tem a ação '%s' (nenhuma ação nova foi preciso criar)" % acao)
    # sequência: SalaNova (cristal) -> Defesa -> quiz (Fase2) -> Câmara -> Fase 3
    check("next_scene" not in ler("Scenes/Fase2/SalaNova.tscn") and "Defesa/Defesa.tscn" in ler("Scenes/Fase2/sala_nova.gd"),
          "SalaNova segue para a Defesa (como no projeto original)")
    check("Defesa/Fase2.tscn" not in ler("Scenes/Defesa/defense_level.gd") and "Fase2/Fase2.tscn" in ler("Scenes/Defesa/defense_level.gd"),
          "Defesa segue para o quiz (Fase2.tscn)")
    check('next_scene = "res://Scenes/Fase5/Camara.tscn"' in ler("Scenes/Fase2/Fase2.tscn"), "quiz (Fase2.tscn) -> Camara.tscn")
    check("Fase3/fase_3.tscn" in ler("Scenes/Fase5/camara.gd"), "Camara.next_scene -> fase_3.tscn")
    check("Dialogue.Style.VOICE" in ler("Scenes/Fase5/camara.gd"), "abertura da Câmara usa a voz do tutorial (VOICE)")
    check(re.search(r'texture_filter=0|default_texture_filter=0', pg) is not None, "project.godot mantém o filtro Nearest")


def teste_motor():
    secao("Motor (Godot)")
    exe = os.environ.get("GODOT") or r"C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
    if not os.path.exists(exe):
        print("  (Godot não encontrado: defina GODOT=caminho; o teste no motor NÃO foi executado)")
        return
    r = subprocess.run([exe, "--headless", "--path", ROOT, "--import"], capture_output=True, text=True, encoding="utf-8", errors="replace")
    erros = [l for l in (r.stdout + r.stderr).splitlines() if re.search(r"SCRIPT ERROR|Parse Error", l)]
    check(not erros, "godot --headless --import sem erros de script %s" % erros[:3])
    r = subprocess.run([exe, "--headless", "--path", ROOT, "res://qa/camara_test.tscn"], capture_output=True, text=True, encoding="utf-8", errors="replace")
    saida = r.stdout + r.stderr
    m = re.search(r"camara_test: (\d+) verificações, (\d+) falhas", saida)
    check(bool(m) and m.group(2) == "0", "qa/camara_test.tscn no motor: %s" % (m.group(0) if m else "sem resultado"))


def main():
    teste_cronograma()
    teste_dash()
    teste_linha_de_tiro()
    teste_caminho()
    teste_robo()
    teste_arquivos()
    if "--motor" in sys.argv:
        teste_motor()
    print("\n%d verificações ok, %d falhas" % (N_OK, len(FALHAS)))
    for f in FALHAS:
        print("  FALHA:", f)
    sys.exit(1 if FALHAS else 0)


if __name__ == "__main__":
    main()
