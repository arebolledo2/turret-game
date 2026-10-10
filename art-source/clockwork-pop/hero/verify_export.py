"""Verify and document Pip's authored identity rest rig, without modifying the GLB."""
import json,struct,hashlib
from pathlib import Path
run=Path(__file__).resolve().parent;b=(run/'cp_hero.glb').read_bytes();size=struct.unpack_from('<I',b,12)[0];d=json.loads(b[20:20+size]);nodes=d['nodes'];names={n['name']:i for i,n in enumerate(nodes)}
parents={child:i for i,n in enumerate(nodes) for child in n.get('children',[])}
expected={'Body':'Pip_Lantern_Keeper','Head':'Body','Arm_L':'Body','Arm_R':'Body','Leg_L':'Pip_Lantern_Keeper','Leg_R':'Pip_Lantern_Keeper','Muzzle':'Arm_R'}
def world_pos(i):
    p=nodes[i].get('translation',[0,0,0]);up=parents.get(i)
    if up is not None:return [a+b for a,b in zip(p,world_pos(up))]
    return p
rig={}
for name,parent in expected.items():
    idx=names[name];n=nodes[idx]
    assert n.get('rotation',[0,0,0,1])==[0,0,0,1] and n.get('scale',[1,1,1])==[1,1,1]
    assert nodes[parents[idx]]['name']==parent and 'mesh' not in n
    rig[name]={'parent':parent,'blender_world':[round(world_pos(idx)[0],6),round(-world_pos(idx)[2],6),round(world_pos(idx)[1],6)],'gltf_local_translation':n.get('translation',[0,0,0]),'identity_rest_rotation':True}
    if name=='Muzzle':assert not n.get('children')
    else:assert any('mesh' in nodes[c] for c in n.get('children',[]))
assert len(d['images'])==4 and all('bufferView' in im and 'uri' not in im for im in d['images'])
assert not d.get('animations') and not d.get('skins')
assert all('TEXCOORD_0' in p['attributes'] for m in d['meshes'] for p in m['primitives'])
glass=next(m for m in d['materials'] if m['name']=='Cyan lantern glass');assert glass.get('alphaMode')=='BLEND'
assert abs(rig['Muzzle']['blender_world'][0]+.267)<1e-5 and abs(rig['Muzzle']['blender_world'][1]-.452)<1e-5 and abs(rig['Muzzle']['blender_world'][2]-.609)<1e-5
result={'sha256':hashlib.sha256(b).hexdigest(),'bytes':len(b),'embedded_images':len(d['images']),'meshes':len(d['meshes']),'materials':len(d['materials']),'animations':0,'skins':0,'all_rest_rotations_identity':True,'all_meshes_uv_mapped':True,'lantern_alpha_mode':glass['alphaMode'],'forward':'Blender +Y / glTF -Z','anatomical_right':'Blender X negative','rig':rig}
(run/'export_verified.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
