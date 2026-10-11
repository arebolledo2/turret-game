import bpy,json
from pathlib import Path
p=Path(__file__).parent
bpy.ops.wm.open_mainfile(filepath=str(p/'cp_bowling.blend'))
for o in bpy.context.scene.objects:
 if o.type=='MESH':
  o.data.calc_loop_triangles();print(o.name,len(o.data.loop_triangles))
