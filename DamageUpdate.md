# Difficulty Balance Tweak Plan

## Goals
- Make early rounds (Wave 1) more accessible without making them trivial
- Keep late-game challenging through enemy scaling
- Enhance player agency with stronger turrets and melee attacks
- Improve early progression feel without breaking game flow

---

## Changes Overview

### 1. Normal (Basic) Turret - Fire Rate Reduction + One-Shot Wave 1

**Rationale:**  
Wave 1 basic enemy (Spider Drone) has 30 HP base. On Hard difficulty:
- Hard multiplier: 30 × 1.5 = **45 HP**
- Current normal turret: 18 damage @ 2.0 fire rate = needs 2.5 shots (too slow to one-shot)
- Target: One-shot capability while reducing spam

**Changes:**
- `damage`: 18.0 → **50.0** (+177% damage)
- `fire_rate`: 2.0 → **1.2** (slower, more impactful shots)
- `range`: 180.0 → **160.0** (slight reduction, more tactical placement)

**Justification:**
- 50 damage one-shots 45 HP hard-mode Wave 1 enemies
- Lower fire rate reduces visual/audio spam, makes strategy more deliberate
- Range reduction balances the damage increase

---

### 2. Sniper Turret - Damage Buff + No Range Reduction

**Changes:**
- `damage`: 45.0 → **70.0** (+55% damage)
- `range`: 500.0 → **500.0** (keep unchanged - it's the long-range specialist)
- `fire_rate`: 0.5 (unchanged, already balanced)

**Justification:**
- Still slow-firing, high-damage specialist
- Maintains long-range role without reduction
- Damage buff keeps late-game relevance

---

### 3. Fire Turret - Damage & DoT Buff + Range Reduction

**Changes:**
- `damage`: 10.0 → **18.0** (+80% base damage)
- `dot_damage`: 4.0 → **8.0** (+100% DoT)
- `fire_rate`: 2.5 → **2.0** (slightly slower)
- `range`: 160.0 → **140.0** (range reduction)
- `dot_duration`: 3.0 (unchanged)

**Justification:**
- Base projectile hits harder, DoT becomes serious threat
- Slightly lower fire rate compensates for damage increase
- Range reduction keeps placement meaningful

---

### 4. Plasma Turret - Damage & Area Buff + Range Reduction

**Changes:**
- `damage`: 25.0 → **40.0** (+60% damage)
- `aoe_radius`: 80.0 → **100.0** (+25% radius)
- `fire_rate`: 1.0 (unchanged)
- `range`: 200.0 → **170.0** (range reduction)
- `knockback_force`: 120.0 (unchanged)

**Justification:**
- Stronger area control with increased damage and radius
- Range reduction encourages closer, riskier positioning
- Higher damage per shot makes it more cost-effective

---

### 5. Shock Turret - Damage Buff + Range Reduction

**Changes:**
- `damage`: 15.0 → **25.0** (+67% damage)
- `fire_rate`: 1.5 (unchanged)
- `range`: 120.0 → **100.0** (range reduction)
- `slow_intensity`: 0.25 (unchanged)
- `slow_duration`: 0.5 (unchanged)

**Justification:**
- Utility turret needed stronger punch
- Range reduction matches new positioning requirement
- Slowing utility remains powerful for crowd control

---

### 6. Tesla Turret - Damage & Chain Buff + Range Reduction

**Changes:**
- `damage`: 22.0 → **38.0** (+73% damage)
- `chain_count`: 3 (unchanged)
- `chain_range`: 120.0 → **150.0** (+25% chain reach)
- `fire_rate`: 1.2 (unchanged)
- `range`: 170.0 → **150.0** (range reduction)

**Justification:**
- Higher damage makes chain lightning punish clusters more effectively
- Increased chain range compensates for reduced primary range
- Maintains its cluster-control specialty

---

### 7. Player Melee Damage Increase

**Current:** `melee_damage: 20.0` (exported in player.gd)

**Change:**
- `melee_damage`: 20.0 → **35.0** (+75% damage)
- `melee_range`: 65.0 (unchanged)
- `melee_cooldown`: 0.7 (unchanged)

**Justification:**
- Risky, short-range attack should reward player skill
- Encourages active player engagement in combat
- Makes melee viable for crowd control in waves

---

## Range Reduction Summary

| Turret | Old Range | New Range | Reduction |
|--------|-----------|-----------|-----------|
| Normal | 180 | 160 | -20 (-11%) |
| Fire | 160 | 140 | -20 (-13%) |
| Plasma | 200 | 170 | -30 (-15%) |
| Shock | 120 | 100 | -20 (-17%) |
| Tesla | 170 | 150 | -20 (-12%) |
| Sniper | 500 | **500** | No change |

---

## Expected Impact

### Wave 1 (Easy Early Game)
- ✅ Basic turrets one-shot basic enemies on Hard
- ✅ Player feels powerful with higher melee damage
- ✅ Reduced turret range keeps placement strategy relevant
- ✅ Lower fire rate on normal turret feels more impactful

### Waves 5-10 (Late Game)
- ✅ Enemy scaling (1.12-1.15× per wave) still outpaces initial player strength
- ✅ Damage increases help but don't trivialize late-game
- ✅ Sniper maintains long-range advantage without nerf
- ✅ Player can build more strategic turret compositions

### Overall Flow
- ✅ Smoother early progression
- ✅ Closer tactical gameplay (ranges reduced)
- ✅ Higher impact per shot (damage increases)
- ✅ Late-game remains challenging with enemy scaling

---

## Tuning Levers for Future Balance

If needed, adjust:
1. **Early-game difficulty**: Tweak Wave 1 enemy counts or base health
2. **Late-game scaling**: Adjust `enemy_hp_scale_per_wave` multipliers in DIFFICULTY_CONFIG
3. **Specific turrets**: Individual damage/fire_rate tweaks without altering others
4. **Enemy variety**: Introduce harder enemy types starting at Wave 4-5
5. **Player progression**: Consider damage/health bonuses from items found in tech drops

---

## Files to Modify

1. **scripts/data/game_constants.gd** → Turret stats (TURRET_BASE_DAMAGE → check turret-specific constants if they exist)
2. **scripts/registries/turret_registry.gd** → TurretRegistry.TYPES dict for all turret definitions
3. **scripts/player.gd** → `melee_damage` exported variable (line ~35)

---

## Testing Checklist

- [ ] Wave 1 Hard: Normal turret one-shots basic enemies
- [ ] Wave 1 Easy/Medium: Verify not overpowered
- [ ] Wave 5+: Confirm enemies still escalate and challenge player
- [ ] Melee attacks feel impactful, not game-breaking
- [ ] Shop pricing still makes sense (may need price adjustments if damage inflation is too high)
- [ ] Chain/Tesla turret chains still work with new range values

