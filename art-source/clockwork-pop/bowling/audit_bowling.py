"""Explicit bowling launch contract, replacing the generic >0.3m cannon rule."""
import bpy,json,hashlib
from pathlib import Path
from mathutils import Vector
out=Path(__file__).parent
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(out/'cp_bowling.glb'))
aim=bpy.data.objects['Aim'];muzzle=bpy.data.objects['Muzzle'];ball=bpy.data.objects['LoadedBall']
base=bpy.data.objects['Static coral rounded plinth']
def under(o,parent):
    while o.parent:
        o=o.parent
        if o==parent:return True
    return False
maximum_y=max((o.matrix_world@Vector(c))[1]for o in bpy.context.scene.objects if o.type=='MESH' for c in o.bound_box)
m=muzzle.matrix_world.translation
checks={
 'Aim_is_empty':aim.type=='EMPTY',
 'Aim_at_base_axis':abs(aim.matrix_world.translation.x)<1e-6 and abs(aim.matrix_world.translation.y)<1e-6,
 'Aim_identity_rotation':all(abs(a)<1e-6 for a in aim.rotation_euler),
 'Muzzle_is_bare_empty':muzzle.type=='EMPTY' and not muzzle.children,
 'Muzzle_under_Aim':under(muzzle,aim),
 'Muzzle_forward_exit':m.y>1.4 and abs(m.y-maximum_y)<.06,
 'Muzzle_raised_bowling_height':.15<=m.z<=.30,
 'Muzzle_faces_positive_Y':(muzzle.matrix_world.to_quaternion()@Vector((0,1,0))).dot(Vector((0,1,0)))>.999,
 'LoadedBall_separate_mesh':ball.type=='MESH' and under(ball,aim),
 'base_static':not under(base,aim),
 'all_weapon_geometry_under_Aim':all(under(o,aim)for o in bpy.context.scene.objects if o.type=='MESH' and o!=base),
}
audit={'checks':checks,'passed':all(checks.values()),'muzzle_blender_m':list(m),'forward_bound_y_m':maximum_y,
 'validator_exception':'Generic muzzle_forward is disabled in local contract because the shared validator hardcodes >0.3m. The bowling brief specifies about 0.2m; explicit approved range is 0.15..0.30m.',
 'glb_sha256':hashlib.sha256((out/'cp_bowling.glb').read_bytes()).hexdigest(),
 'builder_sha256':hashlib.sha256((out/'build_cp_bowling.py').read_bytes()).hexdigest()}
(out/'bowling_contract_audit.json').write_text(json.dumps(audit,indent=2))
print(json.dumps(audit,indent=2))
assert audit['passed']
