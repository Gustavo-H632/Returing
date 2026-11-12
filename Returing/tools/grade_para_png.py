#!/usr/bin/env python3
"""Conversor mínimo e determinístico: grade de pixels em texto -> PNG.

Formato da grade (tools/pixel/*.txt): 1 caractere = 1 pixel; linhas que começam com '#' são comentários.
Legenda (cores de tools/paleta.txt):
  .  transparente      W  branco #fefefe        K  preto #020202
  G  dourado #fed232   g  dourado escuro #b8841a   L  dourado claro #fee286
  D  fundo escuro #1f1c2e    R  vermelho #f62626    B  azul #86befe
Uso: python3 tools/grade_para_png.py tools/pixel/arquivo.txt saida.png [escala]
"""
import sys
from PIL import Image

LEGENDA = {
    ".": (0, 0, 0, 0), "W": (254, 254, 254, 255), "K": (2, 2, 2, 255), "G": (254, 210, 50, 255),
    "g": (184, 132, 26, 255), "L": (254, 226, 134, 255), "D": (31, 28, 46, 255), "R": (246, 38, 38, 255),
    "B": (134, 190, 254, 255),
}


def ler_grade(caminho):
    with open(caminho, encoding="utf-8") as arquivo:
        linhas = [l.rstrip("\n") for l in arquivo if l.strip() and not l.startswith("#")]
    largura = max(len(l) for l in linhas)
    img = Image.new("RGBA", (largura, len(linhas)), (0, 0, 0, 0))
    for y, linha in enumerate(linhas):
        for x, c in enumerate(linha):
            img.putpixel((x, y), LEGENDA[c])
    return img


if __name__ == "__main__":
    img = ler_grade(sys.argv[1])
    escala = int(sys.argv[3]) if len(sys.argv) > 3 else 1
    if escala > 1:
        img = img.resize((img.width * escala, img.height * escala), Image.NEAREST)
    img.save(sys.argv[2])
