"""Skyfall Kestrel: procedural enamel toy bomber, rigid transform animation."""
import bpy, bmesh, math, json
import numpy as np
from mathutils import Vector
from pathlib import Path
OUT=Path(__file__).parent
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
scene.render.fps=30
COLORS=[(0.78,.032,.023),(.96,.84,.58),(.14,.19,.24),(.28,.33,.39),(.83,.48,.055),(.015,.56,.66),(.36,.86,.008),(.028,.038,.05),(.85,.13,.072),(.74,.83,.86),(.36,.20,.07),(.08,.25,.32)]
names=['Vermilion enamel','Warm cream enamel','Gunmetal rubber','Machined turbine alloy','Golden brass','Cockpit turquoise','Lime indicators','Deep intake charcoal','Red panel highlight','Pale steel','Brass shadow','Glass recess']
SIZE=1024
yy,xx=np.mgrid[0:SIZE,0:SIZE]
gx=np.minimum(xx*3//SIZE,2); gy=np.minimum(yy*4//SIZE,3); ids=gy*3+gx
u=(xx*3/SIZE)%1; v=(yy*4/SIZE)%1
rng=np.random.default_rng(42)
grain=rng.normal(0,.0025,(SIZE,SIZE))
sheen=.975+.018*np.sin(u*math.tau)+.008*np.cos(v*math.tau)+grain
def img(name,pixels,linear=False):
    im=bpy.data.images.new(name,SIZE,SIZE,alpha=False)
    im.colorspace_settings.name='Non-Color' if linear else 'sRGB'
    im.pixels.foreach_set(np.asarray(pixels,np.float32).ravel())
    im.filepath_raw=str(OUT/(name+'.png')); im.file_format='PNG'; im.save(); im.pack()
    return im
rgba=np.ones((SIZE,SIZE,4)); rgba[:,:,:3]=np.asarray(COLORS)[ids]*sheen[:,:,None]
ALBEDO=img('kestrel_enamel_atlas',rgba)
orm=np.ones((SIZE,SIZE,4)); orm[:,:,1]=np.array([.31,.31,.37,.33,.23,.17,.21,.5,.31,.3,.36,.36])[ids]+grain
orm[:,:,2]=np.array([.02,.04,.38,.74,.74,.26,.1,.3,.02,.6,.6,.35])[ids]
ORM=img('kestrel_surface_atlas',orm,True)
normal=np.ones((SIZE,SIZE,4)); normal[:,:,0]=.5+grain*.1; normal[:,:,1]=.5+grain*.1; normal[:,:,2]=1
NORMAL=img('kestrel_micro_normal',normal,True)
em=np.ones((SIZE,SIZE,4)); em[:,:,:3]=0
for idx in (5,6): em[ids==idx,:3]=np.asarray(COLORS[idx])*.6
EMISSION=img('kestrel_lens_atlas',em)
mats=[]
for i,name in enumerate(names):
    m=bpy.data.materials.new(name); m.diffuse_color=(*COLORS[i],1); m.use_nodes=True
    n=m.node_tree.nodes; l=m.node_tree.links; bs=n.get('Principled BSDF')
    if i in (0,1,8): bs.inputs['Specular IOR Level'].default_value=.24
    t=n.new('ShaderNodeTexImage'); t.image=ALBEDO; l.new(t.outputs['Color'],bs.inputs['Base Color'])
    t=n.new('ShaderNodeTexImage'); t.image=ORM; sep=n.new('ShaderNodeSeparateColor'); l.new(t.outputs['Color'],sep.inputs['Color']); l.new(sep.outputs['Green'],bs.inputs['Roughness']); l.new(sep.outputs['Blue'],bs.inputs['Metallic'])
    t=n.new('ShaderNodeTexImage'); t.image=NORMAL; norm=n.new('ShaderNodeNormalMap'); norm.inputs['Strength'].default_value=.08; l.new(t.outputs['Color'],norm.inputs['Color']); l.new(norm.outputs['Normal'],bs.inputs['Normal'])
    if i in (5,6):
        t=n.new('ShaderNodeTexImage'); t.image=EMISSION; l.new(t.outputs['Color'],bs.inputs['Emission Color']); bs.inputs['Emission Strength'].default_value=.25
    mats.append(m)
def empty(name,pos,parent=None):
    o=bpy.data.objects.new(name,None); scene.collection.objects.link(o); o.parent=parent; o.location=pos; return o
Body=empty('Body',(0,0,0)); EngineL=empty('Engine_L',(-1.02,.31,.65),Body); EngineR=empty('Engine_R',(1.02,.31,.65),Body)
Bay=empty('BombBay',(0,.48,.46),Body)
def finish(o,name,mi,parent=Body):
    o.name=name; o.data.materials.append(mats[mi]); o.parent=parent
    if parent:
        o.location-=parent.location
    uv=o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap')
    for p in o.data.polygons:
        axis=max(range(3),key=lambda j:abs(p.normal[j])); axes=[j for j in range(3) if j!=axis]
        for li in p.loop_indices:
            co=o.data.vertices[o.data.loops[li].vertex_index].co
            a=co[axes[0]]*.52+.5; b=co[axes[1]]*.52+.5
            # Padded atlas tiles and the same coordinate density on all parts.
            uv.data[li].uv=((mi%3+.09+.82*(a%1))/3,(mi//3+.09+.82*(b%1))/4)
    return o
def bevel(o,w=.03,segments=3):
    mod=o.modifiers.new('Rounded enamel edges','BEVEL'); mod.width=w; mod.segments=segments
    bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=mod.name)
    o.data.shade_smooth()
    mod=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL'); mod.keep_sharp=True; mod.weight=30
    try: bpy.ops.object.modifier_apply(modifier=mod.name)
    except Exception: pass
    return o
def box(name,pos,size,mi,rad=.035,parent=Body):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos); o=bpy.context.object; o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); bevel(o,rad)
    return finish(o,name,mi,parent)
