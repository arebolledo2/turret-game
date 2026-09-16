"""Rebuild the first 3D asset family with Blender's bundled Python.

Run: blender --background --python tools/blender/build_slice_assets.py
No external packages or model services. Blender +Y becomes Godot -Z (forward).
"""
import json
import math
import argparse
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/slice"
SOURCE = ROOT / "art-source/blender"
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)


def material(name, color, metal=0.0, glow=False):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Roughness"].default_value = 0.38
    if glow:
        shader.inputs["Emission Color"].default_value = (*color, 1)
        shader.inputs["Emission Strength"].default_value = 2.0
    return mat


def empty(name, pos=(0, 0, 0), parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = pos
    return obj


def finish(obj, name, mat, parent):
    obj.name = name
    obj.data.materials.append(mat)
    obj.parent = parent
    return obj


def box(name, pos, size, mat, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel = obj.modifiers.new("Machined edges", "BEVEL")
    bevel.width = 0.025
    bevel.segments = 1
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return finish(obj, name, mat, parent)


def cylinder(name, pos, radius, depth, mat, parent=None, vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=pos)
    return finish(bpy.context.object, name, mat, parent)


def sphere(name, pos, radius, mat, parent=None, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=radius, location=pos)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return finish(obj, name, mat, parent)


def strut(name, start, end, radius, mat, parent=None):
    a, b = Vector(start), Vector(end)
    obj = cylinder(name, (a + b) / 2, radius, (b - a).length, mat, parent, 8)
    obj.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
    return obj


def save_asset(name, reference, sockets):
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    triangles = 0
    for obj in meshes:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / f"{name}.blend"))
    bpy.ops.export_scene.gltf(filepath=str(OUT / f"{name}.glb"), export_format="GLB",
                              export_yup=True, export_animations=False, export_cameras=False,
                              export_lights=False)
    return {"id": name, "triangles": triangles, "mesh_parts": len(meshes),
            "materials": len({m.name for o in meshes for m in o.data.materials}),
            "reference": reference, "required_nodes": sockets,
            "source": f"art-source/blender/{name}.blend",
            "model": f"assets/models/slice/{name}.glb",
            "forward": "Godot -Z", "units": "metres", "origin": "ground centre",
            "animation": "Runtime rigid-part articulation; no skeletal rig"}


def build_turret():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    shell = material("Ceramic silver", (0.65, 0.76, 0.8), 0.65)
    dark = material("Graphite", (0.035, 0.07, 0.1), 0.7)
    cyan = material("Ion cyan", (0.04, 0.8, 1), 0.2, True)
    root = empty("TurretModel")
    cylinder("Foot", (0, 0, 0.12), 0.43, 0.24, dark, root)
    cylinder("BaseRim", (0, 0, 0.27), 0.38, 0.09, shell, root)
    cylinder("Reactor", (0, 0, 0.45), 0.17, 0.32, cyan, root)
    for angle in (0, 2.094, 4.189):
        x, y = math.cos(angle), math.sin(angle)
        strut("Support", (x * .17, y * .17, .5), (x * .44, y * .44, .06), .055, shell, root)
    aim = empty("Aim", (0, 0, .63), root)
    box("Housing", (0, 0, .02), (.5, .45, .25), shell, aim)
    box("TopInset", (0, -.03, .16), (.3, .28, .035), dark, aim)
    for x in (-.105, .105):
        strut("Barrel", (x, .15, .02), (x, .64, .02), .06, dark, aim)
        tip = cylinder("Emitter", (x, .655, .02), .068, .035, cyan, aim)
        tip.rotation_euler.x = math.pi / 2
    empty("Muzzle", (0, .7, .02), aim)
    return save_asset("ion_turret", "assets/sprites/turrets/turret_basic.png", ["Aim", "Muzzle"])


def build_drone(charger=False):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    shell = material("Drone graphite", (.12, .16, .2), .6)
    orange = material("Hazard copper", (.95, .34, .04), .45)
    red = material("Threat red", (1, .035, .12), .1, True)
    root = empty("DroneModel")
    sphere("Carapace", (0, 0, .48), .34, shell, root, (1, 1.1, .85))
    cylinder("Crown", (0, 0, .7), .16, .055, orange, root)
    eye = cylinder("EyeRing", (0, .32, .5), .15, .09, orange, root)
    eye.rotation_euler.x = math.pi / 2
    sphere("Eye", (0, .375, .5), .112, red, root, (1, .4, 1))
    if charger:
        # Broad amber armor and forward horns identify a charger at gameplay scale.
        box("RamArmor", (0, .04, .69), (.63, .55, .12), orange, root)
        for side in (-1, 1):
            strut("RamHorn", (side * .2, .28, .59), (side * .26, .66, .49), .055, orange, root)
        box("Spine", (0, -.16, .81), (.1, .3, .07), red, root)
    for side in (-1, 1):
        for index, y in enumerate((-.23, 0, .23)):
            leg = empty(f"Leg_{'L' if side < 0 else 'R'}_{index}", (side * .25, y, .43), root)
            knee = (side * .23, y * .35, .06)
            foot = (side * .35, y * .55, -.39)
            strut("Upper", (0, 0, 0), knee, .048, orange, leg)
            strut("Lower", knee, foot, .04, shell, leg)
            sphere("Joint", knee, .063, red, leg)
    return save_asset("charger_drone" if charger else "spider_drone", "assets/sprites/enemy_spider_drone/spider_drone_right.png",
                      [f"Leg_{side}_{i}" for side in ("L", "R") for i in range(3)])


