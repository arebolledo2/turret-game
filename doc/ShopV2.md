# Shop V2 - Economy & Progression Overhaul

## Overview
This document outlines a comprehensive update to the shop and economy systems, focusing on:
1. Removing the initial shop phase (player starts with a free Normal turret)
2. Rebalancing turret stats (reduced range, increased damage)
3. Dynamic turret pricing (escalating costs per purchase)
4. New item system with **9 interesting items** + **10 "boring" trade-off items**
5. Updated shop slot distribution (65% items, 35% turrets)
6. **Unique/Limited item system** (max quantity obtainable per run)

---

## 1. Remove Initial Shop Phase

### Current Behavior
- Game starts → Difficulty Select → **Shop Phase** → Wave 1
- Player has 120 starting gold to purchase their first turret

### New Behavior
- Game starts → Difficulty Select → Wave Announcement → **Wave 1**
- Player receives **1 free Normal turret** spawned at game start
- Starting gold reduced to **0** (or small amount like 20 for reroll flexibility)
- Shop only appears **after** completing a wave

### Files to Modify
| File | Changes |
|------|---------|
| `scripts/game_manager.gd` | Skip `start_shop_phase()` in `start_game()`, spawn free turret instead |
| `scripts/data/game_constants.gd` | Update `STARTING_GOLD` to 0 or 20 |
| `scripts/turret_manager.gd` | Add `spawn_starting_turret()` method |

### Implementation Notes
```gdscript
# In game_manager.gd start_game():
func start_game() -> void:
    Globals.reset_stats()
    Globals.is_game_active = true
    Events.game_started.emit()
    
    # Spawn free starting turret (instead of shop phase)
    var turret_mgr = get_node_or_null("../TurretManager")
    if turret_mgr and turret_mgr.has_method("spawn_starting_turret"):
        turret_mgr.spawn_starting_turret()
    
    # Go directly to wave 1
    start_wave_announcement()
```

---

## 2. Turret Stat Rebalance

### Design Goals
- **Reduce range** on all turrets except Sniper (creates tighter defensive zones, more strategic placement)
- **Increase damage** slightly to compensate (makes turrets feel more impactful)
- Sniper remains unchanged as the "range specialist"

### Current vs New Stats

| Turret | Current Range | New Range | Current Damage | New Damage |
|--------|---------------|-----------|----------------|------------|
| Normal | 250 | **180** | 15 | **18** |
| Sniper | 500 | **500** (unchanged) | 45 | **45** (unchanged) |
| Fire | 220 | **160** | 8 | **10** |
| Plasma | 280 | **200** | 20 | **25** |
| Shock | 150 | **120** | 12 | **15** |
| Tesla | 220 | **170** | 18 | **22** |

### Files to Modify
| File | Changes |
|------|---------|
| `scripts/registries/turret_registry.gd` | Update `base_stats` for each turret type |

---

## 3. Economy Update: Dynamic Turret Pricing

### Design Goals
- Make turret purchases feel more impactful/meaningful
- Prevent turret spam strategies
- Encourage item purchases (synergy with new item system)

### Current Behavior
- Turret prices scale with wave: `base_price * (1 + 0.15 * wave)`
- No penalty for buying multiple turrets

### New Behavior: Escalating Purchase Cost
Each turret purchased adds a **multiplier** to ALL future turret purchases.

**Formula:**
```
final_price = base_price * (1 + WAVE_PRICE_SCALE * wave) * (1 + TURRET_PURCHASE_PENALTY * turrets_owned)
```

**Constants:**
```gdscript
const TURRET_PURCHASE_PENALTY: float = 0.25  # +25% per turret owned
```

**Example Costs (Wave 3, Base Price 100):**
| Turrets Owned | Multiplier | Final Price |
|---------------|------------|-------------|
| 1 (starting) | 1.0 | 145 |
| 2 | 1.25 | 181 |
| 3 | 1.50 | 218 |
| 4 | 1.75 | 254 |
| 5 | 2.00 | 290 |

### New State Variable
```gdscript
# In Globals or GameState
var turrets_purchased: int = 0  # Track total turrets bought (not including starter)
```

### Files to Modify
| File | Changes |
|------|---------|
| `scripts/data/game_constants.gd` | Add `TURRET_PURCHASE_PENALTY` constant |
| `scripts/autoload/globals.gd` | Add `turrets_purchased` state variable, reset in `reset_stats()` |
| `scripts/shop_manager.gd` | Update `calculate_turret_price()` to include penalty multiplier |

---

## 4. New Item System: 10 Creative Items

### Design Philosophy
- Remove "boring" stat-stick items with minor trade-offs
- Focus on **interesting effects** that change gameplay
- Items should feel exciting to purchase
- Balance power with meaningful drawbacks or synergy requirements

