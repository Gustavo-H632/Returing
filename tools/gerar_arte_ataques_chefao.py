#!/usr/bin/env python3
"""Gera os sprites dos ATAQUES do chefão Guide e do Robô atirador, todos na mesma linguagem visual
(ver tools/estilo_ataques.py: 6 cores, contorno preto, formas simples, luz de cima-esquerda).

Uso (na raiz do projeto):   python tools/gerar_arte_ataques_chefao.py      (precisa de Pillow)

sprites/Enemies/Attacks/
  guide_shot.png             tiro principal: 8 quadros de 64 x 64 (SUBSTITUI o antigo; mesmas medidas/eixo)
  guide_beam.png             orbe dos tiros que se dividem: 4 quadros de 64 x 64 (SUBSTITUI o antigo; quadro 0 em uso)
  guide_slash_aviso.png      golpe de espada em área: 6 quadros de 84 x 84   (raio 84)
  guide_slash_corte.png      corte: 4 quadros de 84 x 84
  guide_circulo_aviso.png    círculos no chão: 8 quadros de 56 x 56          (raio 56)
  guide_circulo_explosao.png dano dos círculos: 5 quadros de 56 x 56
  guide_laser_aviso.png      aviso do raio: 4 quadros de 6 x 16 (repetidos ao longo do raio)
  guide_laser_feixe.png      feixe: 4 quadros de 10 x 50 (ponta, corpo de 40 que se repete, ponta)
  guide_gaiola.png           ladrilho 32 x 32 das paredes da gaiola da transição
sprites/
  robo_melee_aviso.png       golpe de perto do Robô: 6 quadros de 80 x 80    (raio 80)
  robo_melee_impacto.png     impacto: 5 quadros de 80 x 80
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gerar_arte_fase2 import Canvas  # noqa: E402
import estilo_ataques as E  # noqa: E402
from estilo_ataques import BLACK, DK, RED, HI, PINK, WHITE  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
ATT = os.path.join(ROOT, "sprites", "Enemies", "Attacks")
SPR = os.path.join(ROOT, "sprites")


def save(cv, folder, name):
    os.makedirs(folder, exist_ok=True)
    cv.img.save(os.path.join(folder, name))
    print("  ", os.path.relpath(os.path.join(folder, name), ROOT).replace(os.sep, "/"), cv.img.size)


def sheet(frames, w, h):
    s = Canvas(w * len(frames), h)
    for i, f in enumerate(frames):
        s.paste(f, i * w, 0)
    return s


# ---------------------------------------------------------------- raio
BEAM_COL = [BLACK, DK, RED, PINK, WHITE, WHITE, PINK, RED, DK, BLACK]   # 10 px, simétrico, sempre com contorno


def laser_feixe():
    frames = []
    for f in range(4):
        cv = Canvas(10, 50)
        for y in range(40):                       # corpo (40 px que se repetem); brilho de 4 px desce 5 px por quadro
            node = ((y + f * 5) % 20) < 4
            for x in range(10):
                c = BEAM_COL[x]
                if node and 2 <= x <= 7:
                    c = WHITE if 3 <= x <= 6 else PINK
                cv.put(x, 5 + y, c)
        for j in range(5):                        # pontas arredondadas (contorno preto)
            inset = [3, 2, 1, 1, 0][j]
            for x in range(10):
                if inset <= x < 10 - inset:
                    edge = x in (inset, 9 - inset)
                    c = BLACK if (edge or j == 0) else BEAM_COL[x]
                    cv.put(x, j, c)
                    cv.put(x, 49 - j, c)
        frames.append(cv)
    save(sheet(frames, 10, 50), ATT, "guide_laser_feixe.png")


def laser_aviso():
    frames = []
    for f in range(4):
        cv = Canvas(6, 16)
        for y in range(16):
            if ((y + f * 4) % 16) < 8:
                for x in range(6):
                    cv.put(x, y, BLACK if x in (0, 5) or ((y + f * 4) % 16) in (0, 7) else (HI if x in (2, 3) else RED))
        frames.append(cv)
    save(sheet(frames, 6, 16), ATT, "guide_laser_aviso.png")


# ---------------------------------------------------------------- gaiola
def gaiola():
    STEEL, STEEL_D, STEEL_L = (75, 75, 77, 255), (56, 60, 61, 255), (115, 120, 123, 255)
    cv = Canvas(32, 32, STEEL_D)
    cv.frame(0, 0, 32, 32, BLACK)
    for i in range(1, 31):
        cv.put(i, 1, STEEL_L)
        cv.put(1, i, STEEL_L)
        cv.put(i, 30, (40, 44, 48, 255))
        cv.put(30, i, (40, 44, 48, 255))
    cv.rect(5, 5, 22, 22, STEEL)
    cv.frame(5, 5, 22, 22, BLACK)
    for i in range(6, 26):
        cv.put(i, 6, (91, 95, 102, 255))
        cv.put(6, i, (91, 95, 102, 255))
    for j, row in enumerate(["#.....#", ".#...#.", "..#.#..", "...#..."]):      # chevron vermelho
        for i, ch in enumerate(row):
            if ch == "#":
                for dy in (11, 17):
                    cv.put(12 + i, dy + j, BLACK)
                    cv.put(12 + i, dy + j + 1, HI if dy == 11 else RED)
    for (x, y) in ((8, 8), (22, 8), (8, 22), (22, 22)):
        cv.put(x, y, BLACK)
        cv.put(x + 1, y + 1, STEEL_D)
        cv.put(x - 1 if x > 15 else x, y - 1 if y > 15 else y, STEEL_L) if False else None
    save(cv, ATT, "guide_gaiola.png")


def main():
    print("Gerando os ataques (Guide + Robô) em", os.path.normpath(ROOT))
    save(sheet([E.beam_frame(f) for f in range(8)], 64, 64), ATT, "guide_shot.png")
    save(sheet([E.orb_frame(f) for f in range(4)], 64, 64), ATT, "guide_beam.png")
    save(sheet([E.aviso(k, 6, 42, "lamina") for k in range(6)], 84, 84), ATT, "guide_slash_aviso.png")
    save(sheet([E.corte(k, 42) for k in range(4)], 84, 84), ATT, "guide_slash_corte.png")
    save(sheet([E.aviso(k, 8, 28) for k in range(8)], 56, 56), ATT, "guide_circulo_aviso.png")
    save(sheet([E.impacto(k, 28) for k in range(5)], 56, 56), ATT, "guide_circulo_explosao.png")
    laser_aviso()
    laser_feixe()
    gaiola()
    save(sheet([E.aviso(k, 6, 40) for k in range(6)], 80, 80), SPR, "robo_melee_aviso.png")
    save(sheet([E.impacto(k, 40) for k in range(5)], 80, 80), SPR, "robo_melee_impacto.png")


if __name__ == "__main__":
    main()
