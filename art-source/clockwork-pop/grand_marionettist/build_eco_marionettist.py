import bpy, bmesh, math, json, struct
import numpy as np
from mathutils import Vector
from pathlib import Path

bpy.ops.wm.read_factory_settings(use_empty=True)
OUT=Path(__file__).parent
TAU=math.tau
groups={}

def texture(name,color,kind):
    n=1024
    yy,xx=np.mgrid[0:n,0:n].astype(np.float32)/n
    rng=np.random.default_rng(140+kind)
    grain=rng.normal(0,.0035,(n,n)).astype(np.float32)
    waves=.010*np.sin(xx*TAU*3)+.008*np.cos(yy*TAU*2)+.005*np.sin((xx+yy)*TAU*11)
    if kind==2: waves+=.017*np.sin(yy*TAU*120)
    if kind==3: waves+=.010*np.sin(xx*TAU*180)
    if kind==1: waves*=.45
    arr=np.ones((n,n,4),np.float32)
    for i,c in enumerate(color):arr[:,:,i]=np.clip(c*(1+waves)+grain,0,1)
    im=bpy.data.images.new(name,n,n,alpha=True)
    im.pixels.foreach_set(arr.ravel());im.filepath_raw=str(OUT/(name+'.png'));im.file_format='PNG';im.save();im.pack()
    return im

imgs=[texture('Lacquer_Burgundy',(0.36,.055,.145),0),texture('Bone_Porcelain',(.88,.82,.61),1),texture('Machined_Brass',(.72,.43,.13),2),texture('Joint_Graphite',(.12,.145,.16),3)]
def material(name,im=None,col=(1,1,1,1),metal=0,rough=.3,emit=None):
    m=bpy.data.materials.new(name);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=col;bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=rough
    if im:
        t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=im;m.node_tree.links.new(t.outputs['Color'],bs.inputs['Base Color'])
    if emit:bs.inputs['Emission Color'].default_value=(*emit,1);bs.inputs['Emission Strength'].default_value=.6
    return m
wine=material('Burgundy enamel',imgs[0],metal=.38,rough=.27)
bone=material('Ivory ceramic',imgs[1],metal=.02,rough=.24)
gold=material('Warm brass',imgs[2],metal=.78,rough=.29)
steel=material('Gunmetal joints',imgs[3],metal=.8,rough=.32)
black=material('Deep socket rubber',col=(.012,.018,.023,1),rough=.44)
cyan=material('Turquoise optic glass',col=(.025,.53,.58,1),metal=.3,rough=.17,emit=(.015,.25,.3))
shine=material('Optic glints',col=(.62,.92,.9,1),rough=.18)
edge=material('Wine edge trim',imgs[0],metal=.5,rough=.4)

def pivot(name,loc,parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=loc
    if parent:o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted()
    bpy.context.view_layer.update();groups[o.name]=[];return o

def register(o,name,mat,parent):
    o.name=name;o.data.materials.append(mat)
    for p in o.data.polygons:p.use_smooth=True
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if parent:
        w=o.matrix_world.copy();o.parent=parent;o.matrix_world=w;groups[parent.name].append(o)
    return o

def uv(o):
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    if not o.data.uv_layers:
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.015);bpy.ops.object.mode_set(mode='OBJECT')

def ell(name,loc,scale,mat,parent,seg=20,rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,location=loc);o=bpy.context.object;o.scale=scale;return register(o,name,mat,parent)

def cyl(name,a,b,r,mat,parent,verts=24,r2=None):
    a,b=Vector(a),Vector(b);d=b-a
    if r2 is None:bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=d.length,location=(a+b)/2)
    else:bpy.ops.mesh.primitive_cone_add(vertices=verts,radius1=r,radius2=r2,depth=d.length,location=(a+b)/2)
    o=bpy.context.object;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();return register(o,name,mat,parent)

def box(name,loc,scale,mat,parent,bevel=.012):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Machined rounded edges','BEVEL');mod.width=bevel;mod.segments=2;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=mod.name)
    return register(o,name,mat,parent)

