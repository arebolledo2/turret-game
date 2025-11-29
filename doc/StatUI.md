# Pause Menu Stats UI Enhancement

## Overview
Enhance the pause menu to display player details including level, stats, and items.

---

## UI Layout Diagram

```
┌────────────────────────────────────────────────────────────────────────────┐
│                         PAUSE MENU (Full Screen Overlay)                   │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                                                                      │  │
│  │  ┌─────────────────┐   ┌──────────────────────────────────────────┐  │  │
│  │  │    PAUSED       │   │            PLAYER STATS                  │  │  │
│  │  │   ──────────    │   │   ─────────────────────                  │  │  │
│  │  │   Level: 5      │   │   ❤ Health:  75/100    🛡 Armor: 5       │  │  │
│  │  │   Wave:  3/10   │   │   ⚡ Speed:   300       💨 Dodge: 10%     │  │  │
│  │  │                 │   │                                          │  │  │
│  │  │   [ Resume  ]   │   │   (Future: Level Up / Shop Phase)        │  │  │
│  │  │   [ Settings]   │   │                                          │  │  │
│  │  │   [ Quit    ]   │   │                                          │  │  │
│  │  └─────────────────┘   └──────────────────────────────────────────┘  │  │
│  │                                                                      │  │
│  │  ┌────────────────────────────────────────────────────────────────┐  │  │
│  │  │  TURRETS (3)   Click turret icon for details                   │  │  │
│  │  │  ─────────────────────────────────────────────────────────     │  │  │
│  │  │                                                                │  │  │
│  │  │   ┌──────┐   ┌──────┐                                          │  │  │
│  │  │   │ 🗼   │   │ 🔥   │    (Only unlocked turrets shown)         │  │  │
│  │  │   │  x2  │   │  x1  │                                          │  │  │
│  │  │   └──────┘   └──────┘                                          │  │  │
│  │  │    Basic      Flame                                            │  │  │
│  │  │   [SELECTED]                                                   │  │  │
│  │  │  ┌──────────────────────────────────────────────────────────┐ │  │  │
│  │  │  │  Basic Turret (x2)                                       │ │  │  │
│  │  │  │  ───────────────────────────────────────────────         │ │  │  │
│  │  │  │  Stats (Modified by Items):                              │ │  │  │
│  │  │  │   • Damage:     15        • Rotation:   180°/s          │ │  │  │
│  │  │  │   • Range:      400       • Weight:     10 (Heavy)      │ │  │  │
│  │  │  │   • Fire Rate:  2.0/s     • DPS:        30.0            │ │  │  │
│  │  │  └──────────────────────────────────────────────────────────┘ │  │  │
│  │  └────────────────────────────────────────────────────────────────┘  │  │
│  │                                                                      │  │
│  │  ┌────────────────────────────────────────────────────────────────┐  │  │
│  │  │  ITEMS (22)                                                    │  │  │
│  │  │  ─────────                                                     │  │  │
│  │  │  ┌───┐┌───┐┌───┐┌───┐┌───┐┌───┐┌───┐┌───┐┌───┐┌───┐            │  │  │
│  │  │  │ ⚪││ 🟢││ 🔵││ 🟣││ 🟠││ 🔴││ ? ││ ? ││ ? ││ ? │ ...        │  │  │
│  │  │  └───┘└───┘└───┘└───┘└───┘└───┘└───┘└───┘└───┘└───┘            │  │  │
│  │  │  ┌───┐┌───┐┌───┐┌───┐┌───┐┌───┐┌───┐┌───┐┌───┐┌───┐            │  │  │
│  │  │  │ ? ││ ? ││ ? ││ ? ││ ? ││ ? ││ ? ││ ? ││ ? ││ ? │ ...        │  │  │
│  │  │  └───┘└───┘└───┘└───┘└───┘└───┘└───┘└───┘└───┘└───┘            │  │  │
│  │  │        ▲ Hover: "Scope (Common) - Range +10%"                  │  │  │
│  │  └────────────────────────────────────────────────────────────────┘  │  │
│  │                                                                      │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────────┘
```

**Turret Interaction:**
- Only unlocked turrets (count > 0) are visible.
- Click icon to select → shows detailed stats.
- Stats include: Damage, Range, Fire Rate, Rotation Speed, Weight.

**Items Interaction:**
- Two horizontal rows of icons.
- Items have rarities (border color).
- Hover shows tooltip with name, rarity, and effect.

