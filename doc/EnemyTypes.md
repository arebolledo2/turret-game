# Enemy Types Design Document

> Design specification for the enemy type system with behaviors, stats, and visual customization.

---

## Overview

The enemy system uses a **type-based architecture** similar to the turret system. Each enemy type has distinct stats, behaviors, and visual appearance. Enemy types are unlocked progressively as waves advance, with weighted random selection determining spawn distribution.

---

## Behavior Tags

How the enemy moves, attacks, or dies.

| Tag | Description |
|-----|-------------|
| `CHASE` | Pursues the player directly |
| `RANGED` | Keeps distance and fires projectiles (future) |
| `SWARM` | Spawns in groups, weaker individually |
| `TANK` | High health, slow movement, high damage |
| `EXPLOSIVE` | Explodes on death, damaging nearby entities |

### Behavior Combinations
Enemies can have **multiple behaviors**. Examples:
- Basic Robot: `[CHASE]`
- Scout Bot: `[CHASE, SWARM]`
- Boom Bot: `[CHASE, EXPLOSIVE]`

---

## Enemy Definitions

### Basic Robot (basic)
> Standard enemy that chases the player. The workhorse of enemy waves.

| Property | Value |
|----------|-------|
| **Behaviors** | `CHASE` |
| **Base Health** | 30 |
| **Base Speed** | 150 |
| **Contact Damage** | 33 |
| **XP Value** | 10 |
| **Scale** | 1.0 |
| **Spawn Weight** | 100 |
| **Min Wave** | 1 |

---

### Scout Bot (fast)
> Quick but fragile enemy. Appears early and often.

| Property | Value |
|----------|-------|
| **Behaviors** | `CHASE`, `SWARM` |
| **Base Health** | 15 |
| **Base Speed** | 250 |
| **Contact Damage** | 20 |
| **XP Value** | 8 |
| **Scale** | 0.8 |
| **Color Tint** | Light Blue |
| **Spawn Weight** | 60 |
| **Min Wave** | 2 |

**Special Behavior:** Faster than basic enemies but dies quickly. Good for testing player reflexes.

---

### Heavy Bot (tank)
> Slow but very tough enemy. A mid-game threat.

| Property | Value |
|----------|-------|
| **Behaviors** | `CHASE`, `TANK` |
| **Base Health** | 120 |
| **Base Speed** | 80 |
| **Contact Damage** | 50 |
| **XP Value** | 25 |
| **Scale** | 1.4 |
| **Color Tint** | Brown/Rust |
| **Spawn Weight** | 20 |
| **Min Wave** | 3 |

**Special Behavior:** High health requires focused turret fire. Slow movement gives player time to reposition.

---

### Boom Bot (exploder)
> Explodes on death, damaging nearby enemies and player.

| Property | Value |
|----------|-------|
| **Behaviors** | `CHASE`, `EXPLOSIVE` |
| **Base Health** | 20 |
| **Base Speed** | 180 |
| **Contact Damage** | 25 |
| **XP Value** | 15 |
| **Scale** | 0.9 |
| **Color Tint** | Orange/Red |
| **Explosion Radius** | 100 |
| **Explosion Damage** | 40 |
| **Spawn Weight** | 25 |
| **Min Wave** | 4 |

**Special Behavior:** 
- Explodes on death (any death: player contact, turret damage, chain reaction)
- Damages player if within explosion radius
- Damages other enemies at 50% effectiveness (can cause chain reactions!)

---

### Mini Bot (swarm)
> Tiny but spawns in groups of 3.

| Property | Value |
|----------|-------|
| **Behaviors** | `CHASE`, `SWARM` |
| **Base Health** | 8 |
| **Base Speed** | 200 |
| **Contact Damage** | 10 |
| **XP Value** | 3 |
| **Scale** | 0.5 |
| **Color Tint** | Light Green |
| **Spawn Weight** | 40 |
| **Min Wave** | 2 |
| **Spawn Count** | 3 |

