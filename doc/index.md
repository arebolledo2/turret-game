# Turret Game — Documentation

## Quick Reference

| Item              | Value                                      |
| ----------------- | ------------------------------------------ |
| Engine            | Godot 4.6                                  |
| Language          | GDScript (static typing)                   |
| Architecture      | Service-oriented with event bus            |
| Key Pattern       | Signal bus (`Events` autoload)             |
| Testing           | GUT framework                              |
| Launch game       | `.\launch.ps1`                             |
| Run tests         | `.\run_tests.ps1`                          |
| Commit style      | Single emoji prefix                        |

## Project Overview

Wave-based survival tower defense game. Player dodges enemies while turrets provide primary damage. Purchase turrets and items between waves using scrap earned from kills. The game features multiple difficulty levels, 3 game modes (Escort, Tech Defense, Tunneling), 8 turret types, 8 enemy types, a tech tree, and items across 5 rarity tiers.

## Documentation Index

| Document                              | Description                                                                               | When to use                                        |
| ------------------------------------- | ----------------------------------------------------------------------------------------- | -------------------------------------------------- |
| [architecture.md](architecture.md)    | System architecture, service-oriented design, signal bus, registry and component patterns  | Understanding overall design and code organization  |
| [services.md](services.md)            | Autoload services grouped by domain, responsibilities, key signals                          | Adding or modifying game services                   |
| [asset-management.md](asset-management.md) | Unified asset config model, presets, overrides, validation, and live-apply behavior        | Working on visuals/collision config or preset logic |
| [combat.md](combat.md)               | Modifier/buff systems, projectiles, crits, status effects, economy                         | Working on combat mechanics or item effects         |
| [entities.md](entities.md)            | Entity component systems, enemy/turret components, behaviors, items                        | Adding enemies, turrets, items, or behaviors        |
| [game-modes.md](game-modes.md)        | Game state machine, wave cycle, game modes, core coordinators                              | Working on game flow, modes, or wave spawning       |
| [ui.md](ui.md)                        | UI architecture, HUD, screens, shop, font system, scaling                                  | Modifying or adding UI elements                     |
| [development.md](development.md)      | File guide, debug output, commands, testing, conventions                                   | Getting started, debugging, running commands        |

## Key Directories

| Directory            | Contents                                                      |
| -------------------- | ------------------------------------------------------------- |
| `scripts/autoload/`  | Service/autoload singletons and the `Events` signal bus        |
| `scripts/registries/`| Type definitions (enemies, turrets, items, techs, game modes) |
| `scripts/resources/assets/` | Typed asset config resources (visual/collision/entity config)      |
| `scripts/components/`| Entity components (player, enemy, turret) and behaviors       |
| `scripts/systems/`   | Core systems (modifier, buff)                                 |
| `scripts/ui/`        | UI screen and panel scripts                                   |
| `scripts/data/`      | Game constants and balance data                               |
| `resources/asset_presets/` | Built-in asset preset resources (`.tres`)                     |
| `resources/collision_profiles/` | Collision profile resources consumed by asset config      |
| `scenes/`            | Godot scene files                                             |
| `assets/`            | Sprites, audio, and other assets                              |
| `tests/`             | GUT unit and integration tests                                |
| `doc/`               | Project documentation                                         |

---

Art and sprite reference documentation is also available in `doc/`: MainCharSprite.md, PixelLabCharacterGen.md, PixelLabSpriteHelp.md, Prompts.md, Scrap.md, StyleMatrix.md.
