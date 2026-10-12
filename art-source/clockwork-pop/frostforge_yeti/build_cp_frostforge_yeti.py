"""Frostforge Yeti: sculpted rigid mechanical guardian, procedural PBR atlas."""
import bpy, bmesh, math, json
from pathlib import Path
import numpy as np
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
OUT = Path(__file__).parent
OUT.mkdir(parents=True, exist_ok=True)
TAU = math.tau

# Eight surface families share four embedded maps. Clean fired ceramic,
# clouded glacier enamel and brushed metal; no dirt or arbitrary distress.
N = 1024
yy, xx = np.mgrid[0:N, 0:N]
albedo = np.ones((N,N,4), np.float32)
orm = np.ones_like(albedo)
normal = np.ones_like(albedo)
emissive = np.zeros_like(albedo); emissive[:,:,3] = 1
colors = [(0.88,.885,.80),(.22,.70,.80),(.075,.095,.135),(.36,.46,.55),(.71,.49,.21),(.025,.83,.94),(.055,.23,.29),(.94,.94,.86)]
metallic = [.12,.30,.82,.87,.80,.12,.62,.05]
rough = [.30,.23,.31,.25,.30,.21,.32,.32]
for tile in range(8):
    col,row = tile%4,tile//4
    x0,y0 = col*256,row*512
    u,v = np.mgrid[0:512,0:256]; u=u/512.;v=v/256.
    grain = .004*np.sin(v*690+np.sin(u*53)*.3)
    cloud = np.sin(v*13+np.sin(u*10))*.012 + np.sin(v*27-u*19)*.009
    if tile == 1: cloud *= 2.2
    if tile in (2,3,4,6): cloud *= .20
    val = np.clip(1+cloud+grain, .90,1.07)
    sl = np.s_[y0:y0+512,x0:x0+256]
    albedo[sl][:,:,:3] = np.clip(np.array(colors[tile])[None,None,:]*val[:,:,None],0,1)
    orm[sl][:,:,0]=1
    orm[sl][:,:,1]=np.clip(rough[tile]+cloud*.45+grain,.03,.9)
    orm[sl][:,:,2]=metallic[tile]
    normal[sl][:,:,0]=.5 + .005*np.sin(v*310+u*17)
    normal[sl][:,:,1]=.5 + .006*np.cos(u*240+v*13)
    normal[sl][:,:,2]=1
    if tile == 5: emissive[sl][:,:,:3] = (.012,.61,.79)

def image_map(name, pixels, noncolor=False):
    im = bpy.data.images.new(name,width=N,height=N,alpha=True)
    if noncolor: im.colorspace_settings.name='Non-Color'
    im.pixels.foreach_set(pixels.ravel())
    im.filepath_raw=str(OUT/(name+'.png'));im.file_format='PNG';im.save();im.pack()
    return im
IMG_COLOR=image_map('frostforge_albedo',albedo)
IMG_ORM=image_map('frostforge_orm',orm,True)
IMG_NORMAL=image_map('frostforge_normal',normal,True)
IMG_EMISSION=image_map('frostforge_emission',emissive)

MATS=[]
for i,name in enumerate(['Porcelain armor','Glacier enamel','Obsidian hydraulics','Brushed titanium','Champagne brass','Cyan reactor glass','Deep teal housings','Ivory carved beard']):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*colors[i],1)
    ns,lk=m.node_tree.nodes,m.node_tree.links;p=ns.get('Principled BSDF')
    t=ns.new('ShaderNodeTexImage');t.image=IMG_COLOR;lk.new(t.outputs['Color'],p.inputs['Base Color'])
    t=ns.new('ShaderNodeTexImage');t.image=IMG_ORM
    s=ns.new('ShaderNodeSeparateColor');lk.new(t.outputs['Color'],s.inputs[0]);lk.new(s.outputs['Green'],p.inputs['Roughness']);lk.new(s.outputs['Blue'],p.inputs['Metallic'])
    t=ns.new('ShaderNodeTexImage');t.image=IMG_NORMAL
    bump=ns.new('ShaderNodeNormalMap');bump.inputs['Strength'].default_value=.22;lk.new(t.outputs['Color'],bump.inputs['Color']);lk.new(bump.outputs['Normal'],p.inputs['Normal'])
    p.inputs['Coat Weight'].default_value=.24 if i in (0,1,7) else .05
    p.inputs['Coat Roughness'].default_value=.24
    if i==5:
        t=ns.new('ShaderNodeTexImage');t.image=IMG_EMISSION;lk.new(t.outputs['Color'],p.inputs['Emission Color']);p.inputs['Emission Strength'].default_value=.55
    MATS.append(m)

