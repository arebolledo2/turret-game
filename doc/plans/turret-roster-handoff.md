# Turret roster expansion: handoff

Written 17 Oct 2026, updated 26 Oct 2026 for the new upgrade shape (see below). Audience: the next agent picking this work up. Treat code as the source of truth where this doc and the repo disagree.

## What this is

The user asked for a full turret roster plan, then moved on to 2D concept art in `image-gen-web`. Design is done and agreed. 2D concept work is nearly done. **No game code or 3D asset has been written for any new turret yet.**

- Live design board (private Claude artifact, read it with the Artifact tool `action: "read"`): https://claude.ai/artifact/Louc8dHXV2KCMke888k3Kn
- That artifact is the most complete record: stats, all branch and stage text, the engine work table (S1-S12), build order, decisions, and embedded concept thumbnails. Read it first.
- Its HTML source lived in a session scratchpad and may be gone. The artifact copy is authoritative.

## Upgrade shape (decided 26 Oct 2026)

This supersedes the old three-stage, two-branch model everywhere below.

- **Level 5:** one shared upgrade per turret, no choice. It is the old stage-1 form closest to the level-1 turret, must be a straight improvement, and needs a visible hardware change.
- **Level 10:** the final form, with two choices. These are the most interesting old stage-3 forms, tuned above the level-5 form. The existing XP curve stays (level 10 is already hard to reach), so finals tuned for level 15 need a re-bench at level 10.
- **No level 15.** Levels continue forever as stat growth only (existing multipliers).
- Implementation spec: `turret-progression-l5-l10-spec.md`.
- Code impact: `TurretProgression.EVOLUTION_LEVELS` becomes `[5, 10]`; `evolution_options()` returns nothing at level 5 and the two finals at level 10; reshape `TurretEvolution.PATHS`, `base_stats`, `model_key`; update the inspector, salvage UI, dev commands and evolution tests.
- Tesla is reworked into this shape (Relay and Capacitor are gone).
- 19 built forms are retired (Echo Chamber, Focused Lance, Thunder Pin, Twin Saber, Repeater Blade, Gatling, Crossfire and so on).

## Result in one paragraph

19 base turrets (8 in game, 5 requested, 6 proposed), each with one level-5 upgrade and two level-10 finals, so 57 forms. 20 are built (7 level-5 upgrades, 13 finals). 37 remain: Constellation and the three Tesla forms, plus 33 on the new turrets. Cryo and Vortex were considered and dropped by the user.

## Roster

| Group | Turrets |
|---|---|
| In game (8) | Ion, Plasma, Shock, Tesla, Melee, Bow, Flamethrower, Bowling Launcher |
| Requested (5) | Sniper (targets toughest), Scrap Press, Decoy, Earthquake, Boomerang |
| Proposed (6) | Mine Layer, Laser, Beacon, Drone Bay, Lullaby, Discord |
| Aggro family (new build family) | Decoy, Lullaby, Discord: weird support turrets that change enemy behaviour. Bosses are immune. |

Roster in the new shape (L5 upgrade, then the two L10 finals). `Built` means playable today.

| Turret | L5 | L10 final A | L10 final B | Status |
|---|---|---|---|---|
| Ion | Machine Gun | Cyclone Gatling | Omnifire | all built |
| Melee | Saber | Orbit Saber | Stormblade | all built |
| Bow | Repeater Bow | Arrowstorm | Titan Bow | all built |
| Flamethrower | Wide Flame | Inferno Crown | Dragonheart | all built |
| Bowling Launcher | Heavy Roller | Juggernaut | Ricochet King | all built |
| Plasma | Siege Cannon | Worldbreaker | Constellation | Constellation unbuilt (needs S12) |
| Shock | Resonator | Resonance Engine | Thunder Spear | all built, final models done |
| Tesla | Forked Coil | Storm Network | Thunderhead | nothing playable; Storm Network and Thunderhead models exist |
| Sniper | Piercer Rifle | Horizon Piercer | Overwatch | all built, real `cp_sniper` model and portraits, runtime hardware per form |
| Scrap Press | Coin Feeder | Treasury | Academy | new |
| Decoy | Bumper Post | Pile Driver | Maelstrom | new |
| Quake | Aftershock | Tectonic | Cataclysm | all built (placeholder Shock chassis, runtime hardware per form, portraits are Shock copies); models pending |
| Boomerang | Sawblade | Perpetual Saw | Boomerang Storm | new |
| Mine Layer | Minefield | Dead Zone | Chain Reaction | new |
| Laser | Focus Beam | Halo Cutter | Sunpiercer | new |
| Beacon | Overclock Beacon | Command Spire | Aegis Field | new |
| Drone Bay | Escort Drones | Guardian Wing | Reaper Swarm | new |
| Lullaby | Deep Sleep | Coma | Sandman | new |
| Discord | Riot Coil | Anarchy | Civil War | new |

