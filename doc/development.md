# Development

Use Godot 4.7.1 (pinned in `.godot-version`) and statically typed GDScript. The repository is a standalone Git repository inside `turret-dev`. Commit messages use a single emoji prefix. Run relevant tests before committing.

```powershell
./launch.ps1
./run_tests.ps1 -Import
./run_tests.ps1 -filter game_app
./run_tests.ps1 -filter 3d_
python tools/audit_game_resources.py
./tools/test_test_gate.ps1
```

`launch_3d.ps1` is a compatibility alias for the default launcher. Set `GODOT_BIN` or use `-GodotPath` for another installation of the pinned version. Godot F5 opens the start screen; F6 on `scenes/game/arena.tscn` opens an arena directly.

## Complete runs and visual checks

Using the Godot console executable as `godot`:

```powershell
godot --headless --path . res://tools/smoke_progression.tscn
godot --headless --path . res://tools/smoke_progression.tscn -- --control
godot --headless --path . res://tools/smoke_progression.tscn -- --waves=20 --flags=dev_panel --telemetry-out=telemetry.json
godot --path . --resolution 1280x720 res://tools/capture_app.tscn
godot --path . --resolution 1280x720 res://tools/capture_game.tscn -- --shop
godot --path . --resolution 1280x720 res://tools/capture_game.tscn -- --combat-demo
godot --path . --resolution 1280x720 res://tools/capture_game.tscn -- --stress
godot --path . --resolution 2000x1050 res://tools/capture_game.tscn -- --zones --focus=mud
```

Smoke runs default to the six-wave slice; see [dev tools](dev-tools.md) for `--waves`, `--preset`, `--flags` and `--telemetry-out`. They use a seeded dodge bot, actual physics and earned budgets; success requires victory. Native captures require a GPU driver and write ignored `.test-results/` PNGs. Inspect images and stdout/stderr. Stress samples are development measurements, not minimum-spec guarantees.

CI installs the pinned engine, verifies the test gate, audits resource links, imports assets, runs the complete GUT suite and both progression routes, and retains diagnostics. See [tests/README.md](../tests/README.md) for isolation and strict error handling.

Current implementation directories and ownership are listed in [architecture](architecture.md). Use the [Blender asset skill](../.claude/skills/blender-assets/SKILL.md) for geometry/model edits. Historical 2D code is available at `prototype-2d-final`; preserve shared contracts, but do not maintain a second gameplay runtime.

## Arena test performance

Floor texture resources are retained in `WorldGeometry` across arena teardown. Godot's resource cache does not keep otherwise unreferenced maps alive, so loading them afresh for each fixture repeatedly decompresses the 2048px maps. Materials remain per-arena so wave tints do not leak between runs. On the October 12 local check, retaining textures reduced the preparation suite from 8.9s to 1.6s; the complete suite passed 984 tests in 31.2s versus the previous 244.6s run. These are local timings, not CI time limits.
