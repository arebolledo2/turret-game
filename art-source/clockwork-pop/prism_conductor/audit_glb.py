from pathlib import Path
import json, struct

out=Path(__file__).parent
raw=(out/'eco_prism.glb').read_bytes()
length,kind=struct.unpack_from('<II',raw,12)
doc=json.loads(raw[20:20+length]);offset=20+length
blen,bkind=struct.unpack_from('<II',raw,offset);binary=raw[offset+8:offset+8+blen]
components={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
types={5126:'f',5125:'I',5123:'H',5121:'B'}
def accessor(idx):
    a=doc['accessors'][idx];bv=doc['bufferViews'][a['bufferView']];n=components[a['type']];fmt='<'+types[a['componentType']]*n;size=struct.calcsize(fmt)
    start=bv.get('byteOffset',0)+a.get('byteOffset',0);stride=bv.get('byteStride',size)
    return [struct.unpack_from(fmt,binary,start+i*stride) for i in range(a['count'])]
nodes=doc['nodes'];clips=[]
for a in doc.get('animations',[]):
    channels=[];duration=0
    for c in a['channels']:
        sam=a['samplers'][c['sampler']];t=accessor(sam['input']);v=accessor(sam['output']);node=nodes[c['target']['node']]['name'];path=c['target']['path']
        duration=max(duration,t[-1][0]-t[0][0]);err=max(abs(x-y) for x,y in zip(v[0],v[-1]))
        if path=='rotation':err=min(err,max(abs(x+y) for x,y in zip(v[0],v[-1])))
        motion=max(max(abs(x-y) for x,y in zip(v[0],frame)) for frame in v)
        channels.append({'node':node,'path':path,'keys':len(t),'endpoint_error':err,'motion_max':motion})
    clips.append({'name':a.get('name'),'duration_s':round(duration,4),'channels':channels,'root_stationary':all(c['node']!='Body' for c in channels),'endpoint_match':all(c['endpoint_error']<1e-5 for c in channels),'actual_transform_motion':any(c['motion_max']>1e-4 for c in channels)})
parents={child:i for i,n in enumerate(nodes) for child in n.get('children',[])}
report={'animations':clips,'images':len(doc.get('images',[])),'images_embedded':all('bufferView' in i and 'uri' not in i for i in doc.get('images',[])),'meshes_have_uvs':all('TEXCOORD_0' in p['attributes'] for m in doc['meshes'] for p in m['primitives']),'armatures_present':bool(doc.get('skins')),'muzzle_bare':all('mesh' not in n and not n.get('children') for n in nodes if n.get('name')=='Muzzle'),'body_root':all(i not in parents for i,n in enumerate(nodes) if n.get('name')=='Body'),'glb_bytes':len(raw)}
(out/'animation_audit.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
