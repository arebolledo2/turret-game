"""Deterministic Bramble Wisp. Blender +Z up, +Y front; root at ground origin.
Run with Blender 5.2 --background --python build_cp_basic.py.
All generated source images are packed into cp_basic.blend and embedded in GLB.
"""
from pathlib import Path
import math, json
import bpy
import numpy as np
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
OUT = Path(__file__).resolve().parent
OUT.mkdir(parents=True, exist_ok=True)
C = .77
N = 1024
rng = np.random.default_rng(417)
yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
u, v = xx/N, yy/N

def image(name, rgb):
    im = bpy.data.images.new(name, N, N, alpha=False)
    arr = np.ones((N,N,4), dtype=np.float32)
    arr[:,:,:3] = np.clip(rgb,0,1)
    im.pixels.foreach_set(arr.ravel())
    im.filepath_raw = str(OUT/(name+'.png'))
    im.file_format = 'PNG'
    im.save()
    im.pack()
    return im

# Clean enamel with broad tonal movement and very subtle fired-enamel granulation.
enamel_tone = .96 + .055*np.sin(u*math.tau)*np.sin(v*math.tau) + .027*np.cos(v*math.tau*3)
enamel_tone += rng.normal(0,.004,(N,N))
enamel = image('enamel_generated', enamel_tone[:,:,None]*np.array([.075,.69,.60])[None,None,:])

# Shared finish atlas: gold, coral, deep glass, sapphire fasteners, warm ivory.
palette = np.array([[.98,.64,.19],[.98,.32,.235],[.055,.235,.275],[.20,.59,.91],[.99,.93,.67]])
ids = np.minimum((u*5).astype(int),4)
localu = u*5-ids
tone = 1 + .04*np.cos(v*math.tau) + .025*np.sin(localu*math.tau)
tone += rng.normal(0,.003,(N,N))
hardware = image('finishes_generated', palette[ids]*tone[:,:,None])

# Eye is a convex optical face, with iris fibres and polished wedges in colour.
dx, dz = (u-.5)*2, (v-.5)*2
rr, angle = np.hypot(dx,dz), np.arctan2(dz,dx)
eye_rgb = np.zeros((N,N,3),np.float32)
eye_rgb[:] = [.96,.985,.82]
iris = rr < .665
fibres = .055*np.sin(angle*133 + rr*29)+.025*np.cos(angle*207-rr*19)
sector = .11*np.sin(angle*3+.6)+.065*np.cos(angle*5)
rad = np.clip((rr-.27)/.40,0,1)
eye_rgb[:,:,0] = np.where(iris,.016+.03*rad,eye_rgb[:,:,0])
eye_rgb[:,:,1] = np.where(iris,.46+.19*rad+fibres+sector,eye_rgb[:,:,1])
eye_rgb[:,:,2] = np.where(iris,.30+.14*rad+fibres*.5+sector*.6,eye_rgb[:,:,2])
edge = iris & (rr > .625)
eye_rgb[edge] *= .72
pupil = rr < .31
eye_rgb[pupil] = [.013,.13,.145]
shine = ((dx+.26)**2+(dz-.29)**2) < .095**2
eye_rgb[shine] = [.995,1,.90]
iris_image = image('eye_generated',eye_rgb)

materials={}
def mat(name, im, rough=.3, metal=0., emission=0):
    m=bpy.data.materials.new(name);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Roughness'].default_value=rough
    bs.inputs['Metallic'].default_value=metal
    tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im
    m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    if emission:
        m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Emission Color'])
        bs.inputs['Emission Strength'].default_value=emission
    materials[name]=m
    return m

teal=mat('01_Turquoise_enamel',enamel,.27,.20)
gold=mat('02_Warm_brass',hardware,.28,.68)
coral=mat('03_Coral_enamel',hardware,.30,.12)
dark=mat('04_Deep_optical_glass',hardware,.23,.20)
blue=mat('05_Sapphire_fasteners',hardware,.19,.25)
ivory=mat('06_Ivory_indicator',hardware,.22,.08, .10)
eye=mat('07_Emerald_eye',iris_image,.55,0,.12)
eye.node_tree.nodes.get('Principled BSDF').inputs['Specular IOR Level'].default_value=0
tile={gold.name:0,coral.name:1,dark.name:2,blue.name:3,ivory.name:4}
root=bpy.data.objects.new('BrambleWisp',None);bpy.context.collection.objects.link(root)
body=bpy.data.objects.new('Body',None);bpy.context.collection.objects.link(body)
body.parent=root;body.location=(0,0,C)
objects=[]

