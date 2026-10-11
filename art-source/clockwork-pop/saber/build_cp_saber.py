"""Prism Saber. Metres, Z up, +Y forward; no external resources."""
from pathlib import Path
import math
import bpy
import bmesh
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
OUT = Path(__file__).resolve().parent

def material(name, color, metallic=0, rough=.32, glow=0):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metallic
    p.inputs['Roughness'].default_value=rough
    if glow:
        p.inputs['Emission Color'].default_value=(*color,1)
        p.inputs['Emission Strength'].default_value=glow
    return m

teal=material('Ocean teal enamel',(.0015,.165,.138),.12,.36)
edge=material('Turquoise bevel accents',(.005,.285,.235),.10,.36)
coral=material('Warm coral bearings',(.94,.17,.065),.10,.32)
gold=material('Satin brass',(.80,.37,.018),.55,.29)
ivory=material('Warm ivory ceramic',(.86,.78,.56),.13,.31)
dark=material('Midnight grip and gaskets',(.025,.022,.07),.3,.32)
violet=material('Violet polished motor glass',(.21,.006,.73),.15,.21,.18)
magenta=material('Pink axle jewel',(.63,.018,.26),.3,.19,.4)
mint=material('Mint prism heart',(.001,.70,.45),0,.80,2.0)
glow=material('Luminous blade edges',(.54,1,.86),.04,.25,2.3)

groups={}
def finish(o,name,mat,group):
    o.name=name; o.data.materials.append(mat)
    for p in o.data.polygons:p.use_smooth=True
    # Keep broad planes flat; smooth only round corners.
    bm=bmesh.new();bm.from_mesh(o.data)
    for e in bm.edges:
        if len(e.link_faces)==2 and e.calc_face_angle(0)>math.radians(40):e.smooth=False
    bm.to_mesh(o.data);bm.free()
    groups.setdefault(group,[]).append(o)
    return o
def bevel(o,w,segments=3):
    m=o.modifiers.new('Soft machined edges','BEVEL');m.width=w;m.segments=segments
    m.limit_method='ANGLE'
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=m.name)
    return o
def box(name,pos,size,mat,group,w=.02,segments=3):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bevel(o,w,segments);return finish(o,name,mat,group)
def cyl(name,pos,r,depth,mat,group,axis='Z',n=32,w=.009):
    bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=depth,location=pos)
    o=bpy.context.object
    if axis=='X':o.rotation_euler[1]=math.pi/2
    if axis=='Y':o.rotation_euler[0]=math.pi/2
    bevel(o,min(w,r*.3,depth*.2),2)
    return finish(o,name,mat,group)
def sphere(name,pos,scale,mat,group):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=10,radius=1,location=pos)
    o=bpy.context.object;o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,mat,group)
def lathe(name,profile,mat,group,n=48):
    verts=[];faces=[]
    for r,z in profile:
        verts.extend((r*math.cos(i*math.tau/n),r*math.sin(i*math.tau/n),z) for i in range(n))
    for j in range(len(profile)-1):
        for i in range(n):
            a=j*n+i;b=j*n+(i+1)%n;faces.append((a,b,b+n,a+n))
    faces.append(tuple(reversed(range(n))))
    faces.append(tuple((len(profile)-1)*n+i for i in range(n)))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
    return finish(o,name,mat,group)

# True yaw origin sits over a stout static pedestal.
aim=bpy.data.objects.new('Aim',None);bpy.context.collection.objects.link(aim)
aim.location=(0,0,1.015);aim.empty_display_type='PLAIN_AXES';aim.empty_display_size=.10
lathe('Pedestal enamel',[(.305,.012),(.318,.025),(.318,.084),(.311,.098),(.285,.104),(.262,.145),(.244,.169),(.221,.182),(.075,.182)],teal,'Pedestal')
lathe('Pedestal highlight rim',[(.304,.095),(.309,.102),(.300,.111),(.274,.120)],edge,'Pedestal_Trim')
cyl('Brass column foot',(0,0,.194),.092,.040,gold,'Static_Brass',w=.008)
cyl('Brass sweep column',(0,0,.590),.054,.774,gold,'Static_Brass',n=32,w=.007)
cyl('Yaw lower bearing',(0,0,.990),.124,.065,dark,'Yaw_Bearing',w=.01)
cyl('Yaw upper seat',(0,0,1.023),.115,.040,teal,'Head_Shell',w=.008)

# A generous rounded square shoulder motor with capped side and front bearings.
box('Rounded motor shell',(0,-.10,1.235),(.51,.50,.435),teal,'Head_Shell',.082,5)
box('Motor upper facet',(0,-.115,1.427),(.335,.335,.018),edge,'Head_Trim',.025,3)
cyl('Coral top inspection button',(-.018,-.10,1.47),.069,.040,coral,'Coral_Bearings',n=32,w=.009)
# Forward violet lens and its deep gasket; side gold actuator drives ceramic arm.
cyl('Front lens gasket',(0,.156,1.235),.153,.032,dark,'Gaskets',axis='Y')
cyl('Forward coral bezel',(0,.192,1.235),.150,.080,coral,'Coral_Bearings',axis='Y',n=32,w=.011)
cyl('Optic inner rim',(0,.237,1.235),.122,.011,gold,'Gold_Actuator',axis='Y',w=.003)
sphere('Purple convex optic',(0,.245,1.235),(.112,.035,.112),violet,'Optics')
sphere('Lens reflection',(-.048,.272,1.283),(.014,.005,.025),mint,'Optics')
cyl('Far side coral flange',(.268,-.10,1.235),.156,.048,coral,'Coral_Bearings',axis='X')
cyl('Far side teal cap',(.307,-.10,1.235),.132,.051,teal,'Head_Shell',axis='X')
cyl('Hand side coral flange',(-.269,-.10,1.235),.164,.061,coral,'Coral_Bearings',axis='X',w=.010)
cyl('Actuator brass barrel',(-.348,-.10,1.235),.102,.154,gold,'Gold_Actuator',axis='X',n=32,w=.009)
cyl('Actuator socket',(-.430,-.10,1.235),.070,.012,dark,'Gaskets',axis='X',w=.003)
sphere('Pink actuator lens',(-.441,-.10,1.235),(.014,.047,.047),magenta,'Optics')

