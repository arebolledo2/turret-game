# cp_thunderhead-v1 notes

## Iterations
6 runs of run_eval.py (iter01-iter06); contract passed on every run, including the final one.

## What changed and why
- Build 1 (iter01) came out squat. I re-measured the concept (isometric, plate width as the unit) and found it is a tall
  tower, about 2:1 height to plate width. I rebuilt it in concept-scale metres and applied a global scale of 0.58 so the
  height lands at 1.52 m. Footprint is 0.88 x 0.96 m.
- The drums are not on a 120-degree triangle. In the concept they form an arc (front plus two flanking, back open). I placed
  them at 90, 32 and 148 degrees, and added a dark-teal core pillar with brass bands and rivets so the invented back looks
  designed.
- First textures exported all black. `colorspace_settings` was changed after `pixels.foreach_set`, which resets a generated
  image. Fixed by setting the colourspace first.
- Cloud: a metaball version looked like a potato. I replaced it with overlapping spheres, voxel-remeshed and lightly
  relaxed, which gives distinct puffs and soft blends. It still reads a little like a flower.
- The checker uses AgX, which washed out the albedos (khaki brass, dull teal). I pushed albedo saturation up and lowered the
  brass metallic value. Large flat enamel faces also threw a big white sun patch, so I raised their roughness.
- Normals: rounded rims were tilting the normals across big flat faces (dished drum tops and plate). Fixed with custom
  per-corner normals. Horizontal caps and large faces keep a true flat normal, and everything else smooths within 35 degrees.
- Orb: flattened to a cabochon (Y x 0.68) and set into the cloud face, after it first read as a ball stuck on the front.

## Construction
- Everything is written to `build_cp_thunderhead.py` with bmesh lathe profiles (filleted), helix sweeps for the springs
  and coil, and beveled prisms and boxes.
- `Aim` sits at the underside of the teal drum with identity rotation. It carries the teal drum, brass bands/rim/well,
  violet jewels, lugs, rivets, coil, collar, cloud and orb. `Muzzle` is a bare empty under `Aim`, in front of and above the
  orb. The plate, three coral drums, springs, washers, core and feet are static.
- Textures: 4 images at 1024x1024, packed into the GLB. There are two albedo atlases (enamel: teal, coral, cream, dark teal;
  trim: brass, blackened steel, cyan gem, violet gem) and two matching ORM atlases (G = roughness, B = metallic). Each atlas
  is 2x2 tiles of 512 px. UVs are box, mirrored-cylindrical, or planar (gems), scaled into each part's tile.
- The orb is emissive, driven by the violet gem map at strength 0.7.
- Per-vertex ray-cast ambient occlusion is stored as COLOR_0 (floor 0.7, lighter on cream and orb).

## Final counts
- Triangles: 74,800
- Mesh objects: 12
- Materials: 9
- Textures: 4 at 1024x1024
- Size: 0.878 x 0.958 x 1.524 m, min z = 0.0

## Remaining flaws vs concept
- The cloud silhouette is slightly flower-like and flatter-lobed than the concept's three-bump cloud. It also renders greyer
  than the warm cream in the checker.
- Texture density is only roughly consistent. Cylinder wraps are mirrored and stretched, and the plate uses a coarser scale.
- Nothing carries real surface relief (no normal maps), so the concept's soft painted highlights are only suggested by the
  gloss. Brass reads slightly flatter and tan under AgX.
- The concept's drums and teal drum are a touch chunkier and the stack tighter. Feet are plain bevelled blocks.
- The back is invented: open arc with the core pillar, no fourth drum.
- The glass-like cyan and violet jewels carry a baked glint. It is subtle, but not view-dependent.

## Self-score
7/10
