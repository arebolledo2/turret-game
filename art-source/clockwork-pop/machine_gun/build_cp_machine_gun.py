"""Ratchet Sentry. Self-contained Blender build; metres, +Y forward, +Z up."""
from pathlib import Path
import math
import bpy
import bmesh
import numpy as np
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
OUT=Path(__file__).resolve().parent

def mat(name,c,metal=0,rough=.3):
    m=bpy.data.materials.new(name); m.diffuse_color=(*c,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*c,1)
    p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    return m
TEAL=mat('Enamel · turquoise',(.018,.40,.33),.30,.23)
TEALD=mat('Enamel · edge teal',(.015,.28,.27),.36,.30)
BRASS=mat('Polished warm brass',(.80,.42,.065),.75,.23)
CORAL=mat('Coral optic enamel',(.94,.115,.075),.23,.22)
DARK=mat('Graphite plum steel',(.052,.043,.070),.72,.28)
RUBBER=mat('Charcoal foot rubber',(.037,.033,.05),.12,.43)
STEEL=mat('Satin nickel',(.34,.38,.44),.80,.26)
BLUE=mat('Sapphire optic',(.018,.045,.70),.42,.13)
VIOLET=mat('Violet lower optic',(.34,.018,.58),.40,.15)
PALE=mat('Lens glint',(.35,.72,1),.28,.10)
# Small generated optic map: a jewel's blue core, violet rim and reflected studio card.
# The image is built here from arrays and is embedded in the GLB.
yy,xx=np.mgrid[0:256,0:256];u=(xx-127.5)/127.5;v=(yy-127.5)/127.5
rad=np.sqrt(u*u+v*v);bottom=np.clip((-v+.2)/1.2,0,1)
col=np.zeros((256,256,4),dtype=np.float32)
col[:,:,0]=.045+.40*bottom*np.clip(rad,.15,1)
col[:,:,1]=.10+.23*np.clip(v,0,1)
col[:,:,2]=.82-.12*bottom
# Broad cyan glimmer, with a sharply bounded off-center white reflection.
shine=np.exp(-((u+.34)**2/.065+(v-.40)**2/.085))
for i,target in enumerate([.35,.76,1.0]):col[:,:,i]=col[:,:,i]*(1-shine*.75)+target*shine*.75
card=(np.abs(u+.30)<.16)&(np.abs(v-.44)<.19)&(rad<.82)
for i,target in enumerate([.78,.92,1.0]):col[:,:,i]=np.where(card,target,col[:,:,i])
col[:,:,3]=1
im=bpy.data.images.new('Generated sapphire jewel',width=256,height=256,alpha=False)
im.colorspace_settings.name='sRGB';im.pixels.foreach_set(col.ravel());im.pack()
LENS=mat('Optical sapphire glass',(.03,.1,.9),.30,.13)
ns=LENS.node_tree.nodes;tx=ns.new('ShaderNodeTexImage');tx.image=im
LENS.node_tree.links.new(tx.outputs['Color'],ns.get('Principled BSDF').inputs['Base Color'])


parts={}
def finish(o,name,m,parent=None,group=None):
    o.name=name;o.data.materials.append(m)
    for p in o.data.polygons:p.use_smooth=True
    if parent:
        bpy.context.view_layer.update(); w=o.matrix_world.copy();o.parent=parent;o.matrix_world=w
    if group:parts.setdefault(group,[]).append(o)
    return o

def bevel(o,w,n=3):
    mod=o.modifiers.new('Rounded machining','BEVEL');mod.width=w;mod.segments=n;mod.limit_method='ANGLE';mod.angle_limit=.55
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL');mod.keep_sharp=True;mod.weight=35
    bpy.ops.object.modifier_apply(modifier=mod.name)

def box(name,pos,size,m,parent=None,round=.03,group=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);bevel(o,round,4)
    return finish(o,name,m,parent,group)

def cyl(name,pos,r,depth,m,parent=None,axis=(0,0,1),n=32,be=.008,group=None):
    n=min(n,32 if r>.15 else 24)
    bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=depth,location=pos);o=bpy.context.object
    o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
    if be:bevel(o,be,1)
    return finish(o,name,m,parent,group)

def mesh(name,verts,faces,m,parent=None,group=None):
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob)
    return finish(ob,name,m,parent,group)

