#!/usr/bin/env python3
"""Cronograma dos raios da Câmara de Provas: modelo, grade de pontos e busca da ordem/intervalo da Sala 3.

Uso (na raiz do projeto):
    python tools/camara_cronograma.py            # procura a ordem e o menor intervalo válido da Sala 3

Também é importado por validar_camara.py.

MODELO. Num ponto P do piso (centro da cápsula do Player, 28 x 56 parada) cada máquina que cobre P gera,
a cada ciclo, uma CHEGADA: o instante em que a linha de 10 px passa a tocar a cápsula. As chegadas de
máquinas diferentes (inclusive de direções diferentes, que se cruzam) são juntadas e ordenadas; duas
chegadas consecutivas têm de ficar >= 2,6 s afastadas. Como o ciclo se repete, a conta é circular.
"""
import itertools
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import camara_layout as L  # noqa: E402

PASSO = 4   # px entre pontos da grade


def pontos_da_sala(sala, passo=PASSO):
    """Centros possíveis da cápsula: dentro do piso, sem encostar nas paredes (14 nas laterais, 28 em cima/baixo)."""
    fl, ft, fw, fh = L.piso_da_maquina({1: "M1A", 2: "M2", 3: "T0"}[sala])
    pts = []
    y = ft + L.CAP_H / 2
    while y <= ft + fh - L.CAP_H / 2 + 1e-9:
        x = fl + L.CAP_W / 2
        while x <= fl + fw - L.CAP_W / 2 + 1e-9:
            pts.append((x, y))
            x += passo
        y += passo
    return pts


def chegadas(geos, pontos):
    """Para cada ponto, {maquina: (tau_in, tau_out)} (tempos desde o início da varredura)."""
    cob = []
    for (px, py) in pontos:
        d = {}
        for n, g in geos.items():
            r = L.intervalo_de_contato(g, px, py)
            if r is not None:
                d[n] = r
        cob.append(d)
    return cob


def cronograma_ponto(cob_ponto, inicio_aviso, ciclo):
    """Lista ordenada (a, b, maquina) das chegadas dentro de UM ciclo, em segundos desde o início do ciclo,
    reduzidas módulo `ciclo` (a chegada pode cair no ciclo seguinte)."""
    off = L.tempo_ate_varredura()
    ev = []
    for n, (t0, t1) in cob_ponto.items():
        a = inicio_aviso[n] + off + t0
        b = inicio_aviso[n] + off + t1
        ev.append((a % ciclo, b - a, n))
    ev.sort()
    return ev


def menor_folga_circular(ev, ciclo):
    """Menor distância (s) entre chegadas consecutivas (circular). Com 1 chegada, é o próprio ciclo."""
    if len(ev) <= 1:
        return ciclo
    m = ciclo
    for i in range(len(ev)):
        a = ev[i][0]
        b = ev[(i + 1) % len(ev)][0]
        d = (b - a) % ciclo
        if len(ev) == 2 and i == 1:
            d = ciclo - ((ev[1][0] - ev[0][0]) % ciclo)
        m = min(m, d)
    return m


def analisar(sala, intervalo=None, ordem=None, passo=PASSO, atraso=0.0):
    """Roda o cronograma de uma sala sobre a grade. Devolve dict com a pior folga e o pior ponto."""
    geos = {n: L.geometria(n) for n in L.MAQUINAS if L.MAQUINAS[n]["sala"] == sala}
    inicio, ciclo = L.disparos(sala, intervalo, ordem, atraso)
    pts = pontos_da_sala(sala, passo)
    cob = chegadas(geos, pts)
    pior = (1e9, None, None)
    janela_pior = (1e9, None)
    cobertura_min = 99
    for p, c in zip(pts, cob):
        cobertura_min = min(cobertura_min, len(c))
        ev = cronograma_ponto(c, inicio, ciclo)
        f = menor_folga_circular(ev, ciclo)
        if f < pior[0]:
            pior = (f, p, [(e[2], round(e[0], 2)) for e in ev])
        # janela livre: da última chegada (fim do contato) até a próxima chegada, descontando o dash
        if len(ev) >= 1:
            for i in range(len(ev)):
                a, dur, _ = ev[i]
                a2 = ev[(i + 1) % len(ev)][0]
                gap = (a2 - a) % ciclo if len(ev) > 1 else ciclo
                if len(ev) > 1 and i == len(ev) - 1:
                    gap = (ev[0][0] + ciclo - a)
                livre = gap - max(dur, L.DASH_DUR)
                if livre < janela_pior[0]:
                    janela_pior = (livre, p)
    return {"folga_min": pior[0], "ponto": pior[1], "chegadas": pior[2], "ciclo": ciclo,
            "janela_min": janela_pior[0], "janela_ponto": janela_pior[1], "pontos": len(pts),
            "cobertura_min": cobertura_min}


