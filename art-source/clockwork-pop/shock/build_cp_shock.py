"""Standalone procedural Resonance Bell. Metres, Blender Z up, radial crown emitter."""
from pathlib import Path
import math,json
import bpy,bmesh,numpy as np
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
OUT=Path(__file__).resolve().parent
N=1024
rng=np.random.default_rng(139)
COL=[(.055,.65,.57),(.91,.66,.21),(.98,.29,.21),(.15,.14,.24),(.97,.82,.40),(.12,.075,.20),(1,.54,.035),(.99,.91,.58)]
ROUGH=[.34,.27,.26,.48,.25,.38,.14,.21]
METAL=[.18,.79,.07,.08,.66,.25,.03,.35]
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
for name,buf,space in zip(('bell_color_atlas','bell_orm_atlas','bell_micro_normal','bell_amber_fire'),arrs,('sRGB','Non-Color','Non-Color','sRGB')):
    im=bpy.data.images.new(name,width=N,height=N,alpha=True);im.colorspace_settings.name=space;im.pixels.foreach_set(buf.ravel());im.filepath_raw=str(OUT/(name+'.png'));im.file_format='PNG';im.save();im.pack();images.append(im)
materials=[]
for i,name in enumerate(('Lagoon porcelain enamel','Polished warm brass','Coral lacquer hoop','Slate plum foundation','Champagne brass','Dark bell cavity','Faceted amber crystal','Crystal light facets')):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*COL[i],1);n,l=m.node_tree.nodes,m.node_tree.links;p=n.get('Principled BSDF')
    t=n.new('ShaderNodeTexImage');t.image=images[0];l.new(t.outputs['Color'],p.inputs['Base Color'])
    t=n.new('ShaderNodeTexImage');t.image=images[1];sp=n.new('ShaderNodeSeparateColor');l.new(t.outputs['Color'],sp.inputs['Color']);l.new(sp.outputs['Green'],p.inputs['Roughness']);l.new(sp.outputs['Blue'],p.inputs['Metallic'])
    t=n.new('ShaderNodeTexImage');t.image=images[2];nm=n.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.12;l.new(t.outputs['Color'],nm.inputs['Color']);l.new(nm.outputs['Normal'],p.inputs['Normal'])
    p.inputs['Coat Weight'].default_value=.23 if i in (0,2,6) else .07;p.inputs['Coat Roughness'].default_value=.19
    if i in (6,7):
        t=n.new('ShaderNodeTexImage');t.image=images[3];l.new(t.outputs['Color'],p.inputs['Emission Color']);p.inputs['Emission Strength'].default_value=2.0 if i==6 else .13
    materials.append(m)

