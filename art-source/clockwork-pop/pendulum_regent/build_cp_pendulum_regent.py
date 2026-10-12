import bpy, bmesh, math, json
import numpy as np
from pathlib import Path
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
OUT=Path(__file__).parent
OUT.mkdir(parents=True,exist_ok=True)
TAU=math.tau

def texture(name,base,metal=False):
    n=1024
    y,x=np.mgrid[:n,:n].astype(np.float32)/n
    rng=np.random.default_rng(22)
    noise=rng.normal(0,1,(n,n)).astype(np.float32)
    wave=.022*np.sin(TAU*(3*x+2*y))+.013*np.cos(TAU*(8*x-3*y))
    if metal: wave=.045*np.sin(TAU*120*y)+.018*np.sin(TAU*400*y)+.005*noise
    else: wave+=.004*noise
    rgb=np.clip(np.asarray(base)[None,None,:]*(1+wave[:,:,None]),0,1)
    p=np.concatenate([rgb,np.ones((n,n,1))],axis=2).astype(np.float32)
    im=bpy.data.images.new(name,n,n,alpha=False)
    im.colorspace_settings.name='sRGB'
    im.pixels.foreach_set(p.ravel());im.filepath_raw=str(OUT/(name+'.png'));im.file_format='PNG';im.save();im.pack()
    return im

pur_tex=texture('royal_purple_enamel',(0.31,.075,.66))
rose_tex=texture('rose_porcelain_enamel',(.91,.36,.57))
gold_tex=texture('polished_brass',(.91,.64,.25),True)
n=1024;y,x=np.mgrid[:n,:n].astype(np.float32)/n
v=.26+.018*np.sin(TAU*10*x)*np.sin(TAU*7*y)
im=bpy.data.images.new('finish_roughness',n,n,alpha=False);im.colorspace_settings.name='Non-Color'
im.pixels.foreach_set(np.stack([v,v,v,np.ones_like(v)],-1).astype(np.float32).ravel());im.filepath_raw=str(OUT/'finish_roughness.png');im.file_format='PNG';im.save();im.pack()

def mat(name,color,metal=0,rough=.3,tex=None,glow=0):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,1)
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    p.inputs['Coat Weight'].default_value=.32 if metal<.5 else .14;p.inputs['Coat Roughness'].default_value=.18
    if tex:
        t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=tex;m.node_tree.links.new(t.outputs['Color'],p.inputs['Base Color'])
        t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=im;m.node_tree.links.new(t.outputs['Color'],p.inputs['Roughness'])
    if glow:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=glow
    return m
purple=mat('Royal violet enamel',(.31,.075,.66),.16,tex=pur_tex)
rose=mat('Rose enamel',(.91,.36,.57),.07,tex=rose_tex)
gold=mat('Warm polished brass',(.91,.64,.25),.73,tex=gold_tex)
dark=mat('Deep plum cavity',(.027,.008,.061),.08,.45)
handle=mat('Mallet dark walnut',(.08,.032,.078),.1,.42)
ivory=mat('Clock face warm ivory',(.97,.86,.63),.12,.29)
eye=mat('Warm pearl eye',(.98,.82,.37),.08,.2,glow=.17)

def pivot(name,pos,parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=pos
    if parent:o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted()
    bpy.context.view_layer.update();return o
body=pivot('Body',(0,0,1.05))
armL=pivot('Arm_L',(.49,0,1.30),body)
armR=pivot('Arm_R',(-.49,0,1.30),body)
legL=pivot('Leg_L',(.28,0,.61))
legR=pivot('Leg_R',(-.28,0,.61))
pend=pivot('Pendulum',(0,.285,1.315),body)

def finish(o,name,m,parent,smooth=True):
    o.name=name;o.data.materials.append(m)
    if smooth:
        for p in o.data.polygons:p.use_smooth=True
    # Consistent 1-metre box-projected texture density, including bevels and boolean faces.
    uv=o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap')
    for p in o.data.polygons:
        ax=max(range(3),key=lambda a:abs(p.normal[a]))
        for li in p.loop_indices:
            co=o.data.vertices[o.data.loops[li].vertex_index].co
            uv.data[li].uv=((co.y,co.z) if ax==0 else (co.x,co.z) if ax==1 else (co.x,co.y))
    if parent:o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted()
    return o
def bevel(o,w=.02,segments=2):
    bpy.context.view_layer.objects.active=o
    mod=o.modifiers.new('Soft machined edges','BEVEL');mod.width=w;mod.segments=segments
    bpy.ops.object.modifier_apply(modifier=mod.name)
def box(name,loc,size,m,parent,w=.025):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);bevel(o,w)
    return finish(o,name,m,parent)
