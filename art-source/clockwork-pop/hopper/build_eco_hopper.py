from pathlib import Path
import bpy, bmesh, math, json
import numpy as np
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
OUT=Path(__file__).parent
T=math.tau
# Four reproducible, packed procedural finish maps. Clean enamel and machined surfaces.
def image(name,kind):
 n=1024; y,x=np.mgrid[0:n,0:n]/n; rng=np.random.default_rng(81)
 grain=rng.normal(0,.003,(n,n)); sheen=.012*np.sin(T*x*4)*np.sin(T*y*3)
 if kind=='red':
  base=np.stack([.71+sheen+grain,.018+.5*grain,.025+.5*grain],-1)
  # Fine pearlescent enamel, no dirt or oversized arbitrary panel seams.
  base+=((np.sin(x*T*127)*np.sin(y*T*113))*.002)[...,None]
 elif kind=='dark':
  brushed=.006*np.sin(T*y*240)+grain
  base=np.stack([.025+brushed,.032+brushed,.043+brushed],-1)
 elif kind=='metal':
  brushed=.032*np.sin(T*y*310)+grain
  base=np.stack([.55+brushed,.59+brushed,.62+brushed],-1)
 else:
  # Lens depth colour in polar-mapped UVs: golden rim, dark teal core.
  r=np.sqrt((x-.5)**2+(y-.5)**2)*2; rim=np.clip((r-.58)/.39,0,1)
  c=np.array([.012,.065,.075]); a=np.array([.64,.29,.014])
  base=c[None,None,:]*(1-rim[...,None])+a[None,None,:]*rim[...,None]
  base+=.013*(1-y)[...,None]
 pix=np.concatenate([np.clip(base,0,1),np.ones((n,n,1))],2).astype(np.float32)
 im=bpy.data.images.new(name,n,n,alpha=False); im.colorspace_settings.name='sRGB'; im.pixels.foreach_set(pix.ravel()); im.filepath_raw=str(OUT/(name+'.png')); im.file_format='PNG'; im.save(); im.pack(); return im
maps={k:image('hopper_'+k,k) for k in ['red','dark','metal','eye']}
def mat(name,col,metal,rough,tex=None,coat=0):
 m=bpy.data.materials.new(name); m.use_nodes=True; m.diffuse_color=(*col,1); p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*col,1); p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough; p.inputs['Coat Weight'].default_value=coat; p.inputs['Coat Roughness'].default_value=.12
 if tex:
  q=m.node_tree.nodes.new('ShaderNodeTexImage'); q.image=maps[tex]; m.node_tree.links.new(q.outputs['Color'],p.inputs['Base Color'])
 return m
red=mat('Candy red enamel',(.71,.018,.025),.3,.24,'red',.45)
dark=mat('Black segmented carapace',(.025,.032,.043),.55,.32,'dark',.12)
steel=mat('Brushed steel hinges',(.55,.59,.62),.85,.27,'metal')
brass=mat('Warm brass lens bezels',(.55,.25,.055),.78,.25)
lens=mat('Amber teal optical lenses',(.1,.3,.3),.48,.115,'eye',.6)
teal=mat('Turquoise enamel inlays',(.008,.56,.51),.38,.22,coat=.4)
rubber=mat('Graphite foot grips',(.014,.018,.021),.05,.53,'dark')

def empty(name,loc=(0,0,0),parent=None):
 o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o); o.location=loc
 if parent:
  bpy.context.view_layer.update();o.parent=parent; o.matrix_parent_inverse=parent.matrix_world.inverted()
 return o
root=empty('EcoHopper'); body=empty('Body',parent=root)
parts={}
def finish(o,name,m,group):
 if group in ['belly','shell','head','optics']:group='Carapace'
 o.name=name; o.data.materials.append(m)
 for p in o.data.polygons:p.use_smooth=len(p.vertices)<=4
 # Box projection in metres, common .25 metre texel tile, not primitive-dependent.
 uv=o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap')
 for p in o.data.polygons:
  a=max(range(3),key=lambda j:abs(p.normal[j]))
  for li in p.loop_indices:
   v=o.data.vertices[o.data.loops[li].vertex_index].co
   uv.data[li].uv=((v[(a+1)%3]/.25)%100,(v[(a+2)%3]/.25)%100)
 parts.setdefault(group,[]).append(o); return o

