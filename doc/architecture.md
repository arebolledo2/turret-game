# Architecture

`scenes/main.tscn` creates `GameApp`, the application shell. Play creates one `ArenaWorld` from `scenes/game/arena.tscn`. Returning to the menu detaches the arena synchronously before freeing it, so a subsequent Play cannot inherit the old session's service bindings.

## Ownership

| Owner | Responsibilities |
|---|---|
| `GameApp` | Start screen, settings, Play, Quit, menu focus and arena lifetime |
| `ArenaWorld` | Composition root: actor lists, firing, scrap, death handling, pause and input; delegates to the helpers below |
| `ArenaStage` | Floor, rim, lighting and the follow camera, built once |
| `WaveDirector` | Announcement, spawn schedule, wave timer and wave-end resolution |
| `TurretPlacement` | Placement rules and the carry/place interaction |
| `BlastEffects` | Area blasts after a kill: Reactor Overload and boom-bot explosions |
| `DevCommands` | Developer commands behind the dev panel (`world.dev.*`); never reachable from normal play |
| `RunSession` | Fresh `RunSessionState` and shared service binding/teardown |
| `Combat3D` | Authoritative damage and local hit/explosion/pulse/defeat notifications |
| `GameAudio` | Bounded spatial SFX voices and cue throttling |
| `ArenaShop` | Supported stock, validation, transactions and rerolls |
| `game_hud.gd` | HUD, refit, build summary and pause/end presentation |

World classes live in `scripts/game/`. `CombatActor` (with the `TechDropActor` crate subclass), `TurretActor`, `Projectile3D` and `ScrapPickup` own individual behavior. `TurretActor` dispatches on the registry's `fire_mode` (projectile, pulse, chain, sweep) rather than on turret ids; resolved stats are read through the typed `TurretStats` and `EnemyStats` views in `scripts/data/`. `ChargeController3D`, `StatusEffects3D`, `CrowdGrid3D` and `CombatEffects3D` isolate combat concerns. `TurretActor` delegates to `TurretEntrench` (stack rules and ring), `TurretTerrain` (zone bonuses and badge), `TurretRangeRing` and `ShotBurst` (delayed follow-up shots); per-form shot shapes, volley size, gunblade barrel stats and the list of implemented branches live in `TurretEvolution`, so a new form is data plus its visual and attack, not edits across the actor.

## Shared state and notifications

Use explicit calls for commands and queries. Shared services expose economy, stats, registry and modifier rules; `Events` carries shared notifications. World combat notifications remain on the run-owned `Combat3D`, with typed `CombatShot3D` and `CombatHit3D` records. Do not introduce autoload world lookups into damage resolution.

`RunSession.begin_run()` binds fresh state into the run-facing services. On tree exit it replaces bindings only if it still owns them, preventing an older scene from detaching a newer session. App preferences persist separately through `SettingsService`.

`WorldGeometry.METRES_PER_PIXEL = 0.01` is the conversion boundary for existing registry distances and speeds. Damage and durations keep their original units. Visual animation does not change authoritative collision shapes.

## Scope

The native 3D runtime replaces the 2D runtime. Shared registry entries, modifier/buff calculations, and mode data remain available for future work, but their presence does not imply gameplay support. `ArenaShop` allowlists are the source of truth for exposed purchases. See [gameplay](gameplay.md) for supported behavior and [cutover](3d-cutover.md) for retirement details.
