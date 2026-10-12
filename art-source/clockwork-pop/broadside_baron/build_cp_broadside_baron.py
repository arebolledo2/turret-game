"""Broadside Baron: procedural enamel/brass airship, four rigid yaw cannons.
Blender +Y is forward. Run with Blender 5.2 --background --python this_file.
All textures are generated here, packed into the source and embedded in GLB.
"""
import bpy, bmesh, math, json, struct
import numpy as np
from pathlib import Path
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
OUT=Path(__file__).resolve().parent
TAU=math.tau

def texture(name, color, mode):
    n=1024; yy,xx=np.mgrid[0:n,0:n]; u=xx/n; v=yy/n
    rng=np.random.default_rng(431+len(name))
    noise=rng.normal(0,.0018,(n,n))
    if mode=='brass':
        shade=.96+.025*np.sin(TAU*v*63)+.012*np.sin(TAU*v*181)+noise
    elif mode=='lens':
        shade=.91+.055*np.sin(TAU*u)*np.sin(TAU*v)+noise*.3
    else:
        shade=.96+.018*np.sin(TAU*u*3)*np.sin(TAU*v*2)+.007*np.sin(TAU*v*17)+noise
    pix=np.empty((n,n,4),dtype=np.float32)
    for i,c in enumerate(color):pix[:,:,i]=np.clip(c*shade,0,1)
    if mode=='lens':
        rad=np.hypot((u-.5)*2,(v-.5)*2)
        core=np.exp(-(rad/.66)**3)
        edge=(.99,.19,.006);centre=(1.0,.72,.018)
        for i in range(3):pix[:,:,i]=np.clip((edge[i]+(centre[i]-edge[i])*core)*shade,0,1)
    pix[:,:,3]=1
    im=bpy.data.images.new(name,n,n,alpha=False)
    im.colorspace_settings.name='sRGB'; im.pixels.foreach_set(pix.ravel())
    im.filepath_raw=str(OUT/(name+'.png'));im.file_format='PNG';im.save();im.pack()
    return im

def mat(name,color,metal=0,rough=.3,im=None,emission=0):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*color,1)
    bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=rough
    if im:
        t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=im
        m.node_tree.links.new(t.outputs['Color'],bs.inputs['Base Color'])
    if emission:
        bs.inputs['Emission Color'].default_value=(*color,1);bs.inputs['Emission Strength'].default_value=emission
    return m

navy=mat('Midnight blue enamel',(.045,.15,.275),.38,.24,texture('navy_enamel',(.12,.28,.43),'paint'))
ivory=mat('Warm porcelain enamel',(.88,.80,.60),.12,.3,texture('ivory_enamel',(.94,.88,.70),'paint'))
gold=mat('Satin machined brass',(.8,.55,.17),.76,.29,texture('brushed_brass',(.93,.68,.29),'brass'))
amber=mat('Amber optical glass',(.95,.23,.006),.12,.16,texture('amber_optics',(.99,.29,.009),'lens'),.25)
dark=mat('Bore and joint recess',(.012,.024,.037),.35,.4)
steel=mat('Blue silver seams',(.27,.4,.45),.65,.28)

def empty(name,loc=(0,0,0),parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.parent=parent;o.location=loc
    return o

body=empty('Body')
def uv(o):
    me=o.data;layer=me.uv_layers.active or me.uv_layers.new(name='UVMap')
    # Half metre repeating box projection gives consistent detail density on parts.
    for p in me.polygons:
        axis=max(range(3),key=lambda k:abs(p.normal[k]))
        for li in p.loop_indices:
            c=me.vertices[me.loops[li].vertex_index].co
            if o.name=='Convex amber eye':
                layer.data[li].uv=(c.x/.486+.5,c.z/.486+.5)
                continue
            a,b=((c.y,c.z) if axis==0 else ((c.x,c.z) if axis==1 else (c.x,c.y)))
            layer.data[li].uv=(a/.5,b/.5)

def finish(o,name,m,parent=body,smooth=True):
    o.name=name;o.data.materials.append(m);o.parent=parent
    if smooth:
        for p in o.data.polygons:p.use_smooth=True
    uv(o);return o

def mesh(name,verts,faces,m,parent=body,smooth=True):
    me=bpy.data.meshes.new(name+'Mesh');me.from_pydata(verts,[],faces);me.update()
    o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o)
    return finish(o,name,m,parent,smooth)

