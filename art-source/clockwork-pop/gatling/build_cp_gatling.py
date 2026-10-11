import bpy, bmesh, math, json
from pathlib import Path
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
OUT=Path(__file__).parent

def mat(name,hexcol,metal=0,rough=.32):
    c=tuple(int(hexcol[i:i+2],16)/255 for i in (0,2,4))
    c=tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c)
    m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    return m
teal=mat('Turquoise enamel','159D9E',.12)
teal_dark=mat('Deep teal recess','177478',.08)
coral=mat('Coral enamel','F97864',.06)
gold=mat('Honey brass','EFBD50',.58,.31)
gold_dark=mat('Brass recessed seams','A67836',.58,.34)
lavender=mat('Lavender barrel enamel','9069CE',.12)
mint=mat('Mint ceramic collars','92DFCE',.08)
ivory=mat('Warm ivory fasteners','FFF0BD',.10)
dark=mat('Charcoal bore and drive','343042',.35,.36)

def empty(name,loc,parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.parent=parent;o.location=loc;return o
Aim=empty('Aim',(0,0,.74));Rotor=empty('Rotor',(0,.18,.33),Aim)
Muzzle=empty('Muzzle',(0,.98,.524),Aim)
# All build helper coordinates are world coordinates; preserving parent transforms is explicit.
groups={}
def finish(o,name,m,parent=None,group=None):
    o.name=name;o.data.materials.append(m)
    for p in o.data.polygons:p.use_smooth=True
    if parent:
        o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted()
    if group:groups.setdefault((group,parent),[]).append(o)
    return o

def mesh(name,verts,faces,m,parent=None,group=None):
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o)
    return finish(o,name,m,parent,group)

def lathe(name,c,profile,m,parent=None,group=None,n=32,axis='Y',caps=False):
    verts=[];faces=[]
    for a,r in profile:
        for j in range(n):
            t=math.tau*j/n
            if axis=='Y':verts.append((c[0]+r*math.cos(t),c[1]+a,c[2]+r*math.sin(t)))
            elif axis=='Z':verts.append((c[0]+r*math.cos(t),c[1]+r*math.sin(t),c[2]+a))
            else:verts.append((c[0]+a,c[1]+r*math.cos(t),c[2]+r*math.sin(t)))
    for k in range(len(profile)-1):
        for j in range(n):
            q=(j+1)%n;faces.append((k*n+j,(k+1)*n+j,(k+1)*n+q,k*n+q))
    if caps:faces.extend([tuple(range(n-1,-1,-1)),tuple((len(profile)-1)*n+j for j in range(n))])
    o=mesh(name,verts,faces,m,parent,group)
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(o.data);bm.free();return o

def cylinder(name,c,r,d,m,parent=None,group=None,axis='Z',n=32):
    b=min(.015,r*.16,d*.22)
    return lathe(name,c,[(-d/2,r-b),(-d/2+b,r),(d/2-b,r),(d/2,r-b)],m,parent,group,n,axis,True)

def box(name,c,size,m,parent=None,group=None,bev=.035):
    bpy.ops.mesh.primitive_cube_add(size=1,location=c);o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    mod=o.modifiers.new('Soft machined corners','BEVEL');mod.width=bev;mod.segments=2 if name not in ('Belt teeth','Drive belt') else 1
    bpy.ops.object.modifier_apply(modifier=mod.name)
    # Weighted face normals avoid balloon-like planar surfaces.
    mod=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');mod.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(o,name,m,parent,group)

def sphere(name,c,size,m,parent=None,group=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=1,location=c);o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,m,parent,group)

