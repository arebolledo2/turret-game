"""Brass Ram: procedural armored beetle, authored in metres with +Y forward."""
from pathlib import Path
import json, math
import bpy, bmesh
import numpy as np
from mathutils import Vector

OUT = Path(__file__).parent
bpy.ops.wm.read_factory_settings(use_empty=True)
TAU = math.tau

# Shared palette atlas: enamel, machined brass, blackened mechanics, steel,
# amber glass and verdigris indicator. No externally sourced images.
N = 1024
y, x = np.mgrid[0:N, 0:N]
rng = np.random.default_rng(74)
palette = [(0.92,.58,.17),(.41,.021,.054),(.025,.031,.043),(.31,.37,.43),(.97,.36,.015),(.015,.38,.40),(.98,.74,.32),(.22,.092,.024)]
roughs = [.28,.25,.42,.24,.17,.24,.25,.39]
rgba = np.ones((N,N,4),np.float32)
rr = np.ones((N,N,4),np.float32)
grain = rng.random((N,N))
for i,col in enumerate(palette):
    mask = (y//128)==i
    # Fine brushed grain plus broad low-amplitude surface variation.
    finish = .95 + .035*np.sin(x*.12+y*.024)+.025*np.sin(x*.019+y*.035)+.018*(grain-.5)
    rgba[mask,:3] = np.clip(np.array(col)[None,:]*finish[mask,None],0,1)
    rr[mask,:3] = (roughs[i]+.025*(grain[mask,None]-.5))
def image(name, pixels, space):
    im=bpy.data.images.new(name,width=N,height=N,alpha=False)
    im.colorspace_settings.name=space
    im.pixels.foreach_set(pixels.ravel())
    im.filepath_raw=str(OUT/(name+'.png')); im.file_format='PNG'; im.save(); im.pack()
    return im
atlas=image('ram_surface_color',rgba,'sRGB')
rough=image('ram_surface_roughness',rr,'Non-Color')
mats=[]
for i,name in enumerate(['Forged Brass','Oxblood Enamel','Graphite Mechanism','Polished Steel','Amber Optics','Teal Sensor','Pale Brass Edges','Dark Bronze']):
    mat=bpy.data.materials.new(name); mat.use_nodes=True
    bs=mat.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*palette[i],1)
    bs.inputs['Metallic'].default_value=[.56,.26,.68,.86,.1,.3,.60,.68][i]
    bs.inputs['Roughness'].default_value=roughs[i]
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=atlas
    mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    rt=mat.node_tree.nodes.new('ShaderNodeTexImage');rt.image=rough
    mat.node_tree.links.new(rt.outputs['Color'],bs.inputs['Roughness'])
    if i in (4,5):
        bs.inputs['Emission Color'].default_value=(*palette[i],1)
        bs.inputs['Emission Strength'].default_value=.9 if i==4 else .4
    mat.diffuse_color=(*palette[i],1); mats.append(mat)
gold,red,iron,steel,amber,teal,pale,bronze=mats
groups={}
def empty(name,pos=(0,0,0),parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o)
    o.parent=parent;o.location=pos
    return o
root=empty('Root')
body=empty('Body',(0,0,.80),root)
def parent_world(o,p):
    bpy.context.view_layer.update();world=o.matrix_world.copy();o.parent=p;o.matrix_world=world
def finish(o,name,mat,p):
    o.name=name
    # Dominant-axis projection in metres, same density for all components.
    uv=o.data.uv_layers.active or o.data.uv_layers.new(name='SurfaceUV')
    uv.name='SurfaceUV'
    band=mats.index(mat)
    for f in o.data.polygons:
        axis=max(range(3),key=lambda a:abs(f.normal[a]))
        for li in f.loop_indices:
            v=o.data.vertices[o.data.loops[li].vertex_index].co
            u,w=[(v.y,v.z),(v.x,v.z),(v.x,v.y)][axis]
            uv.data[li].uv=((u*1.8)%1, (band+.18+.64*((w*1.8)%1))/8)
    o.data.materials.append(mat)
    parent_world(o,p);groups.setdefault(p,[]).append(o)
    return o
def smooth(o):
    for f in o.data.polygons:f.use_smooth=True
def bevel(o,w=.018,segments=2):
    mod=o.modifiers.new('Rounded forged edges','BEVEL');mod.width=w;mod.segments=segments
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
def sphere(name,pos,scale,mat,p=body,seg=16,rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,radius=1,location=pos)
    o=bpy.context.object;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    smooth(o);return finish(o,name,mat,p)
