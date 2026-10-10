"""Dugout Automaton: correct handle grip, physical 1.2m +Y sweep, runtime rigid rig."""
from pathlib import Path
import math,json
import bpy,bmesh,numpy as np
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
OUT=Path(__file__).resolve().parent
N=1024;rng=np.random.default_rng(227)
COL=[(.04,.72,.62),(.91,.66,.23),(.98,.29,.22),(.98,.89,.65),(.11,.105,.18),(.94,.71,.39),(1,.75,.025),(.18,.14,.80)]
ROUGH=[.31,.28,.28,.32,.42,.36,.17,.16];METAL=[.12,.75,.06,0,.29,0,.20,.13]
imgs=[np.ones((N,N,4),np.float32) for _ in range(4)]
for i,c in enumerate(COL):
    a,b=slice(i//4*512,(i//4+1)*512),slice(i%4*256,(i%4+1)*256)
    v,u=np.mgrid[0:512,0:256].astype(np.float32);v/=512;u/=256;noise=rng.normal(0,1,(512,256)).astype(np.float32)
    broad=.012*np.sin(u*9+v*6)+.008*np.cos(u*5-v*15)
    brush=.012*np.sin(v*770+u*3) if i==1 else .001*np.sin(u*740+v*160)
    imgs[0][a,b,:3]=np.clip(np.array(c)*(1+broad+brush+noise*.0015)[:,:,None],0,1)
    imgs[1][a,b,0]=1;imgs[1][a,b,1]=ROUGH[i]+broad*.5;imgs[1][a,b,2]=METAL[i]
    imgs[2][a,b,:3]=np.stack((.5+noise*.0005,.5+noise*.0005,np.ones_like(noise)),axis=-1)
    imgs[3][a,b,:3]=0
    if i==5:
        # Lengthwise maple fibres, subtle warm ribbons and red stitched barrel band.
        grain=.030*np.sin(u*135+4*np.sin(v*13))+ .014*np.sin(u*362+v*8)
        fibres=np.maximum(np.sin(u*267+np.sin(v*8)*3),0)**28*.06
        imgs[0][a,b,:3]=np.clip(np.array(c)*(1+grain-fibres)[:,:,None],0,1)
        band=(v>.93)&(v<.957)&(np.sin(u*math.tau*28+v*42)>.28)
        imgs[0][a,b,:3][band]=(.88,.15,.085)
        imgs[1][a,b,1]=.35+grain*.7
        imgs[2][a,b,0]=.5+grain*.15
    if i in (6,7):imgs[3][a,b,:3]=np.array(c)*(.13+.04*np.sin(u*6+v*5)[:,:,None])
images=[]
for name,arr,space in zip(('dugout_color_atlas','dugout_orm_atlas','dugout_micro_normal','dugout_optic_glow'),imgs,('sRGB','Non-Color','Non-Color','sRGB')):
    im=bpy.data.images.new(name,width=N,height=N,alpha=True);im.colorspace_settings.name=space;im.pixels.foreach_set(arr.ravel());im.filepath_raw=str(OUT/(name+'.png'));im.file_format='PNG';im.save();im.pack();images.append(im)
materials=[]
for i,name in enumerate(('Lagoon enamel','Brushed brass','Coral lacquer','Warm ivory','Plum joint recess','Maple bat','Amber button','Blue-violet optics')):
    mat=bpy.data.materials.new(name);mat.use_nodes=True;mat.diffuse_color=(*COL[i],1);n,l=mat.node_tree.nodes,mat.node_tree.links;p=n.get('Principled BSDF')
    t=n.new('ShaderNodeTexImage');t.image=images[0];l.new(t.outputs['Color'],p.inputs['Base Color'])
    t=n.new('ShaderNodeTexImage');t.image=images[1];sp=n.new('ShaderNodeSeparateColor');l.new(t.outputs['Color'],sp.inputs['Color']);l.new(sp.outputs['Green'],p.inputs['Roughness']);l.new(sp.outputs['Blue'],p.inputs['Metallic'])
    t=n.new('ShaderNodeTexImage');t.image=images[2];nm=n.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.15;l.new(t.outputs['Color'],nm.inputs['Color']);l.new(nm.outputs['Normal'],p.inputs['Normal'])
    p.inputs['Coat Weight'].default_value=.20 if i in (0,2,5,6,7) else .07;p.inputs['Coat Roughness'].default_value=.20
    if i in (6,7):
        t=n.new('ShaderNodeTexImage');t.image=images[3];l.new(t.outputs['Color'],p.inputs['Emission Color']);p.inputs['Emission Strength'].default_value=.4
    materials.append(mat)
def empty(name,loc,parent=None):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=loc;o.parent=parent;return o
aim=empty('Aim',(0,0,.66));muzzle=empty('Muzzle',(0,1.2,.42),aim) # world (0,1.2,1.08)
groups={}
def project(o,i):
    uv=o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap');cen=Vector(tuple((min(v.co[k] for v in o.data.vertices)+max(v.co[k] for v in o.data.vertices))/2 for k in range(3)))
    for p in o.data.polygons:
        k=max(range(3),key=lambda j:abs(p.normal[j]));ij=([1,2],[0,2],[0,1])[k]
        for li in p.loop_indices:
            v=o.data.vertices[o.data.loops[li].vertex_index].co-cen
            uv.data[li].uv=((i%4+.03+.94*(.5+v[ij[0]]*.72))/4,(i//4+.03+.94*(.5+v[ij[1]]*.72))/2)
def finish(o,name,mat,group,parent=None,smooth=True):
    o.name=name;o.data.materials.append(materials[mat]);project(o,mat)
    for p in o.data.polygons:p.use_smooth=smooth
    if parent:
        bpy.context.view_layer.update();o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted()
    groups.setdefault((group,parent),[]).append(o);return o
def bevel(o,w=.008,s=2):
    bpy.context.view_layer.objects.active=o;mod=o.modifiers.new('Rounded edges','BEVEL');mod.width=w;mod.segments=s;bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=o.modifiers.new('Weighted bevel normals','WEIGHTED_NORMAL');mod.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=mod.name)
def raw(name,v,f,mat,group,parent=None,smooth=True,edge=0):
    me=bpy.data.meshes.new(name);me.from_pydata(v,[],f);me.update();bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free()
    o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o)
    if edge:bevel(o,edge,1)
    return finish(o,name,mat,group,parent,smooth)
def box(name,loc,size,mat,group,parent=None,edge=.01):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);bevel(o,edge,2);return finish(o,name,mat,group,parent)
def cyl(name,loc,r,d,mat,group,parent=None,axis=(0,0,1),n=24):
    n=min(n,24)
    bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=d,location=loc);o=bpy.context.object;bevel(o,min(.008,d*.15),1);o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler();return finish(o,name,mat,group,parent)
