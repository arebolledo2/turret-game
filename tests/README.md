# Turret Survivor tests

Use PowerShell 7 and the Godot version in `.godot-version`. GUT 9.5.1 is vendored; its optional `exclude_addons` setting lookup has a local compatibility default.

## Commands

```powershell
# Import scripts/assets on a fresh checkout, then run the complete gate.
./run_tests.ps1 -Import
./run_tests.ps1 -unit
./run_tests.ps1 -integration
./run_tests.ps1 -filter "game_app"
./run_tests.ps1 -filter "asset" -full
./tools/test_test_gate.ps1
```

Set `GODOT_BIN` or pass `-GodotPath` for an installation outside the standard local location. The runner rejects a different engine version. `-unit` and `-integration` are mutually exclusive; `-filter` selects script filenames by substring. A filter matching nothing fails the run.

The runner isolates Godot's user data in `.test-results/<run-id>/`, by setting APPDATA/XDG_DATA_HOME only in its child process. It retains stdout, stderr, engine logs and `results.json`. It rejects nonzero exits, timeouts, missing/empty results, failures, risky/pending tests, unexpected engine errors and remaining orphan nodes. Errors explicitly asserted with GUT's engine-error assertions are exported individually; the gate exempts exactly those occurrences. It never suppresses a whole error category. Windows is the supported CI platform.

`.github/workflows/tests.yml` downloads the pinned engine, verifies its SHA512 checksum, tests the gate, audits resource links, imports the project, runs the full suite and exercises both six-wave progression builds. Results are uploaded even after failure. Updating Godot requires updating `.godot-version` and `.godot-windows-sha512` together.

## Test boundaries

- `unit/`: algorithms, registries, individual service instances and small component fixtures. Some use autoloads or a small scene tree; these are not all pure unit tests.
- `integration/`: complete scenes, purchases, combat and game-flow transitions.
- `helpers/test_helpers.gd`: a common gameplay-state reset and mock factories.
- `helpers/export_results.gd`: the runner's structured result export hook.

Call `TestHelpers.reset_all_services()` at the start of every test fixture. It binds fresh run state, resets gameplay preferences/modes, clears cached scene references and seeds independent gameplay/cosmetic RNG streams. A standalone service instance has its own `RunSessionState`; tests can inject explicit RNG and storage dependencies.

```gdscript
extends GutTest

func before_each() -> void:
    TestHelpers.reset_all_services()

func test_balance_changes_by_awarded_amount() -> void:
    var script = preload("res://scripts/autoload/economy_service.gd")
    var economy = autofree(script.new())
    economy.reset_state()
    var before: int = economy.total_scrap
    var award: int = economy.add_scrap_probabilistic(5, 1.0)
    assert_eq(award, 5)
    assert_eq(economy.total_scrap - before, award)
```

Use `autofree()` for nodes outside the tree and `add_child_autofree()` for scene fixtures. Never turn an unexercised branch into a passing test. Use fixed offers for purchase tests, injected seeded generators for generation tests, and explicit delta values for game-flow/cooldown tests. Keep real frame waits only where the behavior actually depends on frame scheduling.

Persistence tests create a local AssetConfigService instance, call `configure_storage()` before adding it to the tree, and remove only their own temporary directory. They do not change the global service's active preset, including when launched from the GUT editor UI.

The regression suite covers native 3D combat, supported purchases, session teardown, wave/shop/restart flow, keyboard/controller menu input, settings, shared registries/stat/modifier rules and asset storage failure paths. The cutover gate passes 784 tests: 365 retired 2D runtime tests were removed from the former 1,142, and seven new app/preferences tests were added.

Run `python tools/audit_game_resources.py` for resource closure. Real-physics six-wave checks use `res://tools/smoke_progression.tscn`, with `-- --control` selecting plasma/shock instead of ion. Both run in CI. See [development](../doc/development.md) for commands.