def sphere(name,pos,size,mi,parent=Body,seg=24,rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,radius=1,location=pos); o=bpy.context.object; o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.shade_smooth(); return finish(o,name,mi,parent)
def cyl(name,pos,radius,depth,mi,parent=Body,axis='Y',verts=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=radius,depth=depth,location=pos); o=bpy.context.object
    bevel(o,min(.012,depth*.17,radius*.12),2)
    if axis=='Y': o.rotation_euler[0]=math.pi/2
    elif axis=='X': o.rotation_euler[1]=math.pi/2
    return finish(o,name,mi,parent)
def torus(name,pos,major,minor,mi,parent=Body):
    bpy.ops.mesh.primitive_torus_add(major_radius=major,minor_radius=minor,major_segments=32,minor_segments=8,location=pos,rotation=(math.pi/2,0,0))
    o=bpy.context.object; o.data.shade_smooth(); return finish(o,name,mi,parent)
def mesh(name,vs,fs,mi,parent=Body,rad=.025):
    me=bpy.data.meshes.new(name); me.from_pydata(vs,[],fs); me.update()
    bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free()
    o=bpy.data.objects.new(name,me); scene.collection.objects.link(o)
    if rad: bevel(o,rad,3)
    return finish(o,name,mi,parent)
def prism(name,coords,z,thick,mi,rad=.025):
    vs=[(x,y,z+dz) for dz in (-thick/2,thick/2) for x,y in coords]; n=len(coords)
    fs=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,vs,fs,mi,rad=rad)
def line(name,points,radius,mi,parent=Body):
    curve=bpy.data.curves.new(name,'CURVE'); curve.dimensions='3D'; curve.bevel_depth=radius; curve.bevel_resolution=2; curve.resolution_u=1
    s=curve.splines.new('POLY'); s.points.add(len(points)-1)
    for p,co in zip(s.points,points): p.co=(*co,1)
    o=bpy.data.objects.new(name,curve); scene.collection.objects.link(o); bpy.context.view_layer.objects.active=o; o.select_set(True); bpy.ops.object.convert(target='MESH'); o=bpy.context.object; o.select_set(False); return finish(o,name,mi,parent)
