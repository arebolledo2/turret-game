"""Brood tender: scripted rounded enamel carrier, procedural atlas, rigid-part clips."""
import bpy, math, json
import numpy as np
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).parent
bpy.ops.wm.read_factory_settings(use_empty=True)
PALETTE = [(0.47,.105,.32),(.60,.77,.24),(.085,.10,.16),(.98,.40,.22),(1.0,.88,.52),(.46,.89,.79),(.13,.055,.13),(.35,.42,.48)]
NAMES = ['Plum enamel','Pistachio enamel','Graphite mechanics','Apricot trim','Cream lens','Mint capsule','Plum seals','Steel']
TILES = {}
MATS = {}

def make_image(name,pixels,noncolor=False):
    im=bpy.data.images.new(name,1024,1024,alpha=True)
    im.colorspace_settings.name='Non-Color' if noncolor else 'sRGB'
    im.pixels.foreach_set(pixels.astype(np.float32).ravel())
    im.filepath_raw=str(OUT/(name+'.png'));im.file_format='PNG';im.save();im.pack()
    return im

yy,xx=np.mgrid[0:1024,0:1024]; u=(xx%256)/255;v=(yy%512)/511
base=np.ones((1024,1024,4)); orm=np.ones_like(base);normal=np.ones_like(base)
grain=np.random.default_rng(47).normal(0,.0018,(1024,1024))
for i,c in enumerate(PALETTE):
    m=(xx//256==i%4)&(yy//512==i//4)
    # Soft enamel gradients and very small molded texture; no dirt.
    variation=.93+.055*np.sin(v*math.pi)+.013*np.cos(u*math.tau)+grain
    for k in range(3):base[:,:,k][m]=(np.array(c)[k]*variation)[m]
    r=[.32,.34,.44,.30,.24,.16,.49,.38][i]
    orm[:,:,0][m]=1;orm[:,:,1][m]=(r+.016*np.sin(u*math.tau*3)*np.sin(v*math.tau*2))[m];orm[:,:,2][m]=.35 if i==7 else .08 if i in (2,3) else 0
normal[:,:,0]=.5+.0007*np.sin(u*math.tau*16);normal[:,:,1]=.5+.0007*np.cos(v*math.tau*16);normal[:,:,2]=1
BASE=make_image('enamel_atlas',base);ORM=make_image('enamel_orm',orm,True);NORMAL=make_image('enamel_normal',normal,True)
for i,name in enumerate(NAMES):
    mat=bpy.data.materials.new(name);mat.use_nodes=True;mat.diffuse_color=(*PALETTE[i],1)
    nodes=mat.node_tree.nodes;links=mat.node_tree.links;p=nodes.get('Principled BSDF')
    t=nodes.new('ShaderNodeTexImage');t.image=BASE;links.new(t.outputs['Color'],p.inputs['Base Color'])
    t=nodes.new('ShaderNodeTexImage');t.image=ORM;sep=nodes.new('ShaderNodeSeparateColor');links.new(t.outputs['Color'],sep.inputs['Color']);links.new(sep.outputs['Green'],p.inputs['Roughness']);links.new(sep.outputs['Blue'],p.inputs['Metallic'])
    t=nodes.new('ShaderNodeTexImage');t.image=NORMAL;n=nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.15;links.new(t.outputs['Color'],n.inputs['Color']);links.new(n.outputs['Normal'],p.inputs['Normal'])
    p.inputs['Coat Weight'].default_value=.27 if i in (0,1,3) else .1
    if i==4:p.inputs['Emission Color'].default_value=(*PALETTE[i],1);p.inputs['Emission Strength'].default_value=.16
    MATS[i]=mat;TILES[mat.name]=i
glass=MATS[5].copy();glass.name='Pale mint transparent glass';p=glass.node_tree.nodes.get('Principled BSDF');p.inputs['Transmission Weight'].default_value=.7;p.inputs['Alpha'].default_value=.53;p.inputs['IOR'].default_value=1.36;p.inputs['Coat Weight'].default_value=.4
glass.surface_render_method='DITHERED';glass.use_backface_culling=False;TILES[glass.name]=5

def empty(name,pos=(0,0,0),parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=pos;o.parent=parent;return o
ROOT=empty('Body');HULL=empty('Carriage',parent=ROOT)
GROUPS={}
def finish(o,name,mat,parent):
    o.name=name;o.data.materials.append(mat)
    for p in o.data.polygons:p.use_smooth=True
    # Atlas projection uses each polygon's dominant plane, normalized world density.
    uv=o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap');tile=TILES[mat.name]
    bounds=[(min(v.co[k] for v in o.data.vertices),max(v.co[k] for v in o.data.vertices)) for k in range(3)]
    for p in o.data.polygons:
        ax=max(range(3),key=lambda a:abs(p.normal[a]))
        axes=(1,2) if ax==0 else (0,2) if ax==1 else (0,1)
        for li in p.loop_indices:
            co=o.data.vertices[o.data.loops[li].vertex_index].co
            a,b=[co[k]-bounds[k][0] for k in axes]
            # 230.4 pixels/metre on both axes (atlas cells are 256 x 512).
            uv.data[li].uv=((tile%4+.04+a*.9)/4,(tile//4+.04+b*.45)/2)
    bpy.context.view_layer.update()
    world=o.matrix_world.copy();o.parent=parent;o.matrix_world=world
    GROUPS.setdefault(parent.name,[]).append(o);return o
def sphere(name,pos,scale,mat,parent=HULL,seg=24,rings=14):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=min(seg,32),ring_count=min(rings,16),radius=1,location=pos);o=bpy.context.object;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,mat,parent)
def cylinder(name,pos,rad,depth,mat,parent=HULL,axis=(0,0,1),verts=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=rad,depth=depth,location=pos);o=bpy.context.object;o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
    bevel=o.modifiers.new('Soft machined edges','BEVEL');bevel.width=min(.012,depth*.18,rad*.12);bevel.segments=1;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=bevel.name)
    return finish(o,name,mat,parent)
def rod(name,a,b,r,mat,parent=HULL):
    a,b=Vector(a),Vector(b);return cylinder(name,(a+b)/2,r,(b-a).length,mat,parent,b-a,16)
def torus(name,pos,major,minor,mat,parent=HULL,axis=(0,0,1),majorseg=32,minorseg=6):
    bpy.ops.mesh.primitive_torus_add(major_radius=major,minor_radius=minor,major_segments=majorseg,minor_segments=minorseg,location=pos);o=bpy.context.object;o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler();return finish(o,name,mat,parent)
def box(name,pos,size,mat,parent=HULL,bevel=.02):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    m=o.modifiers.new('Rounded panel','BEVEL');m.width=bevel;m.segments=3;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=m.name);return finish(o,name,mat,parent)
def lathe(name,pos,profile,mat,parent=HULL,scale=(1,1,1),n=48):
    vs=[];fs=[]
    for z,r in profile:
        for j in range(n):
            a=j*math.tau/n;vs.append((r*math.cos(a)*scale[0],r*math.sin(a)*scale[1],z*scale[2]))
    for k in range(len(profile)-1):
        for j in range(n):a=k*n+j;b=k*n+(j+1)%n;fs.append((a,b,b+n,a+n))
    fs.append(tuple(reversed(range(n))));fs.append(tuple(range((len(profile)-1)*n,len(profile)*n)))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],fs);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.location=pos;return finish(o,name,mat,parent)