def sphere(name,loc,scale,m,g,seg=24,rings=12):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,radius=1,location=loc);o=bpy.context.object;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,m,g)
def cyl(name,a,b,r,m,g,seg=12):
 a=Vector(a);b=Vector(b);bpy.ops.mesh.primitive_cylinder_add(vertices=seg,radius=r,depth=(b-a).length,location=(a+b)/2);o=bpy.context.object;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return finish(o,name,m,g)
def box(name,loc,size,m,g,bev=.012):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bev:
  mod=o.modifiers.new('Enamel edge radius','BEVEL');mod.width=bev;mod.segments=2;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 return finish(o,name,m,g)
def tube(name,coords,r,m,g,seg=8):
 vs=[];fs=[];pts=[Vector(p) for p in coords]
 for i,p in enumerate(pts):
  d=(pts[min(i+1,len(pts)-1)]-pts[max(i-1,0)]).normalized();u=d.cross(Vector((0,1,0)))
  if u.length<.01:u=d.cross(Vector((1,0,0)))
  u.normalize();v=d.cross(u)
  vs.extend(p+r*(math.cos(T*j/seg)*u+math.sin(T*j/seg)*v) for j in range(seg))
 for i in range(len(pts)-1):
  for j in range(seg):a=i*seg+j;b=i*seg+(j+1)%seg;fs.append((a,b,b+seg,a+seg))
 fs.extend([tuple(reversed(range(seg))),tuple((len(pts)-1)*seg+j for j in range(seg))]); me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);return finish(o,name,m,g)
def rivet(loc,g,r=.008):sphere('Flush rivet',loc,(r,r,r),steel,g,8,4)
def ring(name,loc,major,minor,m,g,axis=(0,1,0),seg=24):
 bpy.ops.mesh.primitive_torus_add(major_radius=major,minor_radius=minor,major_segments=seg,minor_segments=6,location=loc);o=bpy.context.object;o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler();return finish(o,name,m,g)
# Segmented abdomen, low belly, visible black seam along elytra.
sphere('Ventral carapace',(0,-.115,.405),(.305,.365,.215),dark,'belly')
for i in range(4):
 y=-.12-i*.085; sphere('Abdominal segment',(0,y,.407-i*.009),(.287-i*.009,.076,.183-i*.008),dark,'belly',20,10)
# Smooth, separately formed left/right dorsal wing plates, asymmetric material accents.
def wing(side):
 vs=[];fs=[];nx=13;ny=19
 for j in range(ny):
  t=j/(ny-1);y=.20-t*.76;w=.305*(math.sin(math.pi*(.13+.84*t))**.64)
  for i in range(nx):
   q=i/(nx-1);x=side*(.014+q*w);z=.52+.21*(1-q*q)*math.sin(math.pi*(.19+.77*t))+.045*(1-t)
   vs.append((x,y,z))
 for j in range(ny-1):
  for i in range(nx-1):
   a=j*nx+i;face=(a,a+1,a+nx+1,a+nx);fs.append(tuple(reversed(face)) if side>0 else face)
 me=bpy.data.meshes.new('Wing plate');me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new('Red elytron',me);bpy.context.collection.objects.link(o);finish(o,'Red elytron',red,'shell')
 mod=o.modifiers.new('Shell thickness','SOLIDIFY');mod.thickness=.014;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 # Panel edges remain red, small silver fastening studs articulate perimeter.
 for j in [3,7,11,15]:
  t=j/(ny-1);w=.305*(math.sin(math.pi*(.13+.84*t))**.64);rivet((side*(w+.016),.20-t*.76,.52+.045*(1-t)),'shell')
 def surface(q,t,offset=0):
  w=.305*(math.sin(math.pi*(.13+.84*t))**.64)
  return (side*(.014+q*w),.20-t*.76,.52+.21*(1-q*q)*math.sin(math.pi*(.19+.77*t))+.045*(1-t)+offset)
 for t0 in [.17,.43,.72]:
  vs=[];fs=[]
  for j in range(5):
   for i in range(5):vs.append(surface(.48+.27*i/4,t0+.105*j/4,.007))
  for j in range(4):
   for i in range(4):
    a=j*5+i;f=(a,a+1,a+6,a+5);fs.append(tuple(reversed(f)) if side>0 else f)
  me=bpy.data.meshes.new('Conformed turquoise inset');me.from_pydata(vs,[],fs);me.update();p=bpy.data.objects.new('Turquoise enamel plate inset',me);bpy.context.collection.objects.link(p);finish(p,p.name,teal,'shell')
 for t in [.36,.63]:
  tube('Transverse shell seam',[surface(q,t,.003) for q in np.linspace(.02,.96,17)],.006,dark,'shell',6)
  tube('Raised red panel edge',[surface(q,t-.012,.010) for q in np.linspace(.02,.96,17)],.006,red,'shell',6)
 # central inset dark mechanical longitudinal seam is exposed between wing plates.
