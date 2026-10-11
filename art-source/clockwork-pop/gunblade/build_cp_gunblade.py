"""Original clockwork gun-saber, built in metres, Blender +Y forward."""
import bpy, bmesh, math, json
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).parent
bpy.ops.wm.read_factory_settings(use_empty=True)

def mat(name, rgb, metal=0, rough=.36, emission=0):
    m = bpy.data.materials.new(name); m.diffuse_color=(*rgb,1); m.use_nodes=True
    s=m.node_tree.nodes.get('Principled BSDF')
    s.inputs['Base Color'].default_value=(*rgb,1)
    s.inputs['Metallic'].default_value=metal; s.inputs['Roughness'].default_value=rough
    if emission:
        s.inputs['Emission Color'].default_value=(*rgb,1); s.inputs['Emission Strength'].default_value=emission
    return m

teal=mat('Turquoise enamel',(.016,.35,.30),.28,.28)
deep=mat('Deep teal recesses',(.015,.12,.14),.35,.38)
coral=mat('Coral enamel',(.95,.15,.075),.2,.31)
ivory=mat('Ivory ceramic blade',(.93,.82,.58),.13,.27)
white=mat('Honed warm silver',(.91,.94,.87),.67,.2)
gold=mat('Satin brass',(.83,.49,.08),.67,.27)
dark=mat('Ink steel',(.025,.028,.059),.55,.31)
violet=mat('Violet optics',(.29,.035,.8),.18,.21,.18)
mint=mat('Mint glass inlay',(.13,.83,.7),.32,.24,.09)

def empty(name,pos,parent=None):
    o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o)
    o.parent=parent; o.location=pos; return o

def finish(o,name,m,parent=None):
    o.name=name; o.data.materials.append(m)
    if parent:
        o.parent=parent; o.matrix_parent_inverse=parent.matrix_world.inverted()
    return o

def bevel(o,w=.02,n=2):
    bpy.context.view_layer.objects.active=o
    mod=o.modifiers.new('Soft machined edges','BEVEL'); mod.width=w; mod.segments=n
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bm=bmesh.new(); bm.from_mesh(o.data)
    for f in bm.faces: f.smooth=True
    for e in bm.edges:
        if len(e.link_faces)==2 and e.calc_face_angle(0)>math.radians(38):e.smooth=False
    bm.to_mesh(o.data); bm.free()
    return o

def box(name,pos,size,m,parent=None,w=.018):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos); o=bpy.context.object; o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bevel(o,min(w,min(size)*.25),1 if min(size)<.07 else 2); return finish(o,name,m,parent)

def cyl(name,pos,r,d,m,parent=None,axis='Z',verts=24,w=.008):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=d,location=pos)
    o=bpy.context.object; bevel(o,min(w,d*.2,r*.2),1)
    if axis=='Y':o.rotation_euler[0]=math.pi/2
    if axis=='X':o.rotation_euler[1]=math.pi/2
    return finish(o,name,m,parent)

def orb(name,pos,r,m,parent=None,scale=(1,1,1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=r,location=pos)
    o=bpy.context.object; o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for p in o.data.polygons:p.use_smooth=True
    return finish(o,name,m,parent)

def rod(name,a,b,r,m,parent=None):
    a,b=Vector(a),Vector(b);o=cyl(name,(a+b)/2,r,(b-a).length,m,parent,verts=16)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o

def tube(name,pos,r,inner,d,m,parent=None,axis='Y',n=24):
    vs=[];fs=[]
    for z,rad in [(-d/2,r),(d/2,r),(d/2,inner),(-d/2,inner)]:
        for i in range(n):
            a=math.tau*i/n;vs.append((rad*math.cos(a),rad*math.sin(a),z))
    for k in range(4):
        for i in range(n):fs.append((k*n+i,k*n+(i+1)%n,((k+1)%4)*n+(i+1)%n,((k+1)%4)*n+i))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],fs);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.location=pos
    # Tube geometry already carries rounded radial surfaces; rim bevel only.
    if d>.04:bevel(o,.003,1)
    if axis=='Y':o.rotation_euler[0]=math.pi/2
    if axis=='X':o.rotation_euler[1]=math.pi/2
    return finish(o,name,m,parent)

def prism(name,outline,thick,m,parent,x=0,bevel_width=.004):
    n=len(outline);vs=[(x+s*thick/2,y,z) for s in (-1,1) for y,z in outline]
    fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    fs += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],fs);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(mesh);bm.free()
    if bevel_width:bevel(o,bevel_width,2)
    return finish(o,name,m,parent)