def sphere(name,loc,scale,m,parent):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20 if max(scale)<.09 else 32,ring_count=10 if max(scale)<.09 else 12,location=loc);o=bpy.context.object;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,m,parent)
def cyl(name,loc,r,depth,m,parent,axis='Z',vertices=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=loc);o=bpy.context.object
    if axis=='X':o.rotation_euler[1]=math.pi/2
    if axis=='Y':o.rotation_euler[0]=math.pi/2
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);bevel(o,min(.015,depth/5));return finish(o,name,m,parent)
def torus(name,loc,major,minor,m,parent,axis='Z'):
    bpy.ops.mesh.primitive_torus_add(major_radius=major,minor_radius=minor,major_segments=48,minor_segments=8,location=loc);o=bpy.context.object
    if axis=='X':o.rotation_euler[1]=math.pi/2
    if axis=='Y':o.rotation_euler[0]=math.pi/2
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,m,parent)
def mesh(name,verts,faces,m,parent):
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);return finish(o,name,m,parent)
def barrel(name,rings,m,parent):
    verts=[];faces=[];n=64
    for z,r in rings:
        verts.extend([(r*math.cos(TAU*i/n),r*math.sin(TAU*i/n),z) for i in range(n)])
    for j in range(len(rings)-1):
        for i in range(n):a=j*n+i;b=j*n+(i+1)%n;faces.append((a,b,b+n,a+n))
    faces.append(tuple(reversed(range(n))));faces.append(tuple((len(rings)-1)*n+i for i in range(n)))
    return mesh(name,verts,faces,m,parent)

