"""Clockwork Resonator (Shock/Resonator level 5). Metres, Z up. Static bell tower; Aim carries the halo ring, echo orbs and crystal."""
from pathlib import Path
import math,json
import bpy,bmesh,numpy as np
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
OUT=Path(__file__).resolve().parent
N=1024
rng=np.random.default_rng(139)
COL=[(.055,.65,.57),(.91,.66,.21),(.98,.29,.21),(.15,.14,.24),(.68,.51,.90),(.96,.90,.74),(1,.54,.035),(.45,.88,.77)]
ROUGH=[.34,.27,.26,.48,.12,.30,.14,.12]
METAL=[.18,.79,.07,.08,.0,.0,.03,.0]
arrs=[np.ones((N,N,4),np.float32) for _ in range(4)]
for i,c in enumerate(COL):
    y,x=i//4,i%4;a,b=slice(y*512,(y+1)*512),slice(x*256,(x+1)*256)
    v,u=np.mgrid[0:512,0:256].astype(np.float32);v/=512;u/=256
    noise=rng.normal(0,1,(512,256)).astype(np.float32)
    broad=.014*np.sin(u*8+v*5)+.009*np.cos(u*4-v*11)
    brush=.012*np.sin(v*805+u*4) if i in (1,) else .001*np.sin(u*750+v*10)
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
    if i==7:arrs[3][a,b,:3]=(.20,.46,.40)
    if i==4:arrs[3][a,b,:3]=(.30,.20,.45)
images=[]
for name,buf,space in zip(('res_color_atlas','res_orm_atlas','res_micro_normal','res_emissive'),arrs,('sRGB','Non-Color','Non-Color','sRGB')):
    im=bpy.data.images.new(name,width=N,height=N,alpha=True);im.colorspace_settings.name=space;im.pixels.foreach_set(buf.ravel());im.filepath_raw=str(OUT/(name+'.png'));im.file_format='PNG';im.save();im.pack();images.append(im)
materials=[]
for i,name in enumerate(('Lagoon porcelain enamel','Polished warm brass','Coral lacquer hoop','Slate plum foundation','Lavender jewel resin','Warm ivory ceramic','Faceted amber crystal','Mint jewel resin')):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*COL[i],1);n,l=m.node_tree.nodes,m.node_tree.links;p=n.get('Principled BSDF')
    t=n.new('ShaderNodeTexImage');t.image=images[0];l.new(t.outputs['Color'],p.inputs['Base Color'])
    t=n.new('ShaderNodeTexImage');t.image=images[1];sp=n.new('ShaderNodeSeparateColor');l.new(t.outputs['Color'],sp.inputs['Color']);l.new(sp.outputs['Green'],p.inputs['Roughness']);l.new(sp.outputs['Blue'],p.inputs['Metallic'])
    t=n.new('ShaderNodeTexImage');t.image=images[2];nm=n.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.12;l.new(t.outputs['Color'],nm.inputs['Color']);l.new(nm.outputs['Normal'],p.inputs['Normal'])
    p.inputs['Coat Weight'].default_value=.23 if i in (0,2,6) else .07;p.inputs['Coat Roughness'].default_value=.19
    if i in (4,6,7):
        t=n.new('ShaderNodeTexImage');t.image=images[3];l.new(t.outputs['Color'],p.inputs['Emission Color']);p.inputs['Emission Strength'].default_value=1.2 if i==6 else .7
    materials.append(m)

def empty(name,loc,parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=loc;o.parent=parent;return o
aim=empty('Aim',(0,0,.80));muzzle=empty('Muzzle',(0,0,.40),aim) # crystal centre, world z=1.20
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


def band_z(name,ri,ro,z0,z1,mat,group,parent=aim,n=56,c=.012):
    """Closed rounded-rectangle ring about the vertical axis (hollow, no caps)."""
    prof=[(ri,z0),(ro-c,z0),(ro,z0+c),(ro,z1-c),(ro-c,z1),(ri,z1)]
    pts=prof+[prof[0]]
    v=[(r*math.cos(j*math.tau/n),r*math.sin(j*math.tau/n),z) for r,z in pts for j in range(n)]
    f=[(k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j) for k in range(len(pts)-1) for j in range(n)]
    return raw(name,v,f,mat,group,parent)

# ---- Static tower -------------------------------------------------------------------------
lathe('Ground foundation',[(.47,.015),(.505,.025),(.527,.055),(.527,.095),(.510,.129),(.479,.151),(.0,.151)],3,'Foundation',48,None)
lathe('Foundation top inset',[(.425,.148),(.445,.153),(.448,.158),(.436,.164),(.0,.164)],3,'Foundation',48,None)
for a in (math.radians(30),math.radians(150),math.radians(270)):
    sphere('Cream bell foot',(.40*math.cos(a),.40*math.sin(a),.225),(.088,.088,.075),5,'Static feet',16,8,None)
# Wide coral flared skirt with a dark underside, then the tapering teal bell body and dome.
lathe('Coral skirt',[(.36,.30),(.44,.29),(.475,.32),(.47,.375),(.435,.43),(.38,.47),(.35,.49)],2,'Coral skirt',56,None,open_bottom=True)
lathe('Skirt underside',[(.44,.29),(.30,.31),(.0,.34)],3,'Skirt underside',40,None,open_bottom=True)
lathe('Bell enamel body',[(.35,.47),(.335,.54),(.305,.62),(.272,.70),(.225,.77),(.16,.82),(.09,.845),(.0,.85)],0,'Bell body',48,None,open_bottom=True)
for a in (math.radians(55),math.radians(125)):
    c,s=math.cos(a),math.sin(a)
    cylinder('Skirt port brass ring',(.455*c,.455*s,.385),.09,.04,1,'Port rings',axis=(c,s,.35),parent=None)
    sphere('Skirt port jewel',(.468*c,.468*s,.388),(.062,.062,.048),0,'Port jewels',14,8,None)

# ---- Rotating head (Aim): stem, crystal, floating halo ring and echo orbs ------------------
lathe('Brass stem and collar',[(.092,.835),(.092,.90),(.108,.915),(.13,.925),(.132,.955),(.12,.975),(.075,.985)],1,'Crystal socket',40)
Z0,H=.975,.40
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
# Wide flat brass halo floating around the shoulder, with three rim studs.
band_z('Brass halo ring',.38,.54,.735,.83,1,'Halo ring',c=.035)
for a in (0.0,math.pi,1.5*math.pi):
    sphere('Halo rim stud',(.545*math.cos(a),.545*math.sin(a),.78),(.04,.04,.04),1,'Halo studs',12,6)
# Two glossy echo orbs.
sphere('Lavender echo orb',(-.60,0,.60),(.105,.105,.105),4,'Echo orb lavender',20,10)
sphere('Mint echo orb',(.60,0,.60),(.105,.105,.105),7,'Echo orb mint',20,10)

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
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_resonator.glb'),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False,export_apply=True)
print('RESONATOR_BUILD',stats)
