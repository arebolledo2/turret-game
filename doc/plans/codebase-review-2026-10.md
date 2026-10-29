# Codebase review, October 2026 (before the next nine turrets)

Reviewed on branch `turret-quake-model` (tip `8a31197`; `master..HEAD` is 189 files, +6,786 / -674). Read-only review: no code,
test, asset or doc was changed except this file. Code was treated as the source of truth where docs disagree. Numbers come from
scripts run over the tree (`git ls-files`, line and function counters) and the newest `.test-results` run.

## Verdict

The game is in better shape than "several agents copying each other" suggests: static typing is universal in `scripts/` (zero
untyped `var x =`), GameConstants has one unused constant, functions are mostly short, the test suite is large (1,171 tests,
52k asserts, 39 s) and green, and the recent `TurretForm` / `TurretTargeting` / `GroundZones` pieces are well documented. The
expensive part is not any single god class: it is that **one turret's facts are spread over about 25 code locations in 15+
files plus 6 tools and 6 docs**, and that the half-finished level-5/level-10 conversion (`legacy_stage`) keeps every per-form
table indexed by an old three-stage scheme whose middle column is dead. The Sniper took 71 files over two commits and the Quake
92. Before adding nine more turrets, spend roughly one to two focused days making a form a single data row plus one behaviour
class and one visual class, deriving the counts and tool rows from that data, and normalising line endings; otherwise each new
turret multiplies the drift (stale descriptions, hard-coded `"stormblade"`/`"melee"` checks, vacuous portrait tests) and each
agent's edit of a CRLF file produces whole-file diffs.

## Size and shape (measured)

| Area | Files | Lines | Notes |
|---|---:|---:|---|
| `scripts/` | 153 `.gd` | 19,243 | 1,235 functions; 59 >= 40 lines, 20 >= 60, 6 >= 80 |
| `tests/` | 93 `.gd` | 16,237 | 0.84 test lines per code line; 1,171 tests / 91 scripts / 52,096 asserts / 39.3 s (newest run) |
| `tools/` | 29 `.gd` | 2,386 | plus 7 Python/PowerShell scripts |

Only one file is over 600 lines: `scripts/game/combat_effects_3d.gd` (626). Next: `shop_screen.gd` 568, `turret_actor.gd` 564
(39 functions), `arena_world.gd` 557 (40 functions), `preparation_phase.gd` 533. Functions over 80 lines in `scripts/`:
`TurretEvolution.base_stats` 113 (`turret_evolution.gd:79`), `TurretInspector._show_selected` 111 (`turret_inspector.gd:190`),
`SalvagePresentation.begin` 105, `GameApp._build_menu` 95, `TurretInspector._ready` 92, `CrowdGrid3D.resolve_overlaps` 80.
In tools: `preview_evolution.gd:_ready` 131, `capture_ecology.gd:setup` 116, `preview_shop.gd:_ready` 83.

Per-turret footprint (`git show --name-only`):

| Commit | Files | scripts | tests | tools | doc | assets/art |
|---|---:|---:|---:|---:|---:|---:|
| `0df37d9` Sniper | 42 | 17 | 9 | 2 | 6 | 8 |
| `b6385b8` Sniper model | 29 | 4 | 3 | 4 | 6 | 12 |
| `87d97dc` Quake | 60 | 30 | 11 | 3 | 6 | 10 |
| `8a31197` Quake model | 32 | 5 | 3 | 3 | 6 | 15 |

## 1. Per-turret extension cost

### Touch-points for one base turret with three forms (today)

| # | Where | What has to be written | Same fact also stated in |
|---|---|---|---|
| 1 | `turret_registry.gd:39` `TYPES` | entry: names, fire mode, styles, damage type, base stats, `model_key`, fallback `model` | price in `BASE_PRICES` (`:17`), family in `FAMILIES` (`:31`), targeting in either top level or `base_stats` (`:329`) |
| 2 | `shop_catalog.gd:9` | catalog row | `ArenaShop.TURRETS` is a static copy taken at class load (`arena_shop.gd:5`) |
| 3 | `turret_evolution.gd:6` `PATHS` | upgrade + two finals | bench `FORMS`, showcase `ROSTER`, docs |
| 4 | `turret_evolution.gd:20` `FORMS` | 3 rows: name, model, tier | |
| 5 | `turret_evolution.gd:192` `IMPLEMENTED` | 3 ids on one 600-char line | `test_turret_evolution.gd:112` asserts `== 26` |
| 6 | `turret_evolution.gd:84-188` `base_stats` | 1-3 `match` arms (stats indexed `[stage - 1]`) | doc paragraphs restate the numbers |
| 7 | `turret_evolution.gd:290-311` `description` | 3 arms with numbers typed into prose | constants in the same file (e.g. `:308` restates `OVERWATCH_MARK_*`, `MARKED_BONUS`) |
| 8 | `turret_evolution.gd` constants + optional `*_pattern_text` | mechanic constants | some in `GameConstants`, `StatusEffects3D`, `CombatEffects3D.QUAKE_TINT` |
| 9 | `turret_evolution.gd:261` `shape_shot` | branches by base/form id | |
| 10 | `turret_form.gd:13-24` `create` | `match` arm (plus the `""` special case for an unevolved base, `:23`) | |
| 11 | `scripts/game/<x>_form.gd` (+ `.uid`) | behaviour class | |
| 12 | `scripts/game/<x>_evolution_visual.gd` (+ `.uid`) | builder with its own material palette and mesh helpers | |
| 13 | `turret_actor.gd:115-123` | one more builder call (9 today, each self-filtering by form id; signatures differ: Quake takes `turret_type`, Sniper ignores `_stage`) | |
| 14 | `turret_actor.gd` fire-mode dispatch | new `FIRE_*` branch when the attack shape is new (Sniper added `FIRE_INSTANT`) | `effective_range` area rule repeated in 4 other places (see 3.) |
| 15 | `shop_view_data.gd:118,131-151` | per-form DPS / burst arms | burst intervals `.09`/`.065` repeated from `turret_actor.gd:18` / `gunblade_form.gd:7` |
| 16 | `turret_inspector.gd:212-258` | `turret_type == "sniper"/"quake"/"melee"/"flamethrower"` lines, `"stormblade"`, `"overwatch"` | |
| 17 | `evolution_preview.gd:69-84` | same per-type lines again | |
| 18 | `ui_icon_data.gd:56-57` | SVG icon `turret_<id>` | |
| 19 | `assets/ui/turrets/<id>.png` x4 (+ `.import`) | portraits (render tool is data-driven) | |
| 20 | `clockwork_models.gd:5` `KEYS` | model key | `assets/models/clockwork/manifest.json`, `test_clockwork_roster.gd:24` articulation list, `promote_clockwork_asset.py:16` `choices=[...]` |
| 21 | `tests/` | per-turret integration file; edits to `test_turret_evolution.gd` (`:76` `== 10`, `:100` `== 30`, `:112` `== 26`), `test_shop_catalog.gd:17` (`== 10`), `test_shop_focus.gd` | |
| 22 | `tools/bench_turret_forms.gd:17` | 4-7 rows | `PATHS` |
| 23 | `tools/showcase_turret_roster.gd:6` | 2 rows | `PATHS` |
| 24 | `tools/preview_evolution.gd:33-80` | a copy-pasted `--<x>-preview` block (Sniper and Quake blocks differ only in data) | |
| 25 | `tools/preview_shop.gd:40-75` | a copy-pasted `--<x>` / `--<x>-form=` block with the price hard-coded (`18`, `17`) | `BASE_PRICES` |
| 26 | `tools/capture_game.gd:19-247` | `--<x>-demo` flag, stage function, suffix | |
| 27 | docs | `index.md` ("ten base turrets", "26 playable forms"), `gameplay.md`, `combat.md`, `items.md` family table, two plan files, `doc/art/clockwork-pop/progress.json` | |

