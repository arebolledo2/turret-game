"""Ramjet Beetle: grounded four-leg articulated charger, metres, Blender +Y forward."""
import bpy,bmesh,math,json
import numpy as np
from mathutils import Vector
from pathlib import Path
bpy.ops.wm.read_factory_settings(use_empty=True)
OUT=Path(__file__).resolve().parent;TAU=math.tau
palette=[(.10,.66,.57),(.035,.30,.31),(.96,.69,.23),(.044,.063,.12),(.98,.37,.29),(.30,.38,.46),(.39,.24,.67),(.20,.94,.72)]
rough=[.26,.32,.25,.34,.28,.34,.26,.18];metal=[.1,.16,.78,.37,.10,.40,.12,.04]
N=1024;rng=np.random.default_rng(51262);yy,xx=np.mgrid[0:256,0:512];u=xx/512;v=yy/256
noise=rng.normal(0,1,(256,512));wave=np.sin(u*TAU*27)*.3+np.sin(v*TAU*39)*.15
arrays=[np.zeros((N,N,4),dtype=np.float32) for _ in range(4)]
for i,c in enumerate(palette):
    sy=slice((i//2)*256,(i//2+1)*256);sx=slice((i%2)*512,(i%2+1)*512)
    col=np.array(c)[None,None,:]*(1+noise[:,:,None]*.003+wave[:,:,None]*.006)
    if i==2:col*=1+(np.sin(v*TAU*103)+noise*.4)[:,:,None]*.008
    arrays[0][sy,sx,:3]=np.clip(col,0,1);arrays[1][sy,sx,0]=1;arrays[1][sy,sx,1]=rough[i]+noise*.004+wave*.009;arrays[1][sy,sx,2]=metal[i]
    arrays[2][sy,sx,:3]=(.5,.5,1);arrays[2][sy,sx,0]+=noise*.001;arrays[2][sy,sx,1]+=wave*.001
    if i==7:arrays[3][sy,sx,:3]=np.array(c)*.17
for a in arrays:a[:,:,3]=1
images=[]
for name,arr,cs in zip(['ramjet_albedo','ramjet_orm','ramjet_normal','visor_emission'],arrays,['sRGB','Non-Color','Non-Color','sRGB']):
    im=bpy.data.images.new(name,width=N,height=N,alpha=True);im.colorspace_settings.name=cs;im.pixels.foreach_set(arr.ravel());im.update();im.filepath_raw=str(OUT/(name+'.png'));im.file_format='PNG';im.save();im.pack();images.append(im)
mats=[]
for i,name in enumerate(['Teal enamel armor','Deep teal recess','Warm brushed brass','Midnight mechanism','Coral carapace','Slate toe armor','Purple dorsal ridge','Mint optical visor']):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*palette[i],1);nodes=m.node_tree.nodes;links=m.node_tree.links;p=nodes.get('Principled BSDF')
    for j,socket in[(0,'Base Color'),(3,'Emission Color')]:
        t=nodes.new('ShaderNodeTexImage');t.image=images[j];links.new(t.outputs['Color'],p.inputs[socket])
    t=nodes.new('ShaderNodeTexImage');t.image=images[1];s=nodes.new('ShaderNodeSeparateColor');links.new(t.outputs['Color'],s.inputs['Color']);links.new(s.outputs['Green'],p.inputs['Roughness']);links.new(s.outputs['Blue'],p.inputs['Metallic'])
    t=nodes.new('ShaderNodeTexImage');t.image=images[2];n=nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.15;links.new(t.outputs['Color'],n.inputs['Color']);links.new(n.outputs['Normal'],p.inputs['Normal'])
    p.inputs['Emission Strength'].default_value=1;p.inputs['Coat Weight'].default_value=.32 if i in(0,4,6,7) else .1;p.inputs['Coat Roughness'].default_value=.15;mats.append(m)
def empty(name,pos,parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=pos
    if parent:o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted()
    bpy.context.view_layer.update();return o
root=empty('Ramjet_Beetle',(0,0,0));body=empty('Body',(0,-.05,.46),root)
hips={}
for side,sx in[('L',-1),('R',1)]:
    for idx,y in[(0,.165),(1,-.182)]:hips[(side,idx)]=empty('Leg_'+side+'_'+str(idx),(sx*.221,y,.334),root)
groups={}
def finish(o,name,mi,parent):
    o.name=name;o.data.materials.append(mats[mi]);uv=o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap')
    for p in o.data.polygons:
        axis=max(range(3),key=lambda j:abs(p.normal[j]))
        for li in p.loop_indices:
            co=o.data.vertices[o.data.loops[li].vertex_index].co;a,b=((co.y,co.z) if axis==0 else(co.x,co.z) if axis==1 else(co.x,co.y))
            uv.data[li].uv=((mi%2)*.5+.02+(a/2+.5)*.46,(mi//2)*.25+.01+(b/2+.5)*.23)
    o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted();groups.setdefault(parent.name,[]).append(o);return o
def soft(o,w=.015,seg=3):
    mod=o.modifiers.new('Soft crafted edges','BEVEL');mod.width=w;mod.segments=seg;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    for p in o.data.polygons:p.use_smooth=True
    mod=o.modifiers.new('Weighted edge normals','WEIGHTED_NORMAL');mod.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=mod.name)
def box(name,pos,size,mi,parent,w=.02,seg=3):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);soft(o,w,seg);return finish(o,name,mi,parent)
def lathe(name,pos,profile,mi,parent,axis='Z',segments=28):
    rot=Vector((1,0,0) if axis=='X' else(0,1,0) if axis=='Y' else(0,0,1)).to_track_quat('Z','Y').to_matrix();verts=[];faces=[]
    for r,z in profile:
        for j in range(segments):verts.append(rot@Vector((r*math.cos(TAU*j/segments),r*math.sin(TAU*j/segments),z)))
    for k in range(len(profile)-1):
        for j in range(segments):faces.append((k*segments+j,k*segments+(j+1)%segments,(k+1)*segments+(j+1)%segments,(k+1)*segments+j))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.location=pos
    for p in mesh.polygons:
        k=p.index//segments;p.use_smooth=profile[k][0]>0 and profile[k+1][0]>0
    return finish(o,name,mi,parent)
def cyl(name,pos,r,d,mi,parent,axis='Z',segments=24):
    segments=min(segments,10 if r<.015 else 16 if r<.03 else 28);b=min(.006,d*.2,r*.15)
    return lathe(name,pos,[(0,-d/2),(r-b,-d/2),(r,-d/2+b),(r,d/2-b),(r-b,d/2),(0,d/2)],mi,parent,axis,segments)
def sphere(name,pos,r,mi,parent,scale=(1,1,1),segments=None):
    n=segments or(32 if r>.2 else 20 if r>.07 else 12 if r>.025 else 8)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=n,ring_count=max(6,n//2),radius=r,location=pos);o=bpy.context.object;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for p in o.data.polygons:p.use_smooth=True
    return finish(o,name,mi,parent)
def strut(name,a,b,r,mi,parent):
    a,b=Vector(a),Vector(b);o=cyl(name,(a+b)/2,r,(a-b).length,mi,parent);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o

# Dark beetle chassis, gold belly and large teal forward helmet.
sphere('Beetle inner chassis',(0,-.065,.55),.30,3,body,scale=(1.025,1.19,.87),segments=24)
o=lathe('Gold belly armor',(0,-.065,0),[(0,.31),(.15,.312),(.23,.35),(.28,.40),(.290,.45),(.284,.47),(0,.47)],2,body,segments=36);o.scale.y=1.16
sphere('Rounded teal ram helmet',(0,.227,.547),.244,0,body,scale=(1.08,.84,.97))

# Four curved carapace plates cover the upper/rear ellipsoid, with readable seams.
def shellpoint(theta,phi,scale=1):
    return Vector((.305*math.sin(theta)*math.cos(phi)*scale,-.065+.36*math.cos(theta)*scale,.55+.285*math.sin(theta)*math.sin(phi)*scale))
def patch(name,th0,th1,ph0,ph1,mi,nth=8,nph=8):
    verts=[]
    for scale in[1.024,.996]:
        for i in range(nth+1):
            t=th0+(th1-th0)*i/nth
            for j in range(nph+1):verts.append(shellpoint(t,ph0+(ph1-ph0)*j/nph,scale)-Vector((0,-.065,.55)))
    row=nph+1;count=(nth+1)*row;faces=[]
    for i in range(nth):
        for j in range(nph):
            a=i*row+j;faces.append((a,a+row,a+row+1,a+1));faces.append((a+count,a+1+count,a+row+1+count,a+row+count))
    for i in range(nth):
        for j in[0,nph]:a=i*row+j;faces.append((a,a+count,a+row+count,a+row))
    for j in range(nph):
        for i in[0,nth]:a=i*row+j;faces.append((a,a+1,a+1+count,a+count))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(mesh);bm.free();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.location=(0,-.065,.55);soft(o,.005,2);return finish(o,name,mi,body)
for th0,th1 in[(.98,1.74),(1.79,3.02)]:
    for ph0,ph1 in[(.10,math.pi/2-.12),(math.pi/2+.12,math.pi-.10)]:
        patch('Coral segmented shell',th0,th1,ph0,ph1,4)
        for t in[th0+.10,th1-.10]:
            for p in[ph0+.13,ph1-.13]:sphere('Mint shell rivet',shellpoint(t,p,1.045),.008,7,body)
patch('Purple dorsal crest',.98,3.06,math.pi/2-.09,math.pi/2+.09,6,nth=18,nph=3)
for ph0,ph1 in[(-.09,.075),(math.pi-.075,math.pi+.09)]:patch('Teal flank band',1.05,2.84,ph0,ph1,0,nth=14,nph=2)
sphere('Dorsal mint seal',shellpoint(1.83,math.pi/2,1.052),.025,7,body,scale=(.9,1,.45))

# Shield-like mint visor follows the forward face with a small armored lower mask.
def faceplate(name,points,y,depth,mi):
    verts=[(x,dy,z-.575) for dy in[-depth/2,depth/2] for x,z in points];n=len(points);faces=[tuple(range(n)),tuple(reversed(range(n,2*n)))]
    for j in range(n):faces.append((j,j+n,(j+1)%n+n,(j+1)%n))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(mesh);bm.free();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.location=(0,y,.575);soft(o,.009,3);return finish(o,name,mi,body)
outline=[(-.185,.607),(-.150,.646),(-.064,.630),(.068,.630),(.15,.646),(.185,.607),(.173,.522),(.064,.513),(-.07,.517),(-.173,.525)]
faceplate('Deep teal visor surround',[(x*1.10,.575+(z-.575)*1.16) for x,z in outline],.422,.026,1)
faceplate('Mint forward visor',outline,.445,.020,7)
box('Midnight jaw mask',(0,.437,.455),(.258,.037,.076),3,body,w=.015)
box('Slate jaw grille',(0,.461,.454),(.105,.014,.044),5,body,w=.007)
for x in[-.105,.105]:box('Mask side armored rail',(x,.459,.443),(.032,.04,.092),3,body,w=.011)

# Broad rising ram tusks, swept through Catmull-Rom centers with a tapered section.
def tusk(side):
    sx=side;control=[Vector((sx*.184,.41,.448)),Vector((sx*.248,.476,.398)),Vector((sx*.277,.55,.488)),Vector((sx*.248,.574,.639)),Vector((sx*.208,.542,.803))]
    radii=[.046,.077,.07,.045,.002];centers=[];rs=[]
    for seg in range(4):
        p0=control[max(0,seg-1)];p1=control[seg];p2=control[seg+1];p3=control[min(4,seg+2)]
        for j in range(6):
            t=j/6;centers.append(.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t));rs.append(radii[seg]*(1-t)+radii[seg+1]*t)
    centers.append(control[-1]);rs.append(.001)
    verts=[];faces=[];n=16
    for i,(c,r) in enumerate(zip(centers,rs)):
        tangent=(centers[min(len(centers)-1,i+1)]-centers[max(0,i-1)]).normalized();a=tangent.cross(Vector((1,0,0))).normalized();b=tangent.cross(a).normalized()
        for j in range(n):verts.append(c-Vector((0,0,.5))+r*(a*math.cos(TAU*j/n)*.8+b*math.sin(TAU*j/n)))
    for i in range(len(centers)-1):
        for j in range(n):faces.append((i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j))
    faces.extend([tuple(reversed(range(n))),tuple((len(centers)-1)*n+j for j in range(n))])
    mesh=bpy.data.meshes.new('Tapered ram tusk');mesh.from_pydata(verts,[],faces);mesh.update();bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(mesh);bm.free();o=bpy.data.objects.new('Tapered ram tusk',mesh);bpy.context.collection.objects.link(o);o.location=(0,0,.5)
    for p in mesh.polygons:p.use_smooth=True
    return finish(o,'Broad brass ram tusk',2,body)
for sx in[-1,1]:
    tusk(sx);sphere('Tusk midnight root',(sx*.184,.416,.447),.056,3,body,scale=(1,.7,1))
    cyl('Tusk brass cheek pin',(sx*.192,.46,.462),.024,.020,2,body,'Y',segments=20)
    cyl('Rear ramjet brass port',(sx*.239,-.283,.463),.066,.079,2,body,'X',segments=28)
    cyl('Rear ramjet dark center',(sx*.285,-.283,.463),.039,.022,3,body,'X',segments=24)

# Four rigid legs: L negative X, R positive X; front index 0, rear index 1.
for (side,idx),rig in hips.items():
    sx=-1 if side=='L' else 1;y=.165 if idx==0 else-.182
    hip=(sx*.221,y,.334);knee=(sx*.295,y+.025,.205);ankle=(sx*.326,y+.051,.075)
    sphere('Hip midnight joint',hip,.057,3,rig)
    strut('Upper leg link',hip,knee,.039,3,rig);strut('Lower leg link',knee,ankle,.037,3,rig)
    o=sphere('Teal droplet leg armor',(sx*.296,y+.026,.213),.104,0,rig,scale=(.72,.78,1.20));o.rotation_euler.y=sx*math.radians(15)
    cyl('Golden hip lens bezel',(sx*.365,y,.318),.041,.032,2,rig,'X',segments=24)
    sphere('Hip jewel',(sx*.385,y,.318),.027,1,rig,scale=(.34,1,1))
    sphere('Hip jewel glint',(sx*.396,y+.005,.327),.006,7,rig,scale=(.15,1,1))
    box('Leg armor crease',(sx*.343,y+.069,.217),(.052,.024,.008),3,rig,w=.002)
    footx=sx*.329;footy=y+.063
    box('Grounded dark foot',(footx,footy,.017),(.136,.155,.034),3,rig,w=.014)
    for dx in[-.026,.026]:sphere('Rounded slate toe',(footx+dx,footy+.023,.054),.060,5,rig,scale=(.65,1.08,.68))
    box('Dark toe separator',(footx,footy+.064,.047),(.01,.015,.062),3,rig,w=.003)
    cyl('Ankle brass pin',(sx*.394,footy-.018,.057),.016,.013,2,rig,'X',segments=16)

# Merge only within each articulated rigid pivot.
for o in list(bpy.context.scene.objects):
    if o.type=='MESH':
        bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
for name,objs in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();o=objs[0];o.name=name+'_rigid_geometry'
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=bm.verts,dist=.000001);bm.to_mesh(o.data);bm.free();o.data.update()
    dec=o.modifiers.new('Compact rigid grouping','DECIMATE');dec.ratio=.45 if name=='Body' else .56;bpy.ops.object.modifier_apply(modifier=dec.name)
bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.update();bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_charger.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_charger.glb'),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
for o in bpy.context.scene.objects:
    if o.type=='MESH':o.data.calc_loop_triangles()
stats={'triangles':sum(len(o.data.loop_triangles) for o in bpy.context.scene.objects if o.type=='MESH'),'mesh_objects':sum(o.type=='MESH' for o in bpy.context.scene.objects),'materials':len(mats),'textures':len(images),'animation_clips':0}
(OUT/'build_stats.json').write_text(json.dumps(stats,indent=2));print('FINAL BUILD',stats)
