"""Tuning-Fork Conductor. Deterministic textured Clockwork Pop asset, +Y forward."""
import bpy,bmesh,math,json
import numpy as np
from pathlib import Path
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
OUT=Path(__file__).resolve().parent;TAU=math.tau
palette=[(.13,.70,.65),(.035,.34,.37),(.95,.70,.23),(.10,.075,.16),(.98,.37,.25),(.99,.89,.65),(.15,.86,.84),(.36,.075,.67)]
rough=[.24,.3,.25,.34,.26,.24,.12,.14];metal=[.12,.12,.78,.5,.12,.02,.12,.2]
N=1024;rng=np.random.default_rng(80431);yy,xx=np.mgrid[0:256,0:512];u=xx/512;v=yy/256
noise=rng.normal(0,1,(256,512));wave=np.sin(u*TAU*31)*.3+np.sin(v*TAU*43)*.2
arrays=[np.zeros((N,N,4),dtype=np.float32) for _ in range(4)]
for i,c in enumerate(palette):
    sy=slice((i//2)*256,(i//2+1)*256);sx=slice((i%2)*512,(i%2+1)*512)
    col=np.array(c)[None,None,:]*(1+noise[:,:,None]*.004+wave[:,:,None]*.008)
    if i==2:col*=1+(np.sin(v*TAU*97)+noise*.4)[:,:,None]*.008
    arrays[0][sy,sx,:3]=np.clip(col,0,1);arrays[1][sy,sx,0]=1;arrays[1][sy,sx,1]=rough[i]+noise*.004+wave*.01;arrays[1][sy,sx,2]=metal[i]
    arrays[2][sy,sx,:3]=(.5,.5,1);arrays[2][sy,sx,0]+=noise*.001;arrays[2][sy,sx,1]+=wave*.001
    if i in(6,7):arrays[3][sy,sx,:3]=np.array(c)*(.25 if i==7 else .07)
for a in arrays:a[:,:,3]=1
images=[]
for name,arr,cs in zip(['conductor_albedo','conductor_orm','conductor_normal','charge_emission'],arrays,['sRGB','Non-Color','Non-Color','sRGB']):
    im=bpy.data.images.new(name,width=N,height=N,alpha=True);im.colorspace_settings.name=cs;im.pixels.foreach_set(arr.ravel());im.update();im.filepath_raw=str(OUT/(name+'.png'));im.file_format='PNG';im.save();im.pack();images.append(im)
mats=[]
for i,name in enumerate(['Turquoise enamel','Deep teal recess','Warm brushed brass','Plum mechanism','Coral enamel','Ivory porcelain','Cyan charge glass','Amethyst charge core']):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*palette[i],.40 if i==6 else 1);nodes=m.node_tree.nodes;links=m.node_tree.links;p=nodes.get('Principled BSDF')
    for j,socket in[(0,'Base Color'),(3,'Emission Color')]:
        t=nodes.new('ShaderNodeTexImage');t.image=images[j];links.new(t.outputs['Color'],p.inputs[socket])
    t=nodes.new('ShaderNodeTexImage');t.image=images[1];s=nodes.new('ShaderNodeSeparateColor');links.new(t.outputs['Color'],s.inputs['Color']);links.new(s.outputs['Green'],p.inputs['Roughness']);links.new(s.outputs['Blue'],p.inputs['Metallic'])
    t=nodes.new('ShaderNodeTexImage');t.image=images[2];n=nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.15;links.new(t.outputs['Color'],n.inputs['Color']);links.new(n.outputs['Normal'],p.inputs['Normal'])
    p.inputs['Emission Strength'].default_value=1;p.inputs['Coat Weight'].default_value=.35 if i in(0,4,6,7) else .1;p.inputs['Coat Roughness'].default_value=.14
    if i==6:p.inputs['Alpha'].default_value=.40;m.surface_render_method='DITHERED';m.use_backface_culling=True
    mats.append(m)
root=bpy.data.objects.new('Tuning_Fork_Conductor',None);bpy.context.collection.objects.link(root)
aim=bpy.data.objects.new('Aim',None);bpy.context.collection.objects.link(aim);aim.parent=root;aim.location=(0,0,.338);bpy.context.view_layer.update()
groups={}
def finish(o,name,mi,parent=aim,group=None):
    o.name=name;o.data.materials.append(mats[mi]);uv=o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap')
    for p in o.data.polygons:
        axis=max(range(3),key=lambda j:abs(p.normal[j]))
        for li in p.loop_indices:
            co=o.data.vertices[o.data.loops[li].vertex_index].co;a,b=((co.y,co.z) if axis==0 else(co.x,co.z) if axis==1 else(co.x,co.y))
            uv.data[li].uv=((mi%2)*.5+.02+(a/2+.5)*.46,(mi//2)*.25+.01+(b/2+.5)*.23)
    o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted();groups.setdefault(group or('upper_'+str(mi) if parent==aim else'base_'+str(mi)),[]).append(o);return o
def soft(o,w=.015,seg=3):
    mod=o.modifiers.new('Soft crafted edges','BEVEL');mod.width=w;mod.segments=seg;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    for p in o.data.polygons:p.use_smooth=True
    mod=o.modifiers.new('Weighted edge normals','WEIGHTED_NORMAL');mod.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=mod.name)
def box(name,pos,size,mi,parent=aim,w=.025,seg=4):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);soft(o,w,seg);return finish(o,name,mi,parent)
def lathe(name,pos,profile,mi,axis='Z',segments=32,parent=aim,group=None):
    vec=Vector((1,0,0) if axis=='X' else(0,1,0) if axis=='Y' else(0,0,1));rot=vec.to_track_quat('Z','Y').to_matrix();verts=[];faces=[]
    for r,z in profile:
        for j in range(segments):verts.append(rot@Vector((r*math.cos(TAU*j/segments),r*math.sin(TAU*j/segments),z)))
    for k in range(len(profile)-1):
        for j in range(segments):faces.append((k*segments+j,k*segments+(j+1)%segments,(k+1)*segments+(j+1)%segments,(k+1)*segments+j))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.location=pos
    for p in mesh.polygons:
        k=p.index//segments;p.use_smooth=profile[k][0]>0 and profile[k+1][0]>0
    return finish(o,name,mi,parent,group)
def cyl(name,pos,r,d,mi,axis='Z',segments=24,parent=aim):
    segments=min(segments,10 if r<.015 else 16 if r<.04 else 28)
    b=min(.006,d*.2,r*.15);return lathe(name,pos,[(0,-d/2),(r-b,-d/2),(r,-d/2+b),(r,d/2-b),(r-b,d/2),(0,d/2)],mi,axis,segments,parent)
def sphere(name,pos,r,mi,scale=(1,1,1),parent=aim):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24 if r>.03 else 12,ring_count=12 if r>.03 else 6,radius=r,location=pos);o=bpy.context.object;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for p in o.data.polygons:p.use_smooth=True
    return finish(o,name,mi,parent)
