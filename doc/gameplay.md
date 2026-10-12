# 3D gameplay

Launch with **`./launch.ps1`** or Godot F5. The default main scene opens Play, Settings and Quit. `launch_3d.ps1` remains an alias. F6 on `scenes/game/arena.tscn` opens the arena directly. The 2D runtime is retired; see [the cutover record](3d-cutover.md).

Settings persist fullscreen, VSync, reduced motion and SFX volume (70% by default; zero mutes). Pause/end screens can return to the start menu; each Play creates a fresh session.

## Enemy ecology update

See [the enemy ecology guide](enemy-ecology.md) for the current twenty-wave rosters, five new enemy roles, bosses on waves 6/12/20, summon limits and reward rules. [Godot captures](art/enemy-ecology/index.html) show the delivered models and effects.

## Playable scope

- Elevated orthographic follow camera (`CameraRig`) over a 40.73 x 22.91 metre flat arena (half the previous surface area; same aspect ratio). The camera only translates, stays clamped to the floor, starts at 0.75x zoom (four times the ground area of the old 1.5x default), and zooms 0.5x-2x with the mouse wheel, `+`/`-` keys or gamepad triggers.
- Encounter spawn positions vary by role: nearby wandering Drowse Beetles, alternating ranged flanks, grouped hunters, and the default outer spawn ring.
- The window is resizable with a title bar (1280 x 720 by default); settings offers size presets and fullscreen. Stretch mode is `canvas_items` with `expand` aspect.
- WASD/arrow keys or left stick to move; auto-fire targets nearby enemies.
- E / controller A to pick up and place a nearby turret; carrying slows movement and lets that turret attack instead of the hero's gun. Entrenchment resets on pickup and only builds while deployed; terrain bonuses apply only to deployed turrets.
- Escape / controller Start to pause; shop buttons support keyboard/controller focus.
- Twenty survival waves by default (`RunConfig`, 30 s rising to a 60 s cap from wave 7), using the existing wave-duration, enemy-count, and enemy-stat calculations with the Easy preset. The original six-wave slice is `RunConfig.slice()`.
- Chasing spider drones, soft crowd separation, contact damage and player invulnerability, swept 3D projectile hits, reusable projectile instances, and collectible scrap.
- Plasma turrets prioritize clusters, deal splash damage, and push enemies back. Knockback interrupts charger warnings and dashes.
- Armored chargers appear in the authored rosters from wave 11. Amber rails show their locked dash direction during a 0.9-second warning; they dash, recover, and approach again. Their direction is fixed when the warning begins, so a dodge remains reliable. Contact checks sweep the entire movement segment.
- Shock turrets pulse electric damage around themselves and slow enemies by 25% for 0.5 seconds. Cyan rings identify slowed enemies; slowed chargers keep their locked heading but cover less distance.
- Between waves: choose from two turret offers and two item offers, reroll stock, or repair 10 hull for 5 scrap. Remaining scrap drops are collected when the wave ends.
- Shop, pause, and end screens show the current build: turret counts/damage/fire rate/range, player stats, and purchased item stacks.
- Defeat and victory screens, with a fresh run via the button or R.

The player has a scripted Blender hover-bot model. Other turret attacks, enemy behaviors, unsupported items, research, difficulty/mode selectors, music and final VFX/audio polish, save migration, and production balancing are outside the supported game. No image-generation web app changes or hosted generation services are required.

## Shop and build choices

`ArenaShop` draws two distinct weapons from the ion, plasma, shock, tesla and melee turrets, plus two distinct items using the existing registry rarity weights and stack limits. Its catalog (`ShopCatalog`, one row per id with an optional required feature flag) contains 13 implemented items: Scrap Magnet, Reinforced Hull, Quick Loader, Shock Absorbers, Dense Rounds, Budget Capacitor, Ammo Surplus, Overclock Module, Compact Design, Extended Barrel, Rapid Coolant, Kinetic Enhancer, and Heavy Plating. All modifiers, including drawbacks and projectile/physical/electric filters, use the shared stat services.

Item base prices are 50% of registry prices, rounded before applying the shared wave/item-price policy: common upgrades start at 10 scrap, uncommon at 18. Wave 1 therefore offers common upgrades for 12, compared with ion at 9, plasma at 19, and shock at 16. This is a deliberate six-wave balance setting, not a global economy change. Turret purchases update the remaining prices using the shared purchase penalty. Rerolls use shared escalating costs, reset each shop visit, and are free when every offer is sold. A reroll draws from the limited catalog again; stock is unique within a roll, not across the entire visit. Offer locking is not implemented.

