# Wave-Based Reroll Cost Implementation

## Summary
Implemented wave-based scaling for reroll costs using Option 1 with a 1.5x wave multiplier.

## Formula
```gdscript
reroll_cost = (wave × 1.5 + INCREMENT × rerolls_this_wave) × item_multiplier
```

## Constants Added
- **`REROLL_WAVE_BASE_MULTIPLIER`**: `1.5` (in `game_constants.gd`)

## Changes Made

### 1. [`game_constants.gd`](file:///c:/Users/AndresRebolledo/source/repos/turret-dev/turret-game/scripts/data/game_constants.gd#L131)
Added new constant:
```gdscript
const REROLL_WAVE_BASE_MULTIPLIER: float = 1.5 # Wave-based base cost multiplier
```

### 2. [`economy_service.gd`](file:///c:/Users/AndresRebolledo/source/repos/turret-dev/turret-game/scripts/autoload/economy_service.gd#L26-L31)
Updated `get_reroll_cost()` signature to accept wave parameter:
```gdscript
func get_reroll_cost(wave: int, reroll_cost_multiplier: float) -> int:
    var wave_base_cost := wave * GameConstants.REROLL_WAVE_BASE_MULTIPLIER
    var total_cost := wave_base_cost + shop_reroll_count * GameConstants.REROLL_COST_INCREMENT
    return int(total_cost * reroll_cost_multiplier)
```

### 3. [`shop_manager.gd`](file:///c:/Users/AndresRebolledo/source/repos/turret-dev/turret-game/scripts/shop_manager.gd#L237-L241)
Updated to pass current wave to EconomyService:
```gdscript
func get_reroll_cost() -> int:
    var item_multiplier := ItemTrackingService.get_reroll_cost_multiplier()
    return EconomyService.get_reroll_cost(GameStateService.current_wave, item_multiplier)
```

### 4. [`test_economy_service.gd`](file:///c:/Users/AndresRebolledo/source/repos/turret-dev/turret-game/tests/unit/test_economy_service.gd#L113-L173)
Updated all unit tests to test wave-based scaling with comprehensive test coverage

## Example Costs

### Wave 1
- 1st reroll: `(1 × 1.5) + 0` = **1 gold**
- 2nd reroll: `(1 × 1.5) + 1` = **2 gold**
- 3rd reroll: `(1 × 1.5) + 2` = **3 gold**

### Wave 3
- 1st reroll: `(3 × 1.5) + 0` = **4 gold**
- 2nd reroll: `(3 × 1.5) + 1` = **5 gold**
- 3rd reroll: `(3 × 1.5) + 2` = **6 gold**

### Wave 5
- 1st reroll: `(5 × 1.5) + 0` = **7 gold**
- 2nd reroll: `(5 × 1.5) + 1` = **8 gold**
- 3rd reroll: `(5 × 1.5) + 2` = **9 gold**

### Wave 10
- 1st reroll: `(10 × 1.5) + 0` = **15 gold**
- 2nd reroll: `(10 × 1.5) + 1` = **16 gold**
- 3rd reroll: `(10 × 1.5) + 2` = **17 gold**

## Key Behaviors
- ✅ Reroll costs **reset each wave** (counter resets)
- ✅ Base cost **increases with wave number** (1.5x multiplier)
- ✅ Costs **stack linearly within a wave** (+1 gold per reroll)
- ✅ **Item multipliers** still apply (e.g., Probability Matrix discount)
- ✅ Costs are **rounded down** to integers

## Test Results
- ✅ **577 unit tests** passed
- ✅ **229 integration tests** passed
- ✅ All reroll cost calculations verified
