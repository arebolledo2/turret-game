import bpy, bmesh, math, json
import numpy as np
from pathlib import Path
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
OUT = Path(__file__).parent
TAU=math.tau

# Four shared generated atlases: enamel/metal albedo, roughness-metalness,
# fine surface normal and restrained illuminated glass detail.
N=1024
yy,xx=np.mgrid[0:N,0:N]
u=(xx%256)/255; v=(yy%512)/511
palette=[(.020,.075,.46),(.86,.78,.59),(.68,.40,.105),(.29,.32,.39),(.014,.023,.040),(.60,.12,.022),(.10,.22,.52),(.72,.54,.26)]
rough=[.27,.38,.27,.30,.42,.09,.23,.34]
metal=[.55,.08,.82,.86,.60,.0,.68,.78]
base=np.ones((N,N,4),np.float32); orm=np.ones_like(base); normal=np.ones_like(base); emission=np.ones_like(base)
grain=.006*np.sin(xx*1.72)+.004*np.cos(yy*2.13)
for k,c in enumerate(palette):
    mask=((xx//256)+(yy//512)*4)==k
    # Smooth intentional glaze, very fine manufacturing striation; pristine finish.
    mod=.96+.04*np.sin(u*math.pi)+grain
    if k in (2,3,7): mod=.95+.035*np.cos(v*130)+grain
    for j in range(3): base[:,:,j][mask]=np.clip(c[j]*mod[mask],0,1)
    orm[:,:,0][mask]=1; orm[:,:,1][mask]=rough[k]+grain[mask]*2; orm[:,:,2][mask]=metal[k]
    normal[:,:,0][mask]=.5+.012*np.sin(xx[mask]*1.7)
    normal[:,:,1][mask]=.5+.008*np.cos(yy[mask]*1.3)
    normal[:,:,2][mask]=1.
    for j in range(3): emission[:,:,j][mask]=(c[j]*.6 if k==5 else 0.)

def image(name,pixels,noncolor=False):
    im=bpy.data.images.new(name,width=N,height=N,alpha=False)
    if noncolor: im.colorspace_settings.name='Non-Color'
    im.pixels.foreach_set(pixels.ravel()); im.filepath_raw=str(OUT/(name+'.png')); im.file_format='PNG'; im.save(); im.pack()
    return im
albedo=image('kite_enamel_atlas',base); om=image('kite_surface_orm',orm,True); nm=image('kite_surface_normal',normal,True); em=image('kite_optic_emission',emission)
mats=[]
for k,name in enumerate(['Cobalt enamel','Ivory ceramic','Satin brass','Gunmetal frames','Bore carbon','Amber optic','Blue inner steel','Muted brass markings']):
    m=bpy.data.materials.new(name); m.use_nodes=True
    nodes=m.node_tree.nodes; links=m.node_tree.links; bs=nodes.get('Principled BSDF')
    tex=nodes.new('ShaderNodeTexImage'); tex.image=albedo; links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    tex2=nodes.new('ShaderNodeTexImage'); tex2.image=om
    sep=nodes.new('ShaderNodeSeparateColor'); links.new(tex2.outputs['Color'],sep.inputs['Color'])
    links.new(sep.outputs['Green'],bs.inputs['Roughness']); links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
    nt=nodes.new('ShaderNodeTexImage'); nt.image=nm
    normalnode=nodes.new('ShaderNodeNormalMap'); normalnode.inputs['Strength'].default_value=.25
    links.new(nt.outputs['Color'],normalnode.inputs['Color']); links.new(normalnode.outputs['Normal'],bs.inputs['Normal'])
    if k==5:
        et=nodes.new('ShaderNodeTexImage'); et.image=em; links.new(et.outputs['Color'],bs.inputs['Emission Color']); bs.inputs['Emission Strength'].default_value=.08
        bs.inputs['Coat Weight'].default_value=.7; bs.inputs['Coat Roughness'].default_value=.1
        bs.inputs['Transmission Weight'].default_value=.55; bs.inputs['IOR'].default_value=1.47
    else: bs.inputs['Coat Weight'].default_value=.3 if k==0 else .12
    mats.append(m)

def empty(name,pos,parent=None):
    o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o); o.location=pos; o.parent=parent; return o
root=empty('Root',(0,0,0)); body=empty('Body',(0,-.14,.54),root)
aim=empty('Aim',(0,.30,0),body)
fl=empty('Fin_L',(-.24,-.04,-.16),body); fr=empty('Fin_R',(.24,-.04,-.16),body)
muzzle=empty('Muzzle',(0,.64,0),aim)
groups={}
def finish(o,name,k,parent,smooth=True,bev=0,bevsegments=2):
    o.name=name
    if bev:
        mod=o.modifiers.new('Soft machined edges','BEVEL'); mod.width=bev; mod.segments=bevsegments
        bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=mod.name)
    if smooth:
        for p in o.data.polygons:p.use_smooth=True
    # Per-face planar projection at constant world density, within an atlas region.
    uv=o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap')
    tilex=k%4; tiley=k//4
    for p in o.data.polygons:
        a=max(range(3),key=lambda j:abs(p.normal[j])); axes=[j for j in range(3) if j!=a]
        for li in p.loop_indices:
            co=o.data.vertices[o.data.loops[li].vertex_index].co
            # Atlas margin avoids neighboring-material bleed in mip levels.
            su=.5+co[axes[0]]*.65; sv=.5+co[axes[1]]*.65
            uv.data[li].uv=((tilex+.06+.88*su)/4,(tiley+.04+.92*sv)/2)
    o.data.materials.append(mats[k]); o.parent=parent
    groups.setdefault(parent.name,[]).append(o)
    return o
