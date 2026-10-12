"""Independent deployable tether anchor, procedural construction and four packed maps."""
import bpy, bmesh, math, json
import numpy as np
from mathutils import Vector
from pathlib import Path

bpy.ops.wm.read_factory_settings(use_empty=True)
OUT = Path(__file__).parent
OUT.mkdir(parents=True, exist_ok=True)
TAU = math.tau

def texture(name, base, kind):
    n = 1024
    y, x = np.mgrid[0:n, 0:n].astype(float) / n
    rng = np.random.default_rng(129 + kind)
    grain = rng.normal(0, .0025, (n,n))
    if kind == 0:
        wave = .021*np.cos(TAU*(x*3 + .2*np.sin(y*TAU))) + .012*np.sin(TAU*y*6)
        # Fine porcelain pearlescence and long deliberate polished highlights.
        shine = .025*np.exp(-((x-.35)/.11)**2)
        detail = wave + grain + shine
    elif kind == 1:
        detail = .027*np.sin(TAU*x*2) + .012*np.cos(TAU*y*3) + grain
        detail += .035*np.exp(-((x-.31)/.025)**2)
        detail -= .016*(np.cos(TAU*x*8)>.992)
    elif kind == 2:
        detail = .028*np.sin(TAU*y*3) + .018*np.sin(TAU*y*143) + grain
        detail += .05*np.exp(-((x-.45)/.055)**2)
    else:
        detail = .060*np.sin(TAU*(x+y*2)) + .038*np.cos(TAU*(x*5-y*3))
        detail += .055*np.exp(-((x-.63)/.018)**2)
    rgb = np.clip(np.array(base)[None,None,:]*(1+detail[:,:,None]), .001, 1)
    pix = np.concatenate([rgb, np.ones((n,n,1))], axis=2).astype('float32')
    im = bpy.data.images.new(name, width=n, height=n, alpha=False)
    im.colorspace_settings.name = 'sRGB'
    im.pixels.foreach_set(pix.ravel())
    im.filepath_raw = str(OUT/(name+'.png'))
    im.file_format = 'PNG'
    im.save(); im.pack()
    return im

ivory_tex = texture('ivory_porcelain', (.90,.85,.67), 0)
plum_tex = texture('plum_lacquer', (.43,.035,.16), 1)
gold_tex = texture('brushed_gold', (.87,.62,.22), 2)
rose_tex = texture('crystal_rose', (.78,.015,.48), 3)

def mat(name, color, image, metallic=0, rough=.3, emission=0, tint=1):
    m = bpy.data.materials.new(name); m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color,1)
    bs.inputs['Metallic'].default_value = metallic
    bs.inputs['Roughness'].default_value = rough
    bs.inputs['Coat Weight'].default_value = .24 if metallic < .8 else .12
    bs.inputs['Coat Roughness'].default_value = .18
    tex = m.node_tree.nodes.new('ShaderNodeTexImage'); tex.image = image
    if tint != 1:
        mul = m.node_tree.nodes.new('ShaderNodeMixRGB'); mul.blend_type='MULTIPLY'
        mul.inputs[0].default_value=1; mul.inputs[2].default_value=(tint,tint,tint,1)
        m.node_tree.links.new(tex.outputs['Color'],mul.inputs[1]); out=mul.outputs[0]
    else: out=tex.outputs['Color']
    m.node_tree.links.new(out,bs.inputs['Base Color'])
    if emission:
        m.node_tree.links.new(out,bs.inputs['Emission Color'])
        bs.inputs['Emission Strength'].default_value=emission
    return m

