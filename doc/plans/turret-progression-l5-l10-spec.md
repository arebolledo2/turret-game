# Spec: level 5 upgrade, level 10 final choice

Written 26 Oct 2026. Status: proposal, no code changed. Treat the code as the source of truth where this and the repo disagree. Roster and design rationale: `turret-roster-handoff.md` and the roster artifact.

## Goal

Replace the three-milestone model (levels 5/10/15, branch picked at 5) with:

- **Level 5:** one upgrade per turret. No choice. A straight improvement with a visible hardware change.
- **Level 10:** two final forms, pick one. Tuned above the level-5 form.
- **No level 15.** Levels keep coming forever as stat growth only.

Per turret: 1 upgrade + 2 finals. 19 turrets, 57 forms.

## Non-goals

- No change to the XP curve (`cost_to_next`) or the stat multipliers (`stat_multipliers`). The five-level burst keeps firing at 15, 20, 25 and so on; it is a stat bump, not a form. `test_growth_continues_beyond_mastery_without_extra_forms_or_compounding` already covers growth past the last milestone.
- No new Tesla, Plasma Constellation or new-turret attack logic. Those forms are registered but gated off until built (see Gating).
- No save migration. Branches are run-local and no save code references `evolution_branch` or `evolution_stage`.

## Design

### Form ids

Today a "branch" id (`machine_gun`) names a path, and a `stage` 1 to 3 picks the form. Under the new shape a final can descend from several upgrades, so ids move to **forms**. One id per form, `snake_case` of the display name.

| Base | L5 upgrade | L10 finals |
|---|---|---|
| normal (Ion) | `machine_gun` | `cyclone_gatling`, `omnifire` |
| melee | `saber` | `orbit_saber`, `stormblade` |
| bow | `repeater_bow` | `arrowstorm`, `titan_bow` |
| flamethrower | `wide_flame` | `inferno_crown`, `dragonheart` |
| bowling | `heavy_roller` | `juggernaut`, `ricochet_king` |
| plasma | `siege` | `worldbreaker`, `constellation` |
| shock | `resonator` | `resonance_engine`, `thunder_spear` |
| tesla | `forked_coil` | `storm_network`, `thunderhead` |

New turrets follow the artifact (Sniper `piercer_rifle` then `horizon_piercer` / `overwatch`, and so on) and are added when each turret is built.

### `TurretEvolution` (data)

Replace `PATHS` with:

```gdscript
const PATHS: Dictionary = {
	"normal": {"upgrade": "machine_gun", "finals": ["cyclone_gatling", "omnifire"]},
	...
}
const FORMS: Dictionary = {
	"machine_gun": {"name": "Machine Gun", "model": "machine_gun", "tier": 1},
	"cyclone_gatling": {"name": "Cyclone Gatling", "model": "gatling", "tier": 3},
	...
}
```

API (all static):

- `options(base_type, stage) -> Array[String]`: stage 0 returns `[upgrade]`, stage 1 returns `finals`, otherwise `[]`.
- `form_name(form_id)`, `description(form_id)`, `model_key(form_id)`, `base_stats(base_type, form_id)`.
- `legacy_stage(form_id) -> int`: the `tier` field, 1 for upgrades and 3 for finals.

`legacy_stage` is a transitional shim. Most per-form code indexes arrays by stage (`[2, 3, 5][stage - 1]`, `RESONATOR_ECHO_DELAYS[stage - 1]`, the `*EvolutionVisual.build(model, branch, stage)` builders). Passing `legacy_stage(form_id)` keeps those arrays and visuals exactly as authored: an upgrade renders and behaves as the old stage 1, a final as the old stage 3. The old stage-2 entries become dead data and are deleted in the cleanup step, not in the main change.

`IMPLEMENTED` becomes a list of form ids (20 today): `machine_gun`, `cyclone_gatling`, `omnifire`, `saber`, `orbit_saber`, `stormblade`, `repeater_bow`, `arrowstorm`, `titan_bow`, `wide_flame`, `inferno_crown`, `dragonheart`, `heavy_roller`, `juggernaut`, `ricochet_king`, `siege`, `worldbreaker`, `resonator`, `resonance_engine`, `thunder_spear`.