bpy.context.view_layer.update()
# Stacked broad circular foot with softly rounded enamel shoulder.
lathe('Brass foot',(0,0,0),[(.012,.42),(.025,.46),(.085,.46),(.105,.447)],gold,group='Static brass',axis='Z',caps=True,n=48)
lathe('Foot enamel',(0,0,0),[(.09,.42),(.13,.433),(.18,.41),(.215,.33)],teal,group='Static enamel',axis='Z',caps=True,n=48)
cylinder('Upper pedestal flange',(0,0,.222),.31,.064,gold,group='Static brass',n=40)
box('Pedestal',(0,-.008,.4425),(.33,.33,.455),teal,group='Static enamel',bev=.055)
box('Pedestal coral front stripe',(0,.163,.439),(.105,.03,.392),coral,group='Static coral',bev=.019)
cylinder('Yaw bearing',(0,0,.661),.20,.055,dark,group='Static drive',n=32)
cylinder('Yaw brass race',(0,0,.747),.22,.045,gold,Aim,'Head brass',n=32)
# Receiver: broad capsule, visible teal lip ahead of shell.
lathe('Capsule receiver',(0,0,1.07),[(-.55,.29),(-.535,.331),(-.495,.358),(.095,.358),(.145,.344),(.17,.32)],teal,Aim,'Receiver',n=48,caps=True)
# Rear clean gold band has an inset dark seam and a teal central hatch.
lathe('Rear brass band',(0,0,1.07),[(-.582,.29),(-.573,.36),(-.555,.378),(-.493,.378),(-.48,.36)],gold,Aim,'Head brass',n=48,caps=True)
cylinder('Rear teal cap',(0,-.587,1.07),.272,.016,teal_dark,Aim,'Receiver',axis='Y',n=40)
cylinder('Rear medallion',(0,-.599,1.07),.105,.02,gold,Aim,'Head brass',axis='Y')
cylinder('Rear ivory hub',(0,-.613,1.07),.065,.018,ivory,Aim,'Fasteners',axis='Y',n=24)
# Front bezel, dark recessed drive face.
lathe('Front gold bezel',(0,0,1.07),[(.108,.315),(.13,.374),(.16,.39),(.213,.39),(.237,.365),(.237,.292),(.20,.282)],gold,Aim,'Head brass',n=48)
cylinder('Drive face',(0,.205,1.07),.295,.045,gold_dark,Rotor,'Rotor face',axis='Y',n=40)
# Saddle/coral cover follows the convex receiver instead of floating on top.
box('Teal raised saddle',(0,-.03,1.369),(.405,.30,.146),teal,Aim,'Receiver',bev=.045)
# Curved top cover is a sector of cylinder over its crown.
verts=[];faces=[];angs=[math.radians(52+i*76/10) for i in range(11)]
for y,r in [(-.39,.372),(-.07,.372),(-.07,.43),(-.39,.43)]:
    verts.extend([(r*math.cos(t),y,1.07+r*math.sin(t)) for t in angs])
for row in range(4):
    for j in range(10):faces.append((row*11+j,row*11+j+1,((row+1)%4)*11+j+1,((row+1)%4)*11+j))
faces.extend([tuple([0,11,22,33]),tuple([10,43,32,21])])
cover=mesh('Coral curved cover',verts,faces,coral,Aim,'Coral cover')
mod=cover.modifiers.new('Soft cover corners','BEVEL');mod.width=.012;mod.segments=2
bpy.context.view_layer.objects.active=cover;bpy.ops.object.modifier_apply(modifier=mod.name)
# Six equally spaced barrels, distinct open bores and clean shoulder collars.
for k in range(6):
    t=math.tau*k/6+math.pi/6;x=.194*math.cos(t);z=1.07+.194*math.sin(t)
    cylinder('Drive socket %d'%k,(x,.257,z),.086,.071,dark,Rotor,'Rotor drive',axis='Y',n=24)
    lathe('Mint collar %d'%k,(x,0,z),[(.271,.073),(.28,.096),(.307,.099),(.347,.092),(.358,.079)],mint,Rotor,'Mint collars',n=24,caps=True)
    lathe('Lavender barrel %d'%k,(x,0,z),[(.321,.071),(.345,.075),(.81,.075),(.87,.071),(.87,.052),(.321,.052)],lavender,Rotor,'Lavender barrels',n=24,caps=False)
    # Brass tip with annulus across front and dark inward sleeve.
    o=lathe('Brass muzzle %d'%k,(x,0,z),[(.80,.073),(.812,.087),(.83,.091),(.85,.088),(.85,.079),(.958,.079),(.98,.074),(.98,.057),(.954,.054),(.86,.054)],gold,Rotor,'Brass muzzle rims',n=28)
    o.data.materials.append(dark)
    for p in o.data.polygons:
        if p.index>=7*28:p.material_index=1
    cylinder('Recessed bore darkness %d'%k,(x,.89,z),.055,.008,dark,Rotor,'Rotor drive',axis='Y',n=24)
