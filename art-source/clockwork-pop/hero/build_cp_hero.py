"""Pip the Lantern Keeper: deterministic, articulated chibi biped, +Y forward."""
import bpy,bmesh,math,json
import numpy as np
from pathlib import Path
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
OUT=Path(__file__).resolve().parent;TAU=math.tau
palette=[(.14,.74,.68),(.24,.33,.40),(.98,.70,.22),(.027,.07,.12),(.98,.35,.25),(.99,.90,.70),(.14,.88,.73),(.45,.16,.72)]
rough=[.24,.36,.25,.25,.28,.29,.13,.16];metal=[.10,.34,.76,0,.1,.02,.02,.2]
N=1024;rng=np.random.default_rng(37931);yy,xx=np.mgrid[0:256,0:512];u=xx/512;v=yy/256
noise=rng.normal(0,1,(256,512));wave=np.sin(u*TAU*31)*.28+np.sin(v*TAU*43)*.18
arrays=[np.zeros((N,N,4),dtype=np.float32) for _ in range(4)]
for i,c in enumerate(palette):
    sy=slice((i//2)*256,(i//2+1)*256);sx=slice((i%2)*512,(i%2+1)*512)
    col=np.array(c)[None,None,:]*(1+noise[:,:,None]*.003+wave[:,:,None]*.006)
    if i==2:col*=1+(np.sin(v*TAU*121)+noise*.4)[:,:,None]*.007
    arrays[0][sy,sx,:3]=np.clip(col,0,1);arrays[1][sy,sx,0]=1;arrays[1][sy,sx,1]=rough[i]+noise*.003+wave*.008;arrays[1][sy,sx,2]=metal[i]
    arrays[2][sy,sx,:3]=(.5,.5,1);arrays[2][sy,sx,0]+=noise*.0008;arrays[2][sy,sx,1]+=wave*.0008
    if i==6:arrays[3][sy,sx,:3]=np.array(c)*.10
# Split the amethyst tile: purple optics left, dedicated orange-amber eyes right.
arrays[0][768:1024,768:1024,:3]=np.array((.99,.51,.065))[None,None,:]*(1+noise[:,:256,None]*.003)
arrays[1][768:1024,768:1024,1]=.22;arrays[1][768:1024,768:1024,2]=0
for a in arrays:a[:,:,3]=1
images=[]
for name,arr,cs in zip(['pip_albedo','pip_orm','pip_normal','lantern_emission'],arrays,['sRGB','Non-Color','Non-Color','sRGB']):
    im=bpy.data.images.new(name,width=N,height=N,alpha=True);im.colorspace_settings.name=cs;im.pixels.foreach_set(arr.ravel());im.update();im.filepath_raw=str(OUT/(name+'.png'));im.file_format='PNG';im.save();im.pack();images.append(im)
mats=[]
for i,name in enumerate(['Turquoise helmet enamel','Slate articulated joints','Warm brushed brass','Midnight visor','Coral backpack enamel','Ivory ceramic armor','Cyan lantern glass','Amethyst ear jewels']):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*palette[i],.52 if i==6 else 1);nodes=m.node_tree.nodes;links=m.node_tree.links;p=nodes.get('Principled BSDF')
    for j,socket in[(0,'Base Color'),(3,'Emission Color')]:
        t=nodes.new('ShaderNodeTexImage');t.image=images[j];links.new(t.outputs['Color'],p.inputs[socket])
    t=nodes.new('ShaderNodeTexImage');t.image=images[1];s=nodes.new('ShaderNodeSeparateColor');links.new(t.outputs['Color'],s.inputs['Color']);links.new(s.outputs['Green'],p.inputs['Roughness']);links.new(s.outputs['Blue'],p.inputs['Metallic'])
    t=nodes.new('ShaderNodeTexImage');t.image=images[2];n=nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.15;links.new(t.outputs['Color'],n.inputs['Color']);links.new(n.outputs['Normal'],p.inputs['Normal'])
    p.inputs['Emission Strength'].default_value=1;p.inputs['Coat Weight'].default_value=.4 if i in(0,3,6,7) else .12;p.inputs['Coat Roughness'].default_value=.14
    if i==3:p.inputs['Coat Weight'].default_value=.015;p.inputs['Specular IOR Level'].default_value=.18
    if i==6:p.inputs['Alpha'].default_value=.52;m.surface_render_method='DITHERED';m.use_backface_culling=True
    mats.append(m)
# A ninth material uses the amber sub-tile and emits only on eyes and lantern core.
eyes=mats[2].copy();eyes.name='Amber eyes and lantern flame';p=eyes.node_tree.nodes.get('Principled BSDF');links=eyes.node_tree.links
for socket in['Metallic','Roughness','Emission Color']:
    for link in list(p.inputs[socket].links):links.remove(link)
p.inputs['Metallic'].default_value=0;p.inputs['Roughness'].default_value=.22;p.inputs['Emission Strength'].default_value=.6
t=eyes.node_tree.nodes.new('ShaderNodeTexImage');t.image=images[0];links.new(t.outputs['Color'],p.inputs['Emission Color']);mats.append(eyes)

def empty(name,world,parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=world
    if parent:o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted()
    bpy.context.view_layer.update();return o
root=empty('Pip_Lantern_Keeper',(0,0,0))
body=empty('Body',(0,0,.328),root);head=empty('Head',(0,0,.668),body)
armL=empty('Arm_L',(.179,0,.594),body);armR=empty('Arm_R',(-.179,0,.594),body)
legL=empty('Leg_L',(.082,0,.323),root);legR=empty('Leg_R',(-.082,0,.323),root)
groups={}
def finish(o,name,mi,parent):
    o.name=name;o.data.materials.append(mats[mi]);slot=7 if mi==8 else mi;uv=o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap')
    for p in o.data.polygons:
        axis=max(range(3),key=lambda j:abs(p.normal[j]))
        for li in p.loop_indices:
            co=o.data.vertices[o.data.loops[li].vertex_index].co;a,b=((co.y,co.z) if axis==0 else(co.x,co.z) if axis==1 else(co.x,co.y))
            uv.data[li].uv=((slot%2)*.5+.02+(a/2+.5)*.46,(slot//2)*.25+.01+(b/2+.5)*.23)
            if mi in(7,8):uv.data[li].uv.x=.5+(uv.data[li].uv.x-.5)*.5+(.25 if mi==8 else 0)
    o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted();groups.setdefault(parent.name,[]).append(o);return o
def soft(o,w=.015,seg=3):
    mod=o.modifiers.new('Soft armor edges','BEVEL');mod.width=w;mod.segments=seg;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    for p in o.data.polygons:p.use_smooth=True
    mod=o.modifiers.new('Weighted rounded normals','WEIGHTED_NORMAL');mod.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=mod.name)
def box(name,pos,size,mi,parent,w=.025,seg=4):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);soft(o,w,seg);return finish(o,name,mi,parent)
def rounded_panel(name,pos,width,height,depth,radius,mi,parent):
    points=[]
    for cx,cz,start in[(width/2-radius,height/2-radius,0),(-width/2+radius,height/2-radius,90),(-width/2+radius,-height/2+radius,180),(width/2-radius,-height/2+radius,270)]:
        for j in range(9):
            a=math.radians(start+90*j/8);points.append((cx+radius*math.cos(a),cz+radius*math.sin(a)))
    n=len(points);verts=[(x,y,z) for y in[-depth/2,depth/2] for x,z in points];faces=[tuple(range(n)),tuple(reversed(range(n,2*n)))]
    for j in range(n):faces.append((j,j+n,(j+1)%n+n,(j+1)%n))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(mesh);bm.free()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.location=pos;soft(o,min(.007,depth*.3),3);return finish(o,name,mi,parent)
def lathe(name,pos,profile,mi,parent,axis='Z',segments=32,inner=None):
    vec=Vector((1,0,0) if axis=='X' else(0,1,0) if axis=='Y' else(0,0,1));rot=vec.to_track_quat('Z','Y').to_matrix();verts=[];faces=[]
    for r,z in profile:
        for j in range(segments):verts.append(rot@Vector((r*math.cos(TAU*j/segments),r*math.sin(TAU*j/segments),z)))
    for k in range(len(profile)-1):
        for j in range(segments):faces.append((k*segments+j,k*segments+(j+1)%segments,(k+1)*segments+(j+1)%segments,(k+1)*segments+j))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.location=pos
    for p in mesh.polygons:
        k=p.index//segments;p.use_smooth=profile[k][0]>0 and profile[k+1][0]>0
    finish(o,name,mi,parent)
    if inner is not None:
        mesh.materials.append(mats[3]);uv=mesh.uv_layers.active
        for p in mesh.polygons:
            if p.index//segments>=inner:
                p.material_index=1
                for li in p.loop_indices:uv.data[li].uv=(.53+(uv.data[li].uv.x%.5)*.8,.26+(uv.data[li].uv.y%.25)*.8)
    return o
def cyl(name,pos,r,d,mi,parent,axis='Z',segments=24):
    segments=min(segments,10 if r<.014 else 16 if r<.03 else 28);b=min(.006,d*.2,r*.15)
    return lathe(name,pos,[(0,-d/2),(r-b,-d/2),(r,-d/2+b),(r,d/2-b),(r-b,d/2),(0,d/2)],mi,parent,axis,segments)
def sphere(name,pos,r,mi,parent,scale=(1,1,1),segments=None):
    n=segments or(32 if r>.15 else 24 if r>.065 else 16 if r>.025 else 12)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=n,ring_count=max(6,n//2),radius=r,location=pos);o=bpy.context.object;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for p in o.data.polygons:p.use_smooth=True
    return finish(o,name,mi,parent)
def strut(name,a,b,r,mi,parent):
    a,b=Vector(a),Vector(b);o=cyl(name,(a+b)/2,r,(a-b).length,mi,parent);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def torus(name,pos,major,minor,mi,parent,axis='Z',segments=32,tube=8):
    bpy.ops.mesh.primitive_torus_add(major_radius=major,minor_radius=minor,major_segments=segments,minor_segments=tube,location=pos);o=bpy.context.object;o.rotation_euler=Vector((1,0,0) if axis=='X' else(0,1,0) if axis=='Y' else(0,0,1)).to_track_quat('Z','Y').to_euler();bpy.ops.object.transform_apply(location=False,rotation=True,scale=False)
    for p in o.data.polygons:p.use_smooth=True
    return finish(o,name,mi,parent)

# Ivory rounded torso and coral backpack ride on the waist pivot.
sphere('Ivory rounded torso',(0,0,.473),.165,5,body,scale=(.96,.77,1.04))
box('Coral backpack',(0,-.159,.486),(.295,.121,.285),4,body,w=.027,seg=5)
box('Backpack raised door',(0,-.227,.486),(.246,.025,.22),4,body,w=.02)
for x in[-.103,.103]:box('Backpack brass strap',(x,-.244,.486),(.012,.008,.18),2,body,w=.004,seg=2)
cyl('Backpack winding key',(.159,-.152,.49),.023,.026,2,body,'X',segments=20)
strut('Winding key pin',(.163,-.15,.49),(.194,-.15,.49),.006,2,body)
cyl('Waist swivel rim',(0,0,.331),.096,.029,3,body)
cyl('Dark neck joint',(0,0,.645),.074,.042,3,body)
cyl('Upper neck collar',(0,0,.674),.077,.025,2,head)

# Big friendly teal helmet and inset face. Every detail travels with Head.
box('Rounded teal helmet',(0,0,.913),(.502,.369,.447),0,head,w=.14,seg=8)
rounded_panel('Visor dark border',(0,.177,.913),.379,.324,.037,.065,3,head)
rounded_panel('Glossy midnight visor',(0,.202,.913),.347,.29,.028,.057,3,head)
for x in[-.075,.075]:
    sphere('Amber oval eye',(x,.224,.922),.033,8,head,scale=(1,.24,1.52))
    sphere('Warm eye glint',(x-.009,.233,.947),.007,5,head,scale=(1,.12,1))
for sx in[-1,1]:
    cyl('Brass ear bezel',(sx*.254,0,.923),.078,.041,2,head,'X',segments=28)
    sphere('Purple ear lens',(sx*.279,0,.923),.056,7,head,scale=(.34,1,1))
    sphere('Ear lens glint',(sx*.299,.013,.943),.007,5,head,scale=(.1,1,1))

# Hanging lantern: cage, cyan glass, warm contained flame, no baked animation.
lanY=.166
lathe('Lantern gold lower bowl',(0,lanY,.386),[(0,-.018),(.041,-.018),(.058,-.008),(.063,.01),(.056,.02),(0,.02)],2,body,segments=28)
lathe('Lantern crown',(0,lanY,.545),[(0,-.012),(.062,-.012),(.068,-.003),(.05,.008),(.032,.022),(0,.023)],2,body,segments=28)
sphere('Lantern flame',(0,lanY,.461),.039,8,body,scale=(.88,.7,1.12))
sphere('Lantern cyan glass',(0,lanY,.461),.064,6,body,scale=(.83,.72,1.2))
for sx in[-1,1]:
    for sy in[-1,1]:strut('Lantern brass cage',(sx*.046,lanY+sy*.026,.396),(sx*.052,lanY+sy*.026,.534),.0045,2,body)
torus('Lantern lifting handle',(0,lanY,.575),.013,.003,2,body,'Y',segments=20,tube=6)
sphere('Lantern corner jewel',(.039,lanY+.039,.405),.012,0,body)

# Utility arm hangs down. Weapon arm holds forward at identity shoulder rest.
for side,rig,sx in[('L',armL,1),('R',armR,-1)]:
    sphere('Dark shoulder joint',(sx*.174,0,.586),.048,3,rig)
    sphere('Gold shoulder pauldron',(sx*.199,.0,.604),.063,2,rig,scale=(.92,1,.8))
    cyl('Shoulder armor rivet',(sx*.242,.017,.601),.009,.009,2,rig,'X',segments=12)
strut('Utility upper arm',(.181,0,.565),(.224,.025,.46),.032,1,armL)
box('Utility ivory cuff',(.228,.027,.427),(.101,.09,.125),5,armL,w=.025)
cyl('Cuff brass button',(.279,.04,.427),.014,.007,2,armL,'X',segments=16)
box('Utility glove palm',(.228,.04,.358),(.074,.077,.066),1,armL,w=.02)
for x in[.207,.229,.251]:sphere('Utility rounded finger',(x,.069,.333),.016,1,armL,scale=(.62,.8,1.2))
sphere('Utility glove thumb',(.18,.063,.365),.019,1,armL,scale=(.6,.8,1.25))

strut('Weapon upper arm',(-.179,0,.564),(-.238,.085,.51),.034,1,armR)
sphere('Weapon ivory cuff',(-.253,.137,.51),.055,5,armR,scale=(1,.83,1))
box('Weapon gloved hand',(-.266,.202,.52),(.079,.074,.074),1,armR,w=.019)
for z in[.507,.526,.545]:box('Pistol gripping finger',(-.28,.239,z),(.04,.029,.016),1,armR,w=.006,seg=2)

# Compact forward gold pistol, with a true hollow mouth and precise marker.
gunX=-.267;gunY=.337;gunZ=.609
box('Pistol gold grip',(gunX,.215,.53),(.044,.048,.13),2,armR,w=.009)
box('Pistol grip inset',(gunX,.241,.525),(.032,.013,.072),3,armR,w=.008)
lathe('Hollow gold pistol',(gunX,gunY,gunZ),[(0,-.111),(.032,-.111),(.039,-.1),(.04,-.086),(.035,-.079),(.035,.083),(.042,.087),(.044,.105),(.039,.115),(.027,.115),(.024,.104),(.024,.035),(0,.035)],2,armR,'Y',28,inner=9)
cyl('Pistol breech knob',(gunX,.216,gunZ),.018,.024,2,armR,'Y',segments=16)
cyl('Pistol side dial',(gunX-.042,.283,gunZ),.016,.014,2,armR,'X',segments=16)
box('Pistol front sight',(gunX,.414,.653),(.013,.012,.02),2,armR,w=.004,seg=2)
torus('Pistol trigger guard',(gunX,.267,.556),.021,.005,2,armR,'X',segments=20,tube=6)

# Planted legs are siblings of Body; they never inherit torso yaw.
for rig,sx in[(legL,1),(legR,-1)]:
    sphere('Slate hip joint',(sx*.082,0,.323),.049,1,rig)
    cyl('Gold hip rim',(sx*.12,0,.318),.049,.025,2,rig,'X',segments=20)
    cyl('Slate thigh',(sx*.088,0,.226),.041,.153,1,rig,segments=20)
    o=cyl('Round gold boot shaft',(sx*.091,.011,.111),.062,.18,2,rig,segments=28);o.scale=(1,1.16,1)
    o=cyl('Boot rounded dark sole',(sx*.091,.04,.012),.067,.024,3,rig,segments=28);o.scale=(1,1.66,1)
    sphere('Round brass boot toe',(sx*.091,.07,.054),.059,2,rig,scale=(1,1.24,.64))
    cyl('Boot side button',(sx*.157,.002,.103),.012,.008,3,rig,'X',segments=12)

muzzle=empty('Muzzle',(gunX,gunY+.115,gunZ),armR);muzzle.empty_display_type='ARROWS';muzzle.empty_display_size=.06
# Merge only within a rigid pivot, retaining material regions and UVs.
for o in list(bpy.context.scene.objects):
    if o.type=='MESH':
        bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
for name,objs in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();o=objs[0];o.name=name+'_rigid_geometry'
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=bm.verts,dist=.000001);bm.to_mesh(o.data);bm.free();o.data.update()
    dec=o.modifiers.new('Compact rigid geometry','DECIMATE');dec.ratio=.86 if name=='Head' else .64;bpy.ops.object.modifier_apply(modifier=dec.name)
bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.update();bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_hero.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_hero.glb'),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
for o in bpy.context.scene.objects:
    if o.type=='MESH':o.data.calc_loop_triangles()
stats={'triangles':sum(len(o.data.loop_triangles) for o in bpy.context.scene.objects if o.type=='MESH'),'mesh_objects':sum(o.type=='MESH' for o in bpy.context.scene.objects),'materials':len(mats),'textures':len(images),'animation_clips':0}
(OUT/'build_stats.json').write_text(json.dumps(stats,indent=2));print('FINAL BUILD',stats)
