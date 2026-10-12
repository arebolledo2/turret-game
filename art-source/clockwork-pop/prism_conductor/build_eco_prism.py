from pathlib import Path
import math, random, json
import bpy, bmesh
import numpy as np
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
OUT = Path(__file__).parent
random.seed(21)
TAU=math.tau

# Four authored atlases: clean coated surfaces, brushed gold, optical coatings.
palette=[(.29,.13,.78),(.88,.59,.17),(.68,.78,.86),(.017,.020,.051),
         (.98,.60,.40),(1.0,.80,.60),(.94,.44,.51),(.66,.48,.86),
         (.014,.38,.53),(.008,.12,.25),(.28,.15,.76),(.27,.30,.40),
         (.05,.82,.95),(.47,.29,.08),(.38,.22,.81),(.86,.56,.39)]
rough=[.29,.25,.23,.24,.18,.21,.24,.24,.12,.14,.24,.33,.15,.32,.25,.22]
metal=[.32,.86,.34,.35,.03,.03,.03,.03,.38,.42,.25,.82,.18,.85,.28,.05]
size=1024; tile=256
arrays={k:np.zeros((size,size,4),np.float32) for k in ['Surface','ORM','Emission','Normal']}
for k in arrays: arrays[k][:,:,3]=1
yy,xx=np.mgrid[:tile,:tile]; rng=np.random.default_rng(4)
grain=rng.normal(0,.0018,(tile,tile))
for i,col in enumerate(palette):
    tx=(i%4)*tile; ty=(i//4)*tile
    wave=np.sin(xx*.22+np.sin(yy*.042))*0.008
    if i in (1,13): wave=np.sin(yy*2.1)*.010+np.sin(yy*.087)*.012
    if i in (4,5,6,7,15): wave=.022*np.sin(xx*.029+yy*.020)+.012*np.cos(xx*.061-yy*.025)
    sheen=.025*np.cos((xx-tile*.4)/tile*math.pi)*np.cos((yy-tile*.4)/tile*math.pi)
    arrays['Surface'][ty:ty+tile,tx:tx+tile,:3]=np.clip(np.array(col)[None,None,:]*(1+wave[:,:,None]+sheen[:,:,None])+grain[:,:,None],0,1)
    arrays['ORM'][ty:ty+tile,tx:tx+tile,0]=1
    arrays['ORM'][ty:ty+tile,tx:tx+tile,1]=np.clip(rough[i]+wave*.45,.07,1)
    arrays['ORM'][ty:ty+tile,tx:tx+tile,2]=metal[i]
    arrays['Normal'][ty:ty+tile,tx:tx+tile,:3]=np.stack([.5+grain*.3,.5+wave*.12,np.ones_like(xx)],-1)
    if i in (4,5,6,7,15): arrays['Emission'][ty:ty+tile,tx:tx+tile,:3]=np.array(col)*.10
    if i==12: arrays['Emission'][ty:ty+tile,tx:tx+tile,:3]=np.array(col)*.55
images={}
for name,data in arrays.items():
    image=bpy.data.images.new('Prism_'+name,width=size,height=size,alpha=False)
    image.colorspace_settings.name='sRGB' if name in ('Surface','Emission') else 'Non-Color'
    image.pixels.foreach_set(data.ravel());image.filepath_raw=str(OUT/('prism_'+name.lower()+'.png'));image.file_format='PNG';image.save();image.pack();images[name]=image

names=['Violet enamel','Polished warm gold','Pearl ceramic','Optic shadow','Peach crystal','Champagne crystal','Rose crystal','Lilac crystal','Azure optic','Deep blue glass','Royal amethyst','Dark titanium','Cyan light','Gold recess','Violet bevel','Warm crystal']
mats=[]
for i,name in enumerate(names):
    mat=bpy.data.materials.new(name);mat.use_nodes=True;mat.diffuse_color=(*palette[i],1);mat['atlas_tile']=i
    n=mat.node_tree.nodes;l=mat.node_tree.links;p=n.get('Principled BSDF')
    tex={}
    for label in images:
        t=n.new('ShaderNodeTexImage');t.image=images[label];tex[label]=t;t.extension='EXTEND'
    l.new(tex['Surface'].outputs['Color'],p.inputs['Base Color'])
    sep=n.new('ShaderNodeSeparateColor');l.new(tex['ORM'].outputs['Color'],sep.inputs[0]);l.new(sep.outputs[1],p.inputs['Roughness']);l.new(sep.outputs[2],p.inputs['Metallic'])
    norm=n.new('ShaderNodeNormalMap');norm.inputs['Strength'].default_value=.18;l.new(tex['Normal'].outputs['Color'],norm.inputs['Color']);l.new(norm.outputs[0],p.inputs['Normal'])
    l.new(tex['Emission'].outputs['Color'],p.inputs['Emission Color']);p.inputs['Emission Strength'].default_value=.65 if i==12 else .25
    p.inputs['Coat Weight'].default_value=.30 if i not in (3,11,13) else .08;p.inputs['Coat Roughness'].default_value=.12
    mats.append(mat)

groups={}
def empty(name,loc=(0,0,0),parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=loc;o.parent=parent;groups[o]=[];return o
root=empty('Body')
lenses={s:empty('Lens_'+s,(x,0,.88),root) for s,x in [('L',-.57),('R',.57)]}
crown=empty('Crown',(0,0,1.25),root)
claws={s:empty('Claw_'+s,(x,.02,.59),root) for s,x in [('L',-.51),('R',.51)]}
thrusters={s:empty('Thruster_'+s,(x,0,.30),root) for s,x in [('L',-.19),('R',.19)]}
muzzle=empty('Muzzle',(0,.587,.80),root)

def finish(o,name,mat,parent,smooth=True):
    o.name=name;o.data.materials.append(mats[mat])
    if smooth:
        for p in o.data.polygons:p.use_smooth=True
    o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted();groups[parent].append(o);return o
def sphere(name,loc,scale,mat,parent,seg=32,rings=20):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=min(seg,48),ring_count=min(rings,28),location=loc);o=bpy.context.object;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,mat,parent)
def cylinder(name,loc,r,depth,mat,parent,axis=(0,0,1),verts=40):
    bpy.ops.mesh.primitive_cylinder_add(vertices=min(verts,28),radius=r,depth=depth,location=loc);o=bpy.context.object;o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
    mod=o.modifiers.new('Rounded machined edge','BEVEL');mod.width=min(.012,r*.12,depth*.12);mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(o,name,mat,parent)