### Items to REMOVE (Current Boring Items)
| Item ID | Reason |
|---------|--------|
| `swift_boots` | Minor speed buff, weak damage penalty - unexciting |
| `heavy_ammunition` | Tiny damage buff, minor HP loss - barely noticeable |
| `lightweight_frame` | Minor speed, minor HP loss - same problem |
| `reinforced_plating` | Minor HP, minor speed loss - boring trade |
| `precision_optics` | Minor fire rate, minor speed loss - forgettable |

### NEW Items (10 Creative Damage/Effect Items)

#### Common Tier (Price: 40)

**1. Volatile Rounds** 🔴
```gdscript
"volatile_rounds": {
    "name": "Volatile Rounds",
    "icon": "🔴",
    "description": "Turret projectiles explode on hit, but turrets fire slower",
    "rarity": GameEnums.ItemRarity.COMMON,
    "modifiers": [
        {"stat": "aoe_radius", "operation": "add", "value": 40.0, "filter": {"turret_type": ["normal", "fire"]}},
        {"stat": "fire_rate", "operation": "multiply", "value": 0.85, "filter": {"turret_type": ["all"]}}
    ]
}
```

**2. Scrap Magnet** 🧲
```gdscript
"scrap_magnet": {
    "name": "Scrap Magnet",
    "icon": "🧲",
    "description": "Gold drops are attracted to you from further away",
    "rarity": GameEnums.ItemRarity.COMMON,
    "modifiers": [
        {"stat": "pickup_radius", "operation": "multiply", "value": 2.0}
    ]
}
```

#### Uncommon Tier (Price: 70)

**3. Overcharged Cells** ⚡
```gdscript
"overcharged_cells": {
    "name": "Overcharged Cells",
    "icon": "⚡",
    "description": "Electric turrets deal 50% more damage but chain to fewer targets",
    "rarity": GameEnums.ItemRarity.UNCOMMON,
    "modifiers": [
        {"stat": "damage", "operation": "multiply", "value": 1.5, "filter": {"damage_type": ["electric"]}},
        {"stat": "chain_count", "operation": "add", "value": -1, "filter": {"turret_type": ["tesla"]}}
    ]
}
```

**4. Incendiary Gel** 🩸
```gdscript
"incendiary_gel": {
    "name": "Incendiary Gel",
    "icon": "🩸",
    "description": "Fire effects last twice as long and tick faster",
    "rarity": GameEnums.ItemRarity.UNCOMMON,
    "modifiers": [
        {"stat": "dot_duration", "operation": "multiply", "value": 2.0, "filter": {"turret_type": ["fire"]}},
        {"stat": "dot_tick_rate", "operation": "multiply", "value": 0.5, "filter": {"turret_type": ["fire"]}}
    ]
}
```

**5. Glass Cannon Core** 💎
```gdscript
"glass_cannon_core": {
    "name": "Glass Cannon Core",
    "icon": "💎",
    "description": "ALL turrets deal 40% more damage. You have 50% less health.",
    "rarity": GameEnums.ItemRarity.UNCOMMON,
    "modifiers": [
        {"stat": "damage", "operation": "multiply", "value": 1.4, "filter": {"turret_type": ["all"]}},
        {"stat": "player_max_health", "operation": "multiply", "value": 0.5}
    ]
}
```

#### Rare Tier (Price: 110)

**6. Shrapnel Rounds** 💥
```gdscript
"shrapnel_rounds": {
    "name": "Shrapnel Rounds",
    "icon": "💥",
    "description": "Projectiles pierce through 2 additional enemies",
    "rarity": GameEnums.ItemRarity.RARE,
    "modifiers": [
        {"stat": "pierce", "operation": "add", "value": 2, "filter": {"attack_style": ["projectile"]}}
    ]
}
```

**7. Targeting Matrix** 🎯
```gdscript
"targeting_matrix": {
    "name": "Targeting Matrix",
    "icon": "🎯",
    "description": "Turrets rotate 100% faster and have 15% increased fire rate",
    "rarity": GameEnums.ItemRarity.RARE,
    "modifiers": [
        {"stat": "rotation_speed", "operation": "multiply", "value": 2.0, "filter": {"turret_type": ["all"]}},
        {"stat": "fire_rate", "operation": "multiply", "value": 1.15, "filter": {"turret_type": ["all"]}}
    ]
}
```

**8. Plasma Capacitor** 🟣
```gdscript
"plasma_capacitor": {
    "name": "Plasma Capacitor",
    "icon": "🟣",
    "description": "Plasma explosions are 60% larger with stronger knockback",
    "rarity": GameEnums.ItemRarity.RARE,
    "modifiers": [
        {"stat": "aoe_radius", "operation": "multiply", "value": 1.6, "filter": {"turret_type": ["plasma"]}},
        {"stat": "knockback_force", "operation": "multiply", "value": 1.5, "filter": {"turret_type": ["plasma"]}}
    ]
}
```