# Ceramic linkage and three curled fingers all attach to the hilt, never the blade.
arm=box('Ceramic forearm',(-.348,-.105,.996),(.154,.156,.315),ivory,'Ceramic_Arm',.030,3)
arm.rotation_euler[0]=math.radians(-9)
cyl('Wrist dark isolator',(-.348,-.126,.845),.079,.029,dark,'Gaskets',w=.005)
box('Ceramic grip palm',(-.340,-.292,.818),(.225,.265,.157),ivory,'Ceramic_Hand',.034,4)
# Grip axis is Y. Fingers run down its visible outer face and curl under the hilt.
for j,y in enumerate([-.388,-.303,-.218]):
    f=box('Finger %d outer'%j,(-.436,y,.738),(.066,.065,.124),ivory,'Ceramic_Hand',.019,3)
    f.rotation_euler[1]=math.radians(-12)
    f=box('Finger %d curl'%j,(-.385,y,.690),(.102,.062,.058),ivory,'Ceramic_Hand',.017,3)
    f.rotation_euler[1]=math.radians(-9)
box('Opposing thumb',(-.260,-.401,.754),(.063,.105,.101),ivory,'Ceramic_Hand',.023,3)

sx=-.340;sz=.750
cyl('Dark sword hilt',(sx,-.340,sz),.050,.562,dark,'Sword_Grip',axis='Y',n=32,w=.009)
cyl('Rear brass pommel',(sx,-.636,sz),.080,.060,gold,'Sword_Guard',axis='Y',n=32,w=.01)
cyl('Pommel black inset',(sx,-.672,sz),.051,.009,dark,'Sword_Grip',axis='Y',n=24,w=.002)
cyl('Front hilt ferrule',(sx,-.086,sz),.059,.049,gold,'Sword_Guard',axis='Y',n=32,w=.007)
# Oval guard, tall in Z, cast with rounded edges.
guard=cyl('Oval brass crossguard',(sx,-.028,sz),.142,.047,gold,'Sword_Guard',axis='Y',n=32,w=.013)
guard.scale=(.76,1,1.12)
cyl('Brass blade collar',(sx,.024,sz),.078,.078,gold,'Sword_Guard',axis='Y',n=6,w=.009)

# Prism blade: watertight diamond section. Twin luminous bevels frame a saturated mint centre.
# Width narrows through a chiselled shoulder to the pointed tip; no stretched cylinder.
rows=[(.065,.067),(.105,.079),(.775,.066),(.855,.045)]
verts=[]
for y,w in rows:
    verts.extend([(sx-.008,y,sz+w),(sx-.022,y,sz+w*.69),(sx-.025,y,sz),
                  (sx-.022,y,sz-w*.69),(sx-.008,y,sz-w),
                  (sx+.008,y,sz-w),(sx+.022,y,sz-w*.69),(sx+.025,y,sz),
                  (sx+.022,y,sz+w*.69),(sx+.008,y,sz+w)])
faces=[];indices=[]
for j in range(len(rows)-1):
    for i in range(10):
        faces.append((j*10+i,j*10+(i+1)%10,(j+1)*10+(i+1)%10,(j+1)*10+i))
        indices.append(0 if i in (1,2,6,7) else 1)
tip=len(verts);verts.append((sx,.925,sz))
for i in range(10):
    faces.append(((len(rows)-1)*10+i,(len(rows)-1)*10+(i+1)%10,tip))
    indices.append(0 if i in (1,2,6,7) else 1)
faces.append(tuple(reversed(range(10))));indices.append(0)
mesh=bpy.data.meshes.new('Prismatic sword mesh');mesh.from_pydata(verts,[],faces);mesh.update()
blade=bpy.data.objects.new('Mint luminous prism blade',mesh);bpy.context.collection.objects.link(blade)
bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
mesh.materials.append(mint);mesh.materials.append(glow)
for p,i in zip(mesh.polygons,indices):p.material_index=i
groups['Prism_Blade']=[blade]

# Join decorative pieces by functional group to keep draw/node overhead controlled.
static={'Pedestal','Pedestal_Trim','Static_Brass'}
for name,objects in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    if len(objects)>1:bpy.ops.object.join()
    o=bpy.context.object;o.name=name
    if name not in static:
        world=o.matrix_world.copy();o.parent=aim;o.matrix_world=world
    # Weighted normals preserve broad clean product surfaces through glTF export.
    if name!='Prism_Blade':
        normal=o.modifiers.new('Face weighted finish','WEIGHTED_NORMAL');normal.keep_sharp=True;normal.weight=35
        bpy.context.view_layer.objects.active=o
        try:bpy.ops.object.modifier_apply(modifier=normal.name)
        except RuntimeError:pass
muzzle=bpy.data.objects.new('Muzzle',None);bpy.context.collection.objects.link(muzzle)
muzzle.parent=aim;muzzle.location=(sx,.925,sz-aim.location.z)
muzzle.empty_display_type='ARROWS';muzzle.empty_display_size=.07
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_saber.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_saber.glb'),export_format='GLB',export_yup=True,
    export_animations=False,export_cameras=False,export_lights=False)
