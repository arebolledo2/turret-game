# Clockwork Arrow Projectile — frozen iteration 1

Built and reviewed one harness iteration. The contract passed on the first run with no failed checks or advisory overruns, so no geometry repair was needed. Inspected all five rendered views in `renders/iter01/compare.png` before freezing the export.

This is a standalone projectile, derived solely from the reference's brass shaft and ivory point/fletching and the promoted bow's authored palette. It has one faceted diamond-section ivory triangular point, three evenly spaced solid ivory vanes, two coral binding wraps with thin brass lips, and a bifurcated brass nock with a real string slot. There is no turret, bow, pedestal, external texture, armature, or animation.

## Final metrics and flight contract

- 3,280 triangles, one mesh object, four materials; zero images and zero animation clips.
- Dimensions: 0.121 m X × 0.650 m Y × 0.114 m Z. Minimum Z: −0.045 m.
- Explicit `FlightRoot` empty and `Arrow` mesh both have origin `(0, 0, 0)`.
- Blender forward is +Y; point ends at +0.325 m and nock ends at −0.325 m. Bounds center is zero in X/Y, and the shaft runs through Z=0.
- All arrow components are merged into one rigid mesh for actual game flight.
- The exporter/harness reports 60 loose components after glTF import; this includes the split hard-edge surface islands. This is a rigid projectile, not an articulated assembly.
- No advisory target overruns. The complete reproducible builder, `.blend`, `.glb`, authored metrics, validator output, and render comparison remain in this run folder.

## Visual review and limitations

The shaft, broad point, and three radial fins read cleanly in the side, top, and three-quarter views. Coral binding stays visible at either end of the vanes. The front and rear views necessarily foreshorten the arrow; the three fins remain identifiable as separate spokes. The ivory reads cooler and less saturated in the harness's neutral studio lighting than in the pink-background reference.

The concept depicts a turret and does not expose the actual tail; the standalone fletching and nock are sensible authored extrapolations. The arrowhead is intentionally broad and the fins exaggerated to meet the requested 0.12 m readable width. Exact projectile appearance at gameplay camera distance remains for the parent integration review. No game files were touched and no Godot import was run by this asset agent.

Self-score: **8/10** for a clear standalone arrow matching the collection palette and requested flight contract, with the unavoidable unseen-tail extrapolation and unverified gameplay-distance readability.