def torus(name,loc,r,minor,mat,parent,axis=(0,1,0),seg=64):
    bpy.ops.mesh.primitive_torus_add(major_segments=min(seg,40),minor_segments=8,location=loc,major_radius=r,minor_radius=minor);o=bpy.context.object;o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler();return finish(o,name,mat,parent)
def strut(name,a,b,r,mat,parent):
    a,b=Vector(a),Vector(b);return cylinder(name,(a+b)/2,r,(b-a).length,mat,parent,b-a,32)
def box(name,loc,scale,mat,parent,rot=(0,0,0),bevel=.035):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.rotation_euler=rot
    mod=o.modifiers.new('Soft ceramic contours','BEVEL');mod.width=bevel;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name);return finish(o,name,mat,parent)
def crystal(name,base,tip,r,mat,parent):
    a,b=Vector(base),Vector(tip);axis=(b-a);up=axis.normalized();side=up.cross(Vector((0,1,0))).normalized();other=up.cross(side)
    vs=[]
    for t,rad in [(0,r*.52),(.68,r),(.97,r*.26)]:
        center=a+axis*t
        for k in range(6):vs.append(center+(side*math.cos(TAU*k/6)+other*math.sin(TAU*k/6))*rad)
    vs.append(b);faces=[tuple(reversed(range(6)))]
    for ring in range(2):
        for k in range(6):faces.append((ring*6+k,ring*6+(k+1)%6,(ring+1)*6+(k+1)%6,(ring+1)*6+k))
    for k in range(6):faces.append((12+k,12+(k+1)%6,18))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);return finish(o,name,mat,parent,False)