def uv_project(o):
    while o.data.uv_layers:
        o.data.uv_layers.remove(o.data.uv_layers[0])
    layer=o.data.uv_layers.new(name='UVMap')
    for p in o.data.polygons:
        axis=max(range(3),key=lambda i:abs(p.normal[i]))
        for li in p.loop_indices:
            q=o.data.vertices[o.data.loops[li].vertex_index].co
            a,b=((q.y,q.z),(q.x,q.z),(q.x,q.y))[axis]
            # Shared metre-density projection; tile finishes within their atlas band.
            uv=(a*1.6+.5,b*1.6+.5)
            if o.data.materials[0].name in tile:
                t=tile[o.data.materials[0].name]
                uv=((t+.05+.90*(uv[0]%1))/5,.05+.90*(uv[1]%1))
            layer.data[li].uv=uv

def finish(o,name,m,custom_uv=False):
    o.name=name;o.data.materials.append(m)
    if not custom_uv:uv_project(o)
    for p in o.data.polygons:p.use_smooth=True
    o.parent=body;o.location.z-=C
    objects.append(o)
    return o

def sphere(name,pos,scale,m,segments=32,rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1,location=pos)
    o=bpy.context.object;o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,m)

def ring(name,r1,r2,y,z,m,a1=0,a2=math.tau,segments=64):
    # Rounded annular band, wide front surface, integrated bevel profile.
    profile=[(r1,y-.022),(r1,y-.008),(r1+.008,y+.005),(r2-.009,y+.005),(r2,y-.008),(r2,y-.022)]
    closed=abs(a2-a1-math.tau)<.001
    verts=[];faces=[]
    steps=segments if closed else segments+1
    for i in range(steps):
        a=a1+(a2-a1)*i/segments
        for r,yp in profile:verts.append((math.sin(a)*r,yp,z+math.cos(a)*r))
    for i in range(segments):
        j=(i+1)%steps
        for k in range(len(profile)):
            kn=(k+1)%len(profile)
            faces.append((i*6+k,j*6+k,j*6+kn,i*6+kn))
    if not closed:
        faces.extend([tuple(range(5,-1,-1)),tuple((steps-1)*6+k for k in range(6))])
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o)
    return finish(o,name,m)

def disk(name,pos,r,depth,m,segments=20):
    bpy.ops.mesh.primitive_cylinder_add(vertices=segments,radius=r,depth=depth,location=pos,rotation=(math.pi/2,0,0))
    o=bpy.context.object
    be=o.modifiers.new('Soft machined edge','BEVEL');be.width=min(.008,r*.18);be.segments=1
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=be.name)
    return finish(o,name,m)

def leaf(index,a,length=.22,width=.092,y=-.025,curve=.04):
    radial=Vector((math.sin(a),0,math.cos(a)))
    tangent=Vector((math.cos(a),0,-math.sin(a)))
    verts=[];faces=[];count=10;sections=9
    for j in range(sections):
        t=j/(sections-1)
        center=Vector((0,y,C))+radial*(.335+length*t)+tangent*(curve*t*t)
        center.y += .025*math.sin(t*math.pi)
        w=width*(.88+1.2*t)*(1-t)**.62 if t<1 else .006
        thickness=.065*(1-t)**.6+.007
        for k in range(count):
            f=math.tau*k/count
            point=center+tangent*(w*math.cos(f))+Vector((0,thickness*math.sin(f),0))
            verts.append(tuple(point))
    for j in range(sections-1):
        for k in range(count):
            faces.append((j*count+k,j*count+(k+1)%count,(j+1)*count+(k+1)%count,(j+1)*count+k))
    faces.append(tuple(range(count-1,-1,-1)))
    faces.append(tuple((sections-1)*count+k for k in range(count)))
    me=bpy.data.meshes.new('Leaf');me.from_pydata(verts,[],faces);me.update()
    o=bpy.data.objects.new('Leaf',me);bpy.context.collection.objects.link(o)
    finish(o,'Curved_leaf_%02d'%index,teal)

sphere('Orb_enamel',(0,0,C),(.405,.335,.405),teal)
# Main crown leaf is deliberately larger, with a broad leaf ridge rather than a cone.
leaf(0,0,.275,.11,.14,.085)
for i,(degrees,length,w,y,curve) in enumerate([
    (-38,.245,.094,-.05,-.035),(42,.218,.090,-.085,.02),
    (-78,.252,.099,-.02,-.016),(82,.226,.086,-.065,.01),
    (-120,.23,.087,-.04,-.02),(125,.205,.08,-.055,.02),
    (-157,.18,.07,-.11,-.025),(157,.17,.072,-.08,.025),
    (180,.25,.080,-.03,0)],1):leaf(i,math.radians(degrees),length,w,y,curve)

