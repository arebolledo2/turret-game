# Turret Game - AI Agent Instructions

Wave-based survival tower defense game built in **Godot 4.7** using GDScript. Player dodges enemies while turrets provide primary damage. Purchase turrets and items between waves using scrap earned from kills.

## Quick Reference

- **Engine**: Godot 4.7
- **Language**: GDScript with static typing
- **Architecture**: Service-oriented with event bus pattern
- **Key Pattern**: Explicit commands/queries; signal bus (`Events`) for notifications
- **Tests**: GUT framework - run with `.\run_tests.ps1`
- **Launch**: `.\launch.ps1`
- **Current game**: Native 3D; see `doc/gameplay.md`. The 2D runtime is retired.
- **Commit Style**: Single emoji prefix (e.g., `✨ Add feature`, `🐛 Fix bug`)

## Documentation

Full documentation is in `doc/index.md`. Key documents:

| Document | Description |
| --- | --- |
| [doc/index.md](doc/index.md) | Documentation hub with quick reference and directory guide |
| [doc/architecture.md](doc/architecture.md) | System architecture, service-oriented design, signal bus, registries |
| [doc/services.md](doc/services.md) | Autoload services grouped by domain |
| [doc/combat.md](doc/combat.md) | Modifier/buff systems, projectiles, crits, status effects |
| [doc/entities.md](doc/entities.md) | Entity components, enemy/turret types, behaviors, items |
| [doc/game-modes.md](doc/game-modes.md) | Game state machine, wave cycle, game modes, coordinators |
| [doc/ui.md](doc/ui.md) | UI architecture, HUD, screens, shop, font system |
| [doc/development.md](doc/development.md) | File guide, debug output, commands, testing, conventions |

## Asset workflow skills

- [.claude/skills/blender-assets/SKILL.md](.claude/skills/blender-assets/SKILL.md) — Rebuild and validate the scripted Blender turret/drone model family.

- [.claude/skills/game-audio/SKILL.md](.claude/skills/game-audio/SKILL.md) — Rebuild procedural cues and validate the native 3D SFX mixer.
