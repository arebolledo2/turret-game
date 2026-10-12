"""Kiln Lobber: self-contained procedural textured rigid-part asset.
Blender 5.2: --background --python build_eco_lobber.py
"""
from pathlib import Path
import math, json
import bpy, bmesh
import numpy as np
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
OUT = Path(__file__).resolve().parent
TAU = math.tau

# Four shared 1024-square atlases: colour, metallic/roughness, tangent normal, emission.
# Material zones are intentionally clean, with very gentle broad brushed pigment variation.
S = 1024; CELL = 256
palette = [
 ('Saffron enamel', (0.95, .32, .038), .08, .41),
 ('Orange edge enamel', (1.0, .45, .07), .08, .36),
 ('Warm copper', (.59, .31, .22), .68, .30),
 ('Antique brass', (.83, .58, .21), .72, .26),
 ('Petrol shell', (.16, .29, .32), .42, .37),
 ('Deep charcoal bore', (.041, .031, .051), .10, .65),
 ('Plum fasteners', (.37, .17, .28), .48, .30),
 ('Turquoise lenses', (.05, .73, .75), .25, .22),
 ('Furnace yellow', (1.0, .80, .12), .0, .26),
 ('Dark seams', (.065, .13, .16), .42, .43),
]
color = np.ones((S,S,4), np.float32)
orm = np.ones((S,S,4), np.float32)
normal = np.ones((S,S,4), np.float32); normal[:,:,:3] = (.5,.5,1)
emiss = np.ones((S,S,4), np.float32); emiss[:,:,:3] = 0
rng = np.random.default_rng(83)
y,x = np.mgrid[0:CELL,0:CELL]
u=x/CELL; v=y/CELL
for i,(name,c,metal,rough) in enumerate(palette):
    # soft hand-painted irregularity: coherent low-frequency waves, tiny enamel grain.
    a = .032*np.sin(u*TAU*2 + .6*np.sin(v*TAU*3)) + .018*np.cos(v*TAU*4+u*5)
    fine = rng.normal(0,.004,(CELL,CELL))
    if i in (2,3): a += .018*np.sin(v*TAU*28 + .7*np.sin(u*TAU))
    if i==5: a *= .45
    pix = np.array(c)[None,None,:]*(1+a[:,:,None]+fine[:,:,None])
    # every tile has a subtle directional warmth variation, no black random grime.
    pix += ((v-.5)*.013)[:,:,None]*np.array((1,.5,.15))[None,None,:]
    cy,cx=i//4*CELL,i%4*CELL
    color[cy:cy+CELL,cx:cx+CELL,:3] = np.clip(pix,0,1)
    orm[cy:cy+CELL,cx:cx+CELL,0] = 1
    orm[cy:cy+CELL,cx:cx+CELL,1] = np.clip(rough + .028*a/.05 + fine, .08,.9)
    orm[cy:cy+CELL,cx:cx+CELL,2] = metal
    dx=.006*np.cos(u*TAU*2+.6*np.sin(v*TAU*3))
    dy=.004*np.sin(v*TAU*4+u*5)
    normal[cy:cy+CELL,cx:cx+CELL,0]=.5+dx
    normal[cy:cy+CELL,cx:cx+CELL,1]=.5+dy
    if i in (7,8):
        em=np.array((.02,.33,.34) if i==7 else (1,.73,.018))
        emiss[cy:cy+CELL,cx:cx+CELL,:3]=np.clip(em[None,None,:]*(.96+.04*np.cos(v*TAU))[:,:,None],0,1)

def image_data(name,pix,noncolor=False):
    im=bpy.data.images.new(name, width=S,height=S,alpha=True)
    im.colorspace_settings.name='Non-Color' if noncolor else 'sRGB'
    im.pixels.foreach_set(pix.ravel())
    im.filepath_raw=str(OUT/(name+'.png')); im.file_format='PNG'; im.save(); im.pack()
    return im
