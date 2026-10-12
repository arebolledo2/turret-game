import json,struct
from pathlib import Path
root=Path(__file__).parent
data=(root/'cp_frostforge_yeti.glb').read_bytes()
n=struct.unpack_from('<I',data,12)[0]
doc=json.loads(data[20:20+n]);binstart=20+n+8
def acc(i):
    a=doc['accessors'][i];v=doc['bufferViews'][a['bufferView']]
    width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
    assert a['componentType']==5126
    stride=v.get('byteStride',width*4);start=binstart+v.get('byteOffset',0)+a.get('byteOffset',0)
    return [struct.unpack_from('<'+'f'*width,data,start+j*stride) for j in range(a['count'])]
clips=[]
for anim in doc.get('animations',[]):
    times=[t[0] for sm in anim['samplers'] for t in acc(sm['input'])]
    deltas=[]
    for sm in anim['samplers']:
        values=acc(sm['output']);deltas.append(max(abs(a-b) for a,b in zip(values[0],values[-1])))
    clips.append({'name':anim['name'],'duration_seconds':round(max(times)-min(times),5),'transform_channels':len(anim['channels']),'first_last_max_delta':max(deltas)})
audit={'glb_bytes':len(data),'mesh_count':len(doc.get('meshes',[])),'material_count':len(doc.get('materials',[])),'images':len(doc.get('images',[])),'all_images_embedded':all('bufferView' in i for i in doc.get('images',[])),'animations':clips}
(root/'asset_audit.json').write_text(json.dumps(audit,indent=2))
print(json.dumps(audit,indent=2))
