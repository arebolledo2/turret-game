"""Read-only GLB audit: clips, loop seams, explicit weapon marker contracts."""
import json, struct, math
from pathlib import Path
HERE=Path(__file__).resolve().parent
raw=(HERE/'cp_broadside_baron.glb').read_bytes()
n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n])
binary=raw[28+n:]
def acc(i):
    a=doc['accessors'][i];bv=doc['bufferViews'][a['bufferView']]
    comps={'SCALAR':1,'VEC3':3,'VEC4':4}[a['type']]
    fmt={5126:'f',5123:'H',5125:'I'}[a['componentType']]
    step=bv.get('byteStride',struct.calcsize('<'+fmt*comps))
    offset=bv.get('byteOffset',0)+a.get('byteOffset',0)
    return [struct.unpack_from('<'+fmt*comps,binary,offset+j*step) for j in range(a['count'])]
clips=[]
for an in doc['animations']:
    errors=[];duration=0
    for ch in an['channels']:
        s=an['samplers'][ch['sampler']];ts=acc(s['input']);vals=acc(s['output'])
        duration=max(duration,ts[-1][0]-ts[0][0]);path=ch['target']['path']
        a,b=vals[0],vals[-1]
        if path=='rotation':error=1-abs(sum(x*y for x,y in zip(a,b)))
        else:error=max(abs(x-y) for x,y in zip(a,b))
        errors.append(error)
    clips.append({'name':an['name'],'seconds':round(duration,4),'channels':len(an['channels']),'endpoint_error':round(max(errors),8),'returns_to_rest':max(errors)<1e-5})
node_index={n['name']:i for i,n in enumerate(doc['nodes'])}
stations=[]
for label in ['FL','FR','RL','RR']:
    c=doc['nodes'][node_index['Cannon_'+label]];r=doc['nodes'][node_index['Recoil_'+label]];m=doc['nodes'][node_index['Muzzle_'+label]]
    stations.append({'station':label,'cannon_rotation_xyzw':c.get('rotation',[0,0,0,1]),'marker_translation_gltf_yup':m['translation'],'recoil_under_cannon':node_index['Recoil_'+label] in c.get('children',[]),'muzzle_under_recoil':node_index['Muzzle_'+label] in r.get('children',[])})
result={'animations':clips,'stations':stations,'embedded_images':len(doc.get('images',[])),'all_images_embedded':all('bufferView' in i for i in doc.get('images',[])),'file_bytes':len(raw)}
(HERE/'export_audit.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
