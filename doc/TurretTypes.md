# Turret Types Design Document

> Design specification for the expanded turret system with tags, damage types, and modifier support.

---

## Overview

The turret system uses a **dual-tag architecture** separating **attack style** (how damage is delivered) from **damage type** (elemental/physical classification). This enables flexible item modifiers that can target specific mechanics or damage types independently.

---

## Tag System

### Attack Style Tags
How the turret delivers damage to enemies.

| Tag | Description |
|-----|-------------|
| `projectile` | Fires a visible projectile that travels to target |
| `instant` | Damage applied immediately (hitscan/beam) |
| `aoe` | Damages multiple enemies in an area |
| `chain` | Damage jumps between multiple enemies |

### Damage Type Tags
The elemental or physical classification of damage.

| Tag | Description |
|-----|-------------|
| `physical` | Standard kinetic damage, no special effects |
| `fire` | Burns enemies, innate DoT capability |
| `electric` | Shock damage, pairs well with chain mechanics |
| `plasma` | High-energy damage, combines heat and energy |

### Tag Combinations
Turrets can have **multiple tags from each category**. Examples:
- Normal Turret: `[projectile]` + `[physical]`
- Tesla Turret: `[instant, chain]` + `[electric]`
- Plasma Turret: `[projectile, aoe]` + `[plasma]`

---

## Turret Definitions

### Normal Turret
> Standard auto-targeting turret. Reliable and consistent.

| Property | Value |
|----------|-------|
| **Attack Style** | `projectile` |
| **Damage Type** | `physical` |
| **Targeting** | Nearest enemy in range |
| **Base Damage** | 15 |
| **Fire Rate** | 2.0/sec |
| **Range** | 400 |
| **Projectile Speed** | 500 |
| **Pierce** | 0 |
| **DoT** | None (can be added by items) |

---

### Sniper Turret
> Long-range instant-hit turret. High damage, slow fire rate.

| Property | Value |
|----------|-------|
| **Attack Style** | `instant` |
| **Damage Type** | `physical` |
| **Targeting** | Farthest enemy in range (prioritizes back-line) |
| **Base Damage** | 45 |
| **Fire Rate** | 0.5/sec |
| **Range** | 800 |
| **Projectile Speed** | N/A (instant) |
| **DoT** | None |

**Special Behavior:** Visual laser/tracer effect on hit for feedback.

---

### Fire Turret
> Incendiary turret that ignites enemies.

| Property | Value |
|----------|-------|
| **Attack Style** | `projectile` |
| **Damage Type** | `fire` |
| **Targeting** | Nearest enemy in range |
| **Base Damage** | 8 |
| **Fire Rate** | 2.5/sec |
| **Range** | 350 |
| **Projectile Speed** | 400 |
| **Pierce** | 99 (effectively infinite) |
| **DoT** | Burn: 4 damage/sec for 3 sec |

**Special Behavior:** Applies "Burning" status effect on hit. Projectiles pass through enemies, igniting all in their path.

---

### Plasma Turret
> Fires explosive plasma orbs that damage an area.

| Property | Value |
|----------|-------|
| **Attack Style** | `projectile`, `aoe` |
| **Damage Type** | `plasma` |
| **Targeting** | Enemy cluster (prefers groups) |
| **Base Damage** | 20 |
| **Fire Rate** | 1.0/sec |
| **Range** | 450 |
| **Projectile Speed** | 350 |
| **Pierce** | 0 (explodes on first enemy) |
| **AoE Radius** | 80 |
| **DoT** | None |

**Special Behavior:** Projectile explodes on impact, damaging all enemies in radius. AoE only damages enemies (no friendly fire).

---

### Shock Turret
> Pulses electric damage around itself.