def empty(name,pos,parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o)
    o.location=pos
    if parent:
        o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted()
    bpy.context.view_layer.update()
    return o

ROOT=empty('Frostforge_Yeti',(0,0,0))
BODY=empty('Body',(0,0,1.04),ROOT)
HEAD=empty('Head',(0,.02,1.76),BODY)
ARM={s:empty('Arm_'+s,(sgn*.65,0,1.56),BODY) for s,sgn in [('L',1),('R',-1)]}
ELBOW={s:empty('Elbow_'+s,(sgn*.73,.015,1.08),ARM[s]) for s,sgn in [('L',1),('R',-1)]}
HAND={s:empty('Hand_'+s,(sgn*.79,.11,.61),ELBOW[s]) for s,sgn in [('L',1),('R',-1)]}
LEG={s:empty('Leg_'+s,(sgn*.28,0,.84),ROOT) for s,sgn in [('L',1),('R',-1)]}
SHIN={s:empty('Shin_'+s,(sgn*.29,0,.43),LEG[s]) for s,sgn in [('L',1),('R',-1)]}
ALL_PARTS={}

def finish(o,name,tile,parent,smooth=True):
    o.name=name;o.data.materials.append(MATS[tile])
    if smooth:
        for f in o.data.polygons:f.use_smooth=True
    # UV projection shares about 2k texels/metre across all exterior parts.
    mesh=o.data;uv=mesh.uv_layers.active or mesh.uv_layers.new(name='UVMap');uv.name='UVMap'
    verts=[v.co for v in mesh.vertices]
    lo=[min(v[j] for v in verts) for j in range(3)]
    hi=[max(v[j] for v in verts) for j in range(3)]
    for p in mesh.polygons:
        axis=max(range(3),key=lambda j:abs(p.normal[j]))
        ij=((1,2),(0,2),(0,1))[axis]
        # Normalize part projections but keep an ample atlas border.
        for li in p.loop_indices:
            co=mesh.vertices[mesh.loops[li].vertex_index].co
            a=(co[ij[0]]-lo[ij[0]])/max(hi[ij[0]]-lo[ij[0]],.001)
            b=(co[ij[1]]-lo[ij[1]])/max(hi[ij[1]]-lo[ij[1]],.001)
            uv.data[li].uv=((tile%4+.035+.93*a)/4,(tile//4+.025+.95*b)/2)
    o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted()
    ALL_PARTS.setdefault(parent.name,[]).append(o)
    return o

def bevel(o,width=.03,segments=3):
    m=o.modifiers.new('Rounded ceramic edges','BEVEL');m.width=width;m.segments=segments
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=m.name)
    return o

def sphere(name,pos,size,tile,parent,seg=18,rings=10):
    if max(size)<.085:seg=min(seg,14);rings=min(rings,8)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,radius=1,location=pos)
    o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,tile,parent)

def box(name,pos,size,tile,parent,radius=.03,rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos)
    o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if rot:o.rotation_euler=rot
    bevel(o,min(radius,min(size)*.35),2)
    finish(o,name,tile,parent)
    # Angle weighted normals retain the flat manufactured plates.
    mod=o.modifiers.new('Panel normals','WEIGHTED_NORMAL');mod.keep_sharp=True
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    return o

def cylinder(name,pos,radius,depth,tile,parent,axis=(0,0,1),vertices=20):
    if radius<.075:vertices=min(vertices,16)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=pos)
    o=bpy.context.object;o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
    bevel(o,min(radius*.16,depth*.15,.012),1 if radius<.075 else 2)
    return finish(o,name,tile,parent)

def rod(name,a,b,radius,tile,parent):
    return cylinder(name,(Vector(a)+Vector(b))/2,radius,(Vector(b)-Vector(a)).length,tile,parent,Vector(b)-Vector(a),16)

def torus(name,pos,major,minor,tile,parent,axis=(0,0,1),scale=None):
    bpy.ops.mesh.primitive_torus_add(major_segments=20,minor_segments=6,location=pos,major_radius=major,minor_radius=minor)
    o=bpy.context.object;o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
    if scale:
        o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,tile,parent)

def mesh_obj(name,verts,faces,tile,parent):
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o)
    # Ensure outward winding on closed custom plates and blades.
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
    return finish(o,name,tile,parent)