def optic(name,center,r,depth,parent,colors):
    # Closed, convex triangulated low-poly optical dome with intentionally broad facets.
    x,y,z=center;vs=[(x,y+depth,z)];rings=[(.51,6),(.83,10),(1.,14)] if r>.2 else [(.48,6),(.82,10),(1.,14)]
    ids=[]
    for ir,(rr,count) in enumerate(rings):
        row=[]
        for k in range(count):
            a=TAU*(k/count)+(ir%2)*.12;rad=rr*r;row.append(len(vs));vs.append((x+rad*math.cos(a),y+depth*math.sqrt(max(0,1-rr*rr)),z+rad*math.sin(a)))
        ids.append(row)
    faces=[]
    for k in range(len(ids[0])):faces.append((0,ids[0][(k+1)%len(ids[0])],ids[0][k]))
    for a,b in zip(ids[:-1],ids[1:]):
        ia=ib=0
        while ia<len(a) or ib<len(b):
            na=(ia+1)/len(a) if ia<len(a) else 2;nb=(ib+1)/len(b) if ib<len(b) else 2
            if na<=nb:faces.append((a[ia%len(a)],b[ib%len(b)],a[(ia+1)%len(a)]));ia+=1
            else:faces.append((a[ia%len(a)],b[ib%len(b)],b[(ib+1)%len(b)]));ib+=1
    vs.append((x,y-.015,z));bi=len(vs)-1
    for k in range(len(ids[-1])):faces.append((bi,ids[-1][k],ids[-1][(k+1)%len(ids[-1])]))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
    for m in colors:mesh.materials.append(mats[m])
    for p in mesh.polygons:
        cc=p.center
        if r>.2:
            # A pale peach central heart and deliberate rosy lower / lilac edge facets.
            if p.index<6:p.material_index=1
            elif cc.z<z-r*.43:p.material_index=4 if p.index%3 else 0
            elif abs(cc.x-x)>r*.75 and cc.z>z:p.material_index=5
            else:p.material_index=0 if p.index%4 else 2
        else:
            if p.index<6:p.material_index=0
            else:p.material_index=(2 if cc.z>z+.035 else 3 if cc.x>x+.06 else 0)
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted();groups[parent].append(o);return o

# Round optical chassis and broad porcelain bezel.
sphere('Round lavender chassis',(0,0,.79),(.45,.325,.45),0,root,64,36)
torus('Rear equatorial seam',(0,-.035,.79),.446,.009,10,root)
torus('Rear gold service band',(0,-.276,.79),.225,.010,1,root)
cylinder('Rear access plate',(0,-.306,.79),.205,.033,10,root,(0,1,0),64)
torus('Rear plate inner edge',(0,-.33,.79),.147,.012,1,root)
cylinder('Rear violet spindle',(0,-.342,.79),.079,.03,11,root,(0,1,0))
for k in range(8):
    a=k*TAU/8;box('Rear cooling slot',(math.sin(a)*.127,-.355,.79+math.cos(a)*.127),(.024,.010,.050),3,root,(0,a,0),.005)
torus('Outer optic lavender seat',(0,.290,.81),.342,.049,10,root)
torus('Wide pearl optic rim',(0,.327,.81),.337,.031,2,root)
torus('Inner burgundy optical gasket',(0,.348,.81),.304,.017,3,root)
torus('Rose lens retaining lip',(0,.365,.81),.300,.011,6,root)
optic('Faceted peach crystal heart',(0,.367,.81),.293,.15,root,[4,5,5,5,6,7])
# Gold accents embedded around shell, making restrained areas of reflected warm light.
for x,z in [(-.26,1.10),(.25,1.10),(-.29,.55),(.28,.55),(-.10,.382)]:
    y=.245 if z>.65 else .221
    cylinder('Gold optical calibration stud',(x,y,z),.033,.025,1,root,(0,1,0),32)
    cylinder('Stud inset',(x,y+.016,z),.020,.009,13,root,(0,1,0),28)
