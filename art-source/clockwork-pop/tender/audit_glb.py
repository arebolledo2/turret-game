"""Read exported animation data directly; no Blender/source-only assumptions."""
import json,struct
from pathlib import Path
path=Path(__file__).parent/'eco_tender.glb';raw=path.read_bytes();n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n]);bo=20+n+8;blob=raw[bo:]
def values(index):
    a=doc['accessors'][index];b=doc['bufferViews'][a['bufferView']];size={'SCALAR':1,'VEC3':3,'VEC4':4}[a['type']];stride=b.get('byteStride',size*4);off=b.get('byteOffset',0)+a.get('byteOffset',0)
    return [struct.unpack_from('<'+'f'*size,blob,off+j*stride) for j in range(a['count'])]
nodes=doc['nodes'];report={'root_stationary':True,'embedded_images':len(doc.get('images',[])),'clips':{}}
for anim in doc['animations']:
    duration=0;diff=0;targets=[];hatchangles=[]
    for c in anim['channels']:
        s=anim['samplers'][c['sampler']];ts=values(s['input']);vs=values(s['output']);name=nodes[c['target']['node']]['name'];duration=max(duration,ts[-1][0]);diff=max(diff,max(abs(a-b) for a,b in zip(vs[0],vs[-1])));targets.append(name)
        if name=='Body':report['root_stationary']=False
        if name=='Hatch' and c['target']['path']=='rotation':hatchangles=[2*__import__('math').acos(min(1,abs(v[3]))) for v in vs]
    report['clips'][anim['name']]={'duration_s':round(duration,4),'channels':len(anim['channels']),'pose_endpoint_error':diff,'animated_nodes':sorted(set(targets)),'hatch_max_angle_degrees':round(max(hatchangles,default=0)*180/__import__('math').pi,2)}
(path.parent/'animation_audit.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
