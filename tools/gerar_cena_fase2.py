#!/usr/bin/env python3
"""Escreve Labirinto.tscn e SalaNova.tscn a partir da planta (tools/fase2_layout.py).

Uso (na raiz do projeto):   python tools/gerar_cena_fase2.py

IMPORTANTE: isto roda UMA VEZ, aqui, e grava texto .tscn comum. O jogo NÃO usa TileMap, TileSet, arquivo
de mapa nem geração em tempo de execução: as colisões, os oclusores, o fogo, a porta, a chave, os painéis
e os waypoints são nós ESTÁTICOS dentro do .tscn, alinhados à arte pelos mesmos números da planta.
Você pode abrir a cena no editor e mexer em qualquer nó à mão.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fase2_layout as L  # noqa: E402
import gerar_arte_fase2 as A  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SCENES = os.path.join(ROOT, "Scenes", "Fase2")

OCC_PAD = 1   # px que cada oclusor "engorda" para as emendas entre paredes não vazarem luz


def n(v):
    """Número no formato do Godot."""
    if isinstance(v, float) and v.is_integer():
        v = int(v)
    return str(v)


def v2(x, y):
    return f"Vector2({n(x)}, {n(y)})"


class Scene:
    def __init__(self):
        self.ext = {}        # path -> (id, type)
        self.sub = []        # (id, type, [linhas])
        self.nodes = []      # blocos de texto
        self._n = 0

    def res(self, path, rtype):
        if path not in self.ext:
            self._n += 1
            self.ext[path] = (f"{self._n}_{os.path.splitext(os.path.basename(path))[0][:14].replace(' ', '_')}", rtype)
        return f'ExtResource("{self.ext[path][0]}")'

    def sub_res(self, sid, stype, lines):
        for s in self.sub:
            if s[0] == sid:
                return f'SubResource("{sid}")'
        self.sub.append((sid, stype, lines))
        return f'SubResource("{sid}")'

    def rect_shape(self, w, h):
        return self.sub_res(f"Rect_{n(w)}x{n(h)}", "RectangleShape2D", [f"size = {v2(w, h)}"])

    def node(self, name, ntype=None, parent=None, props=None, node_paths=None, instance=None, index=None, groups=None):
        head = f'[node name="{name}"'
        if ntype:
            head += f' type="{ntype}"'
        if parent is not None:
            head += f' parent="{parent}"'
        if instance:
            head += f" instance={instance}"
        if index is not None:
            head += f' index="{index}"'
        if node_paths:
            head += " node_paths=PackedStringArray(" + ", ".join(f'"{p}"' for p in node_paths) + ")"
        if groups:
            head += " groups=[" + ", ".join(f'"{g}"' for g in groups) + "]"
        head += "]"
        lines = [head]
        for k, val in (props or {}).items():
            lines.append(f"{k} = {val}")
        self.nodes.append("\n".join(lines))

    def text(self):
        steps = len(self.ext) + len(self.sub) + 1
        out = [f"[gd_scene load_steps={steps} format=3]", ""]
        for path, (rid, rtype) in self.ext.items():
            out.append(f'[ext_resource type="{rtype}" path="{path}" id="{rid}"]')
        out.append("")
        for sid, stype, lines in self.sub:
            out.append(f'[sub_resource type="{stype}" id="{sid}"]')
            out.extend(lines)
            out.append("")
        out.append("\n\n".join(self.nodes))
        out.append("")
        return "\n".join(out)


SCRIPT = lambda s, name: s.res(f"res://Scenes/Fase2/{name}", "Script")
TEX = lambda s, name: s.res(f"res://assets/arena/{name}", "Texture2D")


def sprite(s, name, parent, tex, pos, z, hframes=None, extra=None, scale=2):
    props = {"z_index": z, "texture_filter": 1, "position": v2(*pos), "scale": v2(scale, scale),
             "texture": TEX(s, tex)}
    if hframes:
        props["hframes"] = hframes
    props.update(extra or {})
    s.node(name, "Sprite2D", parent, props)


def area(s, name, parent, pos, shape, node_paths=None, props=None, mask=2, groups=None):
    p = {"position": v2(*pos), "collision_layer": 0, "collision_mask": mask, "monitorable": "false"}
    p.update(props or {})
    s.node(name, "Area2D", parent, p, node_paths=node_paths, groups=groups)


# ======================================================================================== LABIRINTO
def build_labirinto():
    s = Scene()
    cw, ch = L.CANVAS_W, L.CANVAS_H
    root_paths = ["player", "chave", "porta", "puzzle", "saida", "hud"]
    s.node("Labirinto", "Node2D", None, {
        "script": SCRIPT(s, "labirinto.gd"),
        "player": 'NodePath("Player")', "chave": 'NodePath("Chave")', "porta": 'NodePath("Porta")',
        "puzzle": 'NodePath("Puzzle")', "saida": 'NodePath("Saida")', "hud": 'NodePath("HudLabirinto")',
    }, node_paths=root_paths)

    s.node("Musica", "AudioStreamPlayer", ".", {
        "stream": s.res("res://Sounds/Musics/Sci-Fi 3 Loop.wav", "AudioStream"),
        "autoplay": "true", "bus": '&"Music"'})

    # Escuro quase preto: só a luz do jogador revela o que está em volta.
    s.node("Escuridao", "CanvasModulate", ".", {"color": "Color(0.03, 0.04, 0.07, 1)"})

    # ---------------------------------------------------------------- ARTE (sprites prontos)
    s.node("Arte", "Node2D", ".")
    sprite(s, "Piso", "Arte", "arena_piso.png", (0, 0), -20, extra={"centered": "false"})
    sprite(s, "Paredes", "Arte", "arena_paredes.png", (0, 0), -10, extra={"centered": "false"})
    s.node("Decoracao", "Node2D", "Arte")
    hx, hy = L.cell_center(*L.HINT_CELL)
    sprite(s, "DicaOrdem", "Arte/Decoracao", "dica_ordem.png", (hx, hy + 8), -12)
    props_list = [   # (célula, deslocamento em px, quadro de props.png)
        ((1, 0), (-14, 10), 1), ((1, 1), (18, -14), 0), ((0, 3), (4, 6), 2),
        ((9, 5), (-8, 14), 3), ((4, 6), (-16, 8), 0), ((9, 1), (12, -10), 2), ((2, 4), (-20, 18), 1),
    ]
    for i, (cell, (dx, dy), frame) in enumerate(props_list, 1):
        cx, cy = L.cell_center(*cell)
        sprite(s, f"Prop{i:02d}", "Arte/Decoracao", "props.png", (cx + dx, cy + dy), -12, extra={
            "region_enabled": "true", "region_rect": f"Rect2({16 * frame}, 0, 16, 16)"})

    # ---------------------------------------------------------------- COLISÕES (mundo = camada 1)
    rects = L.wall_rects()
    s.node("Colisoes", "StaticBody2D", ".", {"collision_layer": 1, "collision_mask": 0})
    for i, (x, y, w, h) in enumerate(rects, 1):
        s.node(f"Parede{i:02d}", "CollisionShape2D", "Colisoes", {
            "position": v2(x + w / 2, y + h / 2), "shape": s.rect_shape(w, h)})

    # ---------------------------------------------------------------- OCLUSORES (mesmos retângulos)
    s.node("Oclusores", "Node2D", ".")
    for i, (x, y, w, h) in enumerate(rects, 1):
        pts = [(-OCC_PAD, -OCC_PAD), (w + OCC_PAD, -OCC_PAD), (w + OCC_PAD, h + OCC_PAD), (-OCC_PAD, h + OCC_PAD)]
        poly = s.sub_res(f"Occ_{i:02d}", "OccluderPolygon2D",
                         ["polygon = PackedVector2Array(" + ", ".join(f"{n(a)}, {n(b)}" for a, b in pts) + ")"])
        s.node(f"Oclusor{i:02d}", "LightOccluder2D", "Oclusores", {"position": v2(x, y), "occluder": poly})

    # ---------------------------------------------------------------- FOGO (Area2D de dano)
    for name, (a, b) in L.FIRE_PASSAGES.items():
        (fx, fy, fw, fh), orient = L.fire_rect(a, b)
        tex = "fogo_corredor_horizontal.png" if orient == "h" else "fogo_corredor_vertical.png"
        area(s, name, ".", (fx + fw / 2, fy + fh / 2), None, node_paths=["sprite"],
             props={"script": SCRIPT(s, "fire_hazard.gd"), "sprite": 'NodePath("Sprite2D")'})
        sprite(s, "Sprite2D", name, tex, (0, 0), -8, hframes=4)
        s.node("Colisao", "CollisionShape2D", name, {"shape": s.rect_shape(fw, fh)})

    # ---------------------------------------------------------------- CHAVE
    kx, ky = L.cell_center(*L.KEY_CELL)
    area(s, "Chave", ".", (kx, ky), None, node_paths=["sprite"],
         props={"script": SCRIPT(s, "maze_key.gd"), "sprite": 'NodePath("Sprite2D")'})
    sprite(s, "Sprite2D", "Chave", "chave.png", (0, -2), -7)
    s.node("Colisao", "CollisionShape2D", "Chave", {"shape": s.sub_res("Circle_22", "CircleShape2D", ["radius = 22.0"])})

    # ---------------------------------------------------------------- PUZZLE (3 painéis)
    s.node("Puzzle", "Node2D", ".", {"script": SCRIPT(s, "puzzle_controller.gd")})
    for name, p in L.PANELS.items():
        px_, py_ = L.cell_center(*p["cell"])
        area(s, name, "Puzzle", (px_, py_), None, node_paths=["sprite"], props={
            "script": SCRIPT(s, "puzzle_panel.gd"), "glyph": p["glyph"],
            "tex_off": TEX(s, "painel_desligado.png"), "tex_on": TEX(s, "painel_ligado.png"),
            "sprite": 'NodePath("Sprite2D")'})
        sprite(s, "Sprite2D", f"Puzzle/{name}", "painel_desligado.png", (0, -4), -7, hframes=3,
               extra={"frame": p["glyph"]})
        s.node("Colisao", "CollisionShape2D", f"Puzzle/{name}", {"shape": s.rect_shape(84, 84)})

    # ---------------------------------------------------------------- PORTA
    dx, dy, dw, dh = L.DOOR_RECT
    s.node("Porta", "Area2D", ".", {
        "position": v2(dx + dw / 2, dy + dh / 2), "collision_layer": 0, "collision_mask": 2, "monitorable": "false",
        "script": SCRIPT(s, "maze_door.gd"),
        "tex_trancada": TEX(s, "porta_trancada.png"), "tex_destrancada": TEX(s, "porta_destrancada.png"),
        "tex_aberta": TEX(s, "porta_aberta.png"),
        "sprite": 'NodePath("Sprite2D")', "corpo_colisao": 'NodePath("Corpo/Colisao")',
        "oclusor": 'NodePath("Corpo/Oclusor")'}, node_paths=["sprite", "corpo_colisao", "oclusor"])
    sprite(s, "Sprite2D", "Porta", "porta_trancada.png", (0, 0), -8)
    s.node("Zona", "CollisionShape2D", "Porta", {"position": v2(-56, 0), "shape": s.rect_shape(112, 120)})
    s.node("Corpo", "StaticBody2D", "Porta", {"collision_layer": 1, "collision_mask": 0})
    s.node("Colisao", "CollisionShape2D", "Porta/Corpo", {"shape": s.rect_shape(dw, dh)})
    pts = [(-dw / 2 - OCC_PAD, -dh / 2 - OCC_PAD), (dw / 2 + OCC_PAD, -dh / 2 - OCC_PAD),
           (dw / 2 + OCC_PAD, dh / 2 + OCC_PAD), (-dw / 2 - OCC_PAD, dh / 2 + OCC_PAD)]
    poly = s.sub_res("Occ_Porta", "OccluderPolygon2D",
                     ["polygon = PackedVector2Array(" + ", ".join(f"{n(a)}, {n(b)}" for a, b in pts) + ")"])
    s.node("Oclusor", "LightOccluder2D", "Porta/Corpo", {"occluder": poly})

    # ---------------------------------------------------------------- SAÍDA (fundo do vestíbulo)
    ex, ey, ew, eh = L.EXIT_RECT
    area(s, "Saida", ".", (ex + ew / 2, ey + eh / 2), None)
    s.node("Colisao", "CollisionShape2D", "Saida", {"shape": s.rect_shape(ew, eh)})

    # ---------------------------------------------------------------- ROTAS DOS DRONES (waypoints)
    s.node("Rotas", "Node2D", ".")
    for i, (dname, d) in enumerate(L.DRONES.items(), 1):
        s.node(f"Rota{i}", "Node2D", "Rotas")
        for j, (rx, ry) in enumerate(d["route"], 1):
            s.node(f"P{j}", "Marker2D", f"Rotas/Rota{i}", {"position": v2(rx, ry)}, groups=["lab_waypoint"])

    # ---------------------------------------------------------------- MAPA DE CORREDORES (dados estáticos p/ os drones)
    pairs = []
    for e in sorted(tuple(sorted(tuple(x) for x in edge)) for edge in L.PASSAGES):
        for (c, r) in e:
            pairs.append(r * L.COLS + c)
    s.node("Grafo", "Node2D", ".", {
        "script": SCRIPT(s, "maze_graph.gd"), "origin": v2(L.WALL, L.WALL), "cell_size": "96.0", "wall_size": "16.0",
        "cols": L.COLS, "rows": L.ROWS,
        "links": "PackedInt32Array(" + ", ".join(str(v) for v in pairs) + ")"})

    # ---------------------------------------------------------------- DRONES (o DroneEnemy.tscn do projeto)
    drone_scene = s.res("res://enemies/drone/DroneEnemy.tscn", "PackedScene")
    for i, (dname, d) in enumerate(L.DRONES.items(), 1):
        s.node(dname, None, ".", {"position": v2(*d["spawn"])}, instance=drone_scene)
        s.node("Patrol", None, f"{dname}/StateMachine", {
            "script": SCRIPT(s, "drone_route_patrol_state.gd"),
            "animation": '&"move"', "speed_multiplier": "0.35",
            "route_path": f'NodePath("../../../Rotas/Rota{i}")'}, index=1)
        s.node("Chase", None, f"{dname}/StateMachine", {
            "script": SCRIPT(s, "drone_maze_chase_state.gd"), "animation": '&"move"'}, index=2)

    # ---------------------------------------------------------------- PLAYER (o Turing.tscn do projeto)
    sx, sy = L.cell_center(*L.START_CELL)
    s.node("Player", None, ".", {
        "position": v2(sx, sy),
        # Dash do labirinto: 560 px/s x 0,30 s = 168 px de alcance, 1 s de recarga, invulnerável durante todo o dash.
        "dash_speed": "560.0", "dash_duration": "0.3", "dash_cooldown": "1.0", "iframes_duration": "0.34",
    }, instance=s.res("res://characters/turing/Turing.tscn", "PackedScene"))
    s.node("Camera2D", "Camera2D", "Player", {
        "limit_left": 0, "limit_top": 0, "limit_right": cw, "limit_bottom": ch})
    grad = s.sub_res("Gradient_Luz", "Gradient", [
        "offsets = PackedFloat32Array(0, 0.55, 1)",
        "colors = PackedColorArray(1, 1, 1, 1, 0.5, 0.5, 0.5, 1, 0, 0, 0, 1)"])
    gtex = s.sub_res("GradTex_Luz", "GradientTexture2D", [
        f"gradient = {grad}", "width = 256", "height = 256", "fill = 1",
        "fill_from = Vector2(0.5, 0.5)", "fill_to = Vector2(1, 0.5)"])
    s.node("Luz", "PointLight2D", "Player", {
        "color": "Color(1, 0.94, 0.8, 1)", "energy": "1.1", "shadow_enabled": "true",
        "texture": gtex, "texture_scale": "1.25",
        "script": SCRIPT(s, "player_light.gd"), "light_range": "160.0"})

    # ---------------------------------------------------------------- HUD do projeto + HUD do labirinto
    s.node("HUD", None, ".", None, instance=s.res("res://ui/hud/hud.tscn", "PackedScene"))
    theme = s.res("res://themes/main_theme.tres", "Theme")
    outline = {"theme_override_colors/font_outline_color": "Color(0, 0, 0, 0.9)",
               "theme_override_constants/outline_size": 4}
    s.node("HudLabirinto", "CanvasLayer", ".", {
        "layer": 11, "script": SCRIPT(s, "lab_hud.gd"),
        "notice_label": 'NodePath("Raiz/Aviso")', "prompt_label": 'NodePath("Raiz/Dica")',
        "objective_label": 'NodePath("Raiz/Objetivo")', "puzzle_label": 'NodePath("Raiz/Paineis")',
        "key_slot": 'NodePath("Raiz/SlotChave")', "key_icon": 'NodePath("Raiz/SlotChave/Icone")'},
        node_paths=["notice_label", "prompt_label", "objective_label", "puzzle_label", "key_slot", "key_icon"])
    s.node("Raiz", "Control", "HudLabirinto", {
        "layout_mode": 3, "anchors_preset": 15, "anchor_right": "1.0", "anchor_bottom": "1.0",
        "grow_horizontal": 2, "grow_vertical": 2, "mouse_filter": 2, "theme": theme})
    s.node("Objetivo", "Label", "HudLabirinto/Raiz", dict({
        "layout_mode": 1, "offset_left": "16.0", "offset_top": "16.0", "offset_right": "560.0", "offset_bottom": "44.0",
        "theme_override_font_sizes/font_size": 18, "text": '"Encontre a chave"'}, **outline))
    s.node("Paineis", "Label", "HudLabirinto/Raiz", dict({
        "layout_mode": 1, "offset_left": "16.0", "offset_top": "46.0", "offset_right": "360.0", "offset_bottom": "70.0",
        "theme_override_font_sizes/font_size": 16, "text": '"Painéis 0/3"'}, **outline))
    s.node("SlotChave", "Panel", "HudLabirinto/Raiz", {
        "layout_mode": 1, "anchors_preset": 1, "anchor_left": "1.0", "anchor_right": "1.0",
        "offset_left": "-80.0", "offset_top": "16.0", "offset_right": "-16.0", "offset_bottom": "80.0",
        "grow_horizontal": 0})
    s.node("Icone", "TextureRect", "HudLabirinto/Raiz/SlotChave", {
        "layout_mode": 1, "anchors_preset": 15, "anchor_right": "1.0", "anchor_bottom": "1.0",
        "offset_left": "6.0", "offset_top": "6.0", "offset_right": "-6.0", "offset_bottom": "-6.0",
        "grow_horizontal": 2, "grow_vertical": 2, "mouse_filter": 2, "texture_filter": 1,
        "texture": TEX(s, "chave.png"), "expand_mode": 1, "stretch_mode": 5})
    s.node("Aviso", "Label", "HudLabirinto/Raiz", dict({
        "layout_mode": 1, "anchors_preset": 12, "anchor_top": "1.0", "anchor_right": "1.0", "anchor_bottom": "1.0",
        "offset_top": "-232.0", "offset_bottom": "-196.0", "grow_horizontal": 2, "grow_vertical": 0,
        "theme_override_font_sizes/font_size": 22, "horizontal_alignment": 1, "vertical_alignment": 1,
        "text": '""'}, **outline))
    s.node("Dica", "Label", "HudLabirinto/Raiz", dict({
        "layout_mode": 1, "anchors_preset": 12, "anchor_top": "1.0", "anchor_right": "1.0", "anchor_bottom": "1.0",
        "offset_top": "-188.0", "offset_bottom": "-156.0", "grow_horizontal": 2, "grow_vertical": 0,
        "theme_override_font_sizes/font_size": 20, "horizontal_alignment": 1, "vertical_alignment": 1,
        "text": '"[E] Interagir"'}, **outline))

    # ---------------------------------------------------------------- Depuração (F3)
    s.node("Depuracao", "CanvasLayer", ".", {
        "layer": 20, "script": SCRIPT(s, "debug_overlay.gd"),
        "colisoes": 'NodePath("../Colisoes")', "oclusores": 'NodePath("../Oclusores")',
        "escuridao": 'NodePath("../Escuridao")', "luz": 'NodePath("../Player/Luz")',
        "linhas": 'NodePath("Linhas")', "rotulo": 'NodePath("Rotulo")'},
        node_paths=["colisoes", "oclusores", "escuridao", "luz", "linhas", "rotulo"])
    s.node("Linhas", "Node2D", "Depuracao", {"script": SCRIPT(s, "debug_lines.gd"), "visible": "false"})
    s.node("Rotulo", "Label", "Depuracao", dict({
        "visible": "false", "offset_left": "16.0", "offset_top": "96.0", "offset_right": "420.0", "offset_bottom": "120.0",
        "theme_override_font_sizes/font_size": 14, "text": '"F3"'}, **outline))

    s.node("Pause", None, ".", None, instance=s.res("res://ui/pause.tscn", "PackedScene"))
    return s


# ======================================================================================== SALA NOVA
def build_sala():
    s = Scene()
    s.node("SalaNova", "Node2D", None, {
        "script": SCRIPT(s, "sala_nova.gd"),
        "nucleo": 'NodePath("Nucleo")', "nucleo_sprite": 'NodePath("Nucleo/Sprite2D")'},
        node_paths=["nucleo", "nucleo_sprite"])
    s.node("Musica", "AudioStreamPlayer", ".", {
        "stream": s.res("res://Sounds/Musics/Sci-Fi 2 Loop.wav", "AudioStream"),
        "autoplay": "true", "bus": '&"Music"'})
    sprite(s, "Piso", ".", "sala_piso.png", (0, 0), -20, extra={"centered": "false"})
    sprite(s, "Paredes", ".", "sala_paredes.png", (0, 0), -10, extra={"centered": "false"})
    solid, _ = A.sala_masks()
    rects = L.wall_rects(solid)
    s.node("Colisoes", "StaticBody2D", ".", {"collision_layer": 1, "collision_mask": 0})
    for i, (x, y, w, h) in enumerate(rects, 1):
        s.node(f"Parede{i:02d}", "CollisionShape2D", "Colisoes", {
            "position": v2(x + w / 2, y + h / 2), "shape": s.rect_shape(w, h)})
    nx, ny = A.SALA_NUCLEO
    area(s, "Nucleo", ".", (nx, ny), None)
    sprite(s, "Sprite2D", "Nucleo", "sala_nucleo.png", (0, -12), -5, hframes=3)
    s.node("Colisao", "CollisionShape2D", "Nucleo", {"shape": s.rect_shape(56, 56)})
    px_, py_ = A.SALA_START
    s.node("Player", None, ".", {"position": v2(px_, py_)}, instance=s.res("res://characters/turing/Turing.tscn", "PackedScene"))
    s.node("HUD", None, ".", None, instance=s.res("res://ui/hud/hud.tscn", "PackedScene"))
    s.node("Aviso", "CanvasLayer", ".", {"layer": 11})
    s.node("Texto", "Label", "Aviso", {
        "anchors_preset": 5, "anchor_left": "0.5", "anchor_right": "0.5", "offset_left": "-300.0", "offset_top": "24.0",
        "offset_right": "300.0", "offset_bottom": "56.0", "grow_horizontal": 2,
        "horizontal_alignment": 1, "theme_override_font_sizes/font_size": 20,
        "theme_override_colors/font_outline_color": "Color(0, 0, 0, 0.9)", "theme_override_constants/outline_size": 4,
        "theme": s.res("res://themes/main_theme.tres", "Theme"),
        "text": '"Sala liberada. Caminhe até o cristal para concluir."'})
    s.node("Pause", None, ".", None, instance=s.res("res://ui/pause.tscn", "PackedScene"))
    return s


def main():
    os.makedirs(SCENES, exist_ok=True)
    for fname, builder in (("Labirinto.tscn", build_labirinto), ("SalaNova.tscn", build_sala)):
        sc = builder()
        path = os.path.join(SCENES, fname)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(sc.text())
        print(fname, len(sc.nodes), "nós,", len(sc.sub), "sub-recursos")


if __name__ == "__main__":
    main()
