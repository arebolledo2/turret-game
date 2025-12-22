# Godot Script Refactoring Plan

## Target: Reduce file sizes from 500+ lines to 150-250 lines for AI agent optimization

### Phase 1 - UI Components (High Impact) 🎯 [COMPLETED]
- [x] shop_screen.gd (630→150 lines) - Extract to shop panels
  - [x] Create scripts/ui/shop/shop_offers_panel.gd
  - [x] Create scripts/ui/shop/shop_player_build_panel.gd
  - [x] Create scripts/ui/shop/shop_build_tabs/turrets_tab.gd
  - [x] Create scripts/ui/shop/shop_build_tabs/items_tab.gd
  - [x] Refactor main shop_screen.gd to orchestrate panels
- [x] hud.gd (289→100 lines) - Split into controller + displays
  - [x] Create scripts/ui/hud/hud_game_display.gd
  - [x] Create scripts/ui/hud/hud_menu_manager.gd
  - [x] Refactor main hud.gd as orchestrator
- [x] build_display_ui.gd (333→200 lines) - Extract tab logic
  - [x] Create scripts/ui/ui_helpers.gd
  - [x] Create scripts/ui/turret_display_ui.gd
  - [x] Create scripts/ui/item_display_ui.gd
  - [x] Refactor build_display_ui.gd as facade

### Phase 2 - Core Entities 🎮
- [ ] player.gd (545→150 lines) - Component-based architecture
  - [ ] Create scripts/player/player_movement.gd
  - [ ] Create scripts/player/player_combat.gd
  - [ ] Create scripts/player/player_turret_handler.gd
  - [ ] Refactor main player.gd as coordinator
- [ ] enemy.gd (524→160 lines) - Behavior components
  - [ ] Create scripts/enemy/enemy_movement.gd
  - [ ] Create scripts/enemy/enemy_visuals.gd
  - [ ] Create scripts/enemy/enemy_status_effects.gd
- [ ] turret.gd (492→160 lines) - Fire modes + modifiers
  - [ ] Create scripts/turret/turret_fire_modes.gd
  - [ ] Create scripts/turret/turret_modifiers.gd
  - [ ] Create scripts/turret/turret_effects.gd

### Phase 3 - Data Files 📊
- [ ] Split item registries by category
  - [ ] rare_items.gd (264 lines) → 3 files @ ~90 lines
  - [ ] common_items.gd (252 lines) → 3 files @ ~85 lines
- [ ] Review enemy_registry.gd for potential splits
- [ ] Review game_constants.gd for balance/visual constant splits

## Progress Tracking
- **Files > 500 lines:** 7 → 0
- **Files > 350 lines:** 12 → 0
- **Target achieved:** All files < 250 lines ✅

## Guidelines
- Target: 150-250 lines per file
- Max: < 350 lines (hard limit)
- File size: < 10KB preferred
- Use composition over inheritance
- Single responsibility per file