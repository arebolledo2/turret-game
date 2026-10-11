"""Clockwork bow: authored geometry, rigid aiming hierarchy, reproducible GLB."""
import bpy, bmesh, math
from mathutils import Vector
from pathlib import Path

bpy.ops.wm.read_factory_settings(use_empty=True)
OUT = Path(__file__).resolve().parent

def material(name, color, metal=0, rough=.3):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    s=m.node_tree.nodes.get('Principled BSDF'); s.inputs['Base Color'].default_value=(*color,1)
    s.inputs['Metallic'].default_value=metal; s.inputs['Roughness'].default_value=rough
    return m
teal=material('Enamel turquoise',(.006,.36,.31),.15,.36)
teal_dark=material('Deep teal facets',(.018,.28,.29),.25,.32)
coral=material('Coral spring limbs',(.84,.095,.047),.08,.35)
coral_edge=material('Coral pale edge', (1,.24,.105),.10,.32)
gold=material('Warm brass',(.83,.48,.055),.75,.24)
gold_light=material('Polished brass edges',(1,.73,.17),.68,.22)
dark=material('Black plum iron',(.085,.055,.105),.45,.31)
ivory=material('Ivory arrow fins',(.94,.85,.58),.10,.29)
purple=material('Amethyst details',(.28,.035,.68),.5,.16)

groups={}
def finish(o,name,mat,group,bevel=0):
    o.name=name; o.data.materials.append(mat)
    if bevel:
        mod=o.modifiers.new('Edge softness','BEVEL'); mod.width=bevel; mod.segments=1 if bevel<.01 else 2
        bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=mod.name)
    # Smooth shallow changes, leave visibly angular machined edges crisp.
    bm=bmesh.new(); bm.from_mesh(o.data)
    for f in bm.faces:f.smooth=True
    for e in bm.edges:
        if len(e.link_faces)==2 and e.calc_face_angle(0)>math.radians(38):e.smooth=False
    bm.to_mesh(o.data); bm.free(); groups.setdefault(group,[]).append(o); return o
def box(name,pos,size,mat,group,bevel=.012):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos); o=bpy.context.object; o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,mat,group,bevel)
def cyl(name,pos,radius,depth,mat,group,axis='Z',vertices=24,bevel=.008):
    bpy.ops.mesh.primitive_cylinder_add(vertices=min(vertices,24),radius=radius,depth=depth,location=pos)
    o=bpy.context.object
    if axis=='X':o.rotation_euler[1]=math.pi/2
    if axis=='Y':o.rotation_euler[0]=math.pi/2
    return finish(o,name,mat,group,min(bevel,depth*.23,radius*.2))
def ball(name,pos,radius,mat,group,scale=(1,1,1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=radius,location=pos)
    o=bpy.context.object; o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,mat,group)
def mesh(name,verts,faces,mat,group,bevel=0):
    d=bpy.data.meshes.new(name); d.from_pydata(verts,[],faces); d.update()
    o=bpy.data.objects.new(name,d); bpy.context.collection.objects.link(o)
    return finish(o,name,mat,group,bevel)
def line(name,a,b,r,mat,group,vertices=10):
    a,b=Vector(a),Vector(b); o=cyl(name,(a+b)/2,r,(b-a).length,mat,group,vertices=vertices,bevel=0)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler(); return o
def empty(name,pos,parent=None):
    o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o); o.location=pos
    if parent:o.parent=parent
    return o

# Broad, layered octagonal base, beveled gold rim and turquoise sloped shoulder.
cyl('Brass foundation',(0,0,.065),.36,.13,gold,'Base',vertices=8,bevel=.009)
cyl('Bright foundation lip',(0,0,.132),.354,.019,gold_light,'Base',vertices=8,bevel=.003)
bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=.338,radius2=.247,depth=.10,location=(0,0,.193))
finish(bpy.context.object,'Turquoise sloped plinth',teal,'Base',.006)
cyl('Column foot',(0,0,.262),.157,.048,gold,'Base',vertices=8)
cyl('Foot upper lip',(0,0,.284),.15,.013,gold_light,'Base',vertices=8,bevel=.003)
cyl('Turquoise octagonal column',(0,0,.47),.112,.372,teal,'Support',vertices=8)
for i in range(4):
    a=math.pi/4+i*math.pi/2; x,y=.289*math.cos(a),.289*math.sin(a)
    cyl('Base bolt',(x,y,.217),.028,.024,gold_light,'BaseHardware',vertices=12,bevel=.005)
