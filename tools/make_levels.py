"""Writes Level01-03.tscn. Positions match the reference images (1672x941)."""
from pathlib import Path
import json, os
GEMS = json.loads(os.environ.get("GEMS", "[[[700,440],[930,200],[860,640]],[[1000,240],[600,560],[1300,620]],[[880,640],[430,560],[1050,330]]]"))


def poly(pts):
    return "PackedVector2Array(" + ", ".join(f"{x}, {y}" for x, y in pts) + ")"


class Scene:
    def __init__(self, name, script):
        self.ext = []
        self.nodes = []
        self.name = name
        self.script = self.res("Script", f"res://scripts/{script}.gd")

    def res(self, typ, path):
        for i, (t, p) in enumerate(self.ext):
            if p == path:
                return i + 1
        self.ext.append((typ, path))
        return len(self.ext)

    def node(self, name, typ=None, parent=".", inst=None, **props):
        self.nodes.append((name, typ, parent, inst, props))

    def text(self):
        out = ["[gd_scene format=3]", ""]
        for i, (t, p) in enumerate(self.ext):
            out.append(f'[ext_resource type="{t}" path="{p}" id="{i + 1}"]')
        out.append("")
        out.append(f'[node name="{self.name}" type="Node2D"]')
        out.append(f'script = ExtResource("{self.script}")')
        out.append("")
        for name, typ, parent, inst, props in self.nodes:
            head = f'[node name="{name}"'
            if typ:
                head += f' type="{typ}"'
            head += f' parent="{parent}"'
            if inst:
                head += f' instance=ExtResource("{inst}")'
            out.append(head + "]")
            for k, v in props.items():
                out.append(f"{k} = {v}")
            out.append("")
        return "\n".join(out)


def tex(s, path):
    return f'ExtResource("{s.res("Texture2D", path)}")'


def v2(x, y):
    return f"Vector2({x}, {y})"


def scene(s, path):
    return s.res("PackedScene", path)


def terrain(s, polys):
    s.node("Terrain", "StaticBody2D", collision_layer=1, collision_mask=0)
    for i, p in enumerate(polys):
        s.node(f"Shape{i}", "CollisionPolygon2D", parent="Terrain", polygon=poly(p))


def miner(s, x, y, sc):
    s.node("Miner", parent=".", inst=scene(s, "res://scenes/Miner.tscn"), position=v2(x, y), body_scale=sc, z_index=10)


def reflector(s, name, x, y, **kw):
    props = {"position": v2(x, y), "z_index": 8}
    props.update(kw)
    s.node(name, parent=".", inst=scene(s, "res://scenes/Reflector.tscn"), **props)


def target(s, name, x, y, **kw):
    props = {"position": v2(x, y), "z_index": 9}
    props.update(kw)
    s.node(name, parent=".", inst=scene(s, "res://scenes/WaveTarget.tscn"), **props)


def npc(s, name, x, y, sheet, sc, facing=-1, z=10):
    s.node(name, parent=".", inst=scene(s, "res://scenes/Npc.tscn"), position=v2(x, y),
           sheet=tex(s, f"res://assets/sprites/{sheet}.png"), body_scale=sc, facing=facing, z_index=z)


def rings(s, pts):
    for i, (x, y) in enumerate(pts):
        s.node(f"Ring{i + 1}", "Area2D", parent=".", script=f'ExtResource("{s.res("Script", "res://scripts/boost_ring.gd")}")', position=v2(x, y))


def gems(s, pts):
    for i, (x, y) in enumerate(pts):
        s.node(f"Gem{i + 1}", parent=".", inst=scene(s, "res://scenes/Gem.tscn"), position=v2(x, y))


# ---------------------------------------------------------------- Level 1
s = Scene("Level01", "level_01")
s.node("Background", "Sprite2D", texture=tex(s, "res://assets/bg/level1.png"), centered="false")
s.node("Gear", "Sprite2D", texture=tex(s, "res://assets/sprites/l1_gear.png"), position=v2(848, 346))
s.node("Cabin", "Sprite2D", texture=tex(s, "res://assets/sprites/l1_cabin.png"), position=v2(788, 528), centered="false", z_index=2)
s.node("Pole", "Sprite2D", texture=tex(s, "res://assets/sprites/pole.png"), position=v2(600, 242), z_index=7)
s.node("Clamp", "Sprite2D", texture=tex(s, "res://assets/sprites/clamp.png"), position=v2(834, 512), z_index=3)
terrain(s, [
    # miner's ledge with boulder A, cut by the fissure
    [(0, 305), (600, 302), (600, 262), (653, 262), (656, 300), (664, 318), (700, 372), (640, 372), (640, 470), (0, 470)],
    # right side of the fissure, boulder B and the upper ledge over the shaft
    [(707, 300), (707, 268), (753, 268), (753, 273), (1120, 273), (1150, 232), (1672, 225), (1672, 310), (770, 312), (760, 372), (752, 372), (712, 312)],
])
miner(s, 468, 306, 0.58)
reflector(s, "CrystalA", 600, 175, length=76.0, thickness=12.0, sprite_scale=0.31, start_angle=-35.0, show_stand="false")
target(s, "Latch", 834, 512, rect_size=v2(52, 28), marker_color="Color(1, 0.55, 0.4, 1)")
gems(s, GEMS[0])
rings(s, [(655, 248)])
Path("scenes/Level01.tscn").write_text(s.text())