wing(-1);wing(1)
for s in [-1,1]:
 cyl('Dorsal vent neck',(s*.074,.037,.723),(s*.074,.037,.765),.019,steel,'shell',16)
 ring('Vent lip',(s*.074,.037,.766),.019,.0035,steel,'shell',(0,0,1),16)
 cyl('Dark vent centre',(s*.074,.037,.765),(s*.074,.037,.768),.013,dark,'shell',16)
# Thoracic collar and forward rounded insect head (no muzzle, nose or mammal ears).
ring('Collar',(0,.215,.525),.172,.032,dark,'belly',(0,1,0))
sphere('Round red head',(0,.36,.594),(.244,.192,.198),red,'head',32,16)
for s in [-1,1]:sphere('Brass facial fastener',(s*.066,.543,.645),(.008,)*3,brass,'head',8,4)
# Circular convex lenses with UVs laid radially onto generated depth-colour map.
for s in [-1,1]:
 center=Vector((s*.163,.492,.625));normal=Vector((s*.45,.89,.09)).normalized();u=Vector((0,0,1)).cross(normal).normalized();v=normal.cross(u)
 ring('Black optic socket',center,.097,.019,dark,'optics',normal)
 ring('Brass optic rim',center+normal*.015,.092,.009,brass,'optics',normal,32)
 vs=[tuple(center+normal*.059)];uvs=[(.5,.5)];fs=[];rn=7;sn=32
 for j in range(1,rn+1):
  rad=.083*j/rn;h=.044*math.sqrt(max(0,1-(rad/.09)**2))+.013
  for k in range(sn):
   th=T*k/sn;vs.append(tuple(center+normal*h+rad*(math.cos(th)*u+math.sin(th)*v)));uvs.append((.5+.5*j/rn*math.cos(th),.5+.5*j/rn*math.sin(th)))
 for k in range(sn):fs.append((0,1+k,1+(k+1)%sn))
 for j in range(rn-1):
  for k in range(sn):a=1+j*sn+k;b=1+j*sn+(k+1)%sn;fs.append((a,a+sn,b+sn,b))
 me=bpy.data.meshes.new('Radial optical cap');me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new('Convex lens',me);bpy.context.collection.objects.link(o);finish(o,'Convex lens',lens,'optics')
 for p in me.polygons:
  for li in p.loop_indices:me.uv_layers.active.data[li].uv=uvs[me.loops[li].vertex_index]
 # Rivet positions around facial edge.
 for a in [-1.25,0,.85,2.05]:rivet((s*.205*math.cos(a),.492,.60+.143*math.sin(a)),'head',.007)
 # two hard little feeding mandibles under the face, clearly mechanical insect.
 tube('Mandible',[(s*.05,.507,.497),(s*.07,.537,.453),(s*.035,.55,.438)],.014,dark,'head')