A new status effect (Quake's stagger, Sniper's mark) adds another 7-8 points: field + API + `clear` in `StatusEffects3D`, field on
`CombatHit3D` and `CombatShot3D` (and `copy()` and `from_stats`), the copy in `Combat3D.hit_from_shot`, a marker variable plus
two hide sites in `CombatActor` (`clear_transients`, `receive_hit`), a `_tick_<status>` in `EnemyActor`, a `TurretStats` getter
and inspector text (see `git show 87d97dc -- scripts/game/combat_actor.gd scripts/game/combat_3d.gd`).

### What can be data-driven, and the smallest high-leverage change

One definition per form (a dictionary row or a small `Resource`) can carry everything in rows 4-10 and 13:

```gdscript
# turret_evolution.gd (or scripts/turrets/<line>/<line>_line.gd, one file per line)
"overwatch": {
	"name": "Overwatch", "model": "sniper", "tier": TIER_FINAL,
	"stats": {"damage": 56.0, "fire_rate": .42, "range": 780.0, "pierce": SNIPER_PIERCER_PIERCE},
	"behaviour": OverwatchForm,          # replaces the TurretForm.create match
	"visual": SniperEvolutionVisual,     # replaces the 9 self-filtering builder calls
	"implemented": true,                 # replaces IMPLEMENTED
	"describe": "_describe_overwatch",   # or a Callable that formats from the constants
},
```

Smallest set that removes the most touch-points (in order): (a) flatten `legacy_stage` so each form's numbers are plain values;
(b) move `base_stats` arms into a `stats` overlay per form, `create` into a `behaviour` field, the builder calls into a `visual`
field, and derive `IMPLEMENTED`; (c) give `TurretForm` the presentation hooks (`stat_lines`, `estimated_dps`, `secondary_stats`)
and give every turret a form object (a default base form) so the UI never switches on ids; (d) derive test counts, bench rows,
showcase rows and tool flags from `PATHS`. That takes rows 4-7, 9, 10, 13, 15-17, 21-26 from "edit" to "nothing" or "append a
row", leaving registry entry, form file(s), visual file, assets and docs.

### `legacy_stage` and the dead stage-2 data

`legacy_stage(form_id)` (`turret_evolution.gd:75`) returns 1 for an upgrade, 3 for a final. No form is tier 2, so every
`[a, b, c][stage - 1]` middle element is dead, and for forms that only exist as finals the first element is dead too. Exactly:

| Location | Dead values |
|---|---|
| `base_stats` `machine_gun`/`cyclone_gatling` `:86-87` | damage 5.5, fire_rate 4.0 |
| `omnifire` `:91-92` (final only) | damage 8.0, 9.0; fire_rate 1.0, 1.15 |
| `siege`/`worldbreaker` `:95-100` | 58.0, .5, 160.0, 280.0 |
| `heavy_roller`/`juggernaut` `:102-105` | 43.0, 10, 420.0, .65 |
| `ricochet_king` `:107-108` (final only) | 22.0, 28.0; .7, .8 |
| `wide_flame`/`inferno_crown` `:112-114` | 4.0, 85.0, 2.5 |
| `dragonheart` `:116-120` (final only) | 3.2, 4.0; 280, 330; 24, 20; 2.2, 2.6; 2.5, 3.0 |
| `repeater_bow`/`arrowstorm` `:122-125` | 13.0, 1.0, pierce 2 |
| `titan_bow` `:127-132` (final only) | first two of all six arrays |
| `stormblade` `:134-136` (final only) | first two of all three arrays |
| `resonator`/`resonance_engine` `:138-139` | 5.0, 276.0 |
| `thunder_spear` `:141-145` (final only) | first two of all five arrays |
| `saber`/`orbit_saber` `:147-149` | 12.0, 450.0, 155.0 |
| `RESONATOR_ECHO_DELAYS` `:195` | `[.4, .8]` (middle entry) |
| `volley_size` `:258` | 3 |
| `shape_shot` `:276,279` | ricochets 2, 4; siege radius .28 (and `titan_bow` scale is always 1.9) |
| `gunblade_barrel_stats` `:284-287` (Stormblade only, always stage 3) | damage 7, 8; fire_rate 2.0, 2.2; the `pierce` condition |
| `description` `:293-303` | Machine Gun middle text, Ricochet 2/4, Wide Flame 85, Repeater 3, Titan 4/6, the "Two opposing held blades" Twin Saber text, the "Two echoes" Resonator text |
| `bow_evolution_visual.gd:15`, `flame_evolution_visual.gd:34` | middle entries 3 and 34.0 |
| `crossfire_evolution_visual.gd:10-11` | the whole `stage < 3` (4-exit) branch |
| `gunblade_evolution_visual.gd:26` | the `stage == 2` layout |
| `machine_gun_form.gd:16` | `ceiling 1.0` branch |
| `scatter_form.gd:9-11` | the retired Scattershot three-way spread |
| `lance_form.gd:13,21` | the non-piercing `stage < 3` path |
| `assets/ui/turrets/` | 23 stage-2-era portraits no form references (~1.6 MB): `bank_shot_1/2, capacitor_1/2, focused_jet_1/2, greatbow_1/2, gunblade_1/2, heavy_roller_2, lance_1/2, machine_gun_2, relay_1/2, repeater_bow_2, resonator_2, saber_2, scatter_1/2, siege_2, wide_flame_2` |
| `ClockworkModels.KEYS` | `scatter`, `focused_lance`, `thunder_pin` are used by no form or enemy (~4.4 MB with textures), yet asserted by `test_clockwork_roster.gd` and baked by `DeathShatter.warm_up` |

