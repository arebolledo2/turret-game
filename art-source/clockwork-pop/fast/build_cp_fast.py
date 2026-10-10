"""Skipper Moth, deterministic Blender 5.2 asset builder.
Z up, +Y forward. Identity Wing_L/R hinges flap about Blender Y (Godot Z).
"""
from pathlib import Path
import math,json
import bpy
import numpy as np
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
OUT=Path(__file__).resolve().parent;OUT.mkdir(parents=True,exist_ok=True)
C=.635;N=1024;rng=np.random.default_rng(933)
yy,xx=np.mgrid[0:N,0:N].astype(np.float32);u,v=xx/N,yy/N

def image(name,rgb):
    im=bpy.data.images.new(name,N,N,alpha=False);im.colorspace_settings.name='sRGB'
    arr=np.ones((N,N,4),np.float32);arr[:,:,:3]=np.clip(rgb,0,1)
    im.pixels.foreach_set(arr.ravel());im.filepath_raw=str(OUT/(name+'.png'))
    im.file_format='PNG';im.save();im.pack();return im

palette=np.array([[.98,.30,.25],[.99,.66,.20],[.065,.12,.13],[.43,.08,.74]])
idx=np.minimum((u*4).astype(int),3);local=u*4-idx
tone=1+.045*np.cos(v*math.tau)+.03*np.sin(local*math.tau)+rng.normal(0,.003,(N,N))
atlas=image('body_finishes_generated',palette[idx]*tone[:,:,None])

def catmull(points,per=6):
    pts=[np.array(p,float) for p in points];out=[];count=len(pts)
    for i in range(count):
        a,b,c,d=pts[(i-1)%count],pts[i],pts[(i+1)%count],pts[(i+2)%count]
        for j in range(per):
            t=j/per
            q=.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t**3)
            out.append(tuple(q))
    return out

upper=catmull([(0,0),(.125,.22),(.36,.49),(.51,.555),(.566,.48),(.53,.285),(.36,.035),(.115,-.018)],8)
lower=catmull([(0,-.012),(.13,-.125),(.32,-.19),(.41,-.12),(.38,-.015),(.15,.045)],6)

def wing_texture(name,outline,bounds,hind=False):
    x0,x1,z0,z1=bounds
    wx=x0+u*(x1-x0);wz=z0+v*(z1-z0)
    distance=np.ones((N,N),np.float32)*100
    for i,p in enumerate(outline):
        q=outline[(i+1)%len(outline)]
        ex,ez=q[0]-p[0],q[1]-p[1]
        t=np.clip(((wx-p[0])*ex+(wz-p[1])*ez)/(ex*ex+ez*ez+1e-10),0,1)
        distance=np.minimum(distance,np.hypot(wx-(p[0]+ex*t),wz-(p[1]+ez*t)))
    # Pearl aqua, with dark teal root petals and broad translucent-looking fans.
    radial=np.hypot(wx,wz)
    green=.68+.13*np.clip(radial/.60,0,1)
    red=.22+.28*np.clip(radial/.65,0,1)
    blue=.63+.11*np.clip(radial/.60,0,1)
    rgb=np.stack([red,green,blue],axis=-1)
    angles=np.arctan2(wz+.01,wx+.025)
    stripes=.965+.035*np.sin(angles*13+radial*5)
    rgb*=stripes[:,:,None]
    # Fine veins fan from the root: image detail rather than small mesh struts.
    vein_distance=np.ones_like(wx)*10
    endpoints=[(.49,.49),(.50,.32),(.42,.13),(.31,.05)] if not hind else [(.34,-.14),(.34,-.07),(.29,.005)]
    for ex,ez in endpoints:
        t=np.clip((wx*ex+wz*ez)/(ex*ex+ez*ez),0,1)
        vein_distance=np.minimum(vein_distance,np.hypot(wx-ex*t,wz-ez*t))
    veins=np.exp(-(vein_distance/.0025)**2)*.20
    rgb=rgb*(1-veins[:,:,None])+np.array([.65,.94,.83])*veins[:,:,None]
    edge=np.clip((.012-distance)/.005,0,1)
    edge_color=np.array([.98,.925,.69] if hind else [.78,.99,.88])
    rgb=rgb*(1-edge[:,:,None])+edge_color*edge[:,:,None]
    rgb+=rng.normal(0,.0015,(N,N,1))
    return image(name,rgb)

