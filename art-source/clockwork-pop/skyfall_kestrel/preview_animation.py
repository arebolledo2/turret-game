"""Small deterministic preview of the packed source's Idle and Attack NLA clips."""
import bpy, math
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).parent
bpy.ops.wm.open_mainfile(filepath=str(HERE/'cp_skyfall_kestrel.blend'))
scene=bpy.context.scene; scene.render.engine='BLENDER_EEVEE'; scene.render.resolution_x=480; scene.render.resolution_y=480; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.world=bpy.data.worlds.new('Preview world'); scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.065,.085,.11,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.8
for name,pos,energy,size in [('Softbox key',(-3,2,5),500,4),('Softbox fill',(3,1,2),350,3),('Softbox rim',(0,-3,4),700,3)]:
    data=bpy.data.lights.new(name,'AREA'); data.energy=energy; data.shape='DISK'; data.size=size
    o=bpy.data.objects.new(name,data); scene.collection.objects.link(o); o.location=pos; o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
camera=bpy.data.objects.new('Preview camera',bpy.data.cameras.new('Preview camera')); scene.collection.objects.link(camera)
camera.data.type='ORTHO'; camera.data.ortho_scale=4.35; camera.location=(-4.5,5.7,4.0); camera.rotation_euler=(Vector((0,-.02,1.02))-camera.location).to_track_quat('-Z','Y').to_euler(); scene.camera=camera
OUT=HERE/'animation_frames'; OUT.mkdir(exist_ok=True)
for clip,frames in [('Idle',range(0,60,5)),('Attack',range(0,31,3))]:
    for o in scene.objects:
        if o.animation_data:
            for track in o.animation_data.nla_tracks: track.mute=track.name!=clip
    for idx,f in enumerate(frames):
        scene.frame_set(f); scene.render.filepath=str(OUT/f'{clip.lower()}_{idx:02d}.png'); bpy.ops.render.render(write_still=True)
print('PREVIEW_DONE')
