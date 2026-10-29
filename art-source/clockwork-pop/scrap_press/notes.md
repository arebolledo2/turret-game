# cp_scrap_press-v1 notes

Iterations: 5 harness runs. Run 1 was a build failure (bmesh.ops.translate takes `vec=`, not `vecs=`); renders exist for iter02-iter05. Final = iter05.

## What changed
- iter02: first build; squat and too wide, coins sunk below the tray floor, funnel small.
- iter03: narrowed arch, taller pillars/housing, saturated colours, coins raised onto the tray floor.
- iter04: deeper pillars, bigger tray/feet/porthole, larger funnel attached nearer the pillar, tri count cut (28-40 vertex cylinders, fewer bevel segments).
- iter05: porthole glow moved proud of the housing surface (was hidden), removed stepped base block, merged rubber bits (16 mesh objects).

## Final stats
12,216 triangles (target 5,000), 16 mesh objects (target 16), 10 materials (target 10). Size 1.357 x 1.175 x 1.58 m, min z 0. Contract passed.
Triangle overrun is deliberate: rounded bevelled forms (smooth enamel look of the concept) and 28-40 sided cylinders for brass/housing/coins.

## Structure
Aim (identity, origin) carries Housing, PistonBrass (band, cap, plunger), PistonRam, PortholeRing, PortholeGlow; Muzzle (bare empty) under Aim at the tray front edge (0, 0.66, 0.52). Static: Feet, BasePlate, BaseBlock, Pedestals, Frame (arch + funnel), BrassTrim, RubberDetails, Knob, Die, CoinTray, Coins.

## Remaining flaws vs concept
- Pillars/arms are simpler than the concept's chunky rounded arch; arm tops lack the thick rounded cap.
- Concept feet are larger and more rounded; base plate/slate block proportions only approximate.
- Funnel is a plain hollow cone, concept has a rolled lip. Coins lack relief beyond an inset face.
- Back/left sides invented (mirror brass fittings, funnel on -X). No baked AO or textures; emissive porthole renders pale.

Self-score: 7/10.