def empty(name,loc,parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=loc;o.parent=parent;return o
aim=empty('Aim',(0,0,.18));muzzle=empty('Muzzle',(0,0,1.01),aim) # central crown world z=1.19
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

# Static foundation: gently chamfered low charcoal-plum round plinth.
lathe('Ground foundation',[(.47,.015),(.505,.025),(.527,.055),(.527,.095),(.510,.129),(.479,.151),(.0,.151)],3,'Foundation',48,None)
lathe('Foundation top inset',[(.425,.148),(.445,.153),(.448,.158),(.436,.164),(.0,.164)],5,'Foundation',48,None)
for a in (math.radians(90),math.radians(210),math.radians(330)):
    x,y=.332*math.cos(a),.332*math.sin(a)
    sphere('Rounded brass bell foot',(x,y,.205),(.075,.075,.064),1,'Static feet',16,8,None)
    cylinder('Foot upper collar',(x,y,.254),.052,.035,4,'Static feet',parent=None)

# Closed dome, flaring bell skirt and thick rounded bell mouth. The underside is hollow.
lathe('Bell enamel outer shell',[(.32,.262),(.382,.267),(.408,.289),(.421,.313),(.418,.341),(.397,.363),(.365,.387),(.336,.435),(.312,.497),(.291,.568),(.276,.631),(.270,.687),(.260,.735)],0,'Bell shell',48,open_bottom=True)
lathe('Dark hollow underside',[(.32,.262),(.310,.280),(.290,.325),(.269,.43),(.243,.56),(.225,.672),(.215,.724),(.0,.724)],5,'Bell interior',40,open_bottom=True)
lathe('Enamel shoulder dome',[(.270,.69),(.282,.735),(.269,.765),(.245,.794),(.211,.818),(.164,.835),(.109,.846),(.0,.852)],0,'Shoulder dome',48)
torus('Thin brass bell-mouth inlay',.398,.009,.363,4,'Brass trim',n=48,m=6)

# Coral collar carries a thick warm brass outer hoop over the shoulder.
lathe('Coral resonance collar',[(.267,.690),(.285,.687),(.305,.700),(.309,.721),(.303,.739),(.285,.746),(.273,.741)],2,'Resonance hoop',48)
lathe('Brass shoulder hoop',[(.266,.738),(.294,.736),(.310,.744),(.310,.756),(.295,.770),(.271,.773),(.261,.763),(.266,.738)],1,'Resonance hoop',48)
for a in (math.radians(90),math.radians(210),math.radians(330)):
    sphere('Collar champagne stud',(.306*math.cos(a),.306*math.sin(a),.713),(.011,.011,.011),4,'Hoop studs',12,6)

# Crown is a flaring brass socket with dark plum inset ribs, supporting a large cut amber jewel.
lathe('Crown brass socket',[(.065,.832),(.074,.838),(.083,.877),(.103,.929),(.115,.949),(.120,.967),(.115,.989),(.092,.994),(.083,.974),(.076,.932),(.049,.848)],1,'Crown socket',40)
torus('Crown collar highlight',.108,.011,.986,4,'Crown socket',n=40,m=6)
for a in (math.radians(90),math.radians(210),math.radians(330)):
    # Three broad tapering inset dark panels make the socket feel like crafted clockwork.
    da=.20
    v=[]
    for r,z in ((.079,.845),(.118,.953)):
        for t in (a-da,a+da):v.append((r*math.cos(t),r*math.sin(t),z))
    raw('Crown plum inset',v,[(0,1,3,2)],5,'Crown insets',smooth=False)

# Irregular-looking but deterministic eight-sided faceted amber crown, no external assets.
profile=[(.048,.977,0),(.090,1.013,.03),(.123,1.080,-.025),(.116,1.130,.04),(.087,1.175,0),(.010,1.219,0)]
n=8;v=[]
for r,z,phase in profile:
    for j in range(n):
        t=j*math.tau/n+phase;v.append((r*math.cos(t),r*math.sin(t),z))
f=[]
for k in range(len(profile)-1):
    for j in range(n):
        q=(k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j)
        if k in (1,2):f.extend([(q[0],q[1],q[2]),(q[0],q[2],q[3])])
        else:f.append(q)
f.extend([tuple(reversed(range(n))),tuple((len(profile)-1)*n+j for j in range(n))])
gem=raw('Cut amber crown crystal',v,f,6,'Amber crown',smooth=False)
uv=gem.data.uv_layers.active
for p in gem.data.polygons:
    for li in p.loop_indices:
        co=gem.data.vertices[gem.data.loops[li].vertex_index].co
        u=(math.atan2(co.y,co.x)+math.pi)/math.tau
        v=(co.z-.977)/.242
        uv.data[li].uv=((2+.03+.94*u)/4,(1+.03+.94*v)/2)
# Sparse light facets provide clear crystal cuts under game lighting without transparent layers.
gem.data.materials.append(materials[7])
for p in gem.data.polygons:
    if p.center.z>1.145 and p.center.y>.01 and p.index%3==0:
        p.material_index=1
        uv=gem.data.uv_layers.active
        for li in p.loop_indices:
            co=gem.data.vertices[gem.data.loops[li].vertex_index].co
            uv.data[li].uv=((3+.5+co.x*.78)/4,(1+.5+(co.z-1.09)*.78)/2)

# A small clapper is visible only beneath the hollow bell mouth.
cylinder('Clapper stem',(0,0,.325),.012,.22,1,'Bell interior',n=12)
sphere('Clapper weight',(0,0,.232),(.043,.043,.04),1,'Bell interior',16,8)

for (name,parent),objs in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]
    if len(objs)>1:bpy.ops.object.join()
    bpy.context.object.name=name
bpy.context.view_layer.update()
for o in bpy.context.scene.objects:
    if o.type=='MESH':o.data.calc_loop_triangles()
stats={'triangles':sum(len(o.data.loop_triangles) for o in bpy.context.scene.objects if o.type=='MESH'),'mesh_objects':sum(o.type=='MESH' for o in bpy.context.scene.objects),'materials':len(materials),'textures':len(images),'Aim':[0,0,.18],'Muzzle_world':[0,0,1.19]}
(OUT/'build_stats.json').write_text(json.dumps(stats,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_shock.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_shock.glb'),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False,export_apply=True)
print('BELL_BUILD',stats)
