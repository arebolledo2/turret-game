"""Cinder Puffer: deterministic standalone Blender 5.2 builder.
Metres, Z up, +Y front. One Body pivot; no animation or external assets.
"""
from pathlib import Path
import math, json
import bpy
import numpy as np
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
OUT=Path(__file__).resolve().parent
OUT.mkdir(parents=True,exist_ok=True)
C=.72; R=.355; N=1024
rng=np.random.default_rng(738)
yy,xx=np.mgrid[0:N,0:N].astype(np.float32)
u,v=xx/N,yy/N

def make_image(name,rgb):
    im=bpy.data.images.new(name,N,N,alpha=False)
    im.colorspace_settings.name='sRGB'
    pixels=np.ones((N,N,4),np.float32);pixels[:,:,:3]=np.clip(rgb,0,1)
    im.pixels.foreach_set(pixels.ravel())
    im.filepath_raw=str(OUT/(name+'.png'));im.file_format='PNG';im.save();im.pack()
    return im

# Clean pristine enamel; slight broad colour variation, no unrelated grime.
tone=.98+.045*np.sin(u*math.tau)*np.cos(v*math.tau)+.015*np.sin(v*math.tau*3)
tone+=rng.normal(0,.004,(N,N))
coral_img=make_image('coral_enamel_generated',tone[:,:,None]*np.array([.98,.265,.225])[None,None,:])
palette=np.array([[.04,.61,.58],[.98,.63,.18],[.99,.93,.67],[.065,.125,.145],[.62,.21,.91]])
idx=np.minimum((u*len(palette)).astype(int),len(palette)-1);local=u*len(palette)-idx
tone=1+.03*np.cos(v*math.tau)+.025*np.sin(local*math.tau)+rng.normal(0,.003,(N,N))
finish_img=make_image('finishes_generated',palette[idx]*tone[:,:,None])

# Warm pressure optic: red top lip, luminous orange lower bowl, jewel facets.
dx,dz=(u-.5)*2,(v-.5)*2;rr=np.hypot(dx,dz);angle=np.arctan2(dz,dx)
gradient=np.clip((1-dz)*.5,0,1)
optic_rgb=np.zeros((N,N,3),np.float32)
optic_rgb[:,:,0]=.94+.045*gradient
optic_rgb[:,:,1]=.07+.55*gradient**1.25
optic_rgb[:,:,2]=.025+.045*(1-gradient)
facets=.97+.035*np.cos(angle*9+.4)+.018*np.cos(rr*22+angle*3)
optic_rgb*=facets[:,:,None]
rim=np.clip((rr-.83)/.16,0,1)
optic_rgb*=1-.32*rim[:,:,None]
shine=((dx+.33)**2+(dz-.39)**2)<.14**2
optic_rgb[shine]=[1,.93,.80]
small=((dx-.47)/.055)**2+((dz-.49)/.09)**2<1
optic_rgb[small]=[1,.81,.82]
optic_img=make_image('ember_optic_generated',optic_rgb)

mats={};tiles={}
def material(name,img,rough=.3,metal=0,glow=0,tile=None):
    m=bpy.data.materials.new(name);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal
    tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=img
    m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    if glow:
        m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Emission Color']);bs.inputs['Emission Strength'].default_value=glow
    mats[name]=m
    if tile is not None:tiles[name]=tile
    return m

coral=material('01_Coral_vessel',coral_img,.29,.10)
teal=material('02_Teal_cap',finish_img,.25,.17,tile=0)
gold=material('03_Brass_pressure_fittings',finish_img,.27,.65,tile=1)
cream=material('04_Ivory_optic_frame',finish_img,.28,.04,tile=2)
dark=material('05_Charcoal_recesses',finish_img,.38,.05,tile=3)
purple=material('06_Amethyst_indicators',finish_img,.22,.10,.08,tile=4)
optic=material('07_Orange_red_optic',optic_img,.25,0,.15)
optic.node_tree.nodes.get('Principled BSDF').inputs['Specular IOR Level'].default_value=0
root=bpy.data.objects.new('CinderPuffer',None);bpy.context.collection.objects.link(root)
body=bpy.data.objects.new('Body',None);bpy.context.collection.objects.link(body)
body.parent=root;body.location=(0,0,C)

def project_uv(o):
    while o.data.uv_layers:o.data.uv_layers.remove(o.data.uv_layers[0])
    layer=o.data.uv_layers.new(name='UVMap')
    for p in o.data.polygons:
        axis=max(range(3),key=lambda i:abs(p.normal[i]))
        for li in p.loop_indices:
            q=o.data.vertices[o.data.loops[li].vertex_index].co
            a,b=((q.y,q.z),(q.x,q.z),(q.x,q.y))[axis]
            uv=(a*1.8+.5,b*1.8+.5)
            if o.data.materials[0].name in tiles:
                t=tiles[o.data.materials[0].name]
                uv=((t+.045+.91*(uv[0]%1))/5,.045+.91*(uv[1]%1))
            layer.data[li].uv=uv

