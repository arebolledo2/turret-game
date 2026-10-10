"""Bulwark Hermit: heavy six-legged enamel helmet, root-level physical hip hinges."""
from pathlib import Path
import math,json
import bpy,bmesh,numpy as np
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
OUT=Path(__file__).resolve().parent;N=1024;rng=np.random.default_rng(373)
COL=[(.055,.70,.62),(.91,.67,.25),(.15,.145,.225),(.98,.25,.17),(1,.77,.045),(.055,.22,.96),(.59,.63,.70),(.11,.075,.19)]
ROUGH=[.32,.27,.42,.23,.16,.15,.34,.40];METAL=[.13,.77,.28,.06,.13,.12,.63,.23]
buffers=[np.ones((N,N,4),np.float32) for _ in range(4)]
for i,c in enumerate(COL):
    a,b=slice(i//4*512,(i//4+1)*512),slice(i%4*256,(i%4+1)*256)
    v,u=np.mgrid[0:512,0:256].astype(np.float32);v/=512;u/=256;noise=rng.normal(0,1,(512,256)).astype(np.float32)
    broad=.014*np.sin(u*8+v*7)+.008*np.cos(v*11-u*3)
    brush=.012*np.sin(v*740+u*4) if i in (1,6) else .0015*np.sin(u*790+v*15)
    buffers[0][a,b,:3]=np.clip(np.array(c)*(1+broad+brush+noise*.0014)[:,:,None],0,1)
    buffers[1][a,b,0]=1;buffers[1][a,b,1]=ROUGH[i]+broad*.4;buffers[1][a,b,2]=METAL[i]
    buffers[2][a,b,:3]=np.stack((.5+noise*.0005,.5+noise*.0005,np.ones_like(noise)),axis=-1)
    buffers[3][a,b,:3]=0
    if i in (3,4,5):buffers[3][a,b,:3]=np.array(c)*(.22+.08*np.sin(u*8+v*5)**2)[:,:,None]
images=[]
for name,buf,space in zip(('bulwark_color_atlas','bulwark_orm_atlas','bulwark_micro_normal','bulwark_optic_fire'),buffers,('sRGB','Non-Color','Non-Color','sRGB')):
    im=bpy.data.images.new(name,width=N,height=N,alpha=True);im.colorspace_settings.name=space;im.pixels.foreach_set(buf.ravel());im.filepath_raw=str(OUT/(name+'.png'));im.file_format='PNG';im.save();im.pack();images.append(im)
materials=[]
for i,name in enumerate(('Lagoon helmet enamel','Polished warm brass','Slate hoof armour','Coral status jewel','Amber face optics','Sapphire forehead jewel','Steel teeth and rivets','Plum hinge recess')):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*COL[i],1);n,l=m.node_tree.nodes,m.node_tree.links;p=n.get('Principled BSDF')
    t=n.new('ShaderNodeTexImage');t.image=images[0];l.new(t.outputs['Color'],p.inputs['Base Color'])
    t=n.new('ShaderNodeTexImage');t.image=images[1];sp=n.new('ShaderNodeSeparateColor');l.new(t.outputs['Color'],sp.inputs['Color']);l.new(sp.outputs['Green'],p.inputs['Roughness']);l.new(sp.outputs['Blue'],p.inputs['Metallic'])
    t=n.new('ShaderNodeTexImage');t.image=images[2];nm=n.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.13;l.new(t.outputs['Color'],nm.inputs['Color']);l.new(nm.outputs['Normal'],p.inputs['Normal'])
    p.inputs['Coat Weight'].default_value=.23 if i in (0,3,4,5) else .07;p.inputs['Coat Roughness'].default_value=.2
    if i in (3,4,5):
        t=n.new('ShaderNodeTexImage');t.image=images[3];l.new(t.outputs['Color'],p.inputs['Emission Color']);p.inputs['Emission Strength'].default_value=.5
    materials.append(m)
