# Rivet Skitter / eco_skitter-v1

Two harness iterations used. Final iteration 2 passes all mandatory checks.

This is the requested tiny beetle summon derived from the parent reference's palette, rather than a reproduction of the capsule carrier. Compact split pistachio enamel wing covers, plum underside and shoulder/leg armor, a single cream lens, warm brass seams and antennas, and six jointed graphite insect legs. No capsule or canine anatomy.

Iteration 1 already passed the geometry contract. Inspected all five comparison views: the broad rounded shell, short planted legs, eye bezel and antenna silhouette read cleanly. Iteration 2 added an explicit stationary SkitterRoot so all cosmetic motion is on child nodes. No failing contract checks occurred.

Final statistics: 11,548 triangles; 10 mesh objects; 7 used materials; dimensions 1.064 x 0.904 x 0.731 m; lowest z 0.001 m. The six required Leg_L/R_0..2 nodes are hip empties with their associated mesh children. The triangle count exceeds the advisory 5,000 target because of smooth split shell surfaces, rounded enamel body, curved lens bezel and rounded leg hinges. Combining rigid pieces keeps the mesh-object count below the advisory target.

Four self-authored 1024 x 1024 PNG atlases are embedded in the 1,051,856-byte GLB: base color, roughness, normal and lens emission. Every mesh is UV unwrapped and mapped into its material region. Surface variation is deliberately restrained to preserve pristine enamel. Images are saved alongside the script for inspection and packed into the Blender source; the GLB has no external image URI.

GLB animation buffer audit (`export_audit.json`) verifies actual transform channels and first/last sampled values: Idle 2.0 s, Walk 1.0 s and Swim 1.6 s have 10 animated channels each; Attack 0.8 s has 11, including a subtle eye scale pulse. All four clips have endpoint differences below 1e-16, and every exported channel varies. Root is stationary; body bobs locally, legs swing in alternating gait, and brass antennas sway. Attack returns to its resting pose. The parent agent will perform Godot playback and animated preview validation; no game files were read or modified.

Remaining limitations: the brass dorsal seam is straight rather than conforming exactly to the dome; legs move as whole rigid assemblies without independent knees; unseen underside is invented; fine surface variation is subtle at gameplay distance. The source reference is a larger parent robot, so visual fidelity is judged against the requested beetle adaptation and shared palette. Self-score: 8/10.

Final files: `build_eco_skitter.py`, `eco_skitter.glb`, `eco_skitter.blend`, four `skitter_*.png` maps, `export_audit.json`, and `renders/iter02/compare.png`.