def plate(name,coords,y,depth,tile,parent,bulge=.035):
    # Sculpted, slightly convex armour panel: polygon coordinates are X/Z.
    n=len(coords);cx=sum(a for a,b in coords)/n;cz=sum(b for a,b in coords)/n
    verts=[(x,y,z) for x,z in coords]+[(x,y-depth,z) for x,z in coords]+[(cx,y+bulge,cz)]
    faces=[]
    for i in range(n):
        j=(i+1)%n;faces.append((i,j,2*n));faces.append((i,n+i,n+j,j))
    faces.append(tuple(range(2*n-1,n-1,-1)))
    o=mesh_obj(name,verts,faces,tile,parent);bevel(o,min(.028,depth*.35),2)
    return o

def chest_panel(name,coords,parent):
    # Armour follows the torso's ellipsoidal surface rather than separate
    # inflated fan plates. Three concentric outline rings make a curved shell.
    n=len(coords);cx=sum(x for x,z in coords)/n;cz=sum(z for x,z in coords)/n
    def front(x,z):return -.025+.33*math.sqrt(max(.02,1-(x/.61)**2-((z-1.35)/.425)**2))+.018
    verts=[(cx,front(cx,cz),cz)]
    for frac in [.50,1]:
        for x,z in coords:
            px=cx+(x-cx)*frac;pz=cz+(z-cz)*frac
            verts.append((px,front(px,pz),pz))
    for x,z in coords:verts.append((x,front(x,z)-.025,z))
    faces=[]
    for j in range(n):
        k=(j+1)%n
        faces.extend([(0,1+j,1+k),(1+j,1+n+j,1+n+k,1+k),(1+n+j,1+2*n+j,1+2*n+k,1+n+k)])
    faces.append(tuple(reversed(range(1+2*n,1+3*n))))
    return mesh_obj(name,verts,faces,1,parent)

def leaf(name,points,width,thick,tile,parent,rings=7):
    # Bézier ceramic fur blade: oval cross section and long sculpted taper.
    a,b,c=map(Vector,points);vs=[];faces=[];sides=8
    for r in range(rings+1):
        t=r/rings;cen=(1-t)**2*a+2*t*(1-t)*b+t*t*c
        direction=(2*(1-t)*(b-a)+2*t*(c-b)).normalized()
        right=Vector((1,0,0));side=direction.cross(right).normalized()
        fullness=(.58+math.sin(t*math.pi)*.42)*(1-t)**.60+.007
        for j in range(sides):
            ang=TAU*j/sides
            vs.append(cen+right*math.cos(ang)*width*fullness+side*math.sin(ang)*thick*fullness)
    for r in range(rings):
        for j in range(sides):faces.append((r*sides+j,r*sides+(j+1)%sides,(r+1)*sides+(j+1)%sides,(r+1)*sides+j))
    faces.extend([tuple(reversed(range(sides))),tuple(range(rings*sides,(rings+1)*sides))])
    return mesh_obj(name,vs,faces,tile,parent)

def dome(name,center,scale,tile,parent,start=0,end=1.86):
    vs=[];faces=[];nr=10;ns=28
    for r in range(nr+1):
        p=start+(end-start)*r/nr
        for j in range(ns):
            a=j*TAU/ns
            vs.append((center[0]+scale[0]*math.sin(p)*math.cos(a),center[1]+scale[1]*math.sin(p)*math.sin(a),center[2]+scale[2]*math.cos(p)))
    for r in range(nr):
        for j in range(ns):faces.append((r*ns+j,r*ns+(j+1)%ns,(r+1)*ns+(j+1)%ns,(r+1)*ns+j))
    # underside is closed so imported backfaces cannot disappear.
    faces.append(tuple(reversed(range(nr*ns,(nr+1)*ns))))
    return mesh_obj(name,vs,faces,tile,parent)

# Central tapered chassis is a broad chest, short mechanical waist and pelvis.
sphere('Ceramic barrel torso',(0,-.025,1.35),(.61,.33,.425),0,BODY,28,16)
sphere('Upper mantle',(0,-.095,1.62),(.43,.30,.205),0,BODY,24,12)
sphere('Dark collar recess',(0,.22,1.72),(.335,.10,.235),2,BODY,24,14)
torus('Collar ivory hoop',(0,.276,1.71),.303,.041,0,BODY,(0,1,0),scale=(1.12,.82,1.0))
# Lower rib-cage intentionally dark and narrow below the ivory shoulders.
sphere('Abdominal hydraulic core',(0,-.04,1.03),(.30,.25,.285),2,BODY)
for z,w in [(1.14,.48),(1.04,.43),(.94,.37)]:
    plate('Faceted belly rib', [(-w/2,z+.045),(w/2,z+.045),(w*.48,z-.018),(w*.33,z-.065),(-w*.33,z-.065),(-w*.48,z-.018)],.22,.042,2,BODY,.014)
    box('Belly titanium seam',(0,.26,z-.044),(w*.58,.013,.016),3,BODY,.006)
