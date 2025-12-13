# UI Improvements Plan (UIv2_Grok)

## Overview
This plan addresses the requested UI improvements for the turret game, focusing on enhanced player feedback, navigation, and information display. The improvements build upon the existing modular UI architecture using the signal bus pattern and Globals for data access.

## Current State Analysis

### Existing UI Components
- **HUD** (`scripts/hud.gd`): Main HUD orchestrator that manages all UI components
  - Pause menu UI is embedded within `scenes/ui/hud.tscn` (not a separate scene)
  - Delegates to `scripts/ui/pause_menu.gd` for pause menu logic
- **Game HUD** (`scripts/ui/game_hud.gd`): Health bar (ProgressBar), wave info, XP, gold, turret count
- **Pause Menu** (`scripts/ui/pause_menu.gd`): Stats grid, turret icons/details, item placeholders
- **Shop Screen** (`scripts/shop_screen.gd`): Offers with details, reroll/continue buttons
- **Data Sources**: Globals for runtime state, registries for type definitions

### Current Issues
1. **Missing Stats**: Luck stat not displayed despite existing in game mechanics
2. **Limited Shop Info**: Shop shows offers but not player's current stats/inventory
3. **Item Placeholders**: Items shown as colored rectangles with tooltips only
4. **Controller Navigation**: Turrets navigable, items are not focusable
5. **Duplicate Display**: Items stored as array duplicates, no quantity badges
6. **Health Values**: Health bar shows visual progress but no numeric values

### Data Availability
- **Luck**: `Globals.get_player_luck_display()` returns integer value
- **Item Counts**: `Globals.item_counts` dictionary tracks quantities
- **Stats**: All player stats available via Globals/player node
- **Registries**: Full type definitions for turrets/items

## Detailed Improvement Plan

### 1. Show Missing Status (Luck)
**Locations**: Pause menu stats grid, Shop screen player stats panel
**Implementation**:
- Add "LuckValue" label to pause menu stats grid
- Add luck display to shop screen player build section
- Use `Globals.get_player_luck_display()` for consistent formatting
- Update `pause_menu.gd` and `shop_screen.gd` update methods

### 2. Detailed Stats in Shop Screen
**Goal**: Mirror pause menu inventory/stats in shop for informed purchasing
**Layout**: Add "Player Build" section below offers in shop panel

**ASCII Mockup**:
```
┌─────────────────────────────────────────────────┐
│  TURRET SHOP - WAVE 3        Gold: 250         │
├─────────────────────────────────────────────────┤
│                                                 │
│  [Offer 1]    [Offer 2]    [Offer 3]          │
│  Fire         Plasma       Lucky Coin          │
│  Turret       Turret       (Item)              │
│  $150         $180         $70                 │
│                                                 │
├─────────────────────────────────────────────────┤
│  PLAYER BUILD                                   │
│  ┌───────────────────────────────────────────┐ │
│  │ Stats: HP:73/120  Speed:100  Luck:5      │ │
│  │        XP:450  Kills:12  Time:2:34       │ │
│  │                                           │ │
│  │ Turrets (3):  🔥x2  ⚡x1                 │ │
│  │ Items (4):    🧲x1  🛡️x2  ⚡x1           │ │
│  └───────────────────────────────────────────┘ │
│                                                 │
│     [Reroll $50]           [Continue]          │
└─────────────────────────────────────────────────┘
```

**Content**:
- **Player Stats**: Health, Speed, XP, Kills, Time, Gold, Luck
- **Owned Turrets**: Emoji icons with counts (e.g., 🔥x2)
- **Owned Items**: Emoji icons with counts (e.g., 🧲x1)
**Reuse**: Extract common rendering logic to avoid duplication

### 3. Item Details Instead of Placeholders
**Pause Menu**:
- Replace `ColorRect` with focusable `Button` nodes
- Show emoji icon from ItemRegistry as Label (e.g., "🧲", "🛡️")
- Add rarity color border on button
- Add quantity badge as small text overlay (e.g., "x2") - positioned in top-right corner
- Add item details panel (icon, name, description, modifiers)
- Use `Globals.item_counts` for unique items + counts

**Shop Screen**:
- Include owned items list in player build section
- Display emoji icons with count (e.g., "🧲x1") in compact format
- Same rendering as pause menu for consistency

### 4. Controller Navigation for Items
**Pause Menu**:
- Make item buttons focusable with `FOCUS_ALL`
- Set focus neighbors: turrets ↔ items, items ↔ resume button
- Left/right cycles within rows, up/down between sections

**Shop Screen**:
- Ensure offers remain navigable
- Add navigation from offers to player build section
- Maintain focus on continue button initially

