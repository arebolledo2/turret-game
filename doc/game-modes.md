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

`PlayfieldView` reserves a compact 76-unit header and no footer. The minimap, status text, boss health and prep controls overlay the playfield; prep has no full-width opaque footer panel. The camera uses the playfield viewport aspect ratio, and mouse projection and world-attached indicators account for its screen offset and pixel scale. The 3D subviewport renders at physical window density with 2x MSAA, independently of the logical UI reference canvas. Decorative floor extends beyond arena bounds so wide zoom does not expose background strips; collisions and playable bounds are unchanged. Shop/pause/reward review remain separate modal screens.


## Core weapon

Both objective modes give the core an automatic projectile weapon. Its independent `RunConfig.core_weapon` profile initially copies Pip's base sidearm (12 damage, 1.2 shots/s, 3.75 m range). It uses the shared weapon/item resolver and critical-hit rules, targets the nearest enemy whose hurtbox overlaps range, and fires through the normal projectile/effects pipeline from the reactor. Its cooldown and negative source ID are separate from the hero and turret identities. Carrying a turret does not suppress core fire. Prep, pause, shop, round end and core death suppress firing. Future core variants can replace the profile without changing the hero loadout; no new core model is introduced.


## Turret purchase curve

Progression pricing counts the starter plus all additional acquired frames. The first six total turrets have no count surcharge and no doubled base cost. The seventh starts steep escalation: count multipliers for turrets 7/8/9/10 are 3.0/6.4/11.2/17.4 before reduction items. Let `N` be additional frames acquired and `E = max(0, N - 4)` for the next purchase. Price is `floor(base * (1 + 0.20 * wave) * (1 + (1.30*E + 0.70*E*E) * adjusted_coefficient/0.65) * shop_discount)`, with the existing Quantity Discount afterward and a minimum price of 1.

Compact Design subtracts 0.04 per stack and Mass Production 0.10 from the coefficient (base 0.65); both now reduce the whole surcharge, with a zero floor and no hidden 0.40 minimum. Their legal combined maximum is a coefficient of 0.33. Below seven turrets there is no count surcharge to reduce. Locked offers retain their captured price; unlocked offers reprice after purchases. Acquisition counting prevents selling or losing frames from resetting escalation. Legacy non-progression economy remains unchanged.

Affordability target: purchasing five Ion turrets after waves 1–5 costs 9+11+12+14+16 = 62 scrap, for six including the starter before wave 6. Starting funds (20) plus those wave bonuses (75) cover this with 33 left over before pickup income or item spending. More expensive turret mixes require collected scrap; six by wave 7 is a budget target rather than a guarantee of shop choices or player spending.

### Protect-the-Core wave pressure

Waves 1-5 keep their easy ecology rosters. From wave 6, mode-specific rosters reserve at least half the encounter-point budget for active core attackers (assault enemies and Kiln Lobbers), with hero hunters and bosses retaining their targeting identities. Half or more of ordinary assault arrivals become core seekers, using the higher of 50% and the difficulty seeker share. Boss waves 6/12/20 use 60% escort budgets instead of 25%, with distinct basic/tank, fast/tank, and tank/charger escorts. Capped specialist spawns fall back within the mode-specific roster. Survival and Convoy retain their existing rosters, escort budgets, and seeker rules.

Spawn-zone discs in core modes leave 2 m of clear ground between the zone edge and the core body or any planned convoy route segment (including future legs). Rejected random candidates are never committed; constrained routes may produce fewer zones, with the normal random spawn fallback still active.