sphere('Pelvis protective shell',(0,-.03,.835),(.33,.245,.145),0,BODY)
torus('Waist porcelain seal',(0,-.01,.866),.255,.038,0,BODY,scale=(1.15,.9,1))
plate('Central groin ivory', [(-.14,.91),(.14,.91),(.126,.68),(.085,.62),(-.085,.62),(-.126,.68)],.258,.075,0,BODY,.035)
plate('Central glacier groin', [(-.095,.864),(.095,.864),(.075,.697),(-.075,.697)],.304,.026,1,BODY,.023)

# The two cloudy-blue breast plates wrap the sternum; cream reveals articulate
# the broad design and preserve the readable ivory/blue material boundary.
for s,sgn in [('L',1),('R',-1)]:
    pts=[(.065,1.53),(.25,1.565),(.465,1.49),(.546,1.36),(.466,1.195),(.30,1.12),(.135,1.205),(.08,1.35)]
    chest_panel('Glacier breast '+s,[(sgn*x,z) for x,z in pts],BODY)
    plate('Lower flank blue '+s,[(sgn*x,z) for x,z in [( .36,1.265),(.44,1.29),(.477,1.16),(.35,1.065),(.26,1.10)]],.19,.046,1,BODY,.015)
    for x,z in [(.245,1.49),(.405,1.41),(.385,1.18)]:
        cylinder('Chest brass fastener',(sgn*x,.317,z),.014,.009,4,BODY,(0,1,0),12)
    # Shoulder drum, ring and shell are huge relative to the face.
    sphere('Shoulder dark ball '+s,(sgn*.57,-.015,1.51),(.23,.255,.24),2,ARM[s])
    torus('Shoulder hydraulic seal '+s,(sgn*.51,.015,1.51),.205,.042,3,ARM[s],(1,0,0))
    torus('Shoulder teal inner ring '+s,(sgn*.486,.015,1.51),.178,.018,6,ARM[s],(1,0,0))
    dome('Ivory shoulder shell '+s,(sgn*.68,-.015,1.52),(.347,.32,.345),0,ARM[s],1.62,1.86)
    dome('Glacier domed shoulder '+s,(sgn*.68,.002,1.533),(.32,.307,.333),1,ARM[s],0,1.73)
    torus('Shoulder ceramic skirt '+s,(sgn*.68,-.015,1.432),.316,.028,0,ARM[s],scale=(1.07,1,1))
    # Gilded shoulder status lens, angled to follow the front shell.
    pos=(sgn*.805,.257,1.70);axis=(sgn*.28,.9,.36)
    cylinder('Shoulder lens housing '+s,pos,.077,.04,4,ARM[s],axis)
    sphere('Shoulder cyan lens '+s,(sgn*.814,.276,1.708),(.060,.025,.062),5,ARM[s])
    cylinder('Shoulder front screw '+s,(sgn*.879,.23,1.474),.022,.017,2,ARM[s],(0,1,0),16)
    cylinder('Shoulder screw slot '+s,(sgn*.879,.242,1.474),.010,.009,3,ARM[s],(0,1,0),12)
    # Back-mounted insulated steam stacks rise behind each shoulder.
    a=(sgn*.83,-.125,1.75);b=(sgn*.89,-.16,1.97)
    rod('Rear exhaust barrel '+s,a,b,.046,3,ARM[s])
    rod('Exhaust brass band '+s,(sgn*.868,-.146,1.91),(sgn*.874,-.148,1.93),.052,4,ARM[s])
    leaf('Icy stack cowl '+s,[(sgn*.884,-.156,1.94),(sgn*.905,-.17,2.045),(sgn*.892,-.18,2.095)],.058,.051,1,ARM[s])
    # Compact ivory upper arm, exposed double piston elbow, huge enamel cuff.
    sphere('Upper arm ivory '+s,(sgn*.695,.007,1.225),(.157,.182,.278),0,ARM[s])
    plate('Upper arm sculpted face '+s,[(sgn*x,z) for x,z in [(.60,1.34),(.77,1.32),(.78,1.16),(.68,1.12),(.615,1.18)]],.166,.035,0,ARM[s],.03)
    cylinder('Elbow spindle '+s,(sgn*.736,.01,1.068),.126,.256,2,ELBOW[s],(1,0,0),24)
    for dx in [-.085,.085]:
        torus('Elbow titanium collar '+s,(sgn*.736+dx,.01,1.068),.106,.019,3,ELBOW[s],(1,0,0))
    sphere('Elbow frontal bearing '+s,(sgn*.732,.116,1.068),(.067,.028,.067),3,ELBOW[s],16,8)
    box('Forearm ivory gauntlet '+s,(sgn*.77,.06,.84),(.385,.365,.417),0,ELBOW[s],.078,rot=(0,sgn*.09,0))
    plate('Forearm glacier shield '+s,[(sgn*x,z) for x,z in [(.617,1.012),(.877,.992),(.931,.704),(.622,.679)]],.25,.035,1,ELBOW[s],.041)
    box('Forearm glacier outer wrap '+s,(sgn*.949,.035,.85),(.018,.197,.276),1,ELBOW[s],.009,rot=(0,sgn*.09,0))
    box('Forearm ivory centre rail '+s,(sgn*.74,.273,.833),(.019,.024,.265),0,ELBOW[s],.007)
    cylinder('Outer wrist reactor ring '+s,(sgn*.945,.115,.977),.095,.038,4,ELBOW[s],(sgn*.65,1,.16))
    sphere('Wrist cyan power jewel '+s,(sgn*.961,.139,.982),(.065,.036,.072),5,ELBOW[s],20,10)
    # Twin bright piston shafts remain visibly recessed in the cuff.
    for dy in [-.09,.09]:
        rod('Wrist piston '+s,(sgn*.77,.02+dy,.55),(sgn*.77,.02+dy,.70),.038,3,ELBOW[s])
        cylinder('Piston upper seal '+s,(sgn*.77,.02+dy,.678),.047,.038,2,ELBOW[s])
    sphere('Palm forged core '+s,(sgn*.79,.075,.545),(.151,.15,.135),2,HAND[s],20,12)
    box('Palm porcelain knuckle plate '+s,(sgn*.79,.201,.572),(.261,.08,.175),0,HAND[s],.045)
    box('Palm glacier face '+s,(sgn*.79,.247,.577),(.207,.033,.119),1,HAND[s],.031)
    # Three curled visible robotic fingers: silver phalanges, dark joints,
    # broad flat knuckles. This is unmistakably a hand rather than a paw.
    for k in [-1,0,1]:
        fx=sgn*.79+k*.083
        rod('Finger first '+s,(fx,.12,.477),(fx,.17,.372),.043,3,HAND[s])
        sphere('Finger black hinge '+s,(fx,.165,.374),(.046,.045,.043),2,HAND[s],12,8)
        rod('Finger curled tip '+s,(fx,.179,.368),(fx,.251,.400),.040,3,HAND[s])
        box('Knuckle inset '+s,(fx,.184,.451),(.051,.014,.066),2,HAND[s],.006,rot=(math.radians(-12),0,0))
    tx=sgn*.625
    rod('Opposed thumb root '+s,(tx,.07,.549),(tx-sgn*.05,.12,.463),.054,3,HAND[s])
    sphere('Thumb hinge '+s,(tx-sgn*.042,.12,.46),(.057,.051,.054),2,HAND[s],12,8)
    rod('Opposed thumb claw '+s,(tx-sgn*.05,.12,.463),(tx-sgn*.014,.222,.415),.043,3,HAND[s])
    # Planted biped legs use short thick thighs and layered knee/shin armour.
    sphere('Hip black joint '+s,(sgn*.282,-.01,.776),(.17,.17,.145),2,LEG[s])
    sphere('Thigh ceramic '+s,(sgn*.30,-.015,.637),(.183,.176,.238),0,LEG[s],24,14)
    plate('Thigh ivory plate '+s,[(sgn*x,z) for x,z in [(.19,.797),(.394,.75),(.425,.529),(.235,.476),(.154,.588)]],.15,.051,0,LEG[s],.027)
    cylinder('Hip gold bearing '+s,(sgn*.447,.027,.769),.070,.028,4,LEG[s],(1,0,0))
    cylinder('Hip blue bearing '+s,(sgn*.462,.027,.769),.050,.034,1,LEG[s],(1,0,0))
    cylinder('Knee side hydraulic '+s,(sgn*.303,0,.451),.105,.305,2,SHIN[s],(1,0,0))
    box('Ivory knee cap '+s,(sgn*.302,.183,.464),(.228,.155,.152),0,SHIN[s],.054)
    box('Knee champagne latch '+s,(sgn*.302,.269,.429),(.155,.017,.035),4,SHIN[s],.009)
    box('Glacier shin block '+s,(sgn*.30,.018,.308),(.276,.276,.264),1,SHIN[s],.068)
    plate('Shin sculpted ivory frame '+s,[(sgn*x,z) for x,z in [(.186,.39),(.365,.385),(.423,.225),(.373,.171),(.212,.181),(.155,.245)]],.185,.052,0,SHIN[s],.011)
    plate('Shin glacier centre '+s,[(sgn*x,z) for x,z in [(.208,.360),(.338,.351),(.37,.233),(.267,.21),(.197,.251)]],.231,.021,1,SHIN[s],.020)
    sphere('Ankle porcelain saddle '+s,(sgn*.30,.025,.168),(.224,.235,.08),0,SHIN[s])
    for dx in [-.17,.17]:
        cylinder('Ankle gold bearing '+s,(sgn*.30+dx,.01,.194),.068,.025,4,SHIN[s],(1,0,0))
        cylinder('Ankle titanium hub '+s,(sgn*.30+dx*1.08,.01,.194),.042,.024,3,SHIN[s],(1,0,0))
    box('Wide sole '+s,(sgn*.30,.051,.057),(.418,.47,.094),2,SHIN[s],.029)
    sphere('Foot instep ivory '+s,(sgn*.30,.062,.135),(.20,.218,.081),0,SHIN[s])
    for k in [-1,0,1]:
        box('Broad titanium toe '+s,(sgn*.30+k*.126,.219,.087),(.119,.23,.146),3,SHIN[s],.037)
        box('Toe blue inset '+s,(sgn*.30+k*.126,.228,.154),(.061,.122,.021),6,SHIN[s],.012)

