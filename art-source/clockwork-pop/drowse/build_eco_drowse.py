"""Drowse beetle: procedural surfaces and rigid transform clips. Blender 5.2."""
import bpy, bmesh, math, json
import numpy as np
from mathutils import Vector
from pathlib import Path

bpy.ops.wm.read_factory_settings(use_empty=True)
OUT = Path(__file__).resolve().parent
TAU = math.tau

def image(name, pixels):
    im = bpy.data.images.new(name, width=1024, height=1024, alpha=True)
    im.colorspace_settings.name = 'sRGB'
    im.pixels.foreach_set(np.asarray(pixels, dtype=np.float32).ravel())
    im.filepath_raw = str(OUT / (name + '.png')); im.file_format = 'PNG'; im.save(); im.pack()
    return im

y,x=np.mgrid[0:1024,0:1024]/1024
rng=np.random.default_rng(39)
def texture(base, fluct):
    broad=(np.sin(TAU*x*3+np.sin(TAU*y))*np.cos(TAU*y*2)+np.sin(TAU*(x*5+y*3))*.35)*.035
    grain=(rng.random(x.shape)-.5)*.007
    rgb=np.zeros((*x.shape,4)); rgb[:,:,:3]=np.array(base)[None,None,:]*(1+(broad+grain)[:,:,None]*fluct); rgb[:,:,3]=1
    return rgb
green=texture((.40,.77,.055),1)
for i in range(38):
    cx,cy=rng.random(2); rx=rng.uniform(.02,.09); ry=rx*rng.uniform(.55,1.8)
    d=((x-cx)/rx)**2+((y-cy)/ry)**2
    a=np.clip((1.1-d)*4,0,1)*rng.uniform(.07,.23)
    tint=np.array((.64,.86,.16) if i%3 else (.45,.72,.07))
    green[:,:,:3]=green[:,:,:3]*(1-a[:,:,None])+tint*a[:,:,None]
green_im=image('lime_enamel',green)
bronze=texture((.67,.385,.15),2)
bronze[:,:,:3]*=(1+.025*np.sin(TAU*y*90))[:,:,None]
bronze_im=image('warm_bronze',bronze)
dark_im=image('deep_olive_rubber',texture((.038,.045,.022),1))
atlas=np.zeros((1024,1024,4)); atlas[:,:,3]=1
swatches=[(.91,.47,.015),(.96,.94,.70),(.42,.49,.32),(.075,.045,.115)]
for j,c in enumerate(swatches):
    yy,xx=divmod(j,2)
    atlas[yy*512:(yy+1)*512,xx*512:(xx+1)*512,:3]=c
accent_im=image('optic_and_fastener_atlas',atlas)

def mat(name, im, rough=.32, metal=0, tile=None):
    m=bpy.data.materials.new(name); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Roughness'].default_value=rough; p.inputs['Metallic'].default_value=metal
    t=m.node_tree.nodes.new('ShaderNodeTexImage'); t.image=im
    m.node_tree.links.new(t.outputs['Color'],p.inputs['Base Color'])
    if tile is not None: m['tile']=tile
    return m
LIME=mat('Satin lime enamel',green_im,.29,.08)
EDGE=mat('Polished lime rim',green_im,.23,.12)
BRONZE=mat('Burnished bronze fittings',bronze_im,.27,.65)
BELLY=mat('Warm bronze belly',bronze_im,.44,.25)
RUBBER=mat('Deep olive joints and seams',dark_im,.55)
EYE=mat('Dark sleepy optics',accent_im,.12,.18,3)
AMBER=mat('Amber lens',accent_im,.14,.32,0)
CREAM=mat('Eye catchlights',accent_im,.17,0,1)
RIVET=mat('Muted silver screws',accent_im,.29,.6,2)

def empty(name,pos=(0,0,0),parent=None):
    ob=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(ob); ob.location=pos; ob.parent=parent; return ob
Body=empty('Body')

def uv(ob):
    mesh=ob.data
    lay=mesh.uv_layers.active or mesh.uv_layers.new(name='UVMap')
    for f in mesh.polygons:
        axis=max(range(3),key=lambda i:abs(f.normal[i])); m=mesh.materials[f.material_index]
        tile=m.get('tile',None)
        for li in f.loop_indices:
            co=ob.matrix_world @ mesh.vertices[mesh.loops[li].vertex_index].co
            u,v=((co.y,co.z) if axis==0 else (co.x,co.z) if axis==1 else (co.x,co.y))
            if tile is None: lay.data[li].uv=(u/.8,v/.8)
            else:
                yy,xx=divmod(int(tile),2); lay.data[li].uv=(xx*.5+.1+(u%1)*.3,yy*.5+.1+(v%1)*.3)