#### Epic Tier (Price: 160)

**9. Berserker Protocol** 🔥
```gdscript
"berserker_protocol": {
    "name": "Berserker Protocol",
    "icon": "🔥",
    "description": "Turrets fire 50% faster when enemies are within close range",
    "rarity": GameEnums.ItemRarity.EPIC,
    "special_effect": "berserker_protocol",
    "modifiers": []
    # Note: Requires special handling - conditional fire rate boost
}
```

**10. Executioner's Mark** ☠️
```gdscript
"executioners_mark": {
    "name": "Executioner's Mark",
    "icon": "☠️",
    "description": "Turrets deal 100% bonus damage to enemies below 25% health",
    "rarity": GameEnums.ItemRarity.EPIC,
    "special_effect": "executioner",
    "modifiers": []
    # Note: Requires special handling - conditional damage boost
}
```

### Files to Modify
| File | Changes |
|------|---------|
| `scripts/registries/item_registry.gd` | Remove old items, add 10 new items |
| `scripts/systems/modifier_system.gd` | Add support for new modifier types (aoe_radius, pierce, etc.) |
| `scripts/turret.gd` | Handle special effects (berserker, executioner) |

---

## 5. Shop Slot Distribution Update

### Current Behavior
- 4 shop slots total
- 3 turrets, 1 item (75% turrets, 25% items)

### New Behavior
- 4 shop slots total
- Each slot rolled independently:
  - **65% chance** → Item
  - **35% chance** → Turret

**Expected Distribution:** ~2.6 items, ~1.4 turrets per shop

### Implementation
```gdscript
const SHOP_ITEM_CHANCE: float = 0.65  # 65% item, 35% turret

func generate_offers() -> void:
    Globals.current_shop_offers.clear()
    
    for i in range(SHOP_OFFER_COUNT):
        var roll = randf()
        if roll < SHOP_ITEM_CHANCE:
            generate_item_offer()
        else:
            generate_turret_offer()
    
    Events.shop_offers_generated.emit(Globals.current_shop_offers)
```

### Files to Modify
| File | Changes |
|------|---------|
| `scripts/data/game_constants.gd` | Add `SHOP_ITEM_CHANCE` constant |
| `scripts/shop_manager.gd` | Rewrite `generate_offers()` to use probability-based slot generation |

---

## Implementation Order

### Phase 1: Core Changes (Low Risk)
1. ✅ Update turret stats in `turret_registry.gd`
2. ✅ Add new constants to `game_constants.gd`
3. ✅ Update `globals.gd` with new state variables

### Phase 2: Economy System
4. ✅ Implement escalating turret pricing in `shop_manager.gd`
5. ✅ Update shop slot distribution logic

### Phase 3: Item Overhaul
6. ✅ Remove old items from `item_registry.gd`
7. ✅ Add 10 new items to `item_registry.gd`
8. ✅ Update `modifier_system.gd` for new modifier types
9. ✅ Add special effect handling in `turret.gd` (berserker, executioner)

### Phase 4: Game Flow
10. ✅ Remove initial shop phase in `game_manager.gd`
11. ✅ Implement free starting turret spawn
12. ✅ Update starting gold

---

## Testing Checklist

- [ ] Game starts directly into Wave 1 (no shop)
- [ ] Player receives free Normal turret at game start
- [ ] Turret ranges feel tighter (require more strategic placement)
- [ ] Turret damage feels impactful
- [ ] Buying turrets increases future turret prices
- [ ] Shop shows ~65% items, ~35% turrets on average
- [ ] All 10 new items appear in shop
- [ ] New items apply their effects correctly
- [ ] Special effects (berserker, executioner) work as intended
- [ ] Game balance feels good through all 10 waves

---

## Balance Notes

### Starting Power Budget
- Old: 120 gold → choose turret type
- New: Free Normal turret → forced into standard loadout initially
- **Rationale:** Simplifies onboarding, ensures consistent early game

### Turret Scarcity
- Escalating prices + reduced shop turret chance = turrets are precious
- Encourages item investment and strategic turret placement
- Late game should have 4-6 turrets max (vs potential 8-10 before)

### Item Power Curve
- Common: Quality-of-life or minor synergies
- Uncommon: Meaningful buffs with trade-offs
- Rare: Significant power spikes
- Epic: Build-defining effects

---

## Future Considerations (Not in this update)

- Legendary/Unique tier items
- Turret upgrade system (enhance existing turrets)
- Item synergy combos (e.g., "fire items empower each other")
- Shop locking (pay to keep an offer for next wave)
- Turret selling (recover partial gold)