def empty(name,loc):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=loc;return o
body=empty('Body',(0,0,.52));groups={};hinges={}
def uvmap(o,i):
    uv=o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap');centre=Vector(tuple((min(v.co[k] for v in o.data.vertices)+max(v.co[k] for v in o.data.vertices))/2 for k in range(3)))
    for p in o.data.polygons:
        k=max(range(3),key=lambda j:abs(p.normal[j]));ij=([1,2],[0,2],[0,1])[k]
        for li in p.loop_indices:
            v=o.data.vertices[o.data.loops[li].vertex_index].co-centre
            uv.data[li].uv=((i%4+.03+.94*(.5+v[ij[0]]*.78))/4,(i//4+.03+.94*(.5+v[ij[1]]*.78))/2)
def finish(o,name,mat,group,parent=body,smooth=True):
    o.name=name;o.data.materials.append(materials[mat]);uvmap(o,mat)
    for p in o.data.polygons:p.use_smooth=smooth
    bpy.context.view_layer.update();o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted();groups.setdefault((group,parent),[]).append(o);return o
def bevel(o,w=.008,s=2):
    bpy.context.view_layer.objects.active=o;mod=o.modifiers.new('Soft armour edges','BEVEL');mod.width=w;mod.segments=s;bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=o.modifiers.new('Weighted bevel normals','WEIGHTED_NORMAL');mod.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=mod.name)
def raw(name,v,f,mat,group,parent=body,edge=0,smooth=True):
    me=bpy.data.meshes.new(name);me.from_pydata(v,[],f);me.update();bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o)
    if edge:bevel(o,edge,1)
    return finish(o,name,mat,group,parent,smooth)
def box(name,loc,size,mat,group,parent=body,edge=.014,segments=2):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);bevel(o,edge,segments);return finish(o,name,mat,group,parent)
def sphere(name,loc,scale,mat,group,parent=body,n=24,rings=12):
    n=min(n,16);rings=min(rings,8)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=n,ring_count=rings,radius=1,location=loc);o=bpy.context.object;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,mat,group,parent)
def cyl(name,loc,r,d,mat,group,parent=body,axis=(0,0,1),n=24):
    n=min(n,20)
    bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=d,location=loc);o=bpy.context.object;bevel(o,min(.007,d*.16),1);o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler();return finish(o,name,mat,group,parent)
def lathe(name,prof,mat,group,parent=body,n=48,yscale=1):
    v=[(r*math.cos(j*math.tau/n),r*math.sin(j*math.tau/n)*yscale,z) for r,z in prof for j in range(n)]
    f=[(k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j) for k in range(len(prof)-1) for j in range(n)]
    f.extend([tuple(reversed(range(n))),tuple((len(prof)-1)*n+j for j in range(n))]);return raw(name,v,f,mat,group,parent)
def rod(name,a,b,r,mat,group,parent=body,n=16):
    a,b=Vector(a),Vector(b);return cyl(name,(a+b)/2,r,(b-a).length,mat,group,parent,b-a,n)
def tube(name,path,r,mat,group,parent=body,n=8):
    v=[]
    for j,p in enumerate(path):
        tangent=Vector(path[min(j+1,len(path)-1)])-Vector(path[max(j-1,0)])
        tangent.normalize();e=tangent.cross(Vector((1,0,0)) if abs(tangent.x)<.9 else Vector((0,1,0))).normalized();g=tangent.cross(e)
        for k in range(n):v.append(Vector(p)+r*(e*math.cos(k*math.tau/n)+g*math.sin(k*math.tau/n)))
    f=[(j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k) for j in range(len(path)-1) for k in range(n)]
    f.extend([tuple(reversed(range(n))),tuple((len(path)-1)*n+k for k in range(n))]);return raw(name,v,f,mat,group,parent)

# Solid rounded helmet dome and darker lower shell/chassis.
v=[];n=48;m=12
for k in range(m+1):
    t=k*math.pi/2/m
    for j in range(n):
        a=j*math.tau/n;v.append((.455*math.cos(t)*math.cos(a),.415*math.cos(t)*math.sin(a),.505+.450*math.sin(t)))
