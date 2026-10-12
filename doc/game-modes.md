# Game flow

The start screen selects difficulty and Survival, Protect the Core or Convoy mode. These choices persist between runs. Play creates a fresh arena/session from `RunConfig`; the normal run has twenty waves.

## Preparation before every wave

Every run begins in **PREPARATION**, and the Shop's **PREPARE** button enters preparation for the next wave. This phase has no time limit. The hero is hidden; the core, combat timers, enemy arrivals, attacks and entrenchment accumulation are stopped. Turrets can be moved directly anywhere valid in the arena, without the hero carrying them.

Select a turret with the cursor or cycle through the squad. Its effective attack range is shown. Begin a move, choose a destination, and place it. Core clearance, arena edges, other turrets and blocked terrain remain authoritative. Invalid positions are red and cannot be committed. Cancel restores the exact original position and entrenchment. A confirmed relocation resets entrenchment; leaving a turret in place preserves it. Moving turrets is free.

| Action | Controller | Mouse / keyboard |
|---|---|---|
| Move cursor / turret | Left stick | Mouse or WASD / arrows |
| Select / place | A | Left click, Space or E |
| Cycle turrets | LB / RB | [ / ] |
| Cancel move | B | Right click or Backspace |
| Start wave | X | Deploy button or Enter |
| Zoom | Triggers | Wheel or zoom keys |
| Pause | Start | Escape |

**Deploy requires all moves to be finished or canceled.** It restores the hero at the combat position, returns the camera to the hero, and starts the 0.8-second wave announcement. Combat follows. Deploy is a separate action from Select / Place, so pressing A to place a turret cannot accidentally start the wave.

## Combat, rewards and the Shop

Survival and stationary core rounds end at the timer. Convoy rounds normally end when the core reaches the final wall doorway; a safety timer remains. Wave cleanup resolves final-tick damage, settles uncollected scrap as turret XP when progression is enabled, and clears surviving enemies and temporary attacks. The XP presentation requires Continue. Pending chest or boss items then receive Keep / Sell review. Waves before the run limit enter the Shop; the final wave ends in Victory. Hero death or core destruction ends the run.

The full-screen Shop offers one turret and three items, free offer locking, rerolls, repairs and turret inspection/evolution. Prepare exits the Shop into untimed placement. Queued feature flags apply when the next wave is initialized. Pause suspends simulation and transactions. Returning to the main menu removes the arena before freeing it, allowing `RunSession` to detach shared state synchronously. Restart clears run purchases, modifiers, actors, drops, offers and any unfinished placement; preferences persist.

See [enemy ecology](enemy-ecology.md) for authored wave rosters, grouped arrival warnings and moving-core routes. Automated combat tools explicitly deploy preparation before simulating combat.


## Playfield and controls

Prep reads the same dedicated gamepad stick actions as the hero. Left stick moves the cursor (and a selected turret while repositioning); A selects/places, B cancels, LB/RB cycles turrets, X deploys, and triggers zoom. Cursor button commands are handled before GUI focus navigation. Keyboard and mouse placement remain supported; clicking the UI rail cannot place a turret.

`PlayfieldView` reserves a compact 76-unit header and no footer. The minimap, status text, boss health and prep controls overlay the playfield; prep has no full-width opaque footer panel. The camera uses the playfield viewport aspect ratio, and mouse projection and world-attached indicators account for its screen offset. Decorative floor extends beyond arena bounds so wide zoom does not expose background strips; collisions and playable bounds are unchanged. Shop/pause/reward review remain separate modal screens.