def build_plasma():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    shell = material("Ceramic silver", (.65, .76, .8), .65)
    dark = material("Graphite", (.035, .07, .1), .7)
    energy = material("Plasma violet", (.48, .08, 1), .2, True)
    root = empty("PlasmaModel")
    cylinder("Foot", (0, 0, .13), .47, .26, dark, root)
    cylinder("BaseRim", (0, 0, .29), .43, .07, shell, root)
    cylinder("Reactor", (0, 0, .48), .18, .34, energy, root)
    for angle in (0, 2.094, 4.189):
        x, y = math.cos(angle), math.sin(angle)
        strut("Support", (x * .2, y * .2, .6), (x * .4, y * .4, .15), .045, shell, root)
    aim = empty("Aim", (0, 0, .67), root)
    sphere("Chamber", (0, 0, .03), .24, dark, aim, (1, 1.2, 1))
    for y in (.05, .23, .4):
        ring = cylinder("AccelerationRing", (0, y, .03), .23, .045, shell, aim)
        ring.rotation_euler.x = math.pi / 2
    sphere("PlasmaCore", (0, .28, .03), .16, energy, aim, (1, 1.7, 1))
    for x in (-.21, .21):
        box("Rail", (x, .22, .03), (.055, .6, .1), dark, aim)
    empty("Muzzle", (0, .55, .03), aim)
    return save_asset("plasma_turret", "assets/sprites/turrets/turret_plasma_static.png", ["Aim", "Muzzle"])


def build_player():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    shell = material("Scout silver", (.62, .75, .77), .6)
    copper = material("Scout copper", (.65, .3, .1), .55)
    cyan = material("Scout cyan", (.03, .9, .85), .2, True)
    root = empty("PlayerModel")
    sphere("Hull", (0, 0, .52), .32, shell, root, (1, .85, 1.12))
    cylinder("Waist", (0, 0, .4), .305, .08, copper, root)
    cylinder("HoverRing", (0, 0, .17), .18, .055, cyan, root)
    sphere("Dome", (0, 0, .87), .245, copper, root, (1, 1, .8))
    sphere("Visor", (0, .205, .88), .175, cyan, root, (1, .35, .65))
    for side in (-1, 1):
        sphere("Shoulder", (side * .33, 0, .58), .115, copper, root)
        box("SidePlate", (side * .34, 0, .48), (.12, .25, .27), shell, root)
    strut("Gun", (.34, 0, .58), (.34, .47, .58), .065, copper, root)
    sphere("Emitter", (.34, .47, .58), .05, cyan, root)
    empty("Muzzle", (.34, .53, .58), root)
    return save_asset("player_bot", "assets/sprites/player/player_static.png", ["Muzzle"])


def build_shock():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    shell = material("Shock silver", (.65, .76, .8), .65)
    dark = material("Shock graphite", (.035, .07, .1), .7)
    energy = material("Shock cyan", (.04, .75, 1), .2, True)
    root = empty("ShockModel")
    cylinder("Foot", (0, 0, .12), .47, .24, dark, root)
    cylinder("Rim", (0, 0, .26), .44, .08, shell, root)
    cylinder("Core", (0, 0, .49), .17, .42, energy, root)
    for angle in (0, 2.094, 4.189):
        x, y = math.cos(angle), math.sin(angle)
        strut("Support", (x * .17, y * .17, .67), (x * .37, y * .37, .25), .065, shell, root)
    aim = empty("Aim", (0, 0, .74), root)
    cylinder("EmitterRing", (0, 0, 0), .4, .1, shell, aim)
    sphere("PulseDome", (0, 0, .07), .27, energy, aim, (1, 1, .8))
    for index in range(6):
        angle = index * math.tau / 6
        box("Electrode", (.34 * math.cos(angle), .34 * math.sin(angle), .11), (.11, .11, .18), dark, aim)
    empty("Muzzle", (0, .45, .08), aim)
    return save_asset("shock_turret", "assets/sprites/turrets/turret_shock.png", ["Aim", "Muzzle"])


builders = {"ion_turret": build_turret, "spider_drone": build_drone,
            "plasma_turret": build_plasma, "charger_drone": lambda: build_drone(True), "player_bot": build_player,
            "shock_turret": build_shock}
parser = argparse.ArgumentParser()
parser.add_argument("--only", nargs="+", choices=list(builders))
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
manifest_path = OUT / "manifest.json"
previous = json.loads(manifest_path.read_text(encoding="utf-8"))["assets"] if manifest_path.exists() else []
by_id = {asset["id"]: asset for asset in previous}
for name in args.only or builders:
    by_id[name] = builders[name]()
assets = [by_id[name] for name in builders if name in by_id]
manifest_path.write_text(json.dumps({"version": 2, "generator": "tools/blender/build_slice_assets.py",
    "blender": bpy.app.version_string, "assets": assets}, indent=2) + "\n", encoding="utf-8", newline="\n")
print("ASSET_MANIFEST " + json.dumps(assets))
