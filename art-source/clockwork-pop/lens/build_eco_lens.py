"""Independent Prism Conductor satellite; generated geometry and packed textures."""
import bpy
import math
import json
from pathlib import Path
import numpy as np
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
OUT = Path(__file__).parent
OUT.mkdir(parents=True, exist_ok=True)

def texture(name, kind):
    n=1024
    v,u=np.mgrid[0:n,0:n].astype(np.float32)/n
    if kind=='ivory':
        subtle=.985+.011*np.sin(u*math.tau*5)*np.sin(v*math.tau*3)
        rgb=np.stack([.88*subtle,.91*subtle,.94*subtle],-1)
        # Fine blue-grey ceramic firing variations; no dirt or wear.
        rgb+= (.005*np.sin((u+v)*math.tau*80))[...,None]
    elif kind=='gold':
        grain=.97+.025*np.sin(v*math.tau*240)+.01*np.sin(u*math.tau*11)
        rgb=np.stack([.94*grain,.65*grain,.23*grain],-1)
    elif kind=='violet':
        g=.91+.07*np.sin(u*math.tau)*np.cos(v*math.tau)
        rgb=np.stack([.32*g,.16*g,.69*g],-1)
        # Subtle polished enamel interference bands.
        rgb+= (.003*np.sin(v*math.tau*24))[...,None]*np.array([.6,.2,1.])
    else:
        rng=np.random.default_rng(39)
        seeds=rng.random((30,2)); colors=[]
        for x,y in seeds:
            c=np.array([.82+.13*y,.42+.25*y,.84-.08*y])
            c+=rng.uniform(-.075,.075,3)
            colors.append(c)
        best=np.ones((n,n))*10; rgb=np.zeros((n,n,3),np.float32)
        for (x,y),c in zip(seeds,colors):
            d=(u-x)**2+(v-y)**2
            mask=d<best; best[mask]=d[mask];rgb[mask]=c
        radial=np.sqrt((u-.5)**2+(v-.5)**2)
        rgb=rgb*(.97-.13*radial[...,None])
    rgba=np.concatenate([np.clip(rgb,0,1),np.ones((n,n,1))],-1).astype(np.float32)
    image=bpy.data.images.new(name,width=n,height=n,alpha=True)
    image.colorspace_settings.name='sRGB'
    image.pixels.foreach_set(rgba.ravel());image.filepath_raw=str(OUT/(name+'.png'))
    image.file_format='PNG';image.save();image.pack()
    return image

images={k:texture(k+'_surface',k) for k in ('ivory','gold','violet','crystal')}

def material(name,image,metal=0,rough=.3,emission=0):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=images[image]
    m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
    if emission:
        m.node_tree.links.new(tex.outputs['Color'],p.inputs['Emission Color'])
        p.inputs['Emission Strength'].default_value=emission
    return m

