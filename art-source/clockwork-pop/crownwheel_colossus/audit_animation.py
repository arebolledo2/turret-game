"""Read the final self-contained GLB and record actual exported rigid animation motion."""
import json,struct,math
from pathlib import Path
out=Path(__file__).parent
raw=(out/'cp_crownwheel_colossus.glb').read_bytes()
length=struct.unpack_from('<I',raw,12)[0]
doc=json.loads(raw[20:20+length]);start=20+length+8
def accessor(idx):
    ac=doc['accessors'][idx];bv=doc['bufferViews'][ac['bufferView']]
    size={'SCALAR':1,'VEC3':3,'VEC4':4}[ac['type']]
    return [struct.unpack_from('<'+'f'*size,raw,start+bv.get('byteOffset',0)+ac.get('byteOffset',0)+i*bv.get('byteStride',4*size)) for i in range(ac['count'])]
report={'embedded_images':len(doc.get('images',[])),'external_uris':[i.get('uri') for i in doc.get('images',[]) if 'uri' in i],'clips':{}}
for anim in doc['animations']:
    clip={'duration_seconds':0,'channels':[]}
    for ch in anim['channels']:
        node=doc['nodes'][ch['target']['node']]['name'];path=ch['target']['path'];sam=anim['samplers'][ch['sampler']]
        times=accessor(sam['input']);values=accessor(sam['output'])
        clip['duration_seconds']=max(clip['duration_seconds'],round(times[-1][0]-times[0][0],4))
        detail={'node':node,'path':path,'samples':len(values),'first':values[0],'last':values[-1]}
        if path=='rotation':
            dot=abs(sum(a*b for a,b in zip(values[0],values[-1])))
            detail['endpoint_orientation_error_degrees']=round(math.degrees(2*math.acos(min(1,dot))),4)
        if node=='Wheel' and path=='rotation':
            angles=[2*math.atan2(v[0],v[3]) for v in values]
            total=sum((b-a+math.pi)%(2*math.pi)-math.pi for a,b in zip(angles,angles[1:]))
            detail['total_axle_rotation_degrees']=round(math.degrees(total),4)
            detail['maximum_nonaxle_quaternion_component']=max(max(abs(v[1]),abs(v[2])) for v in values)
        clip['channels'].append(detail)
    report['clips'][anim['name']]=clip
(out/'animation_audit.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