| Property | Value |
|----------|-------|
| **Attack Style** | `aoe` |
| **Damage Type** | `electric` |
| **Targeting** | All enemies within pulse radius |
| **Base Damage** | 12 |
| **Fire Rate** | 1.5/sec (pulse interval) |
| **Range** | 200 (pulse radius) |
| **Projectile Speed** | N/A |
| **DoT** | None |

**Special Behavior:** Damages all enemies in range simultaneously on each pulse. No projectile—visual electric field effect.

---

### Tesla Turret
> Fires chain lightning that jumps between enemies.

| Property | Value |
|----------|-------|
| **Attack Style** | `instant`, `chain` |
| **Damage Type** | `electric` |
| **Targeting** | Nearest enemy in range |
| **Chain Target** | Closest enemy to last-hit enemy |
| **Base Damage** | 18 |
| **Fire Rate** | 1.2/sec |
| **Range** | 350 |
| **Chain Count** | 3 |
| **Chain Range** | 150 (max distance between chain targets) |
| **Chain Decay** | 0.7 (each jump deals 70% of previous) |
| **DoT** | None |

**Special Behavior:** Lightning visually arcs between chained enemies. Cannot chain to the same enemy twice per shot.

---

## Stat Definitions

### Core Stats (All Turrets)
| Stat | Description |
|------|-------------|
| `damage` | Base damage per hit/pulse |
| `fire_rate` | Attacks per second |
| `range` | Maximum targeting/effect range |
| `rotation_speed` | Turret rotation speed (degrees/sec) |

### Projectile Stats
| Stat | Description |
|------|-------------|
| `projectile_speed` | Travel speed of projectiles |
| `pierce` | Number of enemies projectile can hit before expiring (0 = single target) |

### AoE Stats
| Stat | Description |
|------|-------------|
| `aoe_radius` | Radius of area damage effect |

### Chain Stats
| Stat | Description |
|------|-------------|
| `chain_count` | Maximum number of chain jumps |
| `chain_range` | Maximum distance for chain to jump |
| `chain_decay` | Damage multiplier per chain (e.g., 0.7 = 30% reduction) |

### DoT Stats
| Stat | Description |
|------|-------------|
| `dot_damage` | Damage per tick |
| `dot_duration` | Total duration in seconds |
| `dot_tick_rate` | Ticks per second (default: 1.0) |

---

## Status Effect System

Status effects are applied to **enemies** and tracked on the enemy node. This allows:
- Stacking from multiple sources
- Refreshing duration on reapplication
- Visual indicators on affected enemies
- Future interactions (e.g., "deal +50% damage to burning enemies")

### DoT Stacking Rules
Each damage type tracks its **strongest** DoT effect per enemy:
- When a new DoT of the same damage type is applied, compare `dot_damage`
- If new DoT is stronger, replace the existing effect and refresh duration
- If new DoT is weaker or equal, only refresh duration (keep stronger damage)
- Different damage types stack independently (fire + electric both tick)

### Burning (Fire)
- Deals `dot_damage` per tick for `dot_duration`
- Visual: Orange/red tint, particle flames
- Stacking: Per damage type rules above (strongest fire DoT wins, duration refreshes)

### Shocked (Electric) — Future
- Could slow enemy movement
- Visual: Blue sparks, jitter animation

### Other Status Effects — Future
- Frozen, Poisoned, Marked, Weakened, etc.

---

## Modifier System

Modifiers are bonuses from items that affect turret stats based on tags. Stored as a list in `Globals` and calculated at runtime.

### Modifier Structure
```
{
    "id": "fire_damage_1",
    "stat": "damage",           # Which stat to modify
    "operation": "multiply",    # "add" or "multiply"
    "value": 1.2,               # +20% as multiplier
    "filter": {
        "damage_type": ["fire"] # Only affects turrets with fire tag
    }
}
```

### Filter Options
| Filter Key | Description |
|------------|-------------|
| `damage_type` | Array of damage type tags (OR logic) |
| `attack_style` | Array of attack style tags (OR logic) |
| `turret_type` | Array of specific turret type IDs |

