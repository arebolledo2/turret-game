# 3D proving ground

The first migration slice is implemented on `feat/3d-migration`. The tested 2D baseline remains on `master` and at `prototype-2d-final`.

Launch with **`./launch_3d.ps1`**, or open `scenes/three_d/proving_ground.tscn` in Godot and run that scene (F6). The project's default main scene still opens the 2D game until the remaining features are migrated.

## Playable scope

- Fixed elevated orthographic camera and a 19.2 x 10.8 metre flat arena.
- WASD/arrow keys or left stick to move; auto-fire targets nearby enemies.
- E / controller A to pick up and place a nearby turret; carrying slows movement and disables that turret's fire.
- Escape / controller Start to pause; refit buttons support keyboard/controller focus.
- Three survival waves, using the existing wave-duration and enemy-count calculations.
- Chasing spider drones, contact damage and player invulnerability, swept 3D projectile hits, reusable projectile instances, and collectible scrap.
- Between waves: buy a normal turret, add 20% turret damage, or repair 10 hull. Remaining scrap drops are collected when the wave ends.
- Defeat and victory screens, with a fresh run via the button or R.

This is a playable migration experiment, not feature parity. The player is a primitive placeholder. The shop is deliberately limited to three offers; other turret attacks, enemy behaviors, items, research, difficulty/mode selectors, full VFX/audio, save migration, and production balancing remain to be ported. No image-generation web app changes or hosted generation services are required.

## Boundaries

`SliceWorld` owns the native 3D world and a `RunSession`. It reuses `GameStateService`, `GameStateMachine`, `EconomyService`, `PlayerStatsService`, `TurretStatsService`, registries, and `ModifierService`. It does not send 3D objects through the legacy Node2D event bus. Actor signals stay local until the wider combat event migration.

One conversion constant maps existing pixel-based values to metres: `SliceGeometry.METRES_PER_PIXEL = 0.01`. Player movement, weapon range/speed, enemy speed, and pickup radius cross this boundary. Damage and time retain their existing units. The slice's escalating enemy health and shop pricing are provisional.

Actors use CharacterBody3D with ground-plane movement, Area3D hurtboxes/pickups, and ShapeCast3D projectile sweeps. Visual bobbing and articulated legs do not move authoritative hitboxes. Enemies have no mutual physical collision or navigation in this first open-arena slice. Crowd separation is a future behavior pass.

`SliceActor`, `SliceTurret`, `SliceProjectile`, and `SlicePickup` own individual world behavior. `SliceHUD` is the presentation adapter. The 2D gameplay path remains unchanged.

## Blender proof

Both assets are produced entirely by the checked-in Blender Python script, using the existing 2D artwork as visual references:

| Asset | Triangles in source export | Materials | Animation contract |
|---|---:|---:|---|
| Ion turret | 448 | 3 | Separate yaw pivot, muzzle socket, recoil |
| Spider drone | 2,216 | 3 | Six separate leg pivots driven procedurally at runtime |

Editable `.blend` files live in `art-source/blender/`; approved GLBs and provenance manifest live in `assets/models/slice/`. Sources are excluded from Godot import. Binary models use Git LFS and CI checks out LFS objects. See the [Blender asset skill](../.claude/skills/blender-assets/SKILL.md) for rebuild and validation instructions.

## Verification

The 3D integration tests cover wave/shop/restart lifecycle, shared service state, damage modifiers, rejected purchases, planar targeting, fast swept hits, projectile reuse, duplicate death/pickup prevention, pause, carry/placement, terminal states, imported pivots, movement input, invulnerability, repair caps, and spawn-overlap hits.

Native Vulkan/Forward+ screenshots were reviewed at 1280 x 720 for combat, the refit screen, and a crowd sample. The capture tool warms up for 120 frames and measures 600 wall-clock frame intervals with VSync disabled.

On the local RTX 4090, the initial sample retained **150 drones and 10 turrets**, with 11 projectile instances at capture: **2.248 ms median / 9.568 ms p95**. Drones have increased health and reduced speed for this sample so they remain present. This short development-machine sample is not a minimum-spec benchmark or evidence for the performance of future navigation, skeletal animation, or effects. Re-run after material or scene changes; raw logs and captures are ignored under `.test-results/`.

## Next migration increment

Playtest movement, framing, scale, and turret interaction first. Then migrate a contrasting weapon/enemy pair (such as splash damage and a charger), along with the shared combat-event contracts. Use those results to settle visual style and crowd behavior before converting the full content library or extending the web app.
