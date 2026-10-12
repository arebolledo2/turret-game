# Shared services

Autoload configuration in `project.godot` is authoritative. Commands and queries use explicit calls; `Events` carries shared notifications. Native world hits, explosions, pulses and deaths use the run-owned `Combat3D` signals.

| Service | Current role |
|---|---|
| `GameStateService`, `GameStateMachine` | Run counters, wave calculations and validated phase transitions |
| `EconomyService` | Scrap, shared item/turret pricing, purchase penalties and reroll policy |
| `PlayerStatsService`, `TurretStatsService` | Modifier-backed player and weapon stats |
| `ItemTrackingService`, `ModifierService` | Purchased stacks and effective stat calculation |
| `SettingsService`, `FeatureFlagService` | Persistent app preferences; typed feature flags with scopes, presets and next-wave queueing (see [dev tools](dev-tools.md)) |
| `DifficultyService` | Supplies the Easy preset used by `ArenaWorld` |
| `DebugService` | Structured debug output |

`ArenaShop` owns supported offer generation and transaction validation. It calls `EconomyService.calculate_turret_price()` and `calculate_item_price()` rather than duplicating pricing. Its short-run item base-price scale is local to the arena shop.

`RunSession` binds a fresh `RunSessionState` into the run-facing services and safely detaches that state when the arena exits. App preferences remain outside the session. Gameplay and cosmetic RNG streams remain separate.

## Retained systems

`SpecialEffectService` retains shared calculations that the current arena does not fully expose; chain reactions are not an active feature. The research tree (`TechTreeService`, `TechRegistry`) and the 2D asset configuration stack (`AssetConfigService`, `CollisionProfile`) were removed. The 2D game modes, loot review, temporary buffs and isometric arena were removed; they remain in git history and at the `prototype-2d-final` tag. Do not equate a feature flag or registry entry with a supported native 3D implementation.

The 2D AudioService, off-screen indicator service, entity query, projectile pool/emitter and target-selection runtime were removed. Native projectile reuse and crowd queries live in `scripts/game/`. The run-owned `GameAudio` now provides native spatial cues through the SFX bus; app-wide volume belongs to `SettingsService`.
