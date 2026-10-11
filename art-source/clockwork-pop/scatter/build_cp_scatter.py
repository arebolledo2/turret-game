"""Fanmouth Scattergun: rounded enamel receiver and real hollow spread barrels.
Build with Blender 5.2 --background --python this_file.py.
All geometry generated locally; +Y firing direction, metres, +Z up.
"""
from pathlib import Path
import math
import bpy
import bmesh
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
OUT = Path(__file__).resolve().parent


def mat(name, rgb, metal=0, rough=.3):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*rgb, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rough
    return m

teal = mat('Turquoise enamel', (.009,.30,.235), .07,.34)
edge_teal = mat('Turquoise edge caps', (.013,.39,.29), .08,.32)
side_teal = mat('Recessed blue teal panels', (.016,.145,.175), .15,.34)
coral = mat('Coral orange enamel', (.91,.125,.038), .06,.32)
coral_dark = mat('Coral panel edge', (.60,.09,.045), .23,.3)
brass = mat('Warm machined brass', (.81,.46,.055), .57,.27)
brass_edge = mat('Pale brass bevels', (.98,.68,.17), .59,.25)
dark = mat('Graphite joints and bores', (.024,.032,.052), .35,.31)
steel = mat('Polished steel fasteners', (.34,.36,.37), .72,.23)
bore = mat('Deep blue barrel interior', (.013,.018,.041), .18,.36)


def empty(name, loc, parent=None):
    o=bpy.data.objects.new(name, None); bpy.context.collection.objects.link(o)
    o.location=loc; o.parent=parent; o.empty_display_type='PLAIN_AXES'; o.empty_display_size=.10
    return o
Aim=empty('Aim',(0,0,.61))
Muzzle=empty('Muzzle',(0,1.04,.935-.61),Aim)


def finish(o,name,material,parent=None):
    o.name=name; o.data.materials.append(material)
    for p in o.data.polygons: p.use_smooth=True
    bm=bmesh.new(); bm.from_mesh(o.data)
    for e in bm.edges:
        if len(e.link_faces)==2 and e.calc_face_angle(0) > math.radians(40): e.smooth=False
    bm.to_mesh(o.data); bm.free()
    if parent:
        bpy.context.view_layer.update()
        w=o.matrix_world.copy(); o.parent=parent; o.matrix_world=w
    return o


def bevel(o,w=.025,segments=3):
    bpy.context.view_layer.objects.active=o
    mod=o.modifiers.new('Soft machined edges','BEVEL'); mod.width=w; mod.segments=segments
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return o


def box(name,loc,dims,m,parent=None,w=.035):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    o=bpy.context.object; o.scale=dims; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bevel(o,w,3)
    return finish(o,name,m,parent)


def cyl(name,loc,radius,depth,m,parent=None,axis=(0,0,1),vertices=20,w=.008):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=loc)
    o=bpy.context.object
    if w: bevel(o,w,1)
    o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
    return finish(o,name,m,parent)


def sphere(name,loc,r,scale,m,parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10,ring_count=5,radius=r,location=loc)
    o=bpy.context.object; o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,m,parent)


def annular(name,center,axis,profile,mats,parent=None,segments=40):
    # Closed lathed cross section: (distance along barrel, radius, material for next band).
    direction=Vector(axis).normalized(); tangent=Vector((0,0,1)); radial=direction.cross(tangent).normalized()
    verts=[]
    for distance,radius,_ in profile:
        for k in range(segments):
            a=math.tau*k/segments
            verts.append(Vector(center)+direction*distance+radius*(radial*math.cos(a)+tangent*math.sin(a)))
    faces=[]; indices=[]
    for j,(_,_,mi) in enumerate(profile):
        nxt=(j+1)%len(profile)
        for k in range(segments):
            kn=(k+1)%segments
            faces.append((j*segments+k,j*segments+kn,nxt*segments+kn,nxt*segments+k)); indices.append(mi)
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces); mesh.update()
    o=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(o)
    for m in mats:o.data.materials.append(m)
    for p,i in zip(o.data.polygons,indices):p.material_index=i; p.use_smooth=True
    bm=bmesh.new(); bm.from_mesh(mesh); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    for edge in bm.edges:
        if len(edge.link_faces)==2 and edge.calc_face_angle(0) > math.radians(35): edge.smooth=False
    bm.to_mesh(mesh);bm.free()
    if parent:
        w=o.matrix_world.copy();o.parent=parent;o.matrix_world=w
    return o


