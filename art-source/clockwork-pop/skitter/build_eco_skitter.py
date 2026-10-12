import bpy, math, numpy as np
from mathutils import Vector
from pathlib import Path

OUT = Path(__file__).parent
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
scene.render.fps=30

# Four authored surface atlases: quiet enamel waviness, satin metal and a warm lens.
N=1024
yy,xx=np.mgrid[0:N,0:N].astype(np.float32)
u=(xx%256)/255; v=(yy%512)/511
palette=[(.57,.72,.24),(.39,.085,.27),(.78,.43,.16),(.095,.11,.16),(.99,.86,.52),(.07,.27,.26),(.19,.16,.23),(.72,.84,.36)]
tile=(xx//256+(yy//512)*4).astype(int)
wave=np.sin(u*8+v*5)*.018+np.sin(u*53-v*31)*.003
sheen=.04*np.exp(-((u-.26)**2+(v-.74)**2)/.1)
base=np.array(palette,dtype=np.float32)[tile]*(1+wave[:,:,None])+sheen[:,:,None]
base=np.clip(base,0,1)
rough=np.choose(tile,[.27,.31,.26,.43,.2,.25,.48,.29])+np.sin(u*12+v*9)*.022
def img(name,rgb,space='sRGB'):
    im=bpy.data.images.new(name,width=N,height=N,alpha=True)
    im.colorspace_settings.name=space
    data=np.ones((N,N,4),dtype=np.float32);data[:,:,:3]=rgb
    im.pixels.foreach_set(data.ravel());im.filepath_raw=str(OUT/(name+'.png'));im.file_format='PNG';im.save();im.pack()
    return im
color=img('skitter_enamel_color',base)
rough_im=img('skitter_surface_roughness',np.repeat(rough[:,:,None],3,2),'Non-Color')
normal=np.zeros((N,N,3),dtype=np.float32);normal[:,:,0]=.5+.007*np.cos(u*53-v*31);normal[:,:,1]=.5+.007*np.sin(u*31+v*23);normal[:,:,2]=1
normal_im=img('skitter_enamel_normal',normal,'Non-Color')
em=np.zeros((N,N,3),dtype=np.float32);em[tile==4]=(.99,.77,.31)
emission=img('skitter_lens_emission',em)
materials=[]
for i,name in enumerate(['Pistachio enamel','Plum enamel','Warm brass','Graphite struts','Cream lens','Teal iris','Plum rubber','Pale green trim']):
    m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF')
    t=n.new('ShaderNodeTexImage');t.image=color;l.new(t.outputs['Color'],p.inputs['Base Color'])
    r=n.new('ShaderNodeTexImage');r.image=rough_im;l.new(r.outputs['Color'],p.inputs['Roughness'])
    t=n.new('ShaderNodeTexImage');t.image=normal_im;nm=n.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.22;l.new(t.outputs['Color'],nm.inputs['Color']);l.new(nm.outputs['Normal'],p.inputs['Normal'])
    p.inputs['Metallic'].default_value=.76 if i==2 else (.22 if i==3 else .05)
    p.inputs['Coat Weight'].default_value=.38 if i in [0,1,4,7] else .08
    p.inputs['Coat Roughness'].default_value=.2
    if i==4:
        t=n.new('ShaderNodeTexImage');t.image=emission;l.new(t.outputs['Color'],p.inputs['Emission Color']);p.inputs['Emission Strength'].default_value=.17
    materials.append(m)

def finish(o,mat):
    o.data.materials.append(materials[mat])
    bpy.context.view_layer.objects.active=o;o.select_set(True)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for p in o.data.polygons:p.use_smooth=True
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.025);bpy.ops.object.mode_set(mode='OBJECT')
    for loop in o.data.uv_layers.active.data:
        loop.uv.x=(mat%4+.055+loop.uv.x*.89)/4
        loop.uv.y=(mat//4+.045+loop.uv.y*.91)/2
    o.select_set(False)
    return o
def sphere(name,loc,scale,mat,seg=20,rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,location=loc);o=bpy.context.object;o.name=name;o.scale=scale;return finish(o,mat)
def rod(name,a,b,r1,r2,mat,vertices=12):
    d=Vector(b)-Vector(a);bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r1,radius2=r2,depth=d.length,location=(Vector(a)+Vector(b))/2)
    o=bpy.context.object;o.name=name;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();return finish(o,mat)
