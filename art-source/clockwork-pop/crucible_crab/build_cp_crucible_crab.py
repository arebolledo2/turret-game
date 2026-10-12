import bpy, bmesh, math, json
import numpy as np
from pathlib import Path
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
OUT = Path(__file__).parent
OUT.mkdir(parents=True, exist_ok=True)
TAU=math.tau

# Four generated, shared 1024px atlases: enamel colour, finish, normals and heat.
N=1024
rng=np.random.default_rng(714)
yy,xx=np.mgrid[0:N,0:N]
u=(xx%256)/256; v=(yy%512)/512
noise=rng.normal(0,1,(N,N))
brush=np.sin(u*81+np.sin(v*23))*np.sin(v*131)*.008
mottle=np.sin(u*17+v*11)*np.sin(u*33-v*27)*.021
palette=[(.98,.34,.065),(.105,.115,.135),(.77,.49,.19),(.48,.11,.037),
         (1.,.76,.028),(.37,.125,.042),(.17,.19,.23),(.037,.042,.052)]
metal=[.17,.67,.72,.24,.0,.58,.72,.64]
rough=[.25,.34,.27,.30,.48,.29,.24,.45]
base=np.ones((N,N,4),np.float32); finish=np.ones_like(base); norm=np.ones_like(base); heat=np.zeros_like(base); heat[:,:,3]=1
norm[:,:,0:3]=(.5,.5,1.)
for i,c in enumerate(palette):
    x=(i%4)*256; y=(i//4)*512; sl=np.s_[y:y+512,x:x+256]
    variation=1+mottle[sl]+brush[sl]+noise[sl]*.007
    col=np.array(c)[None,None,:]*variation[:,:,None]
    # Sparse, small pale lacquer scuffs; clean large surfaces remain readable.
    if i in (0,3):
        fleck=(rng.random((512,256))>.9993)
        col=np.where(fleck[:,:,None],col*.62+np.array([.34,.23,.12]),col)
    base[sl][:,:,:3]=np.clip(col,0,1)
    finish[sl][:,:,0]=1
    finish[sl][:,:,1]=np.clip(rough[i]+noise[sl]*.013+mottle[sl]*.6,0,1)
    finish[sl][:,:,2]=metal[i]
    norm[sl][:,:,0]=.5+np.sin(u[sl]*70)*np.cos(v[sl]*63)*.007
    norm[sl][:,:,1]=.5+np.cos(u[sl]*53+v[sl]*43)*.007
    if i==4:
        fu=u[sl]-.5;fv=v[sl]-.42
        core=np.exp(-(fu*fu*27+fv*fv*22))
        tongues=np.clip(np.sin(fu*32+np.sin(fv*19)*2)+.4,0,1)*np.exp(-abs(fu)*3)*np.clip(.8-fv,0,1)
        glow=np.clip(core*.88+tongues*.26,0,1)
        flame=np.stack([np.ones_like(glow),.24+glow*.72,.005+glow**4*.18],-1)
        base[sl][:,:,:3]=flame
        heat[sl][:,:,:3]=flame

def image(name,pixels,noncolor=False):
    img=bpy.data.images.new(name,width=N,height=N,alpha=True)
    img.colorspace_settings.name='Non-Color' if noncolor else 'sRGB'
    img.pixels.foreach_set(pixels.ravel())
    img.filepath_raw=str(OUT/(name+'.png')); img.file_format='PNG'; img.save(); img.pack()
    return img
imgs=[image('Crab_Enamel_Atlas',base),image('Crab_Finish_Atlas',finish,True),image('Crab_Normal_Atlas',norm,True),image('Crab_Heat_Atlas',heat)]
mats=[]
for i,name in enumerate(['Burnt orange enamel','Graphite boiler steel','Warm brass hardware','Oxide red joints','Contained furnace heat','Dark claw copper','Polished dark lenses','Recess and underside']):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*palette[i],1)
    ns=m.node_tree.nodes;ls=m.node_tree.links;p=ns.get('Principled BSDF')
    t=ns.new('ShaderNodeTexImage');t.image=imgs[0];ls.new(t.outputs['Color'],p.inputs['Base Color'])
    t=ns.new('ShaderNodeTexImage');t.image=imgs[1]
    sep=ns.new('ShaderNodeSeparateColor');ls.new(t.outputs['Color'],sep.inputs['Color'])
    ls.new(sep.outputs['Green'],p.inputs['Roughness']);ls.new(sep.outputs['Blue'],p.inputs['Metallic'])
    t=ns.new('ShaderNodeTexImage');t.image=imgs[2];n=ns.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.32
    ls.new(t.outputs['Color'],n.inputs['Color']);ls.new(n.outputs['Normal'],p.inputs['Normal'])
    if i==4:
        t=ns.new('ShaderNodeTexImage');t.image=imgs[3];ls.new(t.outputs['Color'],p.inputs['Emission Color']);p.inputs['Emission Strength'].default_value=1.5
    if i==0:p.inputs['Coat Weight'].default_value=.3;p.inputs['Coat Roughness'].default_value=.23
    mats.append(m)

