"""GLB round-trip motion inspection. Generated proof, no game modifications."""
import bpy, math, json, struct
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).parent
bpy.ops.wm.read_factory_settings(use_empty=True)
sc=bpy.context.scene;sc.render.fps=30
bpy.ops.import_scene.gltf(filepath=str(OUT/'cp_frostforge_yeti.glb'))
sc.render.engine='BLENDER_EEVEE';sc.render.resolution_x=512;sc.render.resolution_y=512;sc.render.resolution_percentage=100
sc.render.image_settings.file_format='PNG'
w=bpy.data.worlds.new('Studio');w.use_nodes=True;w.node_tree.nodes['Background'].inputs[0].default_value=(.065,.105,.15,1);w.node_tree.nodes['Background'].inputs[1].default_value=.6;sc.world=w
for name,pos,power,size in [('Key',(-3,4,6),650,4),('Fill',(4,1,3),400,3),('Rim',(1,-3,5),750,3)]:
    o=bpy.data.objects.new(name,bpy.data.lights.new(name,'AREA'));sc.collection.objects.link(o);o.location=pos;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,1.1))-o.location).to_track_quat('-Z','Y').to_euler()
cam=bpy.data.objects.new('Camera',bpy.data.cameras.new('Camera'));sc.collection.objects.link(cam);sc.camera=cam
cam.location=(-3.4,5.8,3.2);cam.rotation_euler=(Vector((0,0,1.25))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=3.2
proof={}
for clip,frames in [('Idle',[0,15,30]),('Walk',[0,9,18]),('Swim',[0,15,30]),('Attack',[0,18,23])]:
    for o in bpy.data.objects:
        if o.animation_data:
            o.animation_data.action=None
            for tr in o.animation_data.nla_tracks:tr.mute=tr.name!=clip
    for frame in frames:
        sc.frame_set(frame);bpy.context.view_layer.update()
        sc.render.filepath=str(OUT/f'motion_{clip}_{frame:02}.png');bpy.ops.render.render(write_still=True)
        proof[clip+'_'+str(frame)]={o.name:[list(o.matrix_world.translation),list(o.rotation_euler)] for o in bpy.data.objects if o.name in ['Body','Arm_L','Arm_R','Leg_L','Leg_R']}
(OUT/'motion_inspection.json').write_text(json.dumps(proof,indent=2))
print('MOTION PROOF SAVED')