def rounded_front(name,pos,width,height,depth,radius,mi):
    x,y,z=pos; ring=[]
    for cx,cz,start in [(width/2-radius,height/2-radius,0),(-width/2+radius,height/2-radius,90),(-width/2+radius,-height/2+radius,180),(width/2-radius,-height/2+radius,270)]:
        for j in range(7):
            a=math.radians(start+j*15)
            ring.append((x+cx+radius*math.cos(a),z+cz+radius*math.sin(a)))
    vv=[(px,y+dy,pz) for dy in (-depth/2,depth/2) for px,pz in ring]; n=len(ring)
    fs=[tuple(range(n-1,-1,-1))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    if mi==5:
        prev=n
        for scale in (.75,.45,.15):
            base=len(vv)
            vv.extend((x+(px-x)*scale,y+depth/2+.027*(1-scale*scale),z+(pz-z)*scale) for px,pz in ring)
            fs.extend((prev+i,prev+(i+1)%n,base+(i+1)%n,base+i) for i in range(n)); prev=base
        vv.append((x,y+depth/2+.027,z)); centre=len(vv)-1
        fs.extend((prev+i,prev+(i+1)%n,centre) for i in range(n))
        o=mesh(name,vv,fs,mi,rad=0); o.data.shade_smooth(); return o
    fs.append(tuple(range(n,n*2)))
    return mesh(name,vv,fs,mi,rad=.005)
# The fuselage tapers toward the tall stabilizer while keeping a rounded-square front.
stations=[(-1.31,.16,.17,.99),(-1.09,.23,.22,.97),(-.8,.29,.27,.94),(-.42,.38,.34,.94),(.02,.445,.37,.92),(.48,.445,.37,.92),(.81,.36,.33,.94)]
vs=[]
for y,w,h,z in stations:
    for j in range(24):
        a=math.tau*j/24; co=math.cos(a); si=math.sin(a)
        vs.append((w*math.copysign(abs(co)**.68,co),y,z+h*math.copysign(abs(si)**.68,si)))
fs=[tuple(range(23,-1,-1)),tuple(range((len(stations)-1)*24,len(stations)*24))]
for k in range(len(stations)-1):
    for j in range(24): fs.append((k*24+j,k*24+(j+1)%24,(k+1)*24+(j+1)%24,(k+1)*24+j))
mesh('Rounded tapered red fuselage',vs,fs,0,rad=0).data.shade_smooth()
box('Cream armored nose',(0,.73,.97),(.86,.64,.78),1,.185)
box('Lower red bumper',(0,.92,.625),(.79,.28,.21),0,.075)
box('Bomb bay socket',(0,.64,.45),(.71,.57,.16),7,.055)
# Window is a layered rounded square; the raised gold edging is thicker than the recess.
rounded_front('Cockpit gold surround',(0,1.052,1.005),.69,.465,.065,.105,4)
rounded_front('Cockpit deep inset',(0,1.091,1.015),.604,.377,.030,.085,11)
rounded_front('Cyan cockpit glazing',(0,1.11,1.022),.578,.351,.042,.079,5)
rounded_front('Window reflection',(-.105,1.156,1.118),.24,.042,.006,.02,9)
for x in (-.235,.235):
    sphere('Cockpit frame rivet',(x,1.097,.81),(.020,.013,.020),4,seg=12,rings=6)
# Cowling ridge above the nose, and familiar beacon / roof vent.
sphere('Red cockpit roof',(0,.34,1.265),(.39,.57,.155),0)
box('Roof beacon pedestal',(0,.1,1.396),(.20,.19,.025),3,.035)
cyl('Beacon socket',(0,.1,1.42),.065,.024,7,axis='Z')
sphere('Lime beacon',(0,.1,1.46),(.065,.065,.06),6)
cyl('Roof vent rim',(0,.44,1.383),.09,.024,3,axis='Z')
sphere('Roof dark ventilator',(0,.44,1.405),(.068,.068,.023),2)
# Broad beveled swept wings. Cream root paint is geometry flush over red enamel.
for s in (-1,1):
    wing=[(s*.30,.30),(s*1.63,.03),(s*1.72,-.14),(s*1.67,-.61),(s*1.45,-.70),(s*.32,-.44)]
    if s<0: wing.reverse()
    prism('Broad rounded wing',wing,1.16,.14,0,.06)
    stripe=[(s*.38,.273),(s*.60,.230),(s*.60,-.486),(s*.38,-.442)]
    if s<0: stripe.reverse()
    prism('Cream wing root stripe',stripe,1.235,.008,1,.004)
    # Parallel panel cuts follow the wing chords and trailing-edge control surface.
    for x in (.87,1.32):
        yfront=.30-(x-.30)*.203; yback=-.44-(x-.32)*.18
        line('Wing dark panel seam',[(s*x,yfront-.01,1.237),(s*x,yback+.03,1.237)],.008,2)
        line('Wing seam highlight',[(s*(x+.012),yfront-.02,1.239),(s*(x+.012),yback+.04,1.239)],.003,9)
    line('Trailing flap seam',[(s*.65,-.386,1.239),(s*1.53,-.574,1.239)],.005,10)
    for x in (1.0,1.14,1.48):
        line('Wing trim latch',[(s*x,-.54,1.24),(s*x,-.60,1.24)],.006,4)
    box('Engine mounting strut',(s*1.02,-.10,.94),(.11,.24,.29),4,.027)
    sphere('Turbine cream nacelle',(s*1.02,-.09,.65),(.26,.45,.255),1)
    cyl('Red turbine front cowling',(s*1.02,.235,.65),.269,.20,0)
    cyl('Machined front ring',(s*1.02,.356,.65),.268,.11,3)
    cyl('Intake dark aperture',(s*1.02,.418,.65),.209,.012,7)
    torus('Rounded alloy intake lip',(s*1.02,.427,.65),.225,.044,3)
    cyl('Turbine aft exhaust',(s*1.02,-.464,.65),.19,.065,2)
    torus('Exhaust rim',(s*1.02,-.497,.65),.17,.02,3)
    cyl('Exhaust core',(s*1.02,-.51,.65),.12,.018,7)
    pivot=EngineL if s<0 else EngineR
    for j in range(8):
        a=j*math.tau/8
        # Fans are distinct rigid geometry underneath their named runtime pivots.
        coords=[]
        for r,b in ((.084,a),(.195,a+.30),(.195,a+.64),(.094,a+.34)):
            coords.append((s*1.02+r*math.cos(b),.428,.65+r*math.sin(b)))
        vv=[(x,y+dy,z) for dy in (-.008,.008) for x,y,z in coords]
        mesh('Swept turbine blade',vv,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],2,pivot,rad=.005)
    sphere('Amber turbine spinner',(s*1.02,.453,.65),(.119,.098,.119),4,pivot)
    # Fine perimeter notches around the visible ring.
    for j in range(9):
        a=math.tau*j/9; x=s*1.02+.258*math.cos(a); z=.65+.258*math.sin(a)
        o=box('Radial intake engraving',(x,.410,z),(.004,.04,.028),2,.001); o.rotation_euler[1]=math.pi/2-a
    # Small green side indicators and gunmetal protective surrounds.
    o=box('Cream nose side bezel',(s*.425,.82,1.0),(.036,.17,.24),3,.039)
    o=box('Lime side navigation lamp',(s*.446,.82,1.01),(.03,.114,.167),6,.041)
    cyl('Brass body side port',(s*.444,.39,.91),.088,.028,4,axis='X')
    cyl('Lime body indicator',(s*.462,.39,.91),.061,.022,6,axis='X')
    box('Side cheek armor',(s*.402,-.05,.82),(.059,.38,.22),2,.035)
    line('Fuselage side seam',[(s*.423,-.18,.93),(s*.43,.20,.90)],.005,7)