def arc(name,pts,r,mat,parent=HULL):
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.bevel_depth=r;cu.bevel_resolution=1;sp=cu.splines.new('POLY');sp.points.add(len(pts)-1)
    for p,co in zip(sp.points,pts):p.co=(*co,1)
    o=bpy.data.objects.new(name,cu);bpy.context.collection.objects.link(o);bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');o=bpy.context.object;o.select_set(False);return finish(o,name,mat,parent)

# Bulbous plum barrel, flat bottom and an open scalloped crown.
profile=[(.31,.22),(.33,.31),(.37,.38),(.43,.43),(.52,.46),(.65,.475),(.78,.47),(.88,.44),(.96,.415)]
shell=lathe('Bulbous enamel shell',(0,0,0),profile,MATS[0],scale=(1,.91,1))
torus('Belly seam',(0,0,.52),.445,.009,MATS[6],majorseg=48)
torus('Crown rolled lip',(0,0,.935),.395,.02,MATS[0],majorseg=48)
lathe('Crown inset',(0,0,0),[(.94,.32),(.945,.37)],MATS[6],n=48)

# Broad circular face panel and inset cream glass lens, facing +Y.
sphere('Front green plate',(0,.377,.665),(.295,.078,.282),MATS[1],seg=40,rings=20)
torus('Pistachio panel seal',(0,.40,.665),.273,.014,MATS[6],axis=(0,1,0),majorseg=40)
cylinder('Purple lens rim',(0,.46,.685),.175,.07,MATS[0],axis=(0,1,0),verts=40)
torus('Dark lens gasket',(0,.501,.685),.147,.009,MATS[6],axis=(0,1,0),majorseg=40)
sphere('Cream lens',(0,.51,.685),(.14,.045,.14),MATS[4],seg=36,rings=18)
sphere('Lens soft reflection',(-.045,.548,.737),(.022,.0025,.018),MATS[4],seg=12,rings=8)
for j in range(8):
    a=j*math.tau/8+.15;x=.258*math.sin(a);z=.665+.25*math.cos(a)
    sphere('Apricot front fastener',(x,.429,z),(.018,.012,.018),MATS[3],seg=12,rings=8)