box('Gold bezel latch',(-.339,.351,.80),(.024,.032,.115),1,root,bevel=.010)
box('Gold upper tick',(.03,.271,1.215),(.082,.021,.018),1,root,bevel=.008)
cylinder('Lower nozzle seat',(0,.245,.435),.095,.040,13,root,(0,1,.30))
cylinder('Lower gold nozzle',(0,.297,.425),.061,.091,1,root,(0,1,.30))
torus('Nozzle optical tip',(0,.349,.438),.033,.008,1,root,(0,1,.30),40)
cylinder('Nozzle pupil',(0,.355,.440),.025,.012,10,root,(0,1,.30),32)

# Two pivoted satellite housings, with optical fronts facing the same forward direction.
for s,sign in [('L',-1),('R',1)]:
    x=.585*sign;p=lenses[s]
    strut('Lens coupling',(.402*sign,0,.88),(.565*sign,0,.88),.102,10,p)
    torus('Satellite coupling collar',(.461*sign,0,.88),.103,.016,1,p,(1,0,0),40)
    sphere('Gold satellite shell',(x,.014,.88),(.184,.169,.186),1,p,40,24)
    cylinder('Satellite dark socket',(x,.144,.88),.131,.036,3,p,(0,1,0),48)
    torus('Satellite polished rim',(x,.168,.88),.133,.018,1,p,(0,1,0),48)
    torus('Satellite inner violet coating',(x,.172,.88),.113,.008,10,p,(0,1,0),40)
    optic('Blue faceted satellite eye',(x,.174,.88),.107,.037,p,[8,8,9,10])
    sphere('Eye catchlight',(x-.031,.203,.923),(.025,.005,.019),2,p,24,12)
    sphere('Small cyan inner light',(x+.035,.207,.864),(.013,.006,.014),12,p,20,12)
    cp=claws[s]
    sphere('Gold shoulder ball',(.512*sign,.015,.609),(.068,.075,.071),1,cp,32,20)
    torus('Violet shoulder hinge',(.478*sign,.0,.604),.060,.018,10,cp,(1,0,0),40)
    strut('Claw arm',(.519*sign,.012,.585),(.571*sign,.046,.461),.045,11,cp)
    box('Violet claw mitten',(.574*sign,.045,.391),(.180,.145,.225),10,cp,(0,sign*.23,0),.038)
    box('Pearl claw outer guard',(.593*sign,.115,.438),(.156,.050,.169),2,cp,(0,sign*.25,0),.025)
    box('Pearl lower gripper',(.578*sign,.057,.290),(.146,.137,.099),2,cp,(0,sign*.20,0),.026)
    torus('Gold finger',(.510*sign,.068,.328),.044,.019,1,cp,(0,1,0),32)
    cylinder('Gold claw tip',(.589*sign,.061,.250),.039,.023,1,cp,(0,0,1),32)
    tp=thrusters[s]
    strut('Lower gold strut',(.177*sign,-.017,.391),(.217*sign,-.020,.266),.033,1,tp)
    cylinder('Violet foot thruster',(.222*sign,-.020,.226),.063,.103,10,tp,(sign*.20,0,1),32)
    torus('Gold thruster end',(.231*sign,-.020,.174),.045,.010,1,tp,(sign*.20,0,1),32)
    cylinder('Thruster blue inset',(.232*sign,-.020,.167),.032,.012,9,tp,(sign*.20,0,1),32)
cylinder('Central hover stabilizer',(0,-.035,.304),.11,.074,10,root)
cylinder('Stabilizer gold bottom',(0,-.035,.263),.072,.025,1,root)

# Three royal crystal points; rear supports deliberately smaller, maintaining the three-point silhouette.
cylinder('Crown gold pedestal',(0,0,1.232),.115,.051,1,crown)
cylinder('Crown steel neck',(0,0,1.290),.046,.075,11,crown)
cylinder('Crown gold collar',(0,0,1.332),.067,.026,1,crown)
box('Crown violet bridge',(0,0,1.363),(.300,.095,.069),10,crown,bevel=.015)
for name,base,tip,r in [('Center',(0,.008,1.358),(0,.014,1.617),.081),('Left',(-.104,0,1.360),(-.240,.001,1.599),.073),('Right',(.104,0,1.360),(.240,.001,1.599),.073)]:crystal('Crown '+name,base,tip,r,10,crown)

