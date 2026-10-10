"""Verify exported reach, hand/bat position, and horizontal-only upgrade scaling."""
import bpy,json,math
from pathlib import Path
bpy.ops.wm.read_factory_settings(use_empty=True)
p=Path(__file__).parent;bpy.ops.import_scene.gltf(filepath=str(p/'cp_melee.glb'))
aim=bpy.data.objects['Aim'];muzzle=bpy.data.objects['Muzzle']
moving=[o for o in aim.children_recursive if o.type=='MESH']
fixed=[o for o in bpy.context.scene.objects if o.type=='MESH' and o not in moving]
def points(objs):return [o.matrix_world@v.co for o in objs for v in o.data.vertices]
def summary():
    bpy.context.view_layer.update();pts=points(moving)
    return {'tip':list(muzzle.matrix_world.translation),'tip_horizontal_reach':math.hypot(muzzle.matrix_world.translation.x,muzzle.matrix_world.translation.y),'maximum_physical_horizontal_reach':max(math.hypot(v.x,v.y) for v in pts),'moving_min_z':min(v.z for v in pts),'moving_max_z':max(v.z for v in pts),'fixed_vertices':[[round(v.x,7),round(v.y,7),round(v.z,7)] for v in points(fixed)]}
a=summary();aim.scale=(1.5,1.5,1);b=summary()
result={'rest':{k:v for k,v in a.items() if k!='fixed_vertices'},'upgrade_1_5':{k:v for k,v in b.items() if k!='fixed_vertices'},'fixed_geometry_unchanged':a['fixed_vertices']==b['fixed_vertices'],'height_unchanged':abs(a['moving_min_z']-b['moving_min_z'])<1e-6 and abs(a['moving_max_z']-b['moving_max_z'])<1e-6,'Muzzle_bare':len(muzzle.children)==0,'Muzzle_directly_under_Aim':muzzle.parent==aim,'Aim_identity_rotation':list(aim.rotation_euler),'moving_meshes':[o.name for o in moving],'fixed_meshes':[o.name for o in fixed]}
assert abs(a['tip_horizontal_reach']-1.2)<1e-6
assert abs(a['maximum_physical_horizontal_reach']-1.2)<1e-5
assert abs(b['tip_horizontal_reach']-1.8)<1e-6
assert result['height_unchanged'] and result['fixed_geometry_unchanged'] and result['Muzzle_bare'] and result['Muzzle_directly_under_Aim']
(p/'rig_audit.json').write_text(json.dumps(result,indent=2));print('RIG_AUDIT',json.dumps(result))