# Side pistachio plates and coral rotary shoulders with graphite centers.
for s in (-1,1):
    sphere('Side pistachio cover',(s*.419,0,.664),(.075,.264,.255),MATS[1],seg=32,rings=16)
    cylinder('Side seal',(s*.488,.035,.665),.137,.027,MATS[6],axis=(s,0,0),verts=32)
    cylinder('Shoulder graphite hub',(s*.513,.035,.665),.117,.032,MATS[2],axis=(s,0,0),verts=32)
    torus('Coral shoulder rim',(s*.545,.035,.665),.091,.023,MATS[3],axis=(s,0,0))
    cylinder('Mint shoulder center',(s*.557,.035,.665),.075,.022,MATS[5],axis=(s,0,0))
    cylinder('Hub cap',(s*.571,.035,.665),.048,.026,MATS[2],axis=(s,0,0))
    for j in range(6):
        a=j*math.tau/6;sphere('Hub screw',(s*.535,.035+.107*math.cos(a),.665+.107*math.sin(a)),(.007,.009,.009),MATS[7],seg=8,rings=6)

# Back carries a gently domed service plate, tiny vents and collar lights.
sphere('Rear plum service cover',(0,-.40,.65),(.26,.05,.235),MATS[0],seg=28,rings=14)
for x in (-.095,-.048,0,.048,.095):box('Rear cooling slot',(x,-.453,.652),(.023,.012,.075),MATS[6],bevel=.009)
for x in (-.22,.22):sphere('Rear indicator',(x,-.395,.825),(.022,.017,.022),MATS[1],seg=12,rings=8)

