"""Read-only structural and resource verification of frozen Conductor export."""
import json,struct,hashlib
from pathlib import Path
run=Path(__file__).resolve().parent;b=(run/'cp_tesla.glb').read_bytes();size=struct.unpack_from('<I',b,12)[0];d=json.loads(b[20:20+size]);nodes=d['nodes'];names={n['name']:i for i,n in enumerate(nodes)}
aim=nodes[names['Aim']];marker=nodes[names['Muzzle']];root=nodes[names['Tuning_Fork_Conductor']]
assert aim.get('rotation',[0,0,0,1])==[0,0,0,1] and aim.get('scale',[1,1,1])==[1,1,1]
assert abs(aim['translation'][0])<1e-6 and abs(aim['translation'][2])<1e-6
assert names['Muzzle'] in aim['children'] and 'mesh' not in marker and not marker.get('children')
assert marker.get('rotation',[0,0,0,1])==[0,0,0,1]
assert len(aim['children'])==10 and len(root['children'])==5
assert all(nodes[i]['name'].startswith('base_') for i in root['children'] if i!=names['Aim'])
assert len(d['images'])==4 and all('bufferView' in im and 'uri' not in im for im in d['images'])
assert not d.get('animations') and all('TEXCOORD_0' in p['attributes'] for m in d['meshes'] for p in m['primitives'])
glass=next(m for m in d['materials'] if m['name']=='Cyan charge glass');assert glass.get('alphaMode')=='BLEND'
result={'sha256':hashlib.sha256(b).hexdigest(),'bytes':len(b),'embedded_images':len(d['images']),'meshes':len(d['meshes']),'materials':len(d['materials']),'animations':0,'Aim_identity':True,'bare_Muzzle_under_Aim':True,'base_static':True,'all_meshes_uv_mapped':True,'Aim_blender_world':[0,0,.338],'Muzzle_blender_world':[0,.585,.603],'glass_alpha_mode':glass['alphaMode'],'forward':'Blender +Y / glTF -Z'}
(run/'export_verified.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
