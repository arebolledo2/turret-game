import json,struct,math
from pathlib import Path
p=Path(__file__).parent
raw=(p/'eco_marionettist.glb').read_bytes()
jn=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+jn]);data=raw[28+jn:]
def values(i):
    a=doc['accessors'][i];v=doc['bufferViews'][a['bufferView']];n={'SCALAR':1,'VEC3':3,'VEC4':4}[a['type']]
    offset=v.get('byteOffset',0)+a.get('byteOffset',0);fmt={5126:'f',5123:'H',5125:'I'}[a['componentType']]
    stride=v.get('byteStride',struct.calcsize('<'+fmt)*n)
    return [struct.unpack_from('<'+fmt*n,data,offset+j*stride) for j in range(a['count'])]
clips=[]
for a in doc.get('animations',[]):
    channels=[];duration=0;loop_error=0;root_targets=[]
    for c in a['channels']:
        s=a['samplers'][c['sampler']];times=values(s['input']);vals=values(s['output']);duration=max(duration,times[-1][0]);name=doc['nodes'][c['target']['node']].get('name','');path=c['target']['path']
        err=max(abs(x-y) for x,y in zip(vals[0],vals[-1]));loop_error=max(loop_error,min(err,max(abs(x+y) for x,y in zip(vals[0],vals[-1]))) if path=='rotation' else err)
        change=max(max(abs(x-y) for x,y in zip(vals[0],v)) for v in vals)
        channels.append({'node':name,'path':path,'samples':len(vals),'max_component_change':round(change,6),'endpoint_error':round(err,8)})
        if name=='Body' or path=='translation':root_targets.append(name+':'+path)
    clips.append({'name':a['name'],'duration_s':round(duration,3),'channels':channels,'stationary_root':not root_targets,'root_or_translation_channels':root_targets,'endpoint_max_error':loop_error,'intended_loop':a['name'] in ['Idle','Walk','Swim']})
audit={'glb_bytes':len(raw),'images':[{'name':x.get('name'),'embedded': 'bufferView' in x,'mime':x.get('mimeType')} for x in doc.get('images',[])],'skins':len(doc.get('skins',[])),'mesh_nodes':len([n for n in doc['nodes'] if 'mesh' in n]),'materials':len(doc.get('materials',[])),'clip_audits':clips,'external_uris':[x['uri'] for kind in ['images','buffers'] for x in doc.get(kind,[]) if 'uri' in x]}
(p/'glb_audit.json').write_text(json.dumps(audit,indent=2))
print(json.dumps({**{k:v for k,v in audit.items() if k!='clip_audits'},'clips':[{k:v for k,v in c.items() if k!='channels'} | {'channels':len(c['channels'])} for c in clips]},indent=2))
assert all(c['stationary_root'] and c['endpoint_max_error']<.00001 for c in clips)
assert not audit['external_uris'] and audit['skins']==0
