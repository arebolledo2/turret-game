"""Inspect embedded resources and the transform payload of the final GLB."""
from pathlib import Path
import json,struct
P=Path(__file__).parent
raw=(P/'eco_anchor.glb').read_bytes()
length,kind=struct.unpack_from('<II',raw,12)
doc=json.loads(raw[20:20+length])
binary=raw[20+length+8:]
widths={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
formats={5126:'f',5123:'H',5125:'I',5121:'B',5122:'h',5120:'b'}
def accessor(index):
    a=doc['accessors'][index]; v=doc['bufferViews'][a['bufferView']]
    fmt='<'+formats[a['componentType']]*widths[a['type']]
    size=struct.calcsize(fmt); step=v.get('byteStride',size)
    offset=a.get('byteOffset',0)+v.get('byteOffset',0)
    return [struct.unpack_from(fmt,binary,offset+i*step) for i in range(a['count'])]
report={'images':[{'name':im.get('name'),'embedded':'bufferView' in im,'uri':im.get('uri')} for im in doc.get('images',[])],
        'mesh_nodes':sum('mesh' in n for n in doc['nodes']), 'skins':len(doc.get('skins',[])),
        'animations':[], 'body_animated':False,'only_cage_animated':True}
for anim in doc['animations']:
    entry={'name':anim['name'],'channels':[],'duration_seconds':0,'endpoints_match':True,'actual_motion':False}
    for channel in anim['channels']:
        node=doc['nodes'][channel['target']['node']]['name']; path=channel['target']['path']
        sampler=anim['samplers'][channel['sampler']]
        keys=accessor(sampler['input']); values=accessor(sampler['output'])
        end_error=max(abs(a-b) for a,b in zip(values[0],values[-1]))
        delta=max(max(abs(a-b) for a,b in zip(values[0],v)) for v in values)
        entry['duration_seconds']=max(entry['duration_seconds'],keys[-1][0]-keys[0][0])
        entry['endpoints_match'] &= end_error<.00001
        entry['actual_motion'] |= delta>.001
        entry['channels'].append({'node':node,'path':path,'samples':len(keys),'endpoint_error':end_error,'maximum_delta':delta})
        report['body_animated'] |= node=='Body'
        report['only_cage_animated'] &= node=='Cage'
    report['animations'].append(entry)
report['passed'] = (all(im['embedded'] and not im['uri'] for im in report['images']) and
    len(report['images'])==4 and not report['body_animated'] and report['only_cage_animated'] and
    report['skins']==0 and len(report['animations'])==4 and
    all(a['endpoints_match'] and a['actual_motion'] for a in report['animations']))
(P/'glb_audit.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