---

## Implementation Plan

### Phase 1: Add Player Level System

**File:** `scripts/autoload/globals.gd`

1. Add leveling constants:
   ```gdscript
   const XP_PER_LEVEL_BASE: int = 100
   const XP_LEVEL_SCALE: float = 1.5  # XP needed increases per level
   ```

2. Add runtime state:
   ```gdscript
   var player_level: int = 1
   ```

3. Add helper functions:
   ```gdscript
   func get_xp_for_level(level: int) -> int
   func get_current_level_xp() -> int  # XP within current level
   func get_level_progress() -> float  # 0.0 to 1.0
   ```

**File:** `scripts/autoload/events.gd`

4. Add signal:
   ```gdscript
   signal player_leveled_up(new_level: int)
   ```

---

### Phase 2: Update Pause Menu Scene

**File:** `scenes/ui/hud.tscn`

Restructure `PauseMenu/Panel` with new layout:

```
PauseMenu/Panel/
├── HBoxContainer (main horizontal split)
│   ├── LeftPanel (VBoxContainer)
│   │   ├── Title ("PAUSED")
│   │   ├── LevelLabel ("Level: X")
│   │   ├── WaveLabel ("Wave: X/10")
│   │   ├── Spacer
│   │   ├── ResumeButton
│   │   ├── SettingsButton
│   │   └── QuitButton
│   │
│   └── RightPanel (VBoxContainer) - "StatsPanel"
│       ├── StatsTitle ("PLAYER STATS")
│       ├── HSeparator
│       └── StatsGrid (GridContainer, 2 columns)
│           ├── HealthLabel, HealthValue
│           ├── SpeedLabel, SpeedValue
│           ├── DamageLabel, DamageValue
│           ├── RangeLabel, RangeValue
│           ├── FireRateLabel, FireRateValue
│           ├── XPLabel, XPValue
│           ├── KillsLabel, KillsValue
│           └── TurretsLabel, TurretsValue
│
├── TurretsSection (VBoxContainer) - LARGER, middle section
│   ├── TurretsHeader (HBoxContainer)
│   │   ├── TurretsTitle ("TURRETS (3)")
│   │   └── TurretsHint ("Click turret for details")
│   ├── HSeparator
│   ├── TurretIconsRow (HBoxContainer) - always visible icons
│   │   └── TurretIconButton x N (TextureButton per turret type)
│   │       ├── Icon (turret sprite)
│   │       ├── CountBadge (Label "x2")
│   │       └── LockedOverlay (visible if count = 0)
│   └── TurretDetailsPanel (PanelContainer) - shows selected turret
│       ├── TurretName (Label "Basic Turret (x2)")
│       ├── HSeparator
│       └── TurretStatsContainer (HBoxContainer)
│           ├── BaseStatsVBox (VBoxContainer)
│           │   ├── Label ("Base Stats:")
│           │   ├── DamageRow, RangeRow, FireRateRow
│           │   ├── ProjSpeedRow, RotationRow
│           │   └── EffectiveDPS (Label)
│           └── UpgradesVBox (VBoxContainer)
│               ├── Label ("Upgrades:")
│               └── UpgradeRow x N (per upgrade type)
│
└── ItemsSection (VBoxContainer) - SMALLER, bottom section
    ├── ItemsTitle ("ITEMS (12)")
    ├── HSeparator
    ├── ItemsScrollContainer (ScrollContainer, horizontal)
    │   └── ItemsRow (HBoxContainer)
    │       └── ItemSlot x N (TextureRect with tooltip)
    └── ItemsHint ("No items collected" - visible when empty)
```

---

### Phase 3: Update HUD Script

**File:** `scripts/hud.gd`

1. Add new `@onready` references:
   ```gdscript
   @onready var level_label: Label = $PauseMenu/Panel/.../LevelLabel
   @onready var pause_wave_label: Label = $PauseMenu/Panel/.../WaveLabel
   @onready var stats_grid: GridContainer = $PauseMenu/Panel/.../StatsGrid
   @onready var items_container: HBoxContainer = $PauseMenu/Panel/.../ItemSlotContainer
   @onready var items_hint: Label = $PauseMenu/Panel/.../ItemsHint
   ```