def ring(name,pos,r,ri,length,m,parent=None,axis=(0,1,0),n=40,group=None,be=.003):
    n=min(n,32 if r>.15 else 24)
    vs=[];fs=[]
    for z,rad in [(-length/2,r),(length/2,r),(-length/2,ri),(length/2,ri)]:
        for i in range(n):
            a=math.tau*i/n;vs.append((rad*math.cos(a),rad*math.sin(a),z))
    for i in range(n):
        j=(i+1)%n
        fs.extend([(i,j,n+j,n+i),(2*n+j,2*n+i,3*n+i,3*n+j),(j,i,2*n+i,2*n+j),(n+i,n+j,3*n+j,3*n+i)])
    ob=mesh(name,vs,fs,m,None);ob.location=pos;ob.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
    if be:bevel(ob,be,1)
    if parent:
        bpy.context.view_layer.update();w=ob.matrix_world.copy();ob.parent=parent;ob.matrix_world=w
    if group:parts.setdefault(group,[]).append(ob)
    return ob

def sphere(name,pos,r,m,parent=None,scale=(1,1,1),group=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=10,radius=r,location=pos)
    o=bpy.context.object;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,m,parent,group)

def empty(name,pos,parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=pos
    if parent:
        bpy.context.view_layer.update();w=o.matrix_world.copy();o.parent=parent;o.matrix_world=w
    return o

Aim=empty('Aim',(0,0,.68))
# Base: three independent braced legs, soft rubber pads and capped shoulder pivots.
cyl('Static azimuth pedestal',(0,0,.56),.20,.18,DARK,group='BaseMechanism')
cyl('Azimuth collar',(0,0,.65),.225,.075,DARK,group='BaseMechanism')
ring('Azimuth trim',(0,0,.677),.224,.194,.018,STEEL,axis=(0,0,1),group='BaseMechanism')
box('Service block',(-.12,.12,.45),(.185,.16,.225),DARK,round=.021,group='BaseMechanism')
box('Block upper seam',(-.12,.201,.535),(.151,.019,.024),STEEL,round=.003,group='BaseMechanism')
for i,ang in enumerate([0,math.tau/3,-math.tau/3]):
    d=Vector((math.sin(ang),math.cos(ang),0));foot=Vector((0,0,.046))+d*.35
    a=Vector((0,0,.50))+d*.14;b=foot+Vector((0,0,.046))
    ob=cyl('Leg enamel '+str(i),(a+b)/2,.085,(b-a).length,TEAL,axis=b-a,n=12,be=.017,group='Leg_'+str(i));
    cyl('Foot rubber '+str(i),foot,.135,.092,RUBBER,n=32,be=.012,group='Leg_'+str(i))
    ring('Foot steel lip '+str(i),foot+Vector((0,0,.043)),.127,.094,.024,STEEL,axis=(0,0,1),n=32,group='Leg_'+str(i))
    cyl('Hip coral '+str(i),a+Vector((0,0,.016)),.100,.06,CORAL,n=24,be=.009,group='BaseMechanism')
    cyl('Hip screw '+str(i),a+Vector((0,0,.050)),.044,.008,DARK,n=24,be=.004,group='BaseMechanism')
    sphere('Hip inset '+str(i),a+Vector((0,0,.057)),.032,STEEL,scale=(1,1,.27),group='BaseMechanism')
    c=foot+d*.10+Vector((0,0,.065))
    cyl('Ankle brass '+str(i),c,.045,.027,BRASS,axis=d,n=24,be=.004,group='Leg_'+str(i))
    cyl('Ankle plum inset '+str(i),c+d*.017,.028,.006,DARK,axis=d,n=24,be=.002,group='Leg_'+str(i))
    cyl('Ankle coral dot '+str(i),c+d*.022,.018,.004,CORAL,axis=d,n=16,be=.001,group='Leg_'+str(i))
# Brass shoulder bearing, readable from both sides at gameplay distance.
for side in [-1,1]:
    axis=(side,0,0)
    cyl('Shoulder brass bearing',(side*.218,0,.578),.095,.061,BRASS,axis=axis,n=32,be=.007,group='BaseMechanism')
    ring('Shoulder coral lock',(side*.254,0,.578),.070,.049,.019,CORAL,axis=axis,n=24,group='BaseMechanism')
    cyl('Shoulder steel concentric inset',(side*.266,0,.578),.048,.012,STEEL,axis=axis,n=24,be=.005,group='BaseMechanism')
    cyl('Shoulder dark bearing center',(side*.275,0,.578),.034,.011,DARK,axis=axis,n=24,be=.004,group='BaseMechanism')
# Receiver: broad curved enamel, inset front lip, panel separation and protected rear.
box('Receiver rounded housing',(0,-.17,1.00),(.60,.64,.57),TEAL,Aim,round=.09,group='Receiver')
box('Front enamel reinforced lip',(0,.158,1.00),(.596,.060,.566),TEAL,Aim,round=.062,group='Receiver')
box('Rear steel backing',(0,-.505,1.00),(.42,.080,.38),DARK,Aim,round=.04,group='RearParts')
# Deliberate sensible unseen rear: connector pod, charging handle and cooling grille.
cyl('Rear brass connector',(0,-.62,1.125),.077,.202,BRASS,Aim,axis=(0,1,0),n=32,be=.006,group='RearParts')
ring('Rear connector lip',(0,-.728,1.125),.077,.049,.016,BRASS,Aim,n=32,group='RearParts')
cyl('Rear plug dark insert',(0,-.73,1.125),.046,.006,DARK,Aim,axis=(0,1,0),n=24,be=0,group='RearParts')
box('Rear charging handle',(-.235,-.514,1.01),(.093,.17,.245),DARK,Aim,round=.023,group='RearParts')
for i in range(4):box('Rear grille slat '+str(i),(.045,-.551,.922+i*.033),(.22,.014,.012),STEEL,Aim,round=.003,group='RearParts')
# Fine panel seam on curved top and both sides, follows receiver profile.
for y in [-.275,-.405]:
    pts=[(-.30,y,.80),(-.30,y,1.20),(-.279,y,1.25),(-.24,y,1.282),(.24,y,1.282),(.279,y,1.25),(.30,y,1.20),(.30,y,.80)]
    for j in range(len(pts)-1):
        a,b=Vector(pts[j]),Vector(pts[j+1]);cyl('Panel seam',(a+b)/2,.003,(b-a).length,STEEL,Aim,axis=b-a,n=6,be=0,group='ReceiverTrim')
# Front flush brass fasteners.
for x in [-.246,.246]:
    for z in [.792,1.205]:
        cyl('Receiver brass screw',(x,.197,z),.018,.009,BRASS,Aim,axis=(0,1,0),n=16,be=.002,group='ReceiverTrim')
# Top coral recessed drum.
ring('Top optic coral rim',(0,-.18,1.307),.115,.091,.048,CORAL,Aim,axis=(0,0,1),n=40,group='TopOptic')
cyl('Top optic interior',(0,-.18,1.294),.09,.016,CORAL,Aim,n=32,be=.006,group='TopOptic')
sphere('Top optic convex cover',(0,-.18,1.307),.088,CORAL,Aim,scale=(1,1,.25),group='TopOptic')
box('Brass top maker plate',(.185,-.33,1.286),(.09,.16,.017),BRASS,Aim,round=.025,group='ReceiverTrim')
for y in [-.38,-.28]:cyl('Maker plate screw',(.185,y,1.301),.009,.006,DARK,Aim,n=12,be=.002,group='ReceiverTrim')
# Side optic: layered dark gasket, coral enclosure and faceted jewel glass.
for side in [-1,1]:
    p=(side*.315,-.22,1.025);axis=(side,0,0)
    cyl('Optic dark shock mount',p,.174,.065,DARK,Aim,axis=axis,n=40,be=.008,group='Optic_'+str(side))
    ring('Coral side optic bezel',(side*.377,-.22,1.025),.156,.105,.089,CORAL,Aim,axis=axis,n=40,be=.009,group='Optic_'+str(side))
    ring('Side optic inner gasket',(side*.422,-.22,1.025),.112,.094,.012,DARK,Aim,axis=axis,n=40,group='Optic_'+str(side))
    # Jewel lens deliberately has visible low-poly facets matching concept.
    verts=[(side*.457,-.22,1.025)];faces=[];N=16
    for radius,dep in [(.048,.447),(.092,.428)]:
        for i in range(N):
            aa=math.tau*i/N;verts.append((side*dep,-.22+radius*math.cos(aa),1.025+radius*math.sin(aa)))
    for i in range(N):
        j=(i+1)%N;faces.append((0,1+i,1+j));faces.append((1+i,17+i,17+j,1+j))
    o=mesh('Sapphire faceted optic',verts,faces,LENS,Aim,group='Optic_'+str(side))
    uv=o.data.uv_layers.new(name='UVMap')
    for poly in o.data.polygons:
        for idx in poly.loop_indices:
            co=o.data.vertices[o.data.loops[idx].vertex_index].co
            uv.data[idx].uv=((co.y+.22)/.19+.5,(co.z-1.025)/.19+.5)
    for idx,p in enumerate(o.data.polygons):
        p.use_smooth=False
        z=sum(o.data.vertices[v].co.z for v in p.vertices)/len(p.vertices)
        p.material_index=0
# Jacket flange and rivets.
ring('Receiver brass cooling flange',(0,.24,1.00),.247,.15,.078,BRASS,Aim,n=48,group='JacketRings')
for i in range(10):
    a=math.tau*i/10;cyl('Flange rivet',(.227*math.cos(a),.285,1+.227*math.sin(a)),.010,.010,BRASS,Aim,axis=(0,1,0),n=12,be=.003,group='JacketRings')
# True perforated thin-wall jacket, parametrically tiled in the cylinder's unrolled surface.
# Every cell has a circular aperture and inner wall; no decal or black-dot substitute.
vs=[];fs=[];NC=24;NR=5;r=.212;t=.007;y0=.294;L=.31
bounds=[(-1,-1),(0,-1),(1,-1),(1,0),(1,1),(0,1),(-1,1),(-1,0)]
for row in range(NR):
    for col in range(NC):
        ac=math.tau*(col+.5)/NC;yc=y0+L*(row+.5)/NR;hw=math.pi*r/NC;hh=L/NR/2;rad=.0175
        base=len(vs)
        for radius,hole in [(r,False),(r,True),(r-t,False),(r-t,True)]:
            for k,(u,v) in enumerate(bounds):
                if hole:
                    aa=math.atan2(v,u);s=rad*math.cos(aa);dy=rad*math.sin(aa)
                else:s=u*hw;dy=v*hh
                th=ac+s/r;vs.append((radius*math.cos(th),yc+dy,1+radius*math.sin(th)))
        for k in range(8):
            j=(k+1)%8
            fs.extend([(base+k,base+j,base+8+j,base+8+k),(base+16+j,base+16+k,base+24+k,base+24+j),(base+8+k,base+8+j,base+24+j,base+24+k)])
mesh('Perforated brass cooling jacket',vs,fs,BRASS,Aim,group='CoolingJacket')
ring('Jacket front golden cuff',(0,.637,1),.222,.184,.075,BRASS,Aim,n=48,group='JacketRings')
ring('Jacket collar highlight',(0,.675,1),.226,.177,.018,BRASS,Aim,n=48,group='JacketRings')
# Dark inner heat sleeve is smaller, so perforations expose real depth.
cyl('Dark internal heat sleeve',(0,.465,1),.117,.36,DARK,Aim,axis=(0,1,0),n=32,be=.004,group='Barrel')
ring('Barrel throat',(0,.670,1),.097,.057,.035,DARK,Aim,n=40,group='Barrel')
ring('Throat steel edge',(0,.690,1),.077,.056,.012,STEEL,Aim,n=32,group='Barrel')
ring('Single long barrel',(0,.81,1),.056,.033,.26,DARK,Aim,n=32,group='Barrel')
ring('Muzzle collar',(0,.909,1),.080,.055,.022,BRASS,Aim,n=32,group='MuzzleHardware')
ring('Muzzle brass tip',(0,.958,1),.074,.038,.075,BRASS,Aim,n=40,group='MuzzleHardware')
ring('Muzzle face bevel',(0,.999,1),.076,.035,.012,BRASS,Aim,n=40,group='MuzzleHardware')
ring('Deep dark muzzle bore',(0,.975,1),.038,.030,.045,DARK,Aim,n=32,group='MuzzleHardware',be=0)
for i in range(6):
    a=math.tau*i/6;cyl('Muzzle small pin',(.064*math.cos(a),1.006,1+.064*math.sin(a)),.003,.002,DARK,Aim,axis=(0,1,0),n=8,be=0,group='MuzzleHardware')
Muzzle=empty('Muzzle',(0,1.007,1),Aim)
# Apply transforms before joins so exported bounds are tight and reliable.
for ob in list(bpy.context.scene.objects):
    if ob.type=='MESH':
        bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
        bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
# Keep rigid assemblies compact without merging independently useful leg / optic parts.
for name,obs in parts.items():
    if len(obs)>1:
        bpy.ops.object.select_all(action='DESELECT')
        for o in obs:o.select_set(True)
        bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();obs[0].name=name
# Recalculate consistently oriented normals on custom perforated surfaces.
for o in list(bpy.context.scene.objects):
    if o.type=='MESH':
        bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=bm.verts,dist=.00001);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(o.data);bm.free()
# Retain editable packed source in the same run folder.
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_machine_gun.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_machine_gun.glb'),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False)