def ellipsoid(name,pos,scale,k,parent,seg=40,rings=20):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,radius=1,location=pos)
    o=bpy.context.object; o.scale=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,k,parent)
def tube(name,pos,r,length,k,parent,inner=None,segments=32,rot=None):
    # Hollow machined cylinder, local Z; interior is deliberately modeled.
    inner=inner if inner is not None else r*.78
    verts=[]
    for z,rr in [(-length/2,r),(length/2,r),(-length/2,inner),(length/2,inner)]:
        verts.extend([(rr*math.cos(TAU*i/segments),rr*math.sin(TAU*i/segments),z) for i in range(segments)])
    faces=[]
    for i in range(segments):
        j=(i+1)%segments
        faces.extend([(i,j,segments+j,segments+i),(2*segments+i,3*segments+i,3*segments+j,2*segments+j),(i,2*segments+i,2*segments+j,j),(segments+i,segments+j,3*segments+j,3*segments+i)])
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces); mesh.update()
    o=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(o); o.location=pos
    if rot:o.rotation_euler=rot
    return finish(o,name,k,parent,True,.0015 if r>.06 else 0,1)
def cyl(name,pos,r,length,k,parent,rot=None,vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=length,location=pos); o=bpy.context.object
    if rot:o.rotation_euler=rot
    return finish(o,name,k,parent,True,.003 if r>.025 else 0,1)
def beam(name,a,b,r,k,parent,vertices=12):
    a=Vector(a); b=Vector(b); o=cyl(name,(a+b)/2,r,(b-a).length,k,parent,vertices=vertices)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler(); return o
def plate(name,points,thickness,k,parent,axis=0):
    verts=[]
    for side in [-1,1]:
        for point in points:
            c=list(point); c[axis]+=side*thickness/2; verts.append(c)
    n=len(points); faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
    return finish(o,name,k,parent,False,.007)

