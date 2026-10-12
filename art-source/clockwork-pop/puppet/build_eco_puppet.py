"""Clockwork Puppet: compact rigid toy with packed procedural finishes."""
from pathlib import Path
import math, json
import bpy
import numpy as np
from mathutils import Vector

OUT = Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 30

def image_finish(name, color, style):
    n = 1024
    y, x = np.mgrid[0:n, 0:n].astype(float) / n
    rng = np.random.default_rng(42)
    fine = rng.normal(0, .0015, (n, n))
    if style == 'enamel':
        value = 1 + .018*np.sin(x*math.tau*3)*np.sin(y*math.tau*2) + fine
        value += .035*np.exp(-((x-.32)/.10)**2)
    elif style == 'ceramic':
        value = 1 + .012*np.cos(y*math.tau*2) + fine*.6
        value -= .02*np.exp(-((x-.77)/.025)**2)
    elif style == 'metal':
        value = 1 + .045*np.sin(y*math.tau*180) + .025*np.cos(x*math.tau*3) + fine
    else:
        value = 1 + .025*np.sin(y*math.tau*70) + fine*2
    pixels = np.ones((n,n,4),dtype=np.float32)
    pixels[:,:,:3] = np.clip(value[:,:,None]*np.array(color)[None,None,:],0,1)
    img=bpy.data.images.new(name,n,n,alpha=False)
    img.colorspace_settings.name='sRGB'
    img.pixels.foreach_set(pixels.ravel())
    img.filepath_raw=str(OUT/(name+'.png')); img.file_format='PNG'; img.save(); img.pack()
    return img

def material(name, color, metal=0, rough=.3, texture=None, emit=0):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    s=m.node_tree.nodes.get('Principled BSDF')
    s.inputs['Base Color'].default_value=(*color,1)
    s.inputs['Metallic'].default_value=metal; s.inputs['Roughness'].default_value=rough
    if texture:
        t=m.node_tree.nodes.new('ShaderNodeTexImage'); t.image=texture; t.extension='REPEAT'
        m.node_tree.links.new(t.outputs['Color'],s.inputs['Base Color'])
    if emit:
        s.inputs['Emission Color'].default_value=(*color,1); s.inputs['Emission Strength'].default_value=emit
    return m

plum=material('Plum lacquer',(.30,.018,.095),.45,.25,image_finish('plum_enamel',(.43,.042,.15),'enamel'))
ivory=material('Ivory porcelain',(.83,.78,.53),.05,.22,image_finish('ivory_porcelain',(.94,.90,.68),'ceramic'))
gold=material('Warm brass',(.64,.36,.08),.78,.25,image_finish('brass_brush',(.88,.59,.18),'metal'))
dark=material('Graphite joints',(.038,.044,.057),.72,.32,image_finish('graphite_machined',(.075,.087,.11),'dark'))
steel=material('Polished steel',(.23,.28,.31),.86,.24)
rose=material('Rose optic',(.65,.025,.18),.25,.2,emit=1.3)
socket=material('Black recessed socket',(.011,.014,.022),.25,.38)

def empty(name, pos, parent=None):
    o=bpy.data.objects.new(name,None); scene.collection.objects.link(o)
    if parent:
        o.parent=parent; o.location=Vector(pos)-parent.matrix_world.translation
    else: o.location=pos
    bpy.context.view_layer.update()
    return o

root=empty('PuppetRoot',(0,0,0))
body=empty('Body',(0,0,.47),root)
head=empty('Head',(0,0,.735),body)
arms={}; elbows={}; legs={}; knees={}
for side,sgn in [('L',1),('R',-1)]:
    arms[side]=empty('Arm_'+side,(sgn*.205,0,.605),body)
    elbows[side]=empty('Elbow_'+side,(sgn*.24,.008,.422),arms[side])
    legs[side]=empty('Leg_'+side,(sgn*.085,0,.325),root)
    knees[side]=empty('Knee_'+side,(sgn*.11,.002,.185),legs[side])
groups={}

