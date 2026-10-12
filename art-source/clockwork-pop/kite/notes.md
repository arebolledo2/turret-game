# Needle Kite / eco_kite-v1

Final export: `eco_kite.glb`, generated entirely by `build_eco_kite.py`.
The packed editable source is `eco_kite.blend`; all generated texture atlases are also saved beside it.

## Iterations and acceptance

Three harness evaluations used, all passed the full contract. Iteration 1 had 31,088 triangles and a dorsal sail that was too small beside the body. Iteration 2 enlarged the sail and sharpened the glass appearance, with unnecessary tube bevels removed (21,552 triangles). Iteration 3 simplified tiny cylinder/rail tessellation and retained a narrow bevel on larger brass rings (17,168 triangles). The final `renders/iter03/compare.png` was inspected against the reference across every view.

Final geometry: **17,168 triangles, 4 mesh objects, 8 used materials**. Four mesh assemblies consolidate all static parts by their animated pivot, keeping the moving structure inexpensive in object count. The triangle advisory is exceeded by 5,168 triangles to preserve polished round optics, cylindrical ring/shaft silhouettes, clean ceramic edge frames and bevel highlights. This remains a soft-budget candidate; no performance claim is made.

Dimensions in metres: **0.817 × 1.440 × 1.001**, lowest point **z = 0.164**, horizontal bounds centre **(0, 0.081)**. The shell floats above ground. Body, Fin_L, Fin_R, Aim and Muzzle are present. Muzzle is a bare marker directly under Aim, at the open forward barrel lip. The needle cannon contains actual inner bore surfaces and a dark recessed terminus; there is no animal mouth.

## Surface and animation

Four **1024×1024** images are procedurally generated, UV-mapped on every mesh, embedded in the GLB and packed in the Blender source: cobalt/ivory/brass/gunmetal base colour atlas, metallic/roughness atlas, subtle micro-normal atlas and amber optic emission atlas. Textures use deliberate finish variation and fine manufacturing striation, with no generic grime. Amber optics use glTF glass transmission and a clear coat.

Rigid transform clips: **Idle (4 seconds), Walk (2 seconds), Swim (3 seconds), Attack (1 second)**. Body provides subtle local hover/pitch, side fins articulate, and Aim recoils during Attack. Every clip returns to its starting pose; Idle, Walk and Swim have matching loop endpoints. Root has no animation channels. `animation_audit.json` verifies exported transform motion, durations, endpoint agreement, stationary Root, embedded textures and bare Muzzle.

## Fidelity and limitations

Cobalt replaces the concept's teal, and the gold pointed nose becomes the requested functional open cannon. The ivory triangular dorsal fin, brass front collar, inset side optics, compact core, ventral fins and short rear thruster retain the concept's mechanical dart-fish identity. The body includes angular cheek armor around a rounded pressure shell. Unseen rear/underside surfaces are invented with a small turbine and paired ceramic vanes. Side fins are thinner, more explicitly mechanical vanes than the concept's chunky blue lower pods; the glass optics read darker amber than the purple-tinted reference. No in-engine playback or gameplay test was performed in this isolated asset run; the parent will verify Godot import and preview. No game files or other run folders were read or modified.

Honest visual self-score: **8/10**.
