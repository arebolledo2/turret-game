"""Keepsake Cache: deterministic, standalone closed keepsake chest, metres / Z up.
All textures are generated here, packed in the blend and embedded in the GLB.
"""
from pathlib import Path
import math, json
import bpy, bmesh, numpy as np
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
OUT = Path(__file__).resolve().parent
N = 1024
rng = np.random.default_rng(41)
yy, xx = np.mgrid[0:N, 0:N].astype(np.float32) / N
# Eight padded atlas cells: enamel / brass / ivory / coral / plum / recess / amber / champagne.
colors = [(0.10,.70,.60),(.87,.63,.22),(.96,.87,.64),(.97,.28,.22),(.24,.13,.37),(.055,.115,.13),(1,.46,.035),(.96,.87,.59)]
rough = [.29,.27,.35,.29,.33,.48,.15,.24]
metal = [.17,.78,0,.08,.29,.25,.3,.72]
base = np.ones((N,N,4),dtype=np.float32)
orm = np.ones_like(base)
normal = np.ones_like(base)
emissive = np.ones_like(base)
normal[:,:,:3] = (.5,.5,1)
emissive[:,:,:3] = 0
for i,col in enumerate(colors):
    cx,cy=i%4,i//4
    a,b = slice(cy*N//2,(cy+1)*N//2),slice(cx*N//4,(cx+1)*N//4)
    h,w=N//2,N//4
    v,u=np.mgrid[0:h,0:w].astype(np.float32)
    u/=w; v/=h
    micro=rng.normal(0,1,(h,w)).astype(np.float32)
    broad=.012*np.sin(u*9+v*6)+.008*np.cos(v*15-u*4)
    brush=.014*np.sin(v*730+2*np.sin(u*13)) if i in (1,7) else .002*np.sin(u*520+v*115)
    factor=1+broad+brush+micro*.0016
    base[a,b,:3]=np.clip(np.array(col)[None,None,:]*factor[:,:,None],0,1)
    orm[a,b,0]=1
    orm[a,b,1]=np.clip(rough[i]+broad*.65+micro*.001,0,1)
    orm[a,b,2]=metal[i]
    normal[a,b,0]=.5 + (brush*.08 if i in (1,7) else micro*.0006)
    normal[a,b,1]=.5+micro*.0006
    if i==6:
        # Jewel fire is restrained and varies gently under the faceted amber dome.
        fire=.5+.25*np.sin(u*7+v*4)*np.sin(v*9)
        emissive[a,b,:3]=np.stack((fire,fire*.30,fire*.015),axis=-1)

def image(name,arr,space='sRGB'):
    im=bpy.data.images.new(name,width=N,height=N,alpha=True)
    im.colorspace_settings.name=space
    im.pixels.foreach_set(arr.reshape(-1))
    im.filepath_raw=str(OUT/(name+'.png')); im.file_format='PNG'; im.save(); im.pack()
    return im
images=[image('cache_color_atlas',base),image('cache_orm_atlas',orm,'Non-Color'),image('cache_micro_normal',normal,'Non-Color'),image('cache_jewel_fire',emissive)]
mats=[]
for i,name in enumerate(['Lagoon enamel','Satin brass','Warm ivory','Coral lacquer','Plum bezel','Shadow gasket','Amber jewel','Champagne edges']):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*colors[i],1)
    n,l=m.node_tree.nodes,m.node_tree.links;p=n.get('Principled BSDF')
    tex=n.new('ShaderNodeTexImage');tex.image=images[0];l.new(tex.outputs['Color'],p.inputs['Base Color'])
    ot=n.new('ShaderNodeTexImage');ot.image=images[1];split=n.new('ShaderNodeSeparateColor');l.new(ot.outputs['Color'],split.inputs['Color']);l.new(split.outputs['Green'],p.inputs['Roughness']);l.new(split.outputs['Blue'],p.inputs['Metallic'])
    nt=n.new('ShaderNodeTexImage');nt.image=images[2];nm=n.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.18;l.new(nt.outputs['Color'],nm.inputs['Color']);l.new(nm.outputs['Normal'],p.inputs['Normal'])
    p.inputs['Coat Weight'].default_value=.25 if i in (0,3,6) else .08
    p.inputs['Coat Roughness'].default_value=.22
    if i==6:
        et=n.new('ShaderNodeTexImage');et.image=images[3];l.new(et.outputs['Color'],p.inputs['Emission Color']);p.inputs['Emission Strength'].default_value=.28
    mats.append(m)