def tube(name,points,r,mi,parent=aim):
    c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.resolution_u=12;c.bevel_depth=r;c.bevel_resolution=3
    s=c.splines.new('POLY');s.points.add(len(points)-1)
    for p,co in zip(s.points,points):p.co=(*co,1)
    o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');o=bpy.context.object
    for p in o.data.polygons:p.use_smooth=True
    return finish(o,name,mi,parent)

# Fixed rounded square base and brass tower neck.
box('Coral foot',(0,0,.059),(.48,.43,.118),4,parent=root,w=.044,seg=5)
box('Turquoise cushion',(0,0,.151),(.451,.402,.079),0,parent=root,w=.039,seg=5)
cyl('Neck lower brass flange',(0,0,.216),.097,.045,2,parent=root,segments=28)
cyl('Brass neck column',(0,0,.275),.072,.085,2,parent=root,segments=28)
cyl('Fixed dark bearing race',(0,0,.324),.073,.02,3,parent=root,segments=24)
for sx in[-1,1]:
    for sy in[-1,1]:
        cyl('Foot corner brass button',(sx*.202,sy*.202,.055),.026,.025,2,'Y',parent=root,segments=20)
        cyl('Foot corner coral contact',(sx*.202,sy*.219,.055),.022,.008,4,'Y',parent=root,segments=20)

# Lower part of the head is a continuous teal collar on the centered kingpin.
cyl('Yaw collar',(0,0,.374),.093,.079,0,segments=28)
cyl('Rotating shoulder brass trim',(0,0,.419),.085,.018,2,segments=28)

# Continuous rounded U silhouette, extruded in depth. Local origin avoids atlas tile spill.
outline=[]
for j in range(17):
    a=math.pi+math.pi*j/16;outline.append((.22*math.cos(a),.64+.22*math.sin(a)))
outline.append((.22,1.18))
for j in range(1,13):
    a=math.pi*j/12;outline.append((.165+.055*math.cos(a),1.18+.055*math.sin(a)))