upper_bounds=(-.035,.60,-.04,.59);lower_bounds=(-.03,.445,-.22,.075)
upper_im=wing_texture('forewing_generated',upper,upper_bounds)
lower_im=wing_texture('hindwing_generated',lower,lower_bounds,True)

dx,dz=(u-.5)*2,(v-.5)*2;rr=np.hypot(dx,dz);a=np.arctan2(dz,dx)
color=np.zeros((N,N,3),np.float32)
radial=np.clip(rr,0,1)
color[:,:,0]=.24+.23*radial+.035*np.sin(a*8+rr*10)
color[:,:,1]=.008+.08*radial**2
color[:,:,2]=.53+.25*radial
edge=np.clip((rr-.85)/.15,0,1);color*=1-.35*edge[:,:,None]
shine=((dx+.35)**2+(dz-.4)**2)<.16**2;color[shine]=[1,.99,1]
shine2=((dx-.5)**2+(dz-.39)**2)<.10**2;color[shine2]=[.65,.38,.95]
eye_im=image('violet_optic_generated',color)

mats={};tiles={}
def material(name,img,rough=.3,metal=0,glow=0,tile=None):
    m=bpy.data.materials.new(name);m.use_nodes=True;bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal
    tx=m.node_tree.nodes.new('ShaderNodeTexImage');tx.image=img
    m.node_tree.links.new(tx.outputs['Color'],bs.inputs['Base Color'])
    if glow:m.node_tree.links.new(tx.outputs['Color'],bs.inputs['Emission Color']);bs.inputs['Emission Strength'].default_value=glow
    mats[name]=m
    if tile is not None:tiles[name]=tile
    return m

coral=material('01_Coral_enamel',atlas,.28,.10,tile=0)
gold=material('02_Warm_brass',atlas,.27,.62,tile=1)
dark=material('03_Charcoal_tail',atlas,.38,.05,tile=2)
purple=material('04_Violet_socket',atlas,.24,.10,tile=3)
fore=material('05_Pearl_aqua_forewing',upper_im,.42,0)
hind=material('06_Pearl_aqua_hindwing',lower_im,.43,0)
eye=material('07_Violet_optic',eye_im,.31,0,.12)
for m in (fore,hind,eye):m.node_tree.nodes.get('Principled BSDF').inputs['Specular IOR Level'].default_value=0

root=bpy.data.objects.new('SkipperMoth',None);bpy.context.collection.objects.link(root)
body=bpy.data.objects.new('Body',None);bpy.context.collection.objects.link(body);body.parent=root;body.location=(0,0,C)
hinges={}
for label,side in [('L',1),('R',-1)]:
    o=bpy.data.objects.new('Wing_'+label,None);bpy.context.collection.objects.link(o)
    o.parent=body;o.location=(side*.102,-.07,0);o.rotation_euler=(0,0,0)
    o['flap_axis']='Blender local Y / Godot local Z';hinges[label]=o

def project(o):
    while o.data.uv_layers:o.data.uv_layers.remove(o.data.uv_layers[0])
    uv=o.data.uv_layers.new(name='UVMap')
    for p in o.data.polygons:
        axis=max(range(3),key=lambda i:abs(p.normal[i]))
        for li in p.loop_indices:
            q=o.data.vertices[o.data.loops[li].vertex_index].co
            a,b=((q.y,q.z),(q.x,q.z),(q.x,q.y))[axis]
            a,b=a*2+.5,b*2+.5
            if o.data.materials[0].name in tiles:a=(tiles[o.data.materials[0].name]+.05+.9*(a%1))/4;b=.05+.9*(b%1)
            uv.data[li].uv=(a,b)

def finish(o,name,m,parent=body,custom=False):
    o.name=name;o.data.materials.append(m)
    if not custom:project(o)
    for p in o.data.polygons:p.use_smooth=True
    o.parent=parent
    if parent==body:o.location.z-=C
    return o