def finish(ob,name,m,parent=Body):
    ob.name=name; ob.data.materials.append(m)
    for f in ob.data.polygons: f.use_smooth=True
    bpy.context.view_layer.update(); uv(ob)
    if parent:
        mw=ob.matrix_world.copy(); ob.parent=parent; ob.matrix_world=mw
    return ob

def sphere(name,pos,scale,m,parent=Body,seg=24,rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,radius=1,location=pos)
    ob=bpy.context.object; ob.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(ob,name,m,parent)

def tube(name,pts,radius,m,parent=Body,sides=8):
    verts=[]; faces=[]
    for i,pt in enumerate(pts):
        p=Vector(pt); tangent=(Vector(pts[min(i+1,len(pts)-1)])-Vector(pts[max(0,i-1)])).normalized()
        normal=tangent.cross(Vector((0,0,1)))
        if normal.length<.01: normal=tangent.cross(Vector((0,1,0)))
        normal.normalize(); bit=tangent.cross(normal).normalized()
        for j in range(sides): verts.append(p+radius*(normal*math.cos(TAU*j/sides)+bit*math.sin(TAU*j/sides)))
    for i in range(len(pts)-1):
        for j in range(sides): a=i*sides+j; b=i*sides+(j+1)%sides; faces.append((a,b,b+sides,a+sides))
    faces.extend([tuple(reversed(range(sides))),tuple((len(pts)-1)*sides+j for j in range(sides))])
    me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.update(); ob=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(ob)
    return finish(ob,name,m,parent)

def link(name,a,b,r,m,parent=Body):
    ob=sphere(name,(Vector(a)+Vector(b))*.5,(r,r,(Vector(b)-Vector(a)).length*.5+r*.45),m,parent,16,8)
    ob.rotation_euler=(Vector(b)-Vector(a)).to_track_quat('Z','Y').to_euler(); return ob

def join(name,objects,parent):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects: ob.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]; bpy.ops.object.join(); ob=objects[0]; ob.name=name
    mw=ob.matrix_world.copy(); ob.parent=parent; ob.matrix_world=mw; return ob

C=Vector((0,-.075,.47)); R=Vector((.505,.48,.35))
def point(theta,phi,offset=0):
    return C+Vector(((R.x+offset)*math.sin(theta)*math.cos(phi),(R.y+offset)*math.sin(theta)*math.sin(phi),(R.z+offset)*math.cos(theta)))

def patch(name,t0,t1,p0,p1,nt,np_,m):
    verts=[]; faces=[]
    for i in range(nt+1):
        t=t0+(t1-t0)*i/nt
        for j in range(np_+1): verts.append(point(t,p0+(p1-p0)*j/np_))
    for i in range(nt):
        for j in range(np_): a=i*(np_+1)+j; faces.append((a,a+np_+1,a+np_+2,a+1))
    me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.update(); ob=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(ob); finish(ob,name,m)
    sol=ob.modifiers.new('Rolled shell lip','SOLIDIFY'); sol.thickness=.015
    bpy.context.view_layer.objects.active=ob; bpy.ops.object.modifier_apply(modifier=sol.name)
    bev=ob.modifiers.new('Soft panel edges','BEVEL'); bev.width=.006; bev.segments=2; bev.limit_method='ANGLE'; bev.angle_limit=.45
    bpy.ops.object.modifier_apply(modifier=bev.name); uv(ob); return ob

core=sphere('Dark interior chassis',C,(.49,.466,.335),RUBBER,seg=32,rings=16)
belly=sphere('Bronze abdominal drum',(0,-.075,.315),(.482,.448,.166),BELLY,seg=32,rings=12)
shell=[]
# Broad divided top cap, front central panel and two rounded elytra wings.
shell.append(patch('Left upper shell',.014,.72,math.pi/2+.018,3*math.pi/2-.018,9,22,LIME))
shell.append(patch('Right upper shell',.014,.72,-math.pi/2+.018,math.pi/2-.018,9,22,LIME))
shell.append(patch('Forehead shell plate',.82,1.54,1.06,2.08,10,12,LIME))
shell.append(patch('Right broad elytron',.82,1.73,-1.55,1.015,12,24,LIME))
shell.append(patch('Left broad elytron',.82,1.73,2.127,4.70,12,24,LIME))
# Lime equatorial bumper, parted bronze seams running over lower abdomen.
rim=tube('Lime equator bead',[tuple(point(1.735,TAU*i/64,.002)) for i in range(65)],.023,EDGE,sides=10)
belly_lines=[]
for phi in np.linspace(-math.pi,math.pi,13)[:-1]:
    pts=[]
    for a in np.linspace(-.83,.88,9):
        pts.append((.484*math.cos(a)*math.cos(phi),-.075+.450*math.cos(a)*math.sin(phi),.315+.168*math.sin(a)))
    belly_lines.append(tube('Belly segment seam',pts,.0025,BRONZE,sides=5))
