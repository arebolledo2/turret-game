"""Kilnheart Lobber: deterministic, self-contained clockwork turret, +Y forward."""
import bpy, bmesh, math, json
import numpy as np
from mathutils import Vector
from pathlib import Path
bpy.ops.wm.read_factory_settings(use_empty=True)
OUT=Path(__file__).resolve().parent;TAU=math.tau
palette=[(.14,.70,.65),(.045,.35,.36),(.96,.69,.22),(.115,.09,.18),(.98,.35,.25),(.99,.89,.64),(.42,.06,.78),(.47,.40,.48)]
rough=[.24,.30,.25,.32,.27,.24,.14,.3];metal=[.14,.16,.76,.45,.1,.02,.15,.6]
N=1024; rng=np.random.default_rng(64281); yy,xx=np.mgrid[0:256,0:512];u=xx/512;v=yy/256
noise=rng.normal(0,1,(256,512));wave=np.sin(u*TAU*37)*.45+np.sin(v*TAU*41)*.16
arrays=[np.zeros((N,N,4),dtype=np.float32) for _ in range(4)]
for i,col in enumerate(palette):
    sy=slice((i//2)*256,(i//2+1)*256);sx=slice((i%2)*512,(i%2+1)*512)
    tex=np.array(col)[None,None,:]*(1+noise[:,:,None]*.004+wave[:,:,None]*.008)
    if i==2:tex*=1+(np.sin(v*TAU*119)+noise*.4)[:,:,None]*.009
    if i==6:
        polish=(np.sin(u*TAU*4.0+np.sin(v*TAU*3))*np.sin(v*TAU*5))*.04
        tex*=1+polish[:,:,None]
    arrays[0][sy,sx,:3]=np.clip(tex,0,1);arrays[1][sy,sx,0]=1
    arrays[1][sy,sx,1]=rough[i]+noise*.004+wave*.009;arrays[1][sy,sx,2]=metal[i]
    arrays[2][sy,sx,:3]=(.5,.5,1);arrays[2][sy,sx,0]+=noise*.001;arrays[2][sy,sx,1]+=wave*.001
    if i==6:arrays[3][sy,sx,:3]=np.array(col)*.12
for a in arrays:a[:,:,3]=1
images=[]
for name,arr,cs in zip(['kiln_albedo','kiln_orm','kiln_normal','jewel_emission'],arrays,['sRGB','Non-Color','Non-Color','sRGB']):
    im=bpy.data.images.new(name,width=N,height=N,alpha=True);im.colorspace_settings.name=cs;im.pixels.foreach_set(arr.ravel());im.update()
    im.filepath_raw=str(OUT/(name+'.png'));im.file_format='PNG';im.save();im.pack();images.append(im)
mats=[]
for i,name in enumerate(['Turquoise enamel','Teal shadow inset','Warm brushed brass','Plum machinery','Coral enamel','Ivory ceramic','Amethyst jewel','Lilac steel']):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*palette[i],1);nodes=m.node_tree.nodes;links=m.node_tree.links;p=nodes.get('Principled BSDF')
    for j,socket in [(0,'Base Color'),(3,'Emission Color')]:
        t=nodes.new('ShaderNodeTexImage');t.image=images[j];links.new(t.outputs['Color'],p.inputs[socket])
    t=nodes.new('ShaderNodeTexImage');t.image=images[1];s=nodes.new('ShaderNodeSeparateColor');links.new(t.outputs['Color'],s.inputs['Color']);links.new(s.outputs['Green'],p.inputs['Roughness']);links.new(s.outputs['Blue'],p.inputs['Metallic'])
    t=nodes.new('ShaderNodeTexImage');t.image=images[2];n=nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.16;links.new(t.outputs['Color'],n.inputs['Color']);links.new(n.outputs['Normal'],p.inputs['Normal'])
    p.inputs['Emission Strength'].default_value=1;p.inputs['Coat Weight'].default_value=.3 if i in(0,4,6) else .1;p.inputs['Coat Roughness'].default_value=.15;mats.append(m)
root=bpy.data.objects.new('Kilnheart_Lobber',None);bpy.context.collection.objects.link(root)
aim=bpy.data.objects.new('Aim',None);bpy.context.collection.objects.link(aim);aim.parent=root;aim.location=(0,0,.355);bpy.context.view_layer.update()
groups={}
def finish(o,name,mi,parent=aim,group=None):
    o.name=name;o.data.materials.append(mats[mi]);uv=o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap')
    for p in o.data.polygons:
        axis=max(range(3),key=lambda j:abs(p.normal[j]))
        for li in p.loop_indices:
            co=o.data.vertices[o.data.loops[li].vertex_index].co
            a,b=((co.y,co.z) if axis==0 else (co.x,co.z) if axis==1 else (co.x,co.y))
            uv.data[li].uv=((mi%2)*.5+.02+(a/2+.5)*.46,(mi//2)*.25+.01+(b/2+.5)*.23)
    o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted();groups.setdefault(group or ('upper_'+str(mi) if parent==aim else 'base_'+str(mi)),[]).append(o);return o
def soft(o,w=.015,seg=3):
    mod=o.modifiers.new('Rounded enamel edges','BEVEL');mod.width=w;mod.segments=seg;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    for p in o.data.polygons:p.use_smooth=True
    mod=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');mod.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=mod.name)
def box(name,pos,size,mi,parent=aim,w=.015):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);soft(o,w);return finish(o,name,mi,parent)
def lathe(name,pos,profile,mi,axis='Z',segments=40,parent=aim,group=None,inner=None):
    axisvec=Vector((1,0,0) if axis=='X' else (0,1,0) if axis=='Y' else(0,0,1));rot=axisvec.to_track_quat('Z','Y').to_matrix();verts=[];faces=[]
    for r,z in profile:
        for j in range(segments):verts.append(rot@Vector((r*math.cos(TAU*j/segments),r*math.sin(TAU*j/segments),z)))
    for k in range(len(profile)-1):
        for j in range(segments):faces.append((k*segments+j,k*segments+(j+1)%segments,(k+1)*segments+(j+1)%segments,(k+1)*segments+j))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.location=pos
    for p in mesh.polygons:
        k=p.index//segments;p.use_smooth=profile[k][0]>0 and profile[k+1][0]>0
    finish(o,name,mi,parent,group)
    if inner is not None:
        mesh.materials.append(mats[3]);uv=mesh.uv_layers.active
        for p in mesh.polygons:
            if p.index//segments>=inner:
                p.material_index=1
                for li in p.loop_indices:uv.data[li].uv=(.53+(uv.data[li].uv.x%.5)*.8,.26+(uv.data[li].uv.y%.25)*.8)
    return o
def cyl(name,pos,r,d,mi,axis='Z',segments=24,parent=aim):
    segments=min(segments,8 if r<.012 else 12 if r<.03 else 24 if r<.15 else 40)
    b=min(.006,d*.2,r*.15)
    return lathe(name,pos,[(0,-d/2),(r-b,-d/2),(r,-d/2+b),(r,d/2-b),(r-b,d/2),(0,d/2)],mi,axis,segments,parent)
def sphere(name,pos,r,mi,scale=(1,1,1),parent=aim):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24 if r>.06 else 16 if r>.025 else 10,ring_count=12 if r>.06 else 8 if r>.025 else 5,radius=r,location=pos);o=bpy.context.object;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for p in o.data.polygons:p.use_smooth=True
    return finish(o,name,mi,parent)
def strut(name,a,b,r,mi,parent=root):
    a,b=Vector(a),Vector(b);o=cyl(name,(a+b)/2,r,(a-b).length,mi,parent=parent);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def torus(name,pos,major,minor,mi,axis='Z',parent=aim,segments=48,tube=8):
    bpy.ops.mesh.primitive_torus_add(major_radius=major,minor_radius=minor,major_segments=segments,minor_segments=tube,location=pos);o=bpy.context.object
    o.rotation_euler=Vector((1,0,0) if axis=='X' else(0,1,0) if axis=='Y' else(0,0,1)).to_track_quat('Z','Y').to_euler()
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=False)
    for p in o.data.polygons:p.use_smooth=True
    return finish(o,name,mi,parent)

