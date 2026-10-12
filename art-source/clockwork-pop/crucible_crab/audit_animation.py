"""Read the delivered GLB, inspect numeric animation motion and loop endpoints."""
import json,struct,math
from pathlib import Path
root=Path(__file__).parent
raw=(root/'cp_crucible_crab.glb').read_bytes()
size=struct.unpack_from('<I',raw,12)[0]
doc=json.loads(raw[20:20+size]);binary=raw[28+size:]
def values(index):
    a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
    count={'SCALAR':1,'VEC3':3,'VEC4':4}[a['type']]
    offset=v.get('byteOffset',0)+a.get('byteOffset',0);step=v.get('byteStride',count*4)
    return [struct.unpack_from('<'+'f'*count,binary,offset+i*step) for i in range(a['count'])]
report=[]
for anim in doc['animations']:
    duration=0;moving=[];endpoint_delta=0
    for channel in anim['channels']:
        sampler=anim['samplers'][channel['sampler']]
        times=values(sampler['input']);v=values(sampler['output'])
        duration=max(duration,times[-1][0]-times[0][0])
        variation=max(abs(n-b) for row in v for n,b in zip(row,v[0]))
        endpoint_delta=max(endpoint_delta,max(abs(n-b) for n,b in zip(v[-1],v[0])))
        if variation>1e-5:
            moving.append({'node':doc['nodes'][channel['target']['node']]['name'],'path':channel['target']['path'],'range':round(variation,5)})
    report.append({'clip':anim['name'],'duration_s':round(duration,4),'channels':len(anim['channels']),'moving_channels':moving,'max_endpoint_delta':endpoint_delta})
(root/'animation_audit.json').write_text(json.dumps(report,indent=2))
print(json.dumps([{k:v for k,v in r.items() if k!='moving_channels'}|{'moving_channels':len(r['moving_channels'])} for r in report],indent=2))
