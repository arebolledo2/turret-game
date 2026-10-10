# Dugout Automaton — frozen candidate

Final candidate frozen at **iteration 2 of 8 allowed**. Both harness iterations pass. Final front, three-quarter, right side, back and top renders were inspected against the selected reference.

## Deliverables

- `build_cp_melee.py`: deterministic standalone Blender source, factory-empty startup, procedural geometry and generated textures.
- `cp_melee.blend`: editable source with all texture images packed.
- `cp_melee.glb`: self-contained game candidate, no external texture/buffer paths, no baked animations/cameras/lights.
- Four generated 1024×1024 PNG atlases: `dugout_color_atlas`, `dugout_orm_atlas`, `dugout_micro_normal`, `dugout_optic_glow`.
- `renders/iter02/compare.png` and five individual views: final inspected comparison.
- `renders/iter02/validate.json`: final passing contract report.
- `audit_rig.py` and `rig_audit.json`: export-level reach, hierarchy and horizontal scaling verification.
- `export_manifest.json`: frozen exact bytes, source/export hashes and GLB integrity.

## Geometry and grip correction

**12,644 triangles / 16 mesh objects / 8 used materials / four embedded 1024×1024 images.** Bounds **0.660 × 1.530 × 1.149 metres**, minimum Z **0.012m**. Origin is the fixed base centre at world XY **(0,0)**; the asymmetric long bat intentionally shifts total geometry bounds forward.

The bat is gripped at its **narrow handle near the butt knob**, not at the wooden taper or barrel. Three curled brass fingers occupy **y=0.037..0.207m**. The brass butt knob occupies **y=-0.080..-0.029m**. The visible dark handle continues to the ferrule near **y=0.26..0.30m**; the wooden maple taper begins at **y=0.287m** and ends at **y=1.200m**. The grip centre is **y=0.122m**, leaving approximately **1.078m / 84% of the 1.280m total bat length** beyond the grip centre. The hand is physically around the narrow black handle with the long wooden hitting length in front of it.

## Runtime rig and physical reach

- `Aim`: central yaw empty at **(0,0,0.660)m**, identity rotation/scale. It carries shoulder, arm frame/plates, elbow, hand backing/shield, curled grip fingers, bat handle/knob/ferrule, shoulder optics and wooden bat.
- Bare `Muzzle`: directly nested under Aim, local **(0,1.200,0.420)m**, world **(0,1.200,1.080)m**, identity rotation/scale. Forward axis is Blender +Y; horizontal distance from yaw axis is exactly **1.2m** within floating point export precision.
- Base enamel, ivory ribbons, coral trims, feet, base jewels/sockets and central mast remain outside Aim. No animation, armature or deforming rig.
- The parent's validator update checks the named Aim origin for this asymmetric asset rather than demanding a centred overall bounds box. This agent changed no harness/config/game files.

Exported GLB was re-imported and measured in `audit_rig.py`:

- Rest marker radius **1.200000048m**; maximum moving physical vertex radius **1.200000464m**.
- At Blender Aim scale **(1.5,1.5,1)**, marker radius **1.800000072m** and moving geometry radius **1.800000697m**.
- Moving min/max Z remain **0.603..1.161m** before/after scaling. Every fixed base vertex remains unchanged.
- Muzzle has no children and is directly below Aim; Aim rotation is exactly **(0,0,0)**.

Thus the visible bat and hit marker agree with the physical sweep radius, and horizontal range scaling preserves height. Blender XY scaling corresponds to Godot XZ scaling after glTF Y-up conversion. Parent owns game integration and attack/controller verification.

## Iteration record

1. Built the complete base, pillar, articulated golden forearm, jeweled shoulder, gold shield, curled handle grip, long maple bat and proper pivots. Contract passed at 13,696 triangles / 17 mesh objects. Red stitched barrel band and lengthwise maple fibres were generated in the colour atlas. Final render showed the upper ivory base meridians partly buried, making the cream frame read as short ticks.
2. Exposed the full cream meridian ribs and added the rounded connecting shoulder arch. Reduced minor cylinder/socket/optic tessellation and merged the shield into the same rigid hand backing assembly. Contract passes at 12,644 triangles / 16 meshes; all five views inspected. Re-imported export rig audit confirms physical reach and upgrade scaling.

## Surface appearance and budget

Four generated atlases supply clean enamel/lacquer, brushed brass, polished maple fibres and red stitching, metallic/roughness variation, faint micro-normal detail and restrained jewel emission. Images receive colourspace before pixel upload; stock active UV layers are reused. Every mesh has padded atlas UVs with a shared metre-based box projection density; the wooden bat has deliberate cylindrical UVs so fibres align lengthwise and the red stitched band surrounds the barrel near its tip. No generic grime, external images, external models or Cycles baking.

The triangle target of 5,000 is advisory and exceeded. The model retains smooth base silhouette, four round raised sockets/jewels, rounded physical feet, compound hand fingers, crown-like brass bat ferrule/knob, bevelled arm plates and shaped bat barrel. Minor socket/optic tessellation was reduced after appearance acceptance. Object/material/texture targets are met. No performance/frame-time claim is made.

## Remaining limitations

Checker illumination is less saturated/painterly than the illustration. Ivory meridians and shoulder band form a regular constructed frame rather than the reference's softly sculpted asymmetric cream arches. Shoulder lens uses the shared blue-violet optic family instead of a distinct cyan lens. The bat has subtle maple fibres and the red barrel stitch ring; its hand is intentionally repositioned closer to the butt knob to satisfy the user's correction, changing reference proportions around the handle. Jewels are stylized opaque domes rather than full refractive optics. Hidden sides and additional side sockets are invented symmetrically. Runtime animation and in-engine visuals remain for the parent to verify.

Honest self-score: **8.0/10**. Strong silhouette, palette, recognizable mechanism, corrected handle grip and verified physical range; remaining gaps concern painterly colour and exact cream-frame/optic styling.