def parent_world(o,p):
    w=o.matrix_world.copy();o.parent=p;o.matrix_world=w

def empty(name,loc=(0,0,0),parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=loc
    bpy.context.view_layer.update()
    if parent:parent_world(o,parent)
    return o
body=empty('Body',(0,0,1.0))

def finish_obj(o,name,mat,parent=body,smooth=True):
    o.name=name
    bpy.context.view_layer.objects.active=o
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    # Face dominant-axis mapping at common density; fold into the shared atlas tile.
    layer=o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap')
    for poly in o.data.polygons:
        poly.use_smooth=smooth
        axis=max(range(3),key=lambda j:abs(poly.normal[j]))
        for li in poly.loop_indices:
            co=o.data.vertices[o.data.loops[li].vertex_index].co
            a,b=(co.y,co.z) if axis==0 else ((co.x,co.z) if axis==1 else (co.x,co.y))
            # Coordinate span of 4m; 256px per metre before atlas packing.
            layer.data[li].uv=((mat%4+.05+(.45+a*.21)*.9)/4,(mat//4+.05+(.45+b*.21)*.9)/2)
    o.data.materials.append(mats[mat]);bpy.context.view_layer.update()
    if parent:parent_world(o,parent)
    return o

def bevel(o,width=.025,segments=1):
    bpy.context.view_layer.objects.active=o
    mod=o.modifiers.new('Rounded machined edges','BEVEL');mod.width=width;mod.segments=segments;mod.limit_method='ANGLE';mod.angle_limit=math.radians(35)
    bpy.ops.object.modifier_apply(modifier=mod.name)

def box(name,pos,size,mat,parent=body,rounding=.025):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if rounding:bevel(o,rounding,3)
    return finish_obj(o,name,mat,parent,False)

def sphere(name,pos,scale,mat,parent=body,seg=24,rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,radius=1,location=pos)
    o=bpy.context.object;o.scale=scale;return finish_obj(o,name,mat,parent)

def cyl(name,pos,r,depth,mat,parent=body,axis=(0,0,1),vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=pos)
    o=bpy.context.object;o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
    bevel(o,min(.016,r*.16,depth*.22),1)
    return finish_obj(o,name,mat,parent)

def rod(name,a,b,r,mat,parent=body,vertices=20):
    a,b=Vector(a),Vector(b);return cyl(name,(a+b)/2,r,(b-a).length,mat,parent,b-a,vertices)

def tube(name,points,radii,mat,parent=body,sides=16):
    pts=[Vector(p) for p in points];verts=[];faces=[]
    for k,p in enumerate(pts):
        tangent=(pts[min(k+1,len(pts)-1)]-pts[max(k-1,0)]).normalized()
        axis=tangent.cross(Vector((0,0,1)))
        if axis.length<.05:axis=tangent.cross(Vector((0,1,0)))
        axis.normalize();other=tangent.cross(axis).normalized()
        rr=radii[k];r1,r2=rr if isinstance(rr,tuple) else (rr,rr)
        for j in range(sides):
            a=TAU*j/sides;verts.append(p+axis*(math.cos(a)*r1)+other*(math.sin(a)*r2))
    for k in range(len(pts)-1):
        for j in range(sides):
            a=k*sides+j;b=k*sides+(j+1)%sides;faces.append((a,b,b+sides,a+sides))
    faces.append(tuple(reversed(range(sides))));faces.append(tuple((len(pts)-1)*sides+j for j in range(sides)))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
    return finish_obj(o,name,mat,parent)

def ring(name,center,outer,inner,depth,mat,parent=body,axis='Y',segments=32):
    verts=[];faces=[]
    for d,r in [(-depth/2,outer),(-depth/2,inner),(depth/2,outer),(depth/2,inner)]:
        for j in range(segments):
            a=TAU*j/segments
            p=(math.cos(a)*r,d,math.sin(a)*r) if axis=='Y' else ((d,math.cos(a)*r,math.sin(a)*r) if axis=='X' else (math.cos(a)*r,math.sin(a)*r,d))
            verts.append(Vector(center)+Vector(p))
    for j in range(segments):
        k=(j+1)%segments
        for a,b in [(0,1),(2,0),(1,3),(3,2)]:faces.append((a*segments+j,a*segments+k,b*segments+k,b*segments+j))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
    bevel(o,.010,1);return finish_obj(o,name,mat,parent)

# Broad, rounded orange dome, with a visible heavy rolled lower lip.
verts=[];faces=[];S=48;R=13
for k in range(R+1):
    e=(math.pi/2)*k/R
    for j in range(S):
        a=TAU*j/S;verts.append((.87*math.cos(e)*math.cos(a),.67*math.cos(e)*math.sin(a)-.055,1.045+.53*math.sin(e)))
for k in range(R):
    for j in range(S):
        q=k*S+j;n=k*S+(j+1)%S;faces.append((q,n,n+S,q+S))
mesh=bpy.data.meshes.new('Boiler dome');mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new('Boiler dome',mesh);bpy.context.collection.objects.link(o);finish_obj(o,'Orange rounded carapace',0)
ellipse=[(.87*math.cos(TAU*j/64),.67*math.sin(TAU*j/64)-.055,1.055) for j in range(65)]
tube('Rolled orange shell edge',ellipse,[.051]*len(ellipse),0,sides=10)
sphere('Dark pressure vessel',(0,-.02,.81),(.78,.56,.35),1,seg=32,rings=14)
box('Undercarriage',(0,-.03,.59),(1.28,.88,.20),7,rounding=.065)

# Fine raised seams follow the domed surface rather than arbitrary grid panels.
for az in [34,144,216,326]:
    a=math.radians(az);pts=[]
    for j in range(12):
        e=.10+j*.105;pts.append((.878*math.cos(e)*math.cos(a),.678*math.cos(e)*math.sin(a)-.055,1.045+.536*math.sin(e)))
    tube('Carapace panel seam',pts,[.009]*len(pts),5,sides=6)
    for e in [.12,.78]:
        sphere('Panel brass rivet',(.882*math.cos(e)*math.cos(a),.681*math.cos(e)*math.sin(a)-.055,1.045+.54*math.sin(e)),(.027,.027,.027),2,seg=12,rings=6)
box('Crown service vent',(0,-.02,1.566),(.34,.25,.025),5,rounding=.012)
for x in [-.12,-.072,-.024,.024,.072,.12]:box('Crown vent grille',(x,-.02,1.583),(.014,.20,.009),1,rounding=.003)

# Real open octagonal hatch: frame, inward sloping hot refractory wall, rear heat.
outline=[(-1,-.67),(-.67,-1),(.67,-1),(1,-.67),(1,.67),(.67,1),(-.67,1),(-1,.67)]
def hatch_ring(name,loops,mat):
    verts=[];faces=[]
    for w,h,y in loops:
        verts.extend([(x*w,y,.79+z*h) for x,z in outline])
    for k in range(len(loops)-1):
        for j in range(8):faces.append((k*8+j,k*8+(j+1)%8,(k+1)*8+(j+1)%8,(k+1)*8+j))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);bevel(o,.016,2);return finish_obj(o,name,mat,body,False)
hatch_ring('Heavy cast orange hatch frame',[(.49,.38,.58),(.49,.38,.785),(.375,.285,.805),(.36,.27,.69)],0)
hatch_ring('Recessed warm brass hatch liner',[(.374,.284,.792),(.351,.262,.775),(.328,.243,.573)],2)
hatch_ring('Firebrick throat',[(.328,.243,.578),(.300,.223,.551)],3)
arched_brow=[(-.71,.50,1.07),(-.50,.67,1.075),(-.39,.726,1.185),(.39,.726,1.185),(.50,.67,1.075),(.71,.50,1.07)]
tube('Angular armoured brow',arched_brow,[.047]*6,0,sides=10)
for x,y,z in [(-.64,.58,1.09),(-.49,.68,1.12),(-.38,.68,1.20),(.38,.68,1.20),(.49,.68,1.12),(.64,.58,1.09)]:
    sphere('Brow fastening',(x,y,z),(.023,.019,.023),2,seg=12,rings=6)
box('Recessed chamber back',(0,.527,.79),(.60,.024,.44),3,rounding=.024)
# A rear heat plane uses the full procedural flame tile, with independent
# three-dimensional core and fire tongues placed deeper than the hatch lip.
mesh=bpy.data.meshes.new('Procedural fire field')
mesh.from_pydata([(-.29,.548,.575),(.29,.548,.575),(.29,.548,1.005),(-.29,.548,1.005)],[],[(0,1,2,3)]);mesh.update()
o=bpy.data.objects.new('Recessed fire field',mesh);bpy.context.collection.objects.link(o);finish_obj(o,'Recessed fire field',4,body,False)
for li,uv in enumerate([(.0125,.525),(.2375,.525),(.2375,.975),(.0125,.975)]):o.data.uv_layers.active.data[li].uv=uv
sphere('Molten central fire core',(-.032,.558,.756),(.17,.031,.145),4,seg=28,rings=14)
for x,z,s in [(-.24,.84,.055),(.23,.70,.042),(-.13,.98,.028),(.20,.96,.041)]:sphere('Molten ember',(x,.56,z),(s,.018,s*1.3),4,seg=12,rings=6)
for x in [-.255,.255]:
    rod('Recessed glowing refractory bar',(x,.59,.625),(x,.59,.96),.018,3,vertices=10)
box('Hatch lower inspection plate',(0,.810,.478),(.35,.020,.065),3,rounding=.015)
for x,z in [(-.425,.56),(.425,.56),(-.425,1.04),(.425,1.04),(-.28,.452),(.28,.452)]:
    cyl('Hatch heavy bolt',(x,.819,z),.026,.025,1,axis=(0,1,0),vertices=12)
    cyl('Hatch brass bolt centre',(x,.836,z),.014,.012,2,axis=(0,1,0),vertices=10)

# Dark glass-like boiler gauges above the firebox.
for x in [-.35,.35]:
    y=.566;z=1.255
    ring('Gauge brass rim',(x,y,z),.096,.070,.031,2)
    sphere('Dark convex gauge',(x,y+.020,z),(.073,.039,.073),6,seg=20,rings=10)
for s in [-1,1]:
    # Outer side boiler drums: broad concentric brass and graphite bands.
    cyl('Side pressure drum',(s*.84,-.03,1.04),.342,.20,1,axis=(1,0,0),vertices=32)
    ring('Side drum brass flange',(s*.961,-.03,1.04),.339,.266,.078,2,axis='X',segments=32)
    cyl('Side drum dark face',(s*1.010,-.03,1.04),.249,.037,1,axis=(1,0,0),vertices=32)
    cyl('Hub brass collar',(s*1.040,-.03,1.04),.154,.071,2,axis=(1,0,0),vertices=28)
    cyl('Hub graphite cap',(s*1.084,-.03,1.04),.125,.035,6,axis=(1,0,0),vertices=28)
    for a in [math.pi*.25,math.pi*.75,math.pi*1.25,math.pi*1.75]:
        cyl('Side flange fastening',(s*1.012,-.03+math.cos(a)*.296,1.04+math.sin(a)*.296),.015,.012,3,axis=(1,0,0),vertices=10)
    # Two short capped chimneys, with actual pipe hollows and raised brass collars.
    x=s*.53;y=-.28;basez=1.46
    cyl('Chimney dark socket',(x,y,basez),.173,.09,1,vertices=28)
    ring('Chimney lower brass collar',(x,y,basez+.07),.143,.111,.067,2,axis='Z')
    ring('Hollow graphite flue',(x,y,1.735),.116,.087,.42,1,axis='Z')
    ring('Chimney upper brass band',(x,y,1.926),.151,.103,.060,2,axis='Z')
    sphere('Rounded chimney rain cap',(x,y,1.993),(.171,.171,.134),1,seg=28,rings=12)
    for d in [-1,1]:rod('Rain cap narrow brass stripe',(x+d*.093,y+.111,1.978),(x+d*.087,y+.121,2.048),.008,2,vertices=8)
    # Side chassis valve behind claw arm.
    cyl('Side maintenance gauge',(s*.747,.13,.785),.083,.037,5,axis=(1,0,0),vertices=20)
    cyl('Side maintenance brass centre',(s*.777,.13,.785),.043,.03,2,axis=(1,0,0),vertices=16)

# Four substantial crab legs, each with hip and independent knee/ankle articulation.
legs=[];knees=[];feet=[]
for s,label in [(-1,'L'),(1,'R')]:
    for i,y in enumerate([-.51,.04]):
        hip=(s*.66,y,.74);knee=(s*1.27,y-.12,.44);ankle=(s*1.39,y+.04,.14)
        p=empty(f'Leg_{label}_{i}',hip,body);legs.append(p)
        sphere('Brass hip ball',hip,(.129,.129,.129),2,p,seg=20,rings=10)
        tube('Upper orange leg armour',[hip,(s*.95,y-.04,.65),knee],[.116,.132,.10],0,p,sides=20)
        rod('Hip graphite collar',hip,(s*.77,y-.02,.685),.124,1,p)
        k=empty(f'Knee_{label}_{i}',knee,p);knees.append(k)
        sphere('Brass articulated knee',knee,(.114,.114,.114),2,k,seg=18,rings=9)
        tube('Lower red leg armour',[knee,(s*1.34,y-.05,.27),ankle],[.097,.091,.07],3,k,sides=18)
        ring('Leg cuff',ankle,.077,.053,.035,2,k,axis='Z',segments=20)
        f=empty(f'Foot_{label}_{i}',ankle,k);feet.append(f)
        tube('Curved pointed foot',[ankle,(s*1.44,y+.06,.075),(s*1.46,y+.12,.026)],[.069,.059,.013],3,f,sides=16)

# Claws: short bent arm, swollen enamel palm, two individually hinged curved jaws.
claws=[];jaws=[]
for s,label in [(-1,'L'),(1,'R')]:
    hip=(s*.70,.37,.71);p=empty(f'Claw_{label}',hip,body);claws.append(p)
    sphere('Claw brass shoulder',hip,(.13,.13,.13),2,p,seg=20,rings=10)
    tube('Claw upper arm',[hip,(s*.94,.48,.70),(s*1.13,.68,.59)],[.13,.15,.17],0,p,sides=24)
    rod('Claw graphite wrist',(s*1.11,.64,.59),(s*1.16,.76,.54),.199,1,p)
    ring('Claw wrist brass ring',(s*1.15,.72,.56),.192,.167,.034,2,p,segments=28)
    palm=(s*1.17,.86,.43)
    sphere('Huge rounded claw palm',palm,(.34,.29,.35),0,p,seg=32,rings=16)
    # Thin side trim echoes the overlapping reference armour plates.
    for a in [-.72,.72]:
        sphere('Claw shell fastening',(s*(1.17+.275),.89+a*.18,.44+a*.16),(.016,.026,.026),2,p,seg=12,rings=6)
    for z,sign in [(.52,1),(.31,-1)]:
        hinge=(s*1.16,1.05,z);jaw=empty(f'Jaw_{label}_{"Top" if sign>0 else "Bottom"}',hinge,p);jaws.append((jaw,s,sign))
        # Hook shapes are thick at the palm, narrowing toward a dark copper tip.
        if sign>0:
            pts=[(s*1.16,1.04,.64),(s*1.15,1.28,.64),(s*1.12,1.48,.45),(s*1.09,1.57,.28)]
            radii=[(.22,.18),(.185,.169),(.101,.092),(.008,.012)]
        else:
            pts=[(s*1.17,1.02,.24),(s*1.16,1.30,.16),(s*1.13,1.48,.18),(s*1.10,1.58,.24)]
            radii=[(.177,.103),(.144,.079),(.078,.057),(.007,.009)]
        tube('Orange pincer jaw',pts[:3],radii[:3],0 if sign>0 else 3,jaw,sides=24)
        # The final section darkens from orange enamel into heat-darkened copper.
        tube('Dark tapered pincer tip',pts[2:],radii[2:],5,jaw,sides=24)
        cyl('Side pincer hinge pin',(s*1.435,1.045,z),.030,.025,2,jaw,axis=(1,0,0),vertices=12)

# Gentle outward splay makes the open pincer gap and the copper inner jaw read
# clearly from the gameplay camera while retaining the large rounded palms.
for i,p in enumerate(claws):p.rotation_euler.z=(-1 if i==0 else 1)*.08

# Rear service hatches, pressure gauges and two restrained brass cooling rails.
box('Rear dark service panel',(0,-.565,.814),(.64,.055,.30),7,rounding=.04)
for x in [-.23,.23]:
    cyl('Rear red inspection cap',(x,-.601,.82),.100,.026,3,axis=(0,1,0),vertices=24)
    ring('Rear inspection brass ring',(x,-.62,.82),.102,.085,.016,2)
for z in [.69,.79,.89]:rod('Rear cooling rail',(-.34,-.626,z),(.34,-.626,z),.016,1)

# Join geometry that moves together; material assignments and atlas UVs survive.
for p in [o for o in bpy.context.scene.objects if o.type=='EMPTY']:
    group=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.parent==p]
    if not group:continue
    bpy.ops.object.select_all(action='DESELECT')
    for o in group:o.select_set(True)
    bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join()
    group[0].name=p.name+'_Geometry'

# Every named clip uses actual rigid transforms. NLA names merge the per-part
# actions into one glTF animation, with matching endpoints for loopable clips.
scene=bpy.context.scene;scene.render.fps=30
body.location.y=-.45
animated=[body]+legs+knees+feet+claws+[j[0] for j in jaws]
rest={o.name:(o.location.copy(),o.rotation_euler.copy()) for o in animated}
for clip,duration in [('Idle',90),('Walk',48),('Swim',72),('Attack',42)]:
    for o in animated:
        o.animation_data_clear();o.location=rest[o.name][0];o.rotation_euler=rest[o.name][1]
    samples=16 if clip!='Attack' else 14
    for k in range(samples+1):
        t=k/samples;phase=TAU*t;frame=1+round(t*duration)
        for o in animated:o.location=rest[o.name][0].copy();o.rotation_euler=rest[o.name][1].copy()
        if clip=='Idle':
            body.location.z+=.014*math.sin(phase)
            for i,o in enumerate(claws):o.rotation_euler.y=.022*math.sin(phase+i*math.pi)
            for o,s,sign in jaws:o.rotation_euler.x=sign*.025*(1-math.cos(phase))
        elif clip in ('Walk','Swim'):
            amp=.14 if clip=='Walk' else .22
            body.location.z+=(.026 if clip=='Walk' else .05)*math.sin(phase*2)
            body.rotation_euler.y=.035*math.sin(phase)
            for i,o in enumerate(legs):
                ph=phase+(0 if i in [0,3] else math.pi)
                o.rotation_euler.z=amp*math.sin(ph);o.rotation_euler.y=(1 if i<2 else -1)*.10*math.sin(ph)
                knees[i].rotation_euler.y=(1 if i<2 else -1)*.18*max(0,math.sin(ph))
                feet[i].rotation_euler.x=.10*math.sin(ph)
            for i,o in enumerate(claws):o.rotation_euler.x=.055*math.sin(phase+i*math.pi);o.rotation_euler.z+=(1 if i==0 else -1)*.07*math.sin(phase)
        else:
            # Anticipate, open, strike forward and close, then return precisely.
            wind=math.sin(math.pi*min(t/.42,1)) if t<.42 else 0
            strike=math.sin(math.pi*(t-.35)/.42) if .35<t<.77 else 0
            body.rotation_euler.x=-.08*strike;body.location.y+=.035*strike
            for i,o in enumerate(claws):o.rotation_euler.x=-.20*wind+.27*strike;o.rotation_euler.z+=(1 if i==0 else -1)*(.13*wind-.12*strike)
            for o,s,sign in jaws:o.rotation_euler.x=sign*(.40*wind-.08*strike)
        for o in animated:
            o.keyframe_insert(data_path='location',frame=frame,group=o.name)
            o.keyframe_insert(data_path='rotation_euler',frame=frame,group=o.name)
    for o in animated:
        action=o.animation_data.action;action.name=clip+'_'+o.name
        track=o.animation_data.nla_tracks.new();track.name=clip
        strip=track.strips.new(clip,1,action);strip.name=clip
        o.animation_data.action=None
    # Preserve the NLA tracks while resetting object transforms for the next clip.
    for o in animated:
        tracks=list(o.animation_data.nla_tracks)
        # animation_data_clear at next clip would remove these, so store actions.
        pass
    if clip=='Idle':clip_actions={}
    clip_actions[clip]={o.name:o.animation_data.nla_tracks[-1].strips[0].action for o in animated}

for o in animated:
    o.animation_data_clear();o.animation_data_create()
    for clip,duration in [('Idle',90),('Walk',48),('Swim',72),('Attack',42)]:
        action=clip_actions[clip][o.name]
        tr=o.animation_data.nla_tracks.new();tr.name=clip
        st=tr.strips.new(clip,1,action);st.name=clip;tr.mute=True
    o.location=rest[o.name][0];o.rotation_euler=rest[o.name][1]
scene.frame_start=1;scene.frame_end=91;scene.frame_set(1)
bpy.context.view_layer.update()
# Export muted NLA tracks as grouped clips; no renderer-specific materials or lights.
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_crucible_crab.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_crucible_crab.glb'),export_format='GLB',export_yup=True,
    export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips_merged_animation_name='Animation',
    export_cameras=False,export_lights=False,export_materials='EXPORT',export_image_format='AUTO')
stats={'triangles':sum(len(o.data.loop_triangles) for o in scene.objects if o.type=='MESH'),
       'meshes':len([o for o in scene.objects if o.type=='MESH']), 'materials':len(mats),'textures':4}
print('CRAB BUILD COMPLETE',stats)
