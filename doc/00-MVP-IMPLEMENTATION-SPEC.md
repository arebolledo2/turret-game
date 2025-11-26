# MVP Implementation Specification

> **This is the single source of truth for MVP implementation.**  
> Documents 01-04 contain the broader vision and are deferred to post-MVP.

---

## Overview

A minimalist wave-based survival game focused on discovering the core "feel" of turret-based combat. The player dodges enemies while turrets spawn randomly and provide the primary damage output.

**Core Loop:**
1. Wave starts → brief "Wave X" announcement → new turret spawns with visual effect
2. Enemies spawn continuously throughout the wave (time-based)
3. Player dodges and deals weak auto-fire damage
4. Turrets auto-target and damage nearest enemies
5. Enemies drop XP orbs (visual feedback only, no gameplay effect)
6. Wave ends when timer expires
7. Brief pause → Repeat until wave 10 (win) or player death (lose)

---

## Constants & Values

### Player Stats
| Stat | Value | Notes |
|------|-------|-------|
| Max Health | 100 HP | |
| Health Regen | 0 | No regen in MVP |
| Movement Speed | 300 units/sec | |
| Pickup Radius | 50 units | Auto-collect XP drops |
| Invincibility Frames | 0.5 seconds | After taking damage |
| Hits to Survive (per wave) | 3 | Balanced around this |

### Player Weapon (Auto-fire)
| Stat | Value | Notes |
|------|-------|-------|
| Damage | 5 per shot | ~10-15% of total DPS |
| Fire Rate | 3 shots/sec | |
| Range | 200 units | Auto-targets nearest enemy |
| Projectile Speed | 600 units/sec | Visible projectile |

### Turret Stats (Single Type)
| Stat | Value | Notes |
|------|-------|-------|
| Damage | 15 per shot | Main damage source |
| Fire Rate | 2 shots/sec | |
| Range | 250 units | |
| Projectile Speed | 500 units/sec | |
| Rotation Speed | 180 deg/sec | Turret tracks enemies |
| Minimum Spawn Distance | 100 units | From other turrets |
| Player Spawn Exclusion | 150 units | Won't spawn on player |

### Enemy Stats (Base - Wave 1)
| Stat | Base Value | Scaling |
|------|------------|---------|
| Health | 30 HP | +10% per wave |
| Movement Speed | 150 units/sec | +3% per wave |
| Contact Damage | 33 HP | ~3 hits = death from full |
| Size (Collision) | 24 units radius | |

### Wave Configuration
| Wave | Duration | Enemy Count | Enemy HP | Enemy Speed |
|------|----------|-------------|----------|-------------|
| 1 | 20 sec | 10 | 30 | 150 |
| 2 | 24 sec | 14 | 33 | 155 |
| 3 | 28 sec | 18 | 36 | 159 |
| 4 | 32 sec | 22 | 40 | 164 |
| 5 | 36 sec | 26 | 44 | 169 |
| 6 | 40 sec | 30 | 48 | 174 |
| 7 | 44 sec | 34 | 53 | 179 |
| 8 | 48 sec | 38 | 58 | 185 |
| 9 | 52 sec | 42 | 64 | 190 |
| 10 | 60 sec | 50 | 70 | 196 |

**Wave Timing Formula:**
- Duration: `20 + (wave - 1) * 4` seconds (wave 10 = 60 sec)
- Enemy Count: `10 + (wave - 1) * 4` enemies
- Enemy HP: `30 * (1.10 ^ (wave - 1))` (10% increase per wave)
- Enemy Speed: `150 * (1.03 ^ (wave - 1))` (3% increase per wave)

### Arena
| Property | Value |
|----------|-------|
| Size | 1920 x 1080 units |
| Camera | Fixed (no movement) |
| Spawn Zones | 4 fixed zones (one per edge, centered) |
| Spawn Zone Size | 200 units wide |
| Player Start | Center (960, 540) |

### Timing
| Event | Duration |
|-------|----------|
| Wave Announcement | 1.5 seconds |
| Turret Spawn Animation | 0.5 seconds |
| Between-Wave Pause | 2 seconds total |
| Enemy Spawn Interval | Wave duration / enemy count |

---

## Feature Specifications

### 1. Player Character

**Movement:**
- WASD / Arrow keys / Left analog stick
- 8-directional movement, normalized diagonal
- No acceleration/deceleration (instant response)
- Constrained to arena bounds

**Combat:**
- Auto-fire weapon (always active when enemies exist)
- Targets nearest enemy within range
- Cannot manually aim (single-stick friendly)

**Health System:**
- Health bar displayed in HUD
- Takes contact damage from enemies
- Invincibility frames prevent damage stacking
- Health persists across waves (no healing between waves in MVP)

### 2. Turret System

**Spawning:**
- One new turret spawns at the START of each wave
- Random position within arena bounds
- Minimum 100 units from other turrets
- Minimum 150 units from player position
- Visual spawn effect (particle burst or grow animation)
- By wave 10: maximum 10 turrets active

**Behavior:**
- Auto-targets nearest enemy within range
- Rotates smoothly toward target
- Fires when target is within aim tolerance (±10°)
- Instant retarget when enemy dies or leaves range
- Shows range indicator on hover (optional polish)

