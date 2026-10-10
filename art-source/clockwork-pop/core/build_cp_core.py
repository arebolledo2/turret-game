"""Deterministic Clockwork core. Blender 5.2, no external textures or assets.
Run: blender -b --python build_cp_core.py
"""
import bpy, math, json
from pathlib import Path
from mathutils import Vector, Matrix

OUT = Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
TAU = math.tau
CENTER = Vector((0, 0, .90))

def material(name, color, metallic=0, rough=.3, emission=None, strength=0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metallic
    p.inputs['Roughness'].default_value = rough
    if emission:
        p.inputs['Emission Color'].default_value = (*emission, 1)
        p.inputs['Emission Strength'].default_value = strength
    return m

MATS = [
 material('CW_DeepNavy', (.016,.045,.078), .58, .25),
 material('CW_TealEnamel', (.018,.34,.31), .48, .24),
 material('CW_Brass', (.62,.33,.082), .83, .26),
 material('CW_GoldHighlight', (.91,.61,.18), .77, .23),
 material('CW_Coral', (.8,.13,.08), .33, .27),
 material('CW_CyanInlay', (.028,.56,.62), .20, .22, (.07,.84,1), 2.8),
 material('CW_OrbReplaceable', (.07,.40,.57), .25, .18, (.08,.58,.86), 1.35),
 material('CW_DarkRubber', (.009,.017,.028), .05, .48),
]

class Geo:
    def __init__(self): self.v=[]; self.f=[]; self.mi=[]
    def add(self, verts, faces, mat):
        n=len(self.v); self.v.extend(verts)
        for f in faces: self.f.append(tuple(n+i for i in f)); self.mi.append(mat)
    def hoop(self, radius, profile, mat, start=0, end=TAU, steps=96, cap=False):
        vs=[]; fs=[]; k=len(profile)
        for i in range(steps+1 if cap else steps):
            a=start+(end-start)*i/steps
            for dr,z in profile: vs.append(((radius+dr)*math.cos(a),(radius+dr)*math.sin(a),z))
        for i in range(steps):
            j=i+1 if cap else (i+1)%steps
            for p in range(k): fs.append((i*k+p,j*k+p,j*k+(p+1)%k,i*k+(p+1)%k))
        if cap:
            fs.extend([tuple(reversed(range(k))),tuple(steps*k+i for i in range(k))])
        self.add(vs,fs,mat)
    def cylinder(self, center, radius, depth, mat, sides=8, axis=(0,0,1)):
        c=Vector(center); n=Vector(axis).normalized(); u=n.orthogonal().normalized(); v=n.cross(u)
        vs=[tuple(c+u*(math.cos(a)*radius)+v*(math.sin(a)*radius)+n*z)
            for z in (-depth/2,depth/2) for a in [TAU*i/sides for i in range(sides)]]
        fs=[tuple(reversed(range(sides))),tuple(sides+i for i in range(sides))]
        fs += [(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)]
        self.add(vs,fs,mat)
    def lathe(self, profile, mat, sides=64):
        vs=[(r*math.cos(TAU*i/sides),r*math.sin(TAU*i/sides),z) for z,r in profile for i in range(sides)]
        fs=[]
        for row in range(len(profile)-1):
            for i in range(sides):
                j=(i+1)%sides; fs.append((row*sides+i,row*sides+j,(row+1)*sides+j,(row+1)*sides+i))
        fs.extend([tuple(reversed(range(sides))),tuple((len(profile)-1)*sides+i for i in range(sides))])
        self.add(vs,fs,mat)
    def mesh(self,name,parent=None, matrix=None):
        verts=[tuple(matrix @ Vector(v)) for v in self.v] if matrix else self.v
        d=bpy.data.meshes.new(name+'_Geometry'); d.from_pydata(verts,[],self.f); d.update()
        o=bpy.data.objects.new(name,d); bpy.context.collection.objects.link(o)
        for m in MATS: d.materials.append(m)
        for p,mi in zip(d.polygons,self.mi): p.material_index=mi; p.use_smooth=True
        if parent: o.parent=parent
        # Weighted split normals preserve flat machining faces across beveled profile sections.
        bpy.context.view_layer.objects.active=o; o.select_set(True)
        mod=o.modifiers.new('MachinedNormals','WEIGHTED_NORMAL'); mod.keep_sharp=True; mod.weight=40
        bpy.ops.object.modifier_apply(modifier=mod.name); o.select_set(False)
        return o

def pivot(name,position):
    o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o); o.location=position
    o.empty_display_type='PLAIN_AXES'; o.empty_display_size=.1
    return o