# Round, forward-facing head with softened cheek edge.
neck=sphere('Head gasket',(0,.406,.372),(.255,.11,.221),RUBBER)
head=sphere('Round lime head',(0,.478,.381),(.252,.230,.226),LIME,seg=32,rings=16)
face=[]
for s in [-1,1]:
    e=(s*.136,.665,.415)
    face.append(sphere('Dark oval eye',e,(.071,.034,.081),EYE,seg=24,rings=12))
    face.append(sphere('Amber lower eye',(s*.136,.695,.383),(.044,.011,.026),AMBER,seg=18,rings=8))
    face.append(sphere('Cream eye glint',(s*.154,.697,.448),(.019,.010,.019),CREAM,seg=16,rings=8))
    # The relaxed upper eyelid cuts into the tall optics without hiding their pupil.
    pts=[(s*.136+.077*math.cos(a),.678,.424+.075*math.sin(a)) for a in np.linspace(.35,2.85,12)]
    face.append(tube('Relaxed upper brow',pts,.014,LIME,sides=8))
    face.append(sphere('Soft lowered eyelid',(s*.136,.688,.479),(.068,.017,.024),LIME,seg=20,rings=8))
mouth=tube('Small restful smile',[(v,.692-.015*(v/.105)**2,.285+.012*(v/.105)**2) for v in np.linspace(-.105,.105,18)],.006,RUBBER,sides=7)
face.append(mouth)
# High amber headlamp inset into the sloping frontal shell.
gempos=point(1.03,math.pi/2,.009)
gem_normal=Vector((0,.86,.51))
def oriented_disc(name,p,scale,m):
    ob=sphere(name,p,scale,m,seg=28,rings=12); ob.rotation_euler=gem_normal.to_track_quat('Y','Z').to_euler(); return ob
gem=[oriented_disc('Bronze brow optic bezel',gempos,(.080,.022,.080),BRONZE),oriented_disc('Amber brow jewel',gempos+gem_normal*.024,(.062,.018,.062),AMBER)]
gem.append(sphere('Brow jewel highlight',gempos+Vector((-.016,.032,.034)),(.018,.008,.017),CREAM,seg=16,rings=8))
# Small hardware and sleepy indents on broad side panels.
hardware=[]
for s in [-1,1]:
    for theta,phi in [(1.47,.55),(1.42,-.68),(.91,.65),(.68,.77),(.50,1.9)]:
        ph=phi if s==1 else math.pi-phi
        p=point(theta,ph,.008)
        hardware.append(sphere('Flush shell rivet',p,(.010,.010,.007),RIVET,seg=12,rings=6))
    # Soft purple teardrop vent gives the side shell its sleepy expression.
    p=point(1.09,.08 if s==1 else math.pi-.08,.002)
    hardware.append(sphere('Side sleepy vent',(p.x,p.y,p.z),(.008,.049,.022),RUBBER,seg=20,rings=8))
    hardware.append(sphere('Vent interior',(p.x+s*.005,p.y+.007,p.z-.002),(.007,.034,.013),EYE,seg=16,rings=8))
    p=point(1.50,-.61 if s==1 else math.pi+.61,.010)
    hardware.append(sphere('Dark recessed rear port',p,(.008,.022,.030),RUBBER,seg=16,rings=8))
    hardware.append(tube('Bronze oval rear port',[(p.x+s*.006,p.y+.023*math.cos(a),p.z+.031*math.sin(a)) for a in np.linspace(0,TAU,25)],.0045,BRONZE,sides=6))
for phi in np.linspace(0,TAU,13)[:-1]:
    hardware.append(tube('Equator band separation',[tuple(point(theta,phi,.026)) for theta in np.linspace(1.676,1.795,5)],.0025,RUBBER,sides=5))

# Six root-level hip pivots; feet and armor remain rigid within each group.
legs=[]
for side,s in [('L',-1),('R',1)]:
    for i,yy in enumerate([.235,-.065,-.355]):
        hip=Vector((s*(.405 if i!=1 else .455),yy,.288))
        pivot=empty(f'Leg_{side}_{i}',hip)
        knee=Vector((s*(.51 if i!=1 else .555),yy+.01,.185))
        ankle=Vector((s*(.535 if i!=1 else .58),yy+.057,.074))
        toe=Vector((s*(.54 if i!=1 else .59),yy+.079,.033))
        pieces=[sphere('Hip cup',hip,(.064,.063,.057),RUBBER,pivot,16,8),link('Bronze shoulder',hip,knee,.045,BRONZE,pivot),link('Lime shin armor',knee,ankle,.057,LIME,pivot),sphere('Ankle hinge',ankle,(.042,.037,.038),BRONZE,pivot,16,8),link('Dark rounded foot',ankle,toe,.032,RUBBER,pivot)]
        legs.append(pivot); join(f'{side}{i}_jointed_foot',pieces,pivot)