IVORY=mat('Ivory enamel',(.84,.79,.57),ivory_tex,.2,.24)
PLUM=mat('Plum polished alloy',(.28,.018,.075),plum_tex,.55,.22)
GOLD=mat('Machined warm gold',(.72,.4,.085),gold_tex,.78,.27)
IRON=mat('Dark plum gunmetal',(.04,.03,.045),plum_tex,.72,.32,tint=.17)
CRYSTAL=mat('Rose cut crystal',(.66,.012,.24),rose_tex,.28,.19,.32)
FACET=mat('Deep rose crystal facets',(.5,.01,.15),rose_tex,.38,.22,.12,tint=.61)
LIGHT=mat('Rose tether light',(.66,.012,.24),rose_tex,.18,.2,1.45)
AMBER=mat('Gold cap light',(.72,.4,.085),gold_tex,.58,.24,.3)

def empty(name, position=(0,0,0), parent=None):
    ob=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(ob)
    ob.location=position; ob.parent=parent
    return ob

ROOT=empty('Body')
CAGE=empty('Cage',(0,0,.49),ROOT)

def uv(obj):
    layer=obj.data.uv_layers.active or obj.data.uv_layers.new(name='UVMap')
    for f in obj.data.polygons:
        axis=max(range(3),key=lambda k:abs(f.normal[k]))
        for li in f.loop_indices:
            v=obj.data.vertices[obj.data.loops[li].vertex_index].co
            a,b = (v.y,v.z) if axis==0 else ((v.x,v.z) if axis==1 else (v.x,v.y))
            layer.data[li].uv = (a/.30+.5,b/.30+.5)

def finish(obj,name,material,parent=ROOT,bev=0,smooth=True):
    obj.name=name; obj.data.materials.append(material)
    if bev:
        mod=obj.modifiers.new('Polished edge','BEVEL'); mod.width=bev; mod.segments=2
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if smooth:
        for f in obj.data.polygons: f.use_smooth=True
        bm=bmesh.new(); bm.from_mesh(obj.data)
        for e in bm.edges:
            if len(e.link_faces)==2 and e.calc_face_angle(0) > .65: e.smooth=False
        bm.to_mesh(obj.data); bm.free()
    uv(obj)
    world=obj.matrix_world.copy(); obj.parent=parent
    bpy.context.view_layer.update(); obj.matrix_world=world
    return obj

def cyl(name,z,r,depth,material,parent=ROOT,r2=None,loc=None,vertices=24,bev=.005):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=loc or (0,0,z))
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=r2,depth=depth,location=loc or (0,0,z))
    return finish(bpy.context.object,name,material,parent,bev)

def torus(name,z,r,t,material,parent=ROOT,loc=None,rot=None):
    bpy.ops.mesh.primitive_torus_add(major_segments=32,minor_segments=8,major_radius=r,minor_radius=t,location=loc or (0,0,z),rotation=rot or (0,0,0))
    return finish(bpy.context.object,name,material,parent)

def rod(name,a,b,r,material,parent=ROOT):
    a,b=Vector(a),Vector(b)
    o=cyl(name,0,r,(b-a).length,material,parent,loc=(a+b)/2,vertices=12,bev=.002)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return o

def ball(name,loc,r,material,parent=ROOT):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=r,location=loc)
    return finish(bpy.context.object,name,material,parent)

def mesh(name,verts,faces,material,parent=ROOT,bev=0,smooth=False):
    me=bpy.data.meshes.new(name+'Geometry'); me.from_pydata(verts,[],faces); me.update()
    bm=bmesh.new(); bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free()
    o=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(o)
    return finish(o,name,material,parent,bev,smooth)

