# Turret roster expansion: handoff

Written 17 Oct 2026, last updated 29 Oct 2026 (upgrade shape, groundwork, Sniper, Quake, Decoy and S1, form-table refactor, Scrap Press and S5). Audience: the next agent picking this work up. Treat code as the source of truth where this doc and the repo disagree.

## What this is

The user asked for a full turret roster plan, then 2D concept art, then 3D base models, then started bringing turrets into the game one at a time. Design is agreed. **Sniper, Quake, Decoy and the Scrap Press are in the game with real models** (Scrap Press logic, forms and S5 on branch `turret-scrap-press`, its model wired on `turret-scrap-press-model`). The other seven new turrets have favorited base concepts and (for five of them) built 3D base models in `3d-eval/`, but no game code yet.

- Live design board (private Claude artifact, read it with the Artifact tool `action: "read"`): https://claude.ai/artifact/Louc8dHXV2KCMke888k3Kn
- That artifact is the most complete record: stats, all form text, the engine work table (S1-S12), build order, decisions, and embedded concept thumbnails. It was brought up to date on 29 Oct (version 8). Read it first.
- Its HTML source lived in a session scratchpad and may be gone. The artifact copy is authoritative.
- Review of the codebase before adding more turrets: `codebase-review-2026-10.md`. Per-turret loop and order: `turret-bringup-plan.md`.

## Where the work lives

All of it is on `master` (and pushed to `origin/master`) as of 28 Oct 2026; the stacked feature branches are gone. In commit order:

| Commits | Contents |
|---|---|
| `726171f` | Level 5 / level 10 shape, forms by form id, `evolution_form`, portraits renamed, tests; the spec |
| `a45a86a`, `dfc8ece` | Bring-up plan; groundwork: `TurretTargeting` (toughest, backline, farthest), DEPLOYABLE-to-AoE mapping, `aggro` family, `no_attack` marker and its item rules |
| `0df37d9`, `b6385b8` | Sniper logic, then the real `cp_sniper` model wired |
| `87d97dc`, `8a31197` | Quake logic (S7 ground zones, stagger), then the real `cp_quake` model wired |
| `177bb98`, `9db2e53`, `9427ac7`, `eecb26e`, then a docs commit (branch `turret-decoy`, not merged or pushed) | Decoy: S1 taunt and hooked enemies, the turret with its three forms, perf and amber placeholder tint, bench/showcase/capture tools, docs. Built on top of the owner-tagged timed statuses (`a6ce997`) |
| branch `turret-scrap-press` (not merged or pushed): `3bfac8f`, `3c8eb5d`, `30a8b6e`, then a docs commit | Scrap Press: S5 scrap income (`ScrapIncome`, direct XP in the salvage ledger, wave-end hook), the no-attack turret with Coin Feeder, Treasury and Academy, bench/showcase/capture tools, docs |
| branch `turret-scrap-press-model` (on top of `turret-scrap-press`, not merged or pushed) | Scrap Press model: promote `cp_scrap_press`, wire the chassis, fit the hardware (with the golden literals), real portraits, docs |
| `29e7a48` to `d3ae7a0` | Codebase review; golden snapshot test; `legacy_stage` and dead stage-2 data removed; one table row per form (`scripts/data/turret_forms.gd`); roster contract tests and shared test helpers |
| `1734dd3` to `666c7e9` (27 to 28 Oct, not written up here) | Further refactors: typed `TurretStats` cache, per-form DPS estimates and barrel checks moved onto `TurretForm`, melee sweep moved to `SweepForm`, run state read from `RunSessionState`, `CombatEffects3D` split into `StatusVisuals3D` and `BoltEffects3D`, `TurretActor` and `WaveDirector` constants named. Read `git log` and `doc/architecture.md` before relying on the "Not done" list below. |

The review recommended a line-ending normalisation commit (`.gitattributes`, `.editorconfig`): check whether it has happened (many `.gd` files were CRLF and some mixed, which made agent edits produce whole-file diffs).

## Upgrade shape (decided 26 Oct 2026, landed)

This supersedes the old three-stage, two-branch model everywhere below.