def sphere(name,pos,scale,m,parent=body,seg=24,rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,radius=1)
    o=bpy.context.object;o.location=pos;o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,m,parent)

def cyl(name,pos,r,depth,m,parent=body,axis=(0,0,1),seg=24,bevel=.008):
    bpy.ops.mesh.primitive_cylinder_add(vertices=seg,radius=r,depth=depth)
    o=bpy.context.object
    if bevel:
        mod=o.modifiers.new('Soft machined lip','BEVEL');mod.width=bevel;mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    o.location=pos;o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
    return finish(o,name,m,parent)

def tube(name,points,r,m,parent=body,sides=6,closed=False):
    verts=[];faces=[];nn=len(points)
    for i,point in enumerate(points):
        p=Vector(point)
        d=Vector(points[(i+1)%nn])-Vector(points[(i-1)%nn]) if closed else Vector(points[min(nn-1,i+1)])-Vector(points[max(0,i-1)])
        d.normalize();a=d.cross(Vector((0,0,1)))
        if a.length<.01:a=d.cross(Vector((1,0,0)))
        a.normalize();b=d.cross(a).normalized()
        for j in range(sides):verts.append(p+r*(a*math.cos(TAU*j/sides)+b*math.sin(TAU*j/sides)))
    for i in range(nn if closed else nn-1):
        for j in range(sides):faces.append((i*sides+j,i*sides+(j+1)%sides,((i+1)%nn)*sides+(j+1)%sides,((i+1)%nn)*sides+j))
    if not closed:faces.extend([tuple(reversed(range(sides))),tuple((nn-1)*sides+j for j in range(sides))])
    return mesh(name,verts,faces,m,parent)

def ring(name,pos,r,thickness,m,parent=body,axis='y',segments=40):
    p=Vector(pos);pts=[]
    for i in range(segments):
        a=TAU*i/segments
        off=Vector((r*math.sin(a),0,r*math.cos(a))) if axis=='y' else Vector((r*math.sin(a),r*math.cos(a),0))
        pts.append(p+off)
    return tube(name,pts,thickness,m,parent,8,True)

# Hull is a true egg: fuller bow (+Y) and gently tapered stern, rather than a cylinder.
def hull(t,a,extra=0):
    f=math.sqrt(max(0,1-t*t));rx=.84*f*(1+.085*t)+extra;rz=.79*f+extra
    return (rx*math.sin(a),1.22*t,1.10+rz*math.cos(a))

verts=[];faces=[];longs=56;lats=28
for i in range(lats+1):
    t=-math.cos(math.pi*i/lats)
    for j in range(longs):verts.append(hull(t,TAU*j/longs))
for i in range(lats):
    for j in range(longs):faces.append((i*longs+j,i*longs+(j+1)%longs,(i+1)*longs+(j+1)%longs,(i+1)*longs+j))
# Recalculate normals removes winding ambiguity at poles and panels.
h=mesh('Egg hull',verts,faces,navy)

# Porcelain fields follow the continuous egg curvature; dark stripes remain visible.
for k,(a0,a1) in enumerate([(25,67),(113,155),(205,247),(293,335)]):
    verts=[];faces=[];nr=20;nc=10
    for i in range(nr+1):
        t=-.78+1.70*i/nr
        for j in range(nc+1):verts.append(hull(t,math.radians(a0+(a1-a0)*j/nc),.009))
    for i in range(nr):
        for j in range(nc):
            q=i*(nc+1)+j;faces.append((q,q+1,q+nc+2,q+nc+1))
    mesh('Porcelain longitudinal field '+str(k),verts,faces,ivory)
    for a in (a0,a1):
        tube('Brass longitudinal rib', [hull(-.78+1.33*i/36,math.radians(a),.025) for i in range(37)],.022,gold)