f=[(k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j) for k in range(m) for j in range(n)]
f.append(tuple(reversed(range(n))));raw('Rounded teal helmet dome',v,f,0,'Helmet shell')
sphere('Lower enamel body',(0,0,.336),(.402,.377,.239),0,'Lower body',n=24,rings=12)
sphere('Dark undercarriage',(0,-.025,.232),(.335,.317,.125),7,'Undercarriage',n=16,rings=8)
lathe('Belt recessed seam',[(.423,.462),(.456,.46),(.462,.474),(.458,.487),(.43,.49)],7,'Undercarriage',n=32,yscale=.91)
lathe('Heavy horizontal brass belt',[(.433,.473),(.470,.473),(.484,.486),(.487,.518),(.471,.540),(.442,.540),(.432,.523)],1,'Brass armour',n=48,yscale=.91)

# Broad front-to-back brass crown strap follows the actual elliptical dome.
n=41;v=[]
for offset in (0,.020):
    for j in range(n):
        t=-math.pi/2+j*math.pi/(n-1)
        for x in (-.064,.064):
            f=math.sqrt(1-(x/.455)**2)
            v.append((x,(.421+offset)*math.sin(t)*f,.505+(.456+offset)*math.cos(t)*f))
f=[]
for j in range(n-1):
    a=2*j;b=2*(j+1);q=2*n
    f.extend([(a,b,b+1,a+1),(q+a,q+a+1,q+b+1,q+b),(a,q+a,q+b,b),(a+1,b+1,q+b+1,q+a+1)])
f.extend([(0,1,2*n+1,2*n),(2*n-2,4*n-2,4*n-1,2*n-1)])
raw('Brass helmet crown strap',v,f,1,'Brass armour',edge=.004)
for t in (-.9,-.4,.18,.65,1.10):
    p=Vector((0,.442*math.sin(t),.505+.478*math.cos(t)))
    sphere('Crown domed steel rivet',p,(.014,.014,.014),6,'Armour rivets',n=8,rings=4)
for a in (math.pi/6,math.pi/2,5*math.pi/6,7*math.pi/6,3*math.pi/2,11*math.pi/6):
    p=Vector((.489*math.cos(a),.445*math.sin(a),.510))
    sphere('Belt brass rivet',p,(.014,.014,.014),1,'Armour rivets',n=8,rings=4)

# Fine inset helmet panel seams preserve large calm enamel surfaces.
for x in (-.17,-.265,.17,.265):
    s=math.sqrt(1-(x/.455)**2);path=[]
    for j in range(13):
        t=-.23+j*.94/12;path.append((x,.417*math.sin(t)*s,.505+.452*math.cos(t)*s))
    o=tube('Helmet panel groove',path,.0028,7,'Panel seams',n=4)

# Blue forehead lock, status jewel and lower pair of bright amber eyes.
axis=(0,1,0)
cyl('Forehead dark optic bed',(0,.449,.50),.094,.028,7,'Forehead optics',axis=axis,n=32)
cyl('Forehead brass bezel',(0,.473,.50),.091,.049,1,'Forehead optics',axis=axis,n=32)
cyl('Forehead inner dark bezel',(0,.500,.50),.057,.009,7,'Forehead optics',axis=axis,n=28)
sphere('Forehead sapphire lens',(0,.511,.50),(.045,.018,.045),5,'Forehead optics',n=24,rings=12)
sphere('Sapphire lens glint',(-.012,.527,.518),(.008,.003,.010),6,'Forehead optics',n=12,rings=6)
status=Vector((-.19,.297,.742));normal=Vector((status.x/.455**2,status.y/.415**2,(status.z-.505)/.45**2)).normalized()
cyl('Status light brass rim',status,.047,.018,1,'Status optics',axis=normal,n=28)
sphere('Coral status light',status+normal*.013,(.034,.034,.034),3,'Status optics',n=20,rings=10)
sphere('Status light glint',status+normal*.041+Vector((-.005,0,.010)),(.007,.005,.007),6,'Status optics',n=12,rings=6)

# Friendly armoured lower mask, inset dark border and two hanging steel mandibles.
box('Lower face dark gasket',(0,.335,.270),(.350,.108,.180),7,'Face mask',edge=.045)
box('Teal armoured face',(0,.377,.284),(.346,.083,.173),0,'Face mask',edge=.042)
for x in (-.118,.118):
    cyl('Amber eye dark setting',(x,.422,.30),.041,.018,7,'Face optics',axis=axis,n=24)
    sphere('Amber face eye',(x,.434,.30),(.032,.014,.032),4,'Face optics',n=20,rings=10)
    sphere('Amber eye glint',(x-.009,.446,.314),(.005,.003,.006),6,'Face optics',n=12,rings=6)