# All planted feet, leg struts, hinges, support plate and outer bearing remain fixed.
box('Static teal foundation',(0,0,.269),(.43,.37,.093),0,parent=root,w=.035)
box('Brass foundation rim',(0,0,.226),(.454,.398,.034),2,parent=root,w=.028)
for sx in [-1,1]:
    for sy in [-1,1]:
        fx,fy=sx*.281,sy*.238
        lathe('Brass planted foot',(fx,fy,0),[(0,0),(.075,0),(.086,.012),(.086,.035),(.064,.061),(.052,.066),(0,.066)],2,segments=28,parent=root)
        strut('Splayed plum support',(fx,fy,.06),(sx*.201,sy*.16,.279),.044,3)
        cyl('Leg hinge',(sx*.215,sy*.16,.268),.064,.073,3,'X',parent=root)
        cyl('Hinge brass edging',(sx*.255,sy*.16,.268),.053,.011,2,'X',parent=root)
        cyl('Hinge cap',(sx*.264,sy*.16,.268),.041,.014,3,'X',parent=root)
        cyl('Hinge centre bolt',(sx*.274,sy*.16,.268),.015,.008,7,'X',parent=root)
cyl('Fixed bearing shoulder',(0,0,.327),.167,.04,2,parent=root,segments=40)
cyl('Fixed bearing dark race',(0,0,.352),.127,.031,3,parent=root,segments=32)
cyl('Rotating kingpin',(0,0,.372),.096,.04,2,segments=32)
box('Rotating saddle',(0,0,.397),(.247,.277,.049),1,w=.014)