def sphere(name,pos,scale,m,segments=24,rings=12,axis=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1,location=pos)
    o=bpy.context.object;o.scale=scale
    if axis:o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,m)

def custom(name,verts,faces,m,parent=body,custom_uv=False):
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o)
    return finish(o,name,m,parent,custom_uv)

def loft(name,origin,direction,profile,m,n=24):
    d=Vector(direction).normalized();right=d.cross(Vector((0,0,1)))
    if right.length<.01:right=Vector((1,0,0))
    right.normalize();up=right.cross(d).normalized();origin=Vector(origin)
    verts=[];faces=[]
    for axial,r in profile:
        for k in range(n):
            a=math.tau*k/n;verts.append(tuple(origin+d*axial+right*(r*math.cos(a))+up*(r*math.sin(a))))
    for j in range(len(profile)):
        q=(j+1)%len(profile)
        for k in range(n):faces.append((q*n+k,q*n+(k+1)%n,j*n+(k+1)%n,j*n+k))
    return custom(name,verts,faces,m)

def strut(name,start,end,r,m,vertices=8):
    a,b=Vector(start),Vector(end)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=(b-a).length,location=(a+b)/2)
    o=bpy.context.object;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return finish(o,name,m)

# Compact coral head, tapered swept abdomen, brass belly and dark split tail.
sphere('Coral_head',(0,.13,C+.014),(.146,.147,.166),coral,32,16)
d=Vector((0,-.87,-.49)).normalized()
sphere('Coral_abdomen',(0,-.108,.506),(.108,.108,.235),coral,28,14,tuple(d))
sphere('Brass_abdominal_belly',(0,-.106,.476),(.095,.102,.208),gold,24,12,tuple(d))
for axial in (-.08,.06):
    p=Vector((0,-.108,.506))+d*axial
    loft('Abdomen_brass_band',p,d,[(-.009,.111),(.008,.111),(.011,.106),(.011,.091),(-.009,.091)],gold,24)
for side in (-1,1):
    sphere('Split_charcoal_tail',(side*.046,-.355,.292),(.036,.044,.134),dark,20,10,(side*.35,-.78,-.51))
sphere('Tail_coral_end',(0,-.296,.400),(.080,.060,.082),coral,20,10)

# Purple optical socket and large convex violet glass face.
eye_center=Vector((0,.274,C+.025));rad=.108
loft('Coral_eye_rim',eye_center,(0,1,0),[(-.01,.123),(.015,.128),(.032,.121),(.028,.105),(-.01,.105)],coral,40)
loft('Violet_inner_socket',eye_center,(0,1,0),[(.01,.112),(.035,.114),(.042,.105),(.035,.096),(.01,.096)],purple,32)
verts=[tuple(eye_center+Vector((0,.080,0)))];faces=[];rings=7;n=40
for j in range(1,rings+1):
    r=rad*j/rings
    for k in range(n):
        a=math.tau*k/n;verts.append(tuple(eye_center+Vector((r*math.cos(a),.028+.052*math.sqrt(max(0,1-(r/rad)**2)),r*math.sin(a)))))
for k in range(n):faces.append((0,1+(k+1)%n,1+k))
for j in range(rings-1):
    for k in range(n):
        a=1+j*n+k;b=1+j*n+(k+1)%n;c=1+(j+1)*n+(k+1)%n;d1=1+(j+1)*n+k
        faces.append((a,b,c,d1))
o=custom('Violet_glass_eye',verts,faces,eye,custom_uv=True)
uv=o.data.uv_layers.new(name='UVMap')
for p in o.data.polygons:
    for li in p.loop_indices:
        q=o.data.vertices[o.data.loops[li].vertex_index].co-eye_center
        uv.data[li].uv=(.5+q.x/(2*rad),.5+q.z/(2*rad))

# Six rigid brass feelers/legs hanging clear below the head; no Leg_* animation contract.
for side in (-1,1):
    for i,y in enumerate((.145,.065,-.035)):
        x=side*(.091+i*.006)
        start=(x,y,.570-i*.011);knee=(side*(.143+i*.008),y+.012,.486-i*.01)
        end=(side*(.151+i*.008),y+.028,.435-i*.012)
        strut('Brass_feeler_upper',start,knee,.009,gold)
        strut('Brass_feeler_tip',knee,end,.004,gold)
