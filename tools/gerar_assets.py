#!/usr/bin/env python3
"""Gera os assets do modo celular do Returing em res://assets/gerados/.

Uso:  python3 tools/gerar_assets.py        (rode na raiz do projeto; é reexecutável e determinístico)

Estilo: pixel art 2D com a paleta do projeto (tools/paleta.txt). Os botões de toque seguem a
referência mobile_layout.png (cinza translúcido com traço branco) e são desenhados em alta
resolução com suavização, como os ícones do print. Molduras, setas, celular e ícones do app
usam apenas as cores da paleta, pixel a pixel, sem suavização.
"""
import math
import os
import sys

from PIL import Image, ImageDraw

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAIDA = os.path.join(RAIZ, "assets", "gerados")
os.makedirs(SAIDA, exist_ok=True)

# --- Paleta (tools/paleta.txt) ---
PRETO = (2, 2, 2, 255)
FUNDO_ESCURO = (7, 7, 12, 255)
BOTAO_ESCURO = (31, 28, 46, 255)
OURO_ESC = (184, 132, 26, 255)
OURO = (254, 210, 50, 255)
OURO_CLARO = (254, 226, 134, 255)
BRANCO = (254, 254, 254, 255)
CINZA_CLARO = (230, 230, 230, 255)
CINZA = (194, 194, 194, 255)
VERMELHO = (246, 38, 38, 255)
AZUL = (134, 190, 254, 255)
AZUL_CLARO = (214, 254, 254, 255)
MARROM_BG = (20, 16, 12, 255)
MARROM_PAINEL = (34, 26, 19, 255)
MARROM_BORDA = (90, 67, 38, 255)
TEXTO = (235, 221, 186, 255)
TRANSP = (0, 0, 0, 0)

SS = 4  # supersampling dos botões de toque


def salvar(img, nome):
    img.save(os.path.join(SAIDA, nome))
    print("  ", nome, img.size)


# ----------------------------------------------------------------------------
# Botões e analógicos (estilo do print: cinza translúcido, traço branco)
# ----------------------------------------------------------------------------
FILL = (158, 158, 158, 128)
FILL_PRESSED = (158, 158, 158, 184)
RING = (217, 217, 217, 128)
ICON = (255, 255, 255, 217)


def circulo(tam, preenchimento, anel, largura_anel):
    g = tam * SS
    im = Image.new("RGBA", (g, g), TRANSP)
    d = ImageDraw.Draw(im)
    d.ellipse((0, 0, g - 1, g - 1), fill=anel)
    r = largura_anel * SS
    d.ellipse((r, r, g - 1 - r, g - 1 - r), fill=preenchimento)
    return im.resize((tam, tam), Image.LANCZOS)


def lienzo(tam=128):
    return Image.new("RGBA", (tam * SS, tam * SS), TRANSP)


def reduz(im, tam=128):
    return im.resize((tam, tam), Image.LANCZOS)


def linha(d, pts, w, cor=ICON):
    """Polilinha com pontas arredondadas (coordenadas em unidades de 128)."""
    pts = [(x * SS, y * SS) for x, y in pts]
    d.line(pts, fill=cor, width=int(w * SS), joint="curve")
    r = w * SS / 2
    for x, y in (pts[0], pts[-1]):
        d.ellipse((x - r, y - r, x + r, y + r), fill=cor)


def icone_espada():
    im = lienzo(); d = ImageDraw.Draw(im)
    linha(d, [(38, 90), (92, 36)], 11)           # lâmina
    linha(d, [(34, 60), (68, 94)], 9)            # guarda
    d.ellipse(((26) * SS, (88) * SS, (40) * SS, (102) * SS), fill=ICON)  # pomo
    return reduz(im)


def icone_tiro():
    im = lienzo(); d = ImageDraw.Draw(im)
    d.ellipse((56 * SS, 56 * SS, 72 * SS, 72 * SS), fill=ICON)
    d.arc((38 * SS, 38 * SS, 90 * SS, 90 * SS), 0, 360, fill=ICON, width=6 * SS)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        linha(d, [(64 + dx * 28, 64 + dy * 28), (64 + dx * 44, 64 + dy * 44)], 6)
    return reduz(im)


def icone_dash():
    im = lienzo(); d = ImageDraw.Draw(im)
    linha(d, [(38, 40), (62, 64), (38, 88)], 10)
    linha(d, [(66, 40), (90, 64), (66, 88)], 10)
    return reduz(im)


