# cp_drone_bay-v1 notes

Iterations used: 7 of 8 (final = iter07, contract passed).

## What failed and how it was fixed
- iter01: the script mixed Aim-local and world coordinates for head parts, so the head floated below ground (height 0.96, min z -0.045). Head parts are now authored Aim-local and the other parts in world space.
- iter02: `muzzle_in_front_and_raised` failed because the tower sat too far back (Muzzle y only 0.09). Moved the tower/tunnel layout forward and the Muzzle to the head front (y about 0.26).
- iter03: contract passed. The view mapping (+X appears on the left in the front view) showed the drones, pipe-and-ball, pod and indicator panel were mirrored against the concept, and the right drone hid the panel. Mirrored them, moved the panel to the camera-facing side, enlarged the head, drones and tunnel.
- iter04 to iter07: raised the tower and head, made the eyes and dome ring larger, added an inner coral lip and tile pad, cut the segment counts, and made the dome dark and glossy.

## Structure
- Static base: slate, coral, mint, cream, tunnel, tower, drones and arms.
- `Aim` sits at the tower's vertical axis with identity rotation and carries the head parts (teal sphere, side pods, brass lens rings, glass lenses, dome, antenna, bulb). `Muzzle` is a bare empty under `Aim` at the head front.
- Drone body parts hang under `Drone_Wire` and `Drone_Arm` empties. Each drone's propeller blades are a separate object so they can spin.

## Remaining flaws vs concept
- No texture or surface detail (flat colours only).
- Tunnel interior is a plain dark plum liner; the concept has inner doors and arches.
- Brass trim and the drone dishes are simpler than the concept; the white pearl, step and tile seams are minimal.
- The tower indicator panel and lens are small and sit on the far side from most views.
- The base looks glossy and pale at grazing angles in the checker.

## Final counts (advisory targets exceeded on purpose)
- Triangles 27,976 (target 5,000); mesh objects 29 (target 16); materials 13 (target 10).
- Overrun reasons: smooth lathe-built forms (spheres, rounded rings, 80-segment base), many small brass fittings, one object per material per assembly for runtime animation (Aim head, drone propellers), and glass, glow and tile colours kept as separate materials.
- Size 2.367 x 2.299 x 1.672 m; min z 0.0. GLB is 614 KB.

## Self-score
7/10. Silhouette, colours, proportions and layout match the concept well. It is under-detailed in the tunnel interior and tower details, and far over the triangle budget.

## Iteration 10 (triangle reduction, added after the agent run)
- Final = iter10 (iter08 and iter09 were intermediate reduction steps). Contract still passes; the compare renders are visually unchanged from iter07.
- Build script change only: `lathe` sides, `sphere`/`dome` rings and `rr` corner arcs now follow the part size (small brass fittings, studs and drone parts get far fewer sides than the base disc and head), and the tunnel arches use 14 instead of 24 points. The pre-reduction script is kept as `renders/iter07/build_cp_drone_bay.py`.
- Triangles 27,976 -> 12,246. Mesh objects (29) and materials (13) unchanged; size unchanged (2.367 x 2.299 x 1.672 m).