`legacy_stage` is read in 12 places outside `turret_evolution.gd` (forms, visuals, `shop_view_data.gd:118,130`,
`turret_inspector.gd:258`, `evolution_preview.gd:84`, `bench_turret_forms.gd:62`), and there is a second, unrelated "stage"
(`TurretProgression.evolution_stage`, 0-2), which `render_shop_portraits.gd` sets as 1 and 2: the two meanings collide in
names. The spec (`turret-progression-l5-l10-spec.md:62,133`) flags this cleanup as "easy to skip"; it has been skipped.

## 2. God classes and structure

None of the named files is a true god class by size; the issue is mixed responsibilities and reach-through.

| File | Lines / funcs | Responsibilities mixed today | Proposed split (names, boundary) | Value | Risk |
|---|---|---|---|---|---|
| `turret_actor.gd` | 564 / 39 | model build + 9 visual builders, procedural melee model, 5 fire modes, bow burst, saber arms, stats resolution, entrench forwarding (`:67-87`, `:236-261` are 14 one-line wrappers), evolution | `TurretAttack` strategies per fire mode (`SweepAttack`, `FlameAttack`, `InstantAttack`, `PulseAttack`, `ProjectileAttack`) owned by the actor; `TurretStatsResolver` (`resolve_attack_stats`, item conditions, `effective_range`); `TurretVisuals.build(model, type, form) -> TurretVisualHandles` (muzzles, emitters, hardware); move Bow burst and saber arms into `RepeaterBowForm`/a `SaberForm`; make `new_shot`, `reset_cooldown`, `current_view` public (forms call the private ones 18 times, tests 71 times for `_current_view`) | High | Medium |
| `combat_effects_3d.gd` | 626 / 32 | six hand-rolled pools with parallel arrays (sparks, tracers, arcs, arc lights, pulses, flame ribbons), burn and shock overlays, damage numbers; vars declared mid-file (`:482`, `:591`) | `EffectPool` (acquire/age/release over one node array); `ArcEffects`, `PulseEffects`, `FlameEffects`, `ActorOverlays` (burn + shock) | Medium | Low |
| `turret_evolution.gd` | 312 / 11 | form table, all form stats, all mechanic constants, descriptions, shot shapes, Stormblade barrel | data rows per form (section 1); constants per line (`SniperLine`, `QuakeLine`) or next to their form class | High | Low (pure data, testable) |
| `turret_inspector.gd` | 354 | roster paging + per-type stat text (`_show_selected` 111 lines) | `TurretStatText.lines(turret)` built from `TurretForm.stat_lines`; inspector only lays out | Medium | Low |
| `shop_view_data.gd` | 215 | offer chips, build numbers, per-form DPS (`:126-152`), preview by mutating global services (`:157-178`), per-item "affected" rules (`:191-206`) | `TurretForm.estimated_dps`; item "affected" rule as a field on the item row | Medium | Low |
| `arena_world.gd` | 557 / 40 | composition root and service locator (~35 public fields reached as `world.*`) | fine for now; do not grow it with turret code (forms should receive a narrow context) | Low | - |
| `enemy_actor.gd` / `combat_actor.gd` | 248 / 221 | one `_tick_<status>` + marker per status | generic status ticking and markers (refactor R5) | High for Lullaby/Discord/Decoy | Medium |
| `status_effects_3d.gd` | 149 | slow, burn, exposed, marked, stagger, each with bespoke fields/APIs | timed-status table (R5) | High | Medium |
| `game_constants.gd` | 248, 133 consts | clean; one unused (`TURRET_SPLASH_AOE_RADIUS`) | leave; but turret balance lives in 5 other places (registry, evolution, StatusEffects3D, CombatEffects3D, visuals) | Low | - |
| `turret_registry.gd` | 360 | types, prices, families split across three dicts; unknown ids silently become Ion (`get_type`, `:256-259`); 7 blank lines `:304-310`; `get_attack_families` allocates 6 arrays per call (`:334-342`) | fold price/family into `TYPES`, cache families, error on unknown id | Medium | Low |

## 3. Duplication left by copy-paste (file:line)

