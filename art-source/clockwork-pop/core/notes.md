# Clockwork Reactor Core — frozen candidate

Direct 3D concept, explicitly authorized without a 2D reference. One geometry build iteration. No borrowed reference image, textures, animation clips or transparent shells.

## Promoted source

This directory preserves the builder, editable Blender source, contract, audit results and this generation record. The reviewed game export is `assets/models/clockwork/cp_core.glb`; runtime captures and animation are in `doc/art/clockwork-pop/previews/core-*`. The file list below describes the original external run (`3d-eval/runs/cp_core-v1/`), where studio renders and helper scripts remain. Godot integration was subsequently verified with all 865 tests passing (9,789 assertions), plus the resource audit.

## Original generation-run files

- `build_cp_core.py`: deterministic Blender 5.2 builder; writes its source/export into this directory.
- `cp_core.glb`: self-contained game export, 420,488 bytes.
- `cp_core.blend`: editable source, 310,454 bytes; all materials embedded, no external dependencies to pack.
- `contract.json`: custom grounded prop contract.
- `validate.json`: standard harness result, all required checks pass.
- `node_audit.json`: exported node hierarchy, clean UV and arbitrary-rotation envelope audit; all checks pass.
- `renders/iter01/`: front, three-quarter, right side, back and top views of the actual GLB.
- `hero.png`: 1200px presentation render of the actual GLB on a contrasting studio floor.
- `render_hero.py`, `audit_contract.py`: reproducible presentation and additional verification scripts.

GLB SHA-256: `c8839ab7870abbe2761a1f3a1ed8dbc126539275c9a3268caf30cf1ab681758b`.

## Appearance and scale

Three concentric gyroscope hoops, smooth teal enamel faces, brass edge bands, raised calibration tabs, hexagonal gold bolts, repeated luminous cyan inlays and small coral accents. A dark navy stepped pedestal anchors the floating magnetic assembly. The opaque cyan UV sphere is deliberately clean for replacement by the runtime procedural plasma shader.

- 21,176 triangles; 5 mesh nodes; 7 used materials; 22 material primitives/surfaces.
- 0 embedded texture images; 0 animation clips.
- Rest bounds: Blender X/Y/Z = 1.480 / 1.149 / 1.640 m; Godot X/Y/Z = 1.480 / 1.640 / 1.149 m.
- Ground minimum = 0.000 m; root origin = ground center.
- Pedestal diameter = 1.100 m, matching gameplay radius 0.55 m; top = 0.1477 m.
- Orb radius = 0.325 m; orb/pivot center = Godot `(0, 0.9, 0)`.
- Main ring radii = 0.70, 0.59 and 0.48 m.

The 21.2K triangle count exceeds the advisory 20K target by 1,176, within the authorized 15K–25K hero-prop range. Smooth large ring silhouettes, two raised metal edge bands per hoop and two faces of inlays/bolts account for the count. The singleton prop has only five mesh nodes; its multi-material surfaces still produce up to 22 material draw surfaces before engine optimization.

## Exact exported node contract

All five named contract nodes are roots in the GLB scene. All use unit scale and identity rest rotation.

| Root | Godot translation | Type | Child | Runtime rotation |
| --- | --- | --- | --- | --- |
| `Body` | `(0,0,0)` | Empty/Node3D | `Pedestal` | Static |
| `Ring_Outer` | `(0,.9,0)` | Empty/Node3D | `Ring_Outer_Hoop` | Local Y |
| `Ring_Middle` | `(0,.9,0)` | Empty/Node3D | `Ring_Middle_Hoop` | Local X |
| `Ring_Inner` | `(0,.9,0)` | Empty/Node3D | `Ring_Inner_Hoop` | Local Z |
| `Orb` | `(0,.9,0)` | Mesh | None | Material replacement |

Child mesh geometry contains the authored tilts, not the pivot transforms. In Blender: Outer X tilt 90°, yaw 0°; Middle X tilt 58°, Z yaw 62°; Inner X tilt 68°, Z yaw -48°. glTF exports Blender Z-up as Godot Y-up. The suggested runtime axes produce visible tumbling because they differ from each authored plane normal.

`Orb` uses exactly one UV map from the untouched Blender UV sphere primitive, 48 longitude segments and 24 latitude rings. Its only assigned material is `CW_OrbReplaceable`. Replacing surface 0 is safe. No decorative mesh is joined into it, and its center/origin coincide.

## Rotation clearance verification

Audited radial vertex envelopes, independent of ring rotation:

| Ring | Minimum radius | Maximum radius |
| --- | --- | --- |
| Outer | .666331 m | .740068 m |
| Middle | .556396 m | .630079 m |
| Inner | .446494 m | .520096 m |

Outer–middle minimum clearance: .036252 m. Middle–inner: .036300 m. Inner–orb: .121494 m. Outer sphere envelope remains .012232 m above the highest pedestal point even at arbitrary rotation. Thus the rings, orb and base do not intersect under the documented controller axes or any rigid pivot rotation about their shared center. The maximum rotating diameter is 1.480136 m, within the 1.65 m contract.

## Verification and limitations

Standard harness validation passes all 10 checks. The additional audit confirms root parenting, identity rest rotations, sphere UVs and disjoint motion envelopes. All five harness views and the hero image were visually inspected. Parent integration reports working imported pivots and plasma replacement in Godot, close/game camera and critical/dead visual review, plus 15 focused core tests passing; engine integration is owned by the parent task.

The Blender hero render shows the simple authored orb material; the richer plasma is created at runtime in Godot. Metal bands can show small tessellation/normal highlights in close studio reflections. Tiny bolts become secondary accents at gameplay distance. No baked ambient occlusion or texture detail is provided. No frame-time benchmark was requested or performed. Source-level materials are portable glTF PBR; emission glow depends on the game's rendering environment.
