# cp_thunder_pin-v1: notes

**Iterations used:** 8 of 8. The contract passes on iteration 8.

## Approach
- I built all geometry in bmesh:
  - lathed surfaces of revolution with rounded profile corners for the collars, rings, cone, jewels, neck, column and hex plinth/pedestal (6-segment lathe)
  - rounded boxes for the capacitor box, the coral bands and the faceted brass feet
  - a swept helix for the black spring
- The script generates 4 textures at 1024 px: base colour, ORM, normal and emissive. Each is a 4x4 atlas of material cells. Lathed parts unwrap around and along their profile, so brass brushing runs around the rings and the jewels shade from a deep rim to a bright crown. Box parts use a dominant-axis projection into their cell. All images are packed into the GLB and also saved beside the script as PNG.
- The ten materials share the atlas. The jewels have clearcoat plus a low emissive. The ivory tip has a light coat.
- The final step merges meshes per (Base or Head) x material, which gives 15 objects. Aim sits at (0,0,0.58) with identity rotation and carries everything that rotates. Muzzle is an empty at the pin tip, (0, 1.155, 0.87) in world space.

## What failed and how I fixed it
- **Iter 1:** `origin_xy_centred` failed because the bounds centre was 0.28 m forward.
  - Iters 2-6 worked around it by sliding the head back and shortening the lance. That hurt the proportions.
  - After the coordinator set `origin_node: Aim`, I put the head back over the column (HEAD_DY = 0) and gave the lance its full length.
- **Coral bands looked like flat frames.** A uniform bevel with clamping squared off the corners. I now give the Y-parallel edges a large rounding that follows the box, and the rest a small rounding.
- **Ivory looked pitted.** The orange-peel normal was too strong, so I reduced it.
- **Brass looked dull and brownish** under the render lights. I brightened it, set metallic to 0.75 and lowered roughness.
- **Too heavy:** 37k triangles and 59 objects. I applied a global tessellation factor and fewer rounding/dome steps, then merged by material. The result is 17.4k triangles and 15 objects.
- **Iter 7: merged parts turned grey.** The bmesh UV layers had different names, so join dropped some UVs. I now use the single layer name "UVMap" everywhere.

## Remaining flaws vs the concept
- The brass reads less saturated and shiny than the painted concept. The harness render has no environment reflections, and metallic surfaces suffer most.
- Jewels render paler than the concept. The emissive was already lowered.
- The shaft is still slightly thinner and shorter than the concept's lance.
- The feet are 3 brass blocks at 120° as the brief asks. The concept shows them at square corners.
- The pedestal violet studs are small at gameplay distance.
- There is no vertex-colour AO.

## Final counts
- 17,384 triangles
- 15 mesh objects
- 10 materials
- 4 textures at 1024x1024

## Self-score: 7/10