# Deep open belly. The cutter opens the front only and leaves the rear wall intact.
shell=barrel('Rose bell shell',[(.66,.42),(.72,.47),(1.32,.47),(1.43,.43)],rose,body)
bpy.ops.mesh.primitive_cube_add(size=1,location=(0,.41,1.055));cut=bpy.context.object;cut.scale=(.60,.88,.58);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);bevel(cut,.11,7)
bpy.context.view_layer.objects.active=shell;mod=shell.modifiers.new('True recessed pendulum chamber','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cut;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cut,do_unlink=True);bevel(shell,.013,3)
# Reproject after boolean.
shell.data.materials.clear();finish(shell,'Rose bell shell',rose,None)
box('Recessed dark chamber backing',(0,-.012,1.055),(.595,.024,.575),dark,body,.105)
# Dark chamber side and roof lining accentuates cavity depth.
box('Recess left lining',(-.282,.10,1.05),(.018,.30,.40),dark,body,.009)
box('Recess right lining',(.282,.10,1.05),(.018,.30,.40),dark,body,.009)
box('Recess roof lining',(0,.11,1.327),(.39,.28,.016),dark,body,.005)
torus('Lower violet rolled rim',(0,0,.68),.465,.040,purple,body)
barrel('Violet rounded underbelly',[(.48,.25),(.52,.35),(.60,.43),(.65,.44)],purple,body)

# Custom hemisphere to avoid a full sphere hidden in the cavity.
verts=[(0,0,1.925)];faces=[];n=64;rows=13
for j in range(1,rows+1):
    a=(math.pi/2)*j/rows;r=.465*math.sin(a);z=1.43+.495*math.cos(a)
    verts.extend([(r*math.cos(TAU*i/n),r*math.sin(TAU*i/n),z) for i in range(n)])
for i in range(n):faces.append((0,1+i,1+(i+1)%n))
for j in range(rows-1):
    for i in range(n):a=1+j*n+i;b=1+j*n+(i+1)%n;faces.append((a,b,b+n,a+n))
faces.append(tuple(reversed([1+(rows-1)*n+i for i in range(n)])))
mesh('Violet bell dome',verts,faces,purple,body)
torus('Rose equator bumper',(0,0,1.431),.460,.036,rose,body)
torus('Eye violet socket',(0,.433,1.568),.158,.032,purple,body,'Y')
cyl('Eye brass bezel',(0,.473,1.568),.156,.066,gold,body,'Y')
sphere('Single warm round eye',(0,.511,1.568),(.128,.046,.128),eye,body)
torus('Eye inner brass lip',(0,.529,1.568),.130,.013,gold,body,'Y')
for x in [-.355,.355]:
    for z in [.755,1.35]:sphere('Rose shell brass rivet',(x,.322,z),(.025,.021,.025),gold,body)

# Three-point sculpted crown, thick extrusion with rounded outer edges.
cyl('Crown gold band',(0,0,1.934),.181,.055,gold,body)
outline=[(-.185,1.954),(-.263,2.157),(-.253,2.193),(-.188,2.205),(-.150,2.191),(-.12,2.087),(-.085,2.064),(-.047,2.085),(-.04,2.189),(-.022,2.221),(.037,2.22),(.06,2.197),(.069,2.087),(.102,2.067),(.133,2.092),(.169,2.195),(.201,2.208),(.258,2.188),(.27,2.167),(.19,1.954)]
v=[(x,y,z) for y in [-.071,.071] for x,z in outline];k=len(outline);f=[tuple(reversed(range(k))),tuple(k+i for i in range(k))]
f.extend([(i,(i+1)%k,(i+1)%k+k,i+k) for i in range(k)])
o=mesh('Rounded rose three point crown',v,f,rose,body);bevel(o,.018,4)
sphere('Crown gold center stud',(0,.087,2.023),(.018,.018,.018),gold,body)

# Shoulders / independent hands. Positive X is the hammer side.
for sign,arm in [(1,armL),(-1,armR)]:
    cyl('Shoulder violet drum',(sign*.478,0,1.30),.126,.105,purple,arm,'X')
    cyl('Shoulder brass bearing',(sign*.535,0,1.30),.095,.041,gold,arm,'X')
    cyl('Shoulder rose core',(sign*.560,0,1.30),.061,.046,rose,arm,'X')
    box('Short rose upper arm',(sign*.622,.015,1.156),(.13,.17,.29),rose,arm,.04)

# Mallet hand, chunky cylindrical head with clock-face medallion.
cyl('Mallet gauntlet cuff',(.733,.087,1.085),.124,.17,purple,armL,'X')
box('Mallet glove',(.825,.18,1.086),(.17,.19,.20),handle,armL,.06)
for z in [1.037,1.137]:box('Enamel gripping fingers',(.871,.267,z),(.16,.068,.083),purple,armL,.026)
cyl('Mallet handle',(.843,.186,1.235),.036,.63,handle,armL)
cyl('Mallet brass pommel',(.843,.186,.913),.052,.050,gold,armL)
sphere('Mallet pommel dome',(.843,.186,.89),(.052,.052,.041),gold,armL)
cyl('Mallet handle collar',(.843,.186,1.47),.055,.043,gold,armL)
# Hammer axis faces front, showing clock face in frontal gameplay views.
cyl('Chunky purple mallet head',(.843,.174,1.671),.183,.36,purple,armL,'Y')
for yy in [-.012,.359]:cyl('Mallet brass cap',(.843,yy,1.671),.194,.046,gold,armL,'Y')
cyl('Mallet ivory clock dial',(.843,.388,1.671),.153,.013,ivory,armL,'Y')
torus('Mallet front brass lip',(.843,.397,1.671),.158,.017,gold,armL,'Y')
for i in range(12):
    a=TAU*i/12
    tick=box('Clock hour index',(.843+.124*math.sin(a),.400,1.671+.124*math.cos(a)),(.009,.006,.020),handle,armL,.002)
    tick.rotation_euler[1]=a
cyl('Clock central boss',(.843,.410,1.671),.043,.030,gold,armL,'Y')
hand=box('Clock hand',(.86,.410,1.713),(.012,.009,.09),handle,armL,.003);hand.rotation_euler[1]=-.32
sphere('Mallet top brass fastener',(.843,.174,1.852),(.036,.037,.021),gold,armL)

# Broad toy shield, gold rim, domed violet disk and boss.
box('Shield gripping mitten',(-.692,.10,1.067),(.18,.18,.19),purple,armR,.06)
cyl('Shield rear brass grip',(-.75,.16,1.045),.068,.13,gold,armR,'Y')
cyl('Shield violet plate',(-.770,.285,1.034),.395,.092,purple,armR,'Y',64)
sphere('Shield convex enamel face',(-.770,.327,1.034),(.358,.104,.358),purple,armR)
torus('Broad shield golden rim',(-.770,.344,1.034),.371,.040,gold,armR,'Y')
torus('Shield dark inset seam',(-.770,.357,1.034),.332,.009,dark,armR,'Y')
sphere('Shield central brass boss',(-.770,.44,1.034),(.083,.043,.083),gold,armR)

# Hanging brass pendulum: all pieces genuinely below the suspension pivot.
sphere('Pendulum suspension cap',(0,.286,1.309),(.065,.06,.029),gold,pend)
cyl('Pendulum stem',(0,.285,1.19),.017,.230,gold,pend)
torus('Pendulum hanger loop',(0,.286,1.077),.041,.012,gold,pend,'Y')
sphere('Heavy brass pendulum bob',(0,.286,.954),(.174,.146,.174),gold,pend)
torus('Pendulum bob equatorial seam',(0,.286,.954),.173,.007,gold,pend)

# Broad short boots with rose knee medallions and brass toe guards.
for sign,leg in [(1,legL),(-1,legR)]:
    x=sign*.274
    sphere('Violet hip joint',(x,0,.573),(.139,.139,.14),purple,leg)
    box('Chunky violet greave',(x,.022,.353),(.256,.26,.35),purple,leg,.062)
    cyl('Brass knee bezel',(x,.164,.447),.073,.033,gold,leg,'Y')
    cyl('Rose knee button',(x,.186,.447),.058,.027,rose,leg,'Y')
    for yy in [-.04,.092]:cyl('Ankle brass rivet',(x+sign*.137,yy,.245),.043,.024,gold,leg,'X')
    box('Boot broad golden sole',(x,.098,.044),(.314,.421,.086),gold,leg,.039)
    sphere('Purple boot instep',(x,.108,.122),(.155,.202,.112),purple,leg)
    sphere('Boot polished brass toe',(x,.25,.105),(.149,.083,.082),gold,leg)

# Back clockwork embellishment, restrained and visible in turnaround.
cyl('Rear winding socket',(0,-.464,1.092),.096,.034,gold,body,'Y')
cyl('Rear violet socket inset',(0,-.49,1.092),.065,.025,purple,body,'Y')
for x in [-.115,.115]:box('Rear crown-shaped winding grip',(x,-.493,1.092),(.075,.024,.030),gold,body,.013)
box('Winding key axle',(0,-.500,1.092),(.18,.03,.025),gold,body,.009)

# Merge rigid surfaces by pivot; material slots preserve each enamel/brass region.
for p in [body,armL,armR,legL,legR,pend]:
    obs=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.parent==p]
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:o.select_set(True)
    bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();o=bpy.context.object;o.name=p.name+'_Surfaces'
    # Normalize weighted shading across bevels while preserving flat caps.
    bm=bmesh.new();bm.from_mesh(o.data)
    for e in bm.edges:
        if len(e.link_faces)==2 and e.calc_face_angle(0)>.65:e.smooth=False
    bm.to_mesh(o.data);bm.free()