Stage text for each form is in the artifact. Where an old stage-2 or stage-3 text assumed earlier stages (Tesla, Overwatch, Treasury, Academy, Maelstrom, Tectonic, Chain Reaction, Aegis Field, Reaper Swarm, Sandman, Civil War), the artifact has the merged wording.

Retired forms with code in `scripts/systems/turret_evolution.gd`: Gatling, Crossfire, Twin Saber, Repeater Blade and so on from `IMPLEMENTED`, plus Echo Chamber, Focused Lance and Thunder Pin. Leave them until the progression change lands, then delete.

The older `doc/plans/turret-evolution.html` names Shock's first branch "Arc Pulse". The code says Resonator, and the code wins.

## Sniper logic (built 26 Oct 2026, branch `turret-sniper`)

`sniper` is a stocked base turret (damage 40, 0.35/s, 700, price 18, `"targeting": "toughest"`, `fire_mode: "instant"`). `TurretActor._fire_instant` re-picks the toughest enemy at fire time and strikes it plus `pierce` enemies on the lane through it (`TurretTargeting.on_lane`). Piercer Rifle pierces 2 behind; Overwatch keeps that; Horizon Piercer uses `SNIPER_UNLIMITED_PIERCE` (the whole line to full range, in front of the target too). Overwatch (`OverwatchForm`) marks the three toughest enemies before each shot; Marked is a new `StatusEffects3D` status (+25% from any turret-sourced hit, multiplies with Exposed) whose mark jumps, keeping its remaining time, when its holder dies. Starting numbers: Piercer Rifle 52 dmg at 0.40/s (20.8 DPS), Horizon Piercer 70 at 0.45 (31.5, 1.51x), Overwatch 56 at 0.42 (23.5 raw, 29.4 against its own marked target, 1.41x); bench rows and the team (+Machine Gun) rows are in `tools/bench_turret_forms.gd`. All three stages use the real `cp_sniper` chassis (model key `sniper` in `FORMS` and the registry); the model is wired and its portraits are rendered. `SniperEvolutionVisual` adds a longer barrel and muzzle brake (Piercer Rifle), a much longer barrel with glowing rails and an emitter ring (Horizon) or a spotter mast and ring (Overwatch), moving `Muzzle` so shots and tracers leave from the new tip.

## Quake logic (built 26 Oct 2026, branch `turret-quake`; models pending)