def beam(name,a,b,width,depth,mat,parent):
    if any(token in name for token in ['Upper arm enamel','Long thigh armor','Shin enamel shroud']):width*=1.35;depth*=1.25
    if 'Finger ' in name:width*=1.4;depth*=1.35
    a,b=Vector(a),Vector(b);o=box(name,(a+b)/2,(width,depth,(b-a).length),mat,parent,.012);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o

def torus(name,loc,major,minor,mat,parent,axis='Y',segments=28):
    bpy.ops.mesh.primitive_torus_add(major_segments=segments,minor_segments=6,location=loc,major_radius=major,minor_radius=minor)
    o=bpy.context.object
    if axis=='Y':o.rotation_euler.x=math.pi/2
    if axis=='X':o.rotation_euler.y=math.pi/2
    return register(o,name,mat,parent)

def curve(name,pts,r,mat,parent):
    c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.bevel_depth=r;c.bevel_resolution=1;c.resolution_u=10
    s=c.splines.new('BEZIER');s.bezier_points.add(len(pts)-1)
    for bp,pt in zip(s.bezier_points,pts):bp.co=pt;bp.handle_left_type='AUTO';bp.handle_right_type='AUTO'
    o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);bpy.ops.object.select_all(action='DESELECT');bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');return register(bpy.context.object,name,mat,parent)

def rings(name,rows,mat,parent,segments=40):
    vs=[];faces=[]
    for z,rx,ry,cy in rows:
        for j in range(segments):
            a=j*TAU/segments;vs.append((rx*math.cos(a),cy+ry*math.sin(a),z))
    for k in range(len(rows)-1):
        for j in range(segments):a=k*segments+j;b=k*segments+(j+1)%segments;faces.append((a,b,b+segments,a+segments))
    faces.append(tuple(reversed(range(segments))));faces.append(tuple((len(rows)-1)*segments+j for j in range(segments)))
    me=bpy.data.meshes.new(name);me.from_pydata(vs,[],faces);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);return register(o,name,mat,parent)

body=pivot('Body',(0,0,0))
head=pivot('Head',(0,0,1.39),body)
# Torso tapers into a narrow segmented waist; breastplate has a broad shoulder line.
rings('Barrel breastplate',[(.91,.09,.085,0),(.97,.155,.125,0),(1.04,.215,.16,0),(1.17,.25,.165,0),(1.28,.23,.145,0),(1.33,.175,.115,0)],wine,body)
torus('Collar bronze edge',(0,0,1.33),.154,.009,gold,body,axis='Z')
cyl('Neckwell dark disk',(0,0,1.31),(0,0,1.34),.15,steel,body,32)
for z in [1.35,1.375,1.4]:cyl('Neck vertebra',(0,0,z),(0,0,z+.012),.065,steel,head,32)
for z in [.83,.855,.88,.9]:cyl('Waist vertebra',(0,0,z),(0,0,z+.017),.083,steel,body,28)
ell('Pelvic shell',(0,0,.785),(.145,.10,.095),wine,body)
box('Pelvic front shield',(0,.106,.793),(.13,.025,.125),gold,body,.024)
box('Pelvic enamel inset',(0,.126,.795),(.102,.015,.10),wine,body,.020)
# Gem mount: black backing, brass bezel, rivets and polished cyan convex lens.
cyl('Gem backing',(0,.143,1.115),(0,.2,1.115),.094,black,body,40)
torus('Gem brass bezel',(0,.212,1.115),.084,.016,gold,body,segments=40)
ell('Chest sapphire',(0,.219,1.115),(.069,.033,.069),cyan,body,32,16)
ell('Chest gem large highlight',(-.025,.250,1.145),(.012,.003,.017),shine,body,16,8)
ell('Chest gem lower glint',(.027,.248,1.082),(.014,.003,.007),shine,body,16,8)
for j in range(10):
    a=j*TAU/10;ell('Bezel screw',(math.cos(a)*.087,.229,1.115+math.sin(a)*.087),(.004,.003,.004),gold,body,12,6)
