"""Independent pivot and bore-depth audit of the frozen Blender source."""
import bpy
import bmesh
import json
import hashlib
import struct
from pathlib import Path
from mathutils import Vector

OUT=Path(__file__).parent
bpy.ops.wm.open_mainfile(filepath=str(OUT/'cp_bowling_ball.blend'))
o=bpy.data.objects['BowlingBall']
bm=bmesh.new();bm.from_mesh(o.data)
seen=set();components=0
for v in bm.verts:
    if v in seen:continue
    components+=1;stack=[v]
    while stack:
        cur=stack.pop()
        if cur in seen:continue
        seen.add(cur)
        stack.extend(e.other_vert(cur) for e in cur.link_edges)
bm.free()
depths=[]
for normal in [Vector(v).normalized() for v in [(-.23,.76,.61),(.22,.77,.60),(-.01,.91,.415)]]:
    hit,location,_,_=o.ray_cast(normal*.36,-normal,distance=.3)
    assert hit
    depths.append(round(.24-location.dot(normal),6))
assert all(d>.055 for d in depths),depths
assert o.location.length<1e-7 and o.rotation_euler.to_matrix()==o.rotation_euler.to_matrix().Identity(3)
assert components==1,components
glb=(OUT/'cp_bowling_ball.glb').read_bytes()
json_length,chunk_type=struct.unpack_from('<II',glb,12)
doc=json.loads(glb[20:20+json_length])
audit={'source_components':components,'finger_bore_depth_m':depths,'origin':list(o.location),
       'dimensions_m':list(o.dimensions),'all_images_embedded':all('bufferView' in i for i in doc.get('images',[])),
       'glb_sha256':hashlib.sha256(glb).hexdigest(),'harness_iteration':1,'passed':True}
(OUT/'final_audit.json').write_text(json.dumps(audit,indent=2))
print(json.dumps(audit,indent=2))