`quake` is a stocked base turret (damage 16, 0.45/s, range 260, rotation 0, knockback 200, stagger 0.4, price 17, Physical, families Kinetic and AoE, `fire_mode: "pulse"`). `QuakeForm` (`scripts/game/quake_form.gd`) takes over `TurretActor`'s `FIRE_PULSE` branch: a 0.5 s ground telegraph, then a `ShockwaveRing` at 8 m/s that strikes each enemy once as it touches it (nearest first). Aftershock (18, 0.45/s) queues a second ring 0.6 s later at 50% damage. Tectonic (40, 0.5/s, range 400) skips the ring and opens two fissures in an X (45 degrees either side of the line from the turret) at the densest cluster (`Combat3D.select_target` with the cluster radius `TECTONIC_CLUSTER_RADIUS`, 1.5 m); each is an S7 line zone centred on that enemy (half length 65% of reach, half width 0.45 m, both growing with range and area bonuses; 3 s; 40% slow) that hits what stands in it once as it opens. Cataclysm (30, 0.5/s) repeats up to three more rings every 0.9 s while enemies stay in range, each 20% wider, capped at 1.6x the reach, and its hits `extend_stagger` (1 s each, cap 1.5 s); the cooldown starts when the salvo ends. Bench (level 10, 120 s, DPS single / cluster / lane): Aftershock 29 / 239 / 90; Tectonic 47 / 334 / 146 (1.40x on a cluster, 1.6x single: the fissure always lands on a lone target); Cataclysm 42 / 354 / 130 (1.48x cluster, 1.45x single). Level 5: Quake 14 / 113 / 28, Aftershock 23 / 195 / 49. Level 10 base Quake: 18 / 146 / 53.

New engine pieces: **S7 `GroundZones`** (enemy-only circles and oriented lines with a slow, pooled visuals, cap 16, cleared when combat stops; `EnemyActor._steer` reads `speed_factor_at`) and the **stagger status** (`StatusEffects3D.stagger/extend_stagger`, `CombatHit3D.stagger_duration/stagger_cap`, stat `stagger`). API and rules are in `doc/combat.md`. Placeholders: the chassis is the Shock bell (model key `shock`); `QuakeEvolutionVisual` adds a foot plate (Quake), pistons and a ring (Aftershock), crossed blades and spikes (Tectonic), stacked rings and pylons (Cataclysm); portraits `quake.png`, `aftershock.png`, `tectonic.png`, `cataclysm.png` are copies of `shock.png`. Real models and portraits are still to do.

## Shock / Lance logic (built 17 Oct 2026)

Under the new shape only Thunder Spear (L10 final) survives from Lance. Focused Lance and Thunder Pin are retired. The numbers below are the old stage numbers.

`lance` is in `TurretEvolution.IMPLEMENTED`. It keeps Shock's `FIRE_PULSE` mode but `TurretActor._fire_lance` replaces the pulse with a bolt at the nearest enemy (same `chain_arc` visual as Tesla). Model key falls back to `shock`, so the existing chassis and base portrait stand in until real models land.

| Form | Level | Damage | Rate | Range | Slow | Behaviour |
|---|---|---|---|---|---|---|
| Focused Lance | 5 | 24 | .75 | 300 | 30% / .8 s | single bolt |
| Thunder Pin | 10 | 36 | .80 | 340 | 90% / 1.6 s | near-stop pin |
| Thunder Spear | 15 | 48 | .85 | 400 | 90% / 2.0 s | also hits every enemy in a 1.2 m lane behind the target (`LANCE_LANE_HALF_WIDTH`) |

To swap in real models: add `lance`/`thunder_pin`/`thunder_spear` keys to `ClockworkModels.KEYS`, return them from `TurretEvolution.model_key`, keep a `Muzzle` node, and add `res://assets/ui/turrets/lance_{1,2,3}.png` portraits. Stats and numbers are untuned; no showcase run yet.

## Shock / Resonator logic (built 17 Oct 2026)

Under the new shape Resonator is the L5 upgrade and Resonance Engine an L10 final. Echo Chamber is retired.

`resonator` is in `IMPLEMENTED`. `TurretActor._fire_resonator` pulses as before, then queues echoes that `_tick_resonator` fires later at 50% damage (Resonator: one at 0.5 s; Echo Chamber and Engine: 0.4 s and 0.8 s). Echo Chamber and Engine reach 15% farther (range 276). Resonance Engine alternates an inner pulse (half radius, double damage) with an outer pulse (130% radius); an enemy struck by both within 1.2 s is Exposed for 2 s. Echoes copy the ring of the pulse that spawned them but never count towards Exposed.

