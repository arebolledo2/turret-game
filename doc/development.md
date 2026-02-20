# Development Workflow

## Commands

| Command | Description |
| --- | --- |
| `.\launch.ps1` | Launch the game in the Godot editor |
| `.\run_tests.ps1` | Run all GUT tests |
| `.\run_tests.ps1 -unit` | Run unit tests only |
| `.\run_tests.ps1 -integration` | Run integration tests only |
| `.\run_tests.ps1 -filter "pattern"` | Run tests matching a name pattern |

## File Guide

Quick reference for finding code by purpose:

| Purpose | Location |
| --- | --- |
| Game balance | `scripts/data/game_constants.gd`, `GameConstants.DIFFICULTY_CONFIG` |
| Service logic | `scripts/autoload/` |
| Type definitions | `scripts/registries/` |
| Asset config resources | `scripts/resources/assets/`, `resources/asset_presets/`, `resources/collision_profiles/` |
| Entity behaviors | `scripts/turret.gd`, `scripts/enemy.gd`, `scripts/components/` |
| UI scripts | `scripts/hud.gd`, `scripts/ui/` |
| Tests | `tests/unit/`, `tests/integration/` |
| Debug output | `scripts/autoload/debug_service.gd` |
| Scenes | `scenes/` |
| Assets | `assets/sprites/`, `assets/audio/` |

## Testing

**Framework:** GUT (Godot Unit Testing)

Tests are located in:
- `tests/unit/` — Unit tests for individual services and components
- `tests/integration/` — Integration tests for cross-system behavior

Run tests using the PowerShell test runner:
```powershell
# All tests
.\run_tests.ps1

# Unit tests only
.\run_tests.ps1 -unit

# Integration tests only
.\run_tests.ps1 -integration

# Filter by test name
.\run_tests.ps1 -filter "test_economy"

# Asset config focused unit tests
.\run_tests.ps1 -unit -filter "asset_config"
```

## Debug Output Management

**DebugService** (`scripts/autoload/debug_service.gd`) provides compile-time debug output control with **7 categories**:

| Category | Scope |
| --- | --- |
| ENTITY | Entity lifecycle (enemies, turrets, defense targets) |
| COMBAT | Combat mechanics (damage, collisions, projectiles) |
| AI | Enemy AI and movement |
| ARENA | Arena setup and configuration |
| UI | User interface systems |
| SYSTEMS | Core game systems (state machine, spawning) |
| VALIDATION | Warnings and errors (default: enabled) |

### Usage

```gdscript
DebugService.log(DebugService.ENTITY, "Enemy spawned at: ", position)
DebugService.warn(DebugService.VALIDATION, "Missing component")
DebugService.error(DebugService.VALIDATION, "Invalid state")
```

### Controlling Output

Edit const flags in `scripts/autoload/debug_service.gd`:

```gdscript
const ENABLED: bool = true      # Master switch
const ENTITY: bool = true       # Enable/disable ENTITY logs
const COMBAT: bool = false      # Enable/disable COMBAT logs
# ... etc
```

**Zero runtime overhead** — disabled categories are optimized away by the GDScript compiler at compile time.

## Conventions

### Commit Style
Single emoji prefix for all commits:
- `✨ Add feature` — New feature
- `🐛 Fix bug` — Bug fix
- `♻️ Refactor code` — Refactoring
- `🧪 Add tests` — Test additions
- `📝 Update docs` — Documentation

### GDScript Style
- **Static typing** required for all variables and function signatures
- **Signal bus** (`Events`) for all cross-system communication
- **Services first** — access autoload services directly, no facades
- **Component-based** — player and entities use behavior components
- **Test coverage** — all new features require GUT tests
- **Debug categories** — use `DebugService.log()` with appropriate category