def sphere(name,loc,scale,mat,group,parent=None,n=16,rings=8):
    n=min(n,16);rings=min(rings,8)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=n,ring_count=rings,radius=1,location=loc);o=bpy.context.object;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,mat,group,parent)
def lathe(name,prof,mat,group,parent=None,n=40,axis='Z',z=0):
    v=[]
    for r,t in prof:
        for j in range(n):
            a=j*math.tau/n
            v.append((r*math.cos(a),r*math.sin(a),t) if axis=='Z' else (r*math.cos(a),t,z+r*math.sin(a)))
    f=[(k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j) for k in range(len(prof)-1) for j in range(n)]
    f.extend([tuple(reversed(range(n))),tuple((len(prof)-1)*n+j for j in range(n))]);return raw(name,v,f,mat,group,parent)
def strut(name,a,b,r,mat,group,parent=aim,n=20):
    a,b=Vector(a),Vector(b);return cyl(name,(a+b)/2,r,(b-a).length,mat,group,parent,b-a,n)

# Fixed squat enamel pedestal, coral foundation ring and rounded dark feet.
lathe('Enamel dome pedestal',[(.239,.035),(.268,.052),(.275,.090),(.274,.181),(.258,.258),(.226,.317),(.182,.355),(.119,.378),(.0,.378)],0,'Enamel pedestal',n=48)
lathe('Coral foundation band',[(.245,.025),(.282,.038),(.288,.058),(.278,.082),(.263,.093),(.248,.083)],2,'Base coral trims',n=48)
for a in (math.radians(90),math.radians(210),math.radians(330)):
    x,y=.285*math.cos(a),.285*math.sin(a)
    foot=box('Dark foundation foot',(x,y,.051),(.12,.105,.077),4,'Foundation feet',edge=.024);foot.rotation_euler.z=a-math.pi/2
    cuff=box('Coral foot cuff',(x*.91,y*.91,.086),(.125,.100,.065),2,'Base coral trims',edge=.02);cuff.rotation_euler.z=a-math.pi/2