def seta_arco(d, centro, raio, ang0, ang1, largura, ponta):
    """Arco com ponta de seta no fim (ângulos em graus, sentido horário na tela)."""
    cx, cy = centro
    pts = []
    n = 40
    for i in range(n + 1):
        a = math.radians(ang0 + (ang1 - ang0) * i / n)
        pts.append((cx + raio * math.cos(a), cy + raio * math.sin(a)))
    linha(d, pts, largura)
    a = math.radians(ang1)
    px, py = cx + raio * math.cos(a), cy + raio * math.sin(a)
    tang = a + math.pi / 2 * (1 if ang1 > ang0 else -1)
    for lado in (-1, 1):
        b = tang + math.pi + lado * math.radians(35)
        linha(d, [(px, py), (px + ponta * math.cos(b), py + ponta * math.sin(b))], largura)


def icone_trocar():
    """Trocar arma: duas setas circulares (ciclo)."""
    im = lienzo(); d = ImageDraw.Draw(im)
    seta_arco(d, (64, 64), 30, 200, 340, 9, 20)
    seta_arco(d, (64, 64), 30, 20, 160, 9, 20)
    return reduz(im)


def icone_comando():
    """Modo comando: quatro setas em cruz (as setas da sequência)."""
    im = lienzo(); d = ImageDraw.Draw(im)
    d.ellipse((57 * SS, 57 * SS, 71 * SS, 71 * SS), fill=ICON)
    for ang in (0, 90, 180, 270):
        a = math.radians(ang)
        c, s = math.cos(a), math.sin(a)
        def p(x, y):
            return (64 + x * c - y * s, 64 + x * s + y * c)
        linha(d, [p(26, -12), p(40, 0), p(26, 12)], 9)
    return reduz(im)


def icone_pausa():
    im = lienzo(); d = ImageDraw.Draw(im)
    d.rounded_rectangle((40 * SS, 34 * SS, 56 * SS, 94 * SS), radius=3 * SS, fill=ICON)
    d.rounded_rectangle((72 * SS, 34 * SS, 88 * SS, 94 * SS), radius=3 * SS, fill=ICON)
    return reduz(im)


def icone_interagir():
    im = lienzo(); d = ImageDraw.Draw(im)
    linha(d, [(84, 34), (46, 34), (46, 94), (84, 94)], 11)
    linha(d, [(46, 64), (78, 64)], 11)
    return reduz(im)


def gerar_botoes():
    print("Botões de toque")
    salvar(circulo(128, FILL, RING, 4), "btn_base.png")
    salvar(circulo(128, FILL_PRESSED, RING, 4), "btn_base_pressed.png")
    salvar(icone_espada(), "ic_sword.png")
    salvar(icone_tiro(), "ic_shot.png")
    salvar(icone_dash(), "ic_dash.png")
    salvar(icone_trocar(), "ic_swap.png")
    salvar(icone_comando(), "ic_command.png")
    salvar(icone_pausa(), "ic_pause.png")
    salvar(icone_interagir(), "ic_interact.png")
    # Analógicos: base grande e bolinha.
    salvar(circulo(256, (158, 158, 158, 71), RING, 4), "stick_base.png")
    salvar(circulo(128, FILL, RING, 3), "stick_thumb.png")
    salvar(circulo(128, FILL_PRESSED, RING, 3), "stick_thumb_pressed.png")


# ----------------------------------------------------------------------------
# Pixel art
# ----------------------------------------------------------------------------
def px_rect(im, x0, y0, x1, y1, cor):
    ImageDraw.Draw(im).rectangle((x0, y0, x1, y1), fill=cor)


def gerar_moldura():
    """Moldura do quadro de comandos: a moldura dourada do jogo (panel_gold) com interior translúcido."""
    print("Moldura do quadro de comandos")
    fonte = os.path.join(RAIZ, "ui", "theme", "panel_gold.png")
    im = Image.open(fonte).convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a > 0 and (r, g, b) in ((7, 7, 12), (2, 2, 2)) and 4 <= x < im.width - 4 and 4 <= y < im.height - 4:
                pass
    # Interior (cor FUNDO_ESCURO / variações) fica translúcido: só o que está dentro do miolo.
    for y in range(8, im.height - 8):
        for x in range(8, im.width - 8):
            r, g, b, a = px[x, y]
            if a > 0 and r < 60 and g < 60 and b < 60:
                px[x, y] = (r, g, b, 214)
    salvar(im, "board_frame.png")