# Grounded low pedestal. Broad layered porcelain/enamel and four clear brass fasteners.
cyl('Foot shadow skirt',(0,0,.047),.4,.094,deep,verts=48)
cyl('Enamel foundation',(0,0,.105),.392,.12,teal,verts=48,w=.022)
cyl('Brass foot seam',(0,0,.17),.355,.026,gold,verts=48)
bpy.ops.mesh.primitive_cone_add(vertices=48,radius1=.355,radius2=.257,depth=.13,location=(0,0,.235))
finish(bevel(bpy.context.object,.012),'Sloping ivory shoulder',ivory)
cyl('Coral yaw bearing',(0,0,.325),.248,.095,coral,verts=40,w=.015)
cyl('Bearing ink gap',(0,0,.385),.212,.03,dark,verts=40)
cyl('Brass axle',(0,0,.472),.114,.175,gold,verts=24)
for i in range(4):
    a=math.tau*(i+.125)/4
    cyl('Foot anchor',(.29*math.cos(a),.29*math.sin(a),.187),.035,.02,gold,verts=12)
    box('Anchor slot',(.29*math.cos(a),.29*math.sin(a),.199),(.036,.007,.004),dark,w=.001)

Aim=empty('Aim',(0,0,.565));bpy.context.view_layer.update()
# Rounded yaw pod, rear-biased elbow and bright side actuator eyes.
box('Yaw saddle',(0,-.07,.665),(.43,.42,.22),teal,Aim,w=.045)
cyl('Yaw base flange',(0,0,.55),.165,.054,teal,Aim,verts=32)
for s in (-1,1):
    cyl('Coral shoulder joint',(s*.237,-.07,.7),.142,.064,coral,Aim,'X',28,w=.012)
    cyl('Brass shoulder bezel',(s*.278,-.07,.7),.105,.025,gold,Aim,'X',28)
    orb('Violet shoulder optic',(s*.297,-.07,.7),.085,violet,Aim,scale=(.23,1,1))
    orb('Optic catchlight',(s*.317,-.096,.736),.015,mint,Aim,scale=(.25,1,1))
# Articulated arm rises behind the weapon; it ends at rear handle alone.
rod('Elbow brass core',(0,-.18,.725),(0,-.43,.94),.072,gold,Aim)
arm=box('Ivory forearm',(0,-.31,.82),(.17,.17,.29),ivory,Aim,w=.033)
arm.rotation_euler[0]=math.radians(44)
cyl('Wrist dark hinge',(0,-.445,.99),.09,.235,dark,Aim,'X',24)
for s in (-1,1):
    cyl('Wrist brass cap',(s*.125,-.445,.99),.068,.028,gold,Aim,'X',20)

# Grip + hand. Handle axis Y; every finger closes on the dark handle behind the guard.
cyl('Pommel cap',(0,-.697,1.045),.088,.065,gold,Aim,'Y',24)
cyl('Rear handle',(0,-.39,1.045),.061,.56,dark,Aim,'Y',24)
for y in (-.6,-.535,-.28,-.215):
    tube('Grip brass binding',(0,y,1.045),.065,.058,.011,gold,Aim,n=20)
box('Hand palm',(0,-.422,1.11),(.2,.225,.092),ivory,Aim,w=.022)
for y in (-.49,-.42,-.35):
    for s in (-1,1):
        box('Ivory curved finger',(s*.078,y,1.04),(.064,.057,.139),ivory,Aim,w=.014)
    box('Finger underside',(0,y,.981),(.155,.057,.042),ivory,Aim,w=.013)
box('Ivory thumb',(.13,-.437,1.092),(.065,.115,.063),ivory,Aim,w=.018)

# Brass saber guard separates hand from fully unsupported cutting assembly.
guard=[(-.105,.887),(-.115,1.24),(-.035,1.35),(.034,1.35),(.08,1.225),(.06,.894),(.015,.846),(-.06,.85)]
prism('Swept brass guard',guard,.31,gold,Aim,bevel_width=.017)
box('Blade root dark ferrule',(0,.075,1.064),(.19,.13,.23),dark,Aim,w=.016)

# Broad original curved ivory saber, sculpted belly and upward beak. Tip extends far beyond gun exit.
outline=[(.10,1.145),(.36,1.135),(.68,1.125),(.96,1.14),(1.23,1.18),(1.49,1.257),(1.68,1.33),
         (1.56,1.123),(1.34,.977),(1.07,.883),(.8,.848),(.49,.858),(.22,.921),(.10,.993)]
prism('Curved ivory saber',outline,.086,ivory,Aim,bevel_width=.007)
# Mint inset taper follows curve and exposes generous ivory perimeter; bilateral construction.
inlay=[(.20,1.09),(.47,1.079),(.76,1.071),(1.035,1.098),(1.28,1.145),(1.51,1.235),
       (1.40,1.091),(1.21,.99),(.985,.93),(.76,.918),(.50,.933),(.25,.986)]
for s in (-1,1):
    prism('Blade mint fuller',inlay,.005,mint,Aim,x=s*.045,bevel_width=.002)
    # Narrow warm silver sharpened edge follows lower belly rather than rectangular strip.
    edge=[(.18,.981),(.29,.945),(.51,.886),(.8,.875),(1.08,.908),(1.34,1.00),(1.54,1.14),(1.68,1.33),
          (1.56,1.123),(1.34,.977),(1.07,.883),(.8,.848),(.49,.858),(.22,.921),(.10,.993)]
    prism('Honed edge',edge,.003,white,Aim,x=s*.046,bevel_width=0)