# The central blue power inset protrudes into a substantial gilded socket.
cylinder('Reactor obsidian well',(0,.324,1.29),.142,.063,2,BODY,(0,1,0),32)
cylinder('Reactor champagne bezel',(0,.363,1.29),.129,.049,4,BODY,(0,1,0),32)
torus('Reactor raised gold rim',(0,.399,1.29),.107,.014,4,BODY,(0,1,0))
sphere('Convex cyan reactor',(0,.405,1.29),(.096,.046,.112),5,BODY,28,14)
for z in [1.05,1.135]:
    for x in [-.118,.118]:cylinder('Belly tiny titanium bolt',(x,.261,z),.007,.008,3,BODY,(0,1,0),10)

# Head is a compact upright humanoid/ape face: narrow dark horizontal nose,
# brow at the eye line, broad jaw and many overlapping carved beard locks.
sphere('Ceramic cranium',(0,.12,1.825),(.252,.209,.255),0,HEAD,28,16)
sphere('Dark face socket',(0,.278,1.843),(.220,.095,.146),2,HEAD,24,12)
sphere('Square ivory ape jaw',(0,.32,1.717),(.187,.12,.133),7,HEAD,24,12)
box('Short dark nose',(0,.423,1.825),(.072,.038,.024),2,HEAD,.012)
for s,sgn in [('L',1),('R',-1)]:
    sphere('Eye deep socket '+s,(sgn*.102,.359,1.872),(.080,.035,.060),6,HEAD,20,12)
    sphere('Stern cyan eye '+s,(sgn*.102,.385,1.871),(.048,.025,.045),5,HEAD,24,12)
    # Superciliary ridges slope downward at the centre, deliberately stern.
    leaf('Heavy sculpted brow '+s,[(sgn*.22,.314,1.942),(sgn*.11,.405,1.942),(sgn*.016,.417,1.912)],.068,.047,7,HEAD,8)
    leaf('Cheekbone ceramic '+s,[(sgn*.199,.282,1.842),(sgn*.224,.345,1.746),(sgn*.178,.364,1.681)],.068,.039,7,HEAD)
    leaf('Temple swept fur '+s,[(sgn*.205,.184,1.925),(sgn*.27,.245,1.783),(sgn*.29,.27,1.729)],.064,.047,7,HEAD)
    leaf('Side beard fringe '+s,[(sgn*.146,.327,1.748),(sgn*.223,.405,1.674),(sgn*.228,.359,1.609)],.059,.048,7,HEAD)
    cylinder('Ear dark housing '+s,(sgn*.253,.153,1.879),.085,.064,2,HEAD,(1,0,0),24)
    torus('Ear titanium rim '+s,(sgn*.289,.153,1.879),.063,.013,3,HEAD,(1,0,0))
    cylinder('Ear glacier earcup '+s,(sgn*.29,.153,1.879),.056,.017,1,HEAD,(1,0,0),24)
    cylinder('Ear cyan centre '+s,(sgn*.305,.153,1.879),.038,.019,5,HEAD,(1,0,0),24)
    # Smooth offwhite swept horns, with small machined basal collars.
    leaf('Ivory upswept horn '+s,[(sgn*.196,.064,1.996),(sgn*.269,.065,2.062),(sgn*.244,.095,2.147)],.069,.055,7,HEAD,9)
    leaf('Outer moustache '+s,[(sgn*.02,.412,1.779),(sgn*.132,.46,1.795),(sgn*.162,.409,1.735)],.042,.038,7,HEAD)
    leaf('Crown angled ceramic crest '+s,[(sgn*.04,.145,2.011),(sgn*.12,.251,2.104),(sgn*.163,.137,2.14)],.086,.04,0,HEAD)