# Bulging cylindrical pressure vessel and gold structural hoops.
profile=[(0,-.239),(.18,-.239),(.236,-.226),(.286,-.186),(.317,-.11),(.328,-.01),(.319,.09),(.3,.168),(.277,.217),(.235,.228),(0,.228)]
lathe('Rounded teal kiln drum',(0,0,.722),profile,0,'Y',48,group='Drum_enamel')
torus('Rear brass binding hoop',(0,-.197,.722),.275,.017,2,'Y',segments=48)
torus('Mid brass binding hoop',(0,-.061,.722),.328,.018,2,'Y',segments=48)
cyl('Rear brass service hatch',(0,-.25,.722),.143,.054,2,'Y',segments=32)
cyl('Rear shadow hatch',(0,-.282,.722),.106,.016,3,'Y',segments=32)
cyl('Rear teal hatch inset',(0,-.293,.722),.089,.015,1,'Y',segments=32)
for a in [45,135,225,315]:
    t=math.radians(a);cyl('Rear hatch bolt',(math.sin(t)*.118,-.283,.722+math.cos(t)*.118),.009,.006,7,'Y')

# Broad coral face armor consists of eight rounded rigid sectors.
def sector(name,start,end):
    verts=[];seg=6
    for y in [.205,.282]:
        for r in [.231,.308]:
            for j in range(seg+1):
                a=start+(end-start)*j/seg;verts.append((r*math.sin(a),y,.722+r*math.cos(a)))
    faces=[];row=seg+1
    for j in range(seg):
        faces.extend([(j,j+1,row+j+1,row+j),(2*row+j,3*row+j,3*row+j+1,2*row+j+1),(j,2*row+j,2*row+j+1,j+1),(row+j,row+j+1,3*row+j+1,3*row+j)])
    faces.extend([(0,row,3*row,2*row),(seg,2*row+seg,3*row+seg,row+seg)])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);soft(o,.012,3);return finish(o,name,4)