ivory=material('Pearl ceramic','ivory',.12,.27)
gold=material('Satin gold gimbal','gold',.78,.26)
violet=material('Violet enamel','violet',.20,.24)
dark=material('Shadow violet seals','violet',.35,.4)
dark.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.08,.02,.17,1)
# Lower the texture's brightness directly with a glTF-supported multiplier.
for node in dark.node_tree.nodes:
    if node.type=='TEX_IMAGE':
        dark.node_tree.links.remove(next(l for l in dark.node_tree.links if l.from_node==node))
        mul=dark.node_tree.nodes.new('ShaderNodeMixRGB');mul.blend_type='MULTIPLY';mul.inputs[0].default_value=1
        mul.inputs[2].default_value=(.24,.20,.32,1)
        dark.node_tree.links.new(node.outputs['Color'],mul.inputs[1])
        dark.node_tree.links.new(mul.outputs[0],dark.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
        break
crystal=material('Rose violet faceted crystal','crystal',.26,.16,.12)
glow=material('Violet emitter','violet',.15,.20,1.4)

def empty(name,pos=(0,0,0),parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=pos;o.parent=parent
    return o
root=empty('Satellite')
body=empty('Body',(0,0,.49),root)
finL=empty('Fin_L',(-.285,-.035,.49),root)
finR=empty('Fin_R',(.285,-.035,.49),root)
gimbal=empty('Gimbal',(0,0,.49),root)
emitter=empty('RearEmitter',(0,-.225,.49),root)
empty('Muzzle',(0,.305,.49),body)
# Muzzle is a marker and is corrected to local coordinates below.
bpy.data.objects['Muzzle'].location=(0,.305,0)

def uv(o,crystal_projection=False):
    layer=o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap')
    for p in o.data.polygons:
        axis=max(range(3),key=lambda a:abs(p.normal[a]))
        for i in p.loop_indices:
            co=o.data.vertices[o.data.loops[i].vertex_index].co
            if crystal_projection:
                pair=(co.x/.49+.5,co.z/.49+.5)
            elif axis==0:pair=(co.y/.48+.5,co.z/.48+.5)
            elif axis==1:pair=(co.x/.48+.5,co.z/.48+.5)
            else:pair=(co.x/.48+.5,co.y/.48+.5)
            layer.data[i].uv=pair

def finish(o,name,mat,parent,smooth=True,crystal_projection=False):
    o.name=name;o.data.materials.append(mat)
    for p in o.data.polygons:p.use_smooth=smooth
    uv(o,crystal_projection)
    # Inputs use local coordinates for each named pivot.
    o.parent=parent
    return o

def revolved(name,profile,mat,parent,segments=64):
    verts=[];faces=[]
    for r,y in profile:
        for j in range(segments):
            a=j*math.tau/segments;verts.append((r*math.cos(a),y,r*math.sin(a)))
    for k in range(len(profile)-1):
        for j in range(segments):
            a=k*segments+j;b=k*segments+(j+1)%segments
            faces.append((a,b,b+segments,a+segments))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
    return finish(o,name,mat,parent)

def torus(name,r,t,mat,parent,y=0,segments=64,minor=8):
    bpy.ops.mesh.primitive_torus_add(major_radius=r,minor_radius=t,major_segments=segments,minor_segments=minor,
        location=(0,y,0),rotation=(math.pi/2,0,0))
    o=bpy.context.object;bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    return finish(o,name,mat,parent)

def sphere(name,pos,scale,mat,parent,segments=20,rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=pos)
    o=bpy.context.object;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,mat,parent)

# Nested hardware holds a shallow optical assembly, not a boss torso.
revolved('Ceramic optical annulus',[(.258,-.08),(.277,-.06),(.288,-.025),(.29,.07),(.284,.115),
    (.275,.137),(.253,.146),(.24,.132),(.24,-.06),(.258,-.08)],ivory,body)
revolved('Violet rear cap',[(.001,-.22),(.08,-.216),(.16,-.197),(.223,-.155),(.259,-.10),(.265,-.055)],violet,body)
torus('Inner aperture gasket',.243,.012,dark,body,.14,64,8)
torus('Fine gold optical rim',.251,.008,gold,body,.151,64,6)
torus('Outer free gold gimbal',.321,.021,gold,gimbal,.001,64,10)
torus('Rear gimbal tracing',.282,.008,gold,body,-.103,64,6)

# Large flat triangles, explicitly physical facets, slightly proud of the bright aperture.
verts=[(0,.275,0)];faces=[]
radii=[.098,.190,.238];depths=[.263,.213,.16];counts=[8,16,16]
starts=[]
for k,(r,y,count) in enumerate(zip(radii,depths,counts)):
    starts.append(len(verts))
    for i in range(count):
        a=i*math.tau/count+(math.pi/16 if k==1 else 0)
        rr=r*(1+.025*math.sin(i*3.13))
        verts.append((rr*math.cos(a),y+.005*math.sin(i*4.2+k),rr*math.sin(a)))
for i in range(8):faces.append((0,starts[0]+(i+1)%8,starts[0]+i))
for i in range(8):
    a=starts[0]+i;b=starts[0]+(i+1)%8
    c=starts[1]+i*2;d=starts[1]+(i*2+1)%16;e=starts[1]+(i*2+2)%16
    faces.extend([(a,d,c),(a,b,d),(b,e,d)])
for i in range(16):
    a=starts[1]+i;b=starts[1]+(i+1)%16;c=starts[2]+i;d=starts[2]+(i+1)%16
    faces.extend([(a,b,c),(b,d,c)])
mesh=bpy.data.meshes.new('Crystal triangulated optics');mesh.from_pydata(verts,[],faces);mesh.update()
o=bpy.data.objects.new('Crystal faceted eye',mesh);bpy.context.collection.objects.link(o)
finish(o,o.name,crystal,body,False,True)

def fin(name,sign,parent,mat,inset=False):
    # Short swept fins, spaced clear of the ring, with rounded leading edges.
    pts=[(.055,.006,.075),(.128,-.015,.178),(.211,-.091,.257),(.252,-.19,.211),
         (.219,-.228,.087),(.112,-.17,-.094),(.067,-.08,-.115)]
    if inset:pts=[(.055+(x-.055)*.82,y,z*.80) for x,y,z in pts]
    # Both faces lie on parallel planes; this prevents inset/front-face crossings.
    pts=[(x,-.65*x,z) for x,y,z in pts]
    thick=.034 if inset else .028
    verts=[(sign*x,y+d,z) for d in (-thick,thick) for x,y,z in pts]
    n=len(pts);faces=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]
    for i in range(n):faces.append((i,(i+1)%n,(i+1)%n+n,i+n))
    m=bpy.data.meshes.new(name);m.from_pydata(verts,[],faces);m.update()
    o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active=o;o.select_set(True)
    mod=o.modifiers.new('Ceramic softened rim','BEVEL');mod.width=.012 if not inset else .005;mod.segments=3
    bpy.ops.object.modifier_apply(modifier=mod.name);o.select_set(False)
    return finish(o,name,mat,parent,False)