Purchase validation runs before spending or deploying: sold/unsupported/max-stacked items, unavailable placement, insufficient funds, pause, and non-shop states cannot transact. Item purchases immediately update modifiers and hull capacity; additional capacity does not heal damage. Restart resets items, offers, counts, and modifiers. Shop descriptions are generated from actual modifier values because some legacy prose descriptions are stale; purchase-penalty changes are displayed in percentage points (`pp`).

## Boundaries

`ArenaWorld` owns the native 3D world and a `RunSession`. It reuses `GameStateService`, `GameStateMachine`, `EconomyService`, `PlayerStatsService`, `TurretStatsService`, registries, and `ModifierService`. World combat signals stay local; shared notifications use `Events`.

`CombatShot3D` snapshots weapon damage, projectile speed, splash radius, knockback, slow intensity/duration, and damage type at firing. `CombatHit3D` carries a single hit. The run-owned `Combat3D` applies hits and emits hit, explosion, shock-pulse, and defeat notifications; world rewards and bounded cosmetic effects consume those notifications. Splash snapshots its targets before deaths mutate the live enemy list. Projectile reuse resets its complete shot state.

`StatusEffects3D` reuses the shared `StatusEffect` lifetime and refresh implementation through local world ownership. A refresh retains the strongest slow of that damage type and replaces its remaining duration; different types use the strongest active slow, not multiplicative stacking. Slow intensity is capped at 90%. Slow affects pursuit and dash movement, not knockback or timers. Pause freezes lifetimes; death, wave end, and restart clear effects. Shock pulses use registry range, fire rate, damage, and slow values, hit each in-range enemy once, and continue firing while carried. DoT and temporary turret buffs remain unsupported.

One conversion constant maps existing pixel-based values to metres: `WorldGeometry.METRES_PER_PIXEL = 0.01`. Movement, weapon range/speed, splash radius, knockback, and pickup radius cross this boundary. Damage and time retain their existing units. Enemy stats come from `EnemyRegistry.get_stats_for_wave`; turret and item prices use shared `EconomyService` policies, used by the supported shop. The fixed repair offer remains arena-specific.

Actors use CharacterBody3D with ground-plane movement, Area3D hurtboxes/pickups, and ShapeCast3D projectile sweeps. Visual bobbing and articulated legs do not move authoritative hitboxes. `CrowdGrid3D` snapshots positions once per physics tick and queries nearby cells for soft separation. Plasma targeting uses the same grid, with cluster counts shared between turrets and refreshed each physics tick. Target acquisition runs at 5 Hz. Enemies have no physics bodies or obstacle navigation; `CrowdGrid3D.resolve_overlaps` hard-separates enemies from each other and from turrets/core each tick (see combat.md). Separation is suspended during a charger warning/dash to preserve the indicated path.

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

Both routes (six-wave slice) reached victory in 267.5 simulated seconds. A re-run on 4 October 2026, identical with and without the Phase 0 tooling, gave: ion finished with 4 ion turrets, 11 purchased item stacks and 331 kills; control finished with the starter ion, 1 plasma, 4 shock, 5 item stacks and 347 kills. Both ended with 33 hull. The kill counts quoted in older sections of these docs predate later balance changes. Human playtesting is still needed to judge difficulty and upgrade value.

Native Vulkan/Forward+ captures use 1280 x 720. `--combat-demo` stages and freezes a warning, plasma impact, and shock pulse for readability review; `--shop` captures refit. The live `--stress` tool warms up for 120 frames and measures 600 wall-clock frame intervals with VSync disabled. Its third-slice mix includes all three turret types.

The third-slice RTX 4090 sample retained **150 enemies, 10 turrets (4 ion / 3 plasma / 3 shock), and 8 projectile instances**: **13.075 ms median / 17.438 ms p95**, with 562 draw calls at capture. This includes slowing pulses and status indicators. The crowded sample's p95 exceeds a 16.7 ms frame budget; it is not a minimum-spec performance guarantee.

