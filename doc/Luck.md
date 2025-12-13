# Luck System - Implementation Plan

**Status: ✅ IMPLEMENTED**

## Problem Statement

### Current Rarity System Issues
The current shop item generation in `shop_manager.gd` selects items purely randomly from the available pool:

```gdscript
var random_item_id = available_items[randi() % available_items.size()]
```

This approach has two problems:
1. **No rarity weighting**: All items have equal chance to appear, regardless of rarity
2. **No wave-based progression**: Epic items can appear in Wave 1 as often as Wave 10

The desired behavior:
- **Early waves**: Heavily favor COMMON and UNCOMMON items
- **Later waves**: Gradually increase chance of RARE, EPIC, LEGENDARY items
- **Luck stat**: Player can influence rarity rolls through items and upgrades

---

## Luck System Design

### Core Concept
Luck is a player stat (0.0 to 1.0+) that shifts the rarity distribution toward higher tiers. Base luck is 0.0, and items/effects can increase it.

### Rarity Weight Configuration
Add to `GameConstants`:

```gdscript
# =============================================================================
# RARITY / LUCK SYSTEM
# =============================================================================

# Base rarity weights (higher = more common)
# These are the weights when luck = 0 and wave = 1
const RARITY_BASE_WEIGHTS: Dictionary = {
    GameEnums.ItemRarity.COMMON: 100.0,
    GameEnums.ItemRarity.UNCOMMON: 40.0,
    GameEnums.ItemRarity.RARE: 15.0,
    GameEnums.ItemRarity.EPIC: 5.0,
    GameEnums.ItemRarity.LEGENDARY: 1.0,
    GameEnums.ItemRarity.UNIQUE: 0.0,  # Special drops only
}

# How much each point of luck (0.0-1.0) shifts weight toward higher rarities
# At luck=1.0, apply these multipliers to base weights
const LUCK_WEIGHT_MULTIPLIERS: Dictionary = {
    GameEnums.ItemRarity.COMMON: 0.5,      # Common becomes less likely
    GameEnums.ItemRarity.UNCOMMON: 0.8,    # Uncommon slightly less likely
    GameEnums.ItemRarity.RARE: 1.5,        # Rare more likely
    GameEnums.ItemRarity.EPIC: 2.5,        # Epic much more likely
    GameEnums.ItemRarity.LEGENDARY: 4.0,   # Legendary very boosted
    GameEnums.ItemRarity.UNIQUE: 1.0,      # Unique unchanged (special only)
}

# Wave-based rarity unlocks (items below min_wave can't appear)
const RARITY_MIN_WAVE: Dictionary = {
    GameEnums.ItemRarity.COMMON: 1,
    GameEnums.ItemRarity.UNCOMMON: 1,
    GameEnums.ItemRarity.RARE: 2,
    GameEnums.ItemRarity.EPIC: 4,
    GameEnums.ItemRarity.LEGENDARY: 6,
    GameEnums.ItemRarity.UNIQUE: 1,  # Special conditions only
}

# Wave-based weight bonus (per wave after min_wave)
const RARITY_WAVE_BONUS_PER_WAVE: float = 0.05  # +5% weight per wave past min

# Player luck configuration
const PLAYER_BASE_LUCK: float = 0.0
const PLAYER_MAX_LUCK: float = 2.0  # Cap at 200% for sanity
```

### Formula: Effective Rarity Weight

```
effective_weight = base_weight 
                   × lerp(1.0, luck_multiplier, clamp(luck, 0, 1))
                   × (1.0 + wave_bonus_per_wave × waves_past_min)
```

Where:
- `base_weight` = `RARITY_BASE_WEIGHTS[rarity]`
- `luck_multiplier` = `LUCK_WEIGHT_MULTIPLIERS[rarity]`
- `waves_past_min` = `max(0, current_wave - RARITY_MIN_WAVE[rarity])`

**Example at Wave 5, Luck 0.3:**
- COMMON: `100 × lerp(1.0, 0.5, 0.3) × (1 + 0.05×4) = 100 × 0.85 × 1.2 = 102`
- RARE: `15 × lerp(1.0, 1.5, 0.3) × (1 + 0.05×3) = 15 × 1.15 × 1.15 = 19.8`
- EPIC: `5 × lerp(1.0, 2.5, 0.3) × (1 + 0.05×1) = 5 × 1.45 × 1.05 = 7.6`

---

## Player Luck Stat

### State Tracking
Add to `Globals` (runtime state):

```gdscript
# Player luck stat (modifiable via items/effects)
var player_luck: float = GameConstants.PLAYER_BASE_LUCK
```

### Modifier System Integration
Luck can be modified like any other player stat:

```gdscript
{"stat": "player_luck", "operation": "add", "value": 0.15}
{"stat": "player_luck", "operation": "multiply", "value": 1.25}
```

