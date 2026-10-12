"""Check embedded payload, rigid clip durations/endpoints, and stationary root."""
import json, struct
from pathlib import Path
p=Path(__file__).parent
raw=(p/'eco_ram.glb').read_bytes()
n=struct.unpack_from('<I',raw,12)[0]
doc=json.loads(raw[20:20+n])
bin_start=20+n+8
def values(index):
    a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
    width={'SCALAR':1,'VEC3':3,'VEC4':4}[a['type']]
    stride=v.get('byteStride',width*4)
    start=bin_start+v.get('byteOffset',0)+a.get('byteOffset',0)
    return [struct.unpack_from('<'+'f'*width,raw,start+i*stride) for i in range(a['count'])]
clips=[]
for a in doc['animations']:
    duration=0;error=0;animated=set()
    for c in a['channels']:
        samp=a['samplers'][c['sampler']]
        times=values(samp['input']);out=values(samp['output'])
        duration=max(duration,times[-1][0])
        error=max(error,max(abs(u-v) for u,v in zip(out[0],out[-1])))
        animated.add(doc['nodes'][c['target']['node']]['name'])
    clips.append({'name':a['name'],'seconds':duration,'channels':len(a['channels']),
                  'endpoint_max_error':error,'animated_nodes':sorted(animated),'root_stationary':'Root' not in animated})
report={'bytes':len(raw),'embedded_images':len(doc.get('images',[])),
        'all_images_embedded':all('bufferView' in i and 'uri' not in i for i in doc.get('images',[])),
        'skin_count':len(doc.get('skins',[])),'clips':clips}
(p/'animation_audit.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