On the local RTX 4090, the second-slice sample retained **150 enemies (38 chargers), 10 turrets (5 plasma), and 11 projectile instances**: **11.528 ms median / 16.705 ms p95**, with 533 draw calls at capture. Enemies have 10,000 health to remain present, use registry movement speeds, and the player is invulnerable. This intentionally crowded sample exercises separation, charging, splash, and knockback. The first slice measured 2.248 ms median / 9.568 ms p95 with slower basic enemies and no new combat behavior; the workloads differ and are not a controlled regression comparison. These short development-machine samples do not establish minimum-spec performance. Raw logs and captures are ignored under `.test-results/`.

## Combat polish follow-up

Native spatial weapon, warning, impact, pickup, purchase and run-state sounds are implemented, with bounded voices and persistent SFX volume. Muzzle/hit sparks are pooled. Shared marker resources reduce render overhead. See [combat polish](combat-polish.md) for validation, current measurements and remaining frame-budget work.

Playtest the audio mix and warning readability across six waves. Crowded-scene p95 still needs attention before claiming a consistent 60 fps budget or expanding the content catalog.

## Entrench (Phase 1)

A deployed turret earns one **Entrench** stack for every `ENTRENCH_STACK_SECONDS` (4 s) it spends in combat without being moved, up to `ENTRENCH_MAX_STACKS` (5). Each stack adds +6% damage and +4% fire rate (`GameConstants.ENTRENCH_*`). Picking a turret up resets it, including when the turret is returned to its old spot at wave end. Shop time does not count. A gold ring at the base grows with stacks, and the HUD hint shows the stacks of the nearest turret in reach.

While carrying, a **placement preview** dial shows where the turret will land (teal solid arcs when clear, dashed red when blocked). Placement, range, core, route, terrain and optional actor markers share the flat, antialiased GroundDial style with build zones and entrenchment. Tech-drop warnings fill toward arrival without changing their footprint; combat pulses keep their existing radius and duration.

Both are experiment flags (`entrench`, `placement_preview`), on by default and off in the `release` preset. Stacks are applied on top of the cached modifier stats in `TurretActor._current_stats`, so shop modifiers still multiply as before.

## Protect the Core, tech drops and difficulty (Phase 5)

**Modes.** The home screen picks a mode and a difficulty for the next run. `survive` is the classic run. `core` (flag `mode_protect_core`) places a reactor core at the arena centre; enemies head for it and the run ends if the core **or** the hero dies. `RunConfig.mode` carries the choice (`--mode=survive|core` for tools); with the flag off a core request falls back to survive.

**Core rules** (`GameConstants.CORE_*`, `CoreObjective`, `ArenaWorld.core`):
- The core collision footprint and pedestal are 1.1 m across (`CORE_RADIUS` .55 m); enemy stop/hit distances and turret keep-out use that radius. The decorative gyroscope extends to 1.48 m across above the pedestal and does not change collision.
- The Clockwork core (`cp_core.glb`, `CoreReactorVisual`) has three independent, physics-interpolated ring pivots and a procedural plasma orb. The orb shifts from cyan toward coral as health falls, dims and stops on destruction, and resumes after reset. Reduced motion freezes ring rotation and plasma flow and suppresses hit flashes. `--legacy-assets` retains the original plinth/crystal. Preview with `res://tools/preview_core.tscn -- --motion-preview`; source is in `art-source/clockwork-pop/core/`.
- Core hit points are base hull x `CORE_HEALTH_MULT` x the tier's `core_health_mult`. Enemy contact hits it once per `CORE_HIT_INTERVAL` per enemy for `CORE_DAMAGE_FRACTION` of its contact damage; exploder blasts hurt it too. Enemies stop at its edge.
- Repair in the shop (`REPAIR CORE`, same price per HP as hull repair). There is no passive regeneration.
- Aggro is the 2D rule: an enemy within `CORE_AGGRO_RANGE` (2.5 m) of the hero chases the hero and returns to the core once the hero is beyond `CORE_DEAGGRO_RANGE` (5 m). The state is one bit per enemy (`chasing_hero`); the single goal-selection point is `CombatActor.chase_position()`, and survive mode never calls it.
- Waves spawn on a rectangle at `CORE_SPAWN_BOX` of the arena instead of a ring around the hero. Turrets cannot be placed on the core. The HUD shows a core bar and an off-screen arrow; the minimap marks the core.