- **Level 5:** one shared upgrade per turret, no choice. It is the old stage-1 form closest to the level-1 turret, must be a straight improvement, and needs a visible hardware change.
- **Level 10:** the final form, with two choices. These are the most interesting old stage-3 forms, tuned above the level-5 form. The existing XP curve stays (level 10 is already hard to reach), so finals tuned for level 15 need a re-bench at level 10.
- **No level 15.** Levels continue forever as stat growth only (existing multipliers).
- Implementation spec: `turret-progression-l5-l10-spec.md`.
- Landed: `TurretProgression.EVOLUTION_LEVELS` is `[5, 10]`, `evolution_options()` offers one form at level 5 and the two finals at level 10, and forms are addressed by form id (`evolution_form`). The level-5 evolve stays a free, player-triggered shop button. The retune (finals about 1.4 to 1.6 times the upgrade at level 10) is done for Sniper and Quake; the existing 20 finals still need the bench pass.
- Tesla is reworked into this shape (Relay and Capacitor are gone).
- 19 built forms are retired (Echo Chamber, Focused Lance, Thunder Pin, Twin Saber, Repeater Blade, Gatling, Crossfire and so on).

## Result in one paragraph

19 base turrets (12 in game, 1 requested, 6 proposed), each with one level-5 upgrade and two level-10 finals, so 57 forms. 32 are built (7 level-5 upgrades and 13 finals on the original turrets, plus all 6 Sniper and Quake forms, the 3 Decoy forms and the 3 Scrap Press forms). 25 remain: Constellation and the three Tesla forms, plus 21 on the eight other new turrets. Cryo and Vortex were considered and dropped by the user.

## Roster

| Group | Turrets |
|---|---|
| In game (12) | Ion, Plasma, Shock, Tesla (no evolutions yet), Melee, Bow, Flamethrower, Bowling Launcher, Sniper, Quake, Decoy, Scrap Press |
| Requested, not built (1) | Boomerang |
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
| Scrap Press | Coin Feeder | Treasury | Academy | all built (logic and S5), real `cp_scrap_press` chassis |
| Decoy | Bumper Post | Pile Driver | Maelstrom | all built: real `cp_decoy` chassis and portraits (branch `turret-decoy-model`), runtime hardware per form |
| Quake | Aftershock | Tectonic | Cataclysm | all built, real `cp_quake` model and portraits, runtime hardware per form |
| Boomerang | Sawblade | Perpetual Saw | Boomerang Storm | new |
| Mine Layer | Minefield | Dead Zone | Chain Reaction | new |
| Laser | Focus Beam | Halo Cutter | Sunpiercer | new |
| Beacon | Overclock Beacon | Command Spire | Aegis Field | new |
| Drone Bay | Escort Drones | Guardian Wing | Reaper Swarm | new |
| Lullaby | Deep Sleep | Coma | Sandman | new |
| Discord | Riot Coil | Anarchy | Civil War | new |

Stage text for each form is in the artifact. Where an old stage-2 or stage-3 text assumed earlier stages (Tesla, Overwatch, Treasury, Academy, Maelstrom, Tectonic, Chain Reaction, Aegis Field, Reaper Swarm, Sandman, Civil War), the artifact has the merged wording.

Retired forms: the dead stage-2 data is gone from `turret_evolution.gd` (refactor commit `696bc29`). Still on disk and unused: 23 old-stage portraits under `assets/ui/turrets/` and three model keys (`scatter`, `focused_lance`, `thunder_pin`) in `ClockworkModels.KEYS`. Delete them in a cleanup commit.

The older `doc/plans/turret-evolution.html` names Shock's first branch "Arc Pulse". The code says Resonator, and the code wins.

## The form table (refactor, 28 Oct 2026)

Every form is one row in `scripts/data/turret_forms.gd` (`TurretForms.FORMS`): base turret, kind (upgrade or final), name, model, description, stat overrides, implemented flag, behaviour class and visual class (named by string). `TurretEvolution` is the accessor layer; `TurretForm.create` and `TurretActor._rebuild_model` dispatch through the row. The header comment of the table lists the remaining touch-points ("Adding a turret"). `tests/unit/test_turret_form_golden.gd` snapshots every form's stats and shape; `tests/integration/test_turret_roster_contract.gd` buys every stocked turret and takes it through every implemented form. `TestHelpers.disable_crits()` and `TurretTestRig` are the shared test helpers. About 19 touch-points remain per new turret (was about 27). As of the 26 Oct review, not done: form hooks for the UI and splitting `TurretActor`. The owner-aware timed-status mechanism (`TimedStatus` timers keyed by turret source id inside `StatusEffects3D`, with `apply_timed`/`is_active`/`remaining`/`clear_timed`) is done on branch `status-owned-timers`; it also fixes the two-Overwatch unmark bug. Per-status marker/tick tables in `EnemyActor`/`CombatActor` are still bespoke. Later commits (see the table above) moved per-form DPS estimates onto `TurretForm` and extracted the melee sweep, so re-check what remains.

## 3D models