for x in (-.081,.081):
    tooth=box('Short hanging steel mandible',(x,.417,.172),(.028,.038,.115),6,'Mandibles',edge=.011);tooth.rotation_euler.x=math.radians(-12)
    cap=box('Mandible dark tip',(x,.425,.145),(.025,.033,.071),2,'Mandibles',edge=.010);cap.rotation_euler.x=math.radians(-12)
path=[(.30*math.cos(t),.245+.055*math.sin(t),.322-.15*math.sin(t)) for t in np.linspace(0,math.pi,25)]
tube('Lower chin brass arc',path,.018,1,'Brass armour',n=8)

# Six explicit supporting limbs: root-level, identity pivots at the hips.
for side,s in (('L',-1),('R',1)):
    for i,y in enumerate((.24,0,-.24)):
        hip=Vector((s*.330,y,.315));knee=Vector((s*.438,y+(1-i)*.045,.246));foot=Vector((s*.510,y+(1-i)*.090,.106))
        name=f'Leg_{side}_{i}';pivot=empty(name,hip)
        hinges[name]={'position':list(hip),'hinge_axis_blender':[0,1,0],'lift_sign_blender_y':1 if side=='L' else -1,'stride_sign_blender_z':-1 if side=='L' else 1}
        # Body-side socket stays with the shell; rotating metal cap belongs to limb.
        sphere('Fixed dark hip socket',hip,(.061,.059,.061),7,'Undercarriage',n=12,rings=6)
        cyl('Hip dark hinge',hip,.059,.108,7,name,pivot,(0,1,0),16)
        cyl('Hip front brass cap',hip+Vector((0,.061,0)),.055,.020,1,name,pivot,(0,1,0),16)
        # Rounded heavy calf guard slopes down from the hip, rather than lying flat.
        top=hip+Vector((s*.032,0,-.008));bottom=foot+Vector((0,0,.037))
        calf=sphere('Heavy enamel limb armour',(top+bottom)/2,(.068,.071,(top-bottom).length/2+.014),0,name,pivot,n=20,rings=10)
        calf.rotation_euler=(top-bottom).to_track_quat('Z','Y').to_euler()
        # Lower golden cuff perpendicular to the tapered calf.
        rod('Calf brass cuff',foot+Vector((0,0,.045)),foot+Vector((-s*.019,0,.075)),.074,1,name,pivot,n=16)
        sphere('Slate pointed supporting hoof',foot,(.075,.075,.095),2,name,pivot,n=14,rings=7)
        panel=box('Hoof steel armour panel',foot+Vector((s*.058,.008,-.002)),(.013,.042,.060),6,name,pivot,edge=.007,segments=1)
        panel.rotation_euler.y=s*math.radians(-12)
        sphere('Small limb brass pin',knee+Vector((s*.062,0,.002)),(.009,.008,.009),1,name,pivot,n=8,rings=4)

# One merged rigid mesh per limb; main-body groups remain parented to Body.
combined=[]
for group in ('Forehead optics','Status optics','Face optics'):
    combined.extend(groups.pop((group,body)))
groups[('Jewel optics',body)]=combined
for (name,parent),objs in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]
    if len(objs)>1:bpy.ops.object.join()
    bpy.context.object.name=name.replace('Leg_','Limb_') if name.startswith('Leg_') else name
bpy.context.view_layer.update()
for o in bpy.context.scene.objects:
    if o.type=='MESH':o.data.calc_loop_triangles()
stats={'triangles':sum(len(o.data.loop_triangles) for o in bpy.context.scene.objects if o.type=='MESH'),'mesh_objects':sum(o.type=='MESH' for o in bpy.context.scene.objects),'materials':len(materials),'textures':len(images),'Body_position':[0,0,.52],'leg_hinges':hinges}
(OUT/'build_stats.json').write_text(json.dumps(stats,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_tank.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_tank.glb'),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False,export_apply=True)
print('BULWARK_BUILD',stats)