**Convoy** (`--mode=convoy`, flag `mode_convoy`). Core rules apply, but the core drives. Each round has a `ConvoyRoute` (`scripts/systems/convoy_route.gd`): the core's current position followed by 2-4 random "doors" (`ConvoyRoute.leg_count(wave)`), each at least `CONVOY_MIN_LEG` from the last and inside the arena minus `CONVOY_EDGE_MARGIN`. `ConvoyMover` drives the core door to door at `PlayerStatsService.get_core_move_speed()` (`CORE_MOVE_SPEED` x the `core_move_speed` stat, floored at `CORE_MIN_MOVE_SPEED`), pausing `CONVOY_PAUSE_TIME` at every door but the last. The round ends on arrival at the final door (the wave timer is the route's duration x `CONVOY_SAFETY_FACTOR`, only a safety net), so the round lasts as long as the route takes and the enemy count scales with that (faster core = shorter round, fewer enemies, less scrap).
- The next route is generated when a round ends (`ArenaWorld.plan_convoy_route`), from a dedicated RNG seeded `hash([run seed, wave])`, so the shop preview is exactly the route that is driven and no shop or spawn rolls are disturbed. The preview is a ground line with numbered door rings (`RouteOverlay`), a minimap polyline, and a "next route" line in the shop's build summary.
- The spawn box follows the core. Turrets stay where built; the hero re-places them. Three convoy-only items (`tracked_chassis`, `overdrive_engine`, `heavy_hauler`, listed in `ShopCatalog.CONVOY_ONLY`) change core speed.
- Untuned: base speed, pause length, door counts and spawn scaling are first guesses.

**Tech drops** (flag `tech_drops`, `TechDropDirector`, `GameConstants.TECH_DROP_*`). Every 5 s of a wave there is a 20% roll (never in the last 10 s, one drop at a time) to place a crate at least 12 m from the core (8 m from every turret) after a 1.5 s amber warning ring. It is a stationary `CombatActor` in the enemy list, so turrets and the hero target it, with half a tank's HP at the current wave. Destroying it scatters scrap and has a 25% chance to secure an item from the Shop's weighted pool. Secured items are reviewed after the wave's XP report, before Shop or victory: explicitly keep each item or sell it for 25% of its Shop value when the chest was opened, rounded down. Sale payouts are fixed and are not boosted by scrap-income items. Multiple rewards queue separately; pending rewards count against item stack limits. An undestroyed chest vanishes at wave end. Drops do not count as kills.

**Build zones are disabled for this balance pass**, including when loading an older save that enabled them. Their encounter code remains available through development flags. Normal runs get new turrets from the Shop and random items from destroyed tech chests; uncollected scrap becomes turret XP when progression is enabled.

**Difficulty tiers** are Easy, Medium, Hard and Brutal (`--difficulty=brutal`). Each keeps the multipliers (health, damage, count, per-wave HP, hull, turret damage) and adds rules (flag `difficulty_rules`, ignored when off): **elites** (share of spawns with more HP, more speed, double scrap and a gold tint) from wave 4 on Hard/Brutal and wave 6 on Medium, with shares rising in later waves, and in core mode **core seekers** (never chase the hero, red ring), a weaker core and a higher arrival rate sustained across the full round (the rate bonus increases the spawn budget rather than ending arrivals early). Elites and seekers are scheduled by a running credit, so the mix is even and uses no gameplay RNG. Tier values live in `DifficultyService.DIFFICULTY_CONFIG`.

Untuned: core HP, damage fraction, spawn box and Brutal values are first guesses. The dodge-bot dies at core waves 4-6 on Easy/Medium and wave 1-2 on Brutal, so treat them as a floor and tune from a human playtest.

## Terrain zones (Phase 4)

Flag `terrain_zones` (experiment). Each run gets one random layout (`ArenaLayouts`: Crossroads, Highlands, The Sump) chosen with the gameplay RNG when the run starts; it stays the same for every wave and a new run picks again (`--layout=id` or `RunConfig.layout_id` forces one). A layout is data: a list of `TerrainZone`s (circle or axis-aligned rectangle, type, strength) that all keep `ZONE_CENTRE_CLEARANCE` (4 m) clear of the origin, where the hero, first turret and core stand.