imgs=[image_data('kiln_colour',color),image_data('kiln_orm',orm,True),image_data('kiln_normal',normal,True),image_data('kiln_emission',emiss)]
materials=[]
for i,(name,c,metal,rough) in enumerate(palette):
    mat=bpy.data.materials.new(name); mat.diffuse_color=(*c,1); mat.use_nodes=True
    mat['atlas_tile']=i
    ns=mat.node_tree.nodes; ls=mat.node_tree.links; bs=ns.get('Principled BSDF')
    bs.inputs['Metallic'].default_value=metal; bs.inputs['Roughness'].default_value=rough
    t=ns.new('ShaderNodeTexImage'); t.image=imgs[0]; ls.new(t.outputs['Color'],bs.inputs['Base Color'])
    t=ns.new('ShaderNodeTexImage'); t.image=imgs[1]
    sep=ns.new('ShaderNodeSeparateColor'); ls.new(t.outputs['Color'],sep.inputs['Color'])
    ls.new(sep.outputs['Green'],bs.inputs['Roughness']); ls.new(sep.outputs['Blue'],bs.inputs['Metallic'])
    t=ns.new('ShaderNodeTexImage'); t.image=imgs[2]; nm=ns.new('ShaderNodeNormalMap'); nm.inputs['Strength'].default_value=.3
    ls.new(t.outputs['Color'],nm.inputs['Color']); ls.new(nm.outputs['Normal'],bs.inputs['Normal'])
    if i in (7,8):
        t=ns.new('ShaderNodeTexImage'); t.image=imgs[3]; ls.new(t.outputs['Color'],bs.inputs['Emission Color'])
        bs.inputs['Emission Strength'].default_value=.65 if i==7 else 2.2
    materials.append(mat)
ORANGE,EDGE,COPPER,GOLD,TEAL,BORE,PLUM,LENS,FIRE,SEAM=materials

def pivot(name,pos,parent=None):
    o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o); o.location=pos; o.empty_display_type='PLAIN_AXES'; o.empty_display_size=.05
    if parent:
        bpy.context.view_layer.update(); mw=o.matrix_world.copy(); o.parent=parent; o.matrix_world=mw
    return o
root=pivot('Kiln_Lobber',(0,0,0))
body=pivot('Body',(0,0,.50),root)
aim=pivot('Aim',(0,0,.86),body)
muzzle=pivot('Muzzle',(0,.65,.86),aim)
# Marker rotation is identity; +Y is the open-bore axis. No geometry belongs to marker.

assemblies={}
def finish(o,name,mat,group):
    o.name=name; o.data.materials.append(mat)
    for p in o.data.polygons:p.use_smooth=True
    # UV islands are scaled by physical size at roughly common texel density, inside the material's atlas tile.
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.uv.smart_project(angle_limit=1.1,island_margin=.018); bpy.ops.object.mode_set(mode='OBJECT')
    uv=o.data.uv_layers.active
    tile=int(mat['atlas_tile']); tx,ty=tile%4,tile//4
    # Small parts use smaller tile areas; preserve broad painted shading on the main panels.
    extent=max(o.dimensions); scale=min(.90,max(.14,extent/.65*.90))
    for d in uv.data:
        d.uv=((tx+.5+(d.uv.x-.5)*scale)/4,(ty+.5+(d.uv.y-.5)*scale)/4)
    assemblies.setdefault(group,[]).append(o)
    return o

def bevel(o,w=.015,seg=3):
    mod=o.modifiers.new('Soft machined edges','BEVEL'); mod.width=w; mod.segments=seg
    bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=mod.name)
    # weighted normals on broad frame faces prevent pillowed planar shading
    mod=o.modifiers.new('Weighted face normals','WEIGHTED_NORMAL'); mod.keep_sharp=True; mod.weight=30
    bpy.ops.object.modifier_apply(modifier=mod.name)

def box(name,pos,size,mat,group,r=.018):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos); o=bpy.context.object; o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bevel(o,min(r,min(size)*.4),2)
    return finish(o,name,mat,group)

def sphere(name,pos,scale,mat,group,segments=28,rings=14):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1,location=pos); o=bpy.context.object; o.scale=scale
    return finish(o,name,mat,group)

def cyl(name,pos,r,depth,mat,group,axis=(0,0,1),verts=32,bevel_width=.009):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=depth,location=pos); o=bpy.context.object
    o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
    if bevel_width: bevel(o,min(bevel_width,depth*.23,r*.25),2 if r>.09 else 1)
    return finish(o,name,mat,group)

def strut(name,a,b,r,mat,group,verts=20):
    a,b=Vector(a),Vector(b); return cyl(name,(a+b)/2,r,(b-a).length,mat,group,b-a,verts,.006)