def finish(o,name,mat,parent):
    o.name=name; o.data.materials.append(mat)
    bpy.context.view_layer.objects.active=o
    o.select_set(True)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for f in o.data.polygons: f.use_smooth=True
    # A shared 20 cm tile keeps the material grain consistent across parts.
    uv=o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap')
    for f in o.data.polygons:
        axis=max(range(3),key=lambda a:abs(f.normal[a]))
        for li in f.loop_indices:
            co=o.data.vertices[o.data.loops[li].vertex_index].co
            u,v=(co.y,co.z) if axis==0 else ((co.x,co.z) if axis==1 else (co.x,co.y))
            uv.data[li].uv=(u/.2+.5,v/.2+.5)
    world=o.matrix_world.copy(); o.parent=parent; o.matrix_world=world
    groups.setdefault(parent,[]).append(o)
    o.select_set(False)
    return o

def sphere(name,pos,scale,mat,parent,segments=20,rings=10):
    segments=min(segments,16); rings=min(rings,8)
    if max(scale)<=.03: segments=min(segments,12); rings=min(rings,6)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1,location=pos)
    o=bpy.context.object; o.scale=scale
    return finish(o,name,mat,parent)

def bevel(o,amount=.004,segments=2):
    m=o.modifiers.new('Soft cast edges','BEVEL'); m.width=amount; m.segments=segments
    bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=m.name)

def box(name,pos,size,mat,parent,amount=.007):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos)
    o=bpy.context.object; o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bevel(o,amount,2)
    return finish(o,name,mat,parent)

def cylinder(name,pos,radius,depth,mat,parent,axis='Z',vertices=20):
    vertices=min(vertices,20 if radius>.05 else (16 if radius>.025 else 12))
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=pos)
    o=bpy.context.object
    if axis=='Y': o.rotation_euler.x=math.pi/2
    elif axis=='X': o.rotation_euler.y=math.pi/2
    if radius>.025: bevel(o,min(.003,radius*.12,depth*.15),1)
    return finish(o,name,mat,parent)

def strut(name,a,b,r,mat,parent,vertices=12):
    a,b=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=(b-a).length,location=(a+b)/2)
    o=bpy.context.object; o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    if r>.02: bevel(o,min(.003,r*.1),1)
    return finish(o,name,mat,parent)

def torus(name,pos,major,minor,mat,parent,axis='Z',segments=24):
    bpy.ops.mesh.primitive_torus_add(major_segments=min(segments,20),minor_segments=4,location=pos,major_radius=major,minor_radius=minor)
    o=bpy.context.object
    if axis=='Y': o.rotation_euler.x=math.pi/2
    elif axis=='X': o.rotation_euler.y=math.pi/2
    return finish(o,name,mat,parent)

def lathe(name,rings,mat,parent,segments=28):
    verts=[]; faces=[]
    for z,rx,ry,cy in rings:
        for k in range(segments):
            a=k*math.tau/segments; verts.append((rx*math.cos(a),cy+ry*math.sin(a),z))
    for j in range(len(rings)-1):
        for k in range(segments):
            a=j*segments+k; b=j*segments+(k+1)%segments
            faces.append((a,b,b+segments,a+segments))
    faces.append(tuple(range(segments-1,-1,-1)))
    faces.append(tuple((len(rings)-1)*segments+k for k in range(segments)))
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces); mesh.update()
    o=bpy.data.objects.new(name,mesh); scene.collection.objects.link(o)
    return finish(o,name,mat,parent)

# Barrel chest, inset neck deck, pelvis and waist bellows.
lathe('Rounded enamel chest',[(.397,.065,.052,0),(.42,.118,.084,0),(.46,.147,.098,0),(.535,.161,.108,0),(.588,.147,.092,0),(.615,.107,.072,0)],plum,body)
torus('Chest shoulder collar',(0,0,.606),.099,.009,gold,body)
cylinder('Shoulder deck',(0,0,.612),.096,.018,dark,body,vertices=28)
cylinder('Neck stem',(0,0,.648),.040,.075,steel,head)
for z in [.627,.641,.655,.669]: torus('Neck bellows',(0,0,z),.043,.006,dark,head,segments=20)
lathe('Pelvis shell',[(.28,.055,.035,0),(.295,.089,.052,0),(.338,.106,.059,0),(.367,.081,.043,0)],plum,body,segments=20)
cylinder('Waist joint',(0,0,.382),.054,.046,steel,body)
for z in [.368,.382,.396]: torus('Waist ribs',(0,0,z),.057,.006,dark,body,segments=20)
box('Pelvis front inset',(0,.055,.321),(.067,.012,.07),gold,body,.009)
box('Pelvis plate',(0,.063,.325),(.054,.012,.056),plum,body,.009)

