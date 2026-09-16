# 3D proving ground

The second migration slice is implemented on `feat/3d-migration`. The tested 2D baseline remains on `master` and at `prototype-2d-final`; `3d-slice-01` preserves the first playable 3D loop.

Launch with **`./launch_3d.ps1`**, or open `scenes/three_d/proving_ground.tscn` in Godot and run that scene (F6). The project's default main scene still opens the 2D game until the remaining features are migrated.

## Playable scope

- Fixed elevated orthographic camera and a 19.2 x 10.8 metre flat arena.
- WASD/arrow keys or left stick to move; auto-fire targets nearby enemies.
- E / controller A to pick up and place a nearby turret; carrying slows movement and disables that turret's fire.
- Escape / controller Start to pause; refit buttons support keyboard/controller focus.
- Three survival waves, using the existing wave-duration, enemy-count, and enemy-stat calculations with a fixed Easy preset.
- Chasing spider drones, soft crowd separation, contact damage and player invulnerability, swept 3D projectile hits, reusable projectile instances, and collectible scrap.
- Plasma turrets prioritize clusters, deal splash damage, and push enemies back. Knockback interrupts charger warnings and dashes.
- Armored chargers join every fourth spawn from wave 3. Amber rails show their locked dash direction during a 0.9-second warning; they dash, recover, and approach again. Their direction is fixed when the warning begins, so a dodge remains reliable. Contact checks sweep the entire movement segment.
- Between waves: buy an ion or plasma turret, add 20% damage to both turret types, or repair 10 hull. Remaining scrap drops are collected when the wave ends.
- Defeat and victory screens, with a fresh run via the button or R.

The player now has a scripted Blender hover-bot model. This remains a playable migration experiment with four fixed shop offers. Other turret attacks, enemy behaviors, items, research, difficulty/mode selectors, full VFX/audio, save migration, and production balancing remain to be ported. No image-generation web app changes or hosted generation services are required.

## Boundaries

`SliceWorld` owns the native 3D world and a `RunSession`. It reuses `GameStateService`, `GameStateMachine`, `EconomyService`, `PlayerStatsService`, `TurretStatsService`, registries, and `ModifierService`. It does not send 3D objects through the legacy Node2D event bus.

`CombatShot3D` snapshots weapon damage, projectile speed, splash radius, knockback, and damage type at firing. `CombatHit3D` carries a single hit. The run-owned `Combat3D` applies hits and emits hit, explosion, and defeat notifications; world rewards and bounded cosmetic effects consume those notifications. Splash snapshots its targets before deaths mutate the live enemy list. Projectile reuse resets its complete shot state. These are native 3D contracts; status-effect and buff behavior beyond the existing stat queries is still pending.

One conversion constant maps existing pixel-based values to metres: `SliceGeometry.METRES_PER_PIXEL = 0.01`. Movement, weapon range/speed, splash radius, knockback, and pickup radius cross this boundary. Damage and time retain their existing units. Enemy stats come from `EnemyRegistry.get_stats_for_wave`; turret prices use `EconomyService.calculate_turret_price`, also called by the legacy shop manager. This replaces the first slice's provisional enemy-health scaling and turret pricing. The fixed repair and damage-upgrade offers remain slice-specific.

Actors use CharacterBody3D with ground-plane movement, Area3D hurtboxes/pickups, and ShapeCast3D projectile sweeps. Visual bobbing and articulated legs do not move authoritative hitboxes. `CrowdGrid3D` snapshots positions once per physics tick and queries nearby cells for soft separation. Plasma targeting uses the same grid, with cluster counts shared between turrets and refreshed each physics tick. Target acquisition runs at 5 Hz. Enemies have no mutual physical collision or obstacle navigation; dense crowds can still overlap. Separation is suspended during a charger warning/dash to preserve the indicated path.

`SliceActor`, `SliceTurret`, `SliceProjectile`, and `SlicePickup` own individual world behavior. `ChargeController3D` owns charge phases; `CombatEffects3D` reuses up to 32 explosion rings. `SliceHUD` is the presentation adapter. Pause freezes simulation and effects; death, wave completion, and restart clear transient warnings, impulses, and effects. The 2D shop delegates to the extracted pricing policy with its existing behavior preserved.

## Blender proof

All five assets are produced by the checked-in Blender Python script, using existing 2D artwork as visual references:

| Asset | Triangles in source export | Materials | Animation contract |
|---|---:|---:|---|
| Ion turret | 448 | 3 | Separate yaw pivot, muzzle socket, recoil |
| Spider drone | 2,216 | 3 | Six separate leg pivots driven procedurally at runtime |
| Plasma turret | 884 | 3 | Separate yaw pivot, muzzle socket, recoil |
| Charger drone | 2,360 | 3 | Six leg pivots; amber armor and ram horns |
| Player bot | 1,548 | 3 | Muzzle socket; runtime hover/turning |

Editable `.blend` files live in `art-source/blender/`; approved GLBs and provenance manifest live in `assets/models/slice/`. Sources are excluded from Godot import. Binary models use Git LFS and CI checks out LFS objects. See the [Blender asset skill](../.claude/skills/blender-assets/SKILL.md) for rebuild and validation instructions.

## Verification

Final full GUT gate: **1,128 tests passed**, with no risky tests, unexpected errors, or remaining orphans (Godot 4.7.1).

The 27 3D integration tests cover wave/shop/restart lifecycle, shared service state/pricing, damage modifiers, rejected purchases, targeting and cluster-cache invalidation, fast swept hits, projectile reuse, simultaneous splash deaths, pause, carry/placement, terminal states, imported pivots, movement input, invulnerability, repair caps, and spawn-overlap hits. Charger checks include warning timing, locked heading, the warning-to-dash transition, swept contact, and knockback interruption. Other checks cover mass/speed limits, effect reuse, crowd separation, registry scaling, and the wave-3 charger gate.

Native Vulkan/Forward+ captures use 1280 x 720. `--combat-demo` stages and freezes an actual warning and plasma impact for readability review; `--shop` captures refit. The live `--stress` tool warms up for 120 frames and measures 600 wall-clock frame intervals with VSync disabled.

On the local RTX 4090, the second-slice sample retained **150 enemies (38 chargers), 10 turrets (5 plasma), and 11 projectile instances**: **11.528 ms median / 16.705 ms p95**, with 533 draw calls at capture. Enemies have 10,000 health to remain present, use registry movement speeds, and the player is invulnerable. This intentionally crowded sample exercises separation, charging, splash, and knockback. The first slice measured 2.248 ms median / 9.568 ms p95 with slower basic enemies and no new combat behavior; the workloads differ and are not a controlled regression comparison. These short development-machine samples do not establish minimum-spec performance. Raw logs and captures are ignored under `.test-results/`.

## Next migration increment

Playtest plasma value, warning readability, crowd spacing, and the difficulty of all three waves. Buy plasma after wave 1 and compare surviving wave 3 with and without its interruption effect. Then migrate the item/status-effect progression and remaining combat types through the new contracts. Keep broad content conversion and web-app extensions behind those gameplay checks.
