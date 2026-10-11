# Ratchet Sentry — cp_machine_gun-v1

Final accepted and frozen iteration: **6**. Six harness executions, under the eight-run limit. I inspected every compare render and personally reviewed final `renders/iter06/compare.png` after export.

## Construction and contract

Metres, Blender +Z up, weapon +Y forward. Base centered at X/Y zero and feet touch Z=0. `Aim` is a bare empty at `(0, 0, 0.68)` with identity rotation, carrying the full receiver, optics, jacket, barrel, and muzzle hardware. The static pedestal, tripod, and shoulder bearings remain outside Aim. `Muzzle` is bare, parented under Aim, at world `(0, 1.007, 1.0)`, with identity rotation and +Y forward. Rigid assemblies only; no armature or animation. The three legs and side optic assemblies are separate meshes, while decorative fasteners are grouped with their rigid assemblies.

The model uses a rounded teal enamel receiver, genuinely perforated brass thin-wall jacket, one long hollow graphite barrel, concentric open brass muzzle, coral side and top optic drums, faceted blue-violet jewel lenses, brass shoulder bearings, and a splayed tripod with rubber pads. Unseen rear details are invented: a connector socket, charging grip, and four cooling fins. One **256 × 256 generated sapphire texture** is embedded in GLB and packed in the Blender source; no outside images or models are used.

## Iterations

1. Built the complete model. Failed ground gap and bounds centering: joined angled leg objects retained rotated bounding frames, producing misleading minimum Z and overly wide footprint. The forward barrel also placed total-bounds center just beyond tolerance. 40,480 triangles, 14 meshes, 9 materials.
2. Applied mesh rotations before rigid assembly joining, welded coincident jacket vertices, aligned base and Aim with the real X/Y origin, and extended the sensible rear connector. All contract checks passed. 40,088 triangles.
3. Reduced small hardware tessellation and bevel subdivisions while keeping the receiver smooth. Added brass shoulder bearings and strengthened teal/coral/brass saturation. 27,664 triangles; all checks passed.
4. Broadened the cooling jacket to better match the reference, exposed the coral front hip by shifting the service block, and lowered pads to exact ground contact. All checks passed; minimum Z=0.
5. Replaced simple colored lens facets with a generated embedded sapphire map and a more convex cap. All checks passed, but render inspection found the correct optic UV data was not the joined assembly's active UV layer.
6. Named the optic UV layer consistently with the assembly's UVMap before joining. Final sapphire reflection exports correctly. All checks pass.

## Final measurements

- **27,664 triangles**; **14 mesh objects**; **7 used materials**.
- Bounds: **0.914 × 1.743 × 1.331 m** (X/Y/Z).
- Minimum Z: **0.000 m**.
- Total bounds center X/Y: **0.000 / 0.136 m**; actual base and Aim axis remain X/Y zero.
- One embedded 256 × 256 image; no animations.
- Required nodes, parent hierarchy, height, footprint, ground gap, origin tolerance and raised forward muzzle all pass.
- Advisory overrun: triangle target 5,000 exceeded by 22,664. Real jacket perforations alone use 5,760 triangles. Rounded hardware, open concentric tubes, polished receiver corners and repeated tripod fittings account for the rest. Mesh-object and material targets are met. This is a quality-first candidate; a dedicated low-detail or LOD pass could reduce many fittings after visual acceptance.

## Remaining limitations and score

**Self-score: 8/10.** The recognisable silhouette, colors, functional nodes and mechanical details are strong. The concept has fuller, more organic inflation of the receiver and a more luminous lens; the checker makes the brass reflections pale. The rear is invented from the single view and slightly extended to satisfy the supplied asymmetric-bounds test. Cooling apertures are regular rather than subtly staggered like the illustration. The generated lens reflection is painted into its small texture, so that part of the jewel highlight remains fixed as the turret rotates. No AO bake, LOD generation, animation clip, Godot import, or gameplay test was done; the task explicitly confines writes to this run folder and excludes game edits. No crowd performance claim is made.

## Frozen files

`frozen/iter06/` contains the exact final build script, packed `.blend`, self-contained `.glb`, `validate.json`, `compare.png`, `contract.json`, and `audit.json` with SHA-256 hashes. The run root also retains the final script/export/source. `renders/iter06/` retains the full five views and harness logs.