2. Add `update_pause_menu_stats()` function:
   ```gdscript
   func update_pause_menu_stats() -> void:
       # Pull current values from Globals and player
       level_label.text = "Level: %d" % Globals.player_level
       pause_wave_label.text = "Wave: %d/%d" % [Globals.current_wave, Globals.MAX_WAVES]
       
       if player:
           # Update stats grid values
           stats_grid.get_node("HealthValue").text = "%d/%d" % [player.current_health, player.max_health]
           stats_grid.get_node("SpeedValue").text = "%d" % player.speed
           # ... etc
   ```

3. Call `update_pause_menu_stats()` in `toggle_pause()` when pausing.

---

### Phase 4: Turrets Panel (Icon Grid + Detail View)

**File:** `scripts/autoload/globals.gd`

1. Add turret type definitions and tracking:
   ```gdscript
   # Turret type registry
   const TURRET_TYPES: Dictionary = {
       "basic": {
           "name": "Basic Turret", 
           "icon": "🗼",
           "base_stats": {
               "damage": 15.0,
               "range": 400.0,
               "fire_rate": 2.0,
               "rotation_speed": 180.0,
               "weight": 10.0
           }
       },
       "flame": {
           "name": "Flame Turret", 
           "icon": "🔥",
           "base_stats": {
               "damage": 8.0,
               "range": 250.0,
               "fire_rate": 5.0,
               "rotation_speed": 120.0,
               "weight": 15.0
           }
       }
       # ... other types
   }
   
   var turret_counts: Dictionary = {}  # {"basic": 2, "flame": 1, etc.}
   var selected_turret_type: String = "basic"
   ```

**File:** `scripts/hud.gd`

2. Add turret icon and details functions:
   ```gdscript
   func update_turrets_panel() -> void:
       turrets_title.text = "TURRETS (%d)" % Globals.turrets_spawned
       
       # Update each icon's count badge and visibility
       for turret_type in Globals.TURRET_TYPES.keys():
           var btn := turret_icon_buttons[turret_type]
           var count: int = Globals.turret_counts.get(turret_type, 0)
           
           # Only show unlocked turrets
           btn.visible = count > 0
           btn.get_node("CountBadge").text = "x%d" % count
           
           # Auto-select first available if current selection is hidden
           if count > 0 and Globals.selected_turret_type == "":
               _on_turret_icon_pressed(turret_type)
       
       # Show details for selected turret
       if Globals.selected_turret_type != "":
           update_turret_details(Globals.selected_turret_type)
   
   func update_turret_details(turret_type: String) -> void:
       var config := Globals.TURRET_TYPES[turret_type]
       var stats := Globals.get_turret_stats(turret_type) # Applies item modifiers
       
       turret_details.get_node("TurretName").text = "%s (x%d)" % [config["name"], Globals.turret_counts[turret_type]]
       
       turret_details.get_node(".../DamageValue").text = "%.1f" % stats.damage
       turret_details.get_node(".../RangeValue").text = "%d" % stats.range
       turret_details.get_node(".../FireRateValue").text = "%.1f/s" % stats.fire_rate
       turret_details.get_node(".../RotationValue").text = "%d°/s" % stats.rotation_speed
       turret_details.get_node(".../WeightValue").text = "%d" % stats.weight
       turret_details.get_node(".../EffectiveDPS").text = "DPS: %.1f" % (stats.damage * stats.fire_rate)
   ```

---

### Phase 5: Items Panel (Two Rows)

**File:** `scripts/autoload/globals.gd`

1. Add items system definitions:
   ```gdscript
   enum ItemRarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, UNIQUE }
   
   const RARITY_COLORS = {
       ItemRarity.COMMON: Color.WHITE,
       ItemRarity.UNCOMMON: Color.GREEN,
       ItemRarity.RARE: Color.BLUE,
       ItemRarity.EPIC: Color.PURPLE,
       ItemRarity.LEGENDARY: Color.ORANGE,
       ItemRarity.UNIQUE: Color.RED
   }
   
   var collected_items: Array = []  # Array of Item objects/dicts
   ```

**File:** `scripts/hud.gd`