# A large uninterrupted porcelain bow shell matches the concept's pale nose.
verts=[];faces=[];nr=13;nc=56
for i in range(nr+1):
    t=.55+.445*i/nr
    for j in range(nc):verts.append(hull(t,TAU*j/nc,.013))
for i in range(nr):
    for j in range(nc):faces.append((i*nc+j,i*nc+(j+1)%nc,(i+1)*nc+(j+1)%nc,(i+1)*nc+j))
mesh('Porcelain bow dome',verts,faces,ivory)

for t in (-.73,.55):
    tube('Raised brass hull hoop',[hull(t,TAU*j/64,.025) for j in range(64)],.035,gold,sides=8,closed=True)

# Horizontal guard belt and spaced fasteners emphasize the naval construction.
belt=[]
for i in range(80):
    a=TAU*i/80;belt.append((.845*math.sin(a),1.23*math.cos(a),1.10))
tube('Equatorial brass belt',belt,.024,gold,sides=8,closed=True)
for i in range(16):
    a=TAU*i/16
    sphere('Belt rivet',(.867*math.sin(a),1.253*math.cos(a),1.11),(.026,.026,.026),gold,seg=10,rings=5)

# Bow lens: stepped navy face with broad gilded bezel and amber convex glass.
sphere('Bow navy mask',(0,1.116,1.10),(.43,.15,.49),navy)
cyl('Bow brass socket',(0,1.274,1.10),.312,.18,gold,axis=(0,1,0),seg=40)
cyl('Lens dark gasket',(0,1.375,1.10),.263,.018,dark,axis=(0,1,0),seg=40)
ring('Lens rim',(0,1.393,1.10),.273,.025,gold,segments=40)
sphere('Convex amber eye',(0,1.395,1.10),(.243,.095,.243),amber,seg=40,rings=20)
for z in (.69,1.56):sphere('Nose gilded bolt',(0,1.222,z),(.035,.024,.035),gold,seg=12,rings=6)

# Top observation hatch is intentionally low; reference tail fins are omitted.
cyl('Hatch brass plinth',(0,.02,1.872),.315,.09,gold,seg=36)
cyl('Hatch navy dome',(0,.02,1.922),.267,.08,navy,seg=36)
ring('Hatch silver inset',(0,.02,1.964),.238,.012,steel,axis='z',segments=36)
cyl('Hatch small chimney',(0,.02,2.026),.064,.125,gold,seg=20)
cyl('Chimney navy centre',(0,.02,2.093),.043,.008,dark,seg=20,bevel=0)
for sx in (-1,1):
    sphere('Hatch latch',(sx*.278,.02,1.908),(.026,.04,.057),gold,seg=12,rings=6)
    # Side portholes and slatted inset below hull belt.
    for y in (-.27,.10,.43):
        cyl('Side gilded porthole',(sx*.809,y,.94),.071,.034,gold,axis=(sx,0,0),seg=18)
        cyl('Side amber centre',(sx*.831,y,.94),.051,.01,amber,axis=(sx,0,0),seg=18,bevel=0)
cyl('Short signal mast',(0,-.38,1.98),.018,.26,gold,seg=12,bevel=0)
sphere('Signal mast knob',(0,-.38,2.115),(.037,.037,.037),gold,seg=12,rings=6)

# Underbody trim keel and a small hover/ballast pod, no legs.
cyl('Lower pod brass rim',(0,.08,.24),.245,.08,gold,seg=28)
cyl('Lower pod navy body',(0,.08,.315),.219,.12,navy,seg=28)
ring('Lower pod band',(0,.08,.342),.219,.011,gold,axis='z',segments=28)