# Join each moving assembly into one mesh, retaining material regions. Atlas UVs use
# uniform local projection at 1.2m per tile, with ample padding and a tile per finish.
bpy.context.view_layer.update()
for parent,parts in groups.items():
    if not parts:continue
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=bpy.context.object;o.name=parent.name+'_Assembly'
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    mesh=o.data;uv=mesh.uv_layers.active or mesh.uv_layers.new(name='PrismAtlasUV')
    for p in mesh.polygons:
        tileid=mesh.materials[p.material_index]['atlas_tile'];ax=max(range(3),key=lambda a:abs(p.normal[a]));axes=[i for i in range(3) if i!=ax]
        for li in p.loop_indices:
            co=mesh.vertices[mesh.loops[li].vertex_index].co
            u=.5+co[axes[0]]/1.2;v=.5+co[axes[1]]/1.2
            u=min(.96,max(.04,u));v=min(.96,max(.04,v))
            uv.data[li].uv=((tileid%4+u)/4,(tileid//4+v)/4)
    mesh.uv_layers.active=uv

# Separate clips on NLA tracks. Body is the stationary root: only child rigid pivots
# move, so playback never introduces locomotion or model drift.
scene=bpy.context.scene;scene.render.fps=30
animated=list(lenses.values())+[crown]+list(claws.values())+list(thrusters.values())
rest={o:(o.location.copy(),o.rotation_euler.copy()) for o in animated}
for clip,frames in [('Idle',120),('Walk',36),('Swim',60),('Attack',36)]:
    for o in animated:
        o.animation_data_create();act=bpy.data.actions.new(clip+'_'+o.name);o.animation_data.action=act
        for f in range(0,frames+1,3):
            t=f/frames;wave=math.sin(TAU*t);swell=math.sin(math.pi*t)**2
            loc,rot=rest[o];o.location=loc;o.rotation_euler=rot
            sign=-1 if o.name.endswith('_L') else 1
            if clip=='Idle':
                o.rotation_euler.y=sign*.045*wave if o.name.startswith('Lens') else .028*wave
                if o==crown:o.location.z+=.008*wave
            elif clip in ('Walk','Swim'):
                amp=.16 if clip=='Swim' else .09
                if o.name.startswith('Claw'):o.rotation_euler.y=sign*amp*wave;o.rotation_euler.x=.09*math.cos(TAU*t)
                elif o.name.startswith('Lens'):o.rotation_euler.z=sign*.10*wave;o.rotation_euler.x=.055*wave
                elif o.name.startswith('Thruster'):o.rotation_euler.y=sign*.12*wave
                else:o.rotation_euler.y=.055*wave;o.location.z+=.013*wave
            elif clip=='Attack':
                if o.name.startswith('Lens'):o.rotation_euler.z=-sign*.24*swell;o.location.y+=.055*swell
                elif o.name.startswith('Claw'):o.rotation_euler.x=-.3*swell;o.rotation_euler.y=-sign*.16*swell
                elif o==crown:o.location.z+=.040*swell;o.rotation_euler.z=.09*swell
                else:o.rotation_euler.x=.13*swell
            o.keyframe_insert(data_path='location',frame=f);o.keyframe_insert(data_path='rotation_euler',frame=f)
        o.animation_data.action=None;track=o.animation_data.nla_tracks.new();track.name=clip;strip=track.strips.new(clip,0,act);strip.name=clip
        strip.extrapolation='NOTHING';track.mute=False
        o.location=rest[o][0];o.rotation_euler=rest[o][1]
scene.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'eco_prism.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'eco_prism.glb'),export_format='GLB',export_yup=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_cameras=False,export_lights=False,export_materials='EXPORT',export_frame_range=False,export_force_sampling=True)
print('EXPORTED PRISM CONDUCTOR',OUT/'eco_prism.glb')