for sign,piv,side in [(-1,finL,'L'),(1,finR,'R')]:
    sphere('Gold swivel '+side,(0,0,0),(.038,.039,.038),gold,piv,16,8)
    fin('Violet fin border '+side,sign,piv,violet)
    fin('Ivory swept fin '+side,sign,piv,ivory,True)

# Tiny emitter and optical port on the rear, readable but subordinate.
revolved('Rear emitter bezel',[(.048,.011),(.045,-.018),(.028,-.034),(.023,-.025),(.023,.009),(.048,.011)],gold,emitter,32)
sphere('Rear violet emitter',(0,-.026,0),(.023,.009,.023),glow,emitter,16,8)

scene=bpy.context.scene;scene.render.fps=30
scene.frame_start=1;scene.frame_end=61
rest={o.name:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in [finL,finR,gimbal,emitter]}
def reset():
    for o in [finL,finR,gimbal,emitter]:
        o.animation_data_clear();o.location,o.rotation_euler,o.scale=rest[o.name]

def clip(name,frames,mode):
    reset()
    for f in frames:
        t=(f-1)/(frames[-1]-1)
        wave=math.sin(t*math.tau);pulse=math.sin(t*math.pi)**2
        for sign,o in [(-1,finL),(1,finR)]:
            if mode=='Idle':o.rotation_euler=(0,sign*.06*wave,.02*wave)
            elif mode=='Walk':o.rotation_euler=(.07*wave,sign*.16*wave,sign*.035*wave)
            elif mode=='Swim':o.rotation_euler=(.11*wave,sign*.26*wave,sign*.10*wave)
            else:o.rotation_euler=(-.12*pulse,sign*-.28*pulse,sign*.13*pulse)
            o.keyframe_insert(data_path='rotation_euler',frame=f)
        gimbal.rotation_euler=(0,.025*wave if mode=='Idle' else .10*wave, .05*wave if mode!='Attack' else .12*pulse)
        gimbal.keyframe_insert(data_path='rotation_euler',frame=f)
        emitter.scale=(1,1,1) if mode!='Attack' else (1+.16*pulse,1+.16*pulse,1+.16*pulse)
        emitter.keyframe_insert(data_path='scale',frame=f)
    for o in [finL,finR,gimbal,emitter]:
        action=o.animation_data.action;action.name=name+'_'+o.name
        for fc in action.fcurves if hasattr(action,'fcurves') else []:
            for kp in fc.keyframe_points:kp.interpolation='LINEAR'
        track=o.animation_data.nla_tracks.new();track.name=name
        strip=track.strips.new(name,1,action);strip.name=name
        o.animation_data.action=None
    # Keep all NLA clips and detach the active action, then restore neutral values.
    for o in [finL,finR,gimbal,emitter]:o.location,o.rotation_euler,o.scale=rest[o.name]

# Each part carries the same named tracks, yielding four merged rigid clips.
for name,duration in [('Idle',61),('Walk',41),('Swim',49),('Attack',25)]:
    # Preserve earlier NLA tracks while starting a fresh action.
    saved={o.name:[(tr.name,[(s.name,s.action) for s in tr.strips]) for tr in o.animation_data.nla_tracks] if o.animation_data else []
           for o in [finL,finR,gimbal,emitter]}
    clip(name,list(range(1,duration+1,4))+([duration] if (duration-1)%4 else []),name)
    for o in [finL,finR,gimbal,emitter]:
        for trname,strips in saved[o.name]:
            tr=o.animation_data.nla_tracks.new();tr.name=trname
            for stname,act in strips:st=tr.strips.new(stname,1,act);st.name=stname

scene.frame_set(1)
for o in [finL,finR,gimbal,emitter]:o.location,o.rotation_euler,o.scale=rest[o.name]
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'eco_lens.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'eco_lens.glb'),export_format='GLB',export_yup=True,
    export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True,
    export_cameras=False,export_lights=False,export_apply=True)
print('EXPORTED eco_lens: independent rigid satellite, four packed 1024 textures and Idle Walk Swim Attack.')
