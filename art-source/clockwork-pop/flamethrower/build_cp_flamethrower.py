"""Clockwork flamethrower: rounded enamel burner, open brass guard, coral fuel tank.
Procedural geometry only; Blender +Y is weapon forward, +Z up.
"""
from pathlib import Path
import math
import bpy
import bmesh
from mathutils import Vector

OUT = Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)

def linear(h):
    v = [int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(x/12.92 if x <= .04045 else ((x+.055)/1.055)**2.4 for x in v)

def mat(name, color, metallic=0, roughness=.3):
    m = bpy.data.materials.new(name); m.use_nodes=True
    m.diffuse_color=(*linear(color),1)
    s=m.node_tree.nodes.get('Principled BSDF')
    s.inputs['Base Color'].default_value=m.diffuse_color
    s.inputs['Metallic'].default_value=metallic
    s.inputs['Roughness'].default_value=roughness
    s.inputs['Coat Weight'].default_value=.28 if metallic < .5 else .08
    return m

TEAL=mat('Turquoise enamel','009D8F',.0,.30)
CORAL=mat('Coral enamel','FF4B38',.02,.29)
BRASS=mat('Satin brass','F1B820',.35,.25)
GOLD=mat('Brass edge highlights','FFD94F',.4,.23)
RUBBER=mat('Graphite fuel hose','39354C',.05,.4)
BORE=mat('Heat darkened brass bore','573122',.45,.4)
DARK=mat('Dark combustion chamber','19182B',.0,.65)
IVORY=mat('Ivory ceramic','FFF1C7',.02,.28)
BLUE=mat('Blue glass dial','48A4DC',.18,.16)
PINK=mat('Ruby switch','D42B83',.15,.18)
AMBER=mat('Amber switch','FF922B',.1,.2)

def empty(name,pos=(0,0,0),parent=None):
    o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o)
    o.parent=parent; o.location=pos; return o

Aim=empty('Aim')
Muzzle=empty('Muzzle',(0,.847,.89),Aim)

def finish(o,name,m,parent=Aim):
    o.name=name; o.data.materials.clear(); o.data.materials.append(m); o.parent=parent
    for p in o.data.polygons:p.use_smooth=True
    return o

def bevel(o,w=.03,n=3):
    b=o.modifiers.new('Rounded edges','BEVEL'); b.width=w;b.segments=n
    bpy.context.view_layer.objects.active=o
    bpy.ops.object.modifier_apply(modifier=b.name)
    # Weighted normals leave the broad enamel faces beautifully flat.
    nrm=o.modifiers.new('Face normals','WEIGHTED_NORMAL');nrm.keep_sharp=True;nrm.weight=50
    bpy.ops.object.modifier_apply(modifier=nrm.name)
    return o

def box(name,pos,size,m,parent=Aim,r=.06):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bevel(o,min(r,min(size)*.45),3)
    return finish(o,name,m,parent)

def cyl(name,pos,r,d,m,parent=Aim,axis=(0,0,1),vertices=24,b=.015):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=d,location=pos)
    o=bpy.context.object
    if b:bevel(o,min(b,d*.3,r*.2),2 if r>.11 else 1)
    o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
    return finish(o,name,m,parent)

def sphere(name,pos,r,m,scale=(1,1,1),parent=Aim):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=10,radius=r,location=pos)
    o=bpy.context.object;o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,m,parent)

def tube(name,points,r,m,parent=Aim):
    c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.resolution_u=10
    c.bevel_depth=r;c.bevel_resolution=2;c.resolution_u=6
    s=c.splines.new('BEZIER');s.bezier_points.add(len(points)-1)
    for p,co in zip(s.bezier_points,points):
        p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
    o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active=o;o.select_set(True)
    bpy.ops.object.convert(target='MESH');o.select_set(False)
    return finish(o,name,m,parent)

def ring_y(name,profile,mats,ycenter,zcenter=.89,n=48,materials=(BRASS,GOLD,BORE)):
    # closed lathed profile (radius, forward y) with explicit flat face material bands
    verts=[];faces=[]
    for rad,y in profile:
        verts.extend((rad*math.cos(t*math.tau/n),ycenter+y,zcenter+rad*math.sin(t*math.tau/n)) for t in range(n))
    for j in range(len(profile)):
        k=(j+1)%len(profile)
        for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,k*n+(i+1)%n,k*n+i))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.parent=Aim
    for m in materials:mesh.materials.append(m)
    for p in mesh.polygons:
        band=p.index//n;p.material_index=mats[band];p.use_smooth=band in (1,3,5,7)
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(mesh);bm.free()
    return o

# Broad low pedestal and four squat splayed toes are static.
box('Static platform',(0,0,.17),(.66,.62,.18),TEAL,parent=None,r=.07)
box('Static riser',(0,0,.345),(.43,.38,.29),TEAL,parent=None,r=.065)
for sx in (-1,1):
    for sy in (-1,1):
        foot=cyl('Static toe',(.37*sx,.32*sy,.062),.115,.12,TEAL,parent=None,vertices=32,b=.035)
        leg=box('Static splayed arm',(.295*sx,.25*sy,.17),(.22,.24,.27),TEAL,parent=None,r=.07)
        leg.rotation_euler=(math.radians(21)*sy,math.radians(-21)*sx,0)
cyl('Yaw bearing',(0,0,.5),.22,.065,RUBBER)
box('Rotating neck',(0,0,.57),(.40,.35,.23),TEAL,r=.045)

# Enamel housing, short wide burner stub and true hollow guard.
box('Burner enamel housing',(0,.035,.88),(.64,.51,.54),TEAL,r=.095)
ring_y('Hollow burner tube',[(.246,-.18),(.268,-.15),(.272,.14),(.258,.18),(.211,.18),(.208,.15),(.208,-.18)],
       [0,0,0,0,1,1,1],.367,materials=(TEAL,DARK))