def box(name,pos,scale,mat,p=body,w=.022):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);bevel(o,w)
    return finish(o,name,mat,p)
def cylinder(name,a,b,r,mat,p=body,vertices=14,r2=None):
    av,bv=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=r if r2 is None else r2,depth=(bv-av).length,location=(av+bv)*.5)
    o=bpy.context.object;o.rotation_euler=(bv-av).to_track_quat('Z','Y').to_euler()
    bevel(o,min(.012,r*.12),1);smooth(o);return finish(o,name,mat,p)
def tube(name,pts,radii,mat,p=body,sides=10):
    vertices=[];faces=[]
    for i,(pt,r) in enumerate(zip(pts,radii)):
        tangent=Vector(pts[min(i+1,len(pts)-1)])-Vector(pts[max(i-1,0)])
        tangent.normalize();ax=tangent.cross(Vector((0,1,0)))
        if ax.length<.001:ax=tangent.cross(Vector((1,0,0)))
        ax.normalize();ay=tangent.cross(ax).normalized()
        for j in range(sides):vertices.append(Vector(pt)+r*(ax*math.cos(TAU*j/sides)+ay*math.sin(TAU*j/sides)))
    for i in range(len(pts)-1):
        for j in range(sides):
            a=i*sides+j;b=i*sides+(j+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces.extend([tuple(range(sides-1,-1,-1)),tuple(range((len(pts)-1)*sides,len(pts)*sides))])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);smooth(o)
    return finish(o,name,mat,p)
def plate(name,outline,thickness,mat,p=body):
    # Front-facing polygon plate, extrusion along Y.
    verts=[(a,b+d,c) for d in (-thickness*.5,thickness*.5) for a,b,c in outline];n=len(outline)
    faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);bevel(o,.012,2)
    return finish(o,name,mat,p)
def hoof(name,pos,p):
    # Rounded brass cloven armor with a flat sole and a continuous domed toe.
    verts=[];faces=[];sides=14;rings=5
    for k in range(rings):
        phi=(math.pi/2)*k/rings;radius=math.cos(phi)
        for j in range(sides):
            a=TAU*j/sides
            verts.append((pos[0]+.071*radius*math.cos(a),pos[1]+.139*radius*math.sin(a),.025+.136*math.sin(phi)))
    for k in range(rings-1):
        for j in range(sides):
            a=k*sides+j;b=k*sides+(j+1)%sides;faces.append((a,b,b+sides,a+sides))
    tip=len(verts);verts.append((pos[0],pos[1],.161))
    for j in range(sides):faces.append(((rings-1)*sides+j,(rings-1)*sides+(j+1)%sides,tip))
    faces.append(tuple(range(sides-1,-1,-1)))
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);smooth(o)
    return finish(o,name,gold,p)

# Broad beetle abdomen with exposed chassis below the overlapping shell.
sphere('Chassis',(0,-.07,.77),(.55,.63,.40),iron)
sphere('Lower belly',(0,-.06,.66),(.49,.56,.29),red)
sphere('Brass shell substrate',(0,-.12,.98),(.61,.62,.30),gold,seg=32,rings=16)
# Sculpted elytra, curved burgundy inset surfaces bordered by heavy brass rails.
def shell_panel(s):
    # Ellipsoidal elytra conform to the actual abdomen, offset above its brass.
    def point(u,v):
        theta=.79+.68*u;phi=-.1+1.05*v
        return Vector((s*.635*math.cos(phi)*math.sin(theta),-.12+.647*math.sin(phi),.98+.335*math.cos(phi)*math.cos(theta)))
    points=[point(math.cos(TAU*j/32),math.sin(TAU*j/32)) for j in range(32)]
    verts=[point(0,0)];faces=[]
    for ring in range(1,7):
        q=ring/6
        for j in range(32):verts.append(point(q*math.cos(TAU*j/32),q*math.sin(TAU*j/32)))
    for j in range(32):faces.append((0,1+j,1+(j+1)%32))
    for ring in range(5):
        off=1+ring*32
        for j in range(32):faces.append((off+j,off+32+j,off+32+(j+1)%32,off+(j+1)%32))
    if s==1:faces=[tuple(reversed(f)) for f in faces]
    me=bpy.data.meshes.new('Enamel shield');me.from_pydata(verts,[],faces);me.update()
    o=bpy.data.objects.new('Oxblood wing shield',me);bpy.context.collection.objects.link(o);smooth(o);finish(o,o.name,red,body)
    tube('Thick brass wing rim',points+[points[0]],[.030]*33,pale)
    # A long central border and an inset horizontal rib make panels unmistakable.
    for frac in (-.35,.36):
        pts=[point(q,frac) for q in np.linspace(-math.sqrt(1-frac*frac),math.sqrt(1-frac*frac),11)]
        tube('Armored shield division',pts,[.014]*11,gold,sides=8)
    for yy in (-.48,.13):
        sphere('Wing fastener',(s*.40,yy,1.145),(.031,.031,.025),pale,seg=12,rings=6)