# Three large guarded egg capsules: two rear, one forward, contrasting translucency.
EGGS=empty('Capsules',parent=HULL)
GLASS=empty('GlassShells',parent=HULL)
for j,(x,y) in enumerate([(-.218,-.07),(.218,-.07),(0,.205)]):
    z=.924
    torus('Capsule plum cradle',(x,y,z),.151,.026,MATS[0],parent=EGGS,majorseg=32)
    cylinder('Capsule socket',(x,y,z-.007),.147,.025,MATS[6],parent=EGGS,verts=28)
    sphere('Mint liquid capsule foot',(x,y,z+.045),(.128,.128,.038),MATS[5],parent=EGGS,seg=24,rings=10)
    egg_profile=[]
    for k in range(23):
        a=math.pi*k/22;t=(1-math.cos(a))/2;zz=.36*t;rr=max(.0005,.158*math.sin(a)*(1-.18*t))
        egg_profile.append((zz,rr))
    lathe('Pale green glass egg '+str(j),(x,y,z),egg_profile,glass,parent=GLASS,n=32)
    # Mint guard ribs hug the egg silhouette and carry bright clean edges.
    for a in (0,math.pi):
        pts=[]
        for k in range(16):
            theta=math.pi*(.03+k*.94/15);t=(1-math.cos(theta))/2;rr=.158*math.sin(theta)*(1-.18*t)+.005;pts.append((x+rr*math.cos(a),y+rr*math.sin(a),z+.36*t))
        arc('Mint protective egg rib',pts,.009,MATS[5],parent=EGGS)
    # Sparse painted specular flashes intentionally echo the concept.
    pts=[]
    for k in range(11):
        theta=math.pi*(.26+k*.025);t=(1-math.cos(theta))/2;rr=.158*math.sin(theta)*(1-.18*t)+.005;a=math.radians(62);pts.append((x+rr*math.cos(a),y+rr*math.sin(a),z+.36*t))
    arc('Capsule soft glint',pts,.0037,MATS[4],parent=EGGS)

LEGS=[]
for s,side in [(-1,'L'),(1,'R')]:
    for i,y in enumerate([.235,-.235]):
        x=s*.274;leg=empty('Leg_'+side+'_'+str(i),(x,y,.365),ROOT);LEGS.append(leg)
        cylinder('Leg hip seal',(x,y,.355),.074,.025,MATS[2],parent=leg)
        sphere('Hip enamel rounded joint',(x,y,.31),(.076,.072,.085),MATS[0],parent=leg,seg=20,rings=12)
        lathe('Tapered plum shin',(x,y,0),[(.072,.044),(.10,.050),(.19,.065),(.26,.074),(.29,.067)],MATS[0],parent=leg,n=16)
        rod('Dark inset leg piston',(x+s*.045,y-.018,.11),(x+s*.046,y-.02,.275),.019,MATS[2],parent=leg)
        sphere('Ground graphite foot',(x,y,.047),(.105,.098,.047),MATS[2],parent=leg,seg=20,rings=10)
        sphere('Steel toe cap',(x,y+.046,.049),(.069,.052,.046),MATS[7],parent=leg,seg=16,rings=8)
        cylinder('Coral hip pin',(x+s*.072,y,.29),.027,.014,MATS[3],parent=leg,axis=(s,0,0),verts=16)
        cylinder('Coral ankle pin',(x+s*.049,y,.10),.018,.012,MATS[3],parent=leg,axis=(s,0,0),verts=12)

ARMS=[]
for s,side in [(-1,'L'),(1,'R')]:
    arm=empty('Arm_'+side,(s*.565,.035,.655),HULL);ARMS.append(arm)
    rod('Manipulator graphite elbow',(s*.565,.035,.655),(s*.59,.112,.548),.032,MATS[2],parent=arm)
    sphere('Manipulator elbow',(s*.59,.112,.548),(.052,.043,.032),MATS[2],parent=arm,seg=16,rings=8)
    # Tapered rounded forearm flare.
    lathe('Plum tapered forearm',(s*.6,.112,0),[(.35,.061),(.364,.075),(.40,.063),(.48,.04),(.54,.029)],MATS[0],parent=arm,n=20)
    cylinder('Claw wrist',(s*.6,.112,.345),.04,.046,MATS[2],parent=arm,axis=(0,1,0),verts=20)
    # Split claw fingers leave an obvious opening between them.
    for q in (-1,1):
        pts=[]
        for j in range(11):
            a=math.radians(25+j*12);pts.append((s*.6+q*.048*math.sin(a),.114,.328+.050*math.cos(a)))
        arc('Curved graphite claw',pts,.012,MATS[2],parent=arm)
    cylinder('Claw silver knuckle',(s*.6,.14,.352),.025,.017,MATS[7],parent=arm,axis=(0,1,0),verts=16)

