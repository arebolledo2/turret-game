"""Read-only GLB audit; save machine-readable rest transforms and texture checks."""
import json,struct,hashlib,math
from pathlib import Path
OUT=Path(__file__).resolve().parent
raw=(OUT/'cp_charger.glb').read_bytes()
magic,version,length=struct.unpack_from('<4sII',raw)
assert magic==b'glTF' and version==2 and length==len(raw)
chunks={};offset=12
while offset<len(raw):
    size,kind=struct.unpack_from('<II',raw,offset);offset+=8;chunks[kind]=raw[offset:offset+size];offset+=size
g=json.loads(chunks[0x4E4F534A]);binary=chunks[0x004E4942]
nodes=g['nodes'];byname={n['name']:i for i,n in enumerate(nodes)}
parents={c:i for i,n in enumerate(nodes) for c in n.get('children',[])}
root=byname['Ramjet_Beetle'];assert root not in parents
required=['Body','Leg_L_0','Leg_L_1','Leg_R_0','Leg_R_1']
expected={'Body':[0,.46,.05],'Leg_L_0':[-.221,.334,-.165],'Leg_L_1':[-.221,.334,.182],'Leg_R_0':[.221,.334,-.165],'Leg_R_1':[.221,.334,.182]}
metadata={}
for name in required:
    i=byname[name];n=nodes[i];assert parents[i]==root and 'mesh' not in n
    assert n.get('rotation',[0,0,0,1])==[0,0,0,1] and n.get('scale',[1,1,1])==[1,1,1] and 'matrix' not in n
    t=n.get('translation',[0,0,0]);assert all(abs(a-b)<1e-6 for a,b in zip(t,expected[name]))
    children=n.get('children',[]);assert len(children)==1 and 'mesh' in nodes[children[0]]
    metadata[name]={'parent':'Ramjet_Beetle','blender_world_position':[t[0],-t[2],t[1]],'gltf_local_translation':t,'rotation_xyzw':[0,0,0,1],'scale':[1,1,1],'mesh_child':nodes[children[0]]['name']}
assert not g.get('animations') and not g.get('skins') and not g.get('cameras')
assert len(g['meshes'])==5 and len(g['materials'])==8 and len(g['images'])==4
assert all('bufferView' in im and 'uri' not in im for im in g['images'])
assert all('uri' not in b for b in g['buffers'])
triangles=0;uv_ranges=[]
def accessor(ai):
    a=g['accessors'][ai];bv=g['bufferViews'][a['bufferView']];nc={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
    fmt,bs={5121:('B',1),5123:('H',2),5125:('I',4),5126:('f',4)}[a['componentType']]
    start=bv.get('byteOffset',0)+a.get('byteOffset',0);stride=bv.get('byteStride',nc*bs)
    return [struct.unpack_from('<'+fmt*nc,binary,start+i*stride) for i in range(a['count'])]
for mesh in g['meshes']:
    for primitive in mesh['primitives']:
        assert primitive.get('mode',4)==4 and 'TEXCOORD_0' in primitive['attributes'] and 'NORMAL' in primitive['attributes']
        triangles+=g['accessors'][primitive['indices']]['count']//3
        uv=accessor(primitive['attributes']['TEXCOORD_0']);assert all(math.isfinite(a) and 0<=a<=1 for pair in uv for a in pair)
        mi=primitive['material'];tile=['Teal enamel armor','Deep teal recess','Warm brushed brass','Midnight mechanism','Coral carapace','Slate toe armor','Purple dorsal ridge','Mint optical visor'].index(g['materials'][mi]['name']);u0=(tile%2)*.5;v0=1-(tile//2+1)*.25
        assert all(u0-1e-5<=u<=u0+.5+1e-5 and v0-1e-5<=v<=v0+.25+1e-5 for u,v in uv),(mesh['name'],mi)
        uv_ranges.append({'mesh':mesh['name'],'material':g['materials'][mi]['name'],'u':[min(u for u,v in uv),max(u for u,v in uv)],'v':[min(v for u,v in uv),max(v for u,v in uv)]})
result={'passed':True,'triangles':triangles,'mesh_objects':len(g['meshes']),'material_count':len(g['materials']),'embedded_image_count':len(g['images']),'animation_clips':0,'skins':0,'glb_bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'pivots':metadata,'uv_ranges':uv_ranges,'runtime_axes':{'forward':'Blender +Y = Godot -Z','lift_L':'Blender +Y rotation = Godot -Z rotation','lift_R':'Blender -Y rotation = Godot +Z rotation','fore_aft_sweep':'Blender Z rotation = Godot Y rotation','index_0':'fore (+Blender Y)','index_1':'aft (-Blender Y)','L':'negative Blender X','R':'positive Blender X'}}
(OUT/'export_verified.json').write_text(json.dumps(result,indent=2))
print(json.dumps({k:v for k,v in result.items() if k not in ['uv_ranges']},indent=2))