# Chest gold medallion: rose energy lens and a radial ring of brass studs.
cylinder('Chest black socket',(0,.104,.502),.062,.018,socket,body,'Y',28)
cylinder('Chest bezel',(0,.118,.502),.056,.023,gold,body,'Y',28)
cylinder('Chest recess',(0,.133,.502),.041,.006,dark,body,'Y',24)
sphere('Chest lens',(0,.142,.502),(.035,.014,.035),rose,body,24,12)
sphere('Chest glint',(-.011,.154,.515),(.006,.002,.009),ivory,body,12,6)
for k in range(8):
    a=k*math.tau/8
    sphere('Lens bezel rivet',(.048*math.cos(a),.134,.502+.048*math.sin(a)),(.004,.003,.004),gold,body,8,4)
for x,z in [(-.098,.561),(.098,.561),(-.102,.463),(.103,.463),(-.05,.428),(.05,.428)]:
    y=.100 if z>.46 else .085
    sphere('Chest shell rivet',(x,y,z),(.004,.003,.004),gold,body,8,4)
for s in [-1,1]:
    strut('Chest brass seam',(s*.03,.085,.415),(s*.131,.074,.459),.003,gold,body,8)

# Ceramic skull: wide domed cranium, cheek taper, inset sockets and porcelain chin lobes.
lathe('Porcelain skull',[(.691,.033,.028,.030),(.710,.059,.043,.020),(.741,.085,.060,.012),(.777,.109,.076,0),(.821,.112,.079,-.007),(.854,.095,.070,-.011),(.879,.062,.047,-.014),(.892,.008,.007,-.014)],ivory,head,32)
for s in [-1,1]:
    sphere('Porcelain chin lobe',(s*.028,.053,.707),(.026,.034,.023),ivory,head,16,8)
    # Sockets follow the front face; slanted rose lenses make the skull friendly and toy-like.
    cylinder('Eye socket',(s*.052,.073,.795),.029,.012,socket,head,'Y',24)
    torus('Eye steel rim',(s*.052,.082,.795),.0235,.0038,steel,head,'Y',24)
    sphere('Rose eye',(s*.052,.085,.795),(.020,.010,.023),rose,head,24,12)
    sphere('Eye glint',(s*.052-.006,.095,.804),(.004,.002,.005),ivory,head,12,6)
    cylinder('Ear drum',(s*.110,-.005,.793),.038,.036,plum,head,'X',20)
    cylinder('Ear brass cap',(s*.132,-.005,.793),.029,.010,gold,head,'X',20)
    cylinder('Ear inset',(s*.138,-.005,.793),.017,.004,dark,head,'X',16)
    cylinder('Ear core',(s*.141,-.005,.793),.008,.005,gold,head,'X',12)
    sphere('Mask cheek stud',(s*.086,.061,.753),(.004,.003,.004),gold,head,8,4)
# Tiny triangular nose vent on the lower face.
mesh=bpy.data.meshes.new('Nose triangle'); mesh.from_pydata([(-.010,.080,.758),(.010,.080,.758),(0,.082,.770)],[],[(0,2,1)]); mesh.update()
o=bpy.data.objects.new('Nose vent',mesh); scene.collection.objects.link(o); finish(o,'Nose vent',socket,head)

# Rear winding key is readable from side and rear and stays clear of the head.
cylinder('Rear gearbox',(0,-.107,.54),.045,.025,dark,body,'Y',20)
cylinder('Key spindle',(0,-.137,.54),.012,.059,gold,body,'Y',12)
box('Key central bridge',(0,-.171,.562),(.105,.015,.015),gold,body,.004)
for s in [-1,1]:
    torus('Winding key loop',(s*.063,-.173,.574),.027,.010,gold,body,'Y',20)
box('Rear panel',(0,-.108,.474),(.085,.015,.073),plum,body,.012)
for s in [-1,1]:
    for z in [.446,.496]: sphere('Rear screw',(s*.031,-.119,z),(.003,.003,.003),gold,body,8,4)

