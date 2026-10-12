import bpy,math
from mathutils import Vector
from pathlib import Path
OUT=Path(__file__).parent
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUT/'eco_marionettist.glb'))
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=scene.render.resolution_y=512;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Preview dark studio');scene.world.color=(.04,.06,.085)
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.035,.06,.085,1)
for name,pos,energy,size in [('Key',(3,4,5),650,5),('Fill',(-3,2,3),400,4),('Rim',(0,-3,4),550,3)]:
    o=bpy.data.objects.new(name,bpy.data.lights.new(name,'AREA'));bpy.context.collection.objects.link(o);o.location=pos;o.data.energy=energy;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,.9))-o.location).to_track_quat('-Z','Y').to_euler()
cam=bpy.data.objects.new('Preview Camera',bpy.data.cameras.new('Preview Camera'));bpy.context.collection.objects.link(cam);cam.location=(-2.5,4,2.6);cam.rotation_euler=(Vector((0,0,.9))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.15;scene.camera=cam
OUT.joinpath('motion').mkdir(exist_ok=True)
rest={o.name:o.rotation_quaternion.copy() for o in scene.objects}
for o in scene.objects:
    if o.animation_data:
        print('IMPORTED NLA',o.name,[(tr.name,[st.action.name for st in tr.strips]) for tr in o.animation_data.nla_tracks]);o.animation_data.action=None
for clip,frame in [('Idle',24),('Walk',9),('Swim',36),('Attack',21)]:
    for o in scene.objects:
        o.rotation_quaternion=rest[o.name]
        if o.animation_data:
            for tr in o.animation_data.nla_tracks:tr.mute=not tr.name.startswith(clip)
    scene.frame_set(frame);scene.render.filepath=str(OUT/'motion'/f'{clip}.png');bpy.ops.render.render(write_still=True)
for clip,end in [('Idle',96),('Walk',36),('Swim',72),('Attack',42)]:
    for o in scene.objects:
        o.rotation_quaternion=rest[o.name]
        if o.animation_data:
            for tr in o.animation_data.nla_tracks:tr.mute=not tr.name.startswith(clip)
    for i in range(16):
        scene.frame_set(round(i*end/15));scene.render.filepath=str(OUT/'motion'/f'{clip}_{i:02d}.png');bpy.ops.render.render(write_still=True)
print('MOTION RENDER COMPLETE')