for s in (-1,1):shell_panel(s)
tube('Dorsal golden keel',[(0,-.68,.99),(0,-.52,1.17),(0,-.19,1.29),(0,.10,1.27)],[.034]*4,pale,sides=12)
# Belly banding and rear machinery.
for z,rrad in ((.58,.45),(.72,.52)):
    pts=[(rrad*math.cos(TAU*j/40),-.07+.55*math.sin(TAU*j/40),z) for j in range(41)]
    tube('Belly brass seam',pts,[.015]*41,gold,sides=8)
for s in (-1,1):
    cylinder('Rear exhaust', (s*.25,-.56,.64),(s*.25,-.68,.73),.105,bronze)
    cylinder('Rear exhaust dark opening',(s*.25,-.672,.727),(s*.25,-.69,.745),.072,iron)
    for k in range(3):box('Rear vent', (s*(.10+k*.08),-.677,.97),(.043,.024,.105),iron,w=.006)

# Insect head is integrated into the armored front, no separate snout or ears.
sphere('Head gasket',(0,.43,.96),(.44,.22,.33),iron)
sphere('Head armor dome',(0,.49,1.02),(.405,.18,.305),gold,seg=28,rings=14)
for s in (-1,1):
    # Eyes deeply inset with ring-shaped gold apertures and black sockets.
    sphere('Recessed optic socket',(s*.235,.621,1.015),(.139,.052,.129),iron)
    sphere('Warm amber lens',(s*.235,.664,1.015),(.097,.033,.089),amber,seg=24,rings=12)
    sphere('Lens highlight',(s*.217,.692,1.046),(.028,.009,.025),pale,seg=12,rings=6)
    pts=[(s*.235+.120*math.cos(TAU*j/28),.658,1.015+.112*math.sin(TAU*j/28)) for j in range(29)]
    tube('Eye brass retaining ring',pts,[.010]*29,bronze,sides=8)
    # Side bearing and amber cheek indicator.
    cylinder('Temple boss',(s*.365,.50,.968),(s*.426,.50,.968),.105,gold)
    cylinder('Temple bearing',(s*.421,.50,.968),(s*.446,.50,.968),.058,steel)
    cylinder('Temple bearing core',(s*.444,.50,.968),(s*.451,.50,.968),.025,iron,vertices=12)
    plate('Angular brow',[(s*.04,.68,1.115),(s*.12,.68,1.24),(s*.35,.65,1.20),(s*.385,.64,1.085),(s*.24,.69,1.075)],.05,pale)
    # Short paired mandibles: heavy tapered beetle pincers, deliberately insectlike.
    tube('Lower mandible',[(s*.255,.605,.825),(s*.27,.71,.77),(s*.22,.75,.715),(s*.16,.735,.77)],[.062,.051,.030,.006],gold,sides=12)
    sphere('Mandible hinge',(s*.255,.605,.83),(.078,.046,.07),bronze,seg=16,rings=8)
plate('Central layered forehead', [(-.16,.669,1.255),(0,.704,1.33),(.16,.669,1.255),(.105,.71,1.092),(0,.736,1.045),(-.105,.71,1.092)],.06,gold)
plate('Central forehead inset',[(-.064,.741,1.253),(0,.756,1.292),(.064,.741,1.253),(.03,.767,1.15),(0,.776,1.123),(-.03,.767,1.15)],.012,pale)
plate('Jaw guard',[(-.19,.644,.85),(-.13,.719,.91),(.13,.719,.91),(.19,.644,.85),(.115,.681,.78),(-.115,.681,.78)],.045,gold)
for i in range(5):box('Insect mouth grille',((i-2)*.038,.714,.806),(.024,.017,.033),iron,w=.004)
# Chest inset and a proud central breastplate, with exposed side bolts.
plate('Chest shield',[(-.37,.47,.73),(-.27,.568,.60),(0,.61,.50),(.27,.568,.60),(.37,.47,.73),(0,.585,.77)],.032,red)
tube('Chest top border',[(-.37,.491,.73),(-.20,.58,.76),(0,.615,.77),(.20,.58,.76),(.37,.491,.73)],[.022]*5,pale,sides=10)
plate('Chest clasp',[(-.061,.623,.66),(.061,.623,.66),(.044,.634,.57),(0,.64,.54),(-.044,.634,.57)],.022,gold)
cylinder('Chest seal',(0,.655,.614),(0,.667,.614),.033,steel,vertices=16)
for s in (-1,1):
    for yy,zz in ((.35,.84),(.12,.57),(-.31,.57)):
        cylinder('Armor bolt',(s*.505,yy,zz),(s*.524,yy,zz),.023,pale,vertices=10)
    # Teal hip pressure gauge visible between carapace and rear legs.
    cylinder('Pressure gauge rim',(s*.57,-.35,.75),(s*.624,-.35,.75),.094,bronze)
    cylinder('Pressure gauge inset',(s*.623,-.35,.75),(s*.633,-.35,.75),.057,teal)

