"""Read-only GLB node, texture and wing-sweep audit. Run inside Blender."""
from pathlib import Path
import bpy,math,json,struct,hashlib
from mathutils import Matrix

OUT=Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUT/'cp_fast.glb'))
bpy.context.view_layer.update()
result={'hinges':{},'sweep_degrees':[-25,25]}
for name in ('Wing_L','Wing_R'):
    hinge=bpy.data.objects[name]
    mesh_children=[o for o in hinge.children_recursive if o.type=='MESH']
    lo=[1e9]*3;hi=[-1e9]*3
    side=1 if hinge.location.x>0 else -1
    for angle in range(-25,26):
        mat=hinge.matrix_world @ Matrix.Rotation(math.radians(angle)*side,4,'Y')
        for o in mesh_children:
            for v in o.data.vertices:
                q=mat @ o.matrix_local @ v.co
                for axis in range(3):lo[axis]=min(lo[axis],q[axis]);hi[axis]=max(hi[axis],q[axis])
    result['hinges'][name]={'parent':hinge.parent.name,'local_position_m':[round(v,6) for v in hinge.location],
        'rest_rotation_rad':[round(v,8) for v in hinge.rotation_euler],
        'rest_scale':[round(v,6) for v in hinge.scale],'mesh_children':len(mesh_children),
        'axis':'Blender local Y; glTF/Godot local Z, forward is Godot -Z',
        'swept_min_m':[round(v,6) for v in lo],'swept_max_m':[round(v,6) for v in hi]}
raw=(OUT/'cp_fast.glb').read_bytes();n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n])
result['embedded_images']=all('bufferView' in i and 'uri' not in i for i in doc['images'])
result['image_count']=len(doc['images']);result['animation_count']=len(doc.get('animations',[]))
result['bytes']=len(raw);result['sha256']=hashlib.sha256(raw).hexdigest()
(OUT/'export_audit.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