def join(parts,name,parent=None):
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]; bpy.ops.object.join()
    o=bpy.context.object;o.name=name
    if parent:
        w=o.matrix_world.copy();o.parent=parent;o.matrix_world=w
    return o

# Static bolted floor plate, soft lobe corners, grounded graphite gasket.
base=[box('Base plate',(0,0,.093),(.70,.62,.15),teal,w=.048)]
gaskets=[box('Base underside',(0,0,.026),(.66,.58,.052),dark,w=.028)]
fasteners=[]
for x in (-.32,.32):
    for y in (-.27,.27):
        base.append(cyl('Rounded mounting ear',(x,y,.090),.107,.153,edge_teal,w=.017))
        gaskets.append(cyl('Foot pad',(x,y,.018),.103,.036,dark,w=.007))
        fasteners.append(cyl('Bolt pocket',(x,y,.174),.059,.010,dark,w=.003))
        fasteners.append(sphere('Mounting bolt',(x,y,.182),.043,(1,1,.43),steel))
join(base,'Static floor plate');join(gaskets,'Static rubber foundation');join(fasteners,'Floor anchor fasteners')
shaft=[cyl('Pedestal shaft',(0,0,.365),.174,.40,teal,w=.014),
       cyl('Pedestal foot',(0,0,.205),.210,.06,edge_teal,w=.012),
       cyl('Pedestal lower dark ring',(0,0,.166),.205,.025,dark,w=.004),
       cyl('Pedestal top collar',(0,0,.553),.201,.055,edge_teal,w=.010)]
shaft.append(box('Pedestal polished key',(0,.173,.372),(.069,.017,.29),steel,w=.020))
join(shaft,'Static yaw pedestal')
yaw=[cyl('Yaw bearing',(0,0,.585),.204,.055,dark,Aim,w=.009),
     box('Head saddle',(0,-.082,.635),(.50,.43,.14),dark,Aim,w=.047)]
join(yaw,'Rotating head saddle',Aim)

# Receiver: center slab with separate raised side rails creates the reference's top grooves.
body=box('Broad teal receiver',(0,-.28,.9825),(.77,.82,.665),teal,Aim,w=.045)
roof=box('Receiver center roof panel',(0,-.28,1.329),(.598,.80,.043),teal,Aim,w=.017)
join([body,roof],'Broad teal receiver and roof panel',Aim)
rails=[]
for s in (-1,1):
    rails.append(box('Rounded side armour',(s*.392,-.28,1.0),(.174,.83,.715),edge_teal,Aim,w=.065))
join(rails,'Receiver rounded side rails',Aim)
# Dark blue rectangular inset on either side, with shallow trim all around.
sides=[]
for s in (-1,1):
    sides.append(box('Side inset',(s*.482,-.313,.985),(.018,.618,.506),side_teal,Aim,w=.038))
join(sides,'Receiver side inset panels',Aim)
rear=[box('Rear graphite cap',(0,-.718,1.0),(.745,.09,.555),dark,Aim,w=.038),
      box('Rear teal service panel',(0,-.771,1.015),(.60,.019,.399),side_teal,Aim,w=.037)]
# Three short rear vent slots and two restrained fasteners.
for z in (.94,1.01,1.08):rear.append(box('Rear heat vent',(0,-.785,z),(.30,.009,.018),dark,Aim,w=.008))
for x in (-.244,.244):rear.append(sphere('Rear screw',(x,-.787,1.16),.020,(1,.35,1),steel,Aim))
join(rear,'Rear service cap and vents',Aim)

