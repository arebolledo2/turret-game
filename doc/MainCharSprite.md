# Main Character Sprite Plan

## Character Summary
**Cute friendly robot with legs** — cylindrical chrome body, flat top with docking port, single expressive eye, stubby walking legs. White/cyan colors. Funny, goofy hero.

---

## Sprite Requirements

### Base Player (No Turret)

| Asset | Canvas | Directions | Frames | Notes |
|-------|--------|------------|--------|-------|
| Idle | 64px | 8-dir | 1 | Standing, eye blinking optional |
| Walk | 64px | 8-dir | 4 | Leg cycle animation |

### Player + Turret Carried (Per Turret Type)

| Turret | Glow Color | Visual Notes |
|--------|------------|--------------|
| Normal | Cyan `#00FFFF` | Standard barrel, chrome |
| Sniper | Cyan `#00FFFF` | Long barrel, scope lens |
| Fire | Orange `#FF6600` | Nozzle tip, heat glow |
| Plasma | Magenta `#FF00FF` | Orb chamber, energy glow |
| Shock | Cyan `#00FFFF` | Tesla coils, arc sparks |
| Tesla | Cyan `#00FFFF` | Antenna array, chain nodes |

Each turret variant needs: **Idle (1 frame) + Walk (4 frames) × 8 directions**

---

## Approach: Composite In-Engine ✓

Generate player and turrets separately, composite at runtime.

**Pros:** Fewer sprites, easier iteration, dynamic layering  
**Implementation:**
```gdscript
# In player.gd — turret sprite follows player, offset to "dock" position
carried_turret_sprite.position = Vector2(0, -8)  # Above player head
carried_turret_sprite.z_index = 1  # Render on top
```

---

## PixelLab Parameters

```
view: "high top-down"
detail: "high detail"
outline: "single color black outline"
shading: "medium shading"
proportions: "default"
size: 64
n_directions: 8
```

---

## Prompts

### Base Player
```
Cute friendly robot with legs, cylindrical chrome body, 
flat top with circular docking port, single expressive eye, 
stubby walking legs, small antenna, white and cyan colors, 
funny looking, futuristic sci-fi
```

### Player + Normal Turret
```
Cute friendly robot with legs carrying a turret on its head,
cylindrical chrome body, dual-barrel turret mounted on flat top,
single expressive eye, stubby walking legs, white and cyan colors,
turret has glowing cyan lights, futuristic sci-fi
```

### Player + Fire Turret
```
Cute friendly robot with legs carrying a flamethrower turret,
cylindrical chrome body, fire nozzle turret on head with orange glow,
single expressive eye, stubby walking legs, white body with orange accents,
heat shimmer effect, futuristic sci-fi
```

### Player + Plasma Turret
```
Cute friendly robot with legs carrying a plasma cannon,
cylindrical chrome body, glowing magenta orb turret mounted on head,
single expressive eye, stubby walking legs, white body with pink/magenta glow,
energy chamber visible, futuristic sci-fi
```

---

## Checklist

### Phase 1: Base Player
- [x] **1.1** Create base character — 8-dir idle rotations ✓ `fc1544b1-a5f0-45ea-92d5-0bfb31b2af8c`
- [x] **1.2** Generate walk animation — ⚠️ Trial limit (using idle frames)
- [x] **1.3** Download & assemble spritesheet ✓ `player_base.png` (512x64)
- [x] **1.4** Update `player.tscn` — new texture, hframes=8, vframes=1
- [x] **1.5** Update `player.gd` — 8-dir animation logic via `get_direction_from_vector()`

### Phase 2: Turret Top Sprites (Composite Approach)
- [ ] **2.1** Generate Normal turret top-sprite (8-dir, 32px)
- [ ] **2.2** Generate Sniper turret top-sprite (8-dir, 32px)
- [ ] **2.3** Generate Fire turret top-sprite (8-dir, 32px)
- [ ] **2.4** Generate Plasma turret top-sprite (8-dir, 32px)
- [ ] **2.5** Generate Shock turret top-sprite (8-dir, 32px)
- [ ] **2.6** Generate Tesla turret top-sprite (8-dir, 32px)
- [ ] **2.7** Add `CarriedTurretSprite` node to player scene
- [ ] **2.8** Create turret sprite lookup by `turret_type`
- [ ] **2.9** Update `update_carried_turret_position()` to show/hide sprite
- [ ] **2.10** Match turret sprite direction to player facing

### Phase 3: Polish
- [ ] **3.1** Test all directions look correct
- [ ] **3.2** Verify animation timing feels good
- [ ] **3.3** Confirm turret glow colors match damage types

---

## File Structure (Target)

```
assets/sprites/player/
├── player_base.png           # 8-dir × 5 frames (idle + 4 walk)
├── turret_top_normal.png     # 8-dir, 32px
├── turret_top_sniper.png
├── turret_top_fire.png
├── turret_top_plasma.png
├── turret_top_shock.png
└── turret_top_tesla.png
```

---

## Technical Notes

- **Direction order:** S, SW, W, NW, N, NE, E, SE (PixelLab 8-dir)
- **Current offset:** `TURRET_CARRY_OFFSET` in globals — adjust for visual docking
- **Z-index:** Carried turret renders above player body
- **Glow colors:** Match `DamageType` colors from StyleGuide

---

*Created: Nov 2025*
