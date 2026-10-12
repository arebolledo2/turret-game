"""Audit embedded images, rigid channels, duration and seamless pose endpoints."""
import json, struct
from pathlib import Path
import numpy as np
here=Path(__file__).resolve().parent
raw=(here/'eco_lobber.glb').read_bytes()
jlen,jkind=struct.unpack_from('<II',raw,12)
doc=json.loads(raw[20:20+jlen]);bo=20+jlen
blen,bkind=struct.unpack_from('<II',raw,bo); binary=raw[bo+8:bo+8+blen]
sizes={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
def acc(i):
 a=doc['accessors'][i];v=doc['bufferViews'][a['bufferView']];types={5126:'<f4',5123:'<u2',5125:'<u4',5121:'u1'}
 start=v.get('byteOffset',0)+a.get('byteOffset',0)
 return np.frombuffer(binary,dtype=types[a['componentType']],count=a['count']*sizes[a['type']],offset=start).reshape((a['count'],sizes[a['type']]))
report={'images':[{'name':i.get('name'),'embedded':('bufferView' in i),'mime':i.get('mimeType')} for i in doc.get('images',[])], 'animations':[], 'nodes':[n['name'] for n in doc['nodes']]}
for a in doc.get('animations',[]):
 maxerr=0;changed=0;names=set();dur=0;root_channels=[]
 for c in a['channels']:
  sampler=a['samplers'][c['sampler']];times=acc(sampler['input']).flatten(); values=acc(sampler['output']);dur=max(dur,float(times[-1]-times[0]))
  maxerr=max(maxerr,float(np.max(abs(values[-1]-values[0]))));changed+=int(np.max(np.ptp(values,axis=0))>.00001)
  node=doc['nodes'][c['target']['node']]['name'];names.add(node)
  if node=='Kiln_Lobber':root_channels.append(c['target']['path'])
 report['animations'].append({'name':a['name'],'duration_s':round(dur,3),'channels':len(a['channels']),'changing_channels':changed,'animated_nodes':sorted(names),'endpoint_max_error':maxerr,'root_channels':root_channels})
report['muzzle']=next(n for n in doc['nodes'] if n.get('name')=='Muzzle')
assert len(report['images'])==4 and all(x['embedded'] for x in report['images'])
assert all(a['endpoint_max_error']<1e-5 and not a['root_channels'] and a['changing_channels']>0 for a in report['animations'])
assert 'mesh' not in report['muzzle'] and not report['muzzle'].get('children')
(here/'glb_audit.json').write_text(json.dumps(report,indent=2))
print(json.dumps({'animations':report['animations'],'images':report['images'],'muzzle':report['muzzle']},indent=2))