# Four corner weapon stations. Each yaw pivot has local +Y pointing along its nominal diagonal.
cannons=[];recoils=[];muzzles=[]
def cannon(label,sx,sy):
    px=sx*.83;py=sy*.65;pz=1.23
    tube('Corner bracket '+label,[(sx*.70,sy*.56,1.00),(sx*.97,sy*.68,1.00),(px,py,pz)],.046,gold,sides=8)
    cyl('Corner yaw foot '+label,(px,py,pz-.08),.135,.095,navy,seg=20)
    ring('Yaw foot brass '+label,(px,py,pz-.025),.118,.015,gold,axis='z',segments=20)
    p=empty('Cannon_'+label,(px,py,pz),body)
    # rotation about Z maps +Y onto the outward diagonal.
    yaw=math.atan2(-sx,sy);p.rotation_euler.z=yaw
    p['yaw_sector_degrees']=120;p['yaw_min_offset_degrees']=-60;p['yaw_max_offset_degrees']=60
    p['nominal_outward_yaw_degrees']=math.degrees(yaw)
    recoil=empty('Recoil_'+label,(0,0,0),p)
    sphere('Rounded cannon housing '+label,(0,.09,.03),(.279,.278,.279),navy,recoil,seg=28,rings=14)
    ring('Housing back rim '+label,(0,-.095,.03),.215,.018,gold,recoil,segments=28)
    for ss in (-1,1):
        cyl('Cannon trunnion '+label,(ss*.272,.065,.03),.092,.035,gold,recoil,axis=(ss,0,0),seg=18)
        sphere('Trunnion dome '+label,(ss*.294,.065,.03),(.023,.067,.067),amber,recoil,seg=16,rings=8)
    # barrel outside, tapered; hollow mouth has an actual recessed bore.
    profiles=[(.25,.144),(.29,.155),(.32,.155),(.35,.129),(.56,.118),(.69,.133),(.735,.143),(.77,.143),(.77,.106),(.53,.098)]
    verts=[];faces=[];nn=32
    for y,r in profiles:
        for j in range(nn):
            a=TAU*j/nn;verts.append((r*math.sin(a),y,.03+r*math.cos(a)))
    for i in range(len(profiles)-1):
        for j in range(nn):faces.append((i*nn+j,i*nn+(j+1)%nn,(i+1)*nn+(j+1)%nn,(i+1)*nn+j))
    barrel=mesh('Hollow cannon barrel '+label,verts,faces,navy,recoil)
    barrel.data.materials.append(gold);barrel.data.materials.append(dark)
    for po in barrel.data.polygons:
        band=po.index//nn;po.material_index=1 if band in (0,1,5,6,7) else (2 if band==8 else 0)
    cyl('Bore bottom '+label,(0,.528,.03),.097,.008,dark,recoil,axis=(0,1,0),seg=32,bevel=0)
    ring('Breech brass collar '+label,(0,.288,.03),.157,.018,gold,recoil,segments=32)
    ring('Barrel seam '+label,(0,.465,.03),.124,.006,steel,recoil,segments=32)
    marker=empty('Muzzle_'+label,(0,.775,.03),recoil)
    marker['forward_axis']='+Y';marker['purpose']='projectile spawn at open barrel tip'
    cannons.append(p);recoils.append(recoil);muzzles.append(marker)
for label,sx,sy in [('FL',-1,1),('FR',1,1),('RL',-1,-1),('RR',1,-1)]:cannon(label,sx,sy)

# Compact stern hub with four rounded propeller paddles in the XZ plane.
cyl('Aft engine socket',(0,-1.193,1.10),.245,.13,gold,axis=(0,1,0),seg=28)
cyl('Aft engine navy drum',(0,-1.33,1.10),.185,.19,navy,axis=(0,1,0),seg=28)
prop=empty('Propeller',(0,-1.46,1.10),body)
prop['spin_axis']='local Y'
for j in range(4):
    a=TAU*j/4+.25
    blade=sphere('Swept propeller paddle '+str(j),(math.sin(a)*.30,-.015,math.cos(a)*.30),(.10,.025,.255),navy,prop,seg=16,rings=8)
    blade.rotation_euler.y=a
    # A small broad brass tip makes blade rotation readable.
    tip=sphere('Propeller brass cap '+str(j),(math.sin(a)*.505,-.015,math.cos(a)*.505),(.087,.03,.067),gold,prop,seg=12,rings=6)
    tip.rotation_euler.y=a