# Enormous swept horns: rings follow a continuous taper with forged root collars.
horns=[]
for s,label in ((-1,'L'),(1,'R')):
    pivot=empty('Horn_'+label,(s*.315,.28,1.235),body)
    # Convert desired world pivot to Body's local coordinates.
    pivot.location=(s*.315,.28,.435)
    horns.append(pivot)
    pts=[];rs=[]
    for j in range(17):
        t=j/16
        # Sinuous upward/outward curve ending in a sharp hooked inward tip.
        xx=s*(.315+.37*math.sin(t*math.pi)-.06*t)
        yy=.27+.095*t+.035*math.sin(t*math.pi)
        zz=1.14+.51*t+.14*math.sin(math.pi*t)
        pts.append((xx,yy,zz));rs.append(.145*(1-t)**.85+.0015)
    tube('Sweeping brass horn',pts,rs,gold,pivot,sides=16)
    for j in range(2,15,2):
        pt=Vector(pts[j]);ta=(Vector(pts[j+1])-Vector(pts[j-1])).normalized()
        ex=ta.cross(Vector((0,1,0))).normalized();ey=ta.cross(ex)
        radius=rs[j]*(1.024 if j%3 else 1.045)
        ring=[pt+radius*(ex*math.cos(TAU*k/16)+ey*math.sin(TAU*k/16)) for k in range(17)]
        tube('Forged horn ridge',ring,[.004]*17,pale,pivot,sides=5)
    cylinder('Horn dark root',pts[0],pts[1],.151,bronze,pivot)
    cylinder('Horn brass root trim',Vector(pts[0])-.012*(Vector(pts[1])-Vector(pts[0])).normalized(),pts[0],.162,pale,pivot)

# Four piston legs; each ankle and knee has its own rigid pivot.
legs=[]
for s,side in ((-1,'L'),(1,'R')):
    for index,yy in enumerate((.37,-.39)):
        hip=Vector((s*.46,yy,.64));knee=Vector((s*.635,yy+.015,.39));ankle=Vector((s*.64,yy+.025,.15))
        pivot=empty(f'Leg_{side}_{index}',hip,root)
        knee_p=empty(f'Knee_{side}_{index}',knee-hip,pivot)
        ankle_p=empty(f'Ankle_{side}_{index}',ankle-knee,knee_p)
        legs.append((pivot,knee_p,ankle_p,index,s))
        cylinder('Hip black bearing',(s*.415,yy,.64),(s*.60,yy,.64),.135,iron,pivot)
        cylinder('Hip brass surround',(s*.54,yy,.64),(s*.602,yy,.64),.113,bronze,pivot)
        cylinder('Hip polished hub',(s*.601,yy,.64),(s*.626,yy,.64),.073,steel,pivot)
        cylinder('Upper piston shroud',hip,knee,.126,gold,pivot,r2=.144)
        # Thick front cover adds the asymmetrical forged silhouette of the reference.
        sphere('Upper shin armor',(s*.62,yy+.05,.454),(.15,.143,.18),gold,pivot,seg=20,rings=10)
        cylinder('Knee black axle',(s*.515,yy+.015,.39),(s*.755,yy+.015,.39),.094,iron,knee_p)
        cylinder('Knee brass hub',(s*.71,yy+.015,.39),(s*.766,yy+.015,.39),.072,gold,knee_p)
        cylinder('Knee steel fastener',(s*.766,yy+.015,.39),(s*.779,yy+.015,.39),.042,steel,knee_p,vertices=12)
        cylinder('Exposed steel piston',knee,ankle,.067,steel,knee_p)
        cylinder('Lower piston housing',knee-Vector((0,0,.05)),ankle,.112,gold,knee_p,r2=.145)
        cylinder('Lower piston rim',(s*.64,yy+.025,.18),(s*.64,yy+.025,.135),.153,pale,knee_p)
        # Dark mechanical seam, broad flat-soled cloven machine foot.
        sphere('Foot dark bellows',(s*.64,yy+.025,.14),(.144,.17,.091),iron,ankle_p,seg=20,rings=8)
        for toe in (-1,1):
            hoof('Armored cloven foot',(s*.64+toe*.077,yy+.087),ankle_p)
        box('Sole',(s*.64,yy+.075,.022),(.293,.259,.04),iron,ankle_p,w=.012)
        # Visible shin facings and a small oxblood knee panel.
        o=box('Knee enamel plate',(s*.64,yy+.150,.405),(.181,.024,.10),red,knee_p,w=.02)
        cylinder('Front shin bolt',(s*.64,yy+.14,.245),(s*.64,yy+.169,.245),.036,steel,knee_p,vertices=12)