# Four ivory meridian ribs wrap the base between the colored front and side sockets.
profile=[(.288,.085),(.288,.165),(.278,.245),(.246,.305),(.221,.330),(.204,.344),(.185,.355)]
for a in (math.pi/4,3*math.pi/4,5*math.pi/4,7*math.pi/4):
    v=[]
    for r,z in profile:
        for t in (a-.055,a+.055):v.append((r*math.cos(t),r*math.sin(t),z))
    fs=[(2*k,2*k+1,2*k+3,2*k+2) for k in range(len(profile)-1)]
    o=raw('Ivory base meridian',v,fs,3,'Ivory base ribbons');bpy.context.view_layer.objects.active=o
    mod=o.modifiers.new('Raised ceramic ribbon','SOLIDIFY');mod.thickness=.014;bpy.ops.object.modifier_apply(modifier=mod.name)
    bevel(o,.008,2)
lathe('Ivory shoulder connecting arch',[(.223,.327),(.215,.344),(.194,.358),(.182,.362),(.177,.350),(.198,.343),(.213,.323)],3,'Ivory base ribbons',n=40)
for axis,i in [((0,1,0),6),((-1,0,0),7),((0,-1,0),6),((1,0,0),7)]:
    d=Vector(axis);z=.194
    cyl('Coral optic bezel',d*.274+Vector((0,0,z)),.076,.043,2,'Base sockets',axis=axis,n=32)
    cyl('Ivory optic inset',d*.299+Vector((0,0,z)),.055,.022,3,'Base sockets',axis=axis,n=32)
    scale=(.039,.013,.039) if axis[1] else (.013,.039,.039)
    sphere('Jewelled base button',d*.315+Vector((0,0,z)),scale,i,'Base jewels',n=20,rings=10)
    sphere('Base optic glint',d*.326+Vector((-.008 if axis[1] else 0,0,.014+z)),(.006,.004,.008) if axis[1] else (.004,.006,.008),3,'Base jewels',n=12,rings=6)

# Static turntable collar and central gold column terminate at the yaw pivot.
cyl('Coral turntable collar',(0,0,.373),.152,.039,2,'Base coral trims',n=40)
cyl('Turntable shadow',(0,0,.395),.121,.022,4,'Fixed mast',n=32)
cyl('Mast brass footing',(0,0,.411),.074,.035,1,'Fixed mast',n=32)
cyl('Central brass mast',(0,0,.527),.040,.216,1,'Fixed mast',n=24)
cyl('Mast upper dark bearing',(0,0,.639),.062,.033,4,'Fixed mast',n=32)

# Aim carries the complete shoulder/arm/hand/bat, identity rest rotation.
cyl('Shoulder dark rotor',(0,0,.681),.078,.152,4,'Shoulder',aim,(1,0,0),32)
cyl('Shoulder brass housing',(-.070,0,.689),.085,.060,1,'Shoulder',aim,(1,0,0),32)
cyl('Shoulder ivory optic trim',(-.108,0,.689),.061,.022,3,'Shoulder',aim,(1,0,0),32)
sphere('Shoulder blue jewel',(-.127,0,.689),(.015,.046,.046),7,'Shoulder optics',aim,20,10)
sphere('Shoulder jewel glint',(-.142,.012,.712),(.003,.008,.009),3,'Shoulder optics',aim,12,6)

# Two tapered brass side plates frame the dark articulated forearm.
a,b=Vector((0,.015,.699)),Vector((0,.155,.898));delta=b-a
core=box('Arm dark core',(a+b)/2,(.113,.107,delta.length),4,'Arm frame',aim,.017);core.rotation_euler=delta.to_track_quat('Z','Y').to_euler()
for x in (-.068,.068):
    plate=box('Brass forearm side plate',(x,(a.y+b.y)/2,(a.z+b.z)/2),(.035,.125,delta.length+.028),1,'Arm brass plates',aim,.015);plate.rotation_euler=delta.to_track_quat('Z','Y').to_euler()