# Cream aft band and broad horizontal stabilizers.
cyl('Tail cream band',(0,-.865,.973),.275,.12,1)
cyl('Tail brass band',(0,-.787,.973),.276,.017,4)
for s in (-1,1):
    coords=[(s*.10,-.98),(s*.61,-.95),(s*.68,-1.19),(s*.56,-1.29),(s*.10,-1.34)]
    if s<0: coords.reverse()
    prism('Red tailplane',coords,1.12,.085,0,.035)
    line('Tail elevator seam',[(s*.20,-1.235,1.167),(s*.57,-1.21,1.167)],.004,10)
# Swept upright fin with inset rudder panel and a single brass accent.
outline=[(-1.32,1.12),(-1.33,2.03),(-1.16,1.99),(-.80,1.18),(-.93,1.09)]
vs=[(x,y,z) for x in (-.055,.055) for y,z in outline]; n=len(outline)
mesh('Tall red vertical fin',vs,[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],0,rad=.03)
for s in (-1,1):
    line('Vertical rudder seam',[(s*.058,-1.235,1.93),(s*.058,-1.123,1.44),(s*.058,-1.17,1.19)],.005,10)
    line('Gold rudder accent',[(s*.059,-1.30,1.45),(s*.059,-1.123,1.40)],.009,4)