outline.append((.11,.82))
for j in range(1,13):
    a=-math.pi*j/12;outline.append((.11*math.cos(a),.82+.11*math.sin(a)))
outline.append((-.11,1.18))
for j in range(1,13):
    a=math.pi*j/12;outline.append((-.165+.055*math.cos(a),1.18+.055*math.sin(a)))
n=len(outline);verts=[(x,y,z-.82) for y in[-.071,.071] for x,z in outline];faces=[]
faces.append(tuple(reversed(range(n))));faces.append(tuple(range(n,2*n)))
for j in range(n):faces.append((j,(j+1)%n,(j+1)%n+n,j+n))
mesh=bpy.data.meshes.new('Continuous fork');mesh.from_pydata(verts,[],faces);mesh.update()
bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(mesh);bm.free()
o=bpy.data.objects.new('Continuous fork',mesh);bpy.context.collection.objects.link(o);o.location=(0,0,.82);soft(o,.018,4);finish(o,'Rounded tuning fork',0,group='Fork_enamel')

# Large solid contact buttons at the upper prong ends, no cavities.
for x in[-.165,.165]:
    for sy in[-1,1]:
        cyl('Upper brass contact bezel',(x,sy*.084,1.167),.038,.025,2,'Y',segments=28)
        cyl('Upper solid copper electrode',(x,sy*.102,1.167),.032,.012,4,'Y',segments=28)

# Twin long forward conducting rods, seated in ivory ceramic collars.
for x in[-.105,.105]:
    cyl('Ceramic rod insulator',(x,.106,.603),.052,.073,5,'Y',segments=28)
    cyl('Insulator brass seat',(x,.079,.603),.04,.026,2,'Y',segments=24)
    cyl('Brass electrode shaft',(x,.35,.603),.022,.426,2,'Y',segments=16)
    cyl('Solid electrode end collar',(x,.567,.603),.025,.019,2,'Y',segments=16)
    cyl('Closed copper electrode contact',(x,.58,.603),.019,.01,4,'Y',segments=16)

# A compact charged jewel between the two solid rods, matching the concept.
sphere('Amethyst charge core',(0,.575,.603),.026,7)
sphere('Cyan charge sphere',(0,.575,.603),.044,6)
sphere('Charge jewel glint',(-.017,.608,.626),.010,5,scale=(1,.18,1))

# Visible copper spring and curved rear electrical lead, all on the upper assembly.
pts=[]
for j in range(81):
    t=j/80;pts.append((-.073+.146*t,-.102+.025*math.sin(TAU*4*t),.776+.025*math.cos(TAU*4*t)))
tube('Brass induction spring',pts,.006,2)
pts=[]
for j in range(25):
    t=j/24;a=math.pi*.05+math.pi*.85*t;pts.append((.036,-.085-.135*math.sin(a),.55+.158*math.cos(a)))
tube('Looped rear power lead',pts,.014,2)
cyl('Rear lead upper socket',(.036,-.082,.706),.024,.025,3,'Y',segments=16)
cyl('Rear lead lower socket',(.036,-.125,.40),.024,.022,3,'Y',segments=16)
box('Fork rear teal mounting inset',(0,-.074,.573),(.255,.015,.184),1,w=.014)
for x in[-.08,.08]:cyl('Rear service rivet',(x,-.089,.577),.008,.007,2,'Y',segments=12)

muzzle=bpy.data.objects.new('Muzzle',None);bpy.context.collection.objects.link(muzzle);muzzle.parent=aim;muzzle.location=(0,.585,.603-.338);muzzle.empty_display_type='ARROWS';muzzle.empty_display_size=.08
for o in list(bpy.context.scene.objects):
    if o.type=='MESH':
        bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
for name,objs in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();o=objs[0];o.name=name
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=bm.verts,dist=.000001);bm.to_mesh(o.data);bm.free();o.data.update()
    dec=o.modifiers.new('Compact grouped geometry','DECIMATE');dec.ratio=.88 if name=='Fork_enamel' else .67;bpy.ops.object.modifier_apply(modifier=dec.name)
bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.update();bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_tesla.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_tesla.glb'),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
for o in bpy.context.scene.objects:
    if o.type=='MESH':o.data.calc_loop_triangles()
stats={'triangles':sum(len(o.data.loop_triangles) for o in bpy.context.scene.objects if o.type=='MESH'),'mesh_objects':sum(o.type=='MESH' for o in bpy.context.scene.objects),'materials':len(mats),'textures':len(images),'animation_clips':0}
(OUT/'build_stats.json').write_text(json.dumps(stats,indent=2));print('FINAL BUILD',stats)