| Pattern | Examples | Fix |
|---|---|---|
| Material palette + mesh helpers per visual | `static var materials` and the same `albedo/metallic/roughness/emission` loop in 7 files (brass `dba94c` in all: `bowling_:14`, `flame_:14`, `gatling_:14`, `gunblade_:18`, `quake_:80`, `siege_:21`, `sniper_:90`); `_part`/`_cylinder`/`_ring`/`_torus`/`_box` re-declared in 6 files with different signatures (e.g. `sniper_evolution_visual.gd:100-129` vs `quake_evolution_visual.gd:89-133`) | `MeshKit` (`WorldGeometry` already has `material`, `box`, `ring`, `sphere`): `MeshKit.palette(name)`, `cylinder(parent, label, r, h, mat, at, axis)`, `torus(...)` |
| Pooled effect with parallel arrays | `combat_effects_3d.gd:190-213` sparks, `:216-252` tracers, `:256-` arcs, `:421-450` pulses, `:595-625` flames | `EffectPool` |
| Delayed-action queues | `ShotBurst` (`shot_burst.gd`), `ResonatorForm.echoes` (`resonator_form.gd:8,58-67`), `QuakeForm.beats`/`fissures` (`quake_form.gd:17-21,163-176`) | one `BeatQueue` (time, payload, callback) cleared in `TurretForm.clear()` |
| Lane hit test | `lance_form.gd:14-20` hand-rolls what `TurretTargeting.on_lane` (`turret_targeting.gd:88`) does; two half-width constants (`LANCE_LANE_HALF_WIDTH`, `SNIPER_LANE_HALF_WIDTH`) | use `on_lane` |
| Crit roll | `turret_actor.gd:205-207` (bat), `:405-407` (`_new_shot`), `gunblade_form.gd:31-33`; flame hits never crit (`turret_actor.gd:516`) | one `roll_crit(shot_or_hit)` |
| Hit construction bypassing `hit_from_shot` | bat (`turret_actor.gd:210-217`), flame (`:516-521`, families hard-coded `["aoe"]`), gunblade (`gunblade_form.gd:29-30`, `["projectile"]`) | build from a shot so new fields (stagger, future statuses) flow everywhere |
| "Reach with area multiplier" | `turret_actor.gd:322`, `shop_view_data.gd:75-76` (pulse only), `:115-116` (pulse and flame), `turret_inspector.gd:220,232`, `evolution_preview.gd:72-73` | call `effective_range`; `shop_view_data.gd:75` is inconsistent today: Flamethrower reach in the build summary ignores `area_size` |
| Shop/turret special cases on one form id | `"stormblade"` 13 times in 6 files (`shop_view_data.gd:95,148,213`, `turret_inspector.gd:212,255`, `evolution_preview.gd:82`, `turret_actor.gd:87-90` via `form is GunbladeForm`) | `TurretForm.secondary_stats()` |
| Per-turret tool blocks | `preview_evolution.gd:33-58` vs `:59-80`; `preview_shop.gd:40-57` vs `:58-75`; `capture_game.gd:99-157` | `--base=<id> [--form=<id>]` driven by `PATHS` |
| Roster lists | `bench_turret_forms.gd:17-29`, `showcase_turret_roster.gd:6-21` restate `PATHS` (showcase even lists `worldbreaker` twice for Plasma) | derive (as `render_shop_portraits.gd:5-13` already does) |
| Test world setup | `before_each` with `ArenaWorld.new()` + the same 8 lines in 37 places; `_enemy` in 10 files, `_step`/`_combat` in 4; `test_quake_turret.gd:11-56` is a near copy of `test_sniper_turret.gd:10-55` | `TurretTestRig` in `tests/helpers/` |
| Model key lists | `ClockworkModels.KEYS`, `manifest.json`, `test_clockwork_roster.gd:24`, `promote_clockwork_asset.py:16` | read `manifest.json` (or generate KEYS from it) |

## 4. Dependencies and coupling

- **Autoloads:** 13 (`project.godot`). Turret code reaches `ModifierService`, `TurretStatsService`, `FeatureFlagService`,
  `Events` directly; acceptable, but `ShopViewData.preview` (`shop_view_data.gd:157-178`) temporarily mutates
  `TurretStatsService.turret_counts`, `ItemTrackingService.item_counts` and `ModifierService` state; safe only while it stays
  synchronous and signal-free.
- **Variant/Node references:** clean in game code (no `var x: Node` service refs; the repo note about `:=` does not bite here).
  The remaining `Variant`s are `ConfigFile` reads and a few loops (`overwatch_form.gd:43`, `enemy_brain.gd:383`).
- **Private API used across classes:** forms call `actor._new_shot` (13 total uses), `_reset_cooldown` (7), `_current_view` (71
  incl. tests), `_tick_bow_burst`; UI calls `turret._current_view(0.0)` (`turret_inspector.gd:205`). Promote to public.
- **Hard-coded scene paths:** few (`arena_world.gd:519`, `game_app.gd:233`, `game_hud.gd:77`); fine.
- **Stringly typed ids worth constants:** attack families (`"instant"` 17x/8 files, `"kinetic"` 17x/10, `"projectile"` 16x/10,
  `"aoe"` 13x/7); targeting (`TurretTargeting` has consts, but `"closest"`/`"cluster"` stay literal in the registry and
  `Combat3D`); capabilities (`has_capability` `match`, `turret_registry.gd:347-352`); audio cues (`play_cue("ion")` for the
  Sniper `turret_actor.gd:448`, `"plasma"` for Quake `quake_form.gd:98,145`); burst kinds (`"scrap"`); `shot.visual_key ==
  "bowling_ball"` steering physics in `projectile_3d.gd:74,199,207,208`; and the Ion's id `"normal"` (25x/15 files, with
  `_model_key` mapping it to `"ion"`, `turret_actor.gd:473`). Suggest a `TurretIds`/`AttackFamily` const class or
  `StringName` consts; enums are awkward because ids are persisted in dictionaries and docs.
- **Magic numbers outside GameConstants** (turret path): target cache `.2` (`turret_actor.gd:378`), carry offset
  `Vector3(0, 1.15, .25)` (`:334`), recoil `.06`/`.045`/`.16` (`:393,397,462`), burst intervals `.09`/`.065` (duplicated in
  `shop_view_data.gd:136,151`), effect caps `32` and `48` (`combat_effects_3d.gd:491,606`), XP literals in tests and tools
  (`award(110)`, `award(389)`, `award(1500)`, `award(896)` across 57 calls) that encode the XP curve.