# Compact faceted dart shell, with rounded panel edges and an inset front assembly.
ellipsoid('Cobalt pressure shell',(0,0,0),(.33,.365,.285),0,body,40,20)
# Wedge cheek armor introduces broad angular surfaces without losing the round core.
for s in [-1,1]:
    pts=[(s*.25,.22,.12),(s*.305,-.17,.17),(s*.30,-.28,-.04),(s*.265,.12,-.19)]
    plate('Angular cheek panel',pts,.026,0,body,axis=0)
    # Recessed amber porthole and layered brass/gunmetal bezel on both flanks.
    rot=(0,math.pi/2,0)
    cyl('Eye dark recess',(s*.320,-.11,.005),.120,.036,4,body,rot)
    tube('Eye steel seat',(s*.337,-.11,.005),.121,.032,3,body,inner=.098,rot=rot)
    tube('Eye brass bezel',(s*.357,-.11,.005),.109,.040,2,body,inner=.085,rot=rot)
    ellipsoid('Glass orange side optic',(s*.374,-.11,.005),(.030,.083,.083),5,body,32,16)
    for a in [0,math.pi/2,math.pi,3*math.pi/2]:
        cyl('Optic bezel screw',(s*.379,-.11+.105*math.cos(a),.005+.105*math.sin(a)),.010,.009,3,body,rot,12)
    ellipsoid('Shell rivet',(s*.253,.15,.175),(.015,.015,.015),2,body,12,8)

# Wide circular collar opens onto a dark mechanically ribbed front, not an animal face.
ry=(math.pi/2,0,0)
tube('Main brass collar',(0,.285,0),.257,.064,2,body,inner=.215,rot=ry,segments=56)
tube('Main inner carbon recess',(0,.271,0),.217,.058,4,body,inner=.163,rot=ry,segments=48)
for i in range(16):
    a=TAU*i/16
    beam('Radial front gill',(.187*math.cos(a),.303,.187*math.sin(a)),(.213*math.cos(a),.303,.213*math.sin(a)),.008,3,body)
ellipsoid('Cannon cobalt nose',(0,.028,0),(.166,.092,.164),0,aim,32,16)
tube('Gun swivel seat',(0,.104,0),.091,.065,3,aim,inner=.054,rot=ry)
tube('Gun brass breech',(0,.153,0),.076,.042,2,aim,inner=.048,rot=ry)
tube('Needle cobalt shaft',(0,.365,0),.046,.400,0,aim,inner=.027,rot=ry)
# Bore sleeve, open lip, and a deeply recessed dark throat make the muzzle unambiguous.
tube('Needle muzzle shroud',(0,.598,0),.060,.085,2,aim,inner=.033,rot=ry)
tube('Black barrel bore',(0,.603,0),.033,.072,4,aim,inner=.027,rot=ry)
cyl('Deep bore terminus',(0,.567,0),.027,.004,4,aim,ry)
for s in [-1,1]:
    ellipsoid('Nose amber indicator',(s*.117,.073,.061),(.020,.013,.020),5,aim,16,10)

# Large ivory dorsal sail with a clean triangular kite silhouette.
sail=[(0,.21,.215),(0,-.29,.610),(0,-.36,.235)]
plate('Ivory dorsal sail',sail,.058,1,body)
for a,b in zip(sail,sail[1:]+sail[:1]):beam('Dorsal dark frame',a,b,.018,3,body)
# An ivory inset lip and three small brass fasteners frame the high-value sail.
for side in [-1,1]:
    pts=[(side*.037,.162,.254),(side*.037,-.274,.562),(side*.037,-.328,.267)]
    for a,b in zip(pts,pts[1:]+pts[:1]):beam('Sail brass pinstripe',a,b,.004,7,body,8)
    for p in pts:ellipsoid('Sail pin',p,(.008,.012,.012),2,body,12,8)

# Two compact articulated ventral fins, not legs, with ceramic vanes and metal caps.
for s,pivot in [(-1,fl),(1,fr)]:
    cyl('Fin swivel',(s*.004,0,0),.072,.085,3,pivot,(0,math.pi/2,0))
    points=[(s*.015,.09,-.006),(s*.147,-.11,-.126),(s*.105,-.19,-.201),(s*.012,-.095,-.164)]
    plate('Ivory side fin',points,.050,1,pivot,axis=0)
    for a,b in zip(points,points[1:]+points[:1]):beam('Fin cobalt rail',a,b,.016,0,pivot)
    beam('Fin gold trailing trim',points[1],points[2],.018,2,pivot)
    ellipsoid('Fin hub boss',(s*.052,0,0),(.012,.039,.039),3,pivot,16,10)