# Little mechanical delivery hatch below lens, opening from its upper hinge.
HATCH=empty('Hatch',(0,.415,.484),HULL)
box('Hatch recessed opening',(0,.402,.412),(.168,.035,.122),MATS[6],bevel=.024)
box('Delivery hatch lid',(0,.447,.421),(.149,.045,.113),MATS[0],parent=HATCH,bevel=.021)
box('Pistachio hatch pull',(0,.475,.419),(.062,.017,.018),MATS[1],parent=HATCH,bevel=.007)
for x in (-.052,.052):cylinder('Apricot hatch hinge',(x,.439,.48),.012,.029,MATS[3],parent=HATCH,axis=(1,0,0),verts=12)

# Join nonmoving ornament into its rigid carrier; preserve articulated empties.
for name,objs in list(GROUPS.items()):
    if not objs:continue
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();o=bpy.context.object;o.name=name+'_Geometry'
    # Normalize transform to parent-local coordinates without changing geometry.
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)

scene=bpy.context.scene;scene.render.fps=30
REST={o.name:(o.location.copy(),o.rotation_euler.copy()) for o in [HULL,HATCH]+LEGS+ARMS}
def animate(clip,duration):
    frames=int(duration*30);nodes=[HULL,HATCH]+LEGS+ARMS
    for o in nodes:
        o.animation_data_create();action=bpy.data.actions.new(clip+'_'+o.name);o.animation_data.action=action
        for f in range(0,frames+1,3):
            t=f/frames;wave=math.sin(math.tau*t);loc,rot=REST[o.name];o.location=loc;o.rotation_euler=rot
            if o==HULL:
                if clip=='Idle':o.location.z+=.008*(1-math.cos(math.tau*t))
                elif clip=='Walk':o.location.z+=.008*(1-math.cos(math.tau*t*2));o.rotation_euler.y=.018*wave
                elif clip=='Swim':o.location.z+=.02*wave;o.rotation_euler.x=.025*wave
                elif clip=='Attack':o.rotation_euler.x=-.025*math.sin(math.pi*t)**2
            if o in LEGS:
                ix=LEGS.index(o);phase=math.tau*t+(math.pi if ix in (1,2) else 0)
                if clip=='Walk':o.rotation_euler.x=.20*math.sin(phase);o.location.z+=.025*max(0,math.sin(phase))
                elif clip=='Swim':o.rotation_euler.x=.28*math.sin(phase);o.rotation_euler.y=.08*math.cos(phase)
                elif clip=='Attack':o.rotation_euler.x=.055*math.sin(math.pi*t)**2
            if o in ARMS:
                s=-1 if o==ARMS[0] else 1
                if clip=='Idle':o.rotation_euler.y=s*.035*wave
                elif clip=='Walk':o.rotation_euler.x=-.09*wave
                elif clip=='Swim':o.rotation_euler.x=.25*wave;o.rotation_euler.y=s*.10*math.cos(math.tau*t)
                elif clip=='Attack':o.rotation_euler.y=s*-.20*math.sin(math.pi*t)**2
            if o==HATCH and clip=='Attack':o.rotation_euler.x=1.25*math.sin(math.pi*t)**2
            o.keyframe_insert('location',frame=f+1);o.keyframe_insert('rotation_euler',frame=f+1)
        track=o.animation_data.nla_tracks.new();track.name=clip;strip=track.strips.new(clip,1,action);o.animation_data.action=None
        # Only Idle evaluates in the source scene; exporter isolates each NLA track.
        track.mute=clip!='Idle'
        o.location,o.rotation_euler=REST[o.name]
for clip,d in [('Idle',2.4),('Walk',1.2),('Swim',1.6),('Attack',1.2)]:animate(clip,d)
scene.frame_set(1)
for o in [HULL,HATCH]+LEGS+ARMS:o.location,o.rotation_euler=REST[o.name]
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'eco_tender.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'eco_tender.glb'),export_format='GLB',export_yup=True,export_animations=True,export_cameras=False,export_lights=False,export_animation_mode='NLA_TRACKS',export_materials='EXPORT',export_normals=True)
print('EXPORTED',OUT/'eco_tender.glb')
