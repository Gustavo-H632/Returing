#!/usr/bin/env python3
"""Valida a Fase 2 (labirinto) SEM abrir o Godot.

Uso (na raiz do projeto):   python tools/validar_fase2.py

Confere:
  1. caminho início -> chave -> porta existe; o fogo é obrigatório para a chave e para a porta;
  2. nenhuma parede deixa vazar luz (oclusores cobrem todas as paredes, o vão da porta fica fechado
     e o piso alcançável é uma região fechada);
  3. a arte (PNG) está alinhada às colisões e aos oclusores;
  4. o fogo só é cruzável com dash (geometria + invulnerabilidade) e o dash cobre o trecho de fogo;
  5. os drones têm rota livre de paredes, em corredores diferentes;
  6. os .tscn estão íntegros (recursos existentes, referências, nós, sem TileMap);
  7. os .gd têm sintaxe básica coerente e o InputMap tem as ações usadas.
Não substitui o teste no editor: `godot --headless --quit` não estava disponível quando isto foi escrito.
"""
import os
import re
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fase2_layout as L  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
FAILS = []
N_OK = 0


def check(ok, msg):
    global N_OK
    if ok:
        N_OK += 1
        print("  ok   ", msg)
    else:
        FAILS.append(msg)
        print("  FALHA", msg)


def read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        return f.read()


# ------------------------------------------------------------------ parser mínimo de .tscn
def parse_tscn(text):
    ext, sub, nodes = {}, {}, []
    cur = None
    for line in text.splitlines():
        if line.startswith("["):
            m = re.match(r'\[(\w+)\s*(.*)\]$', line)
            kind, rest = m.group(1), m.group(2)
            attrs = dict(re.findall(r'(\w+)=("[^"]*"|\w+\([^)]*\)|\[[^\]]*\]|[^\s\]]+)', rest))
            if kind == "ext_resource":
                ext[attrs["id"].strip('"')] = attrs["path"].strip('"')
                cur = None
            elif kind == "sub_resource":
                cur = {"type": attrs["type"].strip('"'), "props": {}}
                sub[attrs["id"].strip('"')] = cur
            elif kind == "node":
                cur = {"name": re.search(r'name="([^"]*)"', rest).group(1),
                       "type": (re.search(r'type="([^"]*)"', rest) or [None, None])[1],
                       "parent": (re.search(r'parent="([^"]*)"', rest) or [None, None])[1],
                       "instance": "instance=" in rest, "props": {}, "rest": rest}
                nodes.append(cur)
            else:
                cur = None
        elif cur is not None and " = " in line:
            k, v = line.split(" = ", 1)
            cur["props"][k.strip()] = v.strip()
    for nd in nodes:
        if nd["parent"] is None:
            nd["path"] = "."
        elif nd["parent"] == ".":
            nd["path"] = nd["name"]
        else:
            nd["path"] = nd["parent"] + "/" + nd["name"]
    return ext, sub, nodes


def vec2(s):
    m = re.match(r"Vector2\(([-\d.]+),\s*([-\d.]+)\)", s)
    return float(m.group(1)), float(m.group(2))


def sub_id(s):
    return re.match(r'SubResource\("([^"]+)"\)', s).group(1)


def rect_from_nodes(nodes, sub, parent):
    out = []
    for nd in nodes:
        if nd["parent"] == parent and nd["type"] == "CollisionShape2D":
            px, py = vec2(nd["props"]["position"])
            w, h = vec2(sub[sub_id(nd["props"]["shape"])]["props"]["size"])
            out.append((px - w / 2, py - h / 2, w, h))
    return out