## 5. Performance and runtime hazards (code-read, not re-measured)

| Hazard | Evidence | Note |
|---|---|---|
| Pulse turrets scan every tick while idle | `turret_actor.gd:358-363`: when the cooldown is ready and nothing is in range, `world.nearest_enemy` (a linear `select_target` over all enemies, `combat_3d.gd:111-132`) runs every physics tick for each Shock/Quake/Thunder Spear | Docs say "target acquisition runs at 5 Hz"; this path is 60 Hz. Throttle with `target_clock` or use `crowd.query_radius` |
| Per-tick full-enemy scans in effects | `_update_burns` and `_update_shocks` (`combat_effects_3d.gd:483-534`) loop all enemies every tick even with no burns/shocks | early-out on empty |
| Unpooled burn overlays | `combat_effects_3d.gd:486,492-502` `queue_free` + new `QuadMesh`/`ShaderMaterial` per burning enemy | pool like shock overlays (`:536-557`) |
| Shader writes to hidden effects | `combat_effects_3d.gd:459-462` sets `visual_time` on all 48 flame ribbons every tick | only visible ones |
| Allocation per shot / per stats refresh | `get_attack_families` builds 6 arrays per call (`turret_registry.gd:334-342`), called per shot (`turret_actor.gd:404`), per bat hit (`:213`), and for every neighbour in `_has_instant_neighbour` (`:274-279`, O(turrets^2) every 0.25 s); `has_capability` deep-duplicates base stats (`:346`) | cache per type |
| Hero weapon stats every tick | `hero_actor.gd:70` deep-duplicates weapon stats and re-applies item effects each tick | cache with the snapshot |
| Gunblade double resolution | `resolve_attack_stats(true)` recursively resolves the primary (`turret_actor.gd:316`) | small |
| Projectile pool search | `arena_world.gd:381-384` linear scan for an inactive projectile | fine at current counts |
| Known error | `projectile_3d.gd:209` normalises `direction.cross(UP)`; the bring-up plan reports "axis ... must be normalized" from the bowling ball | guard zero/vertical direction before Boomerang reuses this path |

On the memory file's claims (`turret-game-perf-findings.md`): the "5 ms for 150 hurtbox Area3Ds" claim is **no longer in the
docs** (searched `doc/`); hurtboxes still exist as non-monitoring `Area3D`s (`enemy_actor.gd:35-46`) used by projectile
ShapeCasts. I did not re-measure, so the memory's "<1.5 ms when removed" stands unverified. Its `bench_physics` finding is
still true: `tools/bench_physics.gd` never holds `waves.time_left` (only `bench_mix.gd:67` does), so later modes can measure an
empty field.

## 6. Tests

- **Brittle counts that break on every turret:** `test_turret_evolution.gd:76` (`PATHS.size() == 10`), `:100` (`== 30`),
  `:112` (`IMPLEMENTED.size() == 26`), `test_shop_catalog.gd:17` (`turret == 10`) and `:18` (`item == 56`). The structural
  checks around them (one upgrade, two finals, every form in one path) are good; the literal totals add nothing.
- **Missing contract test:** "every stocked base can be bought and fully evolved" exists only for `["bow", "flamethrower",
  "bowling"]` (`test_expansion_base_turrets.gd:170`) and `["tesla", "melee"]` (`test_new_turrets.gd:170`). A form silently
  becomes "Form in development" if its model key does not resolve or it is not in `IMPLEMENTED`
  (`turret_actor.gd:480-487`), so this should loop over `ShopCatalog.ids("turret")` and `PATHS`.
- **Vacuous assertions:** `assert_not_null(ShopArt.turret(...))` (`test_expansion_base_turrets.gd:188,193`,
  `test_sniper_turret.gd:116`, `test_quake_turret.gd:137`) can never fail, because `ShopArt.turret` falls back to the SVG icon
  (`shop_art.gd:12`, `ui_icons.gd:33`). Assert `ResourceLoader.exists("res://assets/ui/turrets/<key>.png")` instead.
- **Randomness:** turret crits are 5% (`game_constants.gd:61`) on the shared gameplay RNG, reset to seed 12345 per test
  (`test_helpers.gd:144`). Exact-damage asserts such as `test_sniper_turret.gd:184` pass because of that seed, so any new RNG
  consumer earlier in a test can flip a hit to a crit. Two tests disable crits ad hoc with a modifier
  (`test_evolved_turrets.gd:410,444`). Add `TestHelpers.disable_crits()` and use it in damage-exact tests.
- **Real-time waits:** one (`test_floor_themes.gd:45`, 1.2 s timer); otherwise tests step physics manually. Good.
- **Orphans:** final gate is clean, but 21 scripts report transient per-test orphans (27 in `test_evolved_turrets.gd`, 18 each in
  the Sniper and Quake files), from `_rebuild_model` queue-freeing models; harmless today, worth knowing when the gate flickers.
- **Dead helpers:** `TestHelpers.create_mock_enemy/player/turret/*_hurtbox` (`test_helpers.gd:12-128`, Node2D/Area2D mocks
  from the 2D runtime) are referenced by no test.
- **Coverage gaps in risky areas (spot-checked):** two Overwatch turrets sharing a target (see risks); `ShopViewData` DPS for
  Sniper/Overwatch/Tectonic (no arm, falls to `damage * rate`); 509 untyped `var x =` in tests (fine, but the repo's `:=` parse
  trap applies there).

## 7. Tools, docs and repo hygiene

### Line endings (tracked text files, by `git ls-files --eol` and a byte scan)