for s in [-1,1]:
    curve('Sweeping brass breast seam',[(s*.04,.097,.948),(s*.155,.134,1.004),(s*.215,.13,1.085)],.005,gold,body)
    ell('Status socket',(s*.16,.149,1.16),(.020,.012,.020),black,body)
    ell('Status turquoise lens',(s*.16,.16,1.16),(.013,.008,.013),cyan,body)
    for x,y,z in [(s*.13,.15,1.272),(s*.195,.13,1.23),(s*.095,.13,.985)]:ell('Breastplate rivet',(x,y,z),(.006,.004,.006),gold,body,12,6)
box('Rear clockwork panel',(0,-.156,1.15),(.205,.021,.15),steel,body,.025)
for z in [1.12,1.145,1.17,1.195]:box('Rear cooling slot',(0,-.174,z),(.15,.006,.009),black,body,.003)

# A bone-porcelain skull with real recessed round eye cavities.
skull=rings('Porcelain skull',[(1.421,.062,.047,.085),(1.445,.078,.067,.071),(1.478,.092,.089,.045),(1.52,.145,.125,.014),(1.58,.162,.127,0),(1.62,.16,.125,-.005),(1.645,.151,.117,-.012),(1.674,.139,.106,-.014),(1.692,.119,.091,-.015),(1.711,.091,.069,-.014),(1.726,.054,.041,-.014),(1.735,.009,.007,-.014)],bone,head,48)
for s in [-1,1]:
    cut=cyl('Temporary eye cut',(s*.077,.22,1.574),(s*.077,.012,1.574),.049,black,None,32)
    bpy.context.view_layer.objects.active=skull;mod=skull.modifiers.new('Recessed eye socket','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cut;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cut,do_unlink=True)
    # dark circular sockets sit behind the face; lens remains recessed
    cyl('Eye cavity backing',(s*.077,.056,1.574),(s*.077,.082,1.574),.047,black,head,32)
    torus('Eye dark steel rim',(s*.077,.104,1.574),.040,.005,steel,head)
    ell('Cyan eye',(s*.077,.109,1.574),(.033,.014,.034),cyan,head,32,16)
    ell('Eye reflection',(s*.077-.010,.122,1.588),(.006,.002,.008),shine,head,16,8)
    ell('Ceramic cheek',(s*.061,.10,1.477),(.045,.023,.039),bone,head)
    for z in [1.531,1.624]:ell('Face brass pin',(s*.122,.08,z),(.006,.005,.006),gold,head,12,6)
    cyl('Cranial burgundy earpiece',(s*.128,-.014,1.598),(s*.177,-.014,1.598),.073,wine,head,32)
    cyl('Ear brass plate',(s*.177,-.014,1.598),(s*.192,-.014,1.598),.054,gold,head,32)
    torus('Ear turned rings',(s*.193,-.014,1.598),.033,.006,gold,head,axis='X')
    cyl('Ear axle cap',(s*.193,-.014,1.598),(s*.2,-.014,1.598),.024,steel,head)
# triangular pear-shaped nasal aperture and scalloped porcelain jaw, no teeth.
ell('Nasal black aperture',(0,.132,1.517),(.018,.009,.014),black,head,16,8)
ell('Ivory chin left',(-.037,.112,1.438),(.032,.019,.020),bone,head)
ell('Ivory chin right',(.037,.112,1.438),(.032,.019,.020),bone,head)
curve('Skull crown brass seam',[(0,.0,1.732),(-.025,.089,1.691),(-.068,.115,1.649)],.0018,gold,head)
# Signal wand rises behind the left shoulder.
beam('Wand enamel base',(-.20,-.09,1.27),(-.225,-.11,1.45),.04,.036,wine,body)
cyl('Wand ribbed shaft',(-.225,-.11,1.445),(-.255,-.115,1.61),.010,steel,body,16)
for i in range(11):
    z=1.45+i*.013;x=-.225-(z-1.445)*.18;torus('Wand coil',(x,-.112,z),.010,.002,black,body,axis='Z',segments=12)
ell('Brass wand tip',(-.255,-.115,1.645),(.034,.031,.05),gold,body,20,12)

anim=[]
for sign,side in [(-1,'L'),(1,'R')]:
    x=sign*.322
    arm=pivot('Arm_'+side,(x,0,1.26),body);anim.append(arm)
    # broad cylindrical shoulder reel, axis transverse, with separate dark connector.
    cyl('Shoulder black axle '+side,(sign*.206,0,1.26),(sign*.33,0,1.26),.082,steel,arm,32)
    cyl('Shoulder reel enamel '+side,(sign*.282,0,1.26),(sign*.42,0,1.26),.127,wine,arm,40)
    torus('Shoulder reel edge '+side,(sign*.413,0,1.26),.102,.009,edge,arm,axis='X')
    cyl('Shoulder brass wheel '+side,(sign*.423,0,1.26),(sign*.439,0,1.26),.075,gold,arm,32)
    torus('Shoulder concentric brass '+side,(sign*.441,0,1.26),.047,.009,gold,arm,axis='X')
    cyl('Shoulder axis socket '+side,(sign*.44,0,1.26),(sign*.447,0,1.26),.032,steel,arm)
    for a in [.7,2.8,4.9]:ell('Shoulder rivet '+side,(sign*.425,math.cos(a)*.091,1.26+math.sin(a)*.091),(.004,.005,.005),gold,arm,12,6)
    elbow=(sign*.405,.012,1.008)
    beam('Upper arm enamel '+side,(sign*.343,0,1.17),elbow,.086,.092,wine,arm)
    cyl('Elbow hinge '+side,(elbow[0]-.055,elbow[1],elbow[2]),(elbow[0]+.055,elbow[1],elbow[2]),.055,steel,arm)
    cyl('Elbow brass cap '+side,(elbow[0]+sign*.055,.012,1.008),(elbow[0]+sign*.07,.012,1.008),.045,gold,arm)
    cyl('Elbow central pin '+side,(elbow[0]+sign*.07,.012,1.008),(elbow[0]+sign*.075,.012,1.008),.021,steel,arm)
    fore=pivot('Elbow_'+side,elbow,arm);anim.append(fore)
    wrist=(sign*.467,.044,.786)
    cyl('Forearm barrel '+side,elbow,wrist,.070,wine,fore,28,r2=.062)
    for t in [.18,.83]:
        c=Vector(elbow).lerp(Vector(wrist),t);d=(Vector(wrist)-Vector(elbow)).normalized();cyl('Forearm steel band '+side,c-d*.005,c+d*.005,.071 if t<.5 else .064,steel,fore)
    beam('Forearm gilded seam '+side,(sign*.412,.066,.981),(sign*.457,.09,.815),.007,.005,gold,fore)
    hand=pivot('Hand_'+side,wrist,fore);anim.append(hand)
    cyl('Wrist piston '+side,wrist,(sign*.474,.05,.75),.022,steel,hand,20)
    box('Palm plated clamp '+side,(sign*.477,.063,.714),(.087,.06,.085),wine,hand,.009)
    for dx in [-.027,.027]:
        for z in [.684,.744]:ell('Palm screw '+side,(sign*.477+dx,.091,z),(.003,.002,.003),gold,hand,10,6)
    for k,dx in enumerate([-.032,0,.032]):
        a=(sign*.477+dx,.065,.68);b=(sign*.477+dx*1.35,.074,.648);c=(sign*.477+dx*1.10,.11,.631)
        beam('Finger proximal '+side,a,b,.018,.022,steel,hand);ell('Finger hinge '+side,b,(.014,.014,.014),black,hand,12,8);beam('Finger curled tip '+side,b,c,.019,.020,steel,hand)
    beam('Opposed thumb '+side,(sign*.447,.066,.723),(sign*.422,.106,.686),.024,.024,steel,hand)
    curve('Hanging puppet cable '+side,[(sign*.50,.038,.72),(sign*.54,-.02,.50),(sign*.46,-.08,.35),(sign*.29,-.08,.31)],.0048,black,hand)

    hip=(sign*.117,0,.787);knee=(sign*.183,.04,.432);ankle=(sign*.228,.006,.126)
    leg=pivot('Leg_'+side,hip,body);anim.append(leg)
    cyl('Hip black axle '+side,(sign*.063,0,.787),(sign*.173,0,.787),.072,steel,leg)
    cyl('Hip burgundy drum '+side,(sign*.132,0,.787),(sign*.178,0,.787),.079,wine,leg,28)
    cyl('Hip brass pin '+side,(sign*.179,0,.787),(sign*.19,0,.787),.047,gold,leg)
    cyl('Hip dark core '+side,(sign*.191,0,.787),(sign*.195,0,.787),.031,steel,leg)
    beam('Long thigh armor '+side,(sign*.142,.0,.725),knee,.077,.086,wine,leg)
    beam('Thigh fine edge '+side,(sign*.114,.047,.71),(sign*.163,.087,.47),.009,.006,gold,leg)
    cyl('Knee dark hinge '+side,(knee[0]-.056,.04,.432),(knee[0]+.056,.04,.432),.055,steel,leg)
    cyl('Knee wine housing '+side,(knee[0]+sign*.01,.04,.432),(knee[0]+sign*.052,.04,.432),.063,wine,leg)
    cyl('Knee gold disk '+side,(knee[0]+sign*.054,.04,.432),(knee[0]+sign*.068,.04,.432),.044,gold,leg)
    cyl('Knee cap socket '+side,(knee[0]+sign*.069,.04,.432),(knee[0]+sign*.074,.04,.432),.023,steel,leg)
    shin=pivot('Knee_'+side,knee,leg);anim.append(shin)
    beam('Shin enamel shroud '+side,(sign*.188,.035,.376),ankle,.083,.084,wine,shin)
    beam('Shin brass inner edge '+side,(sign*.16,.086,.356),(sign*.205,.056,.15),.007,.005,gold,shin)
    for z in [.344,.31,.178]:ell('Shin front rivet '+side,(sign*(.187+(.36-z)*.11),.075,z),(.004,.003,.004),gold,shin,12,6)
    cyl('Ankle transverse axle '+side,(ankle[0]-.058,0,.12),(ankle[0]+.058,0,.12),.041,steel,shin)
    for s2 in [-1,1]:cyl('Ankle gold cap '+side,(ankle[0]+s2*.053,0,.12),(ankle[0]+s2*.064,0,.12),.033,gold,shin)
    foot=pivot('Foot_'+side,ankle,shin);anim.append(foot)
    box('Heavy sole '+side,(sign*.229,.071,.026),(.15,.23,.05),black,foot,.018)
    ell('Enamel instep '+side,(sign*.229,.025,.070),(.072,.10,.052),wine,foot,24,12)
    ell('Dark steel toe '+side,(sign*.229,.136,.052),(.071,.074,.040),steel,foot,24,12)
    beam('Toe chrome ridge '+side,(sign*.229,.074,.081),(sign*.229,.196,.046),.015,.012,steel,foot)
    for dx in [-.062,.062]:ell('Foot golden rivet '+side,(sign*.229+dx,.077,.057),(.004,.004,.004),gold,foot,12,6)

# Merge decorative meshes by their rigid pivot, while preserving individual materials and UVs.
for name,parts in list(groups.items()):
    if not parts:continue
    for o in parts:uv(o)
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=bpy.context.object;o.name=name+'_Geometry'

# One NLA track per clip and per articulated pivot exports synchronized named glTF clips.
scene=bpy.context.scene;scene.render.fps=30
moving=[head]+anim
rest={o.name:o.rotation_euler.copy() for o in moving}
for clip,duration in [('Idle',3.2),('Walk',1.2),('Swim',2.4),('Attack',1.4)]:
    frames=round(duration*30);scene.frame_end=frames
    for o in moving:
        o.animation_data_clear();o.rotation_euler=rest[o.name]
        for f in range(0,frames+1, max(1,frames//16)):
            t=f/frames;wave=math.sin(TAU*t);s=-1 if o.name.endswith('_L') else 1
            rot=Vector((0,0,0));n=o.name
            if clip=='Idle':
                if n=='Head':rot.z=.055*wave;rot.x=.025*math.sin(TAU*t)
                elif n.startswith('Arm_'):rot.y=s*.025*wave
                elif n.startswith('Elbow_'):rot.x=.035*wave
                elif n.startswith('Hand_'):rot.y=.05*wave
            elif clip=='Walk':
                if n.startswith('Leg_'):rot.x=s*.24*wave
                elif n.startswith('Knee_'):rot.x=-.30*max(0,s*wave)
                elif n.startswith('Foot_'):rot.x=.08*s*wave
                elif n.startswith('Arm_'):rot.x=-s*.15*wave
                elif n.startswith('Elbow_'):rot.x=.08*math.sin(TAU*t+math.pi)*s
                elif n=='Head':rot.z=.035*wave
            elif clip=='Swim':
                if n.startswith('Arm_'):rot.y=s*(.16-.16*math.cos(TAU*t));rot.x=.10*wave
                elif n.startswith('Elbow_'):rot.x=.2*(1-math.cos(TAU*t))
                elif n.startswith('Hand_'):rot.y=s*.17*wave
                elif n.startswith('Leg_'):rot.x=s*.12*wave
                elif n.startswith('Knee_'):rot.x=-.1*(1-math.cos(TAU*t))
                elif n=='Head':rot.x=.035*wave
            else:
                # Wind up, command with both hands, then return; all keys are rigid transforms.
                envelope=math.sin(math.pi*t)**2
                if n.startswith('Arm_'):rot.x=.85*envelope;rot.y=s*.25*envelope
                elif n.startswith('Elbow_'):rot.x=.4*envelope
                elif n.startswith('Hand_'):rot.y=s*.48*envelope
                elif n=='Head':rot.x=.12*envelope
            o.rotation_euler=Vector(rest[n])+rot;o.keyframe_insert(data_path='rotation_euler',frame=f,group=n)
        # explicitly close endpoints even when duration is not a multiple of sampling interval
        o.rotation_euler=rest[o.name];o.keyframe_insert(data_path='rotation_euler',frame=frames,group=o.name)
        action=o.animation_data.action;action.name=clip+'_'+o.name
        track=o.animation_data.nla_tracks.new();track.name=clip
        strip=track.strips.new(clip,0,action);strip.action_frame_start=0;strip.action_frame_end=frames
        o.animation_data.action=None;track.mute=True
    # Clearing animation_data would erase previous NLA tracks. Save strips for all clips below.
    if clip=='Idle':saved={o.name:[(clip,o.animation_data.nla_tracks[0].strips[0].action,frames)] for o in moving}
    else:
        for o in moving:saved[o.name].append((clip,o.animation_data.nla_tracks[0].strips[0].action,frames))

for o in moving:
    o.animation_data_clear();o.rotation_euler=rest[o.name];o.animation_data_create()
    for clip,action,frames in saved[o.name]:
        tr=o.animation_data.nla_tracks.new();tr.name=clip;st=tr.strips.new(clip,0,action);st.action_frame_start=0;st.action_frame_end=frames;tr.mute=True
scene.frame_set(0);scene.frame_end=96
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'eco_marionettist.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'eco_marionettist.glb'),export_format='GLB',export_yup=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True,export_cameras=False,export_lights=False)
print('EXPORTED GRAND MARIONETTIST')
