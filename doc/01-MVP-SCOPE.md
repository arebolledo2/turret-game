# MVP/Prototype Scope - Simplified

> ⚠️ **NOTE:** This document has been superseded by `00-MVP-IMPLEMENTATION-SPEC.md`  
> which contains all concrete values and implementation details.  
> This file is kept for historical reference.

## Overview
A minimalist wave-based survival game focused on discovering the core "feel" of turret-based combat. The player dodges enemies while turrets spawn randomly and provide damage output.

## Core Gameplay Loop
- Wave starts → new turret spawns randomly in arena
- Enemies spawn continuously throughout the wave
- Player dodges and deals weak auto-fire damage
- Turrets auto-target and damage nearest enemies
- Enemies drop XP orbs (visual only)
- Wave ends when enemy quota is defeated
- Repeat until wave 10 (win) or player death (lose)

## MVP Feature Checklist

### Must Have
- [ ] Player character with movement (keyboard + left stick)
- [ ] Player weak auto-fire weapon (auto-targets nearest)
- [ ] **Single turret type** with auto-targeting (nearest enemy)
- [ ] **Random turret placement** - 1 new turret at wave start
- [ ] Wave-based enemy spawning (continuous within wave)
- [ ] Single basic enemy type
- [ ] Enemy count increases each wave (difficulty scaling)
- [ ] XP drop on enemy death (visual feedback only)
- [ ] Fixed arena map
- [ ] Win condition: Survive 10 waves
- [ ] Lose condition: Player death
- [ ] Basic HUD (wave number, health, turret count)
- [ ] **Full controller support** (single-stick + auto-aim)


### Explicitly Deferred (Post-MVP)
- Multiple turret types
- Manual turret placement/positioning
- Shop system and economy (gold/purchasing)
- XP/leveling systems
- Turret upgrades/leveling
- Multiple enemy types with different behaviors
- Turret moving/selling/refunding
- Meta progression between runs
- Permanent unlocks/achievements
- Minimap or fog of war
- Boss waves
- Special abilities/active items

## Design Philosophy
**Goal: Feel First, Features Later**

This ultra-minimal MVP removes all strategic complexity to focus purely on:
1. Movement and dodging feel
2. Visual feedback and game pace
3. Turret combat satisfaction
4. Controller responsiveness

Strategic depth (placement, economy, upgrades) will be added once the core feel is validated.

## Implementation Decisions

| Question | Decision |
|----------|----------|
| **Turret Placement Timing** | Automatic at the beginning of each round |
| **Turret Spawn Location** | Completely random in arena |
| **Turret Count Cap** | One new turret per round (10 turrets max by wave 10) |
| **Player Weapon** | Weak auto-fire (auto-targets nearest enemy) |
| **Win Condition** | Survive 10 waves |
| **Enemy Difficulty Scaling** | More enemies per wave |
| **Collectibles** | XP drops for visual feedback only (no gameplay effect) |
| **Controller Layout** | Left stick move + auto-targeting (single-stick) |
| **Turret Targeting** | Nearest enemy |
| **Wave Pacing** | Continuous spawning (no prep phase) |

### Summary
- **Controls**: Single-stick movement, auto-aim for both player and turrets
- **Progression**: 10 waves, 1 turret added per wave = up to 10 turrets by final wave
- **Combat**: Player has weak auto-fire; turrets do the heavy lifting
- **Pacing**: Continuous action, no downtime between waves


## Success Criteria
The MVP is successful when:
1. Movement feels responsive on both keyboard and controller
2. Combat has satisfying visual/audio feedback
3. Difficulty scaling feels appropriate across waves
4. Random turret spawning creates interesting emergent scenarios
5. Core loop is engaging enough to warrant adding strategic systems

## Technical Constraints
- **Engine:** Godot 4.x
- **Perspective:** Top-down 2D
- **Target:** PC (keyboard + mouse + gamepad)
- **Dev Time:** Prototype should be achievable in 2-4 days

## Next Steps
1. **Answer the 10 implementation questions above**
2. Implement basic player movement (keyboard + controller)
3. Implement single turret type with random spawning
4. Implement basic enemy and wave spawning
5. Test and iterate on game feel
6. Add strategic systems only after feel is validated