# Sculpted forehead shield sharpens the stern triangular brow and crest.
plate('Forehead ivory shield',[(-.215,1.979),(-.115,2.074),(0,2.094),(.115,2.074),(.215,1.979),(.04,1.927),(0,1.91),(-.04,1.927)],.289,.077,7,HEAD,.074)
leaf('Median crown crest',[(0,.07,2.015),(0,.20,2.143),(0,.03,2.171)],.074,.045,7,HEAD,8)
# Overlapping rounded pointed leaves create real relief and deep channels.
for k in [-2,-1,0,1,2]:
    x=k*.052
    tip=1.503+abs(k)*.030
    leaf('Beard front lock '+str(k),[(x,.387,1.753),(x*1.12,.508,1.626),(x*1.03,.44,tip)],.052 if k else .058,.042,7,HEAD,8)
for x in [-.072,.072]:
    leaf('Beard upper overlap',[(x,.42,1.779),(x,.473,1.725),(x*1.07,.464,1.671)],.049,.031,7,HEAD)
# Tiny mouth seam visible through the folded moustache, never a muzzle.
box('Quiet straight mouth',(0,.433,1.756),(.121,.012,.012),2,HEAD,.003)

# Invented back follows the concept's clean manufactured construction.
plate('Back glacium shell',[(-.36,1.57),(.36,1.57),(.38,1.28),(.23,1.12),(-.23,1.12),(-.38,1.28)],-.284,.037,1,BODY,-.031)
box('Back ivory spine',(0,-.334,1.399),(.108,.068,.437),0,BODY,.033)
for z in [1.25,1.35,1.45,1.55]:
    for sgn in [-1,1]:box('Rear coolant vent',(sgn*.214,-.326,z),(.153,.027,.032),6,BODY,.011)