SETAS = {
    # polígono da seta apontando para cima em grade 16x16 (x, y)
    "up": [(8, 1), (14, 8), (10, 8), (10, 14), (6, 14), (6, 8), (2, 8)],
}


def gira(pts, graus, c=7.5):
    a = math.radians(graus)
    out = []
    for x, y in pts:
        x -= c; y -= c
        out.append((c + x * math.cos(a) - y * math.sin(a), c + x * math.sin(a) + y * math.cos(a)))
    return out


def seta_px(direcao, preenchimento, contorno, brilho):
    """Seta pixel art 16x16 com contorno de 1 px."""
    ang = {"up": 0, "right": 90, "down": 180, "left": 270}[direcao]
    pts = gira(SETAS["up"], ang)
    big = Image.new("L", (160, 160), 0)
    ImageDraw.Draw(big).polygon([(x * 10 + 5, y * 10 + 5) for x, y in pts], fill=255)
    mask = big.resize((16, 16), Image.NEAREST).point(lambda v: 255 if v > 127 else 0)
    im = Image.new("RGBA", (16, 16), TRANSP)
    p = im.load(); m = mask.load()
    for y in range(16):
        for x in range(16):
            if m[x, y]:
                p[x, y] = preenchimento
    # contorno
    for y in range(16):
        for x in range(16):
            if not m[x, y]:
                vizinho = any(0 <= x + dx < 16 and 0 <= y + dy < 16 and m[x + dx, y + dy]
                              for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if vizinho:
                    p[x, y] = contorno
    # brilho (1 px na quina de cima/esquerda do preenchimento)
    for y in range(16):
        for x in range(16):
            if m[x, y] and (x == 0 or not m[x - 1, y]) and y > 0 and brilho is not None:
                p[x, y] = brilho
    return im


def gerar_setas():
    print("Setas do modo comando")
    for d in ("up", "down", "left", "right"):
        salvar(seta_px(d, OURO, PRETO, OURO_CLARO), f"arrow_{d}.png")
        salvar(seta_px(d, BRANCO, OURO, None), f"arrow_{d}_lit.png")
        salvar(seta_px(d, (60, 56, 72, 255), PRETO, None), f"arrow_{d}_off.png")


def gerar_dpad():
    """D-pad de fallback (sem acelerômetro): placa em cruz de 64x64."""
    print("D-pad de fallback")
    im = Image.new("RGBA", (64, 64), TRANSP)
    d = ImageDraw.Draw(im)
    cruz = [(22, 0), (41, 0), (41, 22), (63, 22), (63, 41), (41, 41), (41, 63), (22, 63), (22, 41), (0, 41), (0, 22), (22, 22)]
    d.polygon(cruz, fill=PRETO)
    inner = [(23, 2), (40, 2), (40, 23), (61, 23), (61, 40), (40, 40), (40, 61), (23, 61), (23, 40), (2, 40), (2, 23), (23, 23)]
    d.polygon(inner, fill=OURO)
    inner2 = [(24, 4), (39, 4), (39, 24), (59, 24), (59, 39), (39, 39), (39, 59), (24, 59), (24, 39), (4, 39), (4, 24), (24, 24)]
    d.polygon(inner2, fill=BOTAO_ESCURO)
    # sombra dourada embaixo
    d.line([(24, 59), (39, 59)], fill=OURO_ESC)
    d.line([(59, 39), (59, 24)], fill=OURO_ESC)
    d.line([(4, 24), (24, 24)], fill=OURO_ESC)
    salvar(im, "dpad_base.png")


def gerar_inclinacao():
    """Indicador de inclinação: anel com marcas e a 'bolinha' que acompanha o celular."""
    print("Indicador de inclinação")
    n = 64
    im = Image.new("RGBA", (n, n), TRANSP)
    d = ImageDraw.Draw(im)
    d.ellipse((0, 0, n - 1, n - 1), fill=PRETO)
    d.ellipse((2, 2, n - 3, n - 3), fill=OURO)
    d.ellipse((4, 4, n - 5, n - 5), fill=OURO_ESC)
    d.ellipse((6, 6, n - 7, n - 7), fill=PRETO)
    d.ellipse((7, 7, n - 8, n - 8), fill=FUNDO_ESCURO)
    # marcas nos 4 lados e cruz central
    c = n // 2
    for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        for k in range(10, 16):
            d.point((c + dx * (k + 8), c + dy * (k + 8)), fill=OURO_CLARO)
    d.line([(c - 3, c), (c + 3, c)], fill=OURO_ESC)
    d.line([(c, c - 3), (c, c + 3)], fill=OURO_ESC)
    salvar(im, "tilt_ring.png")
    dot = Image.new("RGBA", (12, 12), TRANSP)
    dd = ImageDraw.Draw(dot)
    dd.ellipse((0, 0, 11, 11), fill=PRETO)
    dd.ellipse((1, 1, 10, 10), fill=AZUL)
    dd.ellipse((2, 2, 6, 6), fill=AZUL_CLARO)
    salvar(dot, "tilt_dot.png")


def gerar_celular():
    """Celular em paisagem em 5 poses (neutro e inclinado nas 4 direções), pixel art 96x64."""
    print("Celular (tutorial)")
    def base():
        return Image.new("RGBA", (96, 64), TRANSP)
    def corpo(d, pts, tela):
        d.polygon(pts, fill=PRETO)
    # retângulo do celular visto de cima (neutro)
    def desenha(pose):
        im = base(); d = ImageDraw.Draw(im)
        # coordenadas das 4 quinas: topo-esq, topo-dir, base-dir, base-esq
        L, R, T, B = 12, 84, 10, 54
        q = [(L, T), (R, T), (R, B), (L, B)]
        if pose == "left":    # borda esquerda desce: encurta a esquerda
            q = [(L + 4, T + 6), (R, T), (R, B), (L + 4, B - 6)]
        elif pose == "right":
            q = [(L, T), (R - 4, T + 6), (R - 4, B - 6), (L, B)]
        elif pose == "up":    # topo para longe: encurta o topo
            q = [(L + 8, T + 2), (R - 8, T + 2), (R, B), (L, B)]
        elif pose == "down":
            q = [(L, T), (R, T), (R - 8, B - 2), (L + 8, B - 2)]
        d.polygon(q, fill=PRETO)
        def encolhe(q, k):
            cx = sum(p[0] for p in q) / 4; cy = sum(p[1] for p in q) / 4
            return [(cx + (x - cx) * (1 - k / 36.0), cy + (y - cy) * (1 - k / 22.0)) for x, y in q]
        q2 = encolhe(q, 1.5)
        d.polygon(q2, fill=OURO)
        q3 = encolhe(q, 3)
        d.polygon(q3, fill=BOTAO_ESCURO)
        q4 = encolhe(q, 6)
        d.polygon(q4, fill=AZUL)
        # "tela": mini jogo (jogador e robô)
        cx = sum(p[0] for p in q4) / 4; cy = sum(p[1] for p in q4) / 4
        d.rectangle((cx - 12, cy + 1, cx - 8, cy + 8), fill=OURO_CLARO)
        d.rectangle((cx + 8, cy - 8, cx + 13, cy - 2), fill=VERMELHO)
        d.line([(q4[0][0] + 2, q4[0][1] + 2), (q4[1][0] - 2, q4[1][1] + 2)], fill=AZUL_CLARO)
        return im
    for pose in ("neutral", "up", "down", "left", "right"):
        salvar(desenha(pose), f"phone_{pose}.png")


def gerar_joystick_demo():
    """4 quadros do analógico com a bolinha deslocada (tutorial de movimento)."""
    print("Quadros do analógico (tutorial)")
    base = Image.open(os.path.join(SAIDA, "stick_base.png")).convert("RGBA")
    thumb = Image.open(os.path.join(SAIDA, "stick_thumb.png")).convert("RGBA")
    for i, (dx, dy) in enumerate(((0, -1), (1, 0), (0, 1), (-1, 0))):
        im = base.copy()
        im.alpha_composite(thumb, (64 + dx * 56, 64 + dy * 56))
        salvar(im, f"joy_demo_{i}.png")


def gerar_brilho():
    """Anel dourado que pisca ao redor do controle da vez (2 quadros: normal e brilho)."""
    print("Brilho de destaque")
    for i, (cor, esp) in enumerate(((OURO, 4), (OURO_CLARO, 6))):
        im = Image.new("RGBA", (256 * SS, 256 * SS), TRANSP)
        d = ImageDraw.Draw(im)
        g = 256 * SS
        d.ellipse((0, 0, g - 1, g - 1), fill=cor[:3] + (200,))
        r = esp * 2 * SS
        d.ellipse((r, r, g - 1 - r, g - 1 - r), fill=TRANSP)
        salvar(im.resize((256, 256), Image.LANCZOS), f"glow_{i}.png")


# ----------------------------------------------------------------------------
# Ícones do app
# ----------------------------------------------------------------------------
def arte_turing(tam):
    """Frame de frente do Turing (spritesheet 6x6), recortado e ampliado sem suavização."""
    sheet = Image.open(os.path.join(RAIZ, "sprites", "turing.png")).convert("RGBA")
    f = sheet.width // 6
    frame = sheet.crop((0, 0, f, f))
    bbox = frame.getbbox()
    frame = frame.crop(bbox)
    esc = min(tam / frame.width, tam / frame.height)
    return frame.resize((max(1, int(frame.width * esc)), max(1, int(frame.height * esc))), Image.NEAREST)


def icone_app(tam, cantos=True, margem=0.1, plano=False):
    im = Image.new("RGBA", (tam, tam), MARROM_BG)
    d = ImageDraw.Draw(im)
    u = tam // 64  # "pixel" do ícone (64 px lógicos)
    # moldura dourada
    for i, cor in enumerate((PRETO, OURO, OURO_ESC, PRETO)):
        d.rectangle((i * u, i * u, tam - 1 - i * u, tam - 1 - i * u), outline=cor, width=u)
    d.rectangle((4 * u, 4 * u, tam - 1 - 4 * u, tam - 1 - 4 * u), fill=MARROM_PAINEL)
    # listras de "scanline"
    for y in range(5 * u, tam - 5 * u, 4 * u):
        d.rectangle((5 * u, y, tam - 1 - 5 * u, y + u - 1), fill=(40, 31, 22, 255))
    alvo = int(tam * (1 - 2 * margem) * 0.8)
    t = arte_turing(alvo)
    im.alpha_composite(t, ((tam - t.width) // 2, (tam - t.height) // 2 + u * 2))
    if cantos and not plano:
        mask = Image.new("L", (tam, tam), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, tam - 1, tam - 1), radius=tam // 6, fill=255)
        out = Image.new("RGBA", (tam, tam), TRANSP)
        out.paste(im, (0, 0), mask)
        return out
    return im


def gerar_icones():
    print("Ícones do app")
    salvar(icone_app(1024), "icone_app_1024.png")
    salvar(icone_app(512), "icone_app_512.png")
    salvar(icone_app(192), "icone_android_192.png")
    # iOS: quadrado, sem transparência (a Apple aplica os cantos).
    ios = icone_app(1024, cantos=False).convert("RGB")
    ios.save(os.path.join(SAIDA, "icone_ios_1024.png")); print("   icone_ios_1024.png (1024, 1024)")
    # Android adaptativo: fundo e primeiro plano (a máscara do sistema corta as bordas).
    fundo = Image.new("RGBA", (432, 432), MARROM_BG)
    dd = ImageDraw.Draw(fundo)
    for y in range(0, 432, 12):
        dd.rectangle((0, y, 431, y + 2), fill=(40, 31, 22, 255))
    salvar(fundo, "adaptive_bg_432.png")
    fg = Image.new("RGBA", (432, 432), TRANSP)
    t = arte_turing(190)
    fg.alpha_composite(t, ((432 - t.width) // 2, (432 - t.height) // 2))
    salvar(fg, "adaptive_fg_432.png")
    # Windows (.ico com vários tamanhos) e macOS (.icns).
    base = icone_app(256)
    base.save(os.path.join(SAIDA, "icone_win.ico"), sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    print("   icone_win.ico")
    icone_app(1024).save(os.path.join(SAIDA, "icone_mac.icns"))
    print("   icone_mac.icns")
    # Tela de abertura do iOS (retrato 1242x2688 e fundo liso com a arte no centro).
    w, h = 1242, 2688
    splash = Image.new("RGBA", (w, h), MARROM_BG)
    sd = ImageDraw.Draw(splash)
    for y in range(0, h, 12):
        sd.rectangle((0, y, w - 1, y + 2), fill=(40, 31, 22, 255))
    ic = icone_app(512)
    splash.alpha_composite(ic, ((w - 512) // 2, (h - 512) // 2))
    salvar(splash, "splash_ios.png")


def main():
    # Botões, joysticks e ícones dos controles agora vêm de tools/gerar_controles.py (pixel art, grades em tools/pixel/).
    gerar_moldura()
    gerar_setas()
    gerar_dpad()
    gerar_inclinacao()
    gerar_celular()
    gerar_brilho()
    gerar_icones()
    print("Assets gerados em", SAIDA)


if __name__ == "__main__":
    sys.exit(main())
