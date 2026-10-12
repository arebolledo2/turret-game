"""Inspect the self-contained GLB clips without rebuilding the asset."""
import json, struct
from pathlib import Path
P=Path(__file__).parent
raw=(P/'eco_kite.glb').read_bytes()
length=struct.unpack_from('<I',raw,12)[0]
d=json.loads(raw[20:20+length]); start=20+length
blen,bkind=struct.unpack_from('<II',raw,start); binary=raw[start+8:start+8+blen]
width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
def vals(ai):
    a=d['accessors'][ai];v=d['bufferViews'][a['bufferView']];n=width[a['type']]
    assert a['componentType']==5126
    pos=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',n*4)
    return [struct.unpack_from('<'+'f'*n,binary,pos+i*stride) for i in range(a['count'])]
report={'animations':{},'embedded_images':len(d.get('images',[])),'all_images_embedded':all('bufferView' in i for i in d.get('images',[]))}
for animation in d['animations']:
    name=animation['name'];duration=0.;channels=[];max_delta=0.;loop=True
    for ch in animation['channels']:
        sampler=animation['samplers'][ch['sampler']];times=vals(sampler['input']);values=vals(sampler['output'])
        node=d['nodes'][ch['target']['node']]['name'];path=ch['target']['path']
        duration=max(duration,times[-1][0]-times[0][0])
        delta=max(abs(x-y) for value in values for x,y in zip(value,values[0]))
        max_delta=max(max_delta,delta)
        endpoint=max(abs(x-y) for x,y in zip(values[0],values[-1]))
        loop=loop and endpoint<1e-5
        channels.append({'node':node,'path':path,'endpoint_delta':round(endpoint,8),'motion_delta':round(delta,5)})
    report['animations'][name]={'duration_seconds':round(duration,4),'channels':channels,'returns_to_start':loop,'has_transform_motion':max_delta>1e-4,'root_stationary':all(c['node']!='Root' for c in channels)}
report['muzzle_bare']=all('mesh' not in n and not n.get('children') for n in d['nodes'] if n.get('name')=='Muzzle')
report['passed']=all(a['returns_to_start'] and a['has_transform_motion'] and a['root_stationary'] for a in report['animations'].values()) and report['all_images_embedded'] and report['muzzle_bare']
(P/'animation_audit.json').write_text(json.dumps(report,indent=2))
print(json.dumps({k:{p:v[p] for p in ('duration_seconds','returns_to_start','has_transform_motion','root_stationary')} for k,v in report['animations'].items()},indent=2))
print('PASS',report['passed'],'Images',report['embedded_images'],'bare Muzzle',report['muzzle_bare'])