sphere('Propeller brass spinner',(0,-.052,0),(.107,.09,.107),gold,prop,seg=24,rings=12)

# Correct normals and merge static geometry by rigid parent: seven mesh objects total.
for o in list(bpy.context.scene.objects):
    if o.type=='MESH':
        bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(o.data);bm.free()
        uv(o)
for parent in [body,prop]+recoils:
    children=[o for o in list(bpy.context.scene.objects) if o.type=='MESH' and o.parent==parent]
    if not children:continue
    bpy.ops.object.select_all(action='DESELECT')
    for o in children:o.select_set(True)
    bpy.context.view_layer.objects.active=children[0];bpy.ops.object.join()
    merged=children[0];merged.name=parent.name+'_Geometry'

# Named NLA tracks merge per-node actions into four actual glTF transform clips.
scene=bpy.context.scene;scene.render.fps=30
base={o.name:(o.location.copy(),o.rotation_euler.copy()) for o in [body,prop]+cannons+recoils}
def clip(name,frames):
    for o in [body,prop]+cannons+recoils:
        o.animation_data_create();o.animation_data.action=None
        for f in frames:
            loc,rot=base[o.name];o.location=loc;o.rotation_euler=rot
            t=(f-1)/(frames[-1]-1)
            s=math.sin(TAU*t)
            if o==body:
                o.location.z=loc.z+(.032 if name=='Idle' else .052)*s
                o.rotation_euler.x=(.008 if name=='Idle' else .026)*s
                if name=='Attack':o.rotation_euler.x=-.045*math.sin(math.pi*t)**2
            elif o==prop:
                o.rotation_euler.y=rot.y+TAU*(1 if name=='Idle' else 3)*t
            elif o in cannons:
                if name=='Attack':o.rotation_euler.z=rot.z+.10*math.sin(math.pi*t)**2
                else:o.rotation_euler.z=rot.z+.018*s
            elif o in recoils and name=='Attack':
                idx=recoils.index(o);pulse=max(0,1-abs(t-(.28+idx*.11))/.09)
                o.location.y=loc.y-.10*pulse
            o.keyframe_insert(data_path='location',frame=f,group=o.name)
            o.keyframe_insert(data_path='rotation_euler',frame=f,group=o.name)
        action=o.animation_data.action;action.name=name+'_'+o.name
        for slot in action.slots:
            for layer in action.layers:
                for st in layer.strips:
                    cb=st.channelbag(slot)
                    if cb:
                        for fc in cb.fcurves:
                            for key in fc.keyframe_points:key.interpolation='LINEAR' if o==prop else 'BEZIER'
        track=o.animation_data.nla_tracks.new();track.name=name
        strip=track.strips.new(name,1,action);strip.name=name
        o.animation_data.action=None;track.mute=True
    for o in [body,prop]+cannons+recoils:o.location,o.rotation_euler=base[o.name]

clip('Idle',[1,16,31,46,61])
clip('Walk',[1,13,25,37,49])
clip('Swim',[1,13,25,37,49])
clip('Attack',list(range(1,32,2))+[32])
for o in [body,prop]+cannons+recoils:
    for tr in o.animation_data.nla_tracks:tr.mute=False
scene.frame_set(1)
for o in [body,prop]+cannons+recoils:o.location,o.rotation_euler=base[o.name]
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_broadside_baron.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_broadside_baron.glb'),export_format='GLB',export_yup=True,
    export_animations=True,export_animation_mode='NLA_TRACKS',export_cameras=False,export_lights=False,
    export_apply=True,export_extras=True,export_nla_strips=True)
print('BUILT Broadside Baron with four yaw stations and Idle / Walk / Swim / Attack')