- Nine base models were built by Sonnet agents in `3d-eval/runs/cp_<name>-v1/` and all passed the harness contract: Sniper, Scrap Press, Decoy, Quake, Mine Layer, Laser, Beacon, Drone Bay, Discord. Triangle counts are high (7k to 28k against a 5k target; Drone Bay is 28k with 29 objects). **Wired into the game: Sniper, Quake, Decoy and Scrap Press.** The other five (Mine Layer, Laser, Beacon, Drone Bay, Discord) are not promoted and have no game code (the Scrap Press was wired on `turret-scrap-press-model`, see its section). A triangle-reduction pass was offered and not done. Setting `"origin_node": "Aim"` in the contract for long-barrel turrets (Mine Layer, Discord) would likely give better proportions than the centring workaround the agents used.
- Boomerang and Lullaby models are not started (finalist concept not chosen).
- Wiring a model: copy the subject JSON to the run's `contract.json`; add the key to `tools/promote_clockwork_asset.py` and `ClockworkModels.KEYS`; run `python -I turret-game/tools/promote_clockwork_asset.py <key> --iteration N --asset-name cp_<name>`; set the model in the form rows (`model` field) and the registry `model_key`; add the key to the Aim/Muzzle list in `tests/integration/test_clockwork_roster.gd`; adapt the `*EvolutionVisual` runtime hardware to the real model (read the bore from the model's `Muzzle`); render portraits with `tools/render_shop_portraits.tscn` (non-headless), `git checkout` every regenerated portrait except the new ones and delete the stray `forked_coil.png`, then re-run `--headless --import` before taking shop screenshots; commit the extracted texture PNG and `.import` with the GLB. The `3d-asset-design` skill still describes the old stage shape; the steps here are current.

## Sniper logic (built 26 Oct 2026, branch `turret-sniper`)

`sniper` is a stocked base turret (damage 40, 0.35/s, 700, price 18, `"targeting": "toughest"`, `fire_mode: "instant"`). `TurretActor._fire_instant` re-picks the toughest enemy at fire time and strikes it plus `pierce` enemies on the lane through it (`TurretTargeting.on_lane`). Piercer Rifle pierces 2 behind; Overwatch keeps that; Horizon Piercer uses `SNIPER_UNLIMITED_PIERCE` (the whole line to full range, in front of the target too). Overwatch (`OverwatchForm`) marks the three toughest enemies before each shot; Marked is a new `StatusEffects3D` status (+25% from any turret-sourced hit, multiplies with Exposed) whose mark jumps, keeping its remaining time, when its holder dies. Starting numbers: Piercer Rifle 52 dmg at 0.40/s (20.8 DPS), Horizon Piercer 70 at 0.45 (31.5, 1.51x), Overwatch 56 at 0.42 (23.5 raw, 29.4 against its own marked target, 1.41x); bench rows and the team (+Machine Gun) rows are in `tools/bench_turret_forms.gd`. All three stages use the real `cp_sniper` chassis (model key `sniper` in `FORMS` and the registry); the model is wired and its portraits are rendered. `SniperEvolutionVisual` adds a longer barrel and muzzle brake (Piercer Rifle), a much longer barrel with glowing rails and an emitter ring (Horizon) or a spotter mast and ring (Overwatch), moving `Muzzle` so shots and tracers leave from the new tip.

## Decoy logic (built 29 Oct 2026, branch `turret-decoy`; model wired on `turret-decoy-model`)

`decoy` is a stocked base turret (price 10, damage 3, 1.0/1.5 s, pulse reach 150, knockback 150, `taunt_range` 450 in 1/100 m, `FIRE_PULSE`, AoE and Kinetic families, `FAMILIES["aggro"] = ["decoy"]`, model key `decoy`). One class, `DecoyForm` (`scripts/game/decoy_form.gd`), serves the base and all three forms; form rows in `scripts/data/turret_forms.gd` only change numbers and params. It publishes a `TauntPost` to `world.taunts` and fires a pulse that hand-resolves its hits (no scorch decals) with the `DECOY_TINT` wave.

- **Bumper Post (L5):** damage 8, rate 1.0/1.2, knockback 225. Damage x1.10 and speed x1.10 at L5.
- **Pile Driver (L10):** every fourth pulse is a slam (x3 damage, x1.5 reach, 0.6 s stagger). Damage 8, rate 1.0/1.2, reach 180.
- **Maelstrom (L10):** taunt range 700 and ranged enemies answer it; hooks up to 10 enemies (scan every 0.25 s, nearest first) that circle the post on 3 lanes at `MAELSTROM_RING` 1.1 m, ignoring the hero; each hook ticks 25% of pulse damage every 0.5 s as an AoE damage-over-time hit. Damage 7.5, knockback 120.