for side in (-1,1):
    sphere('Head_brass_rivet',(side*.046,-.008,.804),(.027,.019,.022),gold,16,8)
    sphere('Belly_brass_rivet',(side*.061,-.205,.407),(.014,.016,.014),gold,12,6)
    sphere('Brass_wing_root_bearing',(side*.098,-.041,C),(.024,.034,.033),gold,12,6)

# Opaque pearl membrane fore/hindwings with rounded outlines and real thickness.
# Authored in hinge-local coordinates. Object transforms stay identity, including rotations.
def wing(name,outline,bounds,m,label,side,rings):
    n=len(outline);center=np.mean(np.array(outline),axis=0)
    verts=[];faces=[]
    def point(x,z,front):
        y=.015-.14*x+.04*z
        return (side*x,y+front*.007,z)
    for front in (1,-1):
        verts.append(point(*center,front))
        for j in range(1,rings+1):
            t=j/rings
            for x,z in outline:
                q=center+(np.array((x,z))-center)*t
                verts.append(point(*q,front))
    stride=1+rings*n
    for surface in (0,1):
        b=surface*stride
        for k in range(n):faces.append((b,b+1+k,b+1+(k+1)%n))
        for j in range(rings-1):
            for k in range(n):
                a=b+1+j*n+k;c=b+1+j*n+(k+1)%n;d1=b+1+(j+1)*n+(k+1)%n;e=b+1+(j+1)*n+k
                faces.append((a,e,d1,c))
    for k in range(n):
        a=1+(rings-1)*n+k;b=1+(rings-1)*n+(k+1)%n
        faces.append((a,b,b+stride,a+stride))
    # Winding needs front/back and mirrored sides to stay physically outward.
    oriented=[]
    per_surface=n*(1+rings-1)
    area=sum(outline[k][0]*outline[(k+1)%n][1]-outline[(k+1)%n][0]*outline[k][1] for k in range(n))
    for i,f in enumerate(faces):
        first=i < per_surface
        second=per_surface <= i < per_surface*2
        reverse=(first and side*area>0) or (second and side*area<0) or (i>=per_surface*2 and side*area<0)
        oriented.append(tuple(reversed(f)) if reverse else f)
    o=custom(name,verts,oriented,m,hinges[label],True)
    uv=o.data.uv_layers.new(name='UVMap');x0,x1,z0,z1=bounds
    for p in o.data.polygons:
        for li in p.loop_indices:
            q=o.data.vertices[o.data.loops[li].vertex_index].co
            uv.data[li].uv=((side*q.x-x0)/(x1-x0),(q.z-z0)/(z1-z0))
    return o

for label,side in [('L',1),('R',-1)]:
    wing('Forewing_'+label,upper,upper_bounds,fore,label,side,4)
    wing('Hindwing_'+label,lower,lower_bounds,hind,label,side,3)

# Body meshes join per material; wings remain distinct rigid children beneath their hinges.
for m in mats.values():
    group=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.parent==body and o.data.materials[0]==m]
    if not group:continue
    bpy.ops.object.select_all(action='DESELECT')
    for o in group:o.select_set(True)
    bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join();bpy.context.object.name=m.name[3:]+'_body_mesh'

bpy.context.view_layer.update()
stats={'triangles':0,'mesh_objects':0,'materials':len(mats),'textures':4,'animations':0}
for o in bpy.context.scene.objects:
    if o.type=='MESH':o.data.calc_loop_triangles();stats['triangles']+=len(o.data.loop_triangles);stats['mesh_objects']+=1
root['asset']='Skipper Moth';root['front']='+Y';body['motion']='Rigid hover parent; wings have independent identity hinges.'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_fast.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_fast.glb'),export_format='GLB',export_yup=True,
    export_animations=False,export_cameras=False,export_lights=False,export_apply=True)
(OUT/'build_stats.json').write_text(json.dumps(stats,indent=2));print('FINAL_STATS',json.dumps(stats))