scene=bpy.context.scene;scene.render.fps=24
pivots=[body,armL,armR,legL,legR,pend]
rest={o:(o.location.copy(),o.rotation_euler.copy()) for o in pivots}
for clip,frames in [('Idle',48),('Walk',32),('Swim',48),('Attack',30)]:
    for o in pivots:o.animation_data_clear()
    for f in range(0,frames+1,2):
        t=f/frames;s=math.sin(TAU*t)
        for o in pivots:o.location=rest[o][0];o.rotation_euler=rest[o][1]
        pend.rotation_euler[1]=.24*math.sin(2*TAU*t)
        if clip=='Idle':
            body.location.z+=.009*(1-math.cos(TAU*t));armL.rotation_euler[0]=.028*s;armR.rotation_euler[1]=.025*s
        elif clip=='Walk':
            legL.rotation_euler[0]=.36*s;legR.rotation_euler[0]=-.36*s;body.location.z+=.023*(1-math.cos(2*TAU*t));armL.rotation_euler[0]=-.14*s;armR.rotation_euler[0]=.14*s
        elif clip=='Swim':
            body.rotation_euler[0]=-.10;body.location.z+=.035*s;legL.rotation_euler[0]=.26*s;legR.rotation_euler[0]=-.26*s;armL.rotation_euler[1]=.16*s;armR.rotation_euler[1]=-.12*s
        else:
            # Distinct anticipation, rapid heavy downward blow, recovery to neutral.
            a=np.interp(t,[0,.27,.43,.60,.83,1],[0,-.85,-.95,1.95,.30,0])
            armL.rotation_euler[1]=float(a);body.rotation_euler[0]=float(np.interp(t,[0,.43,.6,1],[0,.04,-.09,0]));armR.rotation_euler[1]=-.10*math.sin(math.pi*t)
            body.location.z-=float(np.interp(t,[0,.43,.60,.83,1],[0,0,.10,.025,0]))
            pend.rotation_euler[1]=.22*math.sin(2*TAU*t)
        for o in pivots:o.keyframe_insert(data_path='location',frame=f);o.keyframe_insert(data_path='rotation_euler',frame=f)
    # Include exact final neutral/loop pose when a clip has an odd frame count.
    for o in pivots:
        action=o.animation_data.action;action.name=clip+'_'+o.name
        if clip!='Attack':
            for fc in action.fcurves if hasattr(action,'fcurves') else []:
                for key in fc.keyframe_points:key.interpolation='LINEAR'
        track=o.animation_data.nla_tracks.new();track.name=clip;strip=track.strips.new(clip,0,action);strip.action_frame_start=0;strip.action_frame_end=frames
        o.animation_data.action=None
    # Clearing animation data here would remove NLA. Save tracks before next clip.
    if clip=='Idle':saved={o:[(clip,o.animation_data.nla_tracks[-1].strips[0].action,frames)] for o in pivots}
    else:
        for o in pivots:saved[o].append((clip,o.animation_data.nla_tracks[-1].strips[0].action,frames))

for o in pivots:
    o.animation_data_clear();o.location=rest[o][0];o.rotation_euler=rest[o][1];o.animation_data_create()
    for clip,action,frames in saved[o]:
        track=o.animation_data.nla_tracks.new();track.name=clip;strip=track.strips.new(clip,0,action);strip.action_frame_start=0;strip.action_frame_end=frames
        track.mute=True
scene.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_pendulum_regent.blend'))
# Unmute for export; every clip evaluates to its own keyed rest at frame zero.
for o in pivots:
    for track in o.animation_data.nla_tracks:track.mute=False
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_pendulum_regent.glb'),export_format='GLB',export_yup=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_cameras=False,export_lights=False)
print('EXPORTED PENDULUM REGENT')