def finish(o,name,m,custom=False):
    o.name=name;o.data.materials.append(m)
    if not custom:project_uv(o)
    for p in o.data.polygons:p.use_smooth=True
    o.parent=body;o.location.z-=C
    return o

def mesh(name,verts,faces,m,custom=False):
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o)
    return finish(o,name,m,custom)

def sphere(name,pos,scale,m,segments=32,rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1,location=pos)
    o=bpy.context.object;o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,m)

def loft(name,origin,direction,profile,m,n=24):
    """Closed radial profile around an arbitrary axis; supports genuinely hollow plugs."""
    d=Vector(direction).normalized();right=d.cross(Vector((0,0,1)))
    if right.length<.01:right=Vector((1,0,0))
    right.normalize();up=right.cross(d).normalized();origin=Vector(origin)
    verts=[];faces=[]
    for axial,r in profile:
        for k in range(n):
            a=math.tau*k/n
            verts.append(tuple(origin+d*axial+right*(r*math.cos(a))+up*(r*math.sin(a))))
    for j in range(len(profile)):
        q=(j+1)%len(profile)
        for k in range(n):faces.append((j*n+k,j*n+(k+1)%n,q*n+(k+1)%n,q*n+k))
    return mesh(name,verts,[tuple(reversed(f)) for f in faces],m)

# Dark structural shell visible through actual narrow gaps between coral armour panels.
sphere('Structural_pressure_shell',(0,0,C),(.340,.340,.340),dark,24,12)
latitudes=[-math.pi/2+.025,-.42,.32,math.pi/2-.025]
for band in range(3):
    for sector in range(4):
        a0=math.pi/4+sector*math.pi/2+.017;a1=math.pi/4+(sector+1)*math.pi/2-.017
        l0=latitudes[band]+(.010 if band>0 else 0)
        l1=latitudes[band+1]-(.010 if band<2 else 0)
        verts=[];faces=[];nx=8;ny=5
        for j in range(ny+1):
            lat=l0+(l1-l0)*j/ny
            for k in range(nx+1):
                a=a0+(a1-a0)*k/nx
                # Rounded bevel lip dims into the recess near each panel border.
                edge=min(j,ny-j,k,nx-k)
                rad=R-(.0016 if edge==0 else 0)
                verts.append((rad*math.sin(a)*math.cos(lat),rad*math.cos(a)*math.cos(lat),C+rad*math.sin(lat)))
        for j in range(ny):
            for k in range(nx):
                p=j*(nx+1)+k;faces.append((p,p+1,p+nx+2,p+nx+1))
        mesh('Coral_shell_panel_%d_%d'%(band,sector),verts,[tuple(reversed(f)) for f in faces],coral)

# Broad brass neck and thick teal cap, with a rounded raised crown.
loft('Brass_cap_collar',(0,0,1.037),(0,0,1),
     [(-.015,.131),(.027,.131),(.036,.12),(.036,.093),(-.015,.093)],gold,32)
loft('Teal_pressure_cap',(0,0,1.06),(0,0,1),
     [(0,.073),(.025,.094),(.065,.111),(.106,.119),(.135,.123),(.145,.123),(.148,.097),(.002,.048)],teal,32)
loft('Teal_cap_roll',(0,0,1.19),(0,0,1),
     [(-.007,.114),(.003,.126),(.017,.124),(.022,.110)],teal,32)
sphere('Teal_cap_crown',(0,0,1.205),(.105,.105,.075),teal,24,10)
# A small angled brass pressure pin peeks from behind the cap.
loft('Cap_pressure_pin',(.115,-.035,1.035),(.38,0,.925),
     [(0,.017),(.10,.017),(.10,.027),(.118,.027),(.118,.012),(0,.012)],gold,12)

# Six large barrel fittings. Flared gold lips and an inner bore are real geometry.
directions=[(.88,-.07,.47),(-.88,-.07,.47),(.69,.67,.24),(-.84,-.25,-.08),(.56,.60,-.58),(-.88,.10,-.46)]
for i,direction in enumerate(directions):
    d=Vector(direction).normalized();p=Vector((0,0,C))+d*.329
    loft('Pressure_socket_%d'%i,p,d,[(z,r*1.22) for z,r in [(0,.053),(.027,.058),(.039,.053),(.039,.041),(0,.041)]],gold,16)
    loft('Hollow_pressure_plug_%d'%i,p+d*.026,d,
         [(z,r*1.22) for z,r in [(0,.042),(.095,.042),(.095,.050),(.117,.050),(.123,.045),(.123,.031),(.014,.031),(0,.035)]],gold,16)
    # Recessed dark well at the bottom of each bore.
    loft('Pressure_bore_%d'%i,p+d*.04,d,[(0,.036),(.003,.036),(.003,.001),(0,.001)],dark,12)

