"""Crownwheel: single rolling emerald wheel, open gear hub and stable optical crown."""
import bpy, bmesh, math, json
import numpy as np
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).parent
bpy.ops.wm.read_factory_settings(use_empty=True)
TAU = math.tau
CZ = .905
scene = bpy.context.scene
scene.render.fps = 30

def texture(name, color, kind):
    n=1024
    y,x=np.mgrid[0:n,0:n].astype(np.float32)/n
    rng=np.random.default_rng(274)
    noise=rng.normal(0,.002,(n,n)).astype(np.float32)
    if kind=='enamel':
        shade=1+.018*np.sin(x*TAU*7)+.009*np.sin(y*TAU*43)+noise
    elif kind=='gold':
        shade=1+.023*np.sin(y*TAU*170)+.016*np.sin(x*TAU*3)+noise
    elif kind=='ivory':
        shade=1+.014*np.sin(y*TAU*11)+noise
    else:
        radius=np.sqrt((x-.5)**2+(y-.5)**2)
        shade=.78+.25*np.exp(-radius*radius*10)+.06*np.sin(radius*70)
    px=np.ones((n,n,4),dtype=np.float32)
    px[:,:,:3]=np.clip(np.array(color)[None,None,:]*shade[:,:,None],0,1)
    if kind=='enamel':
        px[:,n//3:2*n//3,:3]*=np.array((.43,.63,.58))
        px[:,2*n//3:,:3]*=np.array((.09,.11,.14))
    if kind=='gold':
        px[:,n//3:2*n//3,:3]*=np.array((.65,.59,.52))
        px[:,2*n//3:,:3]*=np.array((.72,.43,.29))
    im=bpy.data.images.new(name,n,n,alpha=True)
    im.colorspace_settings.name='sRGB'
    im.pixels.foreach_set(px.ravel())
    im.filepath_raw=str(OUT/(name+'.png')); im.file_format='PNG';im.save(); im.pack()
    return im

green_img=texture('Emerald_enamel',(0.08,.59,.39),'enamel')
gold_img=texture('Satin_brass',(.95,.78,.42),'gold')
ivory_img=texture('Warm_ivory',(.88,.76,.54),'ivory')
amber_img=texture('Amber_optic',(1,.48,.045),'amber')

def mat(name,img,tint=(1,1,1),metal=.0,rough=.4,emit=0):
    m=bpy.data.materials.new(name);m.use_nodes=True
    ns=m.node_tree.nodes;bs=ns.get('Principled BSDF')
    tex=ns.new('ShaderNodeTexImage');tex.image=img
    col=tex.outputs['Color']
    if img in (green_img,gold_img):
        m['atlas_band']=0 if tint==(1,1,1) else (2 if tint in ((.09,.11,.14),(.72,.43,.29)) else 1)
    m.node_tree.links.new(col,bs.inputs['Base Color'])
    bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=rough
    if emit:
        m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Emission Color']);bs.inputs['Emission Strength'].default_value=emit
    m.diffuse_color=(*tint,1)
    return m

enamel=mat('Emerald ceramic armor',green_img,metal=.17,rough=.29)
deepgreen=mat('Deep jade tire',green_img,(.43,.63,.58),metal=.1,rough=.43)
brass=mat('Satin golden brass',gold_img,metal=.47,rough=.34)
bronze=mat('Inset bronze gear',gold_img,(.65,.59,.52),metal=.66,rough=.38)
dark=mat('Recessed graphite mechanism',green_img,(.09,.11,.14),metal=.52,rough=.42)
ivory=mat('Ivory inner rim',ivory_img,metal=.18,rough=.32)
copper=mat('Burnished copper bearings',gold_img,(.72,.43,.29),metal=.66,rough=.29)
amber=mat('Amber glass optic',amber_img,metal=.15,rough=.14,emit=.24)

def empty(name,pos,parent=None):
    o=bpy.data.objects.new(name,None);scene.collection.objects.link(o);o.location=pos
    if parent:o.parent=parent
    return o
root=empty('Crownwheel',(0,0,0))
body=empty('Body',(0,0,CZ),root)
wheel=empty('Wheel',(0,0,CZ),root)
optic=empty('Optic',(0,.35,1.91-CZ),body)

def uv(o):
    bpy.context.view_layer.objects.active=o;bpy.ops.object.select_all(action='DESELECT');o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.016)
    bpy.ops.object.mode_set(mode='OBJECT')

def finish(o,name,m,parent):
    o.name=name;o.data.materials.append(m)
    uv(o)
    if 'atlas_band' in m:
        for loop in o.data.uv_layers.active.data:
            loop.uv.x=(m['atlas_band']+.024+.952*loop.uv.x)/3
    for p in o.data.polygons:p.use_smooth=True
    # All coordinates are authored in model/world coordinates.
    world=o.matrix_world.copy();o.parent=parent;o.matrix_world=world
    return o

def bevel(o,width=.02,segments=2):
    bpy.context.view_layer.objects.active=o
    mod=o.modifiers.new('Rounded machined edges','BEVEL');mod.width=width;mod.segments=segments
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=o.modifiers.new('Weighted face normals','WEIGHTED_NORMAL');mod.keep_sharp=True;mod.weight=40
    bpy.ops.object.modifier_apply(modifier=mod.name)

def mesh(name,verts,faces,m,parent,bev=0):
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
    o=bpy.data.objects.new(name,data);scene.collection.objects.link(o)
    # Authored rings follow the same outward winding; recalculate to remove any seam ambiguity.
    bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(data);bm.free()
    if bev:bevel(o,bev,2)
    return finish(o,name,m,parent)

def lathe(name,profile,m,parent,n=80):
    vs=[];fs=[]
    for x,r in profile:
        vs.extend((x,r*math.sin(TAU*i/n),CZ+r*math.cos(TAU*i/n)) for i in range(n))
    for j in range(len(profile)):
        j2=(j+1)%len(profile)
        for i in range(n):
            i2=(i+1)%n
            fs.append((j*n+i,j*n+i2,j2*n+i2,j2*n+i))
    return mesh(name,vs,fs,m,parent)

def cyl(name,pos,r,depth,m,parent,axis='X',n=48):
    bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=depth,location=pos)
    o=bpy.context.object
    if axis=='X':o.rotation_euler[1]=math.pi/2
    if axis=='Y':o.rotation_euler[0]=math.pi/2
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bevel(o,min(.016,r*.18,depth*.24))
    return finish(o,name,m,parent)

def box(name,pos,size,m,parent,rot=0,bev=.022):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.rotation_euler[0]=rot
    bevel(o,min(bev,min(size)*.4))
    return finish(o,name,m,parent)

def join(parts,name,parent):
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join()
    o=bpy.context.object;o.name=name
    world=o.matrix_world.copy();o.parent=parent;o.matrix_world=world
    return o

# Genuine open tire: rounded rectangular annulus with continuous inner cavity.
lathe('Deep green open tire',[(-.25,.57),(-.285,.62),(-.285,.73),(-.25,.8),(-.17,.825),(.17,.825),(.25,.8),(.285,.73),(.285,.62),(.25,.57)],deepgreen,wheel)
lathe('Ivory inset sidewall rims',[(-.292,.55),(-.318,.555),(-.32,.585),(-.304,.61),(-.284,.61),(-.279,.565)],ivory,wheel)
lathe('Ivory far sidewall rim',[(.279,.565),(.284,.61),(.304,.61),(.32,.585),(.318,.555),(.292,.55)],ivory,wheel)
# Broad beveled segmented armor follows the circumference instead of boxy floating paddles.
treads=[]
for k in range(20):
    mid=TAU*k/20;ang=[mid+v for v in (-.136,-.068,0,.068,.136)]
    vs=[]
    for x,r in [(-.245,.808),(-.245,.876),(-.16,.9),(.16,.9),(.245,.876),(.245,.808)]:
        vs.extend((x,r*math.sin(a),CZ+r*math.cos(a)) for a in ang)
    fs=[];nn=len(ang)
    for j in range(6):
        jj=(j+1)%6
        for i in range(nn-1):fs.append((j*nn+i,j*nn+i+1,jj*nn+i+1,jj*nn+i))
    fs.append(tuple(j*nn for j in range(5,-1,-1)));fs.append(tuple(j*nn+nn-1 for j in range(6)))
    treads.append(mesh('Tread_%02d'%k,vs,fs,enamel,wheel,.018))
join(treads,'Twenty rounded tread armor blocks',wheel)

# An inset dark crown and sparse spokes leave the background visible through the annulus.
def gear(name,x,rad,inner,depth,teeth,m):
    vs=[];fs=[];n=teeth*4
    for xx,kind in [(x-depth/2,'outer'),(x+depth/2,'outer'),(x-depth/2,'inner'),(x+depth/2,'inner')]:
        for i in range(n):
            a=TAU*i/n;r=rad+(.038 if i%4 in (1,2) else 0) if kind=='outer' else inner
            vs.append((xx,r*math.sin(a),CZ+r*math.cos(a)))
    for i in range(n):
        j=(i+1)%n
        fs.extend([(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),(i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)])
    return mesh(name,vs,fs,m,wheel,.008)
gear('Shadow gear with open center',-.235,.46,.385,.10,24,dark)
gear('Bronze driven crown',-.335,.32,.218,.066,18,brass)
gear('Reverse driven crown',.317,.32,.218,.06,18,bronze)
spokes=[]
for side in (-1,1):
    for k in range(5):
        a=TAU*k/5+.25
        spokes.append(box('Recessed spoke',(side*.195,.395*math.sin(a),CZ+.395*math.cos(a)),(.10,.085,.36),bronze,wheel,-a,.014))
join(spokes,'Ten recessed radial spokes',wheel)
lathe('Inner cylindrical bronze barrel',[(-.235,.51),(-.235,.535),(.235,.535),(.235,.51)],bronze,wheel)
cyl('Axle sleeve',(0,0,CZ),.212,.70,copper,wheel)

# Fixed suspension arm lives under Body, separate from the wheel's rolling pivot.
cyl('Stationary left axle bezel',(-.402,0,CZ),.177,.073,brass,body)
cyl('Stationary left copper socket',(-.446,0,CZ),.127,.028,copper,body)
cyl('Fixed axle button',(-.468,0,CZ),.082,.028,bronze,body)
cyl('Stationary right axle bezel',(.40,0,CZ),.14,.09,copper,body)
start=Vector((-.37,.012,CZ+.025));end=Vector((-.37,.36,1.87))
v=end-start;rot=-math.atan2(v.y,v.z)
box('Long offset golden suspension strut',(start+end)/2,(.145,.21,v.length),brass,body,rot,.028)
# Warm recessed channel on the strut provides a readable bevel and machined back face.
box('Strut inset bronze channel',(-.288,.18,1.41),(.027,.135,.65),bronze,body,rot,.010)
cyl('Upper arm mounting boss',(-.472,.267,1.64),.091,.037,copper,body)
cyl('Upper arm polished stud',(-.496,.267,1.64),.052,.023,brass,body)
# Head is barrel-like, with a clear forward-facing amber eye.
box('Optic green crown shell',(0,.35,1.91),(.57,.39,.34),enamel,optic,0,.075)
box('Optic underside dark bracket',(0,.28,1.705),(.41,.25,.082),dark,optic,0,.022)
cyl('Optic rounded front plate',(0,.555,1.91),.204,.092,enamel,optic,'Y')
cyl('Optic copper retaining ring',(0,.619,1.91),.141,.062,copper,optic,'Y')
cyl('Optic gold inner lip',(0,.656,1.91),.115,.025,brass,optic,'Y')
bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=16,radius=1,location=(0,.68,1.91))
lens=bpy.context.object;lens.scale=(.099,.053,.099);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
finish(lens,'Convex amber optical lens',amber,optic)
box('Optic dorsal cap seam',(0,.308,2.086),(.36,.20,.018),deepgreen,optic,0,.008)
# Shallow rivets, combined by material for a modest mesh count.
rivets=[]
for side in (-1,1):
    for i in range(16):
        a=TAU*(i+.5)/16
        rivets.append(cyl('Sidewall jewel',(side*.287,.706*math.sin(a),CZ+.706*math.cos(a)),.009,.008,enamel,wheel,n=12))
join(rivets,'Thirty two sidewall fasteners',wheel)

# Named NLA tracks assemble rigid transform channels into one glTF clip per state.
def action(obj,name,frames,values,path):
    obj.animation_data_create();a=bpy.data.actions.new(name+'_'+obj.name);obj.animation_data.action=a
    for f,val in zip(frames,values):
        setattr(obj,path,val);obj.keyframe_insert(data_path=path,frame=f,group=obj.name)
    curves=list(a.fcurves) if hasattr(a,'fcurves') else [fc for layer in a.layers for strip in layer.strips for bag in strip.channelbags for fc in bag.fcurves]
    for fc in curves:
        for kp in fc.keyframe_points:kp.interpolation='LINEAR' if obj==wheel else 'BEZIER'
    track=obj.animation_data.nla_tracks.new();track.name=name
    strip=track.strips.new(name,frames[0],a);strip.name=name
    obj.animation_data.action=None

body_loc=body.location.copy();optic_rot=(0,0,0)
action(body,'Idle',[1,31,61],[(0,0,CZ),(0,0,CZ+.012),(0,0,CZ)],'location')
action(optic,'Idle',[1,16,31,46,61],[(0,0,0),(.025,0,.035),(0,0,0),(-.025,0,-.035),(0,0,0)],'rotation_euler')
rollframes=list(range(1,62,5));rollframes.append(61) if rollframes[-1]!=61 else None
for clip,turns in [('Walk',-1),('Swim',-1)]:
    action(wheel,clip,rollframes,[(turns*TAU*(f-1)/60,0,0) for f in rollframes],'rotation_euler')
    action(body,clip,[1,16,31,46,61],[(0,0,CZ),(0,0,CZ+.013),(0,0,CZ),(0,0,CZ+.013),(0,0,CZ)],'location')
    action(optic,clip,[1,31,61],[(0,0,0),(.035,0,0),(0,0,0)],'rotation_euler')
action(body,'Attack',[1,7,13,19,31],[(0,0,CZ),(.0,-.025,CZ-.025),(0,.07,CZ+.014),(0,.02,CZ),(0,0,CZ)],'location')
action(optic,'Attack',[1,7,13,19,31],[(0,0,0),(-.16,0,0),(.16,0,0),(-.04,0,0),(0,0,0)],'rotation_euler')
action(wheel,'Attack',[1,7,13,19,31],[(0,0,0),(.055,0,0),(-.12,0,0),(-.045,0,0),(0,0,0)],'rotation_euler')
# Keep export and geometric validation at a truly neutral rest pose.
for o in (body,wheel,optic):
    if o.animation_data:
        for tr in o.animation_data.nla_tracks:tr.mute=True
body.location=body_loc;wheel.rotation_euler=(0,0,0);optic.rotation_euler=optic_rot
scene.frame_set(0)
bpy.context.view_layer.update()
# Export muted NLA tracks is not supported; restore tracks only for export and hold rest at frame zero.
for o in (body,wheel,optic):
    if o.animation_data:
        for tr in o.animation_data.nla_tracks:tr.mute=False
scene.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_crownwheel_colossus.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_crownwheel_colossus.glb'),export_format='GLB',export_yup=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True,export_frame_range=False,export_force_sampling=True,export_cameras=False,export_lights=False)
print('CROWNWHEEL COMPLETE',OUT)
