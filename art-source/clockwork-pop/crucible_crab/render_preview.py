"""Standalone source animation preview; never modifies game or harness files."""
import bpy,math
from pathlib import Path
from mathutils import Vector
root=Path(__file__).parent
bpy.ops.wm.open_mainfile(filepath=str(root/'cp_crucible_crab.blend'))
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=scene.render.resolution_y=512;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
world=bpy.data.worlds.new('Preview world');world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.09,.12,.15,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.7;scene.world=world
for name,loc,power,size in [('Softbox',(-3,4,6),600,5),('Warm edge',(3,-2,4),500,4),('Face fill',(2,5,3),200,3)]:
    lamp=bpy.data.objects.new(name,bpy.data.lights.new(name,'AREA'));scene.collection.objects.link(lamp)
    lamp.location=loc;lamp.data.energy=power;lamp.data.shape='DISK';lamp.data.size=size
    lamp.rotation_euler=(Vector((0,0,1))-lamp.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,0))
floor=bpy.context.object;mat=bpy.data.materials.new('Slate ground');mat.diffuse_color=(.035,.06,.083,1);floor.data.materials.append(mat)
cam=bpy.data.objects.new('Preview camera',bpy.data.cameras.new('Preview camera'));scene.collection.objects.link(cam)
cam.location=(-3.7,5.2,3.4);cam.rotation_euler=(Vector((0,0,1.02))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='ORTHO';cam.data.ortho_scale=4.35;scene.camera=cam
out=root/'preview_frames';out.mkdir(exist_ok=True)
for clip,end,frames in [('Attack',43,20),('Walk',49,20)]:
    for o in scene.objects:
        if o.animation_data:
            for track in o.animation_data.nla_tracks:track.mute=track.name!=clip
    for i in range(frames):
        scene.frame_set(1+round(i/(frames-1)*(end-1)))
        scene.render.filepath=str(out/f'{clip}_{i:02d}.png');bpy.ops.render.render(write_still=True)
print('PREVIEWS COMPLETE')