for x,z in [(-.22,1.76),(0,1.81),(.22,1.76)]:
    leaf('Dorsal ivory crest',[(x,-.13,z),(x,-.21,z+.105),(x,-.29,z+.14)],.059,.042,0,BODY)

# Consolidate each moving rigid assembly into one mesh. Materials preserve
# distinct primitive surfaces while animation stays compact and affordable.
for pname,objects in ALL_PARTS.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join()
    o=bpy.context.object;o.name=pname+'_Geometry'
    # Bake all object transforms into mesh; preserve the articulated empty.
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    # Selective simplification spends most geometry on the visible sculpted
    # face and preserves the domed shoulder/chest outlines.
    m=o.modifiers.new('Consolidated surface optimization','DECIMATE')
    m.ratio=.82 if pname=='Head' else .56
    m.use_collapse_triangulate=True
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=m.name)

SCENE=bpy.context.scene;SCENE.render.fps=30
PIVOTS=[BODY,HEAD,*ARM.values(),*ELBOW.values(),*HAND.values(),*LEG.values(),*SHIN.values()]
REST={o.name:(o.location.copy(),o.rotation_euler.copy()) for o in PIVOTS}

def restore():
    for o in PIVOTS:
        o.location=REST[o.name][0];o.rotation_euler=REST[o.name][1]

