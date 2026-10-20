"""Clockwork Focused Lance (Shock/Lance level 5). Metres, Z up, barrel faces +Y. Static bell tower, rotating Aim head."""
from pathlib import Path
import math,json
import bpy,bmesh,numpy as np
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
OUT=Path(__file__).resolve().parent
N=1024
rng=np.random.default_rng(139)
COL=[(.055,.65,.57),(.91,.66,.21),(.98,.29,.21),(.15,.14,.24),(.97,.82,.40),(.96,.90,.74),(1,.54,.035),(.99,.91,.58)]
ROUGH=[.34,.27,.26,.48,.25,.30,.14,.21]
METAL=[.18,.79,.07,.08,.66,.0,.03,.35]
arrs=[np.ones((N,N,4),np.float32) for _ in range(4)]
for i,c in enumerate(COL):
    y,x=i//4,i%4;a,b=slice(y*512,(y+1)*512),slice(x*256,(x+1)*256)
    v,u=np.mgrid[0:512,0:256].astype(np.float32);v/=512;u/=256
    noise=rng.normal(0,1,(512,256)).astype(np.float32)
    broad=.014*np.sin(u*8+v*5)+.009*np.cos(u*4-v*11)
    brush=.012*np.sin(v*805+u*4) if i in (1,4,7) else .001*np.sin(u*750+v*10)
    arrs[0][a,b,:3]=np.clip(np.array(c)*(1+broad+brush+noise*.0016)[:,:,None],0,1)
    arrs[1][a,b,0]=1;arrs[1][a,b,1]=ROUGH[i]+broad*.5;arrs[1][a,b,2]=METAL[i]
    arrs[2][a,b,:3]=np.stack((.5+noise*.0006,.5+noise*.0006,np.ones_like(noise)),axis=-1)
    arrs[3][a,b,:3]=0
    if i==6:
        # The cut amber crown has a bright golden heart fading into deep orange tips.
        fire=(1-v)**1.3
        crystal=np.stack((.98+u*0,.22+.56*fire,.016+.045*fire),axis=-1)
        crystal*= (.94+.06*np.sin(u*32+v*7)**2)[:,:,None]
        arrs[0][a,b,:3]=crystal
        arrs[3][a,b,:3]=np.stack((.35+.60*fire,.08+.70*fire,.004+.035*fire),axis=-1)
    if i==7:arrs[3][a,b,:3]=(.14,.085,.015)
images=[]
for name,buf,space in zip(('lance_color_atlas','lance_orm_atlas','lance_micro_normal','lance_amber_fire'),arrs,('sRGB','Non-Color','Non-Color','sRGB')):
    im=bpy.data.images.new(name,width=N,height=N,alpha=True);im.colorspace_settings.name=space;im.pixels.foreach_set(buf.ravel());im.filepath_raw=str(OUT/(name+'.png'));im.file_format='PNG';im.save();im.pack();images.append(im)
materials=[]
for i,name in enumerate(('Lagoon porcelain enamel','Polished warm brass','Coral lacquer hoop','Slate plum foundation','Champagne brass','Warm ivory ceramic','Faceted amber crystal','Crystal light facets')):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*COL[i],1);n,l=m.node_tree.nodes,m.node_tree.links;p=n.get('Principled BSDF')
    t=n.new('ShaderNodeTexImage');t.image=images[0];l.new(t.outputs['Color'],p.inputs['Base Color'])
    t=n.new('ShaderNodeTexImage');t.image=images[1];sp=n.new('ShaderNodeSeparateColor');l.new(t.outputs['Color'],sp.inputs['Color']);l.new(sp.outputs['Green'],p.inputs['Roughness']);l.new(sp.outputs['Blue'],p.inputs['Metallic'])
    t=n.new('ShaderNodeTexImage');t.image=images[2];nm=n.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.12;l.new(t.outputs['Color'],nm.inputs['Color']);l.new(nm.outputs['Normal'],p.inputs['Normal'])
    p.inputs['Coat Weight'].default_value=.23 if i in (0,2,6) else .07;p.inputs['Coat Roughness'].default_value=.19
    if i in (6,7):
        t=n.new('ShaderNodeTexImage');t.image=images[3];l.new(t.outputs['Color'],p.inputs['Emission Color']);p.inputs['Emission Strength'].default_value=1.2 if i==6 else .13
    materials.append(m)

