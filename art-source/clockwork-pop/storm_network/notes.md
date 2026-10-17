# cp_storm_network-v1 notes

Iterations used: 5 of 8 (final iteration 5 passes the contract).

## Approach
- Everything is built from bmesh lathes/sweeps (rounded-hex tower body, torus rings, helix spring, icosphere gems, offset-outline clover base), with fillet arcs in the profiles instead of bevel modifiers.
- One shared material `Storm_Atlas` with four generated 1024x1024 images: albedo, metal/roughness (G/B), normal, emissive (violet gems only, dim). Parts are UV-mapped into 256 px atlas cells (u = angle around the part axis, v = world height; gems get per-facet random cells), so texel density is uniform.
- Vertex-colour AO (COLOR_0) baked with a BVH ray cast.
- Hierarchy: `StormNetwork` > `Base_Static`, `Aim` (at the turret axis, identity rotation) > `Aim_Tower_A/B/C`, `Aim_Bridge`, `Muzzle` (tip of tower A's gem, tower A is the +Y-most tower).

## What failed and how it was fixed
- Iter 1: spring windows were not cut (extrude_face_region keeps the originals); fixed by deleting the original and floor faces and flipping the lip walls.
- Iter 1/2: towers were too squat and fat versus the concept (height/width ~2.7 vs ~3.8); radii were shrunk about 25 percent, coil lengthened to 7 rings.
- Gems read pale lavender and unfaceted; changed to per-facet random atlas cells, deeper albedo, lower emissive, and a larger gem set higher on the coil.
- Iter 5 polish: more saturated teal and coral, brass ear brackets on the hex corners, a heavier toothed bridge, a larger front jewel.

## Remaining flaws versus the concept
- Concept gems are glassier and brighter, with many small facets and strong highlights. Mine are opaque faceted icospheres, with an AgX-desaturated look in the checker.
- The concept spring is a chunky coil with visible turns across a wider window. Mine shows 3 to 4 thin turns in a narrow slot.
- The concept bridge teeth are a distinct comb. Mine is a rod with small trapezoid teeth, readable only at close range.
- The base top is paler and glossier than the concept's saturated teal in the checker lighting. The concept base has a slightly thicker tiered edge.
- The towers (feet through gems) all rotate as Aim, which includes the foot rings and brass feet, so they sweep over the static base. This was chosen over leaving static posts that would not align.
- Triangle count is high (about 118k) for a game prop. The coil tori and tower revolves could be decimated if needed.
- The brass reads a little dull under the checker's grey world lighting.

## Final counts
- Triangles: 118,208
- Mesh objects: 5 (Base_Static, Aim_Tower_A, Aim_Tower_B, Aim_Tower_C, Aim_Bridge)
- Materials: 1
- Textures: 4 (1024x1024)
- Size: 1.293 x 1.209 x 1.577 m, min z = 0.0

Self-score: 7/10.