**Exposed (S3) is built:** `StatusEffects3D.expose()`, `exposed_remaining` and `exposure_multiplier()`; `CombatActor.receive_hit` applies +30% to hits whose `attack_families` include `instant`. Sniper Spotter and Lullaby can reuse it (Spotter's mark is a different bonus, +15% from every turret, so it will need its own multiplier). There is no visual cue on Exposed enemies yet. Models and portraits follow the same swap-in steps as Lance, using `resonator_{1,2,3}`.

## Decisions already made by the user

- Decoy has **infinite health**, so no turret health system. It taunts, does light kinetic damage with knockback through a pulse (3 dmg every 1.5 s, radius 150), and its upgrades raise damage (Bumper branch) or extend hooks and pull (Siren branch).
- Sleep and infighting are **separate turrets** (Lullaby, Discord), not Decoy upgrades.
- No-attack turrets (Scrap Press, Beacon, Lullaby, Discord) are **excluded** from the Focused Arsenal check and from the Army Doctrine and Crosslink Array counts. Add an `"aggro"` entry to `TurretRegistry.FAMILIES`.
- Cryo and Vortex are omitted.
- Upgrade shape: level 5 one upgrade, level 10 two finals, infinite levels after, XP curve unchanged, level-5 forms must visibly change, Tesla reworked to match (26 Oct).

Still open (recommendations are in the artifact): the shop slot count with 19 bases (one weapon per visit today, `GameConstants.SHOP_OFFER_COUNT`), whether to hold Drone Bay and Beacon until the first batch is playtested, and whether Decoy ever gets health.

## Codebase facts worth knowing (verified 12 Oct 2026)

- Registry: `scripts/registries/turret_registry.gd`. It already has unstocked `sniper` (instant, range 750, `"farthest"` targeting), `fire` (redundant with Flamethrower; retire it) and `mine` entries. `mine` has only the DEPLOYABLE attack style, which maps to no item family in `get_attack_families()`, so no item would apply until AOE is added.
- `GameEnums.DamageType` is Physical, Fire, Electric, Plasma. "Kinetic" is only an attack family.
- Turrets cannot be damaged, and enemies are hard-separated from turrets. Enemy goal selection is `CombatActor.chase_position()`.
- Status effects cover slow (90% cap) and burn only (`StatusEffects3D`). Terrain mud slows the hero as well as enemies.
- Evolution architecture: `TurretEvolution` (paths, `base_stats`, `shape_shot`, `description`), `TurretActor` dispatch, and `*_evolution_visual.gd` for articulated runtime hardware that reuses frozen chassis models through `model_key`. Copy the Bow, Flame and Bowling visual passes in `doc/plans/turret-expansion-progress.md`.
- Shop screens, portraits, controller flow and tests exist for the current roster; see `doc/plans/turret-expansion-audit.md`.

## Shared engine work (S1-S12; sizes are in the artifact)

- S1 Taunt targeting and pull (Decoy)
- S2 Targeting modes: toughest and backline-first (Sniper, Drone Hunters, Limpet)
- S3 Exposed status, a damage-taken multiplier (Spotter, Resonance Engine, Lullaby)
- S4 Enemy behaviour overrides: sleep and enemy-vs-enemy (Lullaby, Discord)
- S5 Scrap generation, direct deposit and direct XP (Scrap Press)
- S6 Returning projectile path (Boomerang)
- S7 Enemy-only ground zones (Earthquake Fault Line)
- S8 Deployable runtime (Mine Layer)
- S9 Auras and healing (Beacon)
- S10 Drone actors (Drone Bay)
- S11 Continuous beam (Laser)
- S12 Delayed ground-target shell (Mortar)

## Suggested order

0. Progression change to the L5/L10 shape (see above), then targeting modes, Exposed status (built), DEPLOYABLE family mapping, utility-turret item rules.
1. Finish Plasma and Tesla (4 forms: Constellation needs S12; Forked Coil, Storm Network, Thunderhead). Then re-bench every existing final at level 10 against its level-5 form.
2. Sniper, Earthquake, Decoy, Scrap Press, Boomerang.
3. Mine Layer and Laser; Beacon and Drone Bay after a playtest.
4. Lullaby and Discord (S4 is the largest piece).

The per-turret definition of done matches the existing roster: attack, a level-5 upgrade and level-10 finals, a visible silhouette change per form, Shop portrait, controller flow, showcase run and tests. Use `.claude/skills/godot-test` for tests and `.claude/skills/2d-to-3d-asset` for models.

## 2D concept art (image-gen-web, local API on port 3000)

Style used throughout: **Clockwork Pop** (style id `3b7b7bc4-4403-4b69-8a10-809235eb4924`), category Turret (`d6f603f7-5efe-4005-9ac1-3d11bda5276c`), provider `comfyui`, 1024x1024, magenta `#FF00FF` background. Prompts are composed as plain text. The generation code in `image-gen-web/lib` has no reference-image support, so each capstone prompt describes its base turret in words and may not match the favorited base exactly.

| Batch | Id | Contents |
|---|---|---|
| New Turret Roster - 3 Each | `ce5635c2-d52d-4699-8976-f8583d51fb72` | 11 base concepts, 3 each |
| Boomerang and Lullaby Retry - 3 Each | `e74ea1bc-beb2-4721-9913-748255d6a6a5` | 4 concepts replacing the rejected Wing Slinger and Cradle Chime |
| Level 15 Mastery Forms - 2 Each | `5ef1997e-50d6-4d4d-99b9-77a9cdbe2712` | 27 capstones, 2 each |

Favorited base concepts (image ids; use these as inputs to `2d-to-3d-asset`):

| Turret | Concept | Image id |
|---|---|---|
| Beacon | Lantern Mast | `86239ee7-f870-42d9-b629-f6bd70d061dd` |
| Boomerang (finalist) | Windup Disc | `57ab7a66-b07d-47a1-a053-c5d0fc0fb6b1` |
| Boomerang (finalist) | Return Pitcher | `3f18ef58-efed-4d73-925e-ea855210541d` |
| Decoy | Bumper Post | `d4c09728-afeb-40a7-8a26-fe840674916a` |
| Discord | Tuning Fork Riot | `7061d2b8-18ab-449b-a55a-d2c2fe92b6c8` |
| Drone Bay | Hive Dock | `4a06cfce-8174-4dcf-ba63-f278632f012d` |
| Earthquake | Thumper | `368cb3c5-8b81-49c7-8a59-064dab860214` |
| Laser | Prism Needle | `a8164453-ff54-465f-8f76-fd643711dcaf` |
| Lullaby (finalist) | Pendulum Hush | `0f0ea218-2bbd-4c6b-be67-c9a188b18bfc` |
| Lullaby (finalist) | Crescent Nightlight | `61c7f1d5-d6fe-4d6a-9124-0a0fa44c99bc` |
| Mine Layer | Pocket Sapper | `ef59bb3a-5146-4794-b6ab-26f67d941cb2` |
| Scrap Press | Tinker Press | `bd3f2f9a-19a3-45f3-942a-314f2411a6b6` |
| Sniper | Plumb Rifle | `1be85414-42ab-4607-8b6f-1c5c7145dfb8` |

Boomerang and Lullaby each have **two finalists**. The user has not picked one yet.

Final-form concept favorites. These were generated as level-15 capstones and are now the level-10 finals (the Plasma/Mortar, Resonator, Lance, Relay and Capacitor rows map to Constellation, Resonance Engine, Thunder Spear, Storm Network and Thunderhead):

| Branch | Concept | Image id |
|---|---|---|
| Plasma / Mortar | Constellation | `a74431ea-7511-4385-9fcd-dff7e31aa656` |
| Shock / Resonator | Resonance Engine | `2568b133-906f-470e-abaa-c2b04806f33b` |
| Shock / Lance | Thunder Spear | `108af945-655e-41a1-bab8-dbe76d052595` |
| Tesla / Relay | Storm Network | `452c55e5-3ea7-498b-8346-bcf91bd0e0aa` |
| Tesla / Capacitor | Thunderhead | `0d4b7673-dee9-4195-9a1c-fb70154f8786` |
| Sniper / Piercer | Horizon Piercer | `68859448-975c-4e5d-9ce4-3c6a47299951` |
| Sniper / Spotter | Overwatch | `9839d0fd-6a4d-428c-a93f-c768d7ad8cb9` |
| Scrap Press / Mint | Treasury | `bf69887e-b85c-4e31-9ba2-ded8723bcaab` |
| Scrap Press / Salvage | Academy | `86160a31-2191-412e-b16d-1cd62b7df869` |
| Decoy / Bumper | Pile Driver | `7a8c0bf1-0b24-4a9f-a4dd-17cc2a2e3a59` |
| Decoy / Siren | Maelstrom | `35af3905-b264-41a0-b47b-5effe8fc676e` |
| Earthquake / Fault Line | Tectonic | `fad6751a-1e22-487e-ac18-975c5849d17e` |
| Earthquake / Aftershock | Cataclysm | **no favorite yet** |
| Boomerang / Sawblade | Perpetual Saw | **no favorite yet** |
| Boomerang / Splinter | Boomerang Storm | **no favorite yet** |
| Mine Layer / Minefield | Dead Zone | `f392aec0-2c73-4003-9896-c6df502d4a43` |
| Mine Layer / Limpet | Chain Reaction | `06a3b980-42a6-44ea-bbb1-190a7599fd60` |
| Laser / Sweep | Halo Cutter | `90d1141d-4164-4ada-9ee8-321181b80e9e` |
| Laser / Focus | Sunpiercer | `38b44d34-85f8-4ea2-8db0-8f09bd318a40` |
| Beacon / Overclock | Command Spire | `0e0e3564-5eb0-47b2-8a3a-0f05de834e62` |
| Beacon / Mender | Aegis Field | `884f984a-0e17-4a3e-b578-84eff29c4dad` |
| Drone Bay / Escort | Guardian Wing | `ca0bea82-f5fb-4ed7-bb4c-6dccf2879aa9` |
| Drone Bay / Hunter | Reaper Swarm | `1ec1bff8-6df0-48cb-aab2-cde16cc0e0d3` |
| Lullaby / Deep Sleep | Coma | `7046b099-b492-46d4-8260-8761a05e26ee` |
| Lullaby / Drowse Field | Sandman | `3c00981b-f021-4112-9cff-c95dabb65603` |
| Discord / Riot | Anarchy | `16326d70-b87f-41b4-aee9-3600f5b712d0` |
| Discord / Mutiny | Civil War | **no favorite yet** |

Four capstones have no favorite: Cataclysm, Perpetual Saw, Boomerang Storm and Civil War. Regenerate them or ask the user before building those branches.

Not yet generated: level 5 concepts. Existing turrets handled those as runtime attachments on the chassis, but the new rule is that the level-5 form must visibly change, so generate or sketch one per new turret before building.

### API notes

- `jq` is not installed. Use PowerShell `Invoke-RestMethod` and send UTF-8 bytes for request bodies.
- Create subjects with `POST /api/subjects` (`name`, `description`, `isTransparent`, `categoryId`), then `POST /api/batches` with `prompts: [{promptText}]`, then `POST /api/batches/<id>/execute`. Batch prompts here are not linked to subjects, so the gallery labels come from the prompt text.
- List images with `GET /api/images?batchId=<id>&limit=100&offset=0`. Favorites are the `isFavorite` flag. The skill is `.claude/skills/image-gen-api`.
- Subject names are placeholders chosen by the previous agent and are safe to rename.

## Other changes made along the way

- `image-gen-web/components/batch/image-gallery.tsx` and `image-gen-web/app/batches/[id]/page.tsx`: the batch gallery now groups images by subject (batch prompt), with a "Group by subject" switch and per-group favorite counts. Typecheck and lint were clean. These edits are not committed.
- Nothing in `turret-game` changed apart from this file.
