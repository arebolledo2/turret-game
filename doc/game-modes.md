# Game flow

The normal launch exposes one supported mode: six survival waves at fixed Easy difficulty. There are no difficulty, spawn-mode, arena-mode or win-condition selectors. Retained registry/state-machine entries describe shared data and possible future work.

Play creates a fresh arena/session. Internally the shared state machine moves through its setup state into `WAVE_ANNOUNCEMENT`, waits two seconds, and enters `COMBAT`. The setup enum `DIFFICULTY_SELECT` does not represent a visible selection screen in this version.

When the wave timer expires, `ArenaWorld.finish_wave()` clears surviving enemies and transient combat effects, collects remaining scrap, and awards the wave bonus. Waves 1–5 enter `SHOP`; Continue begins the next announcement. Wave 6 ends in `VICTORY`. Player death ends in `GAME_OVER`.

The shop offers two distinct turret types and two weighted supported items, repair, and reroll. Pause suspends simulation and transactions. The pause/end panels expose Main Menu, and end panels expose a fresh run. Restart resets purchases, modifiers, actors, drops and offers. Preferences survive.

`GameApp.return_to_menu()` removes the arena from the tree before freeing it, letting `RunSession` detach shared state synchronously. It then marks the game inactive, returns the shared phase to `IDLE`, and focuses Play. Repeated menu → Play → pause → menu cycles are covered by integration tests.

Wave duration/count calculations remain shared. Chargers join from wave 3. The six-wave progression smoke tool exercises actual physics, spawning, damage, earned scrap, purchases and victory for ion and plasma/shock builds. See [development](development.md).