# Antennae taper in sweeping curves, each own pivot for idle sway.
antennae=[]
for s in [-1,1]:
 origin=(s*.085,.365,.757);p=empty('Antenna_'+('L' if s<0 else 'R'),origin,body);g='antenna'+str(s)
 cyl('Antenna socket',(s*.085,.365,.735),origin,.021,dark,'head')
 coords=[]
 for i in range(13):
  t=i/12;coords.append((s*(.085+.14*t+.025*t*t),.365+.095*t,.757+.232*t-.035*t*t))
 tube('Swept red antenna',coords,.0085,red,g);sphere('Antenna sensor tip',coords[-1],(.024,.020,.021),red,g,16,8);parts[g+'_parent']=p;antennae.append(p)
# Four articulated insect legs: short anterior stabilisers and powerful folded posterior jumpers.
legs=[];knees=[];ankles=[]
for s,label in [(-1,'L'),(1,'R')]:
 for idx in [0,1]:
  if idx==0:
   hip=(s*.22,.20,.405);knee=(s*.35,.30,.255);ankle=(s*.43,.37,.095);foot=(s*.465,.42,.047);radius=.037
  else:
   hip=(s*.265,-.22,.427);knee=(s*.51,-.39,.52);ankle=(s*.52,-.21,.105);foot=(s*.61,-.19,.047);radius=.059
  p=empty('Leg_'+label+'_'+str(idx),hip,root);kp=empty('Knee_'+label+'_'+str(idx),knee,p);ap=empty('Ankle_'+label+'_'+str(idx),ankle,kp);legs.append((p,idx,s));knees.append((kp,idx,s));ankles.append((ap,idx,s))
  gu='upper'+label+str(idx);gl='lower'+label+str(idx);gf='foot'+label+str(idx)
  sphere('Hip rubber seal',hip,(radius*1.05,)*3,dark,gu,16,8)
  cyl('Femur',(Vector(hip)*.90+Vector(knee)*.10),(Vector(hip)*.16+Vector(knee)*.84),radius,red,gu,12)
  # Raised smaller ridge gives substantial red armour on large rear thigh.
  if idx==1:
   tube('Femur ridge',[Vector(hip)+Vector((0,0,.02)),Vector(knee)+Vector((0,0,.02))],.025,red,gu)
  cyl('Upper joint pin',Vector(knee)-Vector((.032,0,0)),Vector(knee)+Vector((.032,0,0)),radius*.7,steel,gu,16)
  cyl('Tibia',(Vector(knee)*.88+Vector(ankle)*.12),(Vector(knee)*.18+Vector(ankle)*.82),.030 if idx==0 else .037,red,gl,12)
  # Exposed polished piston and dark zig-zag spring assembly.
  a=Vector(ankle)+Vector((0,0,.009));b=Vector(ankle)+Vector((0,0,.069));cyl('Spring core',a,b,.013,steel,gl)
  coil=[]
  for i in range(65):
   t=i/64;th=T*t*4.2;coil.append(tuple(a+(b-a)*t+Vector((.022*math.cos(th),.022*math.sin(th),0))))
  tube('Ankle coil',coil,.0055,dark,gl,6)
  cyl('Ankle axle',Vector(ankle)-Vector((.020,0,0)),Vector(ankle)+Vector((.020,0,0)),.020,steel,gf)
  # Wedge tarsus has a low pointed metal toe and an enamel heel.
  b=Vector(foot);direction=Vector((s*.5,.866,0));cross=Vector((.866,-s*.5,0));width=.066 if idx else .055
  points=[]
  for z,long,w in [(-.042,-.062,width),(-.042,.10,width*.40),(.035,-.062,width),(-.008,.10,width*.40)]:
   points.extend([tuple(b+direction*long+cross*w+Vector((0,0,z))),tuple(b+direction*long-cross*w+Vector((0,0,z)))])
  faces=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
  me=bpy.data.meshes.new('Pointed tarsus');me.from_pydata(points,[],faces);me.update();o=bpy.data.objects.new('Pointed foot armour',me);bpy.context.collection.objects.link(o);finish(o,o.name,red,gf);o.data.materials.append(steel)
  for poly in me.polygons:
   if poly.index in [3]:poly.material_index=1
  mod=o.modifiers.new('Rounded toe edges','BEVEL');mod.width=.008;mod.segments=2;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
  parts[gu+'_parent']=p;parts[gl+'_parent']=kp;parts[gf+'_parent']=ap
