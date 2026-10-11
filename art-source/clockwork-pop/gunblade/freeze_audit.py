"""Run-local immutable export audit, no build or rendering."""
import hashlib, json, struct
from pathlib import Path
p=Path(__file__).parent
raw=(p/'cp_gunblade.glb').read_bytes()
size=struct.unpack_from('<I',raw,12)[0]
doc=json.loads(raw[20:20+size])
nodes=doc['nodes']
important={n['name']:{k:v for k,v in n.items() if k not in ('name','extras')} for n in nodes if n.get('name') in ('Aim','Muzzle','BladeTip')}
out={'asset':'cp_gunblade','run':'cp_gunblade-v1','reviewed_iteration':3,
     'validation':json.loads((p/'renders/iter03/validate.json').read_text()),
     'nodes':important,'files':{}}
for name in ('build_cp_gunblade.py','cp_gunblade.glb','cp_gunblade.blend','contract.json','notes.md','renders/iter03/compare.png'):
    f=p/name;out['files'][name]={'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'bytes':f.stat().st_size}
(p/'frozen_audit.json').write_text(json.dumps(out,indent=2))
print(json.dumps(out['files'],indent=2))