antennae=[]
for s in [-1,1]:
    base=Vector((s*.152,.475,.53)); tip=Vector((s*.222,.505,.708))
    pivot=empty('Antenna_L' if s<0 else 'Antenna_R',base,Body)
    antennae.append(pivot)
    parts=[sphere('Antenna socket',base,(.031,.031,.030),RUBBER,pivot,16,8),link('Bronze antenna shaft',base,tip,.014,BRONZE,pivot),sphere('Round bronze knob',tip,(.037,.037,.041),BRONZE,pivot,20,10)]
    join('Left knob antenna' if s<0 else 'Right knob antenna',parts,pivot)

# Combine contiguous/static pieces by articulation group, keeping major surfaces separate.
join('Divided lime shell plates',shell+[rim],Body)
join('Bronze segmented abdomen',[belly]+belly_lines,Body)
join('Soft face optics',face,Body)
join('Amber forehead ornament',gem,Body)
join('Flush shell fittings',hardware,Body)

# All clips have identity endpoint poses and no root translation. NLA names become glTF clips.
animated=[Body]+legs+antennae
rest={o:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in animated}
def clip(name,frames,mode):
    for ob in animated: ob.animation_data_clear()
    for frame in range(0,frames+1,4):
        u=frame/frames; phase=TAU*u
        for ob in animated:
            loc,rot,scale=rest[ob]; ob.location=loc; ob.rotation_euler=rot; ob.scale=scale
        if mode=='idle':
            Body.rotation_euler[0]=.018*math.sin(phase)
            Body.scale[2]=1+.011*math.sin(phase)
            for i,a in enumerate(antennae): a.rotation_euler[0]=.05*math.sin(phase+i*.5)
        elif mode in ('walk','swim'):
            amp=.21 if mode=='walk' else .33
            for i,l in enumerate(legs):
                p=phase+(i%3)*math.pi*.66+(math.pi if i>=3 else 0)
                l.rotation_euler[0]=amp*(math.sin(p)-math.sin(p-phase))
                l.rotation_euler[1]=.07*(math.cos(p)-math.cos(p-phase))
            Body.rotation_euler[1]=.025*math.sin(phase*2)
            for i,a in enumerate(antennae): a.rotation_euler[0]=.07*math.sin(phase+i*.4)
        else:
            pulse=math.sin(math.pi*u)**2
            Body.rotation_euler[0]=-.16*pulse
            for i,l in enumerate(legs): l.rotation_euler[0]=(.32 if i%3==0 else -.10)*pulse
            for i,a in enumerate(antennae): a.rotation_euler[0]=-.28*pulse
        for ob in animated:
            ob.keyframe_insert('rotation_euler',frame=frame)
            if ob==Body: ob.keyframe_insert('scale',frame=frame)
    for ob in animated:
        action=ob.animation_data.action; action.name=f'{name}_{ob.name}'
        tr=ob.animation_data.nla_tracks.new(); tr.name=name
        strip=tr.strips.new(name,0,action); strip.action_frame_start=0; strip.action_frame_end=frames
        ob.animation_data.action=None
        # Additional actions/tracks created on each clip are preserved separately below.
    return [(ob,ob.animation_data.nla_tracks[0].strips[0].action) for ob in animated]

all_clips={}
for name,fr,mode in [('Idle',96,'idle'),('Walk',32,'walk'),('Swim',48,'swim'),('Attack',24,'attack')]: all_clips[name]=clip(name,fr,mode)
for ob in animated:
    ob.animation_data_clear(); loc,rot,scale=rest[ob]; ob.location=loc; ob.rotation_euler=rot; ob.scale=scale
    ob.animation_data_create()
    for name,pairs in all_clips.items():
        action=next(a for o,a in pairs if o==ob)
        track=ob.animation_data.nla_tracks.new(); track.name=name
        strip=track.strips.new(name,0,action); strip.blend_type='REPLACE'; strip.extrapolation='NOTHING'
        track.mute=True

bpy.context.scene.render.fps=24
bpy.context.scene.frame_set(0)
for ob in bpy.context.scene.objects:
    if ob.type=='MESH': ob.data.name=ob.name
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'eco_drowse.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'eco_drowse.glb'),export_format='GLB',export_yup=True,export_animations=True,export_cameras=False,export_lights=False,export_animation_mode='NLA_TRACKS',export_nla_strips=True)
meshes=[ob for ob in bpy.context.scene.objects if ob.type=='MESH']
tri=0
for ob in meshes: ob.data.calc_loop_triangles(); tri+=len(ob.data.loop_triangles)
(OUT/'build_stats.json').write_text(json.dumps({'triangles':tri,'mesh_objects':len(meshes),'materials':len(bpy.data.materials),'textures':4,'clips':list(all_clips)},indent=2))