| Zone | Effect | Where it is applied |
|---|---|---|
| High ground | Turrets on it get +25% range (`ZONE_HIGH_GROUND_RANGE_BONUS`) | `TurretActor._current_stats`, refreshed with the cached stats |
| Mud | Enemies **and the hero** move 45% slower, never more than 90% (`ZONE_MUD_SLOW`, `ZONE_MUD_MAX_SLOW`); stacks with shock slows within the cap | `CombatActor._physics_process` |
| No-build | Turrets cannot be placed there (the preview ring goes red) | `TurretPlacement.valid_placement` |
| Power node | Entrench stacks arrive 50% faster (`ZONE_POWER_NODE_ENTRENCH_BONUS`) | `TurretActor._stack_seconds` |

`TerrainZones` is the runtime view: a 2 m cell grid storing the zones that overlap each cell, so a lookup is one cell read plus a shape test, and mud returns at once on a layout with none. Tech drops avoid no-build and mud ground. The props (`zone_high_ground`, `zone_mud`, `zone_no_build`, `zone_power_node`, `zone_marker`) are built by `tools/blender/build_assets.py` and merged to one mesh per material. Flag `debug_zones` (dev, needs the dev panel) labels every zone with its type and strength.

### Zone readability

Flag `zone_readability` (experiment, `live_safe`, requires `terrain_zones`; toggling it rebuilds the scenery at once, same layout). On, a zone is communicated four ways:

- **Ground:** `assets/shaders/zone_ground.gdshader` draws a pattern on a plane the size of the zone, with the true boundary as a thin edge line. High ground = chevrons climbing the screen, mud = slow sludge with bubbles, no-build = hazard hatching and a barred circle, power node = pulses and spokes running out from the pylon. Four hues (`TerrainZone.TYPES`: blue, olive, hazard orange, violet), none of them damage red. Animation freezes under `reduced_motion`.
- **Names:** each zone has a label ("HIGH GROUND / turrets +25% range") that fades in between `ZONE_LABEL_FADE_RANGE` and `ZONE_LABEL_FULL_RANGE` metres of the hero.
- **Where it matters:** the hint bar shows a `GROUND` line for the zone the hero stands in; the carry preview names the ground it would deploy on; a turret that benefits from high ground or a power node has a ring in that zone's colour; the terrain legend shows during the wave announcement and on the pause screen.
- **Props:** scaled up to fill half the zone (`ZONE_PROP_FILL`, capped at `ZONE_PROP_MAX_SCALE`).

Off restores the original flat tinted disc, edge ring, rim posts and small prop (`TerrainZone.legacy_color`). The readable look is also cheaper: about 70 draw calls against 160 for the rim posts and rings in the Crossroads capture with no enemies. Check either look with `capture_game.tscn -- --zones[=layout] [--focus=<zone type>] [--legacy-zones]` (windowed; writes `.test-results/game-zones.png`).

Not yet: zones do not move between waves, and the hero is not affected by high ground, no-build or power nodes. High ground plus Entrench may reward never moving; compare against Entrench telemetry.

### Ground markers

Settings offers **Off / Contextual / All**, defaulting to Contextual. Contextual hides ordinary enemy/player rings, keeps special-threat markers, and shows turret Entrench rings briefly on stack gain or while within pickup/inspection distance. Core clearance appears while carrying a turret. Off hides these optional markers; build zones, attack warnings, slow-status indicators and combat effects remain visible. Entrench bonuses and collision geometry are unchanged.

### Remembered run choices

Difficulty and mode selections on the title screen are saved immediately and restored on the next launch. Returning to the menu or restarting a run retains the selections. If a saved mode is disabled by a feature flag, the menu uses Survive without overwriting the saved mode.

### Movement smoothing

Moving actors, pickups and the follow camera use physics interpolation to blend rendered poses between simulation ticks. Camera follow runs after actor physics. Idle-animated build zones and effects keep their own render timing. Spawns, reused projectiles, camera snaps and turret carry/place transitions reset interpolation history to avoid trails from old positions. `tools/check_camera_follow.tscn` checks hero stability and enemy movement between rendered frames; run with `--fixed-fps 144`, optionally adding `-- --slow-physics` for a 10 Hz stress check. Normal gameplay retains its existing physics rate.

### Turret level stat rewards

XP costs are unchanged. Level 2 gives +5% damage, level 3 +6% attack speed, and level 4 +10% range. Every fifth level gives +5% damage, +4% attack speed, and +3% range together. In later five-level blocks the first two levels give damage, then speed, then range, then the combined bonus. Bonuses add within each stat rather than compounding per level; they multiply item-resolved stats. Melee uses swing speed. Levels 5/10/15 still queue future evolution forms. Recaps show each increased stat, and turret inspection lists accumulated bonuses.