# Ground-deployed three-toed base. Each radial toe has a plum chassis and inset ivory shoe.
for i,theta in enumerate([0,TAU/3,2*TAU/3]):
    def pt(rad,wide,z):
        return (math.sin(theta)*rad+math.cos(theta)*wide, math.cos(theta)*rad-math.sin(theta)*wide,z)
    outline=[(.105,-.086),(.245,-.092),(.352,-.044),(.352,.044),(.245,.092),(.105,.086)]
    vs=[pt(r,w,z) for z in (.008,.072) for r,w in outline]
    fs=[tuple(range(5,-1,-1)),tuple(range(6,12))]+[(j,(j+1)%6,(j+1)%6+6,j+6) for j in range(6)]
    mesh('Toe chassis '+str(i),vs,fs,PLUM,bev=.012,smooth=True)
    outline2=[(.155,-.057),(.253,-.064),(.325,-.032),(.325,.032),(.253,.064),(.155,.057)]
    vs=[pt(r,w,z) for z in (.069,.094) for r,w in outline2]
    mesh('Ivory toe shield '+str(i),vs,fs,IVORY,bev=.009,smooth=True)
    rod('Toe gold spine '+str(i),pt(.15,0,.096),pt(.295,0,.096),.005,GOLD)
    for side in (-1,1):
        ball('Toe rivet',pt(.214,side*.059,.099),.008,GOLD)

cyl('Low dark foundation',.074,.174,.082,IRON,bev=.010)
cyl('Ivory base crown',.136,.176,.052,IVORY,r2=.157,bev=.012)
torus('Base gold reveal',.162,.148,.008,GOLD)
cyl('Plum tapered pedestal',.192,.144,.070,PLUM,r2=.117,bev=.008)
cyl('Gold cage floor',.244,.148,.030,GOLD,bev=.007)
cyl('Black crystal cradle',.265,.117,.023,IRON,bev=.004)
torus('Rose power ring',.265,.115,.005,LIGHT)

# Circular cable socket faces +Y; concentric inset rings and recessed keyed centre.
socket=cyl('Front cable socket chassis',0,.077,.038,PLUM,loc=(0,.151,.152),vertices=24,bev=.006)
socket.rotation_euler=(math.pi/2,0,0)
torus('Cable socket gold ring',0,.059,.011,GOLD,loc=(0,.177,.152),rot=(math.pi/2,0,0))
socket=cyl('Cable socket recessed dark well',0,.046,.010,IRON,loc=(0,.179,.152),vertices=24,bev=.002)
socket.rotation_euler=(math.pi/2,0,0)
torus('Cable socket interior rose halo',0,.028,.005,LIGHT,loc=(0,.187,.152),rot=(math.pi/2,0,0))
socket=cyl('Cable socket solid centre',0,.020,.008,IRON,loc=(0,.188,.152),vertices=16,bev=.003)
socket.rotation_euler=(math.pi/2,0,0)
for ang in [math.pi*.25,math.pi*.75,math.pi*1.25,math.pi*1.75]:
    ball('Socket securing stud',(math.cos(ang)*.068,.175,.152+math.sin(ang)*.068),.006,GOLD)

# Open tapered rigid cage leaves the jewel visible from every angle.
for i in range(6):
    theta = TAU*i/6 + TAU/12
    a=(math.sin(theta)*.145,math.cos(theta)*.145,.26)
    b=(math.sin(theta)*.089,math.cos(theta)*.089,.719)
    rod('Plum cage stanchion '+str(i),a,b,.012,PLUM,CAGE)
    inset=lambda r,z:(math.sin(theta)*r,math.cos(theta)*r,z)
    rod('Gold cage trim '+str(i),inset(.148,.277),inset(.093,.704),.0045,GOLD,CAGE)
    ball('Stanchion gold foot stud',a,.015,GOLD,CAGE)

# Faceted elongated magenta crystal; per-face value variation preserves real cut surfaces.
levels=[(.291,.025),(.354,.088),(.543,.102),(.656,.059),(.711,0)]
verts=[]
for z,r in levels:
    for i in range(8):
        theta=TAU*i/8+math.pi/8
        verts.append((math.sin(theta)*r,math.cos(theta)*r,z))
faces=[tuple(range(7,-1,-1))]
for level in range(4):
    for i in range(8):
        j=(i+1)%8
        faces.append((level*8+i,level*8+j,(level+1)*8+j,(level+1)*8+i))