**S1 (built):** `TauntField`/`TauntPost` (`scripts/game/taunt_field.gd`, `taunt_post.gd`), `EnemyActor.chase_position()` is the single goal chooser (taunt first, then core and hero logic), `EnemyEcology.taunt_kind` (NONE for bosses, lens, anchor, puppet and tech drops; RANGED for Kite, Lobber and Tender; MELEE otherwise). Stationary enemies, `ignores_hero` core seekers and sleeping Drowse Beetles never answer. The hooked status is a generic owner-tagged timed status (`TauntField.HOOKED`), applied by `EnemyActor.hook(owner)` and dropped when no live post holds it. Two Decoys never clear each other's hooks. New `TurretForm.removed()` hook runs from `_exit_tree` and on evolve, releasing a Decoy's hooks; hooks also drop on wave end, pause and reset (and are re-applied within 0.25 s of resuming). There is no sell mechanic yet, so "sold" means removal from the tree. A carried Decoy releases its hooks.

**S1 performance:** with no Decoy each enemy pays one `posts.is_empty()` check (about 0.87 us per enemy per tick); with three posts about 2.2 us (4.5 us before the cached x, z and radius-squared floats). The hook scan is 4 Hz and capped at 10.

**Tuning deviations from the spec:** Pile Driver is 8 damage at 1.2 s, not 14 at 1.0 s, and Maelstrom is 7.5 damage; the spec numbers benched about 3.2x too strong. `tools/bench_turret_forms.gd` has decoy rows plus `pull` and `pull_far` scenarios (one aggro turret at a time at the origin, because real enemies are clamped to the arena). Pile Driver's reach advantage inflates the stationary-cluster bench (about 2.4x); trust the held-percentage table for the aggro role.

**Visuals:** all three forms and the base use the real `cp_decoy` chassis (model key `decoy` in `FORMS` and the registry; a teal lantern-headed post on a spring and cream base blocks, 19.9k triangles, 15 objects; `Aim` carries head, eyes, pods, bumper ring and lantern, `Muzzle` sits between the eyes) and have real portraits (the `turret_decoy` shop icon is a vector glyph, not a Shock copy). `DecoyEvolutionVisual` reads the base radius, bumper ring and lantern from the model and adds posts whose pads meet the ring and a rubber band (Bumper Post), piston columns with ram heads and a hammer head on the lantern cap (Pile Driver), a hooked mast above the lantern and two lane rings (Maelstrom). The hardware is static and does not turn with the head. Known model differences from the concept: flatter bumper ring with boxy blocks, left lens the same purple as the right, pale bulb.

**Not verified:** only capture and preview screenshots, no human playtest. Hook and orbit feel, and Kite or Lobber aiming at a Maelstrom, are unit-tested only. Docs note: `doc/gameplay.md` and `doc/combat.md` already contained duplicated Quake paragraphs before this work.

**Model wiring: done** (branch `turret-decoy-model`). Triangle cost is 19.9k per Decoy; the per-form bench numbers were not taken on that branch because the GPU was busy (run `tools/bench_turret_forms.gd --base=decoy --level=10 --seconds=120`, and level 5, once it is free).

## Scrap Press logic (built 29 Oct 2026, branch `turret-scrap-press`; model wired on `turret-scrap-press-model`)

`scrap_press` is a stocked base turret (price 14, `FIRE_NONE`, `"no_attack": true`, no build family, `fire_rate` 0.25 drops a second, `range` 150 for how far a drop lands, `damage` 0 only because the stat pipeline multiplies it). One class, `ScrapPressForm` (`scripts/game/scrap_press_form.gd`), serves the base and all three forms; rows only change numbers and params. It does not attack, target or turn: `TurretActor` returns after `form.tick`. **S5 is built** as `ScrapIncome` (`world.scrap_income`): pickup, cash and direct-XP exits, the direct-XP tally folded into the wave's salvage ledger, a `TurretForm.wave_end_scrap` hook and `ArenaWorld.spawn_scrap_pickup`. API, ledger rules and clean-up are in `doc/combat.md` ("Scrap income and the Scrap Press (S5)").