# Two rigid arms: black hinge barrels, plum pauldrons and brassy axle caps.
for side,s in [('L',1),('R',-1)]:
    arm=arms[side]; fore=elbows[side]
    cylinder('Shoulder connector',(s*.165,0,.605),.043,.045,dark,arm,'X',20)
    sphere('Round pauldron',(s*.209,0,.607),(.064,.074,.074),plum,arm,20,10)
    cylinder('Shoulder brass hub',(s*.263,0,.61),.033,.013,gold,arm,'X',20)
    cylinder('Shoulder inset',(s*.272,0,.61),.021,.004,dark,arm,'X',16)
    cylinder('Shoulder centre',(s*.276,0,.61),.011,.005,steel,arm,'X',12)
    strut('Upper arm shell',(s*.219,0,.564),(s*.239,.005,.438),.031,plum,arm)
    strut('Upper arm highlight',(s*.206,.028,.555),(s*.226,.033,.451),.004,gold,arm,8)
    cylinder('Elbow barrel',(s*.24,.008,.423),.029,.070,dark,fore,'X',16)
    for off in [-.035,.035]: cylinder('Elbow cap',(s*.24+off,.008,.423),.023,.009,gold,fore,'X',16)
    strut('Forearm cuff',(s*.241,.008,.401),(s*.255,.040,.312),.037,plum,fore,16)
    torus('Forearm rim',(s*.252,.031,.33),.037,.0035,steel,fore,segments=20)
    sphere('Wrist ball',(s*.257,.04,.295),(.024,.024,.022),steel,fore,16,8)
    box('Mitten backplate',(s*.257,.055,.276),(.047,.032,.043),plum,fore,.010)
    # Simplified two curved mechanical fingers plus thumb form an open mitten claw.
    for f in [-1,1]:
        x=s*.257+f*.015
        strut('Claw finger upper',(x,.054,.267),(x+f*.009,.080,.245),.010,dark,fore,10)
        strut('Claw curled tip',(x+f*.009,.080,.245),(x,.095,.242),.010,steel,fore,10)
    strut('Claw thumb',(s*.283,.035,.279),(s*.296,.063,.254),.011,steel,fore,10)

# Shorter jointed legs and oversized rounded boots give the minion its chibi silhouette.
for side,s in [('L',1),('R',-1)]:
    leg=legs[side]; shin=knees[side]
    cylinder('Hip bearing',(s*.10,0,.321),.039,.052,dark,leg,'X',20)
    cylinder('Hip gold cap',(s*.131,0,.321),.027,.010,gold,leg,'X',16)
    cylinder('Hip core',(s*.138,0,.321),.014,.005,steel,leg,'X',12)
    strut('Thigh casing',(s*.094,0,.30),(s*.11,.002,.201),.036,plum,leg,16)
    strut('Thigh trim',(s*.079,.032,.289),(s*.094,.036,.21),.0035,gold,leg,8)
    cylinder('Knee axle',(s*.11,.002,.185),.032,.077,dark,shin,'X',16)
    for off in [-.041,.041]:
        cylinder('Knee cap',(s*.11+off,.002,.185),.025,.008,gold,shin,'X',16)
        cylinder('Knee pin',(s*.11+off*1.12,.002,.185),.012,.005,steel,shin,'X',12)
    strut('Shin casing',(s*.11,.002,.167),(s*.117,.002,.072),.037,plum,shin,16)
    strut('Shin brass trim',(s*.095,.034,.153),(s*.102,.034,.09),.0035,gold,shin,8)
    cylinder('Ankle axle',(s*.117,.003,.062),.022,.074,dark,shin,'X',16)
    box('Boot dark sole',(s*.117,.036,.02),(.120,.180,.028),dark,shin,.012)
    sphere('Boot rounded armour',(s*.117,.027,.047),(.055,.080,.039),plum,shin,20,10)
    sphere('Boot steel toe',(s*.117,.082,.042),(.048,.050,.027),steel,shin,20,10)
    torus('Boot ankle rim',(s*.117,.003,.070),.037,.004,gold,shin,segments=20)
    sphere('Boot front gold rivet',(s*.14,.087,.057),(.004,.003,.004),gold,shin,8,4)