2. Add items grid with 2 rows:
   ```gdscript
   @onready var items_scroll: ScrollContainer = $PauseMenu/.../ItemsScrollContainer
   @onready var items_vbox: VBoxContainer = $PauseMenu/.../ItemsVBox
   @onready var items_row1: HBoxContainer = $PauseMenu/.../ItemsVBox/Row1
   @onready var items_row2: HBoxContainer = $PauseMenu/.../ItemsVBox/Row2
   
   func update_items_panel() -> void:
       var item_count := Globals.collected_items.size()
       items_title.text = "ITEMS (%d)" % item_count
       
       # Clear existing slots
       for child in items_row1.get_children(): child.queue_free()
       for child in items_row2.get_children(): child.queue_free()
       
       # Add item slots, distributing between two rows
       for i in range(item_count):
           var item = Globals.collected_items[i]
           var slot := create_item_slot(item)
           
           # Alternate rows or fill row 1 then row 2? 
           # "10 items per row" -> Fill row 1 until 10, then row 2?
           # Or just alternate for balance. Let's fill sequentially for now.
           if i % 2 == 0:
               items_row1.add_child(slot)
           else:
               items_row2.add_child(slot)
   
   func create_item_slot(item: Dictionary) -> Control:
       var slot := TextureRect.new()
       slot.custom_minimum_size = Vector2(40, 40)
       slot.texture = load(item.icon_path)
       slot.self_modulate = Globals.RARITY_COLORS[item.rarity] # Border/BG color
       slot.tooltip_text = "%s (%s)\n%s" % [item.name, item.rarity_name, item.description]
       return slot
   ```

---

### Phase 6: Scene Structure Updates

**File:** `scenes/ui/hud.tscn`

Updated PauseMenu scene structure (vertical stacking):
```
PauseMenu/Panel/MainVBox/
├── TopSection (HBoxContainer) - compact
│   ├── LeftPanel (buttons, level, wave)
│   └── StatsPanel (player stats grid)
│
├── TurretsSection (VBoxContainer) [size_flags_vertical = EXPAND_FILL] - LARGE
│   ├── TurretsHeader (HBoxContainer)
│   │   ├── TurretsTitle (Label "TURRETS (3)")
│   │   └── TurretsHint (Label "Click turret for details")
│   ├── HSeparator
│   ├── TurretIconsRow (HBoxContainer) [separation = 8]
│   │   └── TurretIconButton x N (TextureButton, 48x48)
│   │       ├── Icon (TextureRect)
│   │       ├── CountBadge (Label, anchored bottom-right)
│   │       └── LockedOverlay (ColorRect, semi-transparent)
│   └── TurretDetailsPanel (PanelContainer) [custom_minimum_size.y = 150]
│       └── TurretDetailsVBox (VBoxContainer)
│           ├── TurretName (Label)
│           ├── HSeparator
│           └── StatsHBox (HBoxContainer)
│               ├── BaseStatsVBox
│               └── UpgradesVBox
│
└── ItemsSection (VBoxContainer) [custom_minimum_size.y = 100] - SMALL
    ├── ItemsTitle (Label "ITEMS (22)")
    ├── HSeparator
    ├── ItemsScrollContainer (ScrollContainer) [horizontal, custom_minimum_size.y = 90]
    │   └── ItemsVBox (VBoxContainer)
    │       ├── Row1 (HBoxContainer) [separation = 4]
    │       └── Row2 (HBoxContainer) [separation = 4]
    └── ItemsHint (Label "No items collected")
```

---

## Files to Modify

| File | Changes |
|------|---------|
| `scripts/autoload/globals.gd` | Add level system, `TURRET_TYPES` registry, `turret_counts` dict, `selected_turret_type`, `collected_items` array, `get_turret_stats()` helper |
| `scripts/autoload/events.gd` | Add `player_leveled_up` signal |
| `scenes/ui/hud.tscn` | Restructure PauseMenu: top row (buttons+stats), turrets section (icons + details), items section (horizontal scroll) |
| `scripts/hud.gd` | Add `setup_turret_icons()`, `update_turrets_panel()`, `update_turret_details()`, `update_items_panel()`, turret icon click handler |

---

## Dependencies

- Player node must be accessible when pause menu opens
- `Globals` must contain all runtime stats before pause
- Turret spawner must update `Globals.turret_counts[type]` when spawning
- Turret types must be registered in `Globals.TURRET_TYPES`

---

## Future Enhancements (Post-MVP)

- Turret upgrade system integration (show upgrade levels in detail panel)
- Item tooltips with rich formatting (rarity colors, stat bonuses)
- Item stacking for duplicate items with count badge
- Keyboard navigation for turret selection (arrow keys)
- Turret preview animation on hover
- Item filtering/sorting (by type, rarity, recent)
- Compare mode: show stat deltas from items/upgrades
