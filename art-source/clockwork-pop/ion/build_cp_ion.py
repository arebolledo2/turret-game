"""Pepperbox Watchman. Deterministic standalone construction, metres, +Y forward."""
import bpy, bmesh, math, json
import numpy as np
from mathutils import Vector, Matrix
from pathlib import Path

bpy.ops.wm.read_factory_settings(use_empty=True)
OUT=Path(__file__).resolve().parent
TAU=math.tau
palette=[(.15,.65,.62),(.075,.35,.38),(.92,.67,.19),(.11,.085,.16),(.95,.32,.22),(.97,.86,.64),(.045,.68,.61),(.4,.32,.44)]
rough=[.26,.30,.25,.32,.28,.30,.14,.3]
metal=[.18,.2,.78,.58,.15,.02,.36,.65]
rng=np.random.default_rng(7283)
N=1024; h=512
yy,xx=np.mgrid[0:h,0:h]; u=xx/h;v=yy/h
noise=rng.normal(0,1,(h,h)); wave=np.sin(u*TAU*43)*.35+np.sin(v*TAU*57)*.15
arrays=[np.zeros((N,N,4),dtype=np.float32) for _ in range(4)]
for idx,col in enumerate(palette):
    cy,cx=divmod(idx,2); sy=slice(cy*256,(cy+1)*256); sx=slice(cx*512,(cx+1)*512)
    # Four rows, two columns: 512 x 256 texels per material.
    small=noise[:256,:]; w=wave[:256,:]
    base=np.array(col)[None,None,:]*(1+small[:,:,None]*.004+w[:,:,None]*.008)
    if idx==2:
        grain=np.sin(v[:256,:]*TAU*170)+small*.4
        base*=1+grain[:,:,None]*.008
    arrays[0][sy,sx,:3]=np.clip(base,0,1)
    arrays[1][sy,sx,0]=1
    arrays[1][sy,sx,1]=rough[idx]+small*.005+w*.012
    arrays[1][sy,sx,2]=metal[idx]
    arrays[2][sy,sx,:3]=(.5,.5,1)
    arrays[2][sy,sx,0]+=(small*.0015)
    arrays[2][sy,sx,1]+=(w*.002)
    if idx==6: arrays[3][sy,sx,:3]=np.array(col)*.17
for a in arrays:a[:,:,3]=1
images=[]
for name,arr,cs in zip(['finish_albedo','finish_orm','finish_normal','optic_emission'],arrays,['sRGB','Non-Color','Non-Color','sRGB']):
    im=bpy.data.images.new(name,width=N,height=N,alpha=True)
    im.colorspace_settings.name=cs;im.pixels.foreach_set(arr.ravel());im.update()
    im.filepath_raw=str(OUT/(name+'.png'));im.file_format='PNG';im.save();im.pack();images.append(im)
mats=[]
for i,name in enumerate(['Seafoam enamel','Deep teal inset','Brushed warm brass','Plum gunmetal','Coral enamel','Ivory optic','Turquoise jewel','Lilac hardware']):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*palette[i],1)
    nodes=m.node_tree.nodes;links=m.node_tree.links;p=nodes.get('Principled BSDF')
    for j,socket in [(0,'Base Color'),(3,'Emission Color')]:
        t=nodes.new('ShaderNodeTexImage');t.image=images[j];links.new(t.outputs['Color'],p.inputs[socket])
    t=nodes.new('ShaderNodeTexImage');t.image=images[1];sep=nodes.new('ShaderNodeSeparateColor');links.new(t.outputs['Color'],sep.inputs['Color'])
    links.new(sep.outputs['Green'],p.inputs['Roughness']);links.new(sep.outputs['Blue'],p.inputs['Metallic'])
    t=nodes.new('ShaderNodeTexImage');t.image=images[2];n=nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.2;links.new(t.outputs['Color'],n.inputs['Color']);links.new(n.outputs['Normal'],p.inputs['Normal'])
    p.inputs['Emission Strength'].default_value=1
    p.inputs['Coat Weight'].default_value=.32 if i in (0,1,4,6) else .12
    p.inputs['Coat Roughness'].default_value=.16
    mats.append(m)