def empty(name,loc,parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=loc;o.parent=parent;return o
aim=empty('Aim',(0,0,.80));muzzle=empty('Muzzle',(0,.92,.10),aim) # barrel tip world (0,.92,.90)
groups={}
def project(o,mat):
    uv=o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap')
    centre=Vector(tuple((min(v.co[k] for v in o.data.vertices)+max(v.co[k] for v in o.data.vertices))/2 for k in range(3)))
    for p in o.data.polygons:
        k=max(range(3),key=lambda j:abs(p.normal[j]));ij=([1,2],[0,2],[0,1])[k]
        for li in p.loop_indices:
            v=o.data.vertices[o.data.loops[li].vertex_index].co-centre
            uv.data[li].uv=((mat%4+.03+.94*(.5+v[ij[0]]*.78))/4,(mat//4+.03+.94*(.5+v[ij[1]]*.78))/2)
def finish(o,name,mat,group,parent=aim,smooth=True):
    o.name=name;o.data.materials.append(materials[mat]);project(o,mat)
    for p in o.data.polygons:p.use_smooth=smooth
    if parent:
        bpy.context.view_layer.update();o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted()
    groups.setdefault((group,parent),[]).append(o);return o
def raw(name,v,f,mat,group,parent=aim,smooth=True):
    me=bpy.data.meshes.new(name);me.from_pydata(v,[],f);me.update();bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free()
    o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);return finish(o,name,mat,group,parent,smooth)
def lathe(name,profile,mat,group,n=48,parent=aim,open_bottom=False):
    v=[(r*math.cos(j*math.tau/n),r*math.sin(j*math.tau/n),z) for r,z in profile for j in range(n)]
    f=[]
    for k in range(len(profile)-1):
        for j in range(n):f.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
    if not open_bottom:f.append(tuple(reversed(range(n))))
    f.append(tuple((len(profile)-1)*n+j for j in range(n)))
    return raw(name,v,f,mat,group,parent)
def torus(name,r,thick,z,mat,group,parent=aim,n=48,m=8):
    v=[((r+thick*math.cos(k*math.tau/m))*math.cos(j*math.tau/n),(r+thick*math.cos(k*math.tau/m))*math.sin(j*math.tau/n),z+thick*math.sin(k*math.tau/m)) for j in range(n) for k in range(m)]
    f=[(j*m+k,((j+1)%n)*m+k,((j+1)%n)*m+(k+1)%m,j*m+(k+1)%m) for j in range(n) for k in range(m)]
    return raw(name,v,f,mat,group,parent)
def sphere(name,loc,scale,mat,group,seg=16,rings=8,parent=aim):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,radius=1,location=loc);o=bpy.context.object;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,mat,group,parent)
def cylinder(name,loc,r,depth,mat,group,axis=(0,0,1),n=24,parent=aim):
    bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=depth,location=loc);o=bpy.context.object
    mod=o.modifiers.new('Rounded metal rim','BEVEL');mod.width=min(.007,depth*.16);mod.segments=1;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler();return finish(o,name,mat,group,parent)


def lathe_y(name,profile,mat,group,z0,y0=0.0,n=40,parent=aim,caps=True,closed=False):
    """Surface of revolution about a horizontal axis along +Y through (0,y0,z0); profile is (radius, distance along Y)."""
    pts=list(profile)+([profile[0]] if closed else [])
    v=[(r*math.cos(j*math.tau/n),y0+t,z0+r*math.sin(j*math.tau/n)) for r,t in pts for j in range(n)]
    f=[]
    for k in range(len(pts)-1):
        for j in range(n):f.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
    if caps:
        f.append(tuple(reversed(range(n))));f.append(tuple((len(pts)-1)*n+j for j in range(n)))
    return raw(name,v,f,mat,group,parent)
def band_y(name,ri,ro,t0,t1,mat,group,z0,n=40,c=.012):
    return lathe_y(name,[(ri,t0),(ro-c,t0),(ro,t0+c),(ro,t1-c),(ro-c,t1),(ri,t1)],mat,group,z0,n=n,caps=False,closed=True)

# ---- Static tower -------------------------------------------------------------------------
lathe('Ground foundation',[(.47,.015),(.505,.025),(.527,.055),(.527,.095),(.510,.129),(.479,.151),(.0,.151)],3,'Foundation',48,None)
lathe('Foundation top inset',[(.425,.148),(.445,.153),(.448,.158),(.436,.164),(.0,.164)],3,'Foundation',48,None)
for a in (math.radians(90),math.radians(210),math.radians(330)):
    x,y=.43*math.cos(a),.43*math.sin(a)
    sphere('Cream bell foot',(x,y,.225),(.078,.078,.07),5,'Static feet',16,8,None)
    cylinder('Brass foot tip',(x,y,.178),.046,.034,1,'Foot tips',parent=None)