Approaching a deployed turret within pickup distance reveals its resolved attack range alongside contextual entrenchment. Moving away hides the range unless the global range overlay is enabled. Ground markers Off disables this proximity reveal.

### Expansion roster implementation

Bow, Flamethrower and Bowling are shop base types. Bow fires authored arrows; Flamethrower deals cone damage with attributed burn; Bowling uses rolling, piercing balls with knockback.

Implemented first evolution choices include Machine Gun, Scattershot, Saber, Siege Cannon and Gunblade. Gunblade retains melee ownership and XP; its kinetic blade sweeps continuously while its projectile gun fires along the rotating barrel when aligned with an enemy. Each attack resolves its own item family bonuses. The Turrets tab shows separate gun stats. Gatling and Crossfire are available as second stages; other later forms remain under development.

Bow now supports both branches through levels 5/10/15: Repeater Bow / Volley Ballista / Arrowstorm fire timed 2/3/5-arrow bursts; Greatbow / Harpoon Ballista / Titan Bow fire progressively larger arrows with 3/5/8 extra pierces and knockback. Burst shots retain their firing snapshot and attribution, and pending bursts cancel when combat ends. Distinct chassis treatments for these later forms still need visual polish.

Flamethrower supports Wide Flame / Furnace Fan / Inferno Crown (60/85/110-degree coverage) and Focused Jet / Dragon Nozzle / Dragonheart (longer reach, narrower aim, stronger burn) through all three milestones. Turret inspection shows cone angle and burn DPS/duration. Evolution chassis polish remains pending.

Bowling supports Heavy Roller / Demolition Roller / Juggernaut (larger balls, more piercing and knockback) and Bank Shot / Pinball Engine / Ricochet King (2/4/6 redirects toward fresh nearby enemies). Redirects sweep their remaining movement time on the new path; an enemy is never selected twice by the same shot. Purchased piercing can extend a shot when no fresh recipient is nearby. The loaded ball disappears during reload.

Gunblade now advances to Repeater Blade (two-shot bursts) and Stormblade (three-shot piercing bursts) at levels 10/15. Follow-up rounds leave the rotating barrel along its current heading; they share the original burst snapshot and turret attribution. Pending rounds cancel when combat ends.

Ion branches now reach Cyclone Gatling and Omnifire at level 15. Cyclone ramps to 2.5x resting rate and pierces an additional enemy. Omnifire emits twelve evenly spaced radial directions from its four outward muzzles. These attacks still use the Gatling/Crossfire chassis pending final-stage visual upgrades.

Saber now advances to Twin Saber and Orbit Saber: two opposing or three evenly spaced held blades share an enemy rehit lockout. The additional authored arm/hand/hilt/blade assemblies rotate with Aim and scale with gameplay reach. Native three-stage close preview: tools/preview_evolution.tscn -- --saber-preview.

Siege Cannon now reaches Moonshot and Worldbreaker at levels 10/15. Shell radii grow from .22 to .28 to .34 m, with rising damage, blast radius and knockback. Splash still includes hurtbox overlap at its boundary. The larger final-stage chassis treatment remains outstanding.


## October combat and wave refresh

Damage numbers show actual health lost, with ivory enemy hits, gold critical hits, orange burn ticks and red hero/core damage. Rapid hits combine briefly; the pool is bounded. Fire has a textured stream and persistent burning silhouettes; electrical attacks use branching arcs and expanding double-ring shock pulses. Reduced motion keeps the information without the float/pop or shader motion.

Medium and harder tiers gain a gradual elite/core-seeker ramp after wave 4 (Medium elites start at wave 6; Hard/Brutal still start at wave 4). Waves 8/12/16 introduce progressively heavier compositions. Enemy count now multiplies the existing linear count by `1 + 0.025*n + 0.0015*n*n`, where `n = max(0, wave - 7)`. The first seven waves retain their count. See [the balance tracking document](plans/combat-feedback-and-balance.md) for comparison values and validation limits.

Pip's sidearm benefits from matching Projectile and universal weapon modifiers. Shop inspection includes hero damage, cadence and reach with purchase previews. Turret-only conditional bonuses and entrenchment do not apply to the hero. `RunConfig.hero` holds a copied loadout definition (weapon, attack families, capabilities and starting turret), providing an extension point for future heroes.