# Lathe a closed profile around Y; profile coordinates (axial Y, radius).
def lathe(name,profile,center,mat,group,N=48):
    vs=[]; fs=[]
    for ay,r in profile:
        for k in range(N):
            ang=k*TAU/N; vs.append((center[0]+r*math.cos(ang),center[1]+ay,center[2]+r*math.sin(ang)))
    for j in range(len(profile)-1):
        for k in range(N):
            n=(k+1)%N; fs.append((j*N+k,j*N+n,(j+1)*N+n,(j+1)*N+k))
    # Close profile strip: useful for annular rims.
    if profile[0]!=profile[-1]:
        for k in range(N):
            n=(k+1)%N; fs.append(((len(profile)-1)*N+k,(len(profile)-1)*N+n,n,k))
    me=bpy.data.meshes.new(name+'Mesh'); me.from_pydata(vs,[],fs); me.update()
    # recalc outside normals for all closed surfaces
    bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=bm.faces); bm.to_mesh(me); bm.free()
    o=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(o)
    return finish(o,name,mat,group)

def torus_y(name,y,z,R,r,mat,group,N=40,M=8,x=0):
    profile=[(y+math.sin(k*TAU/M)*r,R+math.cos(k*TAU/M)*r) for k in range(M)]
    return lathe(name,profile,(x,0,z),mat,group,N)

def arc_z(name,z,r,depth,a0,a1,mat,group,N=36):
    # Curved furnace window following the front of the belly.
    vs=[]; fs=[]
    for zz in (z-depth/2,z+depth/2):
        for rr in (r-.012,r+.012):
            for k in range(N+1):
                a=a0+(a1-a0)*k/N; vs.append((rr*math.sin(a),rr*math.cos(a),zz))
    s=N+1
    for j in range(N):
        fs.extend([(j,j+1,s+j+1,s+j),(2*s+j,3*s+j,3*s+j+1,2*s+j+1),(j,2*s+j,2*s+j+1,j+1),(s+j,s+j+1,3*s+j+1,3*s+j)])
    fs.extend([(0,s,3*s,2*s),(N,2*s+N,3*s+N,s+N)])
    me=bpy.data.meshes.new(name+'Mesh'); me.from_pydata(vs,[],fs); me.update()
    bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=bm.faces); bm.to_mesh(me); bm.free()
    o=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(o); return finish(o,name,mat,group)

# Base: stout charcoal bowl, broad warm copper belt, furnace window and firing cradle.
sphere('Squat enamel belly',(0,-.025,.48),(.35,.30,.225),TEAL,'Body',32,16)
cyl('Belly lower collar',(0,-.03,.285),.19,.035,COPPER,'Body',verts=36)
cyl('Kiln belly belt',(0,-.025,.532),.354,.066,COPPER,'Body',verts=48,bevel_width=.013)
cyl('Upper furnace casing',(0,-.022,.634),.332,.20,ORANGE,'Body',verts=48,bevel_width=.015)
arc_z('Golden hot furnace slit',.605,.338,.078,-.79,.79,FIRE,'Body')
arc_z('Upper visor lip',.653,.345,.026, -.86,.86,EDGE,'Body')
arc_z('Lower visor lip',.556,.346,.024, -.86,.86,COPPER,'Body')
for sx in (-1,1):
    box('Furnace window jamb',(sx*.240,.246,.605),(.038,.049,.098),GOLD,'Body',.009)
for angle in (0,.85,-.85,1.7,-1.7,math.pi):
    p=(.36*math.sin(angle),-.025+.36*math.cos(angle),.533)
    cyl('Belt brass rivet',p,.016,.012,GOLD,'Body',axis=(math.sin(angle),math.cos(angle),0),verts=16)
# Upper receiver is a horizontal drum, dark shell flanked by orange ring ribs.
lathe('Petrol receiver',[(-.34,.265),(-.325,.304),(-.27,.326),(.10,.326),(.16,.307),(.17,.26)],(0,0,.865),TEAL,'Body',48)
for yy in (-.278,.13):
    lathe('Orange receiver hoop',[(yy-.022,.319),(yy-.015,.343),(yy+.015,.343),(yy+.025,.319),(yy+.017,.310),(yy-.02,.310)],(0,0,.865),EDGE,'Body',48)
# Rear cap and service hubs support sensible invented hidden geometry.
cyl('Rear receiver cap',(0,-.35,.865),.252,.05,TEAL,'Body',axis=(0,1,0),verts=40)
torus_y('Rear copper bead',-.386,.865,.24,.012,GOLD,'Body',40,8)
cyl('Rear exhaust dome',(0,-.399,.865),.11,.043,COPPER,'Body',axis=(0,1,0),verts=28)
cyl('Rear exhaust inset',(0,-.423,.865),.084,.007,SEAM,'Body',axis=(0,1,0),verts=28)
for xx in (-.037,0,.037):
    box('Rear three radiator slats',(xx,-.433,.865),(.012,.012,.103),GOLD,'Body',.004)
