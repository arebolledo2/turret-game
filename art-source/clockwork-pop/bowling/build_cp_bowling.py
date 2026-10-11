import bpy, bmesh, math, json, hashlib
from mathutils import Vector
from pathlib import Path

OUT = Path(__file__).parent
bpy.ops.wm.read_factory_settings(use_empty=True)

def material(name, color, metallic=0, rough=.3):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metallic; p.inputs['Roughness'].default_value=rough
    return m
teal=material('Turquoise enamel',(.026,.37,.33),.12,.25)
coral=material('Coral enamel',(.80,.12,.070),.1,.27)
gold=material('Warm polished brass',(.92,.62,.23),.50,.23)
cream=material('Ivory brass inlay',(.95,.79,.45),.3,.22)
dark=material('Shadowed return interior',(.009,.026,.028),.1,.42)
ballmat=material('Glossy blue black bowling resin',(.018,.028,.045),.28,.16)
purple=material('Purple glass lens',(.20,.033,.20),.42,.17)
boltmat=material('Copper fasteners',(.53,.12,.058),.65,.2)

def empty(name,pos,parent=None):
    o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o); o.location=pos; o.parent=parent
    return o
aim=empty('Aim',(0,0,0))
empty('Muzzle',(0,1.50,.24),aim)

def finish(o,name,mat,parent=aim,smooth=True):
    o.name=name; o.data.materials.append(mat); o.parent=parent
    if smooth:
        for p in o.data.polygons:p.use_smooth=True
    return o
def bevel(o,width=.03,segments=3):
    bpy.context.view_layer.objects.active=o
    mod=o.modifiers.new('Soft moulded edges','BEVEL');mod.width=width;mod.segments=segments
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=o.modifiers.new('Weighted broad surface normals','WEIGHTED_NORMAL');mod.keep_sharp=True;mod.weight=40
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return o
def cube(name,pos,scale,mat,parent=aim,width=.03):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    finish(o,name,mat,parent);return bevel(o,width)
def sphere(name,pos,r,mat,scale=(1,1,1),segments=32,rings=20):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=r,location=pos)
    o=bpy.context.object;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,mat)
def cyl(name,pos,r,depth,mat,axis=(0,0,1),vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=pos)
    o=bpy.context.object;o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
    finish(o,name,mat);return bevel(o,.014,2)
def mesh(name,verts,faces,mat,parent=aim):
    m=bpy.data.meshes.new(name);m.from_pydata(verts,[],faces);m.update()
    o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o);finish(o,name,mat,parent)
    bm=bmesh.new();bm.from_mesh(m);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(m);bm.free()
    return o
def extrusion(name,profile,y0,y1,mat):
    n=len(profile);vs=[(x,y,z) for y in [y0,y1] for x,z in profile]
    fs=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n)for i in range(n)]
    return mesh(name,vs,fs,mat)
def arch_profile(r,cz,bottom,steps=32):
    return [(r,bottom),(r,cz)]+[(r*math.cos(math.pi*i/steps),cz+r*math.sin(math.pi*i/steps))for i in range(1,steps+1)]+[(-r,bottom)]
outer=arch_profile(.48,.94,.18)
inner=list(reversed(arch_profile(.315,.825,.40)))
shell=extrusion('Rounded turquoise return housing',outer+inner,-.53,.28,teal)
shell.data.materials.append(dark)
# Inner curved channel stays dark, giving depth behind the glossy ball.
n=len(outer+inner)
for p in shell.data.polygons:
    if p.index>=2+len(outer) and p.index<2+n-1:p.material_index=1
bevel(shell,.036,3)
back=extrusion('Housing rear cover',outer,-.61,-.52,teal);bevel(back,.036,3)
base=cube('Static coral rounded plinth',(0,0,.08),(1.09,1.28,.16),coral,parent=None,width=.09)
cheeks=[]
for side in [-1,1]:
    yz=[(.245,.90),(.35,.73),(.505,.60),(.54,.53),(.54,.18),(.245,.18)]
    verts=[(side*.395+dx,y,z) for dx in [-.081,.081] for y,z in yz]
    n=len(yz);faces=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n)for i in range(n)]
    cheek=mesh('Swept front opening cheek',verts,faces,teal);bevel(cheek,.036,3);cheeks.append(cheek)