# Four exposed artillery rounds, each with a brass belt and rounded dark steel warhead.
for x,y,z in [(-.27,.78,.36),(-.09,.87,.34),(.09,.87,.34),(.27,.78,.36)]:
    cyl('Exposed artillery casing',(x,y,z),.094,.42,2,Bay)
    cyl('Artillery brass belt',(x,y+.09,z),.097,.045,4,Bay)
    sphere('Artillery rounded warhead',(x,y+.238,z),(.093,.104,.093),2,Bay)
    cyl('Rear shell brass rim',(x,y-.18,z),.095,.022,4,Bay)
for x in (-.32,0,.32): sphere('Nose bumper gold stud',(x,1.07,.62),(.044,.031,.044),4,seg=16,rings=8)
DoorL=empty('BayDoor_L',(-.35,-.03,.05),Bay); DoorR=empty('BayDoor_R',(.35,-.03,.05),Bay)
for s,p in ((-1,DoorL),(1,DoorR)):
    # Coordinates are relative to BombBay, including the separate hinge empty.
    o=box('Bomb bay red door',(s*.34,.48,.51),(.08,.55,.11),0,.025,parent=Bay)
    bpy.context.view_layer.update(); mw=o.matrix_world.copy(); o.parent=p; bpy.context.view_layer.update(); o.matrix_world=mw
# Combine meshes that move together, preserving material slots and UVs.
bpy.context.view_layer.update()
for par in (Body,EngineL,EngineR,Bay,DoorL,DoorR):
    children=[o for o in list(scene.objects) if o.type=='MESH' and o.parent==par]
    groups={}
    for o in children: groups.setdefault(o.data.materials[0].name,[]).append(o)
    for mat,group in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in group: o.select_set(True)
        bpy.context.view_layer.objects.active=group[0]
        if len(group)>1: bpy.ops.object.join()
        group[0].name=par.name+' | '+mat
        bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
# All clips animate real transform channels; NLA tracks merge the matching per-part actions.
rest={o:(o.location.copy(),o.rotation_euler.copy()) for o in (Body,EngineL,EngineR,Bay,DoorL,DoorR)}
def animate(name,duration):
    end=duration*30; frames=range(0,end+1,3)
    for o in rest:
        o.animation_data_create(); o.animation_data.action=None
        for f in frames:
            t=f/end; cyc=math.sin(t*math.tau); loc,rot=rest[o]; o.location=loc.copy(); o.rotation_euler=rot.copy()
            if o==Body:
                o.location.z+=cyc*(.025 if name=='Idle' else .045 if name in ('Walk','Swim') else .012)
                o.rotation_euler.x+=cyc*(.012 if name=='Idle' else .025)
                if name=='Swim': o.rotation_euler.y+=cyc*.04
            elif o in (EngineL,EngineR): o.rotation_euler.y+=(t*math.tau*(4 if name=='Idle' else 8))*(1 if o==EngineL else -1)
            elif name=='Attack':
                opening=math.sin(t*math.pi)**2
                if o==Bay: o.location.z-=.17*opening
                elif o==DoorL: o.rotation_euler.y-=.8*opening
                elif o==DoorR: o.rotation_euler.y+=.8*opening
            o.keyframe_insert(data_path='location',frame=f,group=o.name); o.keyframe_insert(data_path='rotation_euler',frame=f,group=o.name)
        act=o.animation_data.action; act.name=name+'_'+o.name
        track=o.animation_data.nla_tracks.new(); track.name=name; strip=track.strips.new(name,0,act); strip.name=name
        o.animation_data.action=None; track.mute=True
        o.location=rest[o][0].copy(); o.rotation_euler=rest[o][1].copy()
for n,d in [('Idle',2),('Walk',2),('Swim',2),('Attack',1)]: animate(n,d)
scene.frame_set(0)
for o,(loc,rot) in rest.items(): o.location=loc; o.rotation_euler=rot
bpy.context.view_layer.update()
# Save a packed editable source and a self-contained GLB with four named clips.
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_skyfall_kestrel.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_skyfall_kestrel.glb'),export_format='GLB',export_yup=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True,export_cameras=False,export_lights=False)
print('Kestrel export complete')