for s in [-1,1]:
    ball('Plinth jewel',(s*.337,0,.074),.024,purple,'BaseHardware',(.3,1,1))

aim=empty('Aim',(0,0,.71))
# Main receiver is a split enclosure: a genuine forward inset rather than a painted cube.
box('Receiver rear shell',(0,-.10,.913),(.38,.20,.37),teal,'Receiver',.026)
box('Receiver roof',(0,.055,1.112),(.36,.31,.088),teal,'Receiver',.021)
box('Receiver lower shell',(0,.055,.737),(.36,.31,.08),teal,'Receiver',.020)
for s in [-1,1]:
    box('Receiver cheek',(s*.172,.04,.93),(.068,.33,.34),teal,'Receiver',.018)
box('Dark recessed interior',(0,.115,.925),(.25,.045,.31),dark,'InnerMechanism',.024)
# Faceted brass frame, extruded octagon annulus in the XZ plane.
outer=[(-.155,.194),(.155,.194),(.215,.13),(.215,-.13),(.155,-.194),(-.155,-.194),(-.215,-.13),(-.215,.13)]
inner=[(x*.76,z*.80) for x,z in outer]
verts=[]
for y in [.19,.245]:
    for ring in [outer,inner]:verts += [(x,y,.93+z) for x,z in ring]
faces=[]
for i in range(8):
    j=(i+1)%8
    faces += [(i,j,8+j,8+i),(16+i,24+i,24+j,16+j),(i,16+i,16+j,j),(8+i,8+j,24+j,24+i)]
mesh('Octagonal receiver rim',verts,faces,gold_light,'Frame',.006)
for x in [-.19,.19]:
    for z in [.78,1.08]:ball('Rim rivet',(x,.257,z),.021,gold,'Frame',(1,.5,1))
# Internal angled bow clutch visible around the shaft.
o=box('Clutch diagonal plate',(0,.15,.92),(.08,.047,.27),dark,'InnerMechanism',.008);o.rotation_euler[1]=-.25
for x,z in [(-.087,1.04),(.071,.946),(-.061,.817)]:
    ball('Clutch amethyst',(x,.168,z),.025,purple,'InnerMechanism',(1,.43,1))
# Large round side inspection medallions and a lower purple winding indicator.
for s in [-1,1]:
    cyl('Side brass bezel',(s*.222,.01,.932),.091,.035,gold,'SideMedallions','X',32)
    cyl('Ivory medallion',(s*.245,.01,.932),.065,.012,ivory,'SideMedallions','X',32,.004)
    cyl('Lower jewel bezel',(s*.183,.071,.714),.054,.035,gold,'SideMedallions','X',24)
    ball('Purple lower lens',(s*.21,.071,.714),.044,purple,'SideMedallions',(.30,1,1))
    for y,z in [(-.086,1.06),(-.086,.804)]:ball('Cheek bolt',(s*.207,y,z),.019,gold_light,'SideMedallions')

# Upright recurved spring bow. Smooth thick ribbons taper gently toward rolled brass tips.
def bezier(p0,p1,p2,p3,n=22):
    return [tuple((1-t)**3*p0[j]+3*(1-t)**2*t*p1[j]+3*(1-t)*t*t*p2[j]+t**3*p3[j] for j in range(2)) for t in [i/n for i in range(n+1)]]
def ribbon(name,pts):
    vv=[]
    for i,(y,z) in enumerate(pts):
        a=Vector(pts[max(0,i-1)]); b=Vector(pts[min(len(pts)-1,i+1)])
        dy,dz=(b-a).normalized(); w=.043*(1-.18*i/(len(pts)-1))
        for x,sgn in [(-.052,-1),(.052,-1),(.052,1),(-.052,1)]:vv.append((x,y-dz*w*sgn,z+dy*w*sgn))
    ff=[(3,2,1,0)]
    for i in range(len(pts)-1):
        for k in range(4):ff.append((4*i+k,4*i+(k+1)%4,4*(i+1)+(k+1)%4,4*(i+1)+k))
    q=4*(len(pts)-1);ff.append((q,q+1,q+2,q+3))
    o=mesh(name,vv,ff,coral,'BowLimbs',.009)
    o.data.materials.append(coral_edge)
    for p in o.data.polygons:
        if p.normal.x<-.6:p.material_index=1
