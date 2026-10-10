"""Re-import final GLB and check six root-level hip hinges and independent shell bob."""
import bpy,json
from pathlib import Path
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
p=Path(__file__).parent;bpy.ops.import_scene.gltf(filepath=str(p/'cp_tank.glb'))
body=bpy.data.objects['Body'];legs=[bpy.data.objects[f'Leg_{side}_{i}'] for side in ('L','R') for i in range(3)]
def pts(o):return [m.matrix_world@v.co for m in o.children_recursive if m.type=='MESH' for v in m.data.vertices]
def lo(o):return min(v.z for v in pts(o))
def snap(o):return [[round(v.x,7),round(v.y,7),round(v.z,7)] for v in pts(o)]
fixed=snap(body);results={}
for o in legs:
    o.rotation_mode='XYZ'
    assert o.type=='EMPTY' and o.parent is None and len(o.children_recursive)>=1
    assert all(abs(v)<1e-7 for v in o.rotation_euler) and all(abs(v-1)<1e-7 for v in o.scale)
    before=lo(o);s=1 if '_L_' in o.name else -1
    o.rotation_euler.y=s*.16;bpy.context.view_layer.update();after=lo(o)
    assert after>before+.012
    assert snap(body)==fixed
    results[o.name]={'hip_world':list(o.matrix_world.translation),'mesh_descendants':[v.name for v in o.children_recursive if v.type=='MESH'],'rotation_identity_at_rest':True,'min_z_rest':before,'min_z_lift_0_16rad':after,'lift_axis_blender':'Y','lift_sign_blender':s,'lift_axis_godot':'Z','lift_sign_godot':-s,'stride_axis_blender':'Z','stride_axis_godot':'Y','forward_stride_sign':-1 if '_L_' in o.name else 1}
    o.rotation_euler.y=0;bpy.context.view_layer.update()
leg_fixed=[snap(o) for o in legs]
body.location.z+=.02;bpy.context.view_layer.update()
assert leg_fixed==[snap(o) for o in legs]
out={'legs':results,'six_independent_root_level_hips':True,'leg_lift_leaves_body_unchanged':True,'body_bob_leaves_legs_unchanged':True,'Body_identity_rotation':list(body.rotation_euler)}
(p/'rig_audit.json').write_text(json.dumps(out,indent=2));print('RIG_AUDIT',json.dumps(out))
