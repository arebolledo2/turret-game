# 3D gameplay

Launch with **`./launch.ps1`** or Godot F5. The default main scene opens Play, Settings and Quit. `launch_3d.ps1` remains an alias. F6 on `scenes/game/arena.tscn` opens the arena directly. The 2D runtime is retired; see [the cutover record](3d-cutover.md).

Settings persist fullscreen, VSync, reduced motion and SFX volume (70% by default; zero mutes). Pause/end screens can return to the start menu; each Play creates a fresh session.

## Playable scope

- Elevated orthographic follow camera (`CameraRig`) over a 57.6 x 32.4 metre flat arena. The camera only translates, stays clamped to the floor, and zooms 0.5x-2x with the mouse wheel, `+`/`-` keys or gamepad triggers.
- Enemies spawn on a ring just outside the default-zoom view around the player (`ArenaWorld._spawn_position`).
- The window is resizable with a title bar (1280 x 720 by default); settings offers size presets and fullscreen. Stretch mode is `canvas_items` with `expand` aspect.
- WASD/arrow keys or left stick to move; auto-fire targets nearby enemies.
- E / controller A to pick up and place a nearby turret; carrying slows movement and disables that turret's fire.
- Escape / controller Start to pause; refit buttons support keyboard/controller focus.
- Six survival waves, using the existing wave-duration, enemy-count, and enemy-stat calculations with a fixed Easy preset.
- Chasing spider drones, soft crowd separation, contact damage and player invulnerability, swept 3D projectile hits, reusable projectile instances, and collectible scrap.
- Plasma turrets prioritize clusters, deal splash damage, and push enemies back. Knockback interrupts charger warnings and dashes.
- Armored chargers join every fourth spawn from wave 3. Amber rails show their locked dash direction during a 0.9-second warning; they dash, recover, and approach again. Their direction is fixed when the warning begins, so a dodge remains reliable. Contact checks sweep the entire movement segment.
- Shock turrets pulse electric damage around themselves and slow enemies by 25% for 0.5 seconds. Cyan rings identify slowed enemies; slowed chargers keep their locked heading but cover less distance.
- Between waves: choose from two turret offers and two item offers, reroll stock, or repair 10 hull for 5 scrap. Remaining scrap drops are collected when the wave ends.
- Shop, pause, and end screens show the current build: turret counts/damage/fire rate/range, player stats, and purchased item stacks.
- Defeat and victory screens, with a fresh run via the button or R.

The player has a scripted Blender hover-bot model. Other turret attacks, enemy behaviors, unsupported items, research, difficulty/mode selectors, music and final VFX/audio polish, save migration, and production balancing are outside the supported game. No image-generation web app changes or hosted generation services are required.

## Shop and build choices

`ArenaShop` draws two distinct weapons from the ion, plasma, shock, tesla and melee turrets, plus two distinct items using the existing registry rarity weights and stack limits. Its explicit allowlist contains 13 implemented items: Scrap Magnet, Reinforced Hull, Quick Loader, Shock Absorbers, Dense Rounds, Budget Capacitor, Ammo Surplus, Overclock Module, Compact Design, Extended Barrel, Rapid Coolant, Kinetic Enhancer, and Heavy Plating. All modifiers, including drawbacks and projectile/physical/electric filters, use the shared stat services.

Item base prices are 50% of registry prices, rounded before applying the shared wave/item-price policy: common upgrades start at 10 scrap, uncommon at 18. Wave 1 therefore offers common upgrades for 12, compared with ion at 9, plasma at 19, and shock at 16. This is a deliberate six-wave balance setting, not a global economy change. Turret purchases update the remaining prices using the shared purchase penalty. Rerolls use shared escalating costs, reset each shop visit, and are free when every offer is sold. A reroll draws from the limited catalog again; stock is unique within a roll, not across the entire visit. Offer locking is not implemented.

Purchase validation runs before spending or deploying: sold/unsupported/max-stacked items, unavailable placement, insufficient funds, pause, and non-shop states cannot transact. Item purchases immediately update modifiers and hull capacity; additional capacity does not heal damage. Restart resets items, offers, counts, and modifiers. Shop descriptions are generated from actual modifier values because some legacy prose descriptions are stale; purchase-penalty changes are displayed in percentage points (`pp`).

## Boundaries

`ArenaWorld` owns the native 3D world and a `RunSession`. It reuses `GameStateService`, `GameStateMachine`, `EconomyService`, `PlayerStatsService`, `TurretStatsService`, registries, and `ModifierService`. World combat signals stay local; shared notifications use `Events`.

`CombatShot3D` snapshots weapon damage, projectile speed, splash radius, knockback, slow intensity/duration, and damage type at firing. `CombatHit3D` carries a single hit. The run-owned `Combat3D` applies hits and emits hit, explosion, shock-pulse, and defeat notifications; world rewards and bounded cosmetic effects consume those notifications. Splash snapshots its targets before deaths mutate the live enemy list. Projectile reuse resets its complete shot state.

`StatusEffects3D` reuses the shared `StatusEffect` lifetime and refresh implementation through local world ownership. A refresh retains the strongest slow of that damage type and replaces its remaining duration; different types use the strongest active slow, not multiplicative stacking. Slow intensity is capped at 90%. Slow affects pursuit and dash movement, not knockback or timers. Pause freezes lifetimes; death, wave end, and restart clear effects. Shock pulses use registry range, fire rate, damage, and slow values, hit each in-range enemy once, and stop firing while carried. DoT and temporary turret buffs remain unsupported.