**Special Behavior:** Each "spawn" produces 3 mini bots at once. Low individual threat but can overwhelm in numbers.

---

## Wave Progression

Enemy types unlock as waves progress:

| Wave | Available Enemy Types |
|------|----------------------|
| 1 | Basic |
| 2 | Basic, Fast, Swarm |
| 3 | Basic, Fast, Swarm, Tank |
| 4+ | All types |

### Spawn Weight System

Each enemy type has a `spawn_weight` that determines relative spawn probability:

```
Spawn Chance = enemy_weight / sum(all_available_weights)
```

Example at Wave 4:
- Basic (100) + Fast (60) + Tank (20) + Exploder (25) + Swarm (40) = 245 total
- Basic: 100/245 = 40.8%
- Fast: 60/245 = 24.5%
- Tank: 20/245 = 8.2%
- Exploder: 25/245 = 10.2%
- Swarm: 40/245 = 16.3%

---

## Stat Scaling

All enemy stats scale with wave number and difficulty:

### Wave Scaling
```gdscript
health = base_health * enemy_health_mult * pow(hp_scale_per_wave, wave - 1)
speed = base_speed * enemy_speed_mult * pow(speed_scale_per_wave, wave - 1)
contact_damage = base_damage * enemy_damage_mult
```

### Difficulty Multipliers

| Difficulty | Health | Speed | Damage | Count |
|------------|--------|-------|--------|-------|
| Easy | 1.0x | 1.0x | 1.0x | 1.0x |
| Medium | 1.25x | 1.1x | 1.2x | 1.2x |
| Hard | 1.5x | 1.2x | 1.5x | 1.4x |

---

## Visual System

### Sprite Loading
All enemy types use the same base sprite set from `res://assets/sprites/enemy/`:
- `enemy_south.png`, `enemy_north.png`, `enemy_east.png`, `enemy_west.png`
- `enemy_south_east.png`, `enemy_south_west.png`, `enemy_north_east.png`, `enemy_north_west.png`

Sprites are loaded dynamically based on the type's `sprite_folder` property.

### Color Tinting
Types without custom sprites use `color_tint` to differentiate:
- Basic: White (no tint)
- Fast: Light Blue `(0.6, 0.9, 1.0)`
- Tank: Brown/Rust `(0.8, 0.5, 0.3)`
- Exploder: Orange/Red `(1.0, 0.4, 0.2)`
- Swarm: Light Green `(0.7, 1.0, 0.7)`

### Scale
Each type has a `scale` property (default 1.0):
- Swarm: 0.5 (half size)
- Fast: 0.8 (slightly smaller)
- Tank: 1.4 (larger)

---

## Adding New Enemy Types

1. Add entry to `ENEMY_TYPES` in `globals.gd`:

```gdscript
"new_type": {
    "name": "Display Name",
    "icon": "🆕",
    "description": "What this enemy does",
    "behaviors": [EnemyBehavior.CHASE],
    "sprite_folder": "res://assets/sprites/enemy",
    "color_tint": Color(1.0, 1.0, 1.0),  # Optional
    "base_stats": {
        "health": 30.0,
        "speed": 150.0,
        "contact_damage": 33.0,
        "xp_value": 10,
        "scale": 1.0,
    },
    "spawn_weight": 50,
    "min_wave": 1,
}
```

2. For custom sprites, create a new folder under `assets/sprites/` with the 8 directional sprites.

3. For new behaviors, add handling in `enemy.gd` (see `_explode()` for example).

---

## Future Enhancements

- **RANGED behavior**: Enemies that stop at range and shoot projectiles
- **Boss enemies**: Unique types that spawn once per wave with special mechanics
- **Elite variants**: Rare upgraded versions of base types
- **Custom sprite sets**: Unique art for each enemy type
- **Animation support**: Walking animations per direction