body=pivot('Body',(0,0,0))
base=Geo()
# Broad grounded circular pedestal, scalloped visually through alternating gold cooling lugs.
base.lathe([(0,.47),(.015,.535),(.035,.55),(.10,.55),(.12,.52),(.135,.48),(.16,.43),(.18,.39)],0)
base.lathe([(.025,.539),(.036,.553),(.051,.553),(.058,.543)],2)
base.lathe([(.12,.521),(.13,.517),(.146,.478),(.153,.46)],3)
base.lathe([(.163,.43),(.177,.42),(.183,.38),(.183,.29)],1)
base.lathe([(.185,.29),(.192,.28),(.195,.255),(.195,.21)],2)
base.lathe([(.196,.21),(.203,.20),(.203,.13)],5)
base.lathe([(.204,.13),(.211,.12),(.211,.015)],0)
for i in range(12):
    a=TAU*i/12; r=.472
    # Brass radial plates on pedestal shoulder.
    base.hoop(r,[(-.025,.145),(.026,.145),(.026,.162),(-.025,.162)],2,a-.065,a+.065,3,True)
    base.cylinder((r*math.cos(a),r*math.sin(a),.171),.013,.018,3,6)
    # Cyan windows cut into broad foot band; opaque inlays, no translucent shells.
    base.hoop(.552,[(0,.069),(.003,.069),(.003,.094),(0,.094)],5,a-.1,a+.1,4,True)
for i in range(3):
    a=TAU*i/3+TAU/12
    base.hoop(.4,[(-.025,.18),(.025,.18),(.025,.198),(-.025,.198)],4,a-.15,a+.15,5,True)
base.v=[(x*.55/.555,y*.55/.555,z*.70) for x,y,z in base.v]
base_obj=base.mesh('Pedestal',body)

PROFILE=[(-.027,-.020),(-.020,-.028),(.020,-.028),(.027,-.020),(.027,.020),(.020,.028),(-.020,.028),(-.027,.020)]
ring_specs=[('Ring_Outer',.70,90,0),('Ring_Middle',.59,58,62),('Ring_Inner',.48,68,-48)]
for name,radius,tilt,yaw in ring_specs:
    p=pivot(name,CENTER)
    g=Geo(); g.hoop(radius,PROFILE,1)
    # Two raised brass edge bands, each with chamfered four-sided section.
    for dr in (-.023,.023):
        g.hoop(radius+dr,[(-.004,-.022),(.004,-.022),(.004,.022),(-.004,.022)],2)
    for i in range(12):
        a=TAU*i/12
        # Broad polished cyan segmented inlays on both faces of each hoop.
        for side in (-1,1):
            z=side*.029
            g.hoop(radius,[(-.009,z),(.009,z),(.009,z+side*.003),(-.009,z+side*.003)],5,a+.045,a+.19,4,True)
            g.cylinder((radius*math.cos(a),radius*math.sin(a),side*.034),.012,.013,3,6)
        if i%3==0:
            # Clockwork calibration tab at the four cardinal points.
            g.hoop(radius,[(-.034,-.021),(.036,-.021),(.04,-.010),(.04,.010),(.036,.021),(-.034,.021)],2,a-.045,a+.045,3,True)
            g.hoop(radius,[(-.011,.032),(.012,.032),(.012,.037),(-.011,.037)],4,a-.024,a+.024,2,True)
    baked=Matrix.Rotation(math.radians(yaw),3,'Z') @ Matrix.Rotation(math.radians(tilt),3,'X')
    g.mesh(name+'_Hoop',p,baked)

# Single UV sphere for shader replacement. Its UV map is the untouched Blender primitive sphere UV.
bpy.ops.mesh.primitive_uv_sphere_add(segments=48,ring_count=24,radius=.325,location=CENTER)
orb=bpy.context.object; orb.name='Orb'; orb.data.name='Orb_UVSphere'; orb.data.materials.append(MATS[6])
for p in orb.data.polygons: p.use_smooth=True
orb['shader_slot']='Replace CW_OrbReplaceable with the Godot procedural plasma ShaderMaterial.'
orb['sphere_radius_m']=.325

# Asset metadata carried in the source, and explicitly documented alongside the GLB.
bpy.context.scene['asset_id']='cp_core'
bpy.context.scene['units']='meters'
bpy.context.scene['coordinate_contract']='Blender Z-up exported as Godot Y-up; all ring pivots have identity rotation.'
bpy.context.scene.unit_settings.system='METRIC'
bpy.context.scene.unit_settings.scale_length=1.0
for o in (body,*[bpy.data.objects[n] for n,_,_,_ in ring_specs]):
    o.rotation_euler=(0,0,0); o.scale=(1,1,1)

# A clean editable source: mesh geometry, material slots and named pivots only.
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_core.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_core.glb'),export_format='GLB',export_yup=True,
                        export_animations=False,export_extras=True,export_apply=True)
stats={'mesh_objects':sum(o.type=='MESH' for o in bpy.data.objects),
       'triangles':sum(len(o.data.loop_triangles) for o in bpy.data.objects if o.type=='MESH')}
for o in bpy.data.objects:
    if o.type=='MESH': o.data.calc_loop_triangles()
stats['triangles']=sum(len(o.data.loop_triangles) for o in bpy.data.objects if o.type=='MESH')
print('CP_CORE_EXPORT',json.dumps(stats))