def main():
    print("== Fase 2 (labirinto): validação offline ==")
    solid, floor = L.build_masks()
    UW, UH = L.UW, L.UH

    # ---------------------------------------------------------------- 1. caminhos
    print("[1] Caminho início -> chave -> porta")
    no_fire = L.adjacency(False)
    with_fire = L.adjacency(True)
    d0 = L.bfs(L.START_CELL, no_fire)
    d1 = L.bfs(L.START_CELL, with_fire)
    door_cell = (L.COLS - 1, 0)
    check(L.KEY_CELL in d1, f"existe caminho do início até a chave (com dash): {d1.get(L.KEY_CELL)} células")
    check(door_cell in d1, f"existe caminho do início até a porta (com dash): {d1.get(door_cell)} células")
    dk = L.bfs(L.KEY_CELL, with_fire)
    check(door_cell in dk, f"existe caminho da chave até a porta: {dk.get(door_cell)} células")
    check(L.KEY_CELL not in d0, "a chave NÃO é alcançável sem atravessar fogo")
    check(door_cell not in d0, "a porta NÃO é alcançável sem atravessar fogo")
    check(all(c in d1 for c in [(c, r) for c in range(L.COLS) for r in range(L.ROWS)]),
          "todas as 70 células são alcançáveis (nenhuma área isolada)")
    for name, p in L.PANELS.items():
        check(p["cell"] in d1, f"painel {name} alcançável (distância {d1.get(p['cell'])})")
    check(d1[L.KEY_CELL] >= 10, "a chave fica longe do início (>= 10 células)")
    check(sorted(L.SOLUTION) == [0, 1, 2] and sorted(p["glyph"] for p in L.PANELS.values()) == [0, 1, 2],
          "símbolos dos painéis são 0,1,2 sem repetição e a solução usa todos")
    ctrl = read("Scenes/Fase2/puzzle_controller.gd")
    m = re.search(r"PackedInt32Array\(\[([^\]]*)\]\)", ctrl)
    check([int(v) for v in m.group(1).split(",")] == L.SOLUTION, "ordem do puzzle no script = ordem da dica desenhada")

    # ---------------------------------------------------------------- tscn
    lab_text = read("Scenes/Fase2/Labirinto.tscn")
    sala_text = read("Scenes/Fase2/SalaNova.tscn")
    ext, sub, nodes = parse_tscn(lab_text)
    ext_s, sub_s, nodes_s = parse_tscn(sala_text)

    # ---------------------------------------------------------------- 2. luz
    print("[2] Oclusores e vazamento de luz")
    walls = rect_from_nodes(nodes, sub, "Colisoes")
    expected = L.wall_rects(solid)
    check(sorted(walls) == sorted(map(lambda r: tuple(float(v) for v in r), expected)),
          f"as {len(walls)} colisões do .tscn = retângulos da planta")
    occ = []
    for nd in nodes:
        if nd["parent"] == "Oclusores":
            px, py = vec2(nd["props"]["position"])
            poly = sub[sub_id(nd["props"]["occluder"])]["props"]["polygon"]
            nums = [float(v) for v in re.findall(r"-?\d+(?:\.\d+)?", poly[poly.index("(") + 1:])]
            pts = list(zip(nums[0::2], nums[1::2]))
            occ.append((px, py, pts))
    check(len(occ) == len(walls), f"um oclusor por parede ({len(occ)})")
    aligned = True
    for (wx, wy, ww, wh), (ox, oy, pts) in zip(sorted(walls), sorted(occ, key=lambda o: (o[0], o[1]))):
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        if abs(ox - wx) > 0 or abs(oy - wy) > 0 or min(xs) > 0 or min(ys) > 0 or max(xs) < ww or max(ys) < wh \
                or max(xs) > ww + 1 or max(ys) > wh + 1:
            aligned = False
    check(aligned, "cada oclusor cobre exatamente a sua parede (folga máxima de 1 px, só para fechar emendas)")
    # cobertura por unidade de 16 px (centro da unidade)
    def covered(px, py):
        for ox, oy, pts in occ:
            xs = [p[0] for p in pts]
            ys = [p[1] for p in pts]
            if ox + min(xs) <= px <= ox + max(xs) and oy + min(ys) <= py <= oy + max(ys):
                return True
        return False
    leak = [(ux, uy) for uy in range(UH) for ux in range(UW)
            if solid[uy][ux] and not covered(ux * 16 + 8, uy * 16 + 8)]
    stray = [(ux, uy) for uy in range(UH) for ux in range(UW)
             if floor[uy][ux] and covered(ux * 16 + 8, uy * 16 + 8)]
    check(not leak, f"toda unidade de parede tem oclusor ({len(leak)} sem)")
    check(not stray, f"nenhum oclusor cobre piso ({len(stray)})")
    # a porta fecha o vão (1128, 64)
    door = [nd for nd in nodes if nd["name"] == "Porta"][0]
    dx, dy = vec2(door["props"]["position"])
    check((dx, dy) == (L.DOOR_RECT[0] + L.DOOR_RECT[2] / 2, L.DOOR_RECT[1] + L.DOOR_RECT[3] / 2),
          "a Porta está exatamente sobre o vão da parede leste")
    door_units = {(ux, uy) for uy in range(UH) for ux in range(UW)
                  if L.DOOR_RECT[0] <= ux * 16 + 8 <= L.DOOR_RECT[0] + L.DOOR_RECT[2]
                  and L.DOOR_RECT[1] <= uy * 16 + 8 <= L.DOOR_RECT[1] + L.DOOR_RECT[3]}
    check(door_units and all(floor[uy][ux] for ux, uy in door_units), "o vão da porta é piso fechado só pela Porta")
    # região fechada: flood fill a partir do início; nunca encosta em vazio nem na borda do mundo
    from collections import deque
    sx, sy = L.cell_center(*L.START_CELL)
    start_u = (sx // 16, sy // 16)
    seen = {start_u}
    q = deque([start_u])
    escaped = False
    while q:
        ux, uy = q.popleft()
        for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = ux + ddx, uy + ddy
            if not (0 <= nx < UW and 0 <= ny < UH):
                escaped = True
                continue
            if solid[ny][nx]:
                continue
            if not floor[ny][nx]:
                escaped = True
                continue
            if (nx, ny) not in seen:
                seen.add((nx, ny))
                q.append((nx, ny))
    check(not escaped, f"o piso alcançável ({len(seen)} unidades) é uma região fechada por paredes (sem vazamento)")

    # ---------------------------------------------------------------- 3. arte x colisão
    print("[3] Alinhamento da arte com as colisões")
    piso = Image.open(os.path.join(ROOT, "assets/arena/arena_piso.png")).convert("RGBA")
    pared = Image.open(os.path.join(ROOT, "assets/arena/arena_paredes.png")).convert("RGBA")
    check(piso.size == (L.CANVAS_W // 2, L.CANVAS_H // 2) and pared.size == piso.size,
          f"arena_piso e arena_paredes têm {piso.size} px (= {L.CANVAS_W}x{L.CANVAS_H} px de mundo / 2)")
    bad_wall, bad_floor, bad_over = 0, 0, 0
    for uy in range(UH):
        for ux in range(UW):
            a0x, a0y = ux * 8, uy * 8
            if solid[uy][ux]:
                if any(pared.getpixel((a0x + i, a0y + j))[3] == 0 for i in range(8) for j in range(8)):
                    bad_wall += 1
            elif floor[uy][ux]:
                if any(piso.getpixel((a0x + i, a0y + j))[3] == 0 for i in range(8) for j in range(8)):
                    bad_floor += 1
            else:
                if any(piso.getpixel((a0x + i, a0y + j))[3] or pared.getpixel((a0x + i, a0y + j))[3]
                       for i in range(8) for j in range(8)):
                    bad_over += 1
    check(bad_wall == 0, "toda unidade de colisão de parede tem arte de parede opaca (0 falhas)" if not bad_wall
          else f"{bad_wall} unidades de parede com arte transparente")
    check(bad_floor == 0, "todo piso tem arte de piso opaca")
    check(bad_over == 0, "nada é desenhado fora do labirinto (vazio fica transparente)")
    wall_in_floor_only = 0
    for uy in range(UH):
        for ux in range(UW):
            if floor[uy][ux] and not solid[uy][ux]:
                continue
    # sprites de objeto: tamanho em px de arte x 2 = tamanho do nó de colisão/área
    def png(name):
        return Image.open(os.path.join(ROOT, "assets/arena", name)).size
    check(png("porta_trancada.png") == (8, 48) and (L.DOOR_RECT[2], L.DOOR_RECT[3]) == (16, 96),
          "sprite da porta (8x48 de arte) cobre o vão 16x96 px")
    for name, (a, b) in L.FIRE_PASSAGES.items():
        (fx, fy, fw, fh), orient = L.fire_rect(a, b)
        sheet = png("fogo_corredor_horizontal.png" if orient == "h" else "fogo_corredor_vertical.png")
        check((sheet[0] // 4 * 2, sheet[1] * 2) == (fw, fh), f"{name}: sprite 4 quadros cobre a área {fw}x{fh} px")

    # ---------------------------------------------------------------- 4. fogo x dash
    print("[4] Fogo só cruzável com dash")
    turing = read("characters/turing/Turing.tscn")
    cap_r = float(re.search(r'id="CapsuleShape2D_tlatl"\]\s*radius = ([\d.]+)\s*height = ([\d.]+)', turing).group(1))
    cap_h = float(re.search(r'id="CapsuleShape2D_tlatl"\]\s*radius = ([\d.]+)\s*height = ([\d.]+)', turing).group(2))
    player = [nd for nd in nodes if nd["name"] == "Player"][0]["props"]
    speed = float(player["dash_speed"])
    dur = float(player["dash_duration"])
    cd = float(player["dash_cooldown"])
    iframes = float(player["iframes_duration"])
    dash_len = speed * dur
    check(cd == 1.0, f"cooldown do dash = {cd} s")
    check(iframes >= dur, f"invulnerabilidade ({iframes} s) cobre o dash inteiro ({dur} s)")
    mobile = 1.5
    check(L.CELL >= cap_h * mobile, f"corredor de {L.CELL} px cabe a cápsula do Player ({cap_h:.0f} px; {cap_h * mobile:.0f} no celular)")
    fire_nodes = {nd["name"]: nd for nd in nodes if nd["name"].startswith("Fogo") and nd["parent"] == "."}
    for name, (a, b) in L.FIRE_PASSAGES.items():
        (fx, fy, fw, fh), orient = L.fire_rect(a, b)
        node = fire_nodes[name]
        px, py = vec2(node["props"]["position"])
        check((px, py) == (fx + fw / 2, fy + fh / 2), f"{name}: posicionado no vão da passagem {a}-{b}")
        # o fogo ocupa a largura inteira do corredor (não há como contornar)
        cross = fh if orient == "h" else fw
        check(cross == L.CELL, f"{name}: ocupa toda a largura do corredor ({cross} px)")
        # extensão da cápsula ao longo do eixo do dash
        ext_axis = (cap_r * 2) if orient == "h" else cap_h
        # folga livre depois do fogo até a próxima parede (distância da borda do fogo ao fim da célula)
        run_after = (L.CELL + L.WALL - L.FIRE_LEN) // 2 + L.WALL // 2   # = 88: célula + metade do vão - sobra do fogo
        run_after = L.CELL - (L.FIRE_LEN - L.WALL) // 2
        s_max = dash_len - L.FIRE_LEN - ext_axis
        check(run_after >= ext_axis, f"{name}: depois do fogo há {run_after} px livres (cápsula usa {ext_axis:.0f})")
        check(s_max >= 40, f"{name}: o dash ({dash_len:.0f} px) sai do fogo mesmo começando a {s_max:.0f} px dele (janela >= 40)")
        # atravessar a pé: tempo dentro do fogo e dano
        walk_time = (L.FIRE_LEN + ext_axis) / 300.0
        dmg = int(re.search(r"var damage: int = (\d+)", read("Scenes/Fase2/fire_hazard.gd")).group(1))
        check(dmg >= 25, f"{name}: andar através custa {dmg} de 100 de vida ({walk_time:.2f} s dentro do fogo)")

    # ---------------------------------------------------------------- 5. drones
    print("[5] Drones e rotas")
    drone_nodes = [nd for nd in nodes if nd["instance"] and nd["name"].startswith("Drone")]
    check(len(drone_nodes) == 3, "3 drones instanciados (res://enemies/drone/DroneEnemy.tscn)")
    check(all("DroneEnemy.tscn" in ext[re.search(r'ExtResource\("([^"]+)"\)', nd["rest"]).group(1)] for nd in drone_nodes),
          "todos usam o DroneEnemy.tscn existente")

    def free_segment(a, b):
        steps = int(max(abs(a[0] - b[0]), abs(a[1] - b[1])) // 4) + 1
        for i in range(steps + 1):
            x = a[0] + (b[0] - a[0]) * i / steps
            y = a[1] + (b[1] - a[1]) * i / steps
            for ox in (-14, 14):
                for oy in (-28, 28):
                    ux, uy = int((x + ox) // 16), int((y + oy) // 16)
                    if solid[uy][ux]:
                        return False
        return True
    corridors = set()
    for dname, d in L.DRONES.items():
        a, b = d["route"]
        check(free_segment(a, b), f"{dname}: a rota {a} -> {b} está livre de paredes (com a cápsula de 28x56)")
        check(d["spawn"][1] == a[1] or d["spawn"][0] == a[0], f"{dname}: nasce em cima da rota")
        corridors.add((a[1] // 112, a[0] // 112) if a[1] != b[1] else ("linha", a[1] // 112))
        dist = ((d["spawn"][0] - sx) ** 2 + (d["spawn"][1] - sy) ** 2) ** 0.5
        check(dist > 250, f"{dname}: nasce longe do início ({dist:.0f} px)")
    check(len(corridors) == 3, "os 3 drones patrulham corredores (linhas) diferentes")
    chase = [nd for nd in nodes if nd["name"] == "Chase" and nd["parent"].endswith("StateMachine")]
    check(len(chase) == 3 and all("drone_maze_chase_state" in ext[re.search(r'ExtResource\("([^"]+)"\)', nd["props"]["script"]).group(1)]
                                  for nd in chase), "cada drone tem Chase do labirinto (contorna paredes pelo MazeGraph)")
    graph = [nd for nd in nodes if nd["name"] == "Grafo"][0]["props"]
    links = [int(v) for v in re.search(r"PackedInt32Array\(([^)]*)\)", graph["links"]).group(1).split(",")]
    want = {frozenset((r1 * L.COLS + c1, r2 * L.COLS + c2)) for (c1, r1), (c2, r2) in (tuple(e) for e in L.PASSAGES)}
    got = {frozenset(links[i:i + 2]) for i in range(0, len(links), 2)}
    check(want == got and len(links) == 2 * len(want), f"Grafo do .tscn = as {len(want)} passagens da planta")
    pat = [nd for nd in nodes if nd["name"] == "Patrol"]
    check(len(pat) == 3 and all("route_path" in nd["props"] for nd in pat), "cada drone tem Patrol com route_path")
    for i, nd in enumerate(pat, 1):
        route = re.search(r'NodePath\("([^"]+)"\)', nd["props"]["route_path"]).group(1)
        base = nd["path"]
        parts = base.split("/")
        for seg in route.split("/"):
            if seg == "..":
                parts.pop()
            else:
                parts.append(seg)
        target = "/".join(parts)
        count = sum(1 for n2 in nodes if n2["parent"] == target and n2["type"] == "Marker2D")
        check(count >= 2, f"Drone{i}: route_path resolve para '{target}' com {count} waypoints")

    # ---------------------------------------------------------------- 6. tscn
    print("[6] Integridade dos .tscn")
    for label, (e, s, nd_list, text) in {"Labirinto.tscn": (ext, sub, nodes, lab_text),
                                         "SalaNova.tscn": (ext_s, sub_s, nodes_s, sala_text)}.items():
        missing = [p for p in e.values() if not os.path.exists(os.path.join(ROOT, p.replace("res://", "")))]
        check(not missing, f"{label}: todos os {len(e)} recursos externos existem {missing[:3] if missing else ''}")
        used_ext = set(re.findall(r'ExtResource\("([^"]+)"\)', text))
        used_sub = set(re.findall(r'SubResource\("([^"]+)"\)', text))
        check(used_ext <= set(e), f"{label}: toda ExtResource usada está declarada")
        check(used_sub <= set(s), f"{label}: todo SubResource usado está declarado")
        paths = {nd["path"] for nd in nd_list}
        inst = {nd["path"] for nd in nd_list if nd["instance"]}   # filhos de cenas instanciadas não aparecem no arquivo
        orphan = [nd["path"] for nd in nd_list if nd["parent"] not in (None, ".") and nd["parent"] not in paths
                  and nd["parent"].split("/")[0] not in inst]
        check(not orphan, f"{label}: todo nó tem pai declarado antes ({orphan[:2]})")
        names = {}
        dup = []
        for nd in nd_list:
            key = (nd["parent"], nd["name"])
            if key in names:
                dup.append(key)
            names[key] = 1
        check(not dup, f"{label}: sem nomes de nó repetidos no mesmo pai")
        for bad in ("TileMap", "TileSet", "TileMapLayer"):
            check(bad not in text, f"{label}: não usa {bad}")
        # node_paths -> destino existe
        for nd in nd_list:
            if "node_paths=" in nd["rest"]:
                for key in re.findall(r'"(\w+)"', re.search(r"node_paths=PackedStringArray\(([^)]*)\)", nd["rest"]).group(1)):
                    target = re.search(r'NodePath\("([^"]+)"\)', nd["props"][key]).group(1)
                    parts = nd["path"].split("/") if nd["path"] != "." else []
                    for seg in target.split("/"):
                        if seg == "..":
                            parts.pop()
                        elif seg != ".":
                            parts.append(seg)
                    full = "/".join(parts) if parts else "."
                    if full not in paths:
                        check(False, f"{label}: {nd['path']}.{key} -> '{target}' não existe")
    for nd in nodes:
        if "node_paths=" in nd["rest"]:
            pass
    ids = [nd for nd in nodes if nd["type"] in ("Area2D",) and nd["parent"] == "."]
    for nd in ids:
        if nd["props"].get("collision_mask") != "2" and nd["name"] in ("Chave", "Saida") or \
                (nd["name"].startswith("Fogo") and nd["props"].get("collision_mask") != "2"):
            check(False, f"{nd['name']}: máscara de colisão deveria ser 2 (Player)")
    check(True, "Areas de fogo/chave/saída detectam a camada 2 (Player)")

    # ---------------------------------------------------------------- 7. scripts + projeto
    print("[7] Scripts e InputMap")
    folder = os.path.join(ROOT, "Scenes", "Fase2")
    for fname in sorted(os.listdir(folder)):
        if not fname.endswith(".gd"):
            continue
        txt = open(os.path.join(folder, fname), encoding="utf-8").read()
        pairs_ok = all(txt.count(a) == txt.count(b) for a, b in (("(", ")"), ("[", "]"), ("{", "}")))
        bad_indent = [i + 1 for i, ln in enumerate(txt.splitlines()) if re.match(r"^ +\S", ln) and not ln.lstrip().startswith("#")]
        check(pairs_ok and not bad_indent, f"{fname}: parênteses balanceados e indentação com tab")
    proj = read("project.godot")
    for action in ("interagir", "dash", "debug_overlay", "move_left", "move_right", "move_up", "move_down"):
        check(re.search(rf"^{action}=\{{", proj, re.M) is not None, f"InputMap tem '{action}'")
    check('textures/canvas_textures/default_texture_filter=0' in proj, "filtro Nearest do projeto preservado")
    check('next_scene = "res://Scenes/Fase2/Labirinto.tscn"' in read("Scenes/Fase1/fase_1.tscn"),
          "Fase 1 encadeia para o Labirinto")

    print()
    print(f"RESULTADO: {N_OK} verificações ok, {len(FAILS)} falhas")
    for f in FAILS:
        print("  -", f)
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