# Ball finger holes are boolean drill bores, not painted dots.
ball=sphere('LoadedBall',(0,.30,.795),.292,ballmat,segments=40,rings=24)
ball.data.materials.append(dark)
for i,v in enumerate([(-.25,.78,.57),(.28,.77,.55),(.07,.65,.76)]):
    normal=Vector(v).normalized();pos=ball.location+normal*.278
    bpy.ops.mesh.primitive_cylinder_add(vertices=20,radius=.045 if i<2 else .039,depth=.16,location=pos)
    cutter=bpy.context.object;cutter.rotation_euler=normal.to_track_quat('Z','Y').to_euler()
    cutter.data.materials.append(ballmat);cutter.data.materials.append(dark)
    for p in cutter.data.polygons:p.material_index=1
    bpy.context.view_layer.objects.active=ball;mod=ball.modifiers.new('Drilled finger bore '+str(i),'BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter
    bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
bevel(ball,.0025,2)

# One uninterrupted inclined brass lane, with coral rail bodies and brass running edges.
start=Vector((0,.25,.50));end=Vector((0,1.50,.175));direction=end-start
length=direction.length;angle=math.atan2(direction.z,direction.y);mid=(start+end)/2
lane=cube('Continuous brass ramp',mid,(.59,length,.042),gold,width=.015);lane.rotation_euler.x=angle
def rail(name,x,zoff,w,h,mat):
    center=mid+Vector((x,0,zoff));o=cube(name,center,(w,length+.025,h),mat,width=.025);o.rotation_euler.x=angle;return o
coralrails=[rail('Coral ramp rail',x,.040,.073,.095,coral)for x in [-.329,.329]]
goldrails=[rail('Brass running edge',x,.088,.052,.018,gold)for x in [-.329,.329]]
toe=cube('Ivory ramp nose',(0,1.501,.169),(.58,.027,.044),cream,width=.011)

coralbadge=[];goldbadge=[];lenses=[];details=[];fasteners=[]
for side in [-1,1]:
    ax=(side,0,0)
    coralbadge.append(cyl('Coral circular escutcheon',(side*.495,-.13,.66),.205,.055,coral,ax,28))
    goldbadge.append(cyl('Ivory brass circular inset',(side*.529,-.13,.66),.162,.042,cream,ax,28))
    coralbadge.append(cyl('Coral lens rim',(side*.554,-.13,.66),.119,.025,coral,ax,28))
    lenses.append(sphere('Purple optical dome',(side*.577,-.13,.66),.099,purple,scale=(.32,1,1),segments=20,rings=12))
    details.append(sphere('Brass push button',(side*.495,-.39,.34),.043,cream,scale=(.4,1,1),segments=16,rings=10))
    details.append(cube('Turquoise side latch',(side*.492,-.05,1.12),(.044,.12,.08),teal,width=.022))
    fasteners.append(sphere('Lower purple rivet',(side*.489,.11,.27),.025,purple,scale=(.35,1,1),segments=12,rings=8))
    for y in [.47,1.40]:
        z=.50+(y-.25)/1.25*(-.325)+.022
        fasteners.append(sphere('Ramp copper bolt',(side*.369,y,z),.017,boltmat,scale=(.36,1,1),segments=8,rings=6))

rear=cube('Rear return access hatch',(0,-.622,.63),(.50,.021,.57),dark,width=.055)
reartrim=[]
for x in [-.21,.21]:
    for z in [.40,.86]:reartrim.append(cyl('Rear hatch brass screws',(x,-.64,z),.014,.018,gold,(0,-1,0),12))

def join(objects,name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=bpy.context.object;o.name=name
    return o
join([shell,back]+cheeks,'Housing')
join(coralrails,'Ramp coral rails');join(goldrails+[toe],'Ramp brass edges')
join(coralbadge,'Coral side lens surrounds');join(goldbadge,'Ivory brass side insets')
join(lenses,'Purple side lenses');join(details,'Side controls');join(fasteners+reartrim,'Decorative fasteners')

bpy.context.scene.unit_settings.system='METRIC'
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.context.scene.objects:
    if o.type=='MESH':o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.select_set(False)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_bowling.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_bowling.glb'),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
print('Exported',OUT/'cp_bowling.glb')
