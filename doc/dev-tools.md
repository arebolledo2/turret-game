# Dev tools and feature flags

Every new system ships behind a feature flag so it can be switched on and off in game, in tests and in smoke runs. This page covers the flag contract, the dev panel, run configuration, telemetry and tool options. Roadmap context: Phase 0 of the gameplay roadmap.

## Feature flags

`FeatureFlagService` (autoload) owns every flag. A definition has:

| Field | Meaning |
|---|---|
| `name`, `description` | Shown in the dev panel |
| `default` | Value after `reset_state()` |
| `scope` | `user` (settings screen, saved with preferences), `dev` (tooling, dev builds only) or `experiment` (system under test; off in release builds) |
| `requires` | Flag ids that must be on. Enabling fails without them; disabling one switches its dependents off |
| `live_safe` | `true` applies immediately. `false` (default) means the change lands when the next wave begins |
| `phase` | Roadmap phase that introduced the flag |

Current flags: `reduced_motion` (user), `dev_panel` (dev, default on), `debug_overlays` (dev, requires `dev_panel`); experiments `entrench`, `placement_preview`, `items_v2`, `items_v2_hooks`, `mode_protect_core`, `tech_drops`, `build_zones`, `difficulty_rules`, `terrain_zones`, `zone_readability` (live-safe, requires `terrain_zones`: off restores the flat tinted discs); dev flag `debug_zones` (requires `dev_panel`).

APIs:

- `is_enabled(id)`: the applied value. Gate a system in **one** place and read this.
- `set_enabled(id, value)`: immediate, for tests, settings loading and presets between runs.
- `request_enabled(id, value)`: run-aware. Returns `applied`, `queued` or `rejected`. While a run is active, non-`live_safe` flags queue and `WaveDirector.begin_next_wave` calls `apply_pending()`. Starting or restarting a run discards queued changes.
- `get_effective(id)` shows the value once queued changes land; `get_pending()` lists them.
- `register_flag` / `unregister_flag` declare flags at runtime (tests). `reset_state()` restores the declared set.
- `apply_preset(id)`: `release` turns every experiment off, `all_experiments` turns them all on in dependency order. Presets never touch `user` or `dev` flags.
- `apply_flag_list("a,-b")` is the command-line form: `-` disables.
- `get_snapshot()` returns every non-user flag; telemetry and smoke output include it.
- `is_dev_build()` is true for debug builds and for release builds launched with `--dev`. `dev_panel_available()` also requires the `dev_panel` flag.

Developer and experiment flag values persist with the preferences file (`[dev_flags]`) only in dev builds, so a release build never loads an experiment.

### Adding a flag

1. Add the definition to `FLAG_DEFINITIONS` with a scope, description and `phase`. New gameplay systems use `experiment`.
2. Gate the system at its entry point. Content gates go in the registry data: add the row to `ShopCatalog` with `requires_flag` set, and the shop stops stocking and selling it while the flag is off.
3. Add a GUT test with the flag on and with it off.
4. When a system is proven, remove its flag and let the behaviour become the baseline.

## Turret progression foundation (Phase 1)

`turret_progression` is an experiment, **on by default**. In the F1 panel, **Experiment Flags → Turret Progression** controls it; restart the run after changing it. Saved developer preferences can override the default. Its configured value updates immediately but `RunSessionState.turret_progression_enabled` is latched at run start; toggling it during combat or a shop never switches the current economy. The panel's top section distinguishes the current run from the next-run setting and lists individual turret IDs, levels, XP, actual damage, level bonuses, pending milestones and the last settlement. Controller access is Back + right-stick click.

When enabled:

- Each uncollected raw scrap unit becomes one turret XP at successful wave end. Per-unit rolls favor proximity using `0.15 + 1 / (1 + planar_distance_squared / 16)`. All owned turrets, including carried ones, remain eligible at every level. Collected/queued-for-deletion pickups are excluded. Only a run with no eligible turret converts leftovers to normal cash.
- `WaveSalvage` freezes pickup and turret positions before cleanup, commits once per wave, and records allocations and before/after progression snapshots. Its separate RNG is derived from the gameplay RNG state at run start without advancing that stream. Defeat, restart and developer jumps do not settle scrap. Victory does. Cleanup itself never awards progression.
- `TurretProgression` costs 14 XP for level 2, then `ceil(28 + 2*(L-1) + .30*(L-1)^2)` per next level. Level 3 requires 45 cumulative XP; the observed 37 XP Hard wave-one award reaches level 2 with 23/31 XP. Milestones 5/10/15 require 116/375/812 cumulative XP. Multiple levels resolve immediately; excess XP carries forward. Ordinary levels add 3% damage additively, with milestone levels 5/10/15 reserved for forms. Growth continues beyond 15. Each turret applies its level multiplier once when constructing attack stats, alongside existing items, difficulty and entrenchment.
- Prices use `floor(base * 2 * (1 + .20*wave) * (1 + linear*N + .10*N*N) * discounts)`, with a minimum of 1. `linear` starts at .65 and cannot drop below .40. N counts all additional acquired frames, including free build rewards, excluding the starter. Paid purchases remain separate for Quantity Discount. Item prices and the normal wave cash bonus are unchanged.
- Leftovers no longer bank or improve next-wave build zones. Other build-zone behavior remains unchanged pending the encounter phase.

**Not yet playable evolution:** milestones are queued, with no forms or branch choices yet. The Shop now shows the wave’s XP and level gains, each owned turret’s level and next-level XP, and damage/item previews including individual level bonuses. A zero-XP award explains that no scrap was left behind. The F1 view additionally lists pending evolution milestones. The dedicated **Turrets** shop tab lets you inspect one turret at a time, including current combat stats and entrenchment. Switch tabs with Q/E or controller LB/RB; scroll inspection details with the mouse wheel or right stick. Positive/negative pickup-range items and harder build encounters are later phases. The legacy economy remains available with the flag off.

Run `./run_tests.ps1 -filter turret_progression` for foundation checks. Telemetry includes a per-wave `salvage` ledger, `turret_xp` and `salvage_fallback_cash`, plus XP/fallback totals; `scrap_earned` continues to count currency only. The original [evolution plan](plans/turret-evolution.html) contains the remaining phases and unvalidated balance targets.

## Wave-end salvage presentation

Rendered games hold `WAVE_END` for a salvage presentation when there is turret XP to award. After collection finishes, the recap stays open until the player presses Continue; there is no auto-advance timer. `WaveSalvage` commits the rewards once first; `SalvagePresentation` replays its immutable allocation ledger. Actual scrap models arc toward their assigned turret, XP bars count up, and each level crossing triggers a brief glow and sound. Cards show before/after damage and multi-level gains. Continue (controller A / Space / click) is required to leave the recap, and can also skip the animation while retaining all rewards. Pause freezes it; restart or scene exit cancels it without a later Shop transition. Carried turrets remain at their settlement position until the sequence finishes, then return to the ground. Final-wave awards play before Victory.

Reduced Motion preserves the XP count-up and recap but omits flying scrap and spatial pulses. The visual budget is 48 flights with two trail motes each; every allocation still contributes to the displayed XP. The presentation never consumes gameplay RNG or awards currency/XP itself. Empty salvage goes straight to Shop. `ArenaWorld.present_wave_rewards` defaults false under the headless renderer so automated simulation stays synchronous; lifecycle tests explicitly enable and advance the presentation.

## Shop catalog

`ShopCatalog.DEFAULT_ENTRIES` lists every turret and item the arena shop can sell, each with an optional required flag. `ArenaShop` stocks from `available_ids` and rejects purchases of entries that are not `is_available`, so a stale offer for gated content cannot be bought. It replaces the old hardcoded allowlist. Items without a 3D consumer stay out of the catalog.

## Run configuration

