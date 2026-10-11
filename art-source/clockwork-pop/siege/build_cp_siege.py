"""Clockwork siege cannon: self-contained rigid parts, +Y forward, metres."""
from pathlib import Path
import math
import json
import bpy
import bmesh
import numpy as np
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
OUT = Path(__file__).resolve().parent

def material(name, color, metallic=0, roughness=.34):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*color,1)
    bs.inputs['Metallic'].default_value=metallic
    bs.inputs['Roughness'].default_value=roughness
    return m

TEAL=material('Enamel jade teal',(.002,.31,.23),.05,.36)
LIGHT=material('Teal rounded trim',(.005,.56,.37),.04,.33)
CORAL=material('Coral enamel',(.94,.075,.025),.02,.34)
GOLD=material('Warm polished brass',(.90,.49,.045),.79,.24)
AGED=material('Brass recessed seams',(.40,.23,.028),.55,.35)
TIRE=material('Charcoal rubber',(.075,.095,.14),.0,.55)
HUB=material('Deep teal inset',(.025,.13,.18),.1,.4)
STEEL=material('Steel trunnion pins',(.40,.46,.53),.55,.3)
IVORY=material('Ivory artillery enamel',(.93,.82,.57),.1,.28)
BORE=material('Dark brass bore',(.21,.103,.018),.35,.43)

# Self-generated subtle warm metal streaks, kept broad enough for gameplay distance.
rng=np.random.default_rng(41)
yy,xx=np.mgrid[0:128,0:256]
grain=(.95+.025*np.sin(yy*.54)+.018*np.sin(yy*.19+xx*.026)+rng.normal(0,.008,(128,256)))
rgba=np.ones((128,256,4),dtype=np.float32)
rgba[:,:,:3]=np.clip(grain[:,:,None]*np.array([.95,.70,.23])[None,None,:],0,1)
im=bpy.data.images.new('generated_brushed_brass',width=256,height=128,alpha=True)
im.colorspace_settings.name='sRGB'; im.pixels.foreach_set(rgba.ravel())
im.filepath_raw=str(OUT/'brushed_brass.png'); im.file_format='PNG'; im.save(); im.pack()
nodes=GOLD.node_tree.nodes; links=GOLD.node_tree.links
tex=nodes.new('ShaderNodeTexImage'); tex.image=im
links.new(tex.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color'])

def empty(name,location=(0,0,0),parent=None):
    o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o)
    o.location=location; o.parent=parent; return o

def finish(o,name,mat,parent=None):
    o.name=name; o.data.materials.append(mat)
    if parent:
        mw=o.matrix_world.copy(); o.parent=parent; o.matrix_world=mw
    return o

def smooth(o):
    bm=bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
    for face in bm.faces: face.smooth=True
    for edge in bm.edges:
        if len(edge.link_faces)==2 and edge.calc_face_angle(0)>math.radians(38): edge.smooth=False
    bm.to_mesh(o.data); bm.free()

def bevel(o,w=.02,segments=2):
    mod=o.modifiers.new('Soft manufactured edges','BEVEL'); mod.width=w; mod.segments=segments
    bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=mod.name)
    smooth(o); return o

def box(name,pos,size,mat,parent=None,rounding=.025):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos); o=bpy.context.object
    o.scale=size; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bevel(o,rounding,3); return finish(o,name,mat,parent)

def cylinder(name,pos,radius,depth,mat,parent=None,axis='Z',vertices=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=pos)
    o=bpy.context.object
    if axis=='X': o.rotation_euler[1]=math.pi/2
    if axis=='Y': o.rotation_euler[0]=math.pi/2
    bevel(o,min(.013,depth*.16),1); return finish(o,name,mat,parent)

