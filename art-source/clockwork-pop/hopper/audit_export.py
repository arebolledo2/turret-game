import json,struct
from pathlib import Path
p=Path(__file__).parent
raw=(p/'eco_hopper.glb').read_bytes();size=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+size]);start=20+size;blen,btype=struct.unpack_from('<II',raw,start);binary=raw[start+8:start+8+blen]
def values(i):
 a=doc['accessors'][i];v=doc['bufferViews'][a['bufferView']];offset=v.get('byteOffset',0)+a.get('byteOffset',0);c={'SCALAR':1,'VEC3':3,'VEC4':4}[a['type']];return struct.unpack_from('<'+str(a['count']*c)+'f',binary,offset),c
clips=[]
for a in doc['animations']:
 duration=0;seam=0;targets=[]
 for ch in a['channels']:
  sampler=a['samplers'][ch['sampler']];times,c=values(sampler['input']);duration=max(duration,max(times));vs,c=values(sampler['output']);seam=max(seam,max(abs(vs[i]-vs[-c+i]) for i in range(c)));node=doc['nodes'][ch['target']['node']]['name'];targets.append([node,ch['target']['path']])
 clips.append({'name':a['name'],'duration_seconds':duration,'channels':len(a['channels']),'max_endpoint_difference':seam,'root_animated':any(n=='EcoHopper' for n,p in targets),'targets':targets})
res={'clips':clips,'images':len(doc.get('images',[])),'all_images_embedded':all('bufferView' in i and 'uri' not in i for i in doc.get('images',[])),'file_size_bytes':len(raw)}
(p/'animation_audit.json').write_text(json.dumps(res,indent=2));print(json.dumps({**res,'clips':[{k:v for k,v in c.items() if k!='targets'} for c in clips]},indent=2))
