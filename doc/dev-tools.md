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

Current flags: `reduced_motion` (user), `dev_panel` (dev, default on), `debug_overlays` (dev, requires `dev_panel`); experiments `entrench`, `placement_preview`, `items_v2`, `items_v2_hooks`, `mode_protect_core`, `tech_drops`, `difficulty_rules`, `terrain_zones`, `zone_readability` (live-safe, requires `terrain_zones`: off restores the flat tinted discs); dev flag `debug_zones` (requires `dev_panel`).

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

The console commands behind the buttons live on `ArenaWorld` (`dev_add_scrap`, `dev_jump_to_wave`, `dev_kill_all_enemies`, ...) and are covered by `tests/integration/test_dev_tools.gd`.

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