cyl('Pressure cap',(0,-.14,1.199),.030,.027,COPPER,'Body',verts=24)
cyl('Pressure cap ivory edge',(0,-.14,1.214),.024,.010,GOLD,'Body',verts=24)

# Forward mortar tube: orange domed outer jacket with a deep dark real bore, thick copper ring.
lathe('Bulging saffron mortar jacket',[(.115,.293),(.16,.323),(.235,.322),(.33,.305),(.40,.278),(.442,.258),(.44,.208),(.26,.207),(.115,.205)],(0,0,.865),ORANGE,'Aim',56)
# The lining continues well behind the lip; nothing caps the actual mouth plane.
lathe('Deep dark bore liner',[(.635,.214),(.575,.214),(.45,.195),(.345,.185),(.34,.197),(.45,.210),(.575,.225),(.635,.225)],(0,0,.865),BORE,'Aim',56)
cyl('Dark recessed bore terminus',(0,.340,.865),.193,.009,BORE,'Aim',axis=(0,1,0),verts=48,bevel_width=0)
lathe('Thick copper muzzle crown',[(.414,.25),(.437,.274),(.49,.283),(.584,.281),(.626,.265),(.65,.249),(.65,.222),(.632,.214),(.60,.218),(.464,.220),(.414,.226)],(0,0,.865),COPPER,'Aim',64)
# Fine warm raised lip reflects light around the edge while interior stays very dark.
torus_y('Muzzle lip bead',.643,.865,.239,.006,COPPER,'Aim',56,8)
torus_y('Muzzle rear seam',.463,.865,.278,.006,PLUM,'Aim',48,8)
for k in range(8):
    a=k*TAU/8
    sphere('Crown plum bolt',(.281*math.cos(a),.458,.865+.281*math.sin(a)),(.011,.016,.011),PLUM,'Aim',12,6)
# Receiver hoop bolts and small hold-down brackets; all move with Aim.
for a in (-.5,.35,1.12,1.92,2.8,3.6,4.6,5.3):
    p=(.35*math.cos(a),.158,.865+.35*math.sin(a))
    cyl('Hoop gold bolt',p,.018,.016,GOLD,'Aim',axis=(0,1,0),verts=16)
for sx in (-1,1):
    box('Mortar hold-down block',(sx*.298,.10,.695),(.077,.068,.078),GOLD,'Body',.008)

# Heavy orange side shutters: recessed painted slab, broad raised frame, rounded rails and turquoise badges.
shutters=[]
for sx,label in ((-1,'L'),(1,'R')):
    x=sx*.38
    sh=pivot('Shutter_'+label,(x,0,.90),body); shutters.append(sh)
    group='Shutter_'+label
    box('Inset orange shutter panel',(x,-.025,.91),(.047,.424,.392),ORANGE,group,.018)
    # Distinct panel rim, short thick upright fore/rear posts and broad top handrail.
    for yy in (-.255,.205):
        box('Rounded orange shutter post',(x,yy,.922),(.086,.080,.444),EDGE,group,.030)
        for zz in (.732,1.105):
            cyl('Shutter brass facebolt',(x+sx*.053,yy,zz),.018,.012,GOLD,group,axis=(sx,0,0),verts=16)
    for zz in (.71,1.135):
        box('Shutter horizontal rail',(x,-.025,zz),(.085,.502,.077),EDGE,group,.028)
    # Diagonal very faint raised crease near bottom provides designed surface structure.
    cyl('Turquoise badge copper housing',(x+sx*.037,.06,.794),.056,.022,COPPER,group,axis=(sx,0,0),verts=32)
    cyl('Turquoise badge brass bead',(x+sx*.052,.06,.794),.048,.012,GOLD,group,axis=(sx,0,0),verts=32)
    sphere('Turquoise enamel badge',(x+sx*.061,.06,.794),(.018,.038,.041),LENS,group,24,12)
    box('Shutter copper hinge',(sx*.326,.087,.768),(.051,.071,.078),COPPER,'Body',.008)
    box('Shutter copper hinge',(sx*.326,-.16,1.058),(.051,.071,.061),COPPER,'Body',.008)

