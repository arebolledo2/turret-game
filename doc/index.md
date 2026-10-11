# Turret Survivor documentation

Turret Survivor is a native 3D survival game in Godot 4.7.1. Move through a flat arena, reposition automated turrets, and buy upgrades between waves (20 by default). The Shop supports eight base turrets: Ion, Plasma, Shock, Tesla, Melee, Bow, Flamethrower and Bowling. The selected expansion adds eleven playable evolution branches with unique forms at levels 5, 10 and 15. See [the roster audit](plans/turret-expansion-audit.md) for availability and validation. The item catalog contains 50 general items, one core-only item and three Convoy-only items.

Launch with `./launch.ps1` or Godot F5. Run `./run_tests.ps1 -Import` on a fresh checkout.

| Guide | Purpose |
|---|---|
| [Gameplay](gameplay.md) | Controls, supported content, balancing and validation |
| [Architecture](architecture.md) | App, arena and shared service boundaries |
| [Services](services.md) | Runtime services and retained data systems |
| [Combat](combat.md) | Hits, projectiles, slow, crowd queries and units |
| [Entities](entities.md) | Native 3D actors and supported catalogs |
| [Game flow](game-modes.md) | Wave lifecycle, run configuration and session cleanup |
| [Items](items.md) | Item tags, turret families, the Phase 2 item pool and shop layout |
| [Dev tools](dev-tools.md) | Feature flags, flag presets, dev panel, telemetry and smoke options |
| [UI](ui.md) | Start screen, settings, HUD and controller focus |
| [Assets](asset-management.md) | Blender sources, GLBs and preserved 2D references |
| [Development](development.md) | Commands, tests, CI and conventions |
| [Combat polish](combat-polish.md) | Native SFX, feedback and performance measurements |
| [3D cutover](3d-cutover.md) | Retirement scope and verification record |

Current world code is under `scripts/game/`, scenes under `scenes/game/`, shared services under `scripts/autoload/` and `scripts/systems/`, and data under `scripts/registries/` and `scripts/data/`. Editable Blender sources are in `art-source/blender/`; runtime models are in `assets/models/game/`.

[The migration investigation](3d-migration-investigation.md) and [the earlier maintenance audit](audit-improvements.md) are historical records. Art notes under `doc/notes/` remain useful references. The 2D runtime is archived in Git at `prototype-2d-final`; it is no longer maintained.
