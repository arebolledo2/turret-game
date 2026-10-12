"""Inspect the binary export without importing or modifying game assets."""
import json
import struct
from pathlib import Path

out=Path(__file__).parent
data=(out/'eco_lens.glb').read_bytes()
length,kind=struct.unpack_from('<II',data,12)
doc=json.loads(data[20:20+length])
offset=20+length
binary_length,binary_kind=struct.unpack_from('<II',data,offset)
binary=data[offset+8:offset+8+binary_length]
sizes={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
fmts={5126:'f',5125:'I',5123:'H',5121:'B'}
def accessor(index):
    a=doc['accessors'][index];view=doc['bufferViews'][a['bufferView']]
    fmt=fmts[a['componentType']];n=sizes[a['type']]
    step=view.get('byteStride',struct.calcsize('<'+fmt*n))
    start=view.get('byteOffset',0)+a.get('byteOffset',0)
    return [struct.unpack_from('<'+fmt*n,binary,start+i*step) for i in range(a['count'])]

animations=[]
for anim in doc.get('animations',[]):
    channels=[]
    for c in anim['channels']:
        s=anim['samplers'][c['sampler']]
        times=accessor(s['input']);values=accessor(s['output'])
        err=max(abs(a-b) for a,b in zip(values[0],values[-1]))
        channels.append({'node':doc['nodes'][c['target']['node']]['name'],'path':c['target']['path'],
                         'keys':len(times),'duration_s':times[-1][0]-times[0][0],
                         'rest_return_error':round(err,7),
                         'actual_motion':any(any(abs(a-b)>1e-6 for a,b in zip(v,values[0])) for v in values[1:])})
    animations.append({'name':anim['name'],'channels':channels})

animated={c['node'] for a in animations for c in a['channels']}
markers=[n for n in doc['nodes'] if n.get('name')=='Muzzle']
audit={'animations':animations,'stationary_root_and_body':not({'Satellite','Body'} & animated),
       'all_animation_names':sorted(a['name'] for a in animations),
       'bare_muzzle':len(markers)==1 and 'mesh' not in markers[0] and not markers[0].get('children'),
       'all_mesh_primitives_uv_mapped':all('TEXCOORD_0' in p['attributes'] for m in doc['meshes'] for p in m['primitives']),
       'embedded_images':len(doc.get('images',[])),
       'all_images_embedded':all('bufferView' in i and 'uri' not in i for i in doc.get('images',[])),
       'all_buffers_embedded':all('uri' not in b for b in doc.get('buffers',[])),
       'glb_bytes':len(data)}
(out/'export_audit.json').write_text(json.dumps(audit,indent=2))
print(json.dumps(audit,indent=2))
assert audit['stationary_root_and_body'] and audit['bare_muzzle']
assert audit['all_animation_names']==['Attack','Idle','Swim','Walk']
assert audit['all_mesh_primitives_uv_mapped'] and audit['all_images_embedded'] and audit['all_buffers_embedded']
assert all(any(c['actual_motion'] for c in a['channels']) for a in animations)
assert all(c['rest_return_error']<1e-6 for a in animations for c in a['channels'])
