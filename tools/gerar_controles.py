#!/usr/bin/env python3
"""Sprites dos controles de toque em pixel art, no estilo das molduras douradas do HUD.

  python3 tools/gerar_controles.py        (na raiz do projeto; determinístico)

- Ícones: desenhados à mão em grades de texto (tools/pixel/ic_*.txt), convertidos por tools/grade_para_png.py;
  recebem um contorno preto de 1 px para lerem bem sobre qualquer cenário.
- Discos (base dos botões, base e bolinha dos joysticks): círculos em pixel art (resolução base 32/64 px) com
  contorno preto, anel dourado em 3 tons (luz vinda do alto-esquerda, como nas molduras do HUD) e miolo escuro
  translúcido. Só as cores de tools/paleta.txt.
- Tudo é exportado ampliado 4x (pixels nítidos) em assets/gerados/.
"""
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from grade_para_png import ler_grade  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAIDA = os.path.join(RAIZ, "assets", "gerados")
PIXEL = os.path.join(RAIZ, "tools", "pixel")
ESCALA = 4

PRETO = (2, 2, 2)
OURO = (254, 210, 50)
OURO_ESC = (184, 132, 26)
OURO_CLARO = (254, 226, 134)
MIOLO = (31, 28, 46)
MARROM = (90, 67, 38)


def disco(tam, anel, alfa_miolo, cor_miolo=MIOLO, apertado=False):
    """Disco em pixel art: contorno preto de 1 px, anel dourado de `anel` px e miolo translúcido."""
    img = Image.new("RGBA", (tam, tam), (0, 0, 0, 0))
    c = (tam - 1) / 2.0
    raio = tam / 2.0
    for y in range(tam):
        for x in range(tam):
            dx, dy = x - c, y - c
            d = math.hypot(dx, dy)
            if d > raio - 0.3:
                continue
            if d > raio - 1.3:
                img.putpixel((x, y), PRETO + (255,))
            elif d > raio - 1.3 - anel:
                lado = (-dx - dy) / (d + 0.001)  # > 0 no alto-esquerda (lado da luz)
                if apertado:
                    cor = OURO_CLARO if lado > -0.4 else OURO
                else:
                    cor = OURO_CLARO if lado > 0.75 else (OURO_ESC if lado < -0.75 else OURO)
                img.putpixel((x, y), cor + (255,))
            elif d > raio - 2.3 - anel:
                img.putpixel((x, y), PRETO + (min(255, alfa_miolo + 60),))
            else:
                img.putpixel((x, y), cor_miolo + (alfa_miolo,))
    return img


def com_contorno(img):
    """Contorno preto de 1 px em volta dos pixels opacos."""
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if img.getpixel((x, y))[3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and img.getpixel((nx, ny))[3] > 0:
                    out.putpixel((x, y), PRETO + (255,))
                    break
    out.alpha_composite(img)
    return out


def icone(nome, tela=32):
    grade = ler_grade(os.path.join(PIXEL, nome + ".txt"))
    img = Image.new("RGBA", (tela, tela), (0, 0, 0, 0))
    img.alpha_composite(grade, ((tela - grade.width) // 2, (tela - grade.height) // 2))
    return com_contorno(img)


def salvar(img, nome):
    img = img.resize((img.width * ESCALA, img.height * ESCALA), Image.NEAREST)
    img.save(os.path.join(SAIDA, nome))
    print("  ", nome, img.size)


def main():
    salvar(disco(32, 2, 150), "btn_base.png")
    salvar(disco(32, 2, 215, MARROM, apertado=True), "btn_base_pressed.png")
    salvar(disco(64, 2, 70), "stick_base.png")
    salvar(disco(32, 3, 205), "stick_thumb.png")
    salvar(disco(32, 3, 235, MARROM, apertado=True), "stick_thumb_pressed.png")
    for nome in ("ic_dash", "ic_pause", "ic_interact", "ic_command", "ic_swap", "ic_sword", "ic_shot"):
        salvar(icone(nome), nome + ".png")
    # Ilustração do tutorial: joystick com a bolinha deslocada para cima, direita, baixo e esquerda.
    base = disco(64, 2, 70)
    bolinha = disco(28, 3, 205)
    for i, (dx, dy) in enumerate(((0, -11), (11, 0), (0, 11), (-11, 0))):
        quadro = base.copy()
        quadro.alpha_composite(bolinha, (18 + dx, 18 + dy))
        salvar(quadro, "joy_demo_%d.png" % i)


if __name__ == "__main__":
    main()