# ---------------------------------------------------------------------------------------------------
# Busca da ordem (Sala 3)
# ---------------------------------------------------------------------------------------------------
def diferencas_por_par(sala=3, passo=PASSO):
    """Para cada par de máquinas que cobrem os mesmos pontos: conjunto de (chegada_b - chegada_a)."""
    geos = {n: L.geometria(n) for n in L.MAQUINAS if L.MAQUINAS[n]["sala"] == sala}
    pts = pontos_da_sala(sala, passo)
    cob = chegadas(geos, pts)
    pares = {}
    for c in cob:
        ns = sorted(c)
        for i in range(len(ns)):
            for j in range(i + 1, len(ns)):
                d = round(c[ns[j]][0] - c[ns[i]][0], 2)
                pares.setdefault((ns[i], ns[j]), set()).add(d)
    return pares


def par_ok(difs, dvaga, intervalo, ciclo, folga):
    """dvaga = (vaga_b - vaga_a): todas as diferenças têm de ficar >= folga longe de 0 (circular)."""
    base = dvaga * intervalo
    for d in difs:
        x = (base + d) % ciclo
        if x < folga or ciclo - x < folga:
            return False
    return True


def buscar_ordem(pares, nomes, intervalo, folga):
    """Backtracking: atribui uma vaga (0..n-1) a cada máquina respeitando todos os pares."""
    n = len(nomes)
    ciclo = n * intervalo
    ordem = []

    def rec(i, usadas, vagas):
        if i == n:
            return True
        nome = nomes[i]
        for v in range(n):
            if v in usadas:
                continue
            ok = True
            for outro, vo in vagas.items():
                key = (nome, outro) if (nome, outro) in pares else (outro, nome)
                if key not in pares:
                    continue
                a, b = key
                va = v if a == nome else vo
                vb = vo if a == nome else v
                if not par_ok(pares[key], vb - va, intervalo, ciclo, folga):
                    ok = False
                    break
            if ok:
                vagas[nome] = v
                usadas.add(v)
                if rec(i + 1, usadas, vagas):
                    return True
                usadas.discard(v)
                del vagas[nome]
        return False

    vagas = {}
    if rec(0, set(), vagas):
        return [nm for nm, _ in sorted(vagas.items(), key=lambda kv: kv[1])]
    return None


def procurar(sala=3, folga=L.MIN_GAP + 0.05, passo=PASSO):
    nomes = [n for n in L.MAQUINAS if L.MAQUINAS[n]["sala"] == sala]
    pares = diferencas_por_par(sala, passo)
    resultado = []
    t = 0.8
    while t <= 4.0 + 1e-9:
        ordem = buscar_ordem(pares, nomes, round(t, 2), folga)
        if ordem:
            resultado.append((round(t, 2), ordem))
            break
        t += 0.05
    return resultado, pares


if __name__ == "__main__":
    res, pares = procurar(3)
    print("pares de máquinas com faixas que se cruzam:", len(pares))
    if not res:
        print("nenhum intervalo <= 4,0 s serve")
        sys.exit(1)
    t, ordem = res[0]
    print("menor intervalo com folga >= %.2f s: %.2f s" % (L.MIN_GAP + 0.05, t))
    print("ordem:", ordem)
    a = analisar(3, intervalo=t, ordem=ordem)
    print("conferência na grade: folga mínima %.3f s em %s, janela mínima %.3f s" % (
        a["folga_min"], a["ponto"], a["janela_min"]))