ring_y('Open heat guard',[(.278,-.145),(.309,-.13),(.315,.125),(.31,.145),(.239,.145),(.228,.13),(.227,-.135),(.246,-.145)],
       [0,0,1,1,2,2,2,0],.67)
cyl('Dark bore end',(0,.306,.89),.21,.025,DARK,axis=(0,1,0),b=0)
# Recesses read as drilled guard vents without fragile micro-geometry.
for i in range(10):
    a=(i+.5)*math.tau/10
    x,z=.277*math.cos(a),.89+.277*math.sin(a)
    cyl('Front guard vent',(x,.818,z),.015,.009,BORE,axis=(0,1,0),vertices=12,b=0)
    x,z=.315*math.cos(a),.89+.315*math.sin(a)
    cyl('Guard side vent',(x,.674,z),.019,.014,BORE,axis=(math.cos(a),0,math.sin(a)),vertices=12,b=0)

# Large coral rear tank with genuinely rounded shoulders and three top plugs.
box('Coral fuel reservoir',(0,-.441,1.01),(.67,.43,.91),CORAL,r=.12)
for x in (-.205,.205):
    cyl('Tank top plug',(x,-.441,1.477),.058,.065,CORAL,b=.018,vertices=24)
cyl('Tank cap seal',(0,-.44,1.487),.086,.065,RUBBER)
cyl('Brass filler cap',(0,-.44,1.548),.09,.072,BRASS,b=.013)
cyl('Filler cap lip',(0,-.44,1.587),.081,.018,GOLD,b=.005)
cyl('Tank outlet stem',(-.18,-.44,.507),.058,.09,RUBBER,b=.013)

# Curved hose carried with the tank, broad loops and blunt brass connectors.
tube('U shaped fuel hose',[(-.22,-.52,1.426),(-.43,-.64,1.43),(-.54,-.65,1.31),(-.555,-.65,.72),(-.50,-.62,.526),(-.31,-.55,.49)],.054,RUBBER)
for p,axis in [((-.265,-.56,1.426),(-1,-.3,0)),((-.295,-.55,.49),(-1,-.3,0))]:
    cyl('Hose brass coupling',p,.07,.1,BRASS,axis=axis,b=.009)
    q=Vector(p)+Vector(axis).normalized()*.066
    cyl('Hose graphite collar',q,.076,.038,RUBBER,axis=axis,b=.007)

# Ceramic side inset, with amber push-button on the visible tank side.
box('Ceramic service inset',(-.346,-.442,.98),(.04,.24,.35),IVORY,r=.08)
sphere('Amber inset button',(-.373,-.43,.937),.035,AMBER,scale=(.4,1,1))

# Raised blue pressure lens, brass bezel and a tiny ivory needle.
cyl('Dial gasket',(0,.065,1.177),.117,.029,RUBBER,b=.006)
cyl('Pressure dial bezel',(0,.065,1.207),.133,.056,BRASS,b=.01)
cyl('Dial ivory face',(0,.065,1.237),.096,.012,IVORY,b=.002)
sphere('Pressure blue lens',(0,.065,1.249),.091,BLUE,scale=(1,1,.26))
cyl('Gauge outer lip',(0,.065,1.241),.127,.018,GOLD,b=.004)
# Cut open gold rim centre with boolean cylinder, retaining the lens beneath it.
rim=bpy.context.object
bpy.ops.mesh.primitive_cylinder_add(vertices=40,radius=.097,depth=.15,location=(0,.065,1.24))
cutter=bpy.context.object;mod= rim.modifiers.new('Open bezel','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter
bpy.context.view_layer.objects.active=rim;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
for i in range(4):
    a=(i+.5)*math.tau/4
    cyl('Dial bezel screw',(.112*math.cos(a),.065+.112*math.sin(a),1.253),.008,.004,BORE,vertices=12,b=.001)
needle=box('Pressure needle',(.0,.077,1.272),(.008,.064,.003),IVORY,r=.001)
needle.rotation_euler.z=math.radians(-35)

# Chunky side controls echo the reference's sapphire and ruby buttons.
for name,loc,rad,color in [('Upper blue control',(-.342,.04,.877),.097,BLUE),('Lower ruby control',(-.223,.0,.535),.102,PINK)]:
    cyl(name+' brass mount',loc,rad,.08,BRASS,axis=(-1,0,0),b=.015)
    cyl(name+' rim',Vector(loc)+Vector((-.049,0,0)),rad*.91,.018,GOLD,axis=(-1,0,0),b=.004)
    sphere(name+' centre',Vector(loc)+Vector((-.066,0,0)),rad*.44,color,scale=(.34,1,1))

# Consolidate rigid parts by parent and material family; keep the yaw assembly distinct.
bpy.ops.object.select_all(action='DESELECT')
groups={}
for o in list(bpy.context.scene.objects):
    if o.type=='MESH':
        for i,m in enumerate(o.data.materials):
            if m is None:o.data.materials[i]=BRASS
        key=(o.parent.name if o.parent else 'Static',tuple(m.name for m in o.data.materials))
        groups.setdefault(key,[]).append(o)
for (parent,materials),objects in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    if len(objects)>1:bpy.ops.object.join()
    objects[0].name=parent+'_'+materials[0].replace(' ','_')

bpy.ops.object.select_all(action='DESELECT')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_flamethrower.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_flamethrower.glb'),export_format='GLB',export_yup=True,
                          export_animations=False,export_cameras=False,export_lights=False)