# Short rear thruster with open nozzle and two ventilation plates.
cyl('Rear cobalt pod',(0,-.37,-.016),.133,.15,0,body,ry)
tube('Rear brass collar',(0,-.421,-.016),.145,.042,2,body,inner=.113,rot=ry)
tube('Rear dark nozzle',(0,-.467,-.016),.117,.064,4,body,inner=.076,rot=ry)
cyl('Rear blue turbine',(0,-.447,-.016),.075,.012,6,body,ry)
for i in range(6):
    a=TAU*i/6
    beam('Nozzle vane',(.020*math.cos(a),-.483,-.016+.020*math.sin(a)),(.070*math.cos(a+.3),-.483,-.016+.070*math.sin(a+.3)),.009,3,body)

# Consolidate fixed geometry, maintaining the four independent moving rigid assemblies.
for pname,objects in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
    o=bpy.context.object;o.name=pname+'_Assembly'
    # Smooth-by-angle keeps faceted cheek and ceramic panels crisp.
    bm=bmesh.new();bm.from_mesh(o.data)
    for edge in bm.edges:
        if len(edge.link_faces)==2 and edge.calc_face_angle(0)>math.radians(40):edge.smooth=False
    bm.to_mesh(o.data);bm.free()

# Named NLA groups merge synchronized object actions into four rigid-part clips.
scene=bpy.context.scene;scene.render.fps=30
rest={o.name:(o.location.copy(),o.rotation_euler.copy()) for o in [body,fl,fr,aim]}
def clip(name,length,kind):
    for ob in [body,fl,fr,aim]:
        ob.animation_data_create(); action=bpy.data.actions.new(name+'_'+ob.name);ob.animation_data.action=action
        for frame in range(0,length+1,3):
            t=frame/length; ang=TAU*t
            loc,rot=rest[ob.name];ob.location=loc;ob.rotation_euler=rot
            if kind=='attack':
                pulse=math.sin(math.pi*min(max((t-.1)/.42,0),1))**2 if t<.52 else 0
                if ob==aim:ob.location.y-=.060*pulse;ob.rotation_euler.x=.035*pulse
                if ob==body:ob.rotation_euler.x=-.025*pulse
                if ob==fl:ob.rotation_euler.y=.13*pulse
                if ob==fr:ob.rotation_euler.y=-.13*pulse
            else:
                speed=1 if kind=='idle' else 2
                if ob==body:
                    ob.location.z+= (.013 if kind=='idle' else .024)*math.sin(ang)
                    ob.rotation_euler.x=(.018 if kind=='idle' else .040)*math.sin(ang)
                    ob.rotation_euler.y=.013*math.sin(ang)
                if ob==fl:ob.rotation_euler.y=(.08 if kind=='idle' else .22)*math.sin(ang*speed)
                if ob==fr:ob.rotation_euler.y=-(.08 if kind=='idle' else .22)*math.sin(ang*speed)
                if ob==aim:ob.rotation_euler.x=.009*math.sin(ang)
            ob.keyframe_insert(data_path='location',frame=frame);ob.keyframe_insert(data_path='rotation_euler',frame=frame)
        track=ob.animation_data.nla_tracks.new();track.name=name;strip=track.strips.new(name,0,action);strip.action_frame_start=0;strip.action_frame_end=length
        ob.animation_data.action=None
        track.mute=True
        ob.location,ob.rotation_euler=rest[ob.name]
clip('Idle',120,'idle');clip('Walk',60,'walk');clip('Swim',90,'swim');clip('Attack',30,'attack')
scene.frame_set(0)
for ob in [body,fl,fr,aim]:ob.location,ob.rotation_euler=rest[ob.name]
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'eco_kite.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'eco_kite.glb'),export_format='GLB',export_yup=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_cameras=False,export_lights=False,export_force_sampling=True)
print('EXPORTED Needle Kite with four rigid clips and four generated image atlases')