### 5. Duplicate Item Display as Quantities
**Data Source**: Use `Globals.item_counts` instead of iterating `collected_items`
**Display**: Show unique items with "xN" badge (small text overlay in top-right corner) for counts > 1
**Logic**: 
- Iterate `item_counts.keys()` 
- Get count from `item_counts[item_id]`
- Hide badge for count = 1
**Note**: Ignore max_stacks property - all stackable items show quantity regardless of max limit

### 6. Health Values in Player Health Bar
**HUD Enhancement**:
- Add `Label` child to health bar ProgressBar
- Center text showing "current/max" format
- Update `game_hud.gd` `update_health_bar()` method
- Maintain color coding (green/yellow/red)

## Implementation Steps

### Phase 1: HUD Health Text
1. Edit `scenes/ui/hud.tscn` - Add Label to HealthBar (embedded in main HUD scene)
2. Update `scripts/ui/game_hud.gd` - Set label text in `update_health_bar()`

### Phase 2: Luck Display
1. Edit `scenes/ui/hud.tscn` - Add Luck row to stats grid in PauseMenu section
2. Update `pause_menu.gd` - Populate luck in `update_stats()`
3. Add luck to shop screen player build section

### Phase 3: Item System Overhaul
1. Refactor `pause_menu.gd` `update_items_panel()`:
   - Use `Globals.item_counts`
   - Create `Button` nodes instead of `ColorRect`
   - Add emoji icon Label from ItemRegistry
   - Add rarity color border styling
   - Add quantity badge as small Label overlay (top-right corner)
   - Add item details panel and selection logic
2. Add controller focus setup for item buttons

### Phase 4: Shop Screen Enhancement
1. Edit `scenes/ui/shop_screen.tscn` - Add player build section
2. Update `shop_screen.gd`:
   - Add rendering for player stats
   - Add owned turrets/items lists
   - Include luck display
   - Extract shared logic if possible

### Phase 5: Controller Navigation
1. Set focus neighbors on dynamically created buttons
2. Test navigation flows: Pause menu, Shop screen
3. Ensure no focus dead-ends

### Phase 6: Polish & Testing
1. Verify all displays update correctly
2. Test with controller-only navigation
3. Confirm stacking behavior with max_stacks items
4. Run existing tests to ensure no regressions

## Technical Considerations

### Code Reuse
- Extract item/turret rendering helpers to reduce duplication
- Keep UI reactive via Events + Globals (no direct node refs)

### Focus Management
- Use `focus_mode = FOCUS_ALL` on interactive elements
- Set `focus_neighbor_*` properties for custom navigation
- Handle dynamic button creation/removal

### Data Consistency
- Prefer `Globals.item_counts` over `collected_items` for display
- Use registry functions for formatting (modifiers, colors)

### Scene Changes
- Update node paths in scripts when adding new UI elements
- Maintain existing styling and layout principles

## Validation Checklist

### Manual Testing
- [ ] Health bar shows "73/120" format after damage/hsmall text overlay (top-right)
- [ ] Item buttons show emoji icons from ItemRegistry
- [ ] Item buttons have rarity color borders
- [ ] Item buttons are focusable and show details on selection
- [ ] Controller can navigate: turrets → items → resume (pause menu)
- [ ] Controller can navigate: offers → build section → buttons (shop)
- [ ] Shop screen shows current stats, turrets, and items in Player Build section
- [ ] All displays update when values change (gold, health, inventory)

### Edge Cases
- [ ] Empty item/turret lists don't break navigation
- [ ] Count = 1 items don't show quantity overlay (only x2, x3, etc.)
- [ ] Focus works when lists change during shop regeneration
- [ ] UI scales properly with different screen sizes
- [ ] Emoji icons render correctly on all platform
- [ ] Focus works when lists change during shop regeneration
- [ ] UI scales properly with different screen sizes
, `get_player_luck_display()`
- UI scenes: `scenes/ui/hud.tscn` (contains embedded pause menu), `scenes/ui/shop_screen.tscn`
- Scripts: `scripts/hud.gd`, `scripts/ui/game_hud.gd`, `scripts/ui/pause_menu.gd`, `scripts/shop_screen.gd`

## Visual Design Notes
- **Item Icons**: Display emoji text from ItemRegistry (🧲🛡️⚡🔥 etc.) using Label nodes
- **Quantity Badges**: Small text overlay "xN" in top-right corner of button, only shown when count > 1
- **Rarity Colors**: Apply ItemRegistry.RARITY_COLORS as border/outline on item buttons
- **Layout**: Shop Player Build section appears below offers, showing compact stats and inventory
- Existing registries: `ItemRegistry`, `TurretRegistry`
- Globals data: `item_counts`, `turret_counts`, player stats
- UI scenes: `hud.tscn`, `pause_menu.tscn`, `shop_screen.tscn`</content>
<parameter name="filePath">c:\Users\AndresRebolledo\source\repos\turret-game\UIv2_Grok.md