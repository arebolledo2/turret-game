import bpy,json
from pathlib import Path
out=Path(__file__).resolve().parent
assert len(bpy.data.images)==4
images=[]
for im in bpy.data.images:
    assert im.packed_file and list(im.size)==[1024,1024]
    images.append({'name':im.name,'size':list(im.size),'colorspace':im.colorspace_settings.name,'packed_bytes':im.packed_file.size})
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert len(meshes)==5
for o in meshes:
    assert len(o.data.uv_layers)==1 and o.data.uv_layers.active
assert not bpy.data.actions
result={'passed':True,'images':images,'mesh_uv_layer_count':{o.name:len(o.data.uv_layers) for o in meshes},'actions':0}
(out/'packed_verified.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