| Scope | CRLF | LF | Mixed |
|---|---:|---:|---:|
| all tracked text (git index) | 225 | 1,574 | 34 |
| `.gd` | 49 | 286 | 22 |
| `scripts/autoload` | 4 | 19 | 3 |
| `scripts/game` | 4 | 168 | 6 |
| `scripts/systems` | 3 | 15 | 2 |
| `scripts/ui` | 5 | 40 | 3 |
| `scripts/registries` | 3 | 9 | 0 |
| `tests/unit` | 16 | 66 | 4 |
| `tests/integration` | 5 | 89 | 2 |
| `tools` | 10 | 82 | 2 |
| `.json` (mostly art-source) | 94 | 88 | 0 |
| `.svg` (assets/ui) | 45 | 14 | 0 |
| `.md` | 14 | 76 | 5 |

The files every turret touches are among them: `turret_evolution.gd`, `turret_registry.gd`, `turret_inspector.gd`,
`shop_screen.gd`, `shop_art.gd`, `ui_icon_data.gd`, `turret_stats_service.gd` are CRLF; `test_turret_evolution.gd`,
`modifier_system.gd`, `preview_shop.gd` are mixed. `.gitattributes` only covers LFS; there is no `.editorconfig`;
`core.autocrlf=false`. Godot writes LF.

Recommendation: add

```gitattributes
* text=auto eol=lf
*.ps1 text eol=crlf
*.png *.jpg *.ogg *.wav *.ttf *.otf binary
*.blend filter=lfs diff=lfs merge=lfs -text
*.glb filter=lfs diff=lfs merge=lfs -text
```

and an `.editorconfig` (`end_of_line = lf`, `insert_final_newline = true`, `indent_style = tab` for `*.gd`, `charset = utf-8`),
then normalise once with `git add --renormalize .` in a single mechanical commit made right after the turret stack merges to
`master` (so no open branch rebases across it). Yes, normalise: the mixed files already prove agents write LF into CRLF files.

### Docs drift

- `doc/combat.md:35-41` and `:45-51`: the "Pulse rings and stagger" and "Ground zones (S7)" sections are duplicated.
- `doc/gameplay.md:186` and `:188`: the Quake paragraph is duplicated (the two differ only in "3.9 m at level 10").
- `doc/gameplay.md:170-194` describe the retired three-stage system: Twin Saber, Moonshot, Greatbow, Harpoon/Volley Ballista,
  Furnace Fan, Focused Jet, Dragon Nozzle, Demolition Roller, Bank Shot, Pinball Engine, Repeater Blade exist in no code; "levels
  10/15" and "level 15" are stale.
- `doc/gameplay.md:36-40`: "two distinct weapons from ion, plasma, shock, tesla and melee ... 13 implemented items" contradicts
  `:28` (four offers) and the 56-item catalog. `:73` and `combat-polish.md` quote 790 tests (now 1,171).
- `doc/items.md:3`: "54-item catalog" and the rarity counts sum to 54; `ShopCatalog` has 56 (`index.md` says 52+1+3 = 56).
- `doc/architecture.md` claims "a new form is data plus its visual and attack, not edits across the actor", which section 1 shows
  is not yet true.
- `SpriteTODO.md` (repo root) is a 2D-era list pointing at `scenes/turret.tscn`, which no longer exists.
- Turret descriptions restate constants in prose (`turret_evolution.gd:306-311`), so the pending retune (spec step 4) will drift
  them; `quake_pattern_text` (`:243`) shows the right pattern (format from constants).

### Other hygiene

- **Godot imports docs:** 99 tracked `.import` files under `doc/` (preview PNGs); nothing loads `res://doc`. Add `doc/.gdignore`
  (as `art-source/.gdignore` already does) and drop those `.import` files. `.godot/imported` is 280 MB locally.
- **Large binaries outside LFS:** LFS covers only `*.blend` (53) and `*.glb` (64). 126 PNGs over 1 MB are plain Git objects
  (`doc/art` 202 MB, `assets/sprites` 88 MB, Clockwork textures); the object store is ~490 MB (281 MB loose + 208 MB pack).
  Track new large PNGs in LFS; do not rewrite history.
- **Ignored leftovers:** `doc/plans/item-migration.*.translation` (Godot auto-imported a CSV that is gone), `tools/__pycache__/`,
  `assets/sprites/player/player_character.zip`, ten `*.blend1` backups. Ignored, so harmless, but `.translation` files mean a
  stray CSV was once imported.
- **.uid pairing:** 357 tracked `.gd`, 358 `.gd.uid`; the extra is `addons/gut/menu_manager.gd.uid` (orphan, addon-owned).
- **Bench tools:** `bench_mix`, `bench_physics`, `bench_split`, `capture_game --stress` all seed turrets with
  `ArenaShop.TURRETS[index % 3]`, i.e. catalog order; inserting a turret before `shock` in `ShopCatalog` silently changes every
  benchmark.
- **Registry leftovers:** `"fire"` and `"mine"` in `TYPES`/`BASE_PRICES` with no 3D consumer (Mine is planned; Fire is not).

## 8. Other findings

- **Correctness, Overwatch with two turrets (fixed on branch `status-owned-timers`, refactor R5 timed-status part done: owner-keyed `TimedStatus` timers in `StatusEffects3D`, `OverwatchForm` passes its turret id; marker/tick tables still bespoke):** `OverwatchForm.before_instant` calls `statuses.unmark()` on enemies it no longer
  wants (`overwatch_form.gd:28-29`), which zeroes the shared timer (`status_effects_3d.gd:64-65`), so a second Overwatch's mark on
  the same enemy is silently removed and its `tick` then drops the entry (`overwatch_form.gd:47-49`). Statuses need a source
  owner before Lullaby/Discord/Decoy add more shared statuses.
- **Silent fallbacks:** `TurretRegistry.get_type` returns the Ion entry for an unknown id (`turret_registry.gd:259`) while
  `_definition` returns `{}`; a typo in a new turret id yields a working Ion, not an error.
- **No-attack/aura turrets are not modelled yet:** `TurretActor._physics_process` assumes every turret targets and fires
  (`turret_actor.gd:352-397`), `fire_mode` defaults to projectile, `ShopViewData` and the inspector assume damage lines. Scrap
  Press, Beacon, Lullaby, Discord need a `FIRE_NONE`/aura path.
