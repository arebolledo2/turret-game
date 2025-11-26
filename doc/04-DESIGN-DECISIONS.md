# Design Decisions & Open Questions

> 📋 **POST-MVP VISION DOCUMENT**  
> These decisions apply to the full game vision. MVP decisions are finalized in `00-MVP-IMPLEMENTATION-SPEC.md`

This document tracks key design decisions that need to be made before implementation can proceed. Answer these questions to finalize the design.

## Critical Decisions (Block Development)

### 1. Player Attack Pattern
**Decision needed for:** Player combat implementation

**Options:**
- **A) Auto-fire:** Player always shoots at nearest enemy automatically
  - Pros: Simple, less input complexity, can focus on dodging
  - Cons: Less player agency, can't choose targets
  
- **B) Manual aim:** Click/hold to shoot toward mouse cursor
  - Pros: More skill expression, can target priority enemies
  - Cons: More complex, might distract from dodging

**Recommendation:** Option A (auto-fire) for MVP. Can add manual aim as post-MVP option/upgrade.

**Your decision:** _______________

---

### 2. Turret Placement System
**Decision needed for:** Turret manager and shop implementation

**Options:**
- **A) Grid-based:** Turrets snap to grid cells
  - Pros: Cleaner visuals, easier validation, more puzzle-like
  - Cons: Less flexibility, might feel restrictive
  - Grid size suggestion: 64x64 or 96x96 pixels
  
- **B) Free-form:** Place turrets anywhere with minimum distance check
  - Pros: Maximum flexibility, more strategic depth
  - Cons: Can look messy, harder to balance coverage

**Recommendation:** Option A (grid-based) for MVP. Cleaner and easier to implement.

**Your decision:** _______________

---

### 3. Turret Selection (Pick 3-4)
**Decision needed for:** Turret implementation priority

**Available archetypes:**
1. Basic Gun (medium damage, medium fire rate, single target)
2. Cannon (high damage, slow fire rate, single target)
3. Rapid-Fire (low damage, fast fire rate, single target)
4. Flamethrower (medium damage, continuous, AoE)
5. Sniper (very high damage, very slow, long range)

**Recommendation for MVP:** 
- Basic Gun (starting option)
- Rapid-Fire (horde clear)
- Cannon (boss killer)
- (Optional 4th: Flamethrower for AoE variety)

**Your selection (list 3-4):**
1. _______________
2. _______________
3. _______________
4. _______________ (optional)

---

### 4. Enemy Spawn Pattern
**Decision needed for:** Enemy spawner implementation

**Options:**
- **A) Random edge spawning:** Enemies spawn at random points along arena edges
  - Pros: Unpredictable, tests player adaptability
  - Cons: Can feel chaotic, harder to strategize turret placement
  
- **B) Fixed spawn zones:** 2-4 designated spawn areas
  - Pros: Strategic turret placement, more tower-defense feel
  - Cons: Can become repetitive, optimal strategies emerge quickly

**Recommendation:** Option B (fixed spawn zones) for MVP. Better for turret-focused gameplay.

**Your decision:** _______________

If Option B, how many spawn zones? _______________ (suggest 3-4)

---

## Important Decisions (Impact Balance/Feel)

### 5. Starting Wave Difficulty
**Decision needed for:** Wave configuration and balancing

**Wave 1 enemy count:** _______________ (suggest 15-25)

**Wave 1 enemy HP:** _______________ (suggest 40-60)

**Gold earned from Wave 1:** _______________ (suggest 150-200)

---

### 6. Win Condition
**Decision needed for:** Game flow and testing

**Number of waves to survive for victory:** _______________ (suggest 10-15)

Reasoning: 10 waves = ~20 minutes, 15 waves = ~30 minutes (assuming ~2 min per wave cycle)

---

### 7. Player Starting Stats
**Decision needed for:** Player balance

**Max health:** _______________ (suggest 100)

**Movement speed:** _______________ (suggest 300 units/sec)

**Weapon damage:** _______________ (suggest 5-10)

**Weapon fire rate:** _______________ (suggest 2-3 shots/sec)

**Starting gold:** _______________ (suggest 100-150)

---

### 8. Arena Size
**Decision needed for:** Arena scene setup

**Dimensions:** _______________x_______________ pixels

**Recommendation:** 1920x1080 (fills standard screen) or 2400x1350 (slightly larger for camera movement)

---

## Minor Decisions (Can Iterate During Development)

### 9. Visual Style
**Options:**
- Minimal/geometric (Brotato style)
- Pixel art
- Hand-drawn
- 3D rendered sprites

**Your preference:** _______________

---

### 10. Projectile Type
**For basic gun turret:**
- **A) Instant hitscan:** No travel time, instant damage
- **B) Projectile:** Visible bullet/projectile with travel speed

**Recommendation:** Option B (projectiles) for better visual feedback

**Your decision:** _______________

---

### 11. Damage Numbers
**Show floating damage numbers when enemies take damage?**

**Your preference:** [ ] Yes  [ ] No  [ ] Decide later

---

### 12. Camera Behavior
**Options:**
- **A) Fixed camera:** Centered on arena, no movement
- **B) Follow player:** Camera smoothly follows player position
- **C) Hybrid:** Slight camera follow with bounds

**Recommendation:** Option B or C depending on arena size

**Your decision:** _______________

---

## Post-MVP Features to Consider

These are explicitly NOT in MVP but good to think about for future iterations:

### Turret Upgrades
- Upgrade existing turrets for gold (increase damage, range, fire rate)
- Tiered upgrade system (turret level 1-3)
- Visual changes when upgraded

### Enemy Variety
- Fast/weak enemies
- Slow/tanky enemies
- Flying enemies (require specific turret types)
- Enemies that split on death
- Boss enemies every 5 waves

### Meta Progression
- Permanent unlocks between runs
- New turret types
- Starting bonuses
- Character selection

### Advanced Turret Features
- Turret synergies (buffs from adjacent turrets)
- Elemental damage types
- Status effects (slow, burn, stun)
- Active abilities (manual trigger)

### Player Progression
- Leveling system (use collected XP)
- Stat increases per level
- Talent tree or skill selection
- Equipment/items

### Quality of Life
- Turret selling/refunding
- Turret repositioning
- Speed up wave button
- Save/load system
- Leaderboard/scoring

---

## Decision Summary Template

Once all decisions are made, fill this out for quick reference:

```
=== FINAL DESIGN DECISIONS ===

Player Attack: [Auto-fire / Manual aim]
Turret Placement: [Grid-based / Free-form]
Selected Turrets: [List 3-4]
Spawn Pattern: [Random edges / Fixed zones]
Spawn Zone Count: [Number]
Wave Count: [Number]
Wave 1 Enemies: [Number]
Arena Size: [Dimensions]
Camera: [Fixed / Follow / Hybrid]
Projectile Type: [Instant / Projectile]

Starting Stats:
- Health: [Number]
- Speed: [Number]
- Damage: [Number]
- Fire Rate: [Number]
- Gold: [Number]
```

---

## Notes Space

Use this space to capture additional thoughts, constraints, or ideas during planning:

```
[Your notes here]
```
