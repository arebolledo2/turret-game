# Enemy ecology implementation

Status: implemented and verified on `feat/enemy-ecology`. Design: [interactive proposal](enemy-ecology.html).

## Accepted scope

- Existing five enemy bodies and collision footprints become 10% smaller.
- Drowse Beetle, Rivet Hopper (insect, no canine anatomy), Needle Kite, Kiln Lobber and Brood Tender.
- Brass Ram, Prism Conductor and Grand Marionettist on waves 6/12/20. Hero targets only; timer completion never requires a kill. Epic/Legendary rewards enter Keep/Sell review.
- Authored twenty-wave rosters, relaxed first five waves on every difficulty, bounded warning overlap and summons, spawns distributed to round end.
- Polished models, animation, supporting Skitters/lenses/anchors/puppets and hostile projectiles/telegraphs. Visible boss HP and improved anchored chest HP.

## Progress

- [x] Inventory favorites: one favorite for each subject except Needle Kite.
- [x] Select Needle Kite compact triangular concept; refine to cobalt/ivory and open muzzle.
- [x] Model and visually review all eight main assets.
- [x] Create supporting models and hostile combat effects.
- [x] Implement enemy roles, target policies and attacks.
- [x] Implement wave schedule and bosses/rewards.
- [x] Improve health UI.
- [x] Verify focused tests, full suite, resource audit, gameplay captures and all three modes.
- [x] Commit final implementation and document actual results/limitations.

## Concept provenance

Regular batch: `fa367042-0b32-4c95-b62b-7fecf6a984b5`; bosses: `ebb4690c-bc6e-40c9-964f-f9a1c353bb8d`.
Selection inventory and review contact sheet: `3d-eval/reports/enemy-ecology-selection/` (outside the game repository; preserve selected references during promotion).
First modeling runs: `eco_drowse-v1`, `eco_hopper-v1`, `eco_lobber-v1`.

## Validation policy

Exercise target masks, timeout cleanup, once-only rewards, no summon economy farming, bounded spawns and reproducible rosters. Inspect actual imported animation and camera-distance readability before accepting exports. No performance claims while image generation or Blender work competes for GPU time.

## Delivery verification

- Full suite: 1,044 tests, 79 scripts, 18,303 assertions; no risky tests, unexpected errors or remaining orphans. Artifacts: `.test-results/d72c521f3968453ebd20d6d1da55fae3/`.
- Final focused check: 21 ecology tests, 2,058 assertions after visual polish. Artifacts: `.test-results/b7f4bfd0b44245aaaf2e8e38338e3719/`.
- All twelve exports visually reviewed and animation playback checked in Godot.
- [Gameplay captures and model inventory](../art/enemy-ecology/index.html).
- [Runtime guide](../enemy-ecology.md). Boss health and encounter pressure remain playtest starting values; no performance benchmark is claimed.