# Thick ivory eye frame, tilted-free +Y front in the same readable language as the concept.
eye_center=Vector((-.085,.351,C-.012));eye_r=.14
loft('Ivory_optic_bezel',eye_center,(0,1,0),
     [(z,r*1.12) for z,r in [(-.017,.143),(-.005,.157),(.017,.160),(.037,.148),(.045,.132),(.035,.122),(.005,.121),(-.017,.130)]],cream,40)
loft('Red_optic_inner_rim',eye_center,(0,1,0),
     [(z,r*1.12) for z,r in [(.006,.124),(.031,.126),(.04,.121),(.038,.114),(.006,.116)]],coral,32)
verts=[tuple(eye_center+Vector((0,.078,0)))];faces=[];rings=7;n=40
for j in range(1,rings+1):
    r=eye_r*j/rings
    for k in range(n):
        a=math.tau*k/n
        verts.append(tuple(eye_center+Vector((r*math.cos(a),.027+.051*math.sqrt(max(0,1-(r/eye_r)**2)),r*math.sin(a)))))
for k in range(n):faces.append((0,1+(k+1)%n,1+k))
for j in range(rings-1):
    for k in range(n):
        a=1+j*n+k;b=1+j*n+(k+1)%n;c=1+(j+1)*n+(k+1)%n;d=1+(j+1)*n+k
        faces.append((d,c,b,a))
o=mesh('Orange_red_glass_optic',verts,faces,optic,True)
layer=o.data.uv_layers.new(name='UVMap')
for p in o.data.polygons:
    for li in p.loop_indices:
        q=o.data.vertices[o.data.loops[li].vertex_index].co-eye_center
        layer.data[li].uv=(.5+q.x/(eye_r*2),.5+q.z/(eye_r*2))

# Rounded teal/amethyst status jewels, symmetric enough to read from gameplay distance.
for i,(x,z,r,m) in enumerate([(-.078,.959,.024,teal),(-.19,.928,.017,purple),(.035,.923,.017,purple),
                           (-.09,.463,.023,teal),(-.205,.49,.017,purple),(.025,.489,.017,purple)]):
    front=math.sqrt(max(.005,R*R-x*x-(z-C)**2))+.005
    sphere('Status_jewel_%d'%i,(x,front,z),(r,.012,r),m,12,6)

# Brass bottom neck, polished coral bulb, and a small coral relief fin.
loft('Bottom_brass_collar',(0,0,.358),(0,0,1),[(-.042,.080),(.013,.080),(.023,.069),(.023,.040),(-.042,.04)],gold,24)
sphere('Bottom_coral_pressure_bulb',(0,0,.244),(.078,.078,.080),coral,20,10)
sphere('Coral_relief_fin',(.116,-.04,.367),(.040,.028,.095),coral,12,6)

# A rear service plate is invented from the same brass/coral construction.
loft('Rear_service_rim',(0,-.346,C),(0,-1,0),[(0,.066),(.017,.073),(.023,.062),(.017,.047),(0,.047)],gold,16)
sphere('Rear_teal_service_plate',(0,-.36,C),(.047,.015,.047),teal,16,8)
# Low-cost dark round fastener heads on the cap and lower collar.
for z,rad in [(1.048,.132),(.337,.080)]:
    for degrees in (0,90,180,270):
        a=math.radians(degrees)
        sphere('Collar_dark_rivet',(rad*math.sin(a),rad*math.cos(a),z),(.005,.005,.005),dark,8,4)

# Seven rigid meshes under Body; one shared finish/material per object.
for m in mats.values():
    group=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.materials[0]==m]
    if not group:continue
    bpy.ops.object.select_all(action='DESELECT')
    for o in group:o.select_set(True)
    bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join()
    bpy.context.object.name=m.name[3:]+'_mesh'

bpy.context.view_layer.update()
stats={'triangles':0,'mesh_objects':0,'materials':len(mats),'textures':3,'animations':0}
for o in bpy.context.scene.objects:
    if o.type=='MESH':o.data.calc_loop_triangles();stats['triangles']+=len(o.data.loop_triangles);stats['mesh_objects']+=1
root['asset']='Cinder Puffer';root['front']='+Y';body['motion']='Single rigid hover pivot; no animation clips.'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_exploder.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_exploder.glb'),export_format='GLB',export_yup=True,
    export_animations=False,export_cameras=False,export_lights=False,export_apply=True)
(OUT/'build_stats.json').write_text(json.dumps(stats,indent=2))
print('FINAL_STATS',json.dumps(stats))