body=bpy.data.objects.new('Body',None);bpy.context.collection.objects.link(body);body.location=(0,0,.53)
groups={}
def finish(o,name,mat,group=None):
    o.name=name;o.data.materials.append(mats[mat])
    # World-density box projection into padded atlas cells. Every mesh gets UVs.
    bpy.context.view_layer.update()
    uv=o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap')
    centre=Vector(tuple((min(v.co[k] for v in o.data.vertices)+max(v.co[k] for v in o.data.vertices))/2 for k in range(3)))
    for poly in o.data.polygons:
        normal=poly.normal;axis=max(range(3),key=lambda k:abs(normal[k]));ij=([1,2],[0,2],[0,1])[axis]
        for li in poly.loop_indices:
            v=o.data.vertices[o.data.loops[li].vertex_index].co-centre
            uv.data[li].uv=((mat%4+(.5+v[ij[0]]*.72)*.94+.03)/4,(mat//4+(.5+v[ij[1]]*.72)*.94+.03)/2)
    o.parent=body;o.matrix_parent_inverse=body.matrix_world.inverted()
    if group:groups.setdefault(group,[]).append(o)
    return o
def smooth(o):
    for p in o.data.polygons:p.use_smooth=True
    mod=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL');mod.keep_sharp=True;mod.weight=50
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
def bevel(o,width=.02,segments=3):
    bpy.context.view_layer.objects.active=o
    mod=o.modifiers.new('Soft machined edges','BEVEL');mod.width=width;mod.segments=segments
    bpy.ops.object.modifier_apply(modifier=mod.name);smooth(o)
def box(name,loc,size,mat,r=.025,seg=3,group=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);bevel(o,r,seg)
    return finish(o,name,mat,group)
def cyl(name,loc,r,d,mat,axis=(0,0,1),verts=32,edge=.008,group=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=d,location=loc);o=bpy.context.object
    if edge:bevel(o,edge,1)
    o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
    return finish(o,name,mat,group)
def sphere(name,loc,scale,mat,seg=20,rings=10,group=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,radius=1,location=loc);o=bpy.context.object;o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for p in o.data.polygons:p.use_smooth=True
    return finish(o,name,mat,group)
def raw(name,vertices,faces,mat,edge=0,group=None):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(mesh);bm.free()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
    if edge:bevel(o,edge,1)
    return finish(o,name,mat,group)
def rr(width,depth,r,n=8):
    out=[]
    for x,y,a in [(width/2-r,depth/2-r,0),(-width/2+r,depth/2-r,90),(-width/2+r,-depth/2+r,180),(width/2-r,-depth/2+r,270)]:
        for j in range(n+1):
            t=math.radians(a+j*90/n);out.append((x+r*math.cos(t),y+r*math.sin(t)))
    return out
def ring(name,width,depth,r,thick,z,height,mat,group=None):
    a=rr(width,depth,r);b=rr(width-2*thick,depth-2*thick,max(.015,r-thick));n=len(a)
    vs=[(x,y,zz) for zz in (z,z+height) for path in (a,b) for x,y in path]
    fs=[]
    for k in range(n):
        j=(k+1)%n;fs.extend([(k,j,n+j,n+k),(2*n+k,3*n+k,3*n+j,2*n+j),(k,2*n+k,2*n+j,j),(n+k,n+j,3*n+j,3*n+k)])
    return raw(name,vs,fs,mat,.006,group)

def rounded_shell(name,loc,size,r,edge,mat,group):
    path=rr(size[0],size[1],r);n=len(path)
    vs=[(x+loc[0],y+loc[1],loc[2]+dz) for dz in (-size[2]/2,size[2]/2) for x,y in path]
    fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    o=raw(name,vs,fs,mat,0,None)
    bpy.context.view_layer.objects.active=o
    mod=o.modifiers.new('Rounded horizontal lips','BEVEL');mod.width=edge;mod.segments=3;mod.limit_method='ANGLE';mod.angle_limit=math.radians(40)
    bpy.ops.object.modifier_apply(modifier=mod.name);smooth(o)
    # Bevel interpolates the UVs that were already projected onto the closed shell.
    groups.setdefault(group,[]).append(o)
    return o

# Solid lower shell and closed lid; seam is a shallow dark continuous gasket.
rounded_shell('Rounded enamel body',(0,0,.438),(1.07,.95,.755),.08,.014,0,'Shell')
rounded_shell('Lid seam gasket',(0,0,.817),(1.071,.951,.012),.081,.003,5,'Shell')
rounded_shell('Rounded enamel lid',(0,0,.919),(1.08,.96,.195),.083,.028,0,'Lid')
box('Solid inset ivory lid',(0,0,1.025),(.81,.69,.036),2,.058,4,'Lid')
ring('Raised ivory lip',.84,.72,.072,.035,1.026,.034,2,'Lid')

# Corner armor follows each rounded body corner, rather than floating cubes.
def armor(sx,sy,z0,z1,label):
    cx,cy=.445,.385
    outer=[(.335,.503),(.445,.503)]
    for i in range(9):
        t=math.pi/2*(1-i/8);outer.append((cx+.118*math.cos(t),cy+.118*math.sin(t)))
    outer.append((.563,.275))
    inner=[(.495,.275)]
    for i in range(9):
        t=math.pi/2*i/8;inner.append((cx+.05*math.cos(t),cy+.05*math.sin(t)))
    inner.append((.335,.435))
    p=outer+inner;n=len(p)
    v=[(sx*x,sy*y,z) for z in (z0,z1) for x,y in p]
    f=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    raw(label,v,f,1,.015,'Brass armor')
    # Rivets on both side faces, carrying the champagne highlight in reference.
    for pos,axis in [((sx*.408,sy*.509,(z0+z1)/2),(0,sy,0)),((sx*.569,sy*.345,(z0+z1)/2),(sx,0,0))]:
        sphere('Domed armor rivet',pos,(.017,.009,.017) if axis[1] else (.009,.017,.017),1,12,6,'Rivets')
    if z1>1:
        # Solid softly beveled gold crown covers the lid corner, no hollow hook.
        crown=outer+[(.445,.320),(.375,.395)]
        n=len(crown)
        v=[(sx*x,sy*y,z) for z in (1.005,1.052) for x,y in crown]
        f=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        raw('Solid brass corner crown',v,f,1,.009,'Brass armor')
for sx in (-1,1):
    for sy in (-1,1):
        armor(sx,sy,.025,.182,'Lower brass corner')
        armor(sx,sy,.862,1.047,'Upper brass corner')

# Coral front latch with a round button and soft droplet tongue.
box('Coral latch backing',(0,.489,.564),(.15,.04,.224),3,.023,3,'Latch backing')
cyl('Latch shadow escutcheon',(0,.52,.59),.053,.026,4,(0,1,0),32,.006,'Latch backing')
box('Latch dark slot',(0,.526,.51),(.027,.011,.078),5,.007,2,'Latch backing')
profile=[(-.024,.60),(.027,.60),(.035,.54),(.038,.50),(.058,.446),(.062,.422),(.054,.399),(.038,.381),(.012,.375),(-.02,.38),(-.045,.395),(-.055,.421),(-.049,.447),(-.027,.499)]
n=len(profile);vs=[(x,y,z) for y in (.536,.558) for x,z in profile]
fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
raw('Coral teardrop latch',vs,fs,3,.008,'Latch tongue')
cyl('Latch brass collar',(0,.555,.588),.046,.028,7,(0,1,0),32,.007,'Latch tongue')
cyl('Latch round button',(0,.578,.588),.038,.016,1,(0,1,0),32,.008,'Latch tongue')
for x in (-.055,.055):
    for z in (.48,.647):sphere('Latch pin',(x,.514,z),(.007,.004,.007),7,12,6,'Latch backing')

# The left hand side is visible in the standard 3/4 render, as in the concept.
axis=(-1,0,0);optic=(-.549,.11,.545)
cyl('Optic dark seating',optic,.123,.025,5,axis,40,.009,'Optic bezel')
cyl('Plum optic bezel',(-.568,.11,.545),.115,.030,4,axis,40,.009,'Optic bezel')
cyl('Plum recessed inner bezel',(-.585,.11,.545),.088,.014,5,axis,40,.004,'Optic bezel')
cyl('Amber lens brass seat',(-.594,.11,.545),.076,.012,1,axis,32,.004,'Optic bezel')
sphere('Faceted amber jewel',(-.602,.11,.545),(.035,.063,.063),6,20,10,'Amber optic')
# Physical ivory glints on the optical dome, sculpted rather than painted white specks.
sphere('Optic broad glint',(-.634,.128,.571),(.003,.010,.013),7,12,6,'Amber optic')
sphere('Optic small glint',(-.631,.088,.527),(.003,.006,.008),7,12,6,'Amber optic')

def strap(name,x,mat,group):
    # Rounded U handle: two rising stems and a wide lower crossbar, rectangular ribbon section.
    yz=[(.215,.575),(.215,.398)]
    for i in range(1,9):
        a=i*math.pi/2/8;yz.append((.175+.04*math.cos(a),.398-.04*math.sin(a)))
    yz.append((-.175,.358))
    for i in range(1,9):
        a=-math.pi/2-i*math.pi/2/8;yz.append((-.175+.04*math.cos(a),.398+.04*math.sin(a)))
    yz.append((-.215,.575))
    vs=[]
    for j,(y,z) in enumerate(yz):
        tangent=Vector((yz[min(j+1,len(yz)-1)][0]-yz[max(j-1,0)][0],yz[min(j+1,len(yz)-1)][1]-yz[max(j-1,0)][1])).normalized()
        dy,dz=-tangent.y*.013,tangent.x*.013
        vs.extend([(x-.012,y+dy,z+dz),(x+.012,y+dy,z+dz),(x+.012,y-dy,z-dz),(x-.012,y-dy,z-dz)])
    faces=[(3,2,1,0)]
    for j in range(len(yz)-1):
        for k in range(4):faces.append((4*j+k,4*j+(k+1)%4,4*(j+1)+(k+1)%4,4*(j+1)+k))
    faces.append(tuple(4*(len(yz)-1)+k for k in range(4)))
    return raw(name,vs,faces,mat,.004,group)
for sy in (-1,1):
    cyl('Handle brass mount',(-.554,sy*.215,.577),.031,.025,1,axis,24,.005,'Handle mounts')
    cyl('Handle pivot pin',(-.584,sy*.215,.577),.018,.034,7,axis,24,.004,'Handle mounts')
strap('Coral carry handle',-.609,3,'Carry handle')
strap('Brass handle edge',-.594,7,'Carry handle')

# Sensible unseen backside: two small brass hinges seated along the rear lid seam.
for x in (-.30,.30):
    box('Rear hinge leaf',(x,-.48,.824),(.105,.018,.102),1,.01,2,'Rear hinges')
    cyl('Rear hinge barrel',(x,-.501,.818),.024,.12,1,(1,0,0),20,.005,'Rear hinges')
    for dx in (-.029,.029):sphere('Rear hinge pin',(x+dx,-.493,.855),(.006,.004,.006),7,12,6,'Rear hinges')

# Merge parts by material and rigid assembly, preserving practical runtime handles.
for name,objs in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]
    if len(objs)>1:bpy.ops.object.join()
    o=bpy.context.object;o.name=name
    # Join creates duplicate slots; glTF material identity is still shared.
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_dropbox.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_dropbox.glb'),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False,export_apply=True)
stats={'triangles':sum(len(o.data.loop_triangles) for o in bpy.context.scene.objects if o.type=='MESH'),'mesh_objects':sum(o.type=='MESH' for o in bpy.context.scene.objects),'materials':len(mats),'textures':len(images)}
for o in bpy.context.scene.objects:
    if o.type=='MESH':o.data.calc_loop_triangles()
stats['triangles']=sum(len(o.data.loop_triangles) for o in bpy.context.scene.objects if o.type=='MESH')
(OUT/'build_stats.json').write_text(json.dumps(stats,indent=2))
print('CACHE_BUILD',stats)