sphere('Dark_face_dome',(0,.277,C),(.339,.165,.339),dark,32,16)
ring('Brass_face_bezel',.326,.385,.305,C,gold)
ring('Coral_lower_bezel',.327,.385,.320,C,coral,math.radians(119),math.radians(241),28)
# Side hinge buttons with broad coin-shaped gold caps.
for x in (-.374,.374):
    disk('Hinge_mount',(x,.307,C),.052,.033,gold)
    disk('Hinge_inset',(x,.33,C),.027,.007,gold)
for degrees in (-35,35,-139,139):
    a=math.radians(degrees);p=(math.sin(a)*.357,.324,C+math.cos(a)*.357)
    disk('Bolt_coral_socket',p,.020,.009,coral,16)
    disk('Blue_jewel_bolt',(p[0],p[1]+.009,p[2]),.014,.013,blue,16)

# Convex eye surface, mapped directly to the procedural circular eye image.
radius=.19; center=Vector((-.048,.431,C+.005)); verts=[tuple(center+Vector((0,.030,0)))]; faces=[]
rings=8;seg=48
for j in range(1,rings+1):
    r=radius*j/rings
    for k in range(seg):
        a=math.tau*k/seg
        verts.append(tuple(center+Vector((r*math.cos(a),.030*math.sqrt(max(0,1-(r/radius)**2)),r*math.sin(a)))))
for k in range(seg):faces.append((0,1+k,1+(k+1)%seg))
for j in range(rings-1):
    for k in range(seg):
        a=1+j*seg+k;b=1+j*seg+(k+1)%seg;c=1+(j+1)*seg+(k+1)%seg;d=1+(j+1)*seg+k
        faces.append((a,b,c,d))
me=bpy.data.meshes.new('EyeSurface');me.from_pydata(verts,[],[tuple(reversed(f)) for f in faces]);me.update()
o=bpy.data.objects.new('Eye',me);bpy.context.collection.objects.link(o)
uv=me.uv_layers.new(name='UVMap')
for p in me.polygons:
    for li in p.loop_indices:
        q=me.vertices[me.loops[li].vertex_index].co-center
        uv.data[li].uv=(.5+q.x/(radius*2),.5+q.z/(radius*2))
finish(o,'Jewel_eye',eye,True)

# Coral medallion overlaps lower frame, then a polished ivory status jewel.
disk('Coral_medallion',(.035,.351,C-.335),.085,.035,coral,24)
disk('Gold_medallion_rim',(.035,.38,C-.335),.058,.025,gold,24)
sphere('Ivory_medallion',(.035,.398,C-.335),(.044,.017,.044),ivory,16,8)
for x in (-.034,.103):disk('Medallion_screw',(x,.378,C-.359),.008,.006,gold,12)

# Unseen rear is a modest service cap with the same material language.
ring('Back_gold_cap',.112,.14,-.298,C,gold,segments=40)
sphere('Back_coral_service_cap',(0,-.314,C),(.109,.025,.109),coral,24,12)
disk('Back_gold_status',(0,-.343,C),.037,.012,gold,20)
# Lower curved coral collar, integrated into orb rather than a separate dangling unit.
ring('Lower_coral_collar',.27,.304,-.13,C-.04,coral,math.radians(130),math.radians(230),20)

# Join rigid geometry by finish. Seven mesh objects/materials under one articulated Body.
for m in list(materials.values()):
    group=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.materials[0]==m]
    if not group:continue
    bpy.ops.object.select_all(action='DESELECT')
    for o in group:o.select_set(True)
    bpy.context.view_layer.objects.active=group[0]
    bpy.ops.object.join()
    result=bpy.context.object;result.name=m.name[3:]+'_mesh'

bpy.context.view_layer.update()
stats={'triangles':0,'mesh_objects':0,'materials':len(materials),'textures':3,'animations':0}
for o in bpy.context.scene.objects:
    if o.type=='MESH':
        o.data.calc_loop_triangles();stats['triangles']+=len(o.data.loop_triangles);stats['mesh_objects']+=1
root['asset']='Bramble Wisp';root['forward']='+Y';body['motion']='Single rigid hover parent; no baked clips.'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_basic.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_basic.glb'),export_format='GLB',export_yup=True,
    export_animations=False,export_cameras=False,export_lights=False,export_apply=True)
(OUT/'build_stats.json').write_text(json.dumps(stats,indent=2))
print('FINAL_STATS',json.dumps(stats))