### 3. Enemy System

**Behavior:**
- Spawns from fixed zones on arena edges
- Moves directly toward player (simple chase AI)
- Deals damage on contact with player
- Dies when HP reaches 0
- Drops XP orb on death

**Spawning:**
- Continuous spawning throughout wave
- Spawn interval = wave duration / enemy count
- Spawns distributed across all 4 spawn zones (round-robin or random)

### 4. XP/Drop System

**XP Orbs:**
- Spawn at enemy death location
- Visual only (no gameplay effect in MVP)
- Auto-collected when player is within pickup radius
- Satisfying pickup sound/visual
- Counter displayed in HUD (for future use)

### 5. Wave System

**Flow:**
1. **Wave Start:**
   - Display "Wave X" announcement (1.5 sec)
   - Spawn new turret with visual effect
   - Begin enemy spawning

2. **During Wave:**
   - Enemies spawn at calculated intervals
   - Timer counts down (optional: show in HUD)
   - Combat continues

3. **Wave End:**
   - All remaining enemies continue (don't despawn)
   - Brief pause (2 sec)
   - If wave < 10: proceed to next wave
   - If wave = 10: victory

### 6. Win/Lose Conditions

**Victory:**
- Survive all 10 waves (timer expires on wave 10)
- Display victory screen with stats:
  - Total enemies killed
  - Total XP collected
  - Time survived
  - Turrets spawned

**Defeat:**
- Player health reaches 0
- Display game over screen with same stats
- "Restart" button

### 7. HUD Elements

**Always Visible:**
- Player health bar (top-left)
- Wave number (top-center)
- Wave timer (top-center, below wave number)
- XP counter (top-right)
- Turret count (top-right)

**Layout:**
```
[Health Bar]                    [Wave 3]                    [XP: 1250]
                                [0:45]                      [Turrets: 3]
```

---

## Technical Requirements

### Input Support
- Keyboard (WASD + Arrow keys)
- Gamepad (Left stick movement, auto-aim)
- Both simultaneously supported

### Performance Targets
- 60 FPS stable
- Support up to 50 enemies + 10 turrets + 100 projectiles

### Scene Structure
```
Main (Node2D)
├── Arena (background, bounds)
├── TurretContainer (dynamic turret spawning)
├── EnemyContainer (dynamic enemy spawning)
├── Player (CharacterBody2D)
├── DropContainer (XP orbs)
├── GameManager (wave logic, state)
├── EnemySpawner (spawn timing/positioning)
└── UILayer (CanvasLayer)
    ├── HUD
    ├── WaveAnnouncement
    ├── GameOver
    └── Victory
```

---

## Visual/Audio Feedback

### Must Have (MVP)
- [x] Turret spawn effect (particles or scale animation)
- [x] Enemy death effect (small particles)
- [x] XP orb pickup effect
- [x] Player damage flash (red tint + screen shake)
- [x] Projectile visuals (small colored shapes)
- [x] Health bar with smooth transitions

### Nice to Have (If Time Permits)
- [ ] Floating damage numbers
- [ ] Muzzle flash on turret/player fire
- [ ] Enemy spawn warning indicators
- [ ] Wave complete celebration effect

### Audio (Placeholder OK)
- Turret firing
- Player firing
- Enemy death
- Player damage
- XP pickup
- Wave start jingle
- Victory/defeat stinger

---

## Implementation Priority

### Phase 1: Core Movement & Combat
1. Player movement (keyboard + gamepad)
2. Arena bounds and collision
3. Basic enemy (spawns, chases, damages player)
4. Player health system with HUD

### Phase 2: Turret System
5. Single turret type with targeting
6. Turret spawning (random position with constraints)
7. Projectile system (player + turret)

### Phase 3: Wave System
8. Wave manager (timing, enemy count scaling)
9. Enemy spawner (fixed zones, intervals)
10. Wave announcements and transitions

### Phase 4: Polish & Win State
11. XP drops (visual only)
12. Win/lose screens
13. Visual effects and feedback
14. Audio implementation

---

## Open Questions (Resolve During Development)

1. **Enemy pathfinding:** Simple direct chase, or basic obstacle avoidance?
   - *Recommendation: Direct chase for MVP (no obstacles)*

2. **Turret projectile collision:** Pass through enemies (pierce) or stop on hit?
   - *Recommendation: Stop on hit (single target)*

3. **Player projectile collision:** Same question
   - *Recommendation: Stop on hit (single target)*

4. **XP orb lifetime:** Persist forever or despawn after time?
   - *Recommendation: Persist forever (clean up between waves if needed)*

---

## Success Criteria

The MVP is successful when:
1. ✅ Movement feels responsive on both keyboard and controller
2. ✅ Taking damage has clear visual/audio feedback
3. ✅ Difficulty scaling feels appropriate across 10 waves
4. ✅ Random turret spawning creates interesting emergent scenarios
5. ✅ Core loop is engaging enough to warrant adding strategic systems
6. ✅ Player can survive ~3 hits per wave with good dodging
7. ✅ Game is completable (wave 10 victory is achievable)

---

## Changelog

| Date | Changes |
|------|---------|
| 2025-11-25 | Initial MVP spec created, consolidated from design docs |