- **Seeded order dependence:** item docs say registry order drives seeded rolls; the same holds for `ShopCatalog` turret order
  (`arena_shop.gd:18`). Append new turrets, never insert.
- **Settings:** preferences have no version key (`settings_service.gd`); runs are not saved, so form ids are not a save-compat
  concern today.
- **Debug output:** `DebugService` is used 7 times, `print` 3, `push_error/warning` 5; fine. No TODO/FIXME/HACK markers.
- **Controller:** the evolution preview handles `JOY_BUTTON_B` (`evolution_preview.gd`); I did not audit controller focus
  across the inspector's dynamic evolve buttons beyond that.

Not checked: `enemy_brain.gd`, `preparation_phase.gd`, `game_hud.gd`, `shop_screen.gd` and `dev_panel.gd` internals; audio;
Blender scripts; actual frame cost (nothing was profiled).

## Ranked refactors

| # | What | Why (evidence) | Shape | Size | Risk | When | Delegate? |
|---|---|---|---|---|---|---|---|
| R1 | Flatten `legacy_stage` and delete dead stage data | Section 1 table; spec step 5 skipped; 12 external readers; agents copy `[a,b,c][stage-1]` into new forms | Each form's numbers become plain values; `volley_size`, echo delays, ricochets, burst counts become per-form fields; delete `legacy_stage`, crossfire/gunblade/scatter/lance/machine-gun stage branches; rename `evolution_stage` uses that mean tier | M | Low with a golden test: snapshot `base_stats(base, form)` and `shape_shot` for all 26 forms before, assert equal after | Before next turret | Yes, agent, with the golden test written first |
| R2 | One definition per form | Rows 4-10, 13 of the touch-point table; `base_stats` is the longest function in `scripts/` (113 lines) | `FORMS[id] = {name, model, tier, stats, behaviour, visual, implemented, describe}`; `TurretForm.create` reads `behaviour`; `TurretActor` calls one `visual.build(model, form_id)`; `IMPLEMENTED` derived; optionally one file per line (`scripts/turrets/<line>/`) | M | Low-medium | Before next turret (right after R1) | Agent, after owner picks dict rows vs `Resource` and the folder layout |
| R3 | Presentation and estimation hooks on forms; every turret has a form | 13 `"stormblade"` checks, `turret_type == "melee/sniper/quake/flamethrower"` in inspector/preview/shop data; 15 `if form`/`form is` checks in `turret_actor.gd`; flame reach inconsistency `shop_view_data.gd:75` | `TurretForm.stat_lines(stats) -> PackedStringArray`, `preview_lines(before, after)`, `estimated_dps(stats)`, `secondary_stats()`; `BaseForm` default (null object); UI uses `effective_range` | M | Medium (UI text) | Before next turret, or with Decoy at the latest | Owner approves API, then agent |
| R4 | Roster contract tests and test rig | Brittle counts (`test_turret_evolution.gd:76,100,112`, `test_shop_catalog.gd:17`); vacuous portrait asserts; 37 copied world setups; crit-seed dependence | `tests/helpers/turret_test_rig.gd` (`world()`, `turret(type, forms)`, `enemy(at, hp, type)`, `step`, `run`, `level_to(level)`), `TestHelpers.disable_crits()`; one data-driven test over every catalog turret: buy, level, both milestones offer forms, portrait files exist, model keys resolve, description non-empty | S | Low | Before next turret | Yes |
| R5 | Generic timed statuses with source ownership | Each status costs 7-8 edits (section 1); Overwatch unmark bug; Lullaby (sleep), Discord (infight), Decoy (taunt) are all statuses | `StatusEffects3D.apply(id, seconds, mode: REFRESH/EXTEND_CAP, source_id)`, `remaining(id)`, `has(id)`; `CombatShot3D/Hit3D.statuses: Array[StatusApplication]` copied once in `hit_from_shot`; marker table `{id: {radius, colour, height}}` ticked in one place; multipliers declared per status | M-L | Medium (touches combat core) | Before Decoy (after Sniper/Quake cleanup) | Owner designs, agent implements |
| R6 | Data-driven tools | `preview_evolution.gd`, `preview_shop.gd`, `capture_game.gd` grow one copied block per turret; bench and showcase restate `PATHS`; prices hard-coded | `--base=<id> [--form=<id>]` everywhere; rows from `PATHS` (+ an optional companion list for team-buff rows) | S-M | Low | Before next turret | Yes |
| R7 | Line-ending policy and normalisation | Section 7 table; CRLF in the files every turret edits | `.gitattributes`, `.editorconfig`, one `--renormalize` commit | S | Low (mechanical), timing matters | Right after the stack merges | Owner picks the moment; agent does it |
| R8 | Registry hygiene | Price/family split, Ion fallback on unknown ids, allocating `get_attack_families`, `"closest"`/`"cluster"` literals | Fold `price`, `family` into `TYPES`; `get_type` errors on unknown; cached families; `TurretIds`/`AttackFamily`/`Targeting` consts; `FIRE_NONE` for no-attack turrets | S | Low | Before Scrap Press | Yes (FIRE_NONE semantics need owner) |
| R9 | `TurretActor` attack strategies | 5 fire modes inline, Bow/Saber state on the actor, 14 forwarding wrappers | `TurretAttack` per fire mode; forms decorate the attack; public `new_shot/reset_cooldown/current_view` | M-L | Medium-high (core loop, many tests poke internals) | After the next three turrets (Boomerang, Mine, Laser add fire modes; design it with two real new modes in hand) | Owner judgement |
| R10 | `CombatEffects3D` split + `EffectPool` | 626 lines, six parallel-array pools, unpooled burns, per-tick scans | `EffectPool`, `ArcEffects`, `PulseEffects`, `FlameEffects`, `ActorOverlays` | M | Low | Whenever; natural with Laser (beam visuals) | Yes |
| R11 | Shared `MeshKit` and `BeatQueue` | 7 palettes, 6 helper sets; 3 delayed-action queues | as in section 3 | S | Low | Fold into R2 / the next form that needs it | Yes |
| R12 | Docs and asset cleanup | Section 7 | rewrite `gameplay.md:170-194`, remove duplicates, fix counts, delete `SpriteTODO.md`, `doc/.gdignore`, remove 23 orphan portraits | S | Low | Before next turret | Yes; owner decides on unused models |