- **Scrap Press (base):** a drop every 4 s worth `1 + (wave - 1) / 5` scrap, laid as a real pickup within 1.5 m. Left at wave end it is salvaged into XP like kill scrap (and counts in the wave's drops and the abandoned share).
- **Coin Feeder (L5):** half of each drop to the wallet (`deposit_share` 0.5; an owed fraction carries over so a one-scrap drop alternates 0 and 1), the rest on the floor. Same rate as the base. Brass hopper, chute and coin tray.
- **Treasury (L10):** every drop deposited, rate x1.25 (0.3125), and `wave_end_scrap` pays interest after the wave bonus: 1 per 10 held, at most 5 (`ScrapIncome.pay_interest`, from `WaveDirector.finish_wave`, shown as "+N interest" in the wave message). Ingot stacks, vault dome, coin ring.
- **Academy (L10):** no scrap; every drop is XP, in full, to each placed turret within 6 m of the press (itself included) through `WaveSalvage.award_direct` (levels land mid-wave). Rate 0.125 (one per 8 s). Mortarboard, books, halo.
- **Stacking:** a second press keeps 60% of its output (charge rate and interest), a third and later 40%; the rank is the number of placed presses with a lower turret id, refreshed with the stats at 4 Hz, and a carried press does not count.

**Decisions where the card was silent or the engine disagreed (flagged in the report):** (1) the id is `scrap_press` (the roster artifact calls it `scrap`). (2) Academy's output is halved (one drop per 8 s); the card gives no figure, and at the card's 4 s three turrets in reach would be about 3x Coin Feeder's scrap in XP, far past the 1.4 to 1.6x finals target. (3) Treasury's "output +25%" is 25% more drops (rate), not bigger drops, so values stay whole numbers. (4) The card stops at a third press at 40%; any later press also keeps 40%. (5) Drop value scales 1 more per five waves (the card says only "scales with wave"). (6) Because the output stat is `fire_rate`, level speed bonuses, Entrench (up to +20% after standing still 20 s) and attack-speed items speed the press, and the level range bonus widens where drops land. (7) Interest is computed after the wave bonus, goes through the earn multiplier and is scaled by the stacking share, rounded. (8) Academy needs turret progression; without it forms cannot be taken at all, and `award_xp` does nothing. (9) Press scrap left on the floor counts toward the abandoned share like any drop, so a parked press can raise the earn multiplier as well as feed XP; this matches the card's "choice engine" note but was not playtested.

**Tuning (no bench was run):** the bench was skipped because the GPU was at 100% utilisation from other work, so there are no benched numbers. The finals are tuned from a simulated-time income check in `tests/integration/test_scrap_press_turret.gd` (`_income`, one press for a whole wave, level-10 finals against a level-5 Coin Feeder, Entrench included): over waves 1, 3, 5, 8 and 12 Treasury makes 1.89, 1.83, 1.73, 1.50 and 1.46 times Coin Feeder's money with interest counted at its 50-scrap ceiling (about 1.4 times at 30 held), and Academy with the press plus two neighbours gives 1.67, 1.50, 1.60, 1.58 and 1.58 times in XP. These are estimates of income, not measured play. `tools/bench_turret_forms.gd` has the four rows and an `income` scenario (`--base=scrap_press [--wave=N] --seconds=60`) that reports wallet plus floor scrap per second, XP per second and interest; it uses simulated time, but it was not run on this branch. Run it once to confirm the test's numbers.

**Visuals:** all four use the real `cp_scrap_press` chassis (model key `scrap_press` in `FORMS` and the registry; a teal arch frame round a coral housing and a brass piston on a slab base, a cream coin tray at the front and a rolled coin funnel on one side, 12.2k triangles, 16 objects, 10 materials, 1.36 x 1.18 x 1.58 m; `Aim` carries housing, piston and porthole, `Muzzle` sits at the front edge of the tray) with real portraits. The model faces -z, away from the game camera, and the press never turns, so `ScrapPressForm.rebuilt` turns the model half a circle: the tray (the drop point) faces the player and the funnel is on the right. Bursts leave from the `Muzzle` (`ScrapPressForm.drop_point`), and pickups are laid in a ring 1.0 m to the reach round the press (`ScrapIncome.lay_pickup` `clearance`), never under its body. `ScrapPressEvolutionVisual` reads the feet, piston top and funnel from the model and adds a brass hopper on legs under the funnel mouth with a spout and a floor coin tray (Coin Feeder), four ingot stacks at the base corners, a gold vault cap with an amber crest on the piston and a floor coin ring (Treasury), a mortarboard on the piston stem with a tassel, books beside the base and a teal halo (Academy). The hardware is static. `render_shop_portraits` now looks at the front of a turned model. Known issues: the funnel and the floor hardware can sit on a pickup (the ring is 1.0 m, the Coin Feeder tray reaches 1.3 m on the funnel side), the vault cap hides the piston discs, and the ingots read olive under the arena light. The shop inspector, evolution preview and build summary show a drop interval and where drops go instead of damage and rate (`TurretRegistry.is_no_attack`, `ShopViewData` `utility` and `interval`). Tools: `capture_game --scrap-press-demo`, `preview_evolution --scrap-press-preview` (`--zoom`, `--focus`), `preview_shop --press[-form=...]`, and the roster showcase (scored by drops made, must make none while carried).

**Not verified:** no human playtest. Screenshots of the preview, the demo, the shop card and the evolution dialog were looked at; the showcase passed in plain, `--alternate` and `--moving` runs. Pickup placement near the arena wall, how loud the per-drop pickup cue gets with several presses, and whether Academy's XP pace feels right are untested by hand.

**Model wiring: done** (branch `turret-scrap-press-model`). Triangle cost is 12.2k per press (not reduced; the contract passes with the 5k target flagged, like the other models). The bench was not run on that branch (GPU at 100% from other work); the `income` scenario and the estimated income table above are still unconfirmed: run `tools/bench_turret_forms.gd --base=scrap_press --seconds=60` once the card is free.

**Reuse:** the three exits in `ScrapIncome` are what any later income or XP turret needs (a Beacon that feeds XP, a Mine Layer that pays per kill); `TurretForm.wave_end_scrap` is a generic wave-end payout hook; `FIRE_NONE` plus `"no_attack": true` is the pattern for Beacon, Lullaby and Discord (they also need an aura or behaviour system, S9 and S4, and must join `FAMILIES["aggro"]` where it applies); `ScrapPressForm._rank_yield` is the pattern for "a second one of me is weaker".

## Quake logic (built 26 Oct 2026, branch `turret-quake`; model wired on `turret-quake-model`)

`quake` is a stocked base turret (damage 16, 0.45/s, range 260, rotation 0, knockback 200, stagger 0.4, price 17, Physical, families Kinetic and AoE, `fire_mode: "pulse"`). `QuakeForm` (`scripts/game/quake_form.gd`) takes over `TurretActor`'s `FIRE_PULSE` branch: a 0.5 s ground telegraph, then a `ShockwaveRing` at 8 m/s that strikes each enemy once as it touches it (nearest first). Aftershock (18, 0.45/s) queues a second ring 0.6 s later at 50% damage. Tectonic (40, 0.5/s, range 400) skips the ring and opens two fissures in an X (45 degrees either side of the line from the turret) at the densest cluster (`Combat3D.select_target` with the cluster radius `TECTONIC_CLUSTER_RADIUS`, 1.5 m); each is an S7 line zone centred on that enemy (half length 65% of reach, half width 0.45 m, both growing with range and area bonuses; 3 s; 40% slow) that hits what stands in it once as it opens. Cataclysm (30, 0.5/s) repeats up to three more rings every 0.9 s while enemies stay in range, each 20% wider, capped at 1.6x the reach, and its hits `extend_stagger` (1 s each, cap 1.5 s); the cooldown starts when the salvo ends. Bench (level 10, 120 s, DPS single / cluster / lane): Aftershock 29 / 239 / 90; Tectonic 47 / 334 / 146 (1.40x on a cluster, 1.6x single: the fissure always lands on a lone target); Cataclysm 42 / 354 / 130 (1.48x cluster, 1.45x single). Level 5: Quake 14 / 113 / 28, Aftershock 23 / 195 / 49. Level 10 base Quake: 18 / 146 / 53.

New engine pieces: **S7 `GroundZones`** (enemy-only circles and oriented lines with a slow, pooled visuals, cap 16, cleared when combat stops; `EnemyActor._steer` reads `speed_factor_at`) and the **stagger status** (`StatusEffects3D.stagger/extend_stagger`, `CombatHit3D.stagger_duration/stagger_cap`, stat `stagger`). API and rules are in `doc/combat.md`. All four stages use the real `cp_quake` chassis (model key `quake` in `FORMS` and the registry; cube, hammer and legs on a stone slab, 17k triangles) and have real portraits; `QuakeEvolutionVisual` reads the slab from the model and adds pistons and a ring (Aftershock), cracks and spikes (Tectonic), ripple rings and pylons (Cataclysm). The hammer is not a separable part, so there is no slam animation.

## Shock / Lance logic (built 17 Oct 2026)

Under the new shape only Thunder Spear (L10 final) survives from Lance. Focused Lance and Thunder Pin are retired. The numbers below are the old stage numbers.

`thunder_spear` is an implemented form. It keeps Shock's `FIRE_PULSE` mode but `TurretActor._fire_lance` replaces the pulse with a bolt at the nearest enemy (same `chain_arc` visual as Tesla). Real models and portraits are done for the surviving forms.

| Form | Level | Damage | Rate | Range | Slow | Behaviour |
|---|---|---|---|---|---|---|
| Focused Lance | 5 | 24 | .75 | 300 | 30% / .8 s | single bolt |
| Thunder Pin | 10 | 36 | .80 | 340 | 90% / 1.6 s | near-stop pin |
| Thunder Spear | 15 | 48 | .85 | 400 | 90% / 2.0 s | also hits every enemy in a 1.2 m lane behind the target (`LANCE_LANE_HALF_WIDTH`) |

The 19 Oct headless bench numbers were taken at the old stage levels; re-bench Thunder Spear at level 10 against Resonator.

## Shock / Resonator logic (built 17 Oct 2026)

Under the new shape Resonator is the L5 upgrade and Resonance Engine an L10 final. Echo Chamber is retired.

`resonator` and `resonance_engine` are implemented forms. `TurretActor._fire_resonator` pulses as before, then queues echoes that `_tick_resonator` fires later at 50% damage (Resonator: one at 0.5 s; Echo Chamber and Engine: 0.4 s and 0.8 s). Echo Chamber and Engine reach 15% farther (range 276). Resonance Engine alternates an inner pulse (half radius, double damage) with an outer pulse (130% radius); an enemy struck by both within 1.2 s is Exposed for 2 s. Echoes copy the ring of the pulse that spawned them but never count towards Exposed.

**Exposed (S3) is built:** `StatusEffects3D.expose()`, `exposed_remaining` and `exposure_multiplier()`; `CombatActor.receive_hit` applies +30% to hits whose `attack_families` include `instant`. Lullaby Coma can reuse it. Overwatch's mark is a separate status (`marked_remaining`, +25% from every turret, multiplicative with Exposed). There is no visual cue on Exposed enemies yet.

## Decisions already made by the user

- Decoy has **infinite health**, so no turret health system. It taunts, does light kinetic damage with knockback through a pulse (3 dmg every 1.5 s, radius 150), and its upgrades raise damage (Bumper branch) or extend hooks and pull (Siren branch).
- Sleep and infighting are **separate turrets** (Lullaby, Discord), not Decoy upgrades.
- No-attack turrets (Scrap Press, Beacon, Lullaby, Discord) are **excluded** from the Focused Arsenal check and from the Army Doctrine and Crosslink Array counts. Add an `"aggro"` entry to `TurretRegistry.FAMILIES`.
- Cryo and Vortex are omitted.
- Upgrade shape: level 5 one upgrade, level 10 two finals, infinite levels after, XP curve unchanged, level-5 forms must visibly change, Tesla reworked to match (26 Oct).

Still open (recommendations are in the artifact): the shop slot count with 19 bases (the shop now rolls up to `SHOP_TURRET_MAX` = 4 weapon slots at 37.5% each, about 1.5 weapons per visit; recheck for a 19-turret pool), whether to hold Drone Bay and Beacon until the first batch is playtested, whether Decoy ever gets health, and the Boomerang and Lullaby finalist picks.

## Codebase facts worth knowing (re-checked 29 Oct 2026)

- Registry: `scripts/registries/turret_registry.gd`. Sniper and Quake are stocked via `ShopCatalog`. `fire` is redundant with Flamethrower (retire it). `mine` is registry-only; DEPLOYABLE now maps to the `aoe` item family. An unknown turret id silently becomes Ion in `get_type`.
- `GameEnums.DamageType` is Physical, Fire, Electric, Plasma. "Kinetic" is only an attack family.
- Targeting: set `"targeting"` (closest, cluster, farthest, toughest, backline) at the top level of the registry entry; selection lives in `TurretTargeting`. No-attack turrets set `"no_attack": true` with empty `attack_styles`; Focused Arsenal, Army Doctrine, Crosslink Array and Lone Sentry ignore them. `FAMILIES["aggro"]` now holds the Decoy: Lullaby and Discord must add their ids when registered.
- Turrets cannot be damaged, and enemies are hard-separated from turrets. Enemy goal selection is `CombatActor.chase_position()`.
- Statuses (`StatusEffects3D`): slow (90% cap), burn, Exposed, Marked, stagger. Enemy-only zones are `world.ground_zones` (S7); terrain mud still slows the hero too. Known bug: two Overwatch turrets share one mark timer, so one can clear the other's mark (`overwatch_form.gd`, `StatusEffects3D.unmark`). The planned generic timed-status system with a source owner fixes it, and should land before Decoy, Lullaby and Discord.
- Instant-hit attacks use `FIRE_INSTANT` with `stats.pierce` and the `before_instant` form hook; pulses use `FIRE_PULSE` (Quake's `QuakeForm` and Shock). Idle pulse turrets currently scan every enemy each tick (the docs say 5 Hz), a perf item from the review.
- Evolution architecture: the form table plus `TurretEvolution`, `TurretActor` dispatch, and `*_evolution_visual.gd` for articulated runtime hardware that reuses frozen chassis models. Copy the Sniper and Quake passes (commits `0df37d9`, `b6385b8`, `87d97dc`, `8a31197`).
- Bench and tools: `tools/bench_turret_forms.gd` takes `--level=N`, `--base=ID` and `--seconds=120` for slow turrets (cells are 16 x 18 m so long-range turrets do not hit neighbouring cells). The bowling ball prints an "axis must be normalized" error at `projectile_3d.gd:209` that predates this work.
- Shop screens, portraits, controller flow and tests exist for the current roster; see `doc/plans/turret-expansion-audit.md`. `doc/gameplay.md` and `doc/items.md` still contain stale text (duplicated paragraphs, the old three-stage forms, "54 items" against 56).

## Shared engine work (S1-S12; sizes are in the artifact)

- S1 Taunt targeting and pull (Decoy) **BUILT** (Lullaby and Discord can reuse `TauntField`, the hooked status, `EnemyActor.hook()` and `clear_all_timed`)
- S2 Targeting modes: toughest and backline-first (Sniper) **BUILT**
- S3 Exposed status, a damage-taken multiplier (Resonance Engine, Lullaby) **BUILT**; Overwatch's Marked is a separate built status
- S4 Enemy behaviour overrides: sleep and enemy-vs-enemy (Lullaby, Discord)
- S5 Scrap generation, direct deposit and direct XP (Scrap Press) **BUILT** (`ScrapIncome`; other income turrets reuse it)
- S6 Returning projectile path (Boomerang)
- S7 Enemy-only ground zones (Quake Tectonic) **BUILT**
- S8 Deployable runtime (Mine Layer); the DEPLOYABLE-to-AoE item mapping is built, the runtime is not
- S9 Auras and healing (Beacon)
- S10 Drone actors (Drone Bay)
- S11 Continuous beam (Laser)
- S12 Delayed ground-target shell (Mortar)

## Suggested order

0. **Done:** progression change, targeting modes, Exposed status, DEPLOYABLE family mapping, utility-turret item rules, `aggro` family, form-table refactor.
1. Generic timed-status system with a source owner (fixes the Overwatch shared-mark bug) before Decoy, Lullaby and Discord. Finish Plasma and Tesla whenever convenient (4 forms: Constellation needs S12; Forked Coil, Storm Network, Thunderhead). Re-bench every existing final at level 10 against its level-5 form.
2. **Sniper, Quake, Decoy and the Scrap Press are done, with real models (Decoy model on `turret-decoy-model`, Scrap Press model on `turret-scrap-press-model`).** Boomerang is **on hold** (2026-10-30; the 2D concepts keep coming out as curved blades, retry batch `a5ee55bb-4af0-480c-845a-fecd6ba380c8` unreviewed). Next: Mine Layer, then the remaining model wiring.
3. Mine Layer and Laser; Beacon and Drone Bay after a playtest.
4. Lullaby and Discord (S4 is the largest piece).
5. Wire the remaining base models as each turret lands.

The per-turret definition of done matches the existing roster: attack, a level-5 upgrade and level-10 finals, a visible silhouette change per form, Shop portrait, controller flow, showcase run and tests. Use `.claude/skills/godot-test` for tests and `.claude/skills/2d-to-3d-asset` for models.

## 2D concept art (image-gen-web, local API on port 3000)

Style used throughout: **Clockwork Pop** (style id `3b7b7bc4-4403-4b69-8a10-809235eb4924`), category Turret (`d6f603f7-5efe-4005-9ac1-3d11bda5276c`), provider `comfyui`, 1024x1024, magenta `#FF00FF` background. Prompts are composed as plain text. The generation code in `image-gen-web/lib` has no reference-image support, so each capstone prompt describes its base turret in words and may not match the favorited base exactly.

| Batch | Id | Contents |
|---|---|---|
| New Turret Roster - 3 Each | `ce5635c2-d52d-4699-8976-f8583d51fb72` | 11 base concepts, 3 each |
| Boomerang and Lullaby Retry - 3 Each | `e74ea1bc-beb2-4721-9913-748255d6a6a5` | 4 concepts replacing the rejected Wing Slinger and Cradle Chime |
| Level 15 Mastery Forms - 2 Each | `5ef1997e-50d6-4d4d-99b9-77a9cdbe2712` | 27 capstones, 2 each |

Favorited base concepts (image ids; use these as inputs to `2d-to-3d-asset`; models for all but Boomerang and Lullaby are already built, see 3D models):

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
- Everything in `turret-game` for this work is on master (see "Where the work lives").