# Central coral drive spindle in the visible void between barrels.
cylinder('Central rotor spindle',(0,.56,1.07),.047,.61,coral,Rotor,'Rotor spindle',axis='Y',n=24)
cylinder('Spindle nose',(0,.884,1.07),.052,.045,gold,Rotor,'Rotor spindle',axis='Y',n=24)
# Large side winding cap, warm ivory button, small coral latch.
for sign in (-1,1):
    cylinder('Side brass mount',(sign*.355,-.18,1.03),.127,.065,gold,Aim,'Head brass',axis='X')
    cylinder('Side coral gasket',(sign*.397,-.18,1.03),.11,.025,coral,Aim,'Coral cover',axis='X')
    sphere('Side ivory screw',(sign*.418,-.18,1.03),(.024,.071,.071),ivory,Aim,'Fasteners')
    box('Coral rear latch',(sign*.335,-.407,1.13),(.035,.142,.067),coral,Aim,'Coral cover',bev=.017)
    sphere('Rear latch ivory rivet',(sign*.357,-.451,1.13),(.018,.025,.025),ivory,Aim,'Fasteners')
# Rivets and pedestal bolts are actual raised pieces.
for k in range(4):
    a=math.tau*k/4+math.pi/4
    cylinder('Flange screw',(math.cos(a)*.24,math.sin(a)*.24,.266),.022,.018,ivory,group='Static fasteners',n=16)
for x in (-.145,.145):sphere('Saddle rivet',(x,.062,1.445),(.026,.026,.013),ivory,Aim,'Fasteners')
for k in range(6):
    a=math.tau*k/6
    sphere('Face gold stud',(.333*math.cos(a),.241,1.07+.333*math.sin(a)),(.019,.011,.019),ivory,Aim,'Fasteners')
# Compact segmented drive belt running down both sides of pedestal. Side +X is the primary reference side.
for s in (-1,1):
    points=[(s*.362,-.18,1.015),(s*.335,-.175,.9),(s*.291,-.146,.77),(s*.248,-.1,.635),(s*.212,-.075,.562)]
    for j in range(len(points)-1):
        a,b=Vector(points[j]),Vector(points[j+1]);delta=b-a
        o=box('Drive belt',(a+b)/2,(.061,.067,delta.length+.014),dark,Aim,'Drive belts',bev=.012);o.rotation_euler=delta.to_track_quat('Z','Y').to_euler()
        for f in (.15,.52,.85):
            c=a+delta*f;o=box('Belt teeth',c,(.081,.027,.019),lavender,Aim,'Drive belts',bev=.006)
            o.rotation_euler=delta.to_track_quat('Z','Y').to_euler()
    cylinder('Lower belt anchor',(s*.216,-.075,.559),.04,.039,gold,Aim,'Head brass',axis='X',n=20)
# Consolidate rigid geometry by motion and material; independent Rotor remains separate from Aim.
for (name,parent),obs in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:o.select_set(True)
    bpy.context.view_layer.objects.active=obs[0]
    if len(obs)>1:bpy.ops.object.join()
    o=bpy.context.object;o.name=name
Aim.location.z=.68
# Simplify small decorative parts after their silhouette has been reviewed.
for name in ('Fasteners','Static fasteners','Drive belts','Static coral'):
    o=bpy.data.objects.get(name)
    if o:
        bpy.context.view_layer.objects.active=o
        mod=o.modifiers.new('Detail simplification','DECIMATE');mod.ratio=.60
        bpy.ops.object.modifier_apply(modifier=mod.name)
# Parent transforms stay correct and glTF keeps the empty pivots.
bpy.context.view_layer.update()
for o in bpy.context.scene.objects:
    if o.type=='MESH':o.data.calc_loop_triangles()
(OUT/'build_metrics.json').write_text(json.dumps({o.name:len(o.data.loop_triangles) for o in bpy.context.scene.objects if o.type=='MESH'},indent=2))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_gatling.glb'),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
