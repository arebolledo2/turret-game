"""A centered, 48 cm bowling projectile with actual drilled finger cavities.

All geometry and the restrained resin colour map are generated here. No assets
are read from disk. Blender +Z is up; +Y is the ball's presentation front.
"""
import bpy
import bmesh
import math
import json
import hashlib
import numpy as np
from mathutils import Vector
from pathlib import Path

OUT = Path(__file__).parent
bpy.ops.wm.read_factory_settings(use_empty=True)
RADIUS = .24

def material(name, colour, metallic=0.0, roughness=.3):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*colour, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*colour, 1)
    p.inputs['Metallic'].default_value = metallic
    p.inputs['Roughness'].default_value = roughness
    return m

resin = material('Polished blue-black resin with warm plum marbling', (.019,.023,.034), .18, .20)
p = resin.node_tree.nodes.get('Principled BSDF')
p.inputs['Coat Weight'].default_value = .48
p.inputs['Coat Roughness'].default_value = .15
brass = material('Restrained flush brass equator inlay', (.48,.285,.105), .68, .28)
interior = material('Dark recessed finger bore walls', (.002,.004,.006), .02, .52)

# Seamless analytic colour map: use positions on a unit sphere so the UV seam
# and the poles agree. Gentle, large plum clouds read as polished resin.
px = 512
u = (np.arange(px, dtype=np.float32)+.5)/px
v = (np.arange(px, dtype=np.float32)+.5)/px
uu, vv = np.meshgrid(u,v)
theta = 2*np.pi*uu
latitude = np.pi*(vv-.5)
x = np.cos(latitude)*np.cos(theta)
y = np.cos(latitude)*np.sin(theta)
z = np.sin(latitude)
cloud = .5+.5*np.sin(3*x+2*y+1.2*z+1.4*np.sin(2.3*y-2*z))
fine = .5+.5*np.sin(12*x+6*y+3*z+2*np.sin(4*y+3*z))
plum = np.clip(.30*cloud+.08*fine+.16*np.exp(-((z+.25)/.5)**2),0,1)
base = np.array([.105,.135,.180],np.float32)
warm = np.array([.205,.104,.170],np.float32)
rgb = base[None,None,:]*(1-plum[:,:,None])+warm[None,None,:]*plum[:,:,None]
rgba = np.concatenate([rgb,np.ones((px,px,1),np.float32)],axis=2)
image = bpy.data.images.new('Generated seamless plum resin',width=px,height=px,alpha=True)
image.colorspace_settings.name = 'sRGB'
image.pixels.foreach_set(rgba.ravel())
image.filepath_raw = str(OUT/'plum_resin.png')
image.file_format = 'PNG'
image.save()
image.pack()
tex = resin.node_tree.nodes.new('ShaderNodeTexImage')
tex.image = image
resin.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])

# The equator is part of the sphere surface, not an added hoop. The narrow
# material strip therefore never increases the collision silhouette.
segments = 56
latitudes = sorted(set([-math.pi/2]+[-math.pi/2+math.pi*j/32 for j in range(1,32)]+[-.016,.016]+[math.pi/2]))
verts = [(0,0,-RADIUS)]
for lat in latitudes[1:-1]:
    verts.extend([(RADIUS*math.cos(lat)*math.cos(2*math.pi*i/segments),
                   RADIUS*math.cos(lat)*math.sin(2*math.pi*i/segments),
                   RADIUS*math.sin(lat)) for i in range(segments)])
verts.append((0,0,RADIUS))
faces=[]
face_lat=[]
for i in range(segments):
    faces.append((0,1+(i+1)%segments,1+i));face_lat.append(-math.pi/2)
ring_count=len(latitudes)-2
for j in range(ring_count-1):
    first=1+j*segments;following=first+segments
    for i in range(segments):
        k=(i+1)%segments
        faces.append((first+i,first+k,following+k,following+i))
        face_lat.append((latitudes[j+1]+latitudes[j+2])/2)
for i in range(segments):
    first=1+(ring_count-1)*segments
    faces.append((first+i,first+(i+1)%segments,len(verts)-1));face_lat.append(math.pi/2)
mesh=bpy.data.meshes.new('Continuous sphere with flush equator inlay')
mesh.from_pydata(verts,[],faces);mesh.update()
ball=bpy.data.objects.new('BowlingBall',mesh)
bpy.context.collection.objects.link(ball)
for mat in (resin,brass,interior):mesh.materials.append(mat)
uv=mesh.uv_layers.new(name='ResinUV')
for poly,lat in zip(mesh.polygons,face_lat):
    poly.use_smooth=True
    poly.material_index=1 if abs(lat)<.016 else 0
    coords=[]
    for li in poly.loop_indices:
        co=mesh.vertices[mesh.loops[li].vertex_index].co
        coords.append([(math.atan2(co.y,co.x)/(2*math.pi))%1,
                       math.asin(max(-1,min(1,co.z/RADIUS)))/math.pi+.5])
    if max(c[0] for c in coords)-min(c[0] for c in coords)>.5:
        for c in coords:
            if c[0]<.5:c[0]+=1
    for li,c in zip(poly.loop_indices,coords):uv.data[li].uv=c

# Triangular bowling grip: the thumb is slightly wider and lower than the
# paired fingers. Each blind bore penetrates 6.5 cm below the sphere surface.
bores=[(-.23,.76,.61,.027),(.22,.77,.60,.027),(-.01,.91,.415,.032)]
for index,(x,y,z,r) in enumerate(bores):
    normal=Vector((x,y,z)).normalized()
    bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=r,depth=.14,location=normal*.245)
    cutter=bpy.context.object
    cutter.name='Temporary drill'
    cutter.rotation_euler=normal.to_track_quat('Z','Y').to_euler()
    for mat in (resin,brass,interior):cutter.data.materials.append(mat)
    for poly in cutter.data.polygons:
        poly.material_index=2
        poly.use_smooth=len(poly.vertices)==4
    bpy.context.view_layer.objects.active=ball
    mod=ball.modifiers.new('Blind drilled finger cavity '+str(index),'BOOLEAN')
    mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter,do_unlink=True)

# Small softened lips catch a narrow resin highlight and expose real depth.
bpy.context.view_layer.objects.active=ball
mod=ball.modifiers.new('Rounded cavity lips','BEVEL')
mod.width=.0015;mod.segments=2;mod.limit_method='ANGLE';mod.angle_limit=.55
bpy.ops.object.modifier_apply(modifier=mod.name)
bm=bmesh.new();bm.from_mesh(ball.data)
bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
bm.to_mesh(ball.data);bm.free()
ball.location=(0,0,0)
ball.rotation_euler=(0,0,0)
ball['diameter_m']=.48
ball['pivot_note']='Geometric center at world origin; suitable for arbitrary-axis projectile rolling.'
ball['finger_bores']='Three actual blind recesses, 6.5 cm maximum cavity depth.'
bpy.context.scene.unit_settings.system='METRIC'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_bowling_ball.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_bowling_ball.glb'),export_format='GLB',export_yup=True,
                          export_animations=False,export_cameras=False,export_lights=False)
ball.data.calc_loop_triangles()
metrics={'triangles':len(ball.data.loop_triangles),'mesh_objects':1,'materials':3,
         'diameter_m':.48,'origin':[0,0,0],'generated_textures':1,'texture_resolution':[512,512],
         'glb_sha256':hashlib.sha256((OUT/'cp_bowling_ball.glb').read_bytes()).hexdigest()}
(OUT/'builder_metrics.json').write_text(json.dumps(metrics,indent=2))
print(json.dumps(metrics,indent=2))
