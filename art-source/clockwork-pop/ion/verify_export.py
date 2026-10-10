"""Read-only verification of the frozen self-contained GLB."""
import json, struct, hashlib
from pathlib import Path
run=Path(__file__).resolve().parent
p=run/'cp_ion.glb';b=p.read_bytes()
size=struct.unpack_from('<I',b,12)[0];doc=json.loads(b[20:20+size])
nodes=doc['nodes'];names={n['name']:i for i,n in enumerate(nodes)}
aim=nodes[names['Aim']];muzzle=nodes[names['Muzzle']];root=nodes[names['Pepperbox_Watchman']]
assert names['Muzzle'] in aim['children']
assert 'mesh' not in muzzle and not muzzle.get('children')
assert aim.get('rotation',[0,0,0,1])==[0,0,0,1]
assert muzzle.get('rotation',[0,0,0,1])==[0,0,0,1]
assert aim.get('scale',[1,1,1])==[1,1,1]
assert abs(aim['translation'][0])<1e-6 and abs(aim['translation'][2])<1e-6
assert len(aim['children'])==10 # nine rigid upper meshes plus marker
assert len(root['children'])==4 # Aim plus three fixed pedestal meshes
assert len(doc['images'])==4 and all('bufferView' in i and 'uri' not in i for i in doc['images'])
assert not doc.get('animations')
assert all('TEXCOORD_0' in p['attributes'] for m in doc['meshes'] for p in m['primitives'])
result={'sha256':hashlib.sha256(b).hexdigest(),'bytes':len(b),'embedded_images':len(doc['images']),'meshes':len(doc['meshes']),'materials':len(doc['materials']),'animations':0,'Aim_identity':True,'bare_Muzzle_under_Aim':True,'base_static':True,'all_meshes_uv_mapped':True,'Muzzle_blender_world':[-.112,.540,.706],'forward':'Blender +Y / glTF -Z'}
(run/'export_verified.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