## Recommended sequence

1. **Before the next turret (Decoy)**, on one short-lived branch after the stack merges:
   R7 (normalise) first, then R4 (tests that pin current behaviour), then R1 and R2 (behind the golden snapshot), R6, R12 and
   the quick wins. Then R3 and R8 (with `FIRE_NONE`), since Decoy and Scrap Press need them.
2. **Fold into turret work:** R5 lands with Decoy (taunt) or at the latest before Lullaby/Discord; R11 as the first new visual
   or queue needs it; R10 with Laser.
3. **Defer until three more turrets exist:** R9 (attack strategies), so the abstraction is shaped by Boomerang, Mine Layer and
   Laser rather than guessed.
4. **Retune (spec step 4)** after R1/R2, so it edits one table and the descriptions format from data.

## Quick wins (under an hour each)

- Remove the duplicated sections in `doc/combat.md:45-51` and `doc/gameplay.md:188`; fix `items.md` counts (56).
- Replace literal counts in `test_turret_evolution.gd:76,100,112` and `test_shop_catalog.gd:17-18` with derived ones.
- Replace vacuous `assert_not_null(ShopArt.turret(...))` with a portrait-file existence check.
- Add `TestHelpers.disable_crits()`; use it in exact-damage tests.
- Delete the unused 2D mock factories in `tests/helpers/test_helpers.gd:12-128`.
- Use `effective_range` in `shop_view_data.gd:75-76` (fixes Flamethrower reach in the build summary).
- Throttle the idle pulse scan (`turret_actor.gd:358-363`) with `target_clock`.
- Cache `TurretRegistry.get_attack_families` per type.
- Early-out `_update_burns`/`_update_shocks` when nothing burns or is shocked; only touch visible flame ribbons.
- Make `TurretRegistry.get_type` `push_error` on an unknown id (keep the Ion fallback for release builds if wanted).
- Share the burst intervals (`ShotBurst` `.09`/`.065`) as constants used by `shop_view_data.gd:136,151`.
- Guard the zero axis at `projectile_3d.gd:209`.
- Hold `waves.time_left` in `tools/bench_physics.gd`, as `bench_mix.gd:67` does.
- Add `doc/.gdignore`; add `.editorconfig` (before the normalisation commit).
- Delete `SpriteTODO.md`, the 7 blank lines at `turret_registry.gd:304-310`, `GameConstants.TURRET_SPLASH_AOE_RADIUS`.
- Remove the 23 orphan stage-2 portraits (pending owner OK).

## Risks that will bite the next turrets

- **Silent "Form in development":** a form whose model key does not resolve or is missing from `IMPLEMENTED` is filtered out of
  `available_evolutions` (`turret_actor.gd:485`) with no test failing except for the five hard-coded types.
- **Missing art passes tests:** portrait checks are vacuous; `ShopArt` falls back to an icon.
- **Copying the stage idiom:** new forms will keep `[a, b, c][stage - 1]` arrays and `legacy_stage` reads until R1 lands.
- **Shared statuses without owners:** the Overwatch unmark bug generalises to sleep/taunt/confuse from several turrets.
- **No-attack turrets:** the actor loop, DPS estimate and inspector assume damage; Scrap Press/Beacon/Lullaby/Discord need a
  `FIRE_NONE` path and an "item rules ignore me" check already partly in place.
- **Hits built outside `hit_from_shot`** (bat, flame, gunblade) will not carry new shot fields (stagger, future statuses).
- **Projectile special cases by `visual_key`:** Boomerang's returning path will add more string checks to `projectile_3d.gd`
  unless movement becomes a per-shot strategy; the known normalise error sits on that path.
- **Catalog order:** inserting rather than appending a turret changes seeded shop rolls and every bench using `TURRETS[i % 3]`.
- **CRLF files:** `turret_evolution.gd`, `turret_registry.gd`, `turret_inspector.gd` produce whole-file diffs and conflicts
  when agents edit them in parallel branches.
- **Crit-seed coupling:** exact-damage tests depend on RNG order; a new RNG consumer (e.g. Discord's target picks) can break
  unrelated tests.
- **Pulse/aura scans:** every idle pulse-mode turret scans all enemies each tick; several aura turrets multiply that.
- **Description drift:** prose numbers will diverge from the retuned constants.
- **Doc counts:** `index.md` hard-codes "ten base turrets" and "26 playable forms".

## Open questions for the owner

1. Dictionary rows in `turret_evolution.gd`, or one `Resource`/script per turret line under `scripts/turrets/<line>/`?
2. Keep the unused `cp_scatter`, `cp_focused_lance`, `cp_thunder_pin` models and the 23 stage-2 portraits, or delete them?
3. No-attack and aura turrets: a `FIRE_NONE` mode on `TurretActor`, or a separate actor class? Do Drone Bay drones and the Decoy
   live in `world.turrets`, `world.enemies` or a new list (crowd separation and targeting depend on it)?
4. When to run the line-ending normalisation commit relative to the open stack and any parallel branches?
5. Status stacking rules for the new statuses (sleep, taunt, infight): one owner, strongest wins, or per-source timers?
6. Is `--legacy-assets` still needed? It is why every new turret carries a fallback `model` GLB path (Quake points at
   `shock_turret.glb`).
7. Should `"fire"` stay in the registry, and should the Ion's id stay `"normal"`?
8. Retune before or after the data-driven move (recommended: after)?
9. Move large PNGs (`doc/art`, Clockwork textures) to LFS for new files going forward?