def lathe(name,profile,pos,mats,parent=None,axis='Y',segments=48):
    # (axial coordinate,radius,material of outgoing strip), closed profile.
    vs=[]; fs=[]
    for a,r,_ in profile:
        for i in range(segments):
            u=math.tau*i/segments
            if axis=='Y': v=(r*math.cos(u),a,r*math.sin(u))
            elif axis=='X': v=(a,r*math.cos(u),r*math.sin(u))
            else: v=(r*math.cos(u),r*math.sin(u),a)
            vs.append(tuple(v[j]+pos[j] for j in range(3)))
    for k in range(len(profile)):
        nxt=(k+1)%len(profile)
        for i in range(segments): fs.append((k*segments+i,k*segments+(i+1)%segments,nxt*segments+(i+1)%segments,nxt*segments+i))
    me=bpy.data.meshes.new(name); me.from_pydata(vs,[],fs); me.update()
    o=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(o)
    for m in mats: me.materials.append(m)
    for p in me.polygons: p.material_index=profile[p.index//segments][2]
    uv=me.uv_layers.new(name='UVMap')
    amin=min(p[0] for p in profile); amax=max(p[0] for p in profile)
    for p in me.polygons:
        strip=p.index//segments; around=p.index%segments
        coords=[(profile[strip][0],around/segments),(profile[strip][0],(around+1)/segments),
                (profile[(strip+1)%len(profile)][0],(around+1)/segments),(profile[(strip+1)%len(profile)][0],around/segments)]
        for loop,(a,u) in zip(p.loop_indices,coords): uv.data[loop].uv=((a-amin)/max(amax-amin,.001),u)
    smooth(o)
    if parent:
        mw=o.matrix_world.copy(); o.parent=parent; o.matrix_world=mw
    return o

def join(parts,name,parent=None,origin=None):
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts: o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]; bpy.ops.object.join(); o=parts[0]; o.name=name
    if origin:
        bpy.context.scene.cursor.location=origin; bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    if parent:
        mw=o.matrix_world.copy(); o.parent=parent; o.matrix_world=mw
    return o

def side_plate(name,x,outline,mat):
    verts=[(x+dx,y,z) for dx in [-.075,.075] for y,z in outline]
    n=len(outline); faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.update()
    o=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(o)
    finish(o,name,mat); bevel(o,.035,3); return o

root=empty('SiegeRoot')
aim=empty('Aim',(0,0,.79),root)
recoil=empty('Barrel',(0,.065,1.025),aim)
# Pivots are world-located despite parent local transforms; preserve desired identity rotations.
aim.location=(0,0,.79)
recoil.location=(0,.065,.235)
muzzle=empty('Muzzle',(0,1.135,.235),aim)

# Static broad carriage, a low chassis with rounded nose, side walls and rear panel.
frame=[]
frame.append(box('Carriage chassis',(0,-.03,.385),(.96,1.25,.29),TEAL,rounding=.06))
frame.append(box('Front sill',(0,.49,.525),(.94,.17,.49),LIGHT,rounding=.045))
frame.append(box('Rear sill',(0,-.56,.54),(.94,.17,.37),LIGHT,rounding=.045))
for side in (-1,1):
    frame.append(box('Side rail',(side*.43,-.04,.61),(.15,.95,.20),TEAL,rounding=.032))
frame.append(cylinder('Yaw seat',(0,0,.635),.28,.15,HUB,vertices=32))
frame.append(cylinder('Yaw brass race',(0,0,.715),.245,.04,GOLD,vertices=32))
join(frame,'StaticCarriage',root,origin=(0,0,0))

# Independent complete wheels around their axles, four equally substantial wheels.
for s,side in [('L',-1),('R',1)]:
    for label,y in [('Front',.43),('Rear',-.49)]:
        x=side*.59; z=.31
        parts=[]
        profile=[(-.105,.245,0),(-.105,.28,0),(-.082,.307,0),(-.052,.31,0),(.070,.31,0),(.100,.282,0),(.105,.245,1),(.105,.17,1),(.088,.153,1),(-.09,.153,0)]
        parts.append(lathe('Wheel tire',profile,(x,y,z),[TIRE,HUB],axis='X',segments=32))
        parts.append(cylinder('Coral wheel hub',(x+side*.112,y,z),.155,.035,CORAL,axis='X',vertices=32))
        parts.append(cylinder('Brass wheel boss',(x+side*.145,y,z),.097,.079,GOLD,axis='X',vertices=24))
        parts.append(cylinder('Boss face',(x+side*.187,y,z),.069,.016,GOLD,axis='X',vertices=16))
        join(parts,f'Wheel_{s}_{label}',root,origin=(x,y,z))

# Aim carries a sculpted teal trunnion cradle with a smooth high arch on each side.
cradle=[]
for side in (-1,1):
    x=side*.36
    # Vertical rounded plates, upper round lobe makes a cannon yoke silhouette.
    cradle.append(side_plate('Sculpted cradle upright',x,[(-.37,.49),(.25,.49),(.25,.67),(.12,.78),(.035,.95),(-.04,1.03),(-.15,1.045),(-.245,.99),(-.30,.84),(-.37,.77)],LIGHT))
    cradle.append(cylinder('Trunnion steel pin',(x+side*.09,-.09,.89),.07,.035,STEEL,axis='X',vertices=20))