strut('Coral arm underside',(.01,-.030,.682),(.01,.12,.891),.042,2,'Arm frame')
cyl('Elbow dark axle',(0,.155,.906),.059,.195,4,'Elbow',aim,(1,0,0),28)
cyl('Elbow brass dial',(-.116,.155,.906),.052,.030,1,'Elbow',aim,(1,0,0),32)
cyl('Elbow amber centre',(-.134,.155,.906),.026,.008,6,'Elbow',aim,(1,0,0),24)
strut('Wrist dark riser',(0,.155,.920),(0,.130,1.015),.047,4,'Hand backing')
box('Coral wrist seat',(0,.145,.967),(.182,.125,.035),2,'Hand backing',aim,.008)
box('Dark palm block',(0,.13,1.024),(.152,.199,.101),4,'Hand backing',aim,.018)
box('Front brass palm shield',(-.091,.13,1.011),(.025,.184,.124),1,'Hand backing',aim,.010)
for y in (.083,.174):
    cyl('Palm recessed fastener',(-.106,y,1.04),.012,.004,4,'Hand backing',aim,(-1,0,0),16)
    sphere('Palm lower rivet',(-.106,y,.978),(.005,.007,.007),1,'Hand backing',aim,12,6)

# Three articulated golden fingers wrap the narrow handle immediately above the butt knob.
for y in (.057,.122,.187):
    v=[];count=13
    for j in range(count):
        a=math.radians(-20+220*j/(count-1))
        # ellipse hugs the handle; rectangular finger band has real gold thickness.
        for r,yy in ((.037,y-.020),(.051,y-.020),(.051,y+.020),(.037,y+.020)):
            v.append((r*math.cos(a),yy,1.08+r*math.sin(a)))
    f=[(3,2,1,0)]
    for j in range(count-1):
        for k in range(4):f.append((4*j+k,4*j+(k+1)%4,4*(j+1)+(k+1)%4,4*(j+1)+k))
    f.append(tuple((count-1)*4+k for k in range(4)))
    raw('Golden curled finger',v,f,1,'Grip fingers',aim,edge=.003)

# Correct baseball bat proportions: handle at hand, then long taper and rounded wooden barrel.
lathe('Dark bat handle',[(.027,-.033),(.026,.018),(.025,.23),(.028,.277),(.030,.30)],4,'Bat handle',aim,n=28,axis='Y',z=1.08)
lathe('Brass butt knob',[(.031,-.080),(.047,-.076),(.054,-.065),(.054,-.044),(.043,-.031),(.027,-.029)],1,'Bat handle',aim,n=32,axis='Y',z=1.08)
lathe('Brass bat handle ferrule',[(.029,.256),(.036,.259),(.039,.276),(.038,.294),(.031,.302)],1,'Bat handle',aim,n=28,axis='Y',z=1.08)
bat=lathe('Maple baseball bat',[(.029,.287),(.033,.342),(.042,.465),(.053,.63),(.066,.82),(.076,1.00),(.081,1.105),(.080,1.150),(.074,1.174),(.057,1.193),(.025,1.199),(.001,1.200)],5,'Wooden bat',aim,n=32,axis='Y',z=1.08)
uv=bat.data.uv_layers.active
for p in bat.data.polygons:
    for li in p.loop_indices:
        co=bat.data.vertices[bat.data.loops[li].vertex_index].co
        u=(math.atan2(co.z-1.08,co.x)+math.pi)/math.tau;v=(co.y-.287)/.913
        uv.data[li].uv=((1+.03+.94*u)/4,(1+.03+.94*v)/2)

# Merge rigid assemblies only. Static components stay outside Aim.
for (name,parent),objs in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]
    if len(objs)>1:bpy.ops.object.join()
    bpy.context.object.name=name
bpy.context.view_layer.update()
for o in bpy.context.scene.objects:
    if o.type=='MESH':o.data.calc_loop_triangles()
stats={'triangles':sum(len(o.data.loop_triangles) for o in bpy.context.scene.objects if o.type=='MESH'),'mesh_objects':sum(o.type=='MESH' for o in bpy.context.scene.objects),'materials':len(materials),'textures':len(images),'Aim_world':[0,0,.66],'Muzzle_world':[0,1.2,1.08],'horizontal_reach':1.2,'grip_y_range':[.037,.207],'butt_knob_y':[-.080,-.029],'wood_bat_y':[.287,1.2]}
(OUT/'build_stats.json').write_text(json.dumps(stats,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cp_melee.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'cp_melee.glb'),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False,export_apply=True)
print('DUGOUT_BUILD',stats)
