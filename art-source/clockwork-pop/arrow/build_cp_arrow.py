"""Standalone Clockwork Pop arrow; metres, +Y forward, centered flight origin."""
import bpy, bmesh, math, json
from mathutils import Vector
from pathlib import Path

bpy.ops.wm.read_factory_settings(use_empty=True)
OUT = Path(__file__).resolve().parent

def material(name, color, metallic, roughness):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    s=m.node_tree.nodes.get('Principled BSDF')
    s.inputs['Base Color'].default_value=(*color,1)
    s.inputs['Metallic'].default_value=metallic
    s.inputs['Roughness'].default_value=roughness
    return m

brass=material('Warm brass',(.83,.48,.055),.75,.24)
gold=material('Polished brass edges',(1,.73,.17),.68,.22)
ivory=material('Ivory arrow fins',(.94,.85,.58),.10,.29)
coral=material('Coral binding',(.84,.095,.047),.08,.35)
parts=[]

def finish(o,name,mat,bevel=0):
    o.name=name; o.data.materials.append(mat)
    if bevel:
        mod=o.modifiers.new('Soft machined edges','BEVEL');mod.width=bevel;mod.segments=2
        bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=mod.name)
    bm=bmesh.new();bm.from_mesh(o.data)
    bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
    for f in bm.faces:f.smooth=True
    for e in bm.edges:
        if len(e.link_faces)==2 and e.calc_face_angle(0)>math.radians(35):e.smooth=False
    bm.to_mesh(o.data);bm.free(); parts.append(o);return o

def cylinder(name,y,radius,length,mat,bevel=.0007):
    bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=radius,depth=length,location=(0,y,0))
    o=bpy.context.object;o.rotation_euler.x=math.pi/2
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    return finish(o,name,mat,bevel)

def mesh(name,verts,faces,mat,bevel=0):
    d=bpy.data.meshes.new(name);d.from_pydata(verts,[],faces);d.update()
    o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o)
    return finish(o,name,mat,bevel)

# A long uninterrupted brass rod, slightly brighter at the tip ferrule.
cylinder('Brass flight shaft',-.048,.0085,.545,brass)
cylinder('Ivory point socket',.204,.012,.035,gold,.001)
cylinder('Socket rear seam',.183,.013,.008,brass,.0006)

# Diamond section point: broad triangular blade from every useful oblique view.
# End coordinates deliberately determine the exact 650 mm overall length.
v=[(0,.325,0),(-.056,.210,0),(0,.210,.045),(.056,.210,0),
   (0,.210,-.045),(0,.193,0)]
mesh('Ivory diamond arrowhead',v,
     [(0,1,2),(0,2,3),(0,3,4),(0,4,1),(5,2,1),(5,3,2),(5,4,3),(5,1,4)],ivory)

# Three solid ivory vanes, evenly spaced around the shaft. Broad tapered fins
# match the bow's simple ivory facets and remain visible at gameplay distance.
for index,a in enumerate([math.pi/2,7*math.pi/6,11*math.pi/6]):
    radial=Vector((math.cos(a),0,math.sin(a)))
    tangent=Vector((-math.sin(a),0,math.cos(a)))
    profile=[(-.307,.008),(-.301,.057),(-.280,.069),(-.228,.066),(-.172,.009)]
    vv=[]
    for side in [-1,1]:
        for y,r in profile:vv.append(tuple(radial*r+Vector((0,y,0))+tangent*(side*.0024)))
    n=len(profile);ff=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    for i in range(n):j=(i+1)%n;ff.append((i,j,n+j,n+i))
    mesh('Ivory tail fin %d'%(index+1),vv,ff,ivory,.0008)

# Coral winding binds both ends of the fletching; a thin gold lip makes each
# wrap feel deliberately manufactured without hiding the warm coral color.
for y,length in [(-.307,.016),(-.174,.016)]:
    cylinder('Coral fletching wrap',y,.0117,length,coral,.0006)
    for d in [-1,1]:cylinder('Wrap brass edge',y+d*(length/2+.001),.012,.002,gold,.0003)

# Bifurcated brass nock (a real string slot). Its rear face is at -.325 m.
cylinder('Nock collar',-.317,.0106,.010,gold,.0005)
for x in [-.0065,.0065]:
    bpy.ops.mesh.primitive_cube_add(size=1,location=(x,-.3215,0))
    o=bpy.context.object;o.scale=(.005,.007,.012)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    finish(o,'Nock prong',brass)

# Every surface travels rigidly. Merge to one mesh and set its actual origin
# to the flight center; no turret hierarchy, ground base or animation tracks.
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join()
o=bpy.context.object;o.name='Arrow'
bpy.context.scene.cursor.location=(0,0,0)
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
root=bpy.data.objects.new('FlightRoot',None);bpy.context.collection.objects.link(root)
o.parent=root;o.matrix_parent_inverse=root.matrix_world.inverted()
o.data.calc_loop_triangles()
points=[o.matrix_world@v.co for v in o.data.vertices]
lo=[min(p[i] for p in points) for i in range(3)]
hi=[max(p[i] for p in points) for i in range(3)]
metrics={'triangles':len(o.data.loop_triangles),'mesh_objects':1,
         'materials':len({m.name for m in o.data.materials}),
         'bounds_min_m':lo,'bounds_max_m':hi,'forward':'Blender +Y',
         'flight_origin_m':list(root.location),'mesh_origin_m':list(o.location),
         'textures':0,'animations':0}
(OUT/'authored_metrics.json').write_text(json.dumps(metrics,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_arrow.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_arrow.glb'),export_format='GLB',export_yup=True,
                          export_animations=False,export_cameras=False,export_lights=False)
