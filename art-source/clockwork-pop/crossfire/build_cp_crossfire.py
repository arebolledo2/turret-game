"""Clockwork Crossfire: deterministic procedural game asset. Blender +Z up, +Y forward."""
import bpy
import bmesh
import math
import json
from pathlib import Path
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
OUT = Path(__file__).resolve().parent


def material(name, color, metallic=0, rough=.35):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = rough
    return mat

teal = material('Turquoise enamel', (.005,.38,.285), .10, .32)
teal_dark = material('Socket inset teal', (.014,.245,.235), .25, .32)
coral = material('Coral lacquer', (.88,.155,.115), .05, .33)
brass = material('Golden brass', (.88,.49,.065), .55, .30)
brass_light = material('Polished rim brass', (.97,.64,.16), .58, .25)
bore = material('Deep bore', (.037,.022,.035), .25, .53)
plum = material('Dark plum swivel', (.135,.057,.111), .38, .36)
ivory = material('Mint ivory bezel', (.78,.91,.64), .10, .3)
mint = material('Mint crystal', (.055,.72,.445), .03, .25)
mint_light = material('Mint crystal bright facets', (.27,.95,.675), .03, .25)


def empty(name, loc, parent=None, yaw=0):
    ob=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(ob)
    ob.location=loc
    ob.rotation_euler=(0,0,yaw)
    if parent: ob.parent=parent
    return ob

Aim=empty('Aim',(0,0,.96))


def finish(ob,name,mat,parent=None,smooth=True):
    ob.name=name
    if mat: ob.data.materials.append(mat)
    if smooth:
        for p in ob.data.polygons:p.use_smooth=True
    if parent:
        ob.parent=parent
        ob.location-=parent.location
    return ob


def bevel(ob,w=.02,n=3):
    bpy.context.view_layer.objects.active=ob
    mod=ob.modifiers.new('Soft machined edges','BEVEL'); mod.width=w; mod.segments=n
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=ob.modifiers.new('Weighted surface normals','WEIGHTED_NORMAL'); mod.keep_sharp=True; mod.weight=40
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return ob


def cube(name,loc,dims,mat,w=.025,n=3,parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    ob=bpy.context.object; ob.scale=dims
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bevel(ob,w,n)
    return finish(ob,name,mat,parent)


def cylinder(name,loc,r,depth,mat,parent=None,vertices=32,w=.015):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=loc)
    ob=bpy.context.object; bevel(ob,w,3)
    return finish(ob,name,mat,parent)


def sphere(name,loc,r,mat,parent=None,scale=(1,1,1),seg=12,rings=6):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,radius=r,location=loc)
    ob=bpy.context.object; ob.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(ob,name,mat,parent)


def mesh(name,verts,faces,mats,indices=None,parent=None,smooth=False):
    me=bpy.data.meshes.new(name+' mesh'); me.from_pydata(verts,[],faces); me.update()
    ob=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(ob)
    for ma in mats:me.materials.append(ma)
    for i,p in enumerate(me.polygons):
        p.use_smooth=smooth
        if indices:p.material_index=indices[i]
    if parent:ob.parent=parent; ob.location=-parent.location
    return ob


def lathe(name,profile,mats,seg=32,parent=None,direction=(0,0,1),base=(0,0,0)):
    # Profile is (axial distance,radius,material for next segment); closed section gives real hollow tubes.
    d=Vector(direction); q=d.to_track_quat('Z','Y'); origin=Vector(base)
    verts=[]
    for t,r,mi in profile:
        for j in range(seg):
            a=j*math.tau/seg
            verts.append(origin+q@Vector((r*math.cos(a),r*math.sin(a),t)))
    faces=[]; ids=[]
    for k in range(len(profile)-1):
        for j in range(seg):
            j1=(j+1)%seg
            faces.append((k*seg+j,k*seg+j1,(k+1)*seg+j1,(k+1)*seg+j));ids.append(profile[k][2])
    ob=mesh(name,verts,faces,mats,ids,parent,True)
    return ob


def join(parts,name):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in parts:ob.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    bpy.ops.object.join(); parts[0].name=name
    return parts[0]

# Heavy enamel foot with gently rounded edge and turned pedestal.
base = lathe('Base',[(0,.0,0),(0,.335,0),(.012,.37,0),(.045,.385,0),(.096,.385,0),(.124,.367,0),(.137,.335,0),(.137,0,0)], [teal], seg=48)
base_parts=[base,cylinder('Base shoulder',(0,0,.163),.226,.095,teal,w=.025)]
join(base_parts,'Static_Base')
post_parts=[cylinder('Pedestal',(0,0,.395),.157,.425,teal,w=.025),cylinder('Pedestal foot',(0,0,.222),.183,.07,teal,w=.016),cylinder('Yaw bearing',(0,0,.641),.221,.105,plum,w=.021)]
join(post_parts,'Static_Pedestal')
bolts=[]
for i in range(4):
    a=math.pi/4+i*math.pi/2
    bolts.append(cylinder('Foot bolt',(math.cos(a)*.30,math.sin(a)*.30,.152),.037,.035,brass_light,vertices=16,w=.008))
join(bolts,'Static_BaseBolts')