### Reset on Game Start
In `Globals.reset_stats()`:

```gdscript
player_luck = GameConstants.PLAYER_BASE_LUCK
```

---

## New Luck-Based Items

### 1. Lucky Charm (COMMON - 40g)
Entry-level luck item with small boost.

```gdscript
"lucky_charm": {
    "name": "Lucky Charm",
    "icon": "🍀",
    "description": "Increases luck by 10%. Better items may appear in shops.",
    "rarity": GameEnums.ItemRarity.COMMON,
    "modifiers": [
        {"stat": "player_luck", "operation": "add", "value": 0.10}
    ]
}
```

### 2. Probability Matrix (RARE - 110g)
Mid-tier luck item with interesting trade-off.

```gdscript
"probability_matrix": {
    "name": "Probability Matrix",
    "icon": "🎲",
    "description": "+25% luck, but rerolls cost 50% more.",
    "rarity": GameEnums.ItemRarity.RARE,
    "modifiers": [
        {"stat": "player_luck", "operation": "add", "value": 0.25},
        {"stat": "reroll_cost", "operation": "multiply", "value": 1.5}
    ]
}
```

### 3. Fortune's Favor (EPIC - 160g)
Powerful luck item with significant impact.

```gdscript
"fortunes_favor": {
    "name": "Fortune's Favor",
    "icon": "⭐",
    "description": "+40% luck. Rare+ items cost 15% less.",
    "rarity": GameEnums.ItemRarity.EPIC,
    "max_stacks": 1,
    "modifiers": [
        {"stat": "player_luck", "operation": "add", "value": 0.40}
    ],
    "special_effect": "fortune_discount"
}
```

---

## Implementation Tasks

### Phase 1: Core Luck System
1. [x] Add `RARITY_BASE_WEIGHTS` to `GameConstants`
2. [x] Add `LUCK_WEIGHT_MULTIPLIERS` to `GameConstants`
3. [x] Add `RARITY_MIN_WAVE` to `GameConstants`
4. [x] Add `RARITY_WAVE_BONUS_PER_WAVE` to `GameConstants`
5. [x] Add `PLAYER_BASE_LUCK` and `PLAYER_MAX_LUCK` to `GameConstants`
6. [x] Add `player_luck` to `Globals` runtime state
7. [x] Add `player_luck` reset in `Globals.reset_stats()`

### Phase 2: Item Registry Updates
1. [x] Add `get_items_by_rarity(rarity)` helper to `ItemRegistry`
2. [x] Add `get_weighted_random_item(wave, luck, item_counts)` to `ItemRegistry`

### Phase 3: Shop Manager Integration
1. [x] Replace random item selection with weighted rarity selection
2. [x] Implement `calculate_rarity_weights(wave, luck)` function
3. [x] Filter items by `RARITY_MIN_WAVE` before selection

### Phase 4: New Items
1. [x] Add `lucky_charm` to `ItemRegistry`
2. [x] Add `probability_matrix` to `ItemRegistry`
3. [x] Add `fortunes_favor` to `ItemRegistry`
4. [x] Implement `fortune_discount` special effect in shop pricing

### Phase 5: Modifier System
1. [x] Register `player_luck` in modifier system
2. [x] Register `reroll_cost` modifier

### Phase 6: Testing
1. [x] All 468 existing tests pass

---

## Files to Modify

| File | Changes |
|------|---------|
| `scripts/data/game_constants.gd` | Add luck/rarity constants |
| `scripts/autoload/globals.gd` | Add `player_luck` state, update `reset_stats()` |
| `scripts/registries/item_registry.gd` | Add weighted selection, new items |
| `scripts/shop_manager.gd` | Use weighted rarity selection |
| `scripts/systems/modifier_system.gd` | Register `player_luck`, `reroll_cost` stats |
| `tests/unit/test_item_registry.gd` | Add luck/rarity tests |

---

## UI Considerations (Future)

- Show current luck value in player stats HUD
- Show item rarity color in shop offers (already implemented via `RARITY_COLORS`)
- Consider showing "luck boost active" indicator when luck > 0

---

## Balance Notes

- At luck = 0, Wave 1: ~62% Common, ~25% Uncommon, ~9% Rare, ~3% Epic, ~1% Legendary
- At luck = 0.5, Wave 5: ~45% Common, ~25% Uncommon, ~17% Rare, ~10% Epic, ~3% Legendary  
- At luck = 1.0, Wave 10: ~28% Common, ~22% Uncommon, ~22% Rare, ~18% Epic, ~10% Legendary

These are rough estimates - actual values depend on final tuning of constants.

---

## Open Questions

1. Should luck affect turret type rarity in shop? (Currently turrets have no rarity)
2. Should luck affect drop rates from enemies?
3. Should there be a "bad luck protection" system (guaranteed rare after N commons)?
4. Should luck be visible to the player, or a hidden stat?