root=bpy.data.objects.new('Pepperbox_Watchman',None);bpy.context.collection.objects.link(root)
aim=bpy.data.objects.new('Aim',None);bpy.context.collection.objects.link(aim);aim.parent=root;aim.location=(0,0,.43)
bpy.context.view_layer.update()
groups={}
def finish(o,name,mi,parent=aim,group=None):
    o.name=name;o.data.materials.append(mats[mi])
    # Object-space box projection with the same density; restrained tiled finish.
    uv=o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap')
    for p in o.data.polygons:
        axis=max(range(3),key=lambda a:abs(p.normal[a]))
        for li in p.loop_indices:
            co=o.data.vertices[o.data.loops[li].vertex_index].co
            a,b=((co.y,co.z) if axis==0 else (co.x,co.z) if axis==1 else (co.x,co.y))
            uv.data[li].uv=((mi%2)*.5+.015+(a/2+.5)*.47,(mi//2)*.25+.008+(b/2+.5)*.234)
    o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted()
    groups.setdefault(group or ('upper_'+str(mi) if parent==aim else 'base_'+str(mi)),[]).append(o)
    return o
def bevel(o,width=.01,segments=3):
    mod=o.modifiers.new('Soft machined edge','BEVEL');mod.width=width;mod.segments=segments
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    for p in o.data.polygons:p.use_smooth=True
    mod=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL');mod.keep_sharp=True;mod.weight=40
    bpy.ops.object.modifier_apply(modifier=mod.name)
def box(name,pos,size,mi,rounding=.025,parent=aim,group=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);bevel(o,rounding,3)
    return finish(o,name,mi,parent,group)
def lathe(name,pos,profile,mi,axis='Z',segments=40,parent=aim,group=None,inner=None):
    verts=[];faces=[]
    rot=Vector((1,0,0) if axis=='X' else (0,1,0) if axis=='Y' else (0,0,1)).to_track_quat('Z','Y').to_matrix()
    for r,z in profile:
        for j in range(segments):verts.append(rot@Vector((r*math.cos(TAU*j/segments),r*math.sin(TAU*j/segments),z)))
    for k in range(len(profile)-1):
        for j in range(segments):faces.append((k*segments+j,k*segments+(j+1)%segments,(k+1)*segments+(j+1)%segments,(k+1)*segments+j))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.location=pos
    for p in mesh.polygons:p.use_smooth=True
    finish(o,name,mi,parent,group)
    if inner:
        mesh.materials.append(mats[3]); start=inner
        for p in mesh.polygons:
            if p.index//segments>=start:p.material_index=1
        # Dark inner UV atlas region.
        uv=mesh.uv_layers.active
        for p in mesh.polygons:
            if p.material_index:
                for li in p.loop_indices:
                    uv.data[li].uv.x=.515+(uv.data[li].uv.x% .5)*.9
                    uv.data[li].uv.y=.258+(uv.data[li].uv.y%.25)*.9
    return o
def cyl(name,pos,r,d,mi,axis='Z',parent=aim,segments=28,group=None):
    segments=min(segments,8 if r<.012 else 12 if r<.025 else 20 if r<.09 else 32)
    b=min(.008,d*.22,r*.12)
    return lathe(name,pos,[(0,-d/2),(r-b,-d/2),(r,-d/2+b),(r,d/2-b),(r-b,d/2),(0,d/2)],mi,axis,segments,parent,group)
def sphere(name,pos,r,mi,scale=(1,1,1),parent=aim,group=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16 if r>.025 else 10,ring_count=8 if r>.025 else 5,radius=r,location=pos);o=bpy.context.object;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for p in o.data.polygons:p.use_smooth=True
    return finish(o,name,mi,parent,group)

# Pedestal: broad weighted shoe, enamel cushion, tapered column, gold shoulder.
cyl('Golden foot',(0,0,.026),.248,.052,2,parent=root,segments=48)
cyl('Seafoam plinth',(0,0,.072),.222,.052,0,parent=root,segments=48)
cyl('Pedestal lower collar',(0,0,.116),.153,.036,2,parent=root)
lathe('Enamel tapered column',(0,0,0),[(0,.123),(.124,.123),(.119,.148),(.11,.31),(.117,.335),(0,.335)],0,parent=root)
cyl('Pedestal capital',(0,0,.348),.155,.039,2,parent=root)
cyl('Fixed bearing cup',(0,0,.382),.098,.035,3,parent=root)
cyl('Yaw spindle',(0,0,.413),.066,.046,1)
for a in [45,135,225,315]:
    t=math.radians(a);sphere('Foot bolt',(math.cos(t)*.211,math.sin(t)*.211,.097),.017,2,scale=(1,1,.8),parent=root)

# All upper construction rotates together on Aim.
box('Plum mounting saddle',(0,-.012,.462),(.32,.285,.041),3,.009)
box('Main rounded enamel housing',(0,0,.642),(.435,.365,.335),0,.031)
box('Forward barrel mounting panel',(0,.189,.659),(.391,.022,.269),1,.013)
box('Rear service panel',(0,-.190,.643),(.333,.018,.254),1,.016)
box('Top reel pedestal',(0,-.01,.81),(.265,.27,.034),0,.011)

# Two long open pepperbox barrels, collar, lip and deep shaded throat.
for x in [-.112,.112]:
    cyl('Receiver collar',(x,.226,.706),.079,.055,2,'Y')
    profile=[(0,-.152),(.061,-.152),(.065,-.141),(.065,.112),(.072,.119),(.073,.137),(.067,.151),(.049,.151),(.045,.138),(.045,.058),(0,.058)]
    lathe('Hollow brass cannon',(x,.389,.706),profile,2,'Y',40,inner=7)
    cyl('Barrel breech bead',(x,.286,.706),.069,.017,2,'Y')

# Camera reels have a shared horizontal axle but unequal discs in fore/aft YZ plane.
for y,z,r in [(.105,.965,.163),(-.177,1.004,.199)]:
    cyl('Axle',(0,y,z),.039,.146,3,'X',segments=24)
    profile=[(0,-.073),(r-.014,-.073),(r-.003,-.063),(r,-.048),(r,.047),(r-.003,.063),(r-.012,.073),(0,.073)]
    lathe('Rounded teal reel',(0,y,z),profile,0,'X',40,group='Reel_enamel')
    for sx in [-1,1]:
        cyl('Inset circular reel face',(sx*.075,y,z),r*.896,.008,1,'X',segments=40)
        if y<0:
            cyl('Coral optic socket',(sx*.088,y,z),.077,.029,4,'X',segments=32)
            cyl('Cream optic bezel',(sx*.107,y,z),.056,.024,5,'X',segments=32)
            sphere('Obsidian optical pupil',(sx*.122,y,z),.036,3,scale=(.25,1,1))
            sphere('Optic glint',(sx*.132,y+.011,z+.013),.006,5,scale=(.2,1,1))
        else:
            cyl('Lilac reel hub',(sx*.088,y,z),.062,.023,7,'X',segments=32)
            sphere('Turquoise domed jewel',(sx*.105,y,z),.044,6,scale=(.42,1,1))
            sphere('Jewel glint',(sx*.124,y+.012,z+.016),.009,5,scale=(.2,1,1))
        # Tiny purposeful hub fasteners; not random dirt.
        for a in [50,170,290]:
            t=math.radians(a);cyl('Hub fastener',(sx*.092,y+math.sin(t)*.068,z+math.cos(t)*.068),.005,.004,7,'X',segments=12)

# Brass side winding dial and trigger lever, duplicated mechanically on both sides.
for sx in [-1,1]:
    cyl('Side dial mounting washer',(sx*.225,-.049,.654),.083,.032,2,'X',segments=32)
    cyl('Dial shadow',(sx*.249,-.049,.654),.071,.025,3,'X',segments=32)
    cyl('Fluted winding dial',(sx*.276,-.049,.654),.07,.045,2,'X',segments=32)
    for j in range(16):
        a=TAU*j/16
        cyl('Dial milling rib',(sx*.271,-.049+math.sin(a)*.068,.654+math.cos(a)*.068),.005,.032,2,'X',segments=8)
    cyl('Dial polished cap',(sx*.302,-.049,.654),.062,.015,2,'X',segments=32)
    for y,z in [(.128,.75),(-.135,.75),(.13,.538)]:
        cyl('Body lilac rivet',(sx*.22,y,z),.01,.009,7,'X',segments=12)
    cyl('Trigger brass boss',(sx*.223,-.062,.533),.019,.022,2,'X',segments=20)
    cyl('Trigger handle',(sx*.266,-.062,.533),.011,.066,2,'X',segments=16)
    sphere('Trigger rounded tip',(sx*.301,-.062,.533),.011,2)
    cyl('Side coral button',(sx*.226,.092,.543),.017,.017,4,'X',segments=20)
cyl('Top brass antenna',( .148,-.115,.847),.012,.078,2,segments=20)
cyl('Antenna seat',(.148,-.115,.813),.022,.014,2,segments=24)
for x in [-.104,.104]:
    cyl('Rear connector',(x,-.219,.651),.035,.044,3,'Y',segments=24)
    cyl('Rear connector gold flange',(x,-.244,.651),.043,.018,2,'Y',segments=24)
    cyl('Rear connector teal end',(x,-.255,.651),.027,.008,1,'Y',segments=24)
for z in [.569,.595,.621]:
    box('Rear ventilation slot',(0,-.202,z),(.098,.009,.008),3,.002)

muzzle=bpy.data.objects.new('Muzzle',None);bpy.context.collection.objects.link(muzzle);muzzle.parent=aim;muzzle.location=(-.112,.540,.706-.43)
muzzle.empty_display_type='ARROWS';muzzle.empty_display_size=.08
# Merge rigid geometry by region/material to keep scene overhead modest.
for name,objects in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();objects[0].name=name
    mesh=objects[0].data
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.remove_doubles(bm,verts=bm.verts,dist=.000001);bm.to_mesh(mesh);bm.free();mesh.update()
    # Remove excess coplanar detail while keeping reel and barrel silhouettes round.
    dec=objects[0].modifiers.new('Compact rigid mesh','DECIMATE');dec.ratio=.86 if name=='Reel_enamel' else .58
    bpy.ops.object.modifier_apply(modifier=dec.name)
bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_ion.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_ion.glb'),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
stats={'triangles':sum(len(o.data.loop_triangles) for o in bpy.context.scene.objects if o.type=='MESH'),'mesh_objects':sum(o.type=='MESH' for o in bpy.context.scene.objects),'materials':len(mats),'textures':len(images),'animation_clips':0}
for o in bpy.context.scene.objects:
    if o.type=='MESH':o.data.calc_loop_triangles()
stats['triangles']=sum(len(o.data.loop_triangles) for o in bpy.context.scene.objects if o.type=='MESH')
(OUT/'build_stats.json').write_text(json.dumps(stats,indent=2))
print('FINAL BUILD',stats)
