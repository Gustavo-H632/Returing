#!/usr/bin/env python3
"""Escreve Scenes/Fase5/Camara.tscn a partir da planta (tools/camara_layout.py).

Uso (na raiz do projeto):   python tools/gerar_cena_camara.py

IMPORTANTE: isto roda UMA VEZ, aqui, e grava texto .tscn comum. O jogo NÃO usa TileMap, TileSet, arquivo de
mapa nem geração em tempo de execução: as colisões, as máquinas, os emissores (feixe + aviso), as portas, os
gatilhos e o fogo são nós ESTÁTICOS dentro do .tscn, alinhados à arte pelos mesmos números da planta.
Você pode abrir a cena no editor e mexer em qualquer nó à mão (a ordem dos filhos de Sala3 é a ordem de disparo).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import camara_layout as C  # noqa: E402
import gerar_cena_fase2 as G  # noqa: E402  (reaproveita a classe Scene e os formatadores)

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "Scenes", "Fase5", "Camara.tscn")
n, v2 = G.n, G.v2

SCRIPT = lambda s, name: s.res(f"res://Scenes/Fase5/{name}", "Script")
ARTE = lambda s, name: s.res(f"res://assets/camara/{name}", "Texture2D")


def np_(path):
    return f'NodePath("{path}")'


def sprite(s, nome, parent, tex, pos, z, hframes=None, extra=None, scale=2):
    props = {"z_index": z, "texture_filter": 1, "position": v2(*pos), "scale": v2(scale, scale), "texture": tex}
    if hframes:
        props["hframes"] = hframes
    props.update(extra or {})
    s.node(nome, "Sprite2D", parent, props)


def area(s, nome, parent, pos, w, h, mask=2, extra=None, node_paths=None):
    p = {"position": v2(*pos), "collision_layer": 0, "collision_mask": mask, "monitorable": "false"}
    p.update(extra or {})
    s.node(nome, "Area2D", parent, p, node_paths=node_paths)
    s.node("Colisao", "CollisionShape2D", f"{parent}/{nome}" if parent != "." else nome, {"shape": s.rect_shape(w, h)})


def centro_rect(r):
    return (r[0] + r[2] / 2.0, r[1] + r[3] / 2.0)


def sufixo(boca, ref):
    return f"maquina_{boca}{'_ref' if ref else ''}.png"


def textura_aviso(nome):
    g = C.geometria(nome)
    m = C.MAQUINAS[nome]
    dx, dy = g["dir"]
    flip = {}
    if m["sala"] == 1:
        arq = "raio_aviso_corredor.png"
        flip = {"flip_h": "true"} if dx < 0 else {}
    elif m["sala"] == 2:
        arq, flip = "raio_aviso_sala2.png", {}
    elif dx == 0:
        arq = "raio_aviso_faixa_v.png"
        flip = {"flip_v": "true"} if dy < 0 else {}
    else:
        arq = "raio_aviso_banda_h.png"
        flip = {"flip_h": "true"} if dx < 0 else {}
    return arq, flip


def textura_feixe(nome):
    g = C.geometria(nome)
    vert = g["dir"][0] != 0          # a linha é vertical quando a máquina varre em x
    return f"raio_feixe_{'v' if vert else 'h'}{g['comprimento']}.png", vert


def construir_maquina(s, nome, parent):
    g = C.geometria(nome)
    m = C.MAQUINAS[nome]
    cx, cy = g["centro"]
    caminho = f"{parent}/{nome}" if parent != "." else nome
    dx, dy = g["dir"]
    destr = g["destrutivel"]
    paths = ["corpo", "aviso", "feixe", "feixe_forma", "feixe_imagem", "explosao"] + (["hurtbox", "saude"] if destr else [])
    props = {
        "position": v2(cx, cy), "script": SCRIPT(s, "camara_maquina.gd"),
        "tempo_aviso": n(C.T_AVISO), "tempo_clarao": n(C.T_CLARAO), "tempo_varredura": n(C.T_VARREDURA),
        "tempo_pausa": n(C.T_PAUSA), "direcao": v2(dx, dy), "distancia": f"{g['distancia']:.1f}",
        "destrutivel": "true" if destr else "false", "reforcada": "true" if g["reforcada"] else "false",
        "dano_minimo": C.DANO_MINIMO,
        "corpo": np_("Corpo"), "aviso": np_("Aviso"), "feixe": np_("Feixe"), "feixe_forma": np_("Feixe/Forma"),
        "feixe_imagem": np_("Feixe/Imagem"), "explosao": np_("Explosao"),
    }
    if destr:
        props["hurtbox"] = np_("Hurtbox")
        props["saude"] = np_("Saude")
    s.node(nome, "Node2D", parent, props, node_paths=paths)

    # corpo (6 quadros) e aviso (4 quadros) -- por baixo do jogador
    sprite(s, "Corpo", caminho, ARTE(s, sufixo(g["boca"], g["reforcada"])), (0, 0), -5, hframes=6)
    arq, flip = textura_aviso(nome)
    fcx, fcy = centro_rect(g["faixa"])
    sprite(s, "Aviso", caminho, ARTE(s, arq), (fcx - cx, fcy - cy), -3, hframes=4,
           extra=dict({"visible": "false"}, **flip))

    # feixe: a Hitbox do projeto (camada 4 = hurtboxes_player -> máscara 8), começa desligada
    if dx == 0:
        ini = (g["perp"], g["inicio"])
        w, h = g["comprimento"], C.BEAM_T
    else:
        ini = (g["inicio"], g["perp"])
        w, h = C.BEAM_T, g["comprimento"]
    s.node("Feixe", "Area2D", caminho, {
        "position": v2(ini[0] - cx, ini[1] - cy), "z_index": 5, "visible": "false",
        "collision_layer": 0, "collision_mask": 8, "monitorable": "false",
        "script": s.res("res://common/combat/hitbox.gd", "Script"),
        "damage": 120, "active_on_start": "false", "one_hit_per_target": "false", "tick_interval": "0.15",
        "source": np_(".."),
    }, node_paths=["source"])
    s.node("Forma", "CollisionShape2D", f"{caminho}/Feixe", {"shape": s.rect_shape(w, h), "disabled": "true"})
    farq, _ = textura_feixe(nome)
    sprite(s, "Imagem", f"{caminho}/Feixe", ARTE(s, farq), (0, 0), 0, hframes=4)

    # hurtbox na camada 1 (só o tiro, máscara 17, a enxerga; a espada lê só a camada 5) + vida do projeto
    if destr:
        hx, hy, hw, hh = g["hurt"]
        s.node("Hurtbox", "Area2D", caminho, {
            "position": v2(hx + hw / 2 - cx, hy + hh / 2 - cy), "collision_layer": 1, "collision_mask": 0,
            "script": s.res("res://common/combat/hurtbox.gd", "Script"), "actor": np_("..")},
            node_paths=["actor"])
        s.node("Forma", "CollisionShape2D", f"{caminho}/Hurtbox", {"shape": s.rect_shape(hw, hh)})
        s.node("Saude", "Node", caminho, {
            "script": s.res("res://common/combat/health_component.gd", "Script"),
            "max_health": 2 if g["reforcada"] else 1})
    sprite(s, "Explosao", caminho, ARTE(s, "maquina_explosao.png"), (0, 0), 6, hframes=5, extra={"visible": "false"})


def construir():
    s = G.Scene()
    s.node("Camara", "Node2D", None, {
        "script": SCRIPT(s, "camara.gd"),
        "sala1": np_("Sala1"), "sala2": np_("Sala2"), "sala3": np_("Sala3"),
        "porta1": np_("Portas/Porta1"), "porta2": np_("Portas/Porta2"), "porta_final": np_("Portas/PortaFinal"),
        "entrada1": np_("Gatilhos/EntradaSala1"), "entrada2": np_("Gatilhos/EntradaSala2"),
        "entrada3": np_("Gatilhos/EntradaSala3"), "saida": np_("Gatilhos/Saida"),
        "player": np_("Player"), "hud": np_("HudCamara"),
    }, node_paths=["sala1", "sala2", "sala3", "porta1", "porta2", "porta_final", "entrada1", "entrada2",
                   "entrada3", "saida", "player", "hud"])

    s.node("Musica", "AudioStreamPlayer", ".", {
        "stream": s.res("res://Sounds/Musics/Sci-Fi 4 Loop.wav", "AudioStream"),
        "autoplay": "true", "bus": '&"Music"'})

    # ---------------------------------------------------------------- ARTE (sprites prontos)
    s.node("Arte", "Node2D", ".")
    for nome, arq, z in (("Piso", "camara_piso.png", -20), ("Faixas", "camara_faixas.png", -18),
                         ("Decoracao", "camara_decoracao.png", -17), ("Paredes", "camara_paredes.png", -10)):
        sprite(s, nome, "Arte", ARTE(s, arq), (0, 0), z, extra={"centered": "false"})
    sx, sy = C.START
    sprite(s, "PlataformaInicio", "Arte", ARTE(s, "plataforma_inicio.png"), (sx, sy), -16)

    # ---------------------------------------------------------------- COLISÕES (mundo = camada 1)
    s.node("Colisoes", "StaticBody2D", ".", {"collision_layer": 1, "collision_mask": 0})
    for i, (x, y, w, h) in enumerate(C.wall_rects(), 1):
        s.node(f"Parede{i:02d}", "CollisionShape2D", "Colisoes", {
            "position": v2(x + w / 2, y + h / 2), "shape": s.rect_shape(w, h)})
    for nome in C.MAQUINAS:     # reforço sólido logo à frente da parede de cada máquina
        x, y, w, h = C.geometria(nome)["solido"]
        s.node(f"Reforco{nome}", "CollisionShape2D", "Colisoes", {
            "position": v2(x + w / 2, y + h / 2), "shape": s.rect_shape(w, h)})

    # ---------------------------------------------------------------- FOGO da Sala 1 (FireHazard do projeto)
    fx, fy, fw, fh = C.FOGO
    area(s, "Fogo", ".", (fx + fw / 2, fy + fh / 2), fw, fh, extra={
        "script": s.res("res://Scenes/Fase2/fire_hazard.gd", "Script"), "sprite": np_("Sprite2D")},
        node_paths=["sprite"])
    sprite(s, "Sprite2D", "Fogo", s.res("res://assets/arena/fogo_corredor_horizontal.png", "Texture2D"),
           (0, 0), -8, hframes=4)

    # ---------------------------------------------------------------- SALAS (cronograma + máquinas filhas, em ordem)
    for numero, ordem in ((1, C.ORDEM_SALA1), (2, C.ORDEM_SALA2), (3, C.ORDEM_SALA3)):
        s.node(f"Sala{numero}", "Node", ".", {
            "script": SCRIPT(s, "camara_sequenciador.gd"),
            "intervalo_disparos": n(C.intervalo_de(numero)), "atraso_inicial": n(C.ATRASO_INICIAL[numero])})
        for nome in ordem:
            construir_maquina(s, nome, f"Sala{numero}")

    # ---------------------------------------------------------------- PORTAS
    s.node("Portas", "Node2D", ".")
    for nome, p in C.PORTAS.items():
        cx, cy = p["c"]
        o = p["o"]
        bx, by, bw, bh = C.door_blocker(nome)
        paths = ["sprite", "colisao", "contador"]
        s.node(nome, "Node2D", "Portas", {
            "position": v2(cx, cy), "script": SCRIPT(s, "camara_porta.gd"),
            "aberta_ao_iniciar": "true" if p["aberta"] else "false",
            "tex_trancada": ARTE(s, f"porta_{o}_trancada.png"), "tex_aberta": ARTE(s, f"porta_{o}_aberta.png"),
            "sprite": np_("Sprite2D"), "colisao": np_("Corpo/Colisao"), "contador": np_("Contador")},
            node_paths=paths)
        sprite(s, "Sprite2D", f"Portas/{nome}", ARTE(s, f"porta_{o}_trancada.png"), (0, 0), -4)
        s.node("Corpo", "StaticBody2D", f"Portas/{nome}", {"collision_layer": 1, "collision_mask": 0})
        s.node("Colisao", "CollisionShape2D", f"Portas/{nome}/Corpo", {"shape": s.rect_shape(bw, bh)})
        s.node("Contador", "Label", f"Portas/{nome}", {
            "z_index": -3, "position": v2(-14, -11), "size": v2(28, 22),
            "theme": s.res("res://themes/main_theme.tres", "Theme"),
            "theme_override_colors/font_color": "Color(1, 0.35, 0.35, 1)",
            "theme_override_colors/font_outline_color": "Color(0, 0, 0, 1)",
            "theme_override_constants/outline_size": 3, "theme_override_font_sizes/font_size": 16,
            "horizontal_alignment": 1, "vertical_alignment": 1, "text": f'"{p["contador"]}"'})

    # ---------------------------------------------------------------- GATILHOS
    s.node("Gatilhos", "Node2D", ".")
    for nome, r in C.ENTRADAS.items():
        area(s, nome, "Gatilhos", centro_rect(r), r[2], r[3])
    area(s, "Saida", "Gatilhos", centro_rect(C.SAIDA), C.SAIDA[2], C.SAIDA[3])

    # ---------------------------------------------------------------- PLAYER (o Turing.tscn do projeto)
    s.node("Player", None, ".", {
        "position": v2(*C.START),
        # Dash: 560 px/s x 0,30 s = 168 px, 1 s de recarga, invulnerável durante todo o dash.
        "dash_speed": "560.0", "dash_duration": "0.3", "dash_cooldown": "1.0", "iframes_duration": "0.34",
    }, instance=s.res("res://characters/turing/Turing.tscn", "PackedScene"))
    s.node("Camera2D", "Camera2D", "Player", {
        "limit_left": 0, "limit_top": 0, "limit_right": C.WORLD_W, "limit_bottom": C.WORLD_H})

    # ---------------------------------------------------------------- HUD do projeto + HUD da câmara
    s.node("HUD", None, ".", None, instance=s.res("res://ui/hud/hud.tscn", "PackedScene"))
    theme = s.res("res://themes/main_theme.tres", "Theme")
    outline = {"theme_override_colors/font_outline_color": "Color(0, 0, 0, 0.9)",
               "theme_override_constants/outline_size": 4}
    s.node("HudCamara", "CanvasLayer", ".", {
        "layer": 11, "script": SCRIPT(s, "camara_hud.gd"),
        "objetivo": np_("Raiz/Objetivo"), "maquinas": np_("Raiz/Maquinas"), "aviso": np_("Raiz/Aviso")},
        node_paths=["objetivo", "maquinas", "aviso"])
    s.node("Raiz", "Control", "HudCamara", {
        "layout_mode": 3, "anchors_preset": 15, "anchor_right": "1.0", "anchor_bottom": "1.0",
        "grow_horizontal": 2, "grow_vertical": 2, "mouse_filter": 2, "theme": theme})
    s.node("Objetivo", "Label", "HudCamara/Raiz", dict({
        "layout_mode": 1, "offset_left": "16.0", "offset_top": "16.0", "offset_right": "1100.0", "offset_bottom": "44.0",
        "theme_override_font_sizes/font_size": 18, "text": '"Atravesse o corredor."'}, **outline))
    s.node("Maquinas", "Label", "HudCamara/Raiz", dict({
        "layout_mode": 1, "offset_left": "16.0", "offset_top": "46.0", "offset_right": "360.0", "offset_bottom": "70.0",
        "theme_override_font_sizes/font_size": 18, "text": '"Máquinas 0/10"'}, **outline))
    s.node("Aviso", "Label", "HudCamara/Raiz", dict({
        "layout_mode": 1, "anchors_preset": 12, "anchor_top": "1.0", "anchor_right": "1.0", "anchor_bottom": "1.0",
        "offset_top": "-232.0", "offset_bottom": "-196.0", "grow_horizontal": 2, "grow_vertical": 0,
        "theme_override_font_sizes/font_size": 22, "horizontal_alignment": 1, "vertical_alignment": 1,
        "text": '""'}, **outline))

    # ---------------------------------------------------------------- Depuração (F3)
    s.node("Depuracao", "CanvasLayer", ".", {
        "layer": 20, "script": SCRIPT(s, "camara_debug.gd"),
        "colisoes": np_("../Colisoes"), "linhas": np_("Linhas"), "rotulo": np_("Rotulo")},
        node_paths=["colisoes", "linhas", "rotulo"])
    s.node("Linhas", "Node2D", "Depuracao", {"script": SCRIPT(s, "camara_debug_linhas.gd"), "visible": "false"})
    s.node("Rotulo", "Label", "Depuracao", dict({
        "visible": "false", "offset_left": "16.0", "offset_top": "96.0", "offset_right": "900.0", "offset_bottom": "420.0",
        "theme_override_font_sizes/font_size": 13, "text": '"F3"'}, **outline))

    s.node("Pause", None, ".", None, instance=s.res("res://ui/pause.tscn", "PackedScene"))
    return s


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sc = construir()
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(sc.text())
    print("Camara.tscn", len(sc.nodes), "nós,", len(sc.sub), "sub-recursos,", len(sc.ext), "recursos externos")


if __name__ == "__main__":
    main()
