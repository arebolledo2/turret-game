"""Record immutable reviewed source/export hashes and GLB pivot audit."""
from pathlib import Path
import json, hashlib, struct

root=Path(__file__).resolve().parent
raw=(root/'cp_flamethrower.glb').read_bytes()
length,kind=struct.unpack_from('<II',raw,12)
doc=json.loads(raw[20:20+length])
nodes=doc['nodes']
named={node.get('name'):i for i,node in enumerate(nodes)}
aim=named['Aim'];muzzle=named['Muzzle']
desc=[]
def walk(index):
    for child in nodes[index].get('children',[]):
        desc.append(child);walk(child)
walk(aim)
assert muzzle in desc
assert 'mesh' not in nodes[aim] and 'mesh' not in nodes[muzzle]
assert nodes[aim].get('rotation',[0,0,0,1])==[0,0,0,1]
assert nodes[aim].get('translation',[0,0,0])==[0,0,0]
static=[node['name'] for i,node in enumerate(nodes) if 'mesh' in node and i not in desc]
assert len(static)==1 and static[0].startswith('Static_')
report=json.loads((root/'renders/iter06/validate.json').read_text())
files=['build_cp_flamethrower.py','cp_flamethrower.glb','cp_flamethrower.blend','contract.json','notes.md','renders/iter06/compare.png']
audit={
    'asset':'cp_flamethrower','run':'cp_flamethrower-v1','frozen_iteration':6,'harness_calls':6,
    'reviewed_render':'renders/iter06/compare.png','contract_passed':report['passed'],
    'triangles':report['triangles'],'mesh_objects':report['mesh_objects'],'materials':report['materials'],
    'size_m':report['size_m'],'target_overruns':report['target_overruns'],
    'pivot_audit':{'Aim':nodes[aim],'Muzzle':nodes[muzzle],'all_upper_meshes_under_Aim':True,'static_meshes':static},
    'textures':len(doc.get('images',[])),'animations':len(doc.get('animations',[])),
    'files':{name:{'sha256':hashlib.sha256((root/name).read_bytes()).hexdigest(),'bytes':(root/name).stat().st_size} for name in files}}
(root/'freeze.json').write_text(json.dumps(audit,indent=2)+'\n')
print(json.dumps(audit,indent=2))