# Visible side hinge discs, pneumatic barrels, and small brass fasteners.
for s in [-1,1]:
 for y,z,r in [(.01,.45,.059),(-.20,.43,.044)]:
  ring('Steel body hinge',(s*.29,y,z),r,.009,steel,'belly',(s,0,0),20);cyl('Dark hinge axle',(s*.292,y,z),(s*.304,y,z),r*.68,dark,'belly',16)
 for y,z in [(.10,.50),(-.08,.39),(-.32,.45)]:sphere('Brass fixing',(s*.298,y,z),(.009,)*3,brass,'belly',8,4)
# Join parts that share one rigid motion. No material or per-rivet node overhead.
for group,objects in list(parts.items()):
 if group.endswith('_parent'):continue
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=bpy.context.object;o.name=group+'_mesh'
 parent=parts.get(group+'_parent',body)
 bpy.context.view_layer.update();world=o.matrix_world.copy();o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted();o.matrix_world=world
# Bake actual rigid transform actions into NLA tracks, grouped by clip name at export.
bpy.context.scene.render.fps=30
animated=[body]+antennae+[x[0] for x in legs]+[x[0] for x in knees]+[x[0] for x in ankles]
rest={o:(o.location.copy(),o.rotation_euler.copy()) for o in animated}
for clip,seconds in [('Idle',2.0),('Walk',1.0),('Swim',1.0),('Attack',.8)]:
 count=int(seconds*30)
 for o in animated:
  o.animation_data_create();act=bpy.data.actions.new(clip+'_'+o.name);o.animation_data.action=act
  for f in range(0,count+1,2):
   t=f/count;loc,rot=rest[o];o.location=loc;o.rotation_euler=rot
   if o==body:
    if clip=='Idle':o.location.z+=.006*math.sin(T*t)
    elif clip in ['Walk','Swim']:o.location.z+=.009*(1-math.cos(2*T*t))/2;o.rotation_euler.y=.022*math.sin(T*t)
    else:o.location.z+=.065*math.sin(math.pi*t)**2;o.rotation_euler.x=-.14*math.sin(math.pi*t)**2
   elif o in antennae:
    o.rotation_euler.y=.04*math.sin(T*t+(0 if o==antennae[0] else math.pi)) if clip!='Attack' else .18*math.sin(math.pi*t)**2
   else:
    record=next((r for r in legs if r[0]==o),None);kr=next((r for r in knees if r[0]==o),None);ar=next((r for r in ankles if r[0]==o),None);q=record or kr or ar;_,idx,s=q
    phase=T*t+(0 if (s<0)==(idx==0) else math.pi)
    if clip=='Idle':o.rotation_euler.y=.009*math.sin(T*t)*s
    elif clip in ['Walk','Swim']:
     if record:o.rotation_euler.x=.19*math.sin(phase);o.rotation_euler.y=.03*math.cos(phase)*s
     elif kr:o.rotation_euler.x=-.23*max(0,math.sin(phase))
     elif ar:o.rotation_euler.x=.10*math.sin(phase)
    else:
     a=math.sin(math.pi*t)**2
     if record:o.rotation_euler.x=(.40 if idx==1 else -.16)*a
     elif kr:o.rotation_euler.x=(-.58 if idx==1 else .22)*a
     elif ar:o.rotation_euler.x=.15*a
   o.keyframe_insert('location',frame=f);o.keyframe_insert('rotation_euler',frame=f)
  track=o.animation_data.nla_tracks.new();track.name=clip;strip=track.strips.new(clip,0,act);track.mute=True;o.animation_data.action=None
for o,(loc,rot) in rest.items():o.location=loc;o.rotation_euler=rot
bpy.context.scene.frame_set(0);bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'eco_hopper.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'eco_hopper.glb'),export_format='GLB',export_yup=True,export_animations=True,export_cameras=False,export_lights=False,export_animation_mode='NLA_TRACKS',export_merge_animation='NLA_TRACK',export_materials='EXPORT')
print('HOPPER EXPORT COMPLETE')