`RunConfig` holds wave limit (default 20), difficulty (default Easy) and an optional flag preset. `GameApp` creates one for Play and hands it to `ArenaWorld.run_config`; `ArenaWorld` reads it once at startup, so a restart reuses it. `RunConfig.slice()` is the original six-wave run, used by older integration tests. `mode` is `survive` or `core` (Phase 5); difficulty includes Brutal. Later phases add hero and run modifiers here. Tool arguments: `--waves=N --difficulty=easy|medium|hard|brutal --mode=survive|core --layout=crossroads|highlands|sump --preset=id`.

## Dev panel

`DevPanel` is added to the arena when `dev_panel_available()`. It pauses the run while open and restores the previous pause state on close.

| Input | Action |
|---|---|
| F1 | Toggle |
| Controller: hold Back, click right stick (either order) | Toggle |
| Esc / controller B | Close |

Navigation uses the standard UI focus actions (d-pad or left stick, A to activate), so the whole panel works on a controller. Contents:

- **Flag presets** and a checkbox for every flag, grouped by scope, each with its description and an "applies next wave" note. Queued changes show as `QUEUED ON/OFF`.
- **Run**: +50 / +500 scrap, restore hull, god mode, jump to the shop before the previous/next wave, deploy now (skip the shop), restart run.
- **Enemies**: spawn five of the selected type (basic, fast, tank, exploder, charger), kill all enemies.
- **Time**: cycle 0.25x to 4x. Time scale resets when the panel leaves the tree.
- `debug_overlays` shows a live text block (state, wave, enemy/turret/projectile counts, scrap, kills, pending flags, enabled experiments) without opening the panel. The frame readout is display only, not a measurement.

The console commands behind the buttons live on `DevCommands` (`world.dev.add_scrap`, `world.dev.jump_to_wave`, `world.dev.kill_all_enemies`, ...) and are covered by `tests/integration/test_dev_tools.gd`.

## Telemetry

`RunTelemetry` (`ArenaWorld.telemetry`) records per wave: kills, kills by turret (`"<id>:<type>"`; blank source means player gun or blast), completed turret moves, scrap earned, scrap spent by category (turret, item, reroll, repair) and hull lost. It never affects gameplay. Kill attribution uses `CombatShot3D.source_id` / `CombatHit3D.source_id`, stamped from `TurretActor.turret_id`.

## Smoke tool options

```powershell
godot --headless --path . res://tools/smoke_progression.tscn -- --waves=20 --preset=all_experiments --flags=debug_overlays --telemetry-out=C:/temp/run.json
```

| Option | Effect |
|---|---|
| `--control` | Buy plasma/shock instead of ion |
| `--waves=N` | Wave limit. The default is the six-wave slice so the regression gate stays quick |
| `--difficulty=easy\|medium\|hard` | Difficulty preset |
| `--preset=<id>` | Flag preset |
| `--flags=a,-b` | Enable/disable individual flags |
| `--telemetry-out=<path>` | Write the telemetry JSON. It is also printed as `PROGRESSION_TELEMETRY` |

The `PROGRESSION_SMOKE` line includes the flag snapshot so results from different flag sets can be compared.

## Performance tools

| Tool | Use |
|---|---|
| `res://tools/capture_game.tscn -- --stress` | Windowed stress capture. `GAME_METRICS` reports frame, physics, process, GPU and render-CPU medians and p95 |
| `res://tools/bench_physics.tscn` | Headless ablation: switches enemy, turret, world, effects and HUD processing off one at a time |
| `res://tools/bench_split.tscn` | Headless per-subsystem script timing per physics tick (engine-side physics cost is the remainder) |

Run the headless tools with `godot --headless --path . <scene>`. They measure CPU only, so a busy GPU does not affect them.

XP presentation uses a shared high-contrast `TurretXpBar`: large meters in the salvage recap and selected turret details, plus compact meters on every Turrets roster button. Current/next level labels lead; exact XP totals remain available in detailed inspection.