def ring(name,loc,major,minor,mat,rot=(math.pi/2,0,0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=32,minor_segments=8,location=loc,major_radius=major,minor_radius=minor,rotation=rot)
    o=bpy.context.object;o.name=name;return finish(o,mat)
def empty(name,loc,parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=loc
    if parent:o.parent=parent;o.location=Vector(loc)-parent.location
    return o
def parent(o,p):
    w=o.matrix_world.copy();o.parent=p;o.matrix_world=w
def join(name,parts,p=None):
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=parts[0];o.name=name
    if p:parent(o,p)
    o.select_set(False);return o

body=empty('Body',(0,0,.32))
parts=[sphere('Plum lower carapace',(0,-.035,.31),(.325,.39,.225),1,28,16)]
# Individual elliptical wing covers separated by a plum dorsal seam.
for side in [-1,1]:
    verts=[];faces=[];rows=16;cols=14
    for j in range(rows+1):
        a=math.pi*j/rows
        for k in range(cols+1):
            t=.025+(math.pi/2-.025)*k/cols
            verts.append((side*(.014+.322*math.sin(a)*math.sin(t)),-.035+.375*math.cos(a),.355+.242*math.sin(a)*math.cos(t)))
    for j in range(rows):
        for k in range(cols):
            a=j*(cols+1)+k;f=(a,a+1,a+cols+2,a+cols+1)
            faces.append(f if side==1 else tuple(reversed(f)))
    me=bpy.data.meshes.new('Elytron');me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new('Pistachio wing cover',me);bpy.context.collection.objects.link(o)
    sol=o.modifiers.new('Enamel thickness','SOLIDIFY');sol.thickness=.012;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=sol.name);finish(o,0);parts.append(o)
    # Small shoulder relief and intentional brass rivets.
    parts.append(sphere('Plum shoulder',(.235*side,.215,.39),(.065,.12,.1),1,16,10))
    for y in [-.22,.05,.25]:parts.append(sphere('Brass shell rivet',(side*(.27 if y<.15 else .22),y,.48 if y<.15 else .45),(.012,.012,.012),2,10,6))
parts.append(rod('Brass dorsal seam',(0,-.29,.515),(0,.22,.55),.007,.007,2))
join('Carapace',parts,body)

# A cream cyclopean eye faces +Y, with a dark socket, plum bezel and warm rim.
eye=empty('Eye',(0,.315,.365),body)
parts=[sphere('Face pad',(0,.315,.365),(.205,.105,.165),7,24,14),sphere('Plum socket',(0,.405,.365),(.137,.045,.137),1,24,14),ring('Warm lens rim',(0,.439,.365),.112,.012,2),sphere('Cream eye',(0,.444,.365),(.107,.034,.107),4,24,14)]
join('Cyclops eye',parts,eye)

for side in [-1,1]:
    pivot=empty('Antenna_L' if side<0 else 'Antenna_R',(side*.12,.22,.49),body)
    a=(side*.12,.22,.49);b=(side*.165,.265,.635);c=(side*.205,.34,.705)
    parts=[sphere('Antenna collar',a,(.033,.035,.032),1,12,8),rod('Brass antenna stem',a,b,.009,.007,2),rod('Brass antenna tip',b,c,.007,.008,2),sphere('Mint antenna bead',c,(.024,.022,.025),7,16,10)]
    join('Antenna mesh',parts,pivot)

legs=[]
for side in [-1,1]:
    for index,y in enumerate([.225,-.015,-.245]):
        hip=(side*.265,y,.295);knee=(side*.435,y+(.055 if index==0 else -.045 if index==2 else 0),.19);foot=(side*.485,y+(.095 if index==0 else -.08 if index==2 else 0),.033)
        pivot=empty(f"Leg_{'L' if side<0 else 'R'}_{index}",hip);legs.append((pivot,side,index))
        parts=[sphere('Hip swivel',hip,(.046,.045,.046),2,12,8),rod('Upper leg strut',hip,knee,.038,.028,3),rod('Plum leg shield',Vector(hip).lerp(Vector(knee),.22),Vector(hip).lerp(Vector(knee),.85),.04,.03,1),sphere('Knee hinge',knee,(.033,.038,.033),2,12,8),rod('Lower leg',knee,foot,.022,.013,3),sphere('Rubber foot',foot,(.048,.062,.032),6,14,8)]
        join('Leg mesh '+str(side)+' '+str(index),parts,pivot)

# A stationary root keeps all motion local to articulated parts.
root=empty('SkitterRoot',(0,0,0))
for obj in list(bpy.context.scene.objects):
    if obj != root and obj.parent is None:parent(obj,root)

# Rigid transform clips, with stationary origin and an explicit final resting frame.
animated=[body,eye]+[x[0] for x in legs]+[bpy.data.objects['Antenna_L'],bpy.data.objects['Antenna_R']]
rest={o.name:(o.location.copy(),o.rotation_euler.copy()) for o in animated}
def animate(clip,seconds):
    frames=round(seconds*30)
    for o in animated:
        if o.animation_data:o.animation_data.action=None
    for frame in range(0,frames+1,3):
        t=frame/frames;ph=2*math.pi*t
        for o in animated:o.location=rest[o.name][0];o.rotation_euler=rest[o.name][1]
        if clip=='Idle':
            body.location.z+=.008*math.sin(ph);body.rotation_euler.x=.015*math.sin(ph)
        elif clip=='Walk':
            body.location.z+=.009*(1-math.cos(ph*2));body.rotation_euler.y=.025*math.sin(ph)
        elif clip=='Swim':
            body.rotation_euler.x=.055*math.sin(ph);body.location.z+=.025*math.sin(ph)
        else:
            pulse=math.sin(math.pi*t)**2;body.rotation_euler.x=-.24*pulse;body.location.y+=.035*pulse;eye.scale=(1+.045*pulse,1+.08*pulse,1+.045*pulse)
        for o,side,index in legs:
            offset=(index%2)*math.pi+(math.pi if side<0 else 0)
            if clip=='Walk':o.rotation_euler.z=.21*math.sin(ph+offset);o.rotation_euler.y=side*.17*max(0,math.sin(ph+offset))
            elif clip=='Swim':o.rotation_euler.z=.29*math.sin(ph+offset);o.rotation_euler.y=side*(.2+.18*math.sin(ph+offset))
            elif clip=='Attack':o.rotation_euler.z=side*(.18 if index==0 else -.09)*math.sin(math.pi*t)**2;o.rotation_euler.y=-side*.14*math.sin(math.pi*t)**2
            else:o.rotation_euler.z=.018*math.sin(ph+offset)
        for side in [-1,1]:
            a=bpy.data.objects['Antenna_L' if side<0 else 'Antenna_R'];a.rotation_euler.y=side*.06*math.sin(ph);a.rotation_euler.x=.045*(math.sin(ph+.4)-math.sin(.4))
        for o in animated:
            o.keyframe_insert('location',frame=frame);o.keyframe_insert('rotation_euler',frame=frame)
        if clip=='Attack':eye.keyframe_insert('scale',frame=frame)
    for o in animated:
        act=o.animation_data.action;act.name=clip+'_'+o.name
        for fcurve in act.fcurves if hasattr(act,'fcurves') else []:
            for point in fcurve.keyframe_points:point.interpolation='LINEAR'
        track=o.animation_data.nla_tracks.new();track.name=clip;strip=track.strips.new(clip,0,act);strip.name=clip
        o.animation_data.action=None
for clip,secs in [('Idle',2),('Walk',1),('Swim',1.6),('Attack',.8)]:animate(clip,secs)
for o in animated:o.location=rest[o.name][0];o.rotation_euler=rest[o.name][1]
eye.scale=(1,1,1)
scene.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'eco_skitter.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'eco_skitter.glb'),export_format='GLB',export_yup=True,export_animations=True,export_cameras=False,export_lights=False,export_animation_mode='NLA_TRACKS')
print('Built Rivet Skitter')