### Example Modifiers

**"+20% Fire Damage"**
```
filter: { damage_type: ["fire"] }
stat: "damage"
operation: "multiply"
value: 1.2
```

**"+15% Projectile Damage"**
```
filter: { attack_style: ["projectile"] }
stat: "damage"
operation: "multiply"
value: 1.15
```

**"+1 Chain Count"**
```
filter: { attack_style: ["chain"] }
stat: "chain_count"
operation: "add"
value: 1
```

**"+2 Pierce to Projectiles"**
```
filter: { attack_style: ["projectile"] }
stat: "pierce"
operation: "add"
value: 2
```

**"+50 Range to Sniper Turret"**
```
filter: { turret_type: ["sniper"] }
stat: "range"
operation: "add"
value: 50
```

**"All Turrets gain Burn DoT"** (Advanced)
```
filter: {}  # All turrets
stat: "dot_damage"
operation: "add"
value: 2
# Also needs dot_duration if not present
```

### Modifier Calculation Order
1. Start with base stat value
2. Apply all `add` operations (sum)
3. Apply all `multiply` operations (product)

This ensures predictable stacking: +10 and +20 damage = +30, then ×1.2 and ×1.1 = ×1.32.

---

## Shop Integration (Future)

During the shop phase between waves:
1. Player sees available turret types (unlocked)
2. Player purchases turrets with currency (XP or gold)
3. Purchased turrets are added to spawn pool
4. On wave start, purchased turrets spawn at random valid locations

### Spawn Pool
- `pending_turrets: Array[String]` — turret type IDs to spawn
- Each wave start, spawn all pending turrets at random positions
- Validate positions (min distance from other turrets, not on player)

---

## Extensibility Notes

### Adding a New Turret Type
1. Add entry to `TURRET_TYPES` dictionary in `globals.gd`
2. Define `attack_style` and `damage_type` tag arrays
3. Define base stats (only include relevant stats for the attack style)
4. Create scene if unique visuals needed (or reuse base with color/sprite swap)
5. Implement any special behavior in turret script (check turret type)

### Adding a New Tag
1. Add to the appropriate tag category in this document
2. Update item/modifier generation to include new tag
3. Turrets with new tag automatically benefit from matching modifiers

### Adding a New Stat
1. Add to stat definitions in this document
2. Add default value to turret base stats (or 0/null if optional)
3. Update `get_turret_stats()` to apply modifiers to new stat
4. Turret script reads and uses the new stat

---

## Visual Design

### Implementation Approach
**Phase 1 (Current):** Color tint differentiation using `modulate` on existing sprites.
**Phase 2 (Future):** Unique sprite assets per turret type.

### Color Tints (Phase 1)
| Turret | Modulate Color | Hex |
|--------|----------------|-----|
| Normal | Green | `#66CC66` |
| Sniper | Dark Blue | `#4466AA` |
| Fire | Orange | `#FF6633` |
| Plasma | Purple | `#AA44DD` |
| Shock | Yellow | `#DDDD44` |
| Tesla | Cyan | `#44DDDD` |

### Future Unique Assets (Phase 2)
| Turret | Color Palette | Projectile Style |
|--------|---------------|------------------|
| Normal | Green/Gray | Simple bullet |
| Sniper | Dark Blue/Black | Laser trace |
| Fire | Orange/Red | Fireball with trail |
| Plasma | Purple/Pink | Glowing orb, explosion |
| Shock | Yellow/Blue | Electric field pulse |
| Tesla | Cyan/White | Lightning arc |

---

## Summary

The tag-based system provides:
- **Flexibility**: Items can target broad categories or specific turrets
- **Extensibility**: New turrets/tags/stats slot into existing framework
- **Clarity**: Separation of attack style and damage type makes effects predictable
- **Scalability**: Modifier system handles simple and complex bonuses uniformly