# Merge all stationary geometry sharing each rigid pivot, retaining material slots.
for p,parts in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    bpy.ops.object.join();o=bpy.context.object;o.name=p.name+'_Geometry'
    # Use exact pivot origins for compact transform channels.
    bpy.context.scene.cursor.location=p.matrix_world.translation
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')

bpy.context.scene.render.fps=30
animated=[body]+horns+[o for leg in legs for o in leg[:3]]
base={o:(o.location.copy(),o.rotation_euler.copy()) for o in animated}
durations={'Idle':60,'Walk':30,'Swim':48,'Attack':30}
for clip,end in durations.items():
    for o in animated:
        if clip=='Idle':o.animation_data_clear()
        o.location=base[o][0];o.rotation_euler=base[o][1]
    for frame in range(0,end+1,3):
        t=frame/end;wave=math.sin(TAU*t)
        body.rotation_euler=(.009*wave,0,.008*math.sin(TAU*t)) if clip=='Idle' else (0,0,0)
        body.location=base[body][0]
        if clip=='Walk':body.rotation_euler=(.025*wave,0,.025*wave)
        if clip=='Swim':body.rotation_euler=(.055*wave,.025*wave,0)
        pulse=math.sin(math.pi*t)**2
        if clip=='Attack':
            body.rotation_euler.x=-.25*pulse
            body.location.z-=.047*pulse
        for hi,knee,foot,index,s in legs:
            phase=TAU*t+math.pi*(index+(s==1))
            hi.rotation_euler=(0,0,0);knee.rotation_euler=(0,0,0);foot.rotation_euler=(0,0,0)
            if clip=='Idle':
                hi.rotation_euler.x=.008*math.sin(phase);knee.rotation_euler.x=-hi.rotation_euler.x
            elif clip in ('Walk','Swim'):
                amp=.19 if clip=='Walk' else .29
                hi.rotation_euler.x=amp*math.sin(phase)
                hi.rotation_euler.y=s*.025*(1-math.cos(phase))
                knee.rotation_euler.x=-.16*math.sin(phase)+.085*(1-math.cos(phase))
                foot.rotation_euler.x=-hi.rotation_euler.x-knee.rotation_euler.x
            elif clip=='Attack':
                hi.rotation_euler.x=(-.12 if index==0 else .16)*pulse
                knee.rotation_euler.x=.15*pulse
                foot.rotation_euler.x=-hi.rotation_euler.x-knee.rotation_euler.x
        for h in horns:h.rotation_euler=(0,0,0)
        if clip=='Attack':
            for h in horns:h.rotation_euler.x=-.075*pulse
        for o in animated:
            o.keyframe_insert(data_path='location',frame=frame,group=o.name)
            o.keyframe_insert(data_path='rotation_euler',frame=frame,group=o.name)
    for o in animated:
        act=o.animation_data.action;act.name=clip+'_'+o.name
        track=o.animation_data.nla_tracks.new();track.name=clip
        strip=track.strips.new(clip,0,act);strip.action_frame_start=0;strip.action_frame_end=end
        o.animation_data.action=None
        track.mute=True
# Restore neutral transform for export and evaluation. NLA tracks stay muted in
# authored blend but the exporter emits named animation groups from all tracks.
for o in animated:o.location=base[o][0];o.rotation_euler=base[o][1]
bpy.context.scene.frame_set(0)
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'eco_ram.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'eco_ram.glb'),export_format='GLB',export_yup=True,
    export_animations=True,export_animation_mode='NLA_TRACKS',export_frame_range=False,
    export_force_sampling=True,export_cameras=False,export_lights=False)
print('RAM_EXPORT_COMPLETE')
