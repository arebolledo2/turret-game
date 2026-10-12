import json, struct
from pathlib import Path
folder=Path(__file__).parent
raw=(folder/'cp_pendulum_regent.glb').read_bytes()
json_len=struct.unpack_from('<I',raw,12)[0]
doc=json.loads(raw[20:20+json_len]);bin_start=20+json_len+8
binary=raw[bin_start:]
def accessor(i):
    a=doc['accessors'][i];bv=doc['bufferViews'][a['bufferView']]
    dims={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
    off=bv.get('byteOffset',0)+a.get('byteOffset',0)
    stride=bv.get('byteStride',dims*4)
    return [struct.unpack_from('<'+'f'*dims,binary,off+j*stride) for j in range(a['count'])]
clips=[]
for animation in doc['animations']:
    entry={'name':animation['name'],'channels':len(animation['channels']),'duration_seconds':0,'loop_endpoint_max_error':0,'articulated_nodes':[]}
    for ch in animation['channels']:
        s=animation['samplers'][ch['sampler']];times=accessor(s['input']);values=accessor(s['output'])
        entry['duration_seconds']=max(entry['duration_seconds'],times[-1][0]-times[0][0])
        entry['loop_endpoint_max_error']=max(entry['loop_endpoint_max_error'],max(abs(a-b) for a,b in zip(values[0],values[-1])))
        node=doc['nodes'][ch['target']['node']]['name']
        if node not in entry['articulated_nodes']:entry['articulated_nodes'].append(node)
    clips.append(entry)
result={'clips':clips,'embedded_images':len(doc.get('images',[])),'external_image_uris':[i.get('uri') for i in doc.get('images',[]) if i.get('uri')],'bytes':len(raw)}
(folder/'animation_audit.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