upper=bezier((.59,1.015),(.57,1.31),(.19,1.43),(.20,1.581))
lower=bezier((.59,.844),(.57,.48),(.16,.39),(.20,.22))
ribbon('Upper coral limb',upper); ribbon('Lower coral limb',lower)
box('Upper coral bow grip',(0,.59,.985),(.103,.09,.058),coral,'BowLimbs',.010)
box('Lower coral bow grip',(0,.59,.88),(.103,.09,.060),coral,'BowLimbs',.010)
for z in [1.005,.854]:box('Turquoise grip binding',(0,.585,z),(.121,.102,.086),teal,'BowClamps',.010)
for s in [-1,1]:
    for y,z in [(.59,1.07),(.58,.775)]:ball('Limb teal peg',(s*.059,y,z),.018,teal,'BowHardware',(.40,1,1))
    ball('Limb brass pin',(s*.059,.418,1.363),.016,gold_light,'BowHardware',(.40,1,1))
for z in [1.581,.22]:
    cyl('Rolled brass limb tip',(0,.20,z),.050,.136,gold,'BowHardware','X',24,.007)
    for s in [-1,1]:cyl('Tip end cap',(s*.075,.20,z),.028,.015,gold_light,'BowHardware','X',20,.003)
# The two taut string segments converge at the rear arrow nock. Endpoints touch limb caps.
nock=(0,-.10,.93)
line('Upper taut string',(0,.36,1.581),nock,.007,dark,'BowString',10)
line('Lower taut string',(0,.36,.22),nock,.007,dark,'BowString',10)
for g in ['BowLimbs','BowClamps','BowHardware']:
    for o in groups[g]:o.location.y+=.16
# A narrow guide below the projectile physically mounts the bow to the receiver,
# while its open upper slot lets the separate arrow travel clear of the coral grip.
box('Bow mounting rail',(0,.492,.883),(.045,.506,.039),dark,'BowClamps',.006)
box('Rail forward ferrule',(0,.712,.883),(.066,.055,.047),gold,'BowClamps',.006)
# Nocked brass arrow with an ivory pointed blade and corrected fletching at rear.
line('Arrow brass shaft',nock,(0,1.023,.93),.015,gold_light,'LoadedArrow',16)
line('Arrow nock collar',(0,-.112,.93),(0,-.069,.93),.019,dark,'LoadedArrow',12)
v=[(0,1.25,.93),(-.052,1.045,.93),(0,1.045,.978),(.052,1.045,.93),(0,1.045,.882),(0,1.00,.93)]
mesh('Ivory spearhead',v,[(0,1,2),(0,2,3),(0,3,4),(0,4,1),(5,2,1),(5,3,2),(5,4,3),(5,1,4)],ivory,'LoadedArrow',.003)
for a in [0,2*math.pi/3,4*math.pi/3]:
    dx,dz=math.cos(a),math.sin(a)
    v=[(.016*dx,.287,.93+.016*dz),(.082*dx,.295,.93+.082*dz),(.075*dx,.365,.93+.075*dz),(.016*dx,.412,.93+.016*dz)]
    o=mesh('Ivory rear fletching',v,[(0,1,2,3)],ivory,'LoadedArrow')
    mod=o.modifiers.new('Fin thickness','SOLIDIFY');mod.thickness=.006
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
# Winding spool and crank behind the enclosure. Two pronounced brass flanges enclose dark wound cord.
line('Spool axle',(0,-.17,.96),(0,-.56,.96),.031,gold_light,'WindupSpool',20)
box('Rear axle socket',(0,-.239,.96),(.12,.10,.13),dark,'WindupSpool',.016)
cyl('Spool wound cord',(0,-.435,.96),.131,.15,dark,'WindupSpool','Y',32,.003)
for y in [-.355,-.52]:
    cyl('Winding flange',(0,y,.96),.175,.027,gold,'WindupSpool','Y',32,.006)
    cyl('Winding rim',(0,y-.013,.96),.176,.012,gold_light,'WindupSpool','Y',32,.002)
cyl('Spool hub',(0,-.546,.96),.060,.031,gold_light,'WindupSpool','Y',24,.006)
line('Crank extension',(.18,-.12,.824),(.30,-.12,.824),.034,dark,'Crank',16)
box('Crank offset plate',(.295,-.12,.768),(.03,.044,.16),dark,'Crank',.009)
cyl('Crank brass knob',(.295,-.06,.703),.045,.106,gold,'Crank','Y',20,.007)

# Merge coherent rigid pieces while preserving independently removable projectile/string/spool.
static={'Base','BaseHardware','Support'}
for group,objects in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=bpy.context.object;o.name=group
    if group not in static:
        world=o.matrix_world.copy();o.parent=aim;o.matrix_world=world
muzzle=empty('Muzzle',(0,1.25,.93-.71),aim)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_bow.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_bow.glb'),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
