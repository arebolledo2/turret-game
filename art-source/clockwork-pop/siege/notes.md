# Clockwork siege — frozen candidate

Final iteration: **3**. Three of the permitted eight harness runs were used. All three passed the contract using the run-local `contract.json` with `origin_node: "Aim"`. The base origin remains `(0, 0, 0)` on the ground; the asymmetric forward barrel shifts the overall bounds centre to Y = 0.157 m, so validation correctly checks the actual yaw pivot.

## Construction and iteration

- Iteration 1 established the wheeled teal carriage, coral breech, brass open barrel and pointed ivory shell. The model passed, but the muzzle was too narrow, the colors looked pale, and the supports looked like round fenders. It used 16,128 triangles.
- Iteration 2 widened the muzzle to 0.70 m across, strengthened coral and teal saturation, made the front carriage taller, and replaced the side support circles with bevelled sculpted plates. It passed at 15,752 triangles.
- Iteration 3 added a script-generated 256 × 128 brushed-brass color texture and a brass shell fuse. It reduced minor cylinder bevels from two segments to one, retaining smooth major silhouettes and passing at 13,704 triangles.

## Final metrics

- 13,704 triangles, 10 mesh objects, 10 used materials.
- Dimensions: 1.725 m X × 1.955 m Y × 1.376 m Z; lowest point 0.000 m.
- One embedded generated brass color texture, 256 × 128. No external images or models.
- No armature, no exported animations. Rigid meshes and pivots are ready for runtime motion.
- `Aim` is an identity-rotation yaw pivot at `(0, 0, 0.79)` in Blender metres; it carries the cradle and breech.
- `Barrel` is a separate recoil pivot under `Aim`, local `(0, 0.065, 0.235)`, carrying `RecoilBarrelMesh`. Animate its local Y position to recoil.
- Bare `Muzzle` is directly under `Aim`, local `(0, 1.135, 0.235)`, world `(0, 1.135, 1.025)`, identity rotation and +Y forward. It has no children or geometry.
- Four complete named wheel meshes have origins at their individual axle centres, and the shell is a separate rigid mesh. The shell rack and main carriage remain static under `SiegeRoot`.

The triangle advisory overrun is deliberate: the four rounded wheels account for 4,816 triangles, the coral breech and its substantial smooth bands for 2,392, and the hollow barrel for 1,824. Rounded bevels on the supports, chassis, rack and pointed shell preserve the polished toy-like style. Material and object targets are met. Simplifying these farther is a later visual/performance decision.

## Remaining differences and score

The reference has hand-painted reflections, richer surface variation and stronger glossy turquoise highlights. The candidate has cleaner, more regular manufactured surfaces. The reconstructed underside and rear are sensible inventions from the single view. The requested shell intentionally differs from the reference pot and is narrower and taller. The harness's three-quarter view sees the shell on the far side, whereas the reference view prominently shows it on the near side. The brass texture is subtle and the reference's irregular painted sheen is not reproduced fully. No game integration was performed by this asset agent; the parent handles it.

Self-score: **8/10**. Strong recognizable silhouette, readable colors and requested shell substitution, a genuinely deep open muzzle, and correct rigid-part hierarchy; painterly surface fidelity remains below the concept.

Final export and source are frozen at iteration 3. `metrics.json` records the final validation and hierarchy audit. `frozen_manifest.json` records SHA-256 hashes of the GLB, builder, generated texture, local contract, metrics and these notes.