o=mesh('Central cut tether crystal',verts,faces,CRYSTAL,CAGE)
o.data.materials.append(FACET)
for poly in o.data.polygons: poly.material_index = 1 if poly.index%5 in (1,2) else 0
# Gold petal cradle beneath the gem and a clean open upper collar.
cyl('Crystal bottom collet',.303,.052,.040,GOLD,CAGE,r2=.034,bev=.004,vertices=16)
torus('Top cage collar',.713,.091,.012,GOLD,CAGE)
cyl('Ivory cap shoulders',.737,.107,.033,IVORY,CAGE,r2=.088,bev=.007)
cyl('Gold crown dome',.769,.092,.040,GOLD,CAGE,r2=.057,bev=.005)
cyl('Plum top finial neck',.795,.035,.025,PLUM,CAGE,bev=.004)
# Small faceted amber finial gives the pylon a strong crown without humanoid features.
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.035,location=(0,0,.829))
finish(bpy.context.object,'Amber anchor finial',AMBER,CAGE,smooth=False)
for theta in [TAU*i/6 for i in range(6)]:
    ball('Cap gold rivet',(math.sin(theta)*.101,math.cos(theta)*.101,.736),.007,GOLD,CAGE)

# Merge only rigid pieces that share a material and a pivot; preserve crystal facet materials.
for parent in (ROOT,CAGE):
    for material in (IVORY,PLUM,GOLD,IRON,LIGHT,AMBER):
        parts=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.parent==parent and len(o.data.materials)==1 and o.data.materials[0]==material]
        if len(parts)>1:
            bpy.ops.object.select_all(action='DESELECT')
            for p in parts:p.select_set(True)
            bpy.context.view_layer.objects.active=parts[0]; bpy.ops.object.join()
            parts[0].name=parent.name+' '+material.name+' assembly'

# NLA clips: only Cage rotates/scales. Body/root and base stay completely stationary.
scene=bpy.context.scene; scene.render.fps=30; scene.frame_set(1)
rest=CAGE.rotation_euler.copy()
for name,end,amplitude in [('Idle',90,.030),('Walk',60,.050),('Swim',120,.045),('Attack',24,.32)]:
    CAGE.animation_data_create(); CAGE.animation_data.action=None
    for frame in range(1,end+1,3):
        t=(frame-1)/(end-1)
        phase=math.sin(TAU*t)
        if name=='Attack':
            phase=math.sin(math.pi*t)**2
            rx=.028*math.sin(TAU*t); rz=amplitude*phase
            scale=1+.04*phase
        else:
            rx=.012*phase if name in ('Walk','Swim') else 0
            rz=amplitude*phase; scale=1
        CAGE.rotation_euler=(rx,0,rz); CAGE.scale=(scale,scale,scale)
        CAGE.keyframe_insert(data_path='rotation_euler',frame=frame,group='Cage')
        CAGE.keyframe_insert(data_path='scale',frame=frame,group='Cage')
    CAGE.rotation_euler=rest; CAGE.scale=(1,1,1)
    CAGE.keyframe_insert(data_path='rotation_euler',frame=end,group='Cage')
    CAGE.keyframe_insert(data_path='scale',frame=end,group='Cage')
    action=CAGE.animation_data.action; action.name=name
    track=CAGE.animation_data.nla_tracks.new(); track.name=name
    strip=track.strips.new(name,1,action); strip.name=name
    CAGE.animation_data.action=None; track.mute=True

scene.frame_set(1); CAGE.rotation_euler=rest; CAGE.scale=(1,1,1)
# Track mutes are preview-only. Export evaluates each track independently.
for track in CAGE.animation_data.nla_tracks: track.mute=False
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'eco_anchor.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'eco_anchor.glb'),export_format='GLB',export_yup=True,
    export_animations=True,export_animation_mode='NLA_TRACKS',export_cameras=False,export_lights=False,
    export_force_sampling=True,export_frame_range=False,export_nla_strips=True)
print('ANCHOR_EXPORTED',OUT/'eco_anchor.glb')