# The clean rounded cube remains the dominant central shape.
head = cube('Head_Enamel',(0,0,.984),(.598,.598,.618),teal,w=.064,n=4,parent=Aim)
face_panels=[]
for i,d in enumerate(((0,1,0),(1,0,0),(0,-1,0),(-1,0,0))):
    center=Vector(d)*.297+Vector((0,0,.984))
    panel=cube('Recessed face panel',center,(.485,.018,.494),teal_dark,w=.022,n=3,parent=Aim)
    panel.rotation_euler.z=i*math.pi/2
    face_panels.append(panel)
join([head]+face_panels,'Head_Enamel')

# Four radial sockets and brass barrels: a continuous tube, an open bore and a substantial machined lip.
for i,d in enumerate(((0,1,0),(1,0,0),(0,-1,0),(-1,0,0))):
    origin=Vector((0,0,1.004))
    prof=[(.285,.106,0),(.285,.143,0),(.299,.162,0),(.316,.170,0),(.378,.170,0),(.393,.159,0),(.402,.137,0),(.402,.106,0),(.285,.106,0)]
    collar=lathe('Socket',prof,[coral],seg=32,parent=Aim,direction=d,base=origin)
    recessed=lathe('Teal socket backing',[(.282,.0,0),(.282,.176,0),(.300,.176,0),(.300,0,0)],[teal_dark],seg=32,parent=Aim,direction=d,base=origin)
    # small raised enamel fastener on top of every coral socket
    screw=sphere('Coral socket fastener',origin+Vector(d)*.351+Vector((0,0,.167)),.0125,teal,parent=Aim,scale=(1,1,.55),seg=12,rings=6)
    join([collar,recessed,screw],f'Collar_{i}')
    # Rounded brass muzzle rim, recessed dark inner wall, no solid cap at the tip.
    prof=[(.370,.097,0),(.407,.103,0),(.870,.103,0),(.900,.109,0),(.902,.136,1),(.914,.144,1),(.995,.144,1),(1.011,.136,1),(1.012,.101,1),(1.002,.093,2),(.923,.091,2),(.537,.080,2),(.537,0,2),(.370,0,0),(.370,.097,0)]
    prof = [(t,r*1.12,mi) for t,r,mi in prof]
    lathe(f'Barrel_{i}',prof,[brass,brass_light,bore],seg=32,parent=Aim,direction=d,base=origin)
    yaw={0:0,1:-math.pi/2,2:math.pi,3:math.pi/2}[i]
    tip=origin+Vector(d)*1.014
    empty('Muzzle' if i==0 else f'Muzzle_{i}',tip-Aim.location,Aim,yaw)

# A rounded square inset and ivory raised frame hold a low, faceted mint window.
def round_square(half,r,n=6):
    pts=[]
    for cx,cy,start in ((half-r,half-r,0),(-half+r,half-r,90),(-half+r,-half+r,180),(half-r,-half+r,270)):
        for k in range(n+1):
            a=math.radians(start+k*90/n)
            pts.append((cx+r*math.cos(a),cy+r*math.sin(a)))
    return pts

outer=round_square(.211,.060); inner=round_square(.171,.05)
verts=[]
for coords,z in ((outer,1.288),(outer,1.305),(inner,1.305),(inner,1.288)):
    verts.extend((x,y,z) for x,y in coords)
n=len(outer);faces=[]
for k in range(3):
    for j in range(n):faces.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
frame=mesh('Mint Ivory Frame',verts,faces,[ivory],parent=Aim); bevel(frame,.006,2)
shadow=cube('Window recess',(0,0,1.285),(.451,.451,.020),teal_dark,w=.060,n=4,parent=Aim)
join([frame,shadow],'Top_WindowFrame')

# Octagonal glass with deliberately broad, readable triangular facets.
ring=[(-.116,-.16),(.116,-.16),(.16,-.116),(.16,.116),(.116,.16),(-.116,.16),(-.16,.116),(-.16,-.116)]
verts=[(x,y,1.299) for x,y in ring]+[(x*.59,y*.59,1.325) for x,y in ring]+[(.008,-.015,1.331)]
faces=[];ids=[]
for j in range(8):
    faces.append((j,(j+1)%8,(j+1)%8+8,j+8));ids.append(1 if j in (0,1,7) else 0)
    faces.append((j+8,(j+1)%8+8,16));ids.append(1 if j in (0,1,6) else 0)
faces.append(tuple(reversed(range(8))));ids.append(0)
mesh('Mint_FacetedWindow',verts,faces,[mint,mint_light],ids,parent=Aim)
fasteners=[]
for x in (-.228,.228):
    for y in (-.228,.228):fasteners.append(sphere('Top screw',(x,y,1.292),.022,teal,parent=Aim,scale=(1,1,.55)))
join(fasteners,'Head_Fasteners')

# Weld profile axis vertices and strip zero-area faces, preserving separate rigid objects.
for ob in [o for o in bpy.context.scene.objects if o.type == 'MESH']:
    bm=bmesh.new(); bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=0.000001)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=0.000001)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(ob.data); bm.free(); ob.data.update()
bpy.context.view_layer.update()
# Save the exact construction scene, without lights/cameras, beside the self-contained export.
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_crossfire.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_crossfire.glb'), export_format='GLB', export_yup=True, export_animations=False, export_cameras=False, export_lights=False)


