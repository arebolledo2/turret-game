"""Freeze the inspected iteration without rebuilding or modifying the candidate."""
import hashlib
import json
import struct
from pathlib import Path

root=Path(__file__).resolve().parent
raw=(root/'cp_crossfire.glb').read_bytes()
length,kind=struct.unpack_from('<II',raw,12)
assert kind==0x4E4F534A
scene=json.loads(raw[20:20+length])
nodes=scene['nodes']
by_name={n['name']:i for i,n in enumerate(nodes) if 'name' in n}
parents={child:i for i,n in enumerate(nodes) for child in n.get('children',[])}
aim=by_name['Aim']
assert nodes[aim].get('rotation',[0,0,0,1])==[0,0,0,1]
markers={}
for name in ['Muzzle','Muzzle_1','Muzzle_2','Muzzle_3']:
    idx=by_name[name]; n=nodes[idx]
    assert parents[idx]==aim and 'mesh' not in n and not n.get('children')
    markers[name]={'parent':'Aim','translation_gltf_m':n.get('translation',[0,0,0]),'rotation_xyzw':n.get('rotation',[0,0,0,1]),'bare_empty':True}
report=json.loads((root/'renders/iter03/validate.json').read_text())
assert report['passed']
report.update({'final_iteration':3,'manual_inspection':'Concept and all five final views personally inspected; four radial open bores and mint window verified.','marker_audit':markers,'glb_bytes':len(raw),'self_score':8})
(root/'metrics.json').write_text(json.dumps(report,indent=2)+'\n')
files=['build_cp_crossfire.py','cp_crossfire.glb','cp_crossfire.blend','renders/iter03/validate.json','renders/iter03/compare.png']
freeze={'asset':'cp_crossfire','run':'cp_crossfire-v1','final_iteration':3,'frozen':True,'files':{f:{'sha256':hashlib.sha256((root/f).read_bytes()).hexdigest(),'bytes':(root/f).stat().st_size} for f in files}}
(root/'frozen_export.json').write_text(json.dumps(freeze,indent=2)+'\n')
print(json.dumps({'glb_sha256':freeze['files']['cp_crossfire.glb']['sha256'],'markers':markers},indent=2))