### `TurretProgression` (logic)

- `EVOLUTION_LEVELS = [5, 10]`.
- Rename `evolution_branch` to `evolution_form` (it now changes at the second evolution, so "branch" is misleading). `evolution_stage` stays and runs 0 to 2.
- `evolution_options(base_type)` keeps its guard logic (queued milestone matches the next level, level reached) and then returns `TurretEvolution.options(base_type, evolution_stage)`. The stage-0 special case that returned every branch and the later case that locked the choice both go away.
- `evolve(base_type, form)` sets `evolution_form = form`, increments the stage, pops the pending milestone.
- `snapshot()` reports `evolution_form`.
- The pending queue and ordering already guarantee the level-10 evolution is impossible before the level-5 one, even if a single award crosses both levels.

### Evolving in the shop

The level-5 upgrade stays a player-triggered, free evolve in the shop, like today. It just offers one button. This keeps the ceremony and the existing flow (`TurretActor.evolve`, inspector button, evolution preview) unchanged apart from names. Recommendation; auto-applying at level 5 is the alternative (see Open questions).

### Gating

`TurretActor.available_evolutions()` already filters by `IMPLEMENTED` plus an available model. Keep that. Consequences, all acceptable and tested:

- Tesla has registered forms but none implemented: no evolve buttons, as today.
- Plasma at level 10 offers only Worldbreaker until Constellation lands. The UI already handles a list of one.

### Stats and tuning

- Flatten the per-stage arrays: each form gets one stats block. Initial values: upgrades take the old stage-1 numbers, finals take the old stage-3 numbers.
- The finals were tuned for level 15. They now arrive at level 10 with five fewer levels of stat growth, so re-bench each at level 10 against its upgrade at level 10 (`tools/bench_turret_forms.gd`). Proposed target to start from: final DPS about 1.4 to 1.6 times the upgrade, never below it, with roles kept distinct. The user's rule is "better than level 5"; the exact ratio is a tuning decision.
- Shock's 19 Oct bench numbers are for the old stages and are obsolete.

### Art and assets

- `ShopArt.turret(id, form_id)` replaces `(id, branch, stage)`; portrait key becomes `form_id` (file `assets/ui/turrets/<form_id>.png`), falling back to the base id.
- Rename portraits: `machine_gun_1.png` to `machine_gun.png`, `machine_gun_3.png` to `cyclone_gatling.png`, `scatter_3.png` to `omnifire.png`, `lance_3.png` to `thunder_spear.png`, `resonator_1/3` to `resonator` / `resonance_engine`, and so on. Delete the 19 retired forms' portraits and their `.import` files. Tesla needs a new `forked_coil.png`; `storm_network` and `thunderhead` come from `relay_3` and `capacitor_3`.
- `ClockworkModels.KEYS` already has every model key the finals use. Retired keys (`focused_lance`, `thunder_pin`, and any stage-2-only keys) can be removed in cleanup.

## Change list

| Area | Files | Change |
|---|---|---|
| Data | `scripts/systems/turret_evolution.gd` | New `PATHS` / `FORMS`, new API, `IMPLEMENTED` as form ids, `legacy_stage`; `base_stats`, `shape_shot`, `description`, `model_key` take a form id |
| Logic | `scripts/systems/turret_progression.gd` | Levels, rename field, options/evolve |
| Actor | `scripts/game/turret_actor.gd` | Lines ~103-120 (form creation, model key, visual builders), ~297-301 (stats), ~391 (`shape_shot`), ~426-443 (`display_name`, `available_evolutions`, `evolve`), ~499-501 (Saber blade count: Orbit Saber is 3 blades, Saber 1) |
| Forms | `scripts/game/turret_form.gd` and `*_form.gd` | `TurretForm.create` keys by form id (`machine_gun` and `cyclone_gatling` both map to `MachineGunForm`; `scatter` becomes `omnifire`; `resonator` / `resonance_engine`; `lance` becomes `thunder_spear`); replace `evolution_stage` reads with `legacy_stage(evolution_form)` |
| UI | `scripts/ui/turret_inspector.gd`, `evolution_preview.gd`, `scripts/game/shop_view_data.gd` | Milestone loop is two entries; the milestone-0 label is the upgrade, milestone-1 is the chosen final; replace `evolution_branch == "gunblade"` checks (inspector 212, 249; shop_view_data 95, 118, 129, 207) with form-id checks (`stormblade`); preview takes a form id |
| Dev / salvage | `scripts/game/dev_commands.gd` (66), `dev_panel.gd` (98), `salvage_presentation.gd` (250) | They iterate `EVOLUTION_LEVELS`, so only the length changes; verify the dev panel can reach both forms |
| Tools | `tools/bench_turret_forms.gd`, `preview_evolution.gd`, `showcase_turret_roster.gd`, `render_shop_portraits.gd` | Port specs to form ids; showcase loop ends at stage 2 instead of 3 |
| Docs | `doc/architecture.md`, `doc/plans/turret-roster-handoff.md` | Replace the three-stage description |

