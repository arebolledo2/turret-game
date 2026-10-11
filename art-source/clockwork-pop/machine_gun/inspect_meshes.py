import bpy
from pathlib import Path
bpy.ops.wm.open_mainfile(filepath=str(Path(__file__).parent/'cp_machine_gun.blend'))
for o in bpy.context.scene.objects:
    if o.type=='MESH':
        o.data.calc_loop_triangles();print(o.name,len(o.data.loop_triangles))