# Tripod stance: a front leg and two rear outriggers. Upper knuckles and lower segments are rigid distinct assemblies.
legs=[]; knees=[]
leg_specs=[(0,.255),(-.27,-.145),(.27,-.145)]
for i,(hx,hy) in enumerate(leg_specs):
    v=Vector((hx,hy,0)).normalized()
    hip=Vector((hx,hy,.378)); knee=hip+Vector((v.x*.055,v.y*.055,-.072)); foot=Vector((v.x*.465,v.y*.465,.058))
    leg=pivot('Leg_'+str(i),hip,root); kn=pivot('Knee_'+str(i),knee,leg); legs.append(leg); knees.append(kn)
    upper='Leg_'+str(i); lower='Knee_'+str(i)
    axis=Vector((-v.y,v.x,0))
    # Round hip cup in copper with brass shoulder band and a teal/plum bolt face.
    cyl('Hip copper socket',hip,.086,.115,COPPER,upper,axis,32)
    cyl('Hip brass shoulder',hip+axis*.062,.069,.027,GOLD,upper,axis,32)
    cyl('Hip enamel insert',hip+axis*.079,.048,.014,LENS if i==2 else PLUM,upper,axis,28)
    strut('Short brass upper link',hip,knee,.071,GOLD,upper,24)
    cyl('Knee charcoal drum',knee,.060,.141,SEAM,lower,axis,28)
    for ss in (-1,1):
        cyl('Knee plum bearing',knee+axis*(ss*.075),.043,.014,PLUM,lower,axis,24)
        cyl('Knee copper pin',knee+axis*(ss*.086),.025,.010,COPPER,lower,axis,20)
    # Tapered robust dark teal shin, angled outward toward a broad foot.
    a=knee+Vector((v.x*.008,v.y*.008,-.035)); b=foot+Vector((0,0,.075))
    bpy.ops.mesh.primitive_cone_add(vertices=28,radius1=.078,radius2=.062,depth=(a-b).length,location=(a+b)/2)
    o=bpy.context.object; o.rotation_euler=(a-b).to_track_quat('Z','Y').to_euler(); bevel(o,.009,2); finish(o,'Thick petrol shin',TEAL,lower)
    sphere('Rounded copper tripod foot',foot+Vector((0,0,.024)),(.121,.121,.071),COPPER,lower,28,12)
    cyl('Copper foot sole',foot+Vector((0,0,-.034)),.120,.034,COPPER,lower,verts=32,bevel_width=.010)
    cyl('Fine brass sole bead',foot+Vector((0,0,-.012)),.119,.010,GOLD,lower,verts=32,bevel_width=.004)
# add service brass and teal bolts on lower belly readable in front view
for xx in (-.245,.245):
    cyl('Lower furnace brass badge',(xx,.23,.441),.051,.025,GOLD,'Body',axis=(0,1,0),verts=28)
    cyl('Lower furnace turquoise button',(xx,.247,.441),.034,.015,LENS,'Body',axis=(0,1,0),verts=28)

# Lift the upper receiver and barrel together to reveal the glowing slit below the bore.
# Shift completed world geometry once, then matching empty transforms, retaining a neutral Aim.
for key in ('Aim','Shutter_L','Shutter_R'):
    for o in assemblies[key]:o.location.z+=.05
for o in assemblies['Body']:
    if any(token in o.name for token in ('receiver','Rear','Pressure','Shutter copper hinge','hold-down')):o.location.z+=.05
bpy.context.view_layer.update()
aim.location.z+=.05
muzzle.location.z+=.005
for sh in shutters:sh.location.z+=.05
# The muzzle was already under Aim, so the pivot shift carries its bore position with it.

# Join all fixed geometry per moving assembly. Ten efficient draw objects retain atlas/material regions.
parents={'Body':body,'Aim':aim,**{s.name:s for s in shutters},**{l.name:l for l in legs},**{k.name:k for k in knees}}
for key,objects in assemblies.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]; bpy.ops.object.join(); o=bpy.context.object; o.name=key+'_mesh'
    bpy.context.view_layer.update(); mw=o.matrix_world.copy(); o.parent=parents[key]; o.matrix_world=mw
    # Place mesh origin at corresponding pivot, simplify object rest transforms.
    bpy.context.scene.cursor.location=parents[key].matrix_world.translation
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')