# Substantial gun mechanism perched ABOVE the blade, unified at root with brass backbone.
box('Brass receiver bed',(0,.35,1.166),(.25,.60,.063),gold,Aim,w=.015)
box('Gun receiver shell',(0,.352,1.302),(.345,.568,.241),teal,Aim,w=.039)
box('Receiver rear ivory plate',(0,.075,1.3),(.35,.052,.191),ivory,Aim,w=.016)
box('Coral ammo bridge',(0,.297,1.44),(.22,.18,.035),coral,Aim,w=.011)
box('Receiver sight recess',(0,.515,1.438),(.083,.11,.017),dark,Aim,w=.005)
box('Brass front sight',(0,.547,1.46),(.047,.038,.043),gold,Aim,w=.007)
# Chunky right ammo drum + left inspection eye.
cyl('Coral ammo chamber',(.221,.267,1.30),.141,.123,coral,Aim,'X',32,w=.014)
cyl('Chamber brass inset',(.292,.267,1.30),.102,.022,gold,Aim,'X',28)
cyl('Chamber teal endcap',(.308,.267,1.30),.071,.017,teal,Aim,'X',24)
for i in range(6):
    a=math.tau*i/6
    cyl('Ammo rotary rivet',(.31,.267+.114*math.cos(a),1.30+.114*math.sin(a)),.014,.012,gold,Aim,'X',12,w=.002)
cyl('Sight brass port',(-.185,.333,1.313),.081,.026,gold,Aim,'X',28)
orb('Receiver violet lens',(-.205,.333,1.313),.068,violet,Aim,scale=(.22,1,1))
orb('Receiver catchlight',(-.223,.311,1.343),.011,mint,Aim,scale=(.3,1,1))
for s in (-1,1):
    for y in (.443,.497,.551):box('Receiver side vent',(s*.174,y,1.314),(.005,.025,.076),deep,Aim,w=.002)
# Open brass barrel: genuine bore, dark liner, sunk breech stop. Muzzle marker sits at exit.
cyl('Barrel dark coupling',(0,.662,1.30),.127,.096,dark,Aim,'Y',28)
tube('Brass barrel',(0,.844,1.30),.105,.074,.345,gold,Aim)
for y in (.729,.821,.913):tube('Barrel turned rib',(0,y,1.30),.115,.099,.027,gold,Aim,n=28)
tube('Muzzle ivory collar',(0,1.031,1.30),.116,.076,.071,ivory,Aim)
tube('Dark muzzle liner',(0,1.034,1.30),.075,.059,.067,dark,Aim)
cyl('Bore distant shadow',(0,.92,1.30),.059,.004,dark,Aim,'Y',24,w=.001)
# Give rear a meaningful mechanical finish, oversized readable screws and enamel panels.
box('Rear pod coral badge',(0,-.29,.675),(.203,.015,.098),coral,Aim,w=.008)
for s in (-1,1):
    cyl('Guard root screw',(s*.164,-.007,1.192),.025,.012,dark,Aim,'X',16,w=.003)
    cyl('Receiver corner screw',(s*.174,.151,1.344),.025,.012,gold,Aim,'X',16,w=.003)

bpy.context.view_layer.update()
Muzzle=empty('Muzzle',(0,1.069,1.30),None)
Muzzle.parent=Aim;Muzzle.matrix_parent_inverse=Aim.matrix_world.inverted()
BladeTip=empty('BladeTip',(0,1.68,1.33),None)
BladeTip.parent=Aim;BladeTip.matrix_parent_inverse=Aim.matrix_world.inverted()

# Combine rigid material islands to keep draw surfaces predictable. Every moving island remains under Aim.
groups={}
for o in list(bpy.context.scene.objects):
    if o.type=='MESH':groups.setdefault((o.parent.name if o.parent else 'Static',o.data.materials[0].name),[]).append(o)
for (owner,material),objects in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
    objects[0].name=owner+' - '+material

# Bake transforms to give the engine and validator tight bounds for the merged rigid islands.
# Parent-inverse removal also leaves the Aim hierarchy simple and explicit.
for o in list(bpy.context.scene.objects):
    if o.type=='MESH':
        mw=o.matrix_world.copy()
        for v in o.data.vertices:
            p=mw@v.co
            if o.parent:p.y*=.96
            v.co=p
        o.location=(0,0,0);o.rotation_euler=(0,0,0);o.scale=(1,1,1)
        if o.parent:
            o.matrix_parent_inverse=o.parent.matrix_world.inverted()
for marker in (Muzzle,BladeTip):marker.location.y*=.96

bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_gunblade.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_gunblade.glb'),export_format='GLB',export_yup=True,
    export_animations=False,export_cameras=False,export_lights=False)