for j in range(8):
    a=j*TAU/8;sector('Rounded coral armor petal',a-TAU/16+.009,a+TAU/16-.009)
    cyl('Coral ring steel rivet',(.276*math.sin(a),.29,.722+.276*math.cos(a)),.010,.008,7,'Y')
lathe('Deep plum inner recess',(0,.266,.722),[(.145,-.018),(.224,-.018),(.237,-.006),(.237,.006),(.226,.02),(.146,.02)],3,'Y',48)
torus('Amethyst focusing rim',(0,.298,.722),.178,.026,6,'Y',segments=48,tube=10)

# Short heavy mouth with an open bore and recessed dark liner.
lathe('Wide brass muzzle',(0,.403,.722),[(.098,-.14),(.139,-.095),(.156,-.079),(.161,-.054),(.144,-.038),(.142,.103),(.164,.11),(.17,.129),(.165,.152),(.143,.163),(.112,.163),(.106,.149),(.106,-.115),(.098,-.14),(0,-.14)],2,'Y',48,inner=10)
lathe('Open muzzle reinforcement hoop',(0,.364,.722),[(.107,-.011),(.15,-.011),(.156,-.005),(.156,.005),(.15,.011),(.107,.011),(.107,-.011)],2,'Y',40)

# Jewel crown and side ceramic optics, readable from either side.
lathe('Crown gold socket',(0,-.044,1.025),[(.083,-.035),(.112,-.035),(.127,-.019),(.127,.029),(.116,.043),(.09,.043),(.083,.029),(.083,-.035)],2,segments=40)
sphere('Polished amethyst crown',(0,-.044,1.05),.086,6,scale=(1,1,.94))
sphere('Crown studio glint',(-.025,-.003,1.115),.012,5,scale=(1,.75,.12))
for sx in [-1,1]:
    cyl('Ivory side optic socket',(sx*.318,-.122,.737),.061,.038,5,'X',segments=32)
    cyl('Side optic plum recess',(sx*.341,-.122,.737),.045,.018,3,'X',segments=24)
    sphere('Amethyst side optic',(sx*.35,-.122,.737),.038,6,scale=(.41,1,1))
    sphere('Side optic glint',(sx*.366,-.116,.752),.007,5,scale=(.15,1,1))
    cyl('Rear side brass fitting',(sx*.257,-.202,.75),.04,.041,2,'X',segments=24)

muzzle=bpy.data.objects.new('Muzzle',None);bpy.context.collection.objects.link(muzzle);muzzle.parent=aim;muzzle.location=(0,.566,.722-.355);muzzle.empty_display_type='ARROWS';muzzle.empty_display_size=.09
# Bake rigid mesh rotations before joining so bounds stay aligned with the asset axes.
for o in list(bpy.context.scene.objects):
    if o.type=='MESH':
        bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
for name,objs in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();o=objs[0];o.name=name
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=bm.verts,dist=.000001);bm.to_mesh(o.data);bm.free();o.data.update()
    dec=o.modifiers.new('Compact rigid grouping','DECIMATE');dec.ratio=.9 if name=='Drum_enamel' else .53;bpy.ops.object.modifier_apply(modifier=dec.name)
bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_plasma.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_plasma.glb'),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
for o in bpy.context.scene.objects:
    if o.type=='MESH':o.data.calc_loop_triangles()
stats={'triangles':sum(len(o.data.loop_triangles) for o in bpy.context.scene.objects if o.type=='MESH'),'mesh_objects':sum(o.type=='MESH' for o in bpy.context.scene.objects),'materials':len(mats),'textures':len(images),'animation_clips':0}
(OUT/'build_stats.json').write_text(json.dumps(stats,indent=2));print('FINAL BUILD',stats)