One conversion constant maps existing pixel-based values to metres: `WorldGeometry.METRES_PER_PIXEL = 0.01`. Movement, weapon range/speed, splash radius, knockback, and pickup radius cross this boundary. Damage and time retain their existing units. Enemy stats come from `EnemyRegistry.get_stats_for_wave`; turret and item prices use shared `EconomyService` policies, used by the supported shop. The fixed repair offer remains arena-specific.

Actors use CharacterBody3D with ground-plane movement, Area3D hurtboxes/pickups, and ShapeCast3D projectile sweeps. Visual bobbing and articulated legs do not move authoritative hitboxes. `CrowdGrid3D` snapshots positions once per physics tick and queries nearby cells for soft separation. Plasma targeting uses the same grid, with cluster counts shared between turrets and refreshed each physics tick. Target acquisition runs at 5 Hz. Enemies have no mutual physical collision or obstacle navigation; dense crowds can still overlap. Separation is suspended during a charger warning/dash to preserve the indicated path.

`CombatActor`, `TurretActor`, `Projectile3D`, and `ScrapPickup` own individual world behavior. `ChargeController3D` owns charge phases; `CombatEffects3D` reuses up to 32 explosion rings. `game_hud.gd` is the presentation adapter. Pause freezes simulation and effects; death, wave completion, and restart clear transient warnings, impulses, and effects.

## Blender proof

All six assets are produced by the checked-in Blender Python script, using existing 2D artwork as visual references:

| Asset | Triangles in source export | Materials | Animation contract |
|---|---:|---:|---|
| Ion turret | 448 | 3 | Separate yaw pivot, muzzle socket, recoil |
| Spider drone | 2,216 | 3 | Six separate leg pivots driven procedurally at runtime |
| Plasma turret | 884 | 3 | Separate yaw pivot, muzzle socket, recoil |
| Charger drone | 2,360 | 3 | Six leg pivots; amber armor and ram horns |
| Player bot | 1,548 | 3 | Muzzle socket; runtime hover/turning |
| Shock turret | 748 | 3 | Pulse dome and electrodes; standard Aim/Muzzle contract |

Editable `.blend` files live in `art-source/blender/`; approved GLBs and provenance manifest live in `assets/models/game/`. Sources are excluded from Godot import. Binary models use Git LFS and CI checks out LFS objects. See the [Blender asset skill](../.claude/skills/blender-assets/SKILL.md) for rebuild and validation instructions.

## Verification

Final full GUT gate: **790 tests passed**, with no risky tests, unexpected errors, or remaining orphans (Godot 4.7.1). This run included a fresh asset import.

The arena integration tests cover wave/shop/restart lifecycle, shared service state/pricing, damage modifiers, rejected purchases, targeting and cluster-cache invalidation, fast swept hits, projectile reuse, simultaneous splash deaths, pause, carry/placement, terminal states, imported pivots, movement input, invulnerability, repair caps, and spawn-overlap hits. Charger checks include warning timing, locked heading, the warning-to-dash transition, swept contact, and knockback interruption. Progression checks add supported stock generation, purchase atomicity, dynamic pricing, rerolls, hull capacity, actual movement/pickup changes, filtered weapon stats, pulse boundaries/cooldowns, slow refresh/expiry/cleanup, HUD states, and both six-wave build paths.

`godot --headless --path . res://tools/smoke_progression.tscn` runs an accelerated real-physics ion build; append `-- --control` for plasma/shock. The seeded dodge bot uses real damage, spawning, drops, shop stock, and budgets, with no invulnerability or injected funds. These checks exercise complete runs; they are not human playtesting or performance measurements.

Both routes reached wave-6 victory in 267.5 simulated seconds. Ion finished with 7 ion turrets, 9 purchased item stacks, and 392 kills; control finished with the starter ion, 2 plasma, 4 shock, 3 item stacks, and 391 kills. Both retained 25 hull. Human playtesting is still needed to judge difficulty and upgrade value.

Native Vulkan/Forward+ captures use 1280 x 720. `--combat-demo` stages and freezes a warning, plasma impact, and shock pulse for readability review; `--shop` captures refit. The live `--stress` tool warms up for 120 frames and measures 600 wall-clock frame intervals with VSync disabled. Its third-slice mix includes all three turret types.

The third-slice RTX 4090 sample retained **150 enemies, 10 turrets (4 ion / 3 plasma / 3 shock), and 8 projectile instances**: **13.075 ms median / 17.438 ms p95**, with 562 draw calls at capture. This includes slowing pulses and status indicators. The crowded sample's p95 exceeds a 16.7 ms frame budget; it is not a minimum-spec performance guarantee.

On the local RTX 4090, the second-slice sample retained **150 enemies (38 chargers), 10 turrets (5 plasma), and 11 projectile instances**: **11.528 ms median / 16.705 ms p95**, with 533 draw calls at capture. Enemies have 10,000 health to remain present, use registry movement speeds, and the player is invulnerable. This intentionally crowded sample exercises separation, charging, splash, and knockback. The first slice measured 2.248 ms median / 9.568 ms p95 with slower basic enemies and no new combat behavior; the workloads differ and are not a controlled regression comparison. These short development-machine samples do not establish minimum-spec performance. Raw logs and captures are ignored under `.test-results/`.

## Combat polish follow-up

Native spatial weapon, warning, impact, pickup, purchase and run-state sounds are implemented, with bounded voices and persistent SFX volume. Muzzle/hit sparks are pooled. Shared marker resources reduce render overhead. See [combat polish](combat-polish.md) for validation, current measurements and remaining frame-budget work.

Playtest the audio mix and warning readability across six waves. Crowded-scene p95 still needs attention before claiming a consistent 60 fps budget or expanding the content catalog.
