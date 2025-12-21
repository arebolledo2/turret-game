# Turret Survivor Test Suite

Automated tests using [GUT (Godot Unit Test)](https://github.com/bitwes/Gut) framework.

## Test Structure

```
tests/
├── unit/                        # Pure logic tests (no scene tree)
│   ├── test_globals.gd          # Wave scaling, helper functions
│   └── test_difficulty_config.gd # Difficulty validation
├── integration/                 # Scene-based tests
│   ├── test_enemy.gd            # Enemy behavior and signals
│   ├── test_turret.gd           # Turret targeting and firing
│   ├── test_game_manager.gd     # Game state transitions
│   └── test_signal_flow.gd      # Events signal bus
```

## Running Tests

### From Command Line

```powershell
# Run all tests
.\run_tests.ps1

# Run only unit tests
.\run_tests.ps1 -unit

# Run only integration tests
.\run_tests.ps1 -integration

# Filter by test name
.\run_tests.ps1 -filter "test_enemy"

# Verbose output
.\run_tests.ps1 -verbose
```

### From Godot Editor

1. Open the project in Godot 4.3
2. Enable the GUT plugin: Project → Project Settings → Plugins → GUT → Enable
3. Open GUT panel: Bottom panel → GUT
4. Click "Run All" to run tests

## Writing New Tests

### Unit Test Template

```gdscript
extends GutTest

func before_each() -> void:
    Globals.reset_stats()
    Globals.current_difficulty = GameEnums.Difficulty.EASY

func test_example():
    var result = Globals.get_wave_duration(1)
    assert_eq(result, 20.0, "Wave 1 should be 20 seconds")
```

### Integration Test Template

```gdscript
extends GutTest

var scene: PackedScene
var instance: Node

func before_all() -> void:
    scene = load("res://scenes/enemy.tscn")

func before_each() -> void:
    Globals.reset_stats()
    instance = scene.instantiate()
    add_child_autofree(instance)

func test_signals():
    watch_signals(Events)
    # ... trigger action ...
    assert_signal_emitted(Events, "signal_name")
```

## Test Conventions

- **File naming**: `test_<feature>.gd`
- **Function naming**: `test_<description>()`
- **Use `add_child_autofree()`**: Auto-cleanup after each test
- **Reset state**: Call `Globals.reset_stats()` in `before_each()`
- **Signal testing**: Use `watch_signals(Events)` then `assert_signal_emitted()`

## Key Assertions

| Assertion | Purpose |
|-----------|---------|
| `assert_eq(a, b)` | Equality check |
| `assert_gt(a, b)` | a > b |
| `assert_lt(a, b)` | a < b |
| `assert_almost_eq(a, b, tolerance)` | Float comparison |
| `assert_true(condition)` | Boolean check |
| `assert_has(dict, key)` | Dictionary key exists |
| `assert_signal_emitted(obj, signal)` | Signal was emitted |
| `assert_signal_emitted_with_parameters(obj, signal, params)` | Signal with specific params |