# ---------------------------------------------------------------- Level 2
s = Scene("Level02", "level_02")
s.node("Background", "Sprite2D", texture=tex(s, "res://assets/bg/level2.png"), centered="false")
s.node("Pulley", "Sprite2D", texture=tex(s, "res://assets/sprites/l2_pulley.png"), position=v2(1522, 102))
s.node("HangingBeam", "StaticBody2D", position=v2(850, 30), collision_layer=1, collision_mask=0, z_index=6)
s.node("Sprite", "Sprite2D", parent="HangingBeam", texture=tex(s, "res://assets/sprites/hanging_beam.png"), centered="false")
s.node("Shape", "CollisionPolygon2D", parent="HangingBeam", polygon=poly([(10, 30), (54, 30), (54, 380), (10, 380)]))
s.node("Wall", parent=".", inst=scene(s, "res://scenes/BreakableWall.tscn"), position=v2(1114, 82), z_index=5)
s.node("PowerNode", "Sprite2D", texture=tex(s, "res://assets/sprites/power_node.png"), position=v2(1440, 600), z_index=4)
terrain(s, [
    [(0, 432), (330, 432), (325, 520), (250, 530), (250, 941), (0, 941)],
    [(545, 760), (955, 760), (955, 941), (545, 941)],
    [(1112, 452), (1672, 440), (1672, 500), (1300, 520), (1262, 640), (1120, 600)],
    [(1150, 742), (1672, 735), (1672, 941), (1150, 941)],
    [(1480, 500), (1500, 500), (1500, 735), (1480, 735)],
])
npc(s, "Mechanic", 1330, 438, "npc_mechanic_sheet", 0.85)
miner(s, 170, 428, 0.92)
reflector(s, "CrystalA", 752, 712, length=140.0, thickness=18.0, sprite_scale=0.58, start_angle=30.0, stand_offset=v2(0, 22), show_stand="false", track=v2(140, 0), track_period=5.0, draw_cart="true")
reflector(s, "CrystalB", 1330, 700, length=110.0, thickness=16.0, sprite_scale=0.46, start_angle=60.0, stand_offset=v2(0, 30))
target(s, "WeakPoint", 1112, 330, radius=22.0)
target(s, "PowerSocket", 1440, 594, radius=20.0, active="false", marker_color="Color(0.5, 1, 0.95, 1)")
gems(s, GEMS[1])
rings(s, [(540, 545), (960, 490)])
Path("scenes/Level02.tscn").write_text(s.text())

# ---------------------------------------------------------------- Level 3
s = Scene("Level03", "level_03")
s.node("Background", "Sprite2D", texture=tex(s, "res://assets/bg/level3.png"), centered="false")
s.node("Worm", parent=".", inst=scene(s, "res://scenes/StoneWorm.tscn"), position=v2(410, 10), scale=v2(0.8, 0.8), z_index=3)
s.node("Elevator", parent=".", inst=scene(s, "res://scenes/Elevator.tscn"), position=v2(1160, 436), z_index=4)
s.node("GroundFG", "Sprite2D", texture=tex(s, "res://assets/sprites/l3_ground_fg.png"), position=v2(1150, 780), centered="false", z_index=5)
terrain(s, [
    [(0, 488), (280, 488), (280, 560), (220, 640), (0, 640)],
    [(0, 700), (370, 705), (370, 941), (0, 941)],
    [(370, 812), (1672, 805), (1672, 941), (370, 941)],
])
npc(s, "Brother", 1470, 806, "npc_brother_sheet", 0.8)
npc(s, "Worker1", 1545, 806, "npc_worker_sheet", 0.76)
npc(s, "Worker2", 1615, 806, "npc_mechanic_sheet", 0.78)
miner(s, 190, 488, 0.85)
reflector(s, "CrystalA", 690, 768, length=170.0, thickness=22.0, sprite_scale=0.7, start_angle=25.0, stand_offset=v2(0, 30), stand_scale=1.3)
reflector(s, "CrystalB", 1432, 452, length=130.0, thickness=16.0, sprite_scale=0.54, start_angle=-45.0, stand_offset=v2(0, 34))
gems(s, GEMS[2])
rings(s, [(520, 600), (840, 640)])
Path("scenes/Level03.tscn").write_text(s.text())
print("levels written")