# Join components sharing a rigid pivot, preserving material assignments and UVs.
for pivot,parts in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    bpy.ops.object.join()
    o=bpy.context.object; o.name=pivot.name+'_Geometry'
    world=o.matrix_world.copy(); o.parent=pivot; o.matrix_world=world
    # Set mesh origin to the rigid pivot so its transform remains identity after import.
    scene.cursor.location=pivot.matrix_world.translation
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    if pivot==head: o.scale=(1.16,1.12,1.07)

animated=[body,head,*arms.values(),*elbows.values(),*legs.values(),*knees.values()]
rest={o:(o.location.copy(),o.rotation_euler.copy()) for o in animated}

def restore():
    for o,(loc,rot) in rest.items():o.location=loc.copy(); o.rotation_euler=rot.copy()

durations={'Idle':2.4,'Walk':1.0,'Swim':1.6,'Attack':1.1}
for clip,duration in durations.items():
    n=round(duration*30)
    for f in range(0,n+1,3):
        t=f/n; a=math.tau*t
        restore()
        if clip=='Idle':
            body.location.z += .006*math.sin(a)
            head.rotation_euler.z=.035*math.sin(a)
            for side,s in [('L',1),('R',-1)]:
                arms[side].rotation_euler.y=s*.025*math.sin(a)
                elbows[side].rotation_euler.x=.03*math.sin(a)
        elif clip=='Walk':
            body.location.z += .008*(1-math.cos(a*2))/2
            body.rotation_euler.z=.035*math.sin(a)
            for side,s in [('L',1),('R',-1)]:
                swing=math.sin(a)*s
                legs[side].rotation_euler.x=.40*swing
                knees[side].rotation_euler.x=-.44*max(0,swing)
                arms[side].rotation_euler.x=-.30*swing
                elbows[side].rotation_euler.x=-.15-.10*swing
        elif clip=='Swim':
            body.rotation_euler.x=-.12+.035*math.sin(a)
            head.rotation_euler.x=.10
            for side,s in [('L',1),('R',-1)]:
                arms[side].rotation_euler.y=-s*(.42+.30*math.sin(a))
                arms[side].rotation_euler.x=-.35+.18*math.cos(a)
                elbows[side].rotation_euler.x=-.25+.18*math.sin(a)
                legs[side].rotation_euler.x=.16*math.sin(a+s*.45)
                knees[side].rotation_euler.x=-.16-.12*math.sin(a+s*.45)
        else:
            pulse=math.sin(math.pi*t)**2
            strike=math.exp(-((t-.47)/.16)**2)*math.sin(math.pi*t)
            body.rotation_euler.x=-.08*pulse; head.rotation_euler.x=.12*pulse
            for side,s in [('L',1),('R',-1)]:
                arms[side].rotation_euler.x=-1.30*strike+.25*pulse
                arms[side].rotation_euler.y=-s*.13*pulse
                elbows[side].rotation_euler.x=-.55*pulse+.35*strike
        for o in animated:
            o.keyframe_insert('location',frame=f)
            o.keyframe_insert('rotation_euler',frame=f)
    # Give each articulated part a same-named NLA track; exporter merges by track.
    for o in animated:
        ad=o.animation_data; action=ad.action
        action.name=clip+'_'+o.name
        track=ad.nla_tracks.new(); track.name=clip
        strip=track.strips.new(clip,0,action); strip.name=clip
        ad.action=None
        # Remove numerical drift at clip boundaries and use linear interpolation for rigid motion.
        for slot in action.slots:
            for layer in action.layers:
                for st in layer.strips:
                    if hasattr(st,'channelbag'):
                        bag=st.channelbag(slot)
                        if bag:
                            for fc in bag.fcurves:
                                for k in fc.keyframe_points:k.interpolation='LINEAR'
    restore()

scene.frame_set(0)
# Disable NLA evaluation for the saved neutral pose; export still serializes the strips.
for o in animated:
    o.animation_data.use_nla=False
restore()
bpy.context.view_layer.update()
scene.frame_end=72
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'eco_puppet.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'eco_puppet.glb'),export_format='GLB',export_yup=True,
    export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True,
    export_cameras=False,export_lights=False,export_apply=True)
print('PUPPET_BUILD_COMPLETE')
