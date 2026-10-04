# Game flow

The normal launch exposes one supported mode: survival at Easy difficulty, 20 waves by default. A `RunConfig` (wave limit, difficulty, flag preset) is created by the start screen and read once by `ArenaWorld`; restarts reuse it. There are no difficulty, spawn-mode, arena-mode or win-condition selectors in the UI. The Medium and Hard difficulty presets in `DifficultyService` are retained for future work.

Play creates a fresh arena/session. Internally the shared state machine moves from `IDLE` into `WAVE_ANNOUNCEMENT`, waits two seconds, and enters `COMBAT`.

When the wave timer expires, `ArenaWorld.finish_wave()` clears surviving enemies and transient combat effects, collects remaining scrap, and awards the wave bonus. Waves before the configured limit enter `SHOP`; Continue begins the next announcement. Queued feature-flag changes apply as a wave begins (see [dev tools](dev-tools.md)). The final wave ends in `VICTORY`. Player death ends in `GAME_OVER`.

The shop offers two distinct turret types and two weighted supported items, repair, and reroll. Pause suspends simulation and transactions. The pause/end panels expose Main Menu, and end panels expose a fresh run. Restart resets purchases, modifiers, actors, drops and offers. Preferences survive.

`GameApp.return_to_menu()` removes the arena from the tree before freeing it, letting `RunSession` detach shared state synchronously. It then marks the game inactive, returns the shared phase to `IDLE`, and focuses Play. Repeated menu → Play → pause → menu cycles are covered by integration tests.

Wave duration/count calculations remain shared. Chargers join from wave 3. The progression smoke tool (six waves by default, `--waves=N` for longer runs) exercises actual physics, spawning, damage, earned scrap, purchases and victory for ion and plasma/shock builds. See [development](development.md).