## Tests

Existing tests to port, by file (counts from the repo; each needs a read-through, not a mechanical rename):

- `tests/unit/test_turret_evolution.gd` (39 lines): rewrite. Replace the branch-lock test with: level 5 offers exactly one form; level 10 offers the two finals; the level-10 final cannot be taken before the level-5 upgrade; a single award crossing both levels queues both in order; invalid base or unearned milestone cannot evolve. Replace "each base has two complete named paths" with: every base has one upgrade and two finals, all with names, and every `PATHS` form exists in `FORMS`.
- `tests/unit/test_turret_progression.gd`: update `test_thresholds_overflow_and_ordered_milestones` (two milestones, none at 15) and `test_levels_reward_distinct_stats_and_milestone_burst`; keep the beyond-mastery growth test and assert no pending evolution appears at level 15 or 20.
- `tests/integration/test_evolved_turrets.gd` (676 lines): port every per-form behaviour test to form ids and drop tests for retired forms (Gatling, Crossfire, Twin Saber, Repeater Blade, Volley Ballista, Echo Chamber, Focused Lance, Thunder Pin, and the other stage-2 forms). Keep one test per surviving form.
- `tests/integration/test_turret_progression_run.gd`, `test_shop_focus.gd`, `test_dev_tools.gd`, `test_expansion_base_turrets.gd`: update field names and milestone expectations.
- New: `legacy_stage` returns 1 for every upgrade and 3 for every final; `ShopArt.turret_portrait_key` resolves every implemented form (missing portrait files are a test failure, not a silent fallback).
- Use the `godot-test` skill. After adding the new `class_name` scripts, run the `-Import` step first, and keep the zero-orphan gate clean.

## Work order

1. **Data and logic:** `TurretEvolution`, `TurretProgression`, plus the unit tests. The game must not be left half-converted, so land steps 1 to 3 together in one branch.
2. **Consumers:** actor, forms, UI, shop view data, tools, with the shim keeping behaviour identical.
3. **Integration tests, portraits and assets.** Run the full suite; the game should play identically to today for the 20 surviving forms.
4. **Retune:** bench finals at level 10, adjust stats.
5. **Cleanup:** delete stage-2 array entries, retired model keys, retired portraits, `legacy_stage` once the arrays are flattened.
6. **Then** the per-turret build work (Tesla first), each against the new shape.

## Risks

- The shim hides how much of the code still thinks in stages. Step 5 is easy to skip; track it.
- Portrait and model renames break silently (fallback textures). The new portrait test guards this.
- Finals that were balanced against level-15 stat growth may feel weak at level 10 until retuned (step 4).
- Players mid-run when this ships are not an issue (run-local), but test fixtures and dev saves that hard-code `evolution_branch` will fail loudly.

## Decisions (26 Oct 2026)

1. Level-5 evolve stays a free, player-triggered shop button (one option). No flow change.
2. `evolution_branch` is renamed to `evolution_form` in the same change.
3. Retune: start finals at roughly 1.4 to 1.6 times the upgrade's DPS at level 10, and adjust per turret role during the bench step.

## Follow-up outside this change

The `3d-asset-design` skill still describes the old levels (a level-10 sibling concept of a level-15 form, `<branch>_{1,2,3}.png` portraits, `model_key` per stage). Update it once this lands: one concept per final form, one per level-5 upgrade, portraits named by form id.