def pose(clip,t):
    restore()
    if clip=='Idle':
        wave=math.sin(TAU*t);wave2=math.sin(TAU*t+.4)-math.sin(.4)
        BODY.location.z+=.009*wave
        HEAD.rotation_euler.z=.015*wave
        for s,sgn in [('L',1),('R',-1)]:
            ARM[s].rotation_euler.y=sgn*.018*wave
            ELBOW[s].rotation_euler.x=.025*wave2
    elif clip=='Walk':
        w=math.sin(TAU*t);c=math.cos(TAU*t)
        BODY.location.z+=.017*(1-math.cos(2*TAU*t))
        BODY.rotation_euler.y=.025*w;BODY.rotation_euler.z=.026*w
        HEAD.rotation_euler.z=-.018*w
        for s,sgn in [('L',1),('R',-1)]:
            legw=w*sgn
            LEG[s].rotation_euler.x=.28*legw
            SHIN[s].rotation_euler.x=-max(0,legw)*.20
            ARM[s].rotation_euler.x=-.19*legw
            ELBOW[s].rotation_euler.x=-.09+.04*legw
            HAND[s].rotation_euler.y=.027*sgn*c
    elif clip=='Swim':
        w=math.sin(TAU*t);c=math.cos(TAU*t)
        BODY.rotation_euler.x=-.18+.028*w
        BODY.location.z+=.035*w
        HEAD.rotation_euler.x=.12
        for s,sgn in [('L',1),('R',-1)]:
            ARM[s].rotation_euler.x=.42+.40*c
            ARM[s].rotation_euler.y=sgn*(.33+.13*w)
            ELBOW[s].rotation_euler.x=-.25-.20*w
            LEG[s].rotation_euler.x=.16*math.sin(TAU*t+sgn*.5)
            SHIN[s].rotation_euler.x=-.16+sgn*.10*w
    elif clip=='Attack':
        # Two-arm wind-up, heavy downward slam, compressed impact and recover.
        keys=[(0,0,0,0),(.18,1.1,.35,.03),(.44,2.16,.45,.055),(.56,.30,.20,-.13),(.68,.18,.11,-.09),(.82,.06,0,-.035),(1,0,0,0)]
        for i in range(len(keys)-1):
            a,b=keys[i],keys[i+1]
            if a[0]<=t<=b[0]:
                f=(t-a[0])/(b[0]-a[0]);f=f*f*(3-2*f)
                ar=a[1]*(1-f)+b[1]*f;el=a[2]*(1-f)+b[2]*f;drop=a[3]*(1-f)+b[3]*f;break
        BODY.location.z+=drop;BODY.rotation_euler.x=-.25*max(0,-drop/.13)
        HEAD.rotation_euler.x=-.045*math.sin(math.pi*t)
        for s,sgn in [('L',1),('R',-1)]:
            ARM[s].rotation_euler.x=ar;ARM[s].rotation_euler.y=sgn*(-.16*math.sin(math.pi*t))
            ELBOW[s].rotation_euler.x=el
            LEG[s].rotation_euler.x=-.11*max(0,-drop/.13)
            SHIN[s].rotation_euler.x=.17*max(0,-drop/.13)

for clip,frames in [('Idle',60),('Walk',36),('Swim',60),('Attack',42)]:
    for o in PIVOTS:
        o.animation_data_create();o.animation_data.action=None
    for f in range(frames+1):
        pose(clip,f/frames)
        for o in PIVOTS:
            o.keyframe_insert(data_path='location',frame=f)
            o.keyframe_insert(data_path='rotation_euler',frame=f)
    for o in PIVOTS:
        ac=o.animation_data.action;ac.name=clip+'_'+o.name
        for curve in ac.layers[0].strips[0].channelbags[0].fcurves:
            for key in curve.keyframe_points:key.interpolation='LINEAR'
        track=o.animation_data.nla_tracks.new();track.name=clip
        strip=track.strips.new(clip,0,ac);strip.action_frame_start=0;strip.action_frame_end=frames
        track.mute=True
        o.animation_data.action=None
restore()
# All NLA strips export regardless of their viewport mute state. Neutral scene
# is evaluated with the tracks muted, retaining the contract resting pose.
for o in PIVOTS:
    for track in o.animation_data.nla_tracks:track.mute=True
SCENE.frame_set(0)
restore()
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_frostforge_yeti.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_frostforge_yeti.glb'),export_format='GLB',export_yup=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True,export_frame_range=False,export_force_sampling=True,export_cameras=False,export_lights=False)
print('EXPORTED FROSTFORGE YETI',len([o for o in bpy.data.objects if o.type=='MESH']))