cradle.append(box('Cradle cross brace',(0,-.09,.72),(.63,.34,.12),HUB,rounding=.028))
join(cradle,'RotatingCradle',aim)

# Coral breech with two oversized teal support bands and a brass rear cap.
breech=[]
breech.append(lathe('Coral breech',[(-.68,.21,0),(-.655,.29,0),(-.61,.305,0),(-.02,.305,0),(.03,.285,0),(.04,.01,0),(-.68,.01,0)],(0,0,1.025),[CORAL],segments=48))
for y in [-.60,.015]:
    breech.append(lathe('Teal breech ring',[(y-.055,.29,0),(y-.055,.327,0),(y-.032,.343,1),(y+.032,.343,1),(y+.055,.327,0),(y+.055,.29,0)],(0,0,1.025),[TEAL,LIGHT],segments=48))
breech.append(cylinder('Rear brass cap',(0,-.724,1.025),.255,.08,GOLD,axis='Y',vertices=40))
breech.append(cylinder('Rear central plug',(0,-.790,1.025),.17,.06,GOLD,axis='Y',vertices=32))
join(breech,'CoralBreech',aim)

# Continuous barrel and genuinely recessed, open bore: the wall extends 0.65m inside.
barrel=[]
barrel.append(lathe('Brass barrel and open muzzle',[
    (.065,.215,0),(.080,.240,0),(.135,.242,0),(.164,.215,0),
    (.925,.227,0),(.965,.290,0),(.985,.350,0),(1.105,.350,0),
    (1.135,.327,0),(1.135,.242,0),(1.116,.223,1),(.48,.201,1),
    (.44,.001,1),(.065,.001,0)],(0,0,1.025),[GOLD,BORE],segments=48))
barrel.append(lathe('Dark muzzle seam',[(.970,.310,0),(.978,.345,0),(.985,.351,0),(.997,.351,0),(.997,.342,0)],(0,0,1.025),[AGED],segments=48))
join(barrel,'RecoilBarrelMesh',recoil)

# An ivory artillery round in the right side rack. Pointed ogive, brass cartridge rim.
rack=[]
rack.append(box('Shell rack outrigger',(.57,-.26,.54),(.45,.39,.14),TEAL,rounding=.045))
rack.append(cylinder('Shell tray',(.76,-.26,.65),.176,.077,LIGHT,vertices=32))
rack.append(lathe('Shell retaining lip',[(.668,.153,0),(.668,.18,0),(.692,.18,0),(.692,.153,0)],(.76,-.26,0),[TEAL],axis='Z',segments=32))
join(rack,'ShellRack',root)
shell=[]
shell.append(lathe('Ivory shell',[(.694,.124,0),(.712,.137,0),(.952,.137,0),(.995,.132,0),(1.055,.107,0),(1.120,.069,0),(1.158,.025,0),(1.17,.001,0),(.694,.001,0)],(.76,-.26,0),[IVORY],axis='Z',segments=32))
shell.append(cylinder('Shell brass base',(.76,-.26,.709),.14,.043,GOLD,vertices=32))
shell.append(cylinder('Shell coral driving band',(.76,-.26,.785),.139,.035,CORAL,vertices=32))
shell.append(lathe('Shell brass fuse',[(1.120,.069,0),(1.154,.030,0),(1.171,.002,0),(1.145,.002,0)],(.76,-.26,0),[GOLD],axis='Z',segments=24))
join(shell,'ArtilleryShell',root,origin=(.76,-.26,.694))

# Keep all mesh normals explicit and export only the rigid asset.
bpy.context.view_layer.update()
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_siege.glb'),export_format='GLB',export_yup=True,
    export_animations=False,export_cameras=False,export_lights=False)
metrics={}
for o in bpy.context.scene.objects:
    if o.type=='MESH':
        o.data.calc_loop_triangles(); metrics[o.name]=len(o.data.loop_triangles)
(OUT/'build_metrics.json').write_text(json.dumps({'triangles_by_object':metrics,'total_triangles':sum(metrics.values())},indent=2))
print('EXPORT',OUT/'cp_siege.glb')
