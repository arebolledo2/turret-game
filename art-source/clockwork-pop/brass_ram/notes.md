# Brass Ram candidate

Final export: `eco_ram.glb`; source: `build_eco_ram.py` and `eco_ram.blend`.
Reference: `3d-eval/ref/eco_ram.png`, inspected before construction.

Used 3 of the allowed 8 harness evaluations. Iteration 1 passed scale, ground,
origin and pivot checks but only exported Attack: clearing animation data before
each clip also removed the earlier NLA tracks. Preserving tracks fixed this.
Custom plates originally used a differently named UV layer; joining them with
primitive meshes sampled the brass atlas region. A single shared UV layer name
fixed the burgundy elytra and chest. Iteration 2 passed all checks and established
the large hooked horn silhouette. Iteration 3 rounded the cloven feet and reduced
secondary-part tessellation; every contract check still passes.

Final counts: **27,792 triangles, 15 mesh objects, 8 materials**. Dimensions:
**1.578 x 1.521 x 1.671 metres**, lowest point **0.002m**. Body and all four
Leg_L_0/1 and Leg_R_0/1 empties carry geometry. Horn_L/R, knee and ankle child
pivots provide rigid articulation. Root remains stationary.

Two generated and embedded 1024 x 1024 images: shared palette/base-color atlas
and roughness atlas. Materials distinguish brass, oxblood enamel, graphite,
steel, amber lenses and small teal pressure gauges. No externally sourced images,
models, skeleton or external texture references.

Clips: **Idle 2.0s; Walk 1.0s; Swim 1.6s; Attack 1.0s**. Idle, Walk and Swim have
matching endpoint transforms; Attack bends the forehead/horns into a short ram
and returns to the rest pose. Loop selection is a playback/import setting; glTF
does not store a universal loop flag. `animation_audit.json` checks actual
exported rigid-transform channels, endpoints and embedded payload.

The 12,000-triangle advisory target is exceeded to retain round forged horn
sections, brass shield rims, curved elytra, deep eye apertures and numerous
separate piston bearings. Mesh and material advisory targets are respected.
Visual acceptance and selective later optimization should precede crowd testing.

Remaining differences: the reference is more bulbous and hand-painted; this
candidate has a more mechanical integrated insect visor, symmetrically hooked
horns and straighter lower pistons. Its unseen back is invented with dark exhausts
and a broad paired elytra seam. Brass reads darker than the brightest reference
highlights under the harness lighting, and amber emission reads pale. The body
has no separate canine muzzle, ears, tail or mammalian limb anatomy.

Self-score: **7.8/10**. Reviewed the final six-tile compare image critically.
Godot import, runtime clip playback and animated preview remain with the parent
task; no files outside this run folder were written and no game files were edited.