# Animation through common NLA track names merges all rigid-node actions into named glTF clips.
scene=bpy.context.scene; scene.render.fps=30; scene.frame_start=1; scene.frame_end=61
animated=[body,aim,*legs,*knees,*shutters]
rests={o.name:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in animated}
def clip(name,length,loop):
    for o in animated:
        loc,rot,scale=rests[o.name]
        o.animation_data_create(); o.animation_data.action=None
        for f in range(1,length+1,3):
            t=(f-1)/(length-1); phase=t*TAU
            o.location=loc; o.rotation_euler=rot; o.scale=scale
            if name=='Idle':
                if o==body: o.location.z+=.004*math.sin(phase)
                if o==aim: o.rotation_euler.x+=.008*math.sin(phase)
            elif name in ('Walk','Swim'):
                if o==body:
                    o.location.z+=.008*(1-math.cos(phase*2))*.5
                    o.rotation_euler.y+=.018*math.sin(phase)
                for i,l in enumerate(legs):
                    ph=phase+i*TAU/3
                    if o==l:
                        o.rotation_euler.x+=.13*(math.sin(ph)-math.sin(i*TAU/3))
                        o.rotation_euler.y+=.07*(math.sin(ph+i*1.2)-math.sin(i*TAU/3+i*1.2))
                    if o==knees[i]: o.rotation_euler.x+=.055*(math.sin(ph-.5)-math.sin(i*TAU/3-.5))
                if o==aim: o.rotation_euler.x+=.01*math.sin(phase)
            elif name=='Attack':
                # Anticipation, sharp barrel recoil, damped return, all ending exactly in rest.
                def lerpkeys(keys):
                    for (a,va),(b,vb) in zip(keys,keys[1:]):
                        if a<=t<=b:
                            q=(t-a)/(b-a); q=q*q*(3-2*q); return va+(vb-va)*q
                    return keys[-1][1]
                kick=lerpkeys([(0,0),(.2,-.012),(.32,.06),(.48,.035),(.72,-.006),(1,0)])
                if o==aim:
                    o.location.y-=kick; o.rotation_euler.x-=kick*1.2
                if o==body: o.rotation_euler.x+=kick*.21
                for i,l in enumerate(legs):
                    if o==l:o.rotation_euler.x+=kick*.3
                for sh in shutters:
                    if o==sh:o.rotation_euler.y+=(1 if sh.name.endswith('L') else -1)*kick*.30
            for path in ('location','rotation_euler','scale'):o.keyframe_insert(data_path=path,frame=f,group=o.name)
        # Exact final sample closes seamless clips / returns Attack to rest.
        o.location=loc; o.rotation_euler=rot; o.scale=scale
        for path in ('location','rotation_euler','scale'):o.keyframe_insert(data_path=path,frame=length,group=o.name)
        act=o.animation_data.action; act.name=name+'_'+o.name; act['loop']=loop
        # LINEAR keys deliberately avoid overshoot; dense keys preserve the smooth gait/recoil.
        for layer in act.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for fc in bag.fcurves:
                        for kp in fc.keyframe_points:kp.interpolation='LINEAR'
        track=o.animation_data.nla_tracks.new(); track.name=name
        strip=track.strips.new(name,1,act); strip.name=name
        strip.action_frame_start=1;strip.action_frame_end=length;strip.frame_start=1;strip.frame_end=length
        o.animation_data.action=None
for name,length,loop in [('Idle',61,True),('Walk',31,True),('Swim',31,True),('Attack',25,False)]:clip(name,length,loop)
# Mute animation in packed Blender rest pose; exporter reads NLA data regardless of viewport evaluation.
for o in animated:
    for tr in o.animation_data.nla_tracks:tr.mute=True
    loc,rot,sc=rests[o.name];o.location=loc;o.rotation_euler=rot;o.scale=sc
scene.frame_set(1); bpy.context.view_layer.update()
# Unmute just before export, disable evaluation via influence=0 is not necessary: frame 1 uses resting transforms.
for o in animated:
    for tr in o.animation_data.nla_tracks:tr.mute=False
scene.frame_set(1)
root['asset']='Kiln Lobber';root['forward']='+Y';root['units']='metres';root['animation_loop_clips']='Idle,Walk,Swim'
# Packed source and export are self-contained; generated PNGs also accompany them for review.
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'eco_lobber.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'eco_lobber.glb'),export_format='GLB',export_yup=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_cameras=False,export_lights=False,export_extras=True)
print('BUILD COMPLETE',len([o for o in scene.objects if o.type=='MESH']),'rigid mesh assemblies')