# Raised front octagonal coral mounting casting.
# Extruded octagonal chamfered rectangle creates the characteristic chopped corners.
coords=[(-.272,-.175),(-.175,-.272),(.175,-.272),(.272,-.175),(.272,.175),(.175,.272),(-.175,.272),(-.272,.175)]
verts=[(x,y,z+.945) for y in (.139,.255) for x,z in coords]
faces=[tuple(range(7,-1,-1)),tuple(range(8,16))]+[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
mesh=bpy.data.meshes.new('Coral casting');mesh.from_pydata(verts,[],faces);mesh.update()
o=bpy.data.objects.new('Coral casting',mesh);bpy.context.collection.objects.link(o);bevel(o,.028,3);finish(o,'Coral front casting',coral,Aim)
front=[]
for x in (-.388,.388):
    for z in (.775,1.25):
        front.append(cyl('Front bolt recess',(x,.148,z),.039,.011,dark,Aim,axis=(0,1,0),vertices=24,w=.003))
        front.append(sphere('Front bolt',(x,.158,z),.025,(1,.36,1),steel,Aim))
for x in (-.252,.252):front.append(sphere('Coral flange rivet',(x,.234,.946),.013,(1,.4,1),brass_edge,Aim))
join(front,'Face recessed fasteners',Aim)

# Separate barrels permit runtime recoil. 4 degree spread remains subtle in silhouette.
for s,label in ((-1,'L'),(1,'R')):
    axis=Vector((s*math.sin(math.radians(4)),math.cos(math.radians(4)),0))
    origin=Vector((s*.153,.211,.935))
    # Cross section is continuous down a deep open bore, including the true muzzle rim.
    p=[(0,.104,0),(.035,.104,0),(.044,.137,1),(.095,.140,1),(.108,.107,0),
       (.111,.099,0),(.316,.099,0),(.329,.108,1),(.354,.108,1),(.368,.099,0),
       (.546,.099,0),(.554,.112,1),(.616,.112,1),(.638,.103,1),(.642,.079,1),
       (.625,.075,0),(.563,.075,2),(.18,.069,2),(.16,.0,2),(0,.0,0)]
    p=[(d*1.27 if d > .108 else d,r,mi) for d,r,mi in p]
    barrel=annular('Barrel_'+label,origin,axis,p,[brass,brass_edge,bore],Aim,32)
    # At its base a coral raised shoulder reinforces the mounting plate.
    socket=cyl('Barrel socket '+label,origin,.128,.065,coral_dark,Aim,axis=axis,vertices=24,w=.012)
    part=join([barrel,socket],'Barrel_'+label,Aim)
    bpy.context.scene.cursor.location=origin
    bpy.context.view_layer.objects.active=part
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    part['recoil_axis_parent_space']=[float(v) for v in axis]
    part['spread_degrees']=s*4


# Rounded side port: coral rotary collar, brass rim and genuinely inset bore.
ports=[]
for s in (-1,1):
    ports.append(cyl('Coral side port',(s*.497,-.257,1.012),.128,.068,coral,Aim,axis=(s,0,0),vertices=24,w=.020))
    ports.append(annular('Brass side socket',(s*.535,-.257,1.012),(s,0,0),[(0,.091,0),(.018,.094,0),(.035,.086,0),(.035,.056,0),(.027,.048,1),(.006,.048,1),(0,.05,0)],[brass_edge,brass],Aim,24))
    ports.append(cyl('Port shadow',(s*.543,-.257,1.012),.045,.006,coral_dark,Aim,axis=(s,0,0),vertices=24,w=0))
# Pedestal-side hinge resembles the smaller brass circular reference detail.
for s in (-1,1):
    ports.append(cyl('Head hinge dark hub',(s*.266,-.043,.649),.073,.040,dark,Aim,axis=(s,0,0),vertices=24,w=.006))
    ports.append(cyl('Head hinge gold cap',(s*.289,-.043,.649),.059,.026,brass_edge,Aim,axis=(s,0,0),vertices=24,w=.010))
join(ports,'Head side ports and hinges',Aim)

bpy.context.view_layer.update()
for o in bpy.context.scene.objects:
    if o.type=='MESH':
        o.data.calc_loop_triangles(); print('MESH_COUNT',o.name,len(o.data.loop_triangles))
# Source retained for inspection and editing; no lights or cameras exported.
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_scatter.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_scatter.glb'),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
print('EXPORTED',OUT/'cp_scatter.glb')