# Flared skirt, tapering bell body and thick coral hoops at the foot and lower waist.
lathe('Bell enamel body',[(.41,.30),(.45,.31),(.46,.335),(.44,.365),(.40,.385),(.37,.41),(.30,.46),(.265,.56),(.24,.67),(.218,.76),(.208,.80)],0,'Bell body',48,None,open_bottom=True)
lathe('Dark skirt underside',[(.41,.30),(.395,.315),(.35,.34),(.27,.38),(.0,.41)],3,'Bell underside',40,None,open_bottom=True)
torus('Coral base hoop',.450,.036,.338,2,'Coral hoops',None,48,8)
torus('Coral waist hoop',.31,.03,.455,2,'Coral hoops',None,48,8)
torus('Brass skirt inlay',.402,.008,.388,4,'Brass trim',None,48,6)
lathe('Brass shoulder ring',[(.205,.795),(.235,.795),(.252,.806),(.252,.822),(.236,.834),(.205,.834)],1,'Brass trim',48,None)

# ---- Rotating head (Aim) ------------------------------------------------------------------
lathe('Head drum',[(.205,.832),(.19,.84),(.185,.88),(.188,.94),(.178,.975),(.15,.99),(.0,.995)],0,'Head drum',40)
lathe('Crystal brass socket',[(.088,.985),(.10,.995),(.118,1.015),(.132,1.035),(.138,1.052),(.126,1.060),(.112,1.050),(.098,1.030),(.07,1.02)],1,'Crystal socket',40)
for a in (math.radians(90),math.radians(210),math.radians(330)):
    sphere('Drum champagne stud',(.188*math.cos(a),.188*math.sin(a),.9),(.012,.012,.012),4,'Drum studs',12,6)
# Faceted amber crystal, tall and pointed like the concept.
Z0,H=1.0,.43
profile=[(.056,.977,0),(.112,1.013,.03),(.148,1.080,-.025),(.134,1.130,.04),(.09,1.18,0),(.010,1.219,0)]
n=8;v=[]
for r,z,phase in profile:
    zz=Z0+(z-.977)*H/.242
    for j in range(n):
        t=j*math.tau/n+phase;v.append((r*math.cos(t),r*math.sin(t),zz))
f=[]
for k in range(len(profile)-1):
    for j in range(n):
        q=(k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j)
        if k in (1,2):f.extend([(q[0],q[1],q[2]),(q[0],q[2],q[3])])
        else:f.append(q)
f.extend([tuple(reversed(range(n))),tuple((len(profile)-1)*n+j for j in range(n))])
gem=raw('Cut amber crystal',v,f,6,'Amber crystal',smooth=False)
uv=gem.data.uv_layers.active
for p in gem.data.polygons:
    for li in p.loop_indices:
        co=gem.data.vertices[gem.data.loops[li].vertex_index].co
        uv.data[li].uv=((2+.03+.94*(math.atan2(co.y,co.x)+math.pi)/math.tau)/4,(1+.03+.94*(co.z-Z0)/H)/2)
gem.data.materials.append(materials[7])
for p in gem.data.polygons:
    if p.center.z>Z0+.22 and p.center.y>.01 and p.index%3==0:
        p.material_index=1
        for li in p.loop_indices:
            co=gem.data.vertices[gem.data.loops[li].vertex_index].co
            uv.data[li].uv=((3+.5+co.x*.78)/4,(1+.5+(co.z-Z0-.2)*.78)/2)

# Lance barrel along +Y at z=.90: teal rod, brass collars, ivory insulator tip, short rear stub.
BZ=.90
lathe_y('Lance rod',[(.064,.12),(.064,.72)],0,'Barrel rod',BZ,n=28)
lathe_y('Rear stub',[(.056,-.17),(.056,-.15),(.056,.12)],0,'Barrel rod',BZ,n=24)
band_y('Barrel root ring',.064,.112,.10,.20,1,'Barrel rings',BZ,c=.016)
band_y('Barrel mid ring',.064,.098,.36,.42,1,'Barrel rings',BZ,c=.012)
band_y('Barrel tip ring',.064,.108,.62,.70,1,'Barrel rings',BZ,c=.014)
band_y('Rear cap ring',.05,.085,-.205,-.15,1,'Barrel rings',BZ,c=.012)
lathe_y('Ivory insulator tip',[(.0,.66),(.09,.664),(.10,.70),(.088,.78),(.052,.86),(.016,.92),(.0,.94)],5,'Ivory tip',BZ,n=32)

for (name,parent),objs in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]
    if len(objs)>1:bpy.ops.object.join()
    bpy.context.object.name=name
bpy.context.view_layer.update()
for o in bpy.context.scene.objects:
    if o.type=='MESH':o.data.calc_loop_triangles()
stats={'triangles':sum(len(o.data.loop_triangles) for o in bpy.context.scene.objects if o.type=='MESH'),'mesh_objects':sum(o.type=='MESH' for o in bpy.context.scene.objects),'materials':len(materials),'textures':len(images)}
(OUT/'build_stats.json').write_text(json.dumps(stats,indent=2))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_focused_lance.glb'),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False,export_apply=True)
print('LANCE_BUILD',stats)
