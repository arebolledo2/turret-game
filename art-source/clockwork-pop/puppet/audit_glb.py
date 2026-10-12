"""Inspect exported binary animation samples, embedded images and root motion."""
import json, struct
from pathlib import Path

out=Path(__file__).resolve().parent
raw=(out/'eco_puppet.glb').read_bytes()
jlen=struct.unpack_from('<I',raw,12)[0]
doc=json.loads(raw[20:20+jlen])
bin_offset=20+jlen+8
sizes={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}

def values(index):
    a=doc['accessors'][index]; v=doc['bufferViews'][a['bufferView']]
    n=sizes[a['type']]; fmt={5126:'f',5125:'I',5123:'H',5121:'B'}[a['componentType']]
    stride=v.get('byteStride',struct.calcsize('<'+fmt*n))
    off=bin_offset+v.get('byteOffset',0)+a.get('byteOffset',0)
    return [struct.unpack_from('<'+fmt*n,raw,off+k*stride) for k in range(a['count'])]

result={'root':'PuppetRoot','stationary_root':True,'embedded_images':len(doc.get('images',[])),
        'external_images':[i for i in doc.get('images',[]) if 'uri' in i],'animations':[]}
for animation in doc['animations']:
    item={'name':animation['name'],'channels':len(animation['channels']),'duration_s':0,'endpoint_error':0,'moving_channels':0,'nodes':[]}
    for c in animation['channels']:
        name=doc['nodes'][c['target']['node']]['name']; sampler=animation['samplers'][c['sampler']]
        times=values(sampler['input']); samples=values(sampler['output'])
        item['duration_s']=max(item['duration_s'],times[-1][0]-times[0][0])
        err=max(abs(a-b) for a,b in zip(samples[0],samples[-1]))
        if c['target']['path']=='rotation':err=min(err,max(abs(a+b) for a,b in zip(samples[0],samples[-1])))
        item['endpoint_error']=max(item['endpoint_error'],err)
        if any(max(abs(a-b) for a,b in zip(samples[0],s))>1e-5 for s in samples):item['moving_channels']+=1
        item['nodes'].append(name)
        if name=='PuppetRoot':result['stationary_root']=False
    item['duration_s']=round(item['duration_s'],6)
    item['endpoint_error']=round(item['endpoint_error'],8)
    item['nodes']=sorted(set(item['nodes']))
    result['animations'].append(item)
assert result['stationary_root'] and not result['external_images']
assert {a['name'] for a in result['animations']}=={'Idle','Walk','Swim','Attack'}
assert all(a['moving_channels']>0 and a['endpoint_error']<1e-5 for a in result['animations'])
(out/'animation_audit.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
