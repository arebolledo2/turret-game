"""Read the exported glTF transform channels without another harness iteration."""
import json,struct,math
from pathlib import Path
HERE=Path(__file__).parent
raw=(HERE/'cp_skyfall_kestrel.glb').read_bytes(); length=struct.unpack_from('<I',raw,12)[0]; doc=json.loads(raw[20:20+length]); buf=raw[28+length:]
def read_acc(index):
    acc=doc['accessors'][index]; view=doc['bufferViews'][acc['bufferView']]; n={'SCALAR':1,'VEC3':3,'VEC4':4}[acc['type']]
    stride=view.get('byteStride',4*n); offset=view.get('byteOffset',0)+acc.get('byteOffset',0)
    return [struct.unpack_from('<'+'f'*n,buf,offset+i*stride) for i in range(acc['count'])]
result={'embedded_images':all('bufferView' in i and 'uri' not in i for i in doc.get('images',[])),'image_count':len(doc.get('images',[])),'clips':{}}
for anim in doc.get('animations',[]):
    channels=[]
    for channel in anim['channels']:
        sampler=anim['samplers'][channel['sampler']]; values=read_acc(sampler['output']); times=read_acc(sampler['input']); start,end=values[0],values[-1]
        diff=math.sqrt(sum((a-b)**2 for a,b in zip(start,end)))
        if channel['target']['path']=='rotation': diff=min(diff,math.sqrt(sum((a+b)**2 for a,b in zip(start,end))))
        movement=max(math.sqrt(sum((a-b)**2 for a,b in zip(start,v))) for v in values)
        channels.append({'node':doc['nodes'][channel['target']['node']]['name'],'path':channel['target']['path'],'duration':round(times[-1][0]-times[0][0],4),'endpoint_difference':round(diff,6),'sampled_motion':round(movement,6)})
    result['clips'][anim['name']]={'duration':max(c['duration'] for c in channels),'channel_count':len(channels),'returns_to_pose':all(c['endpoint_difference']<.0001 for c in channels),'channels':channels}
(HERE/'animation_audit.json').write_text(json.dumps(result,indent=2)); print(json.dumps({k:v if k!='clips' else {n:{kk:vv for kk,vv in c.items() if kk!='channels'} for n,c in v.items()} for k,v in result.items()},indent=2))
