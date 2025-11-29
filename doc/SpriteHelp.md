# Sprite Creation Guide for Turret Survivor

> A quickstart guide for creating pixel art sprites using PixelLab AI.

---

## Quick Reference

| Asset Type | Recommended Size | PixelLab Tool | Directions | Animation |
|------------|------------------|---------------|------------|-----------|
| Player | 64-96 px | `create_character` | 8 | walk, idle |
| Enemy (basic) | 64 px | `create_character` | 8 | walk |
| Enemy (boss) | 96-128 px | `create_character` | 8 | walk |
| Turret | 48-64 px | `create_map_object` | 1 | idle (optional) |
| Projectile | 16-24 px | `create_map_object` | 1 or 4 | - |
| Pickup/Drop | 24-32 px | `create_map_object` | 1 | - |
| Tile/Ground | 32 px | `create_topdown_tileset` | - | - |
| Map Object | 48-96 px | `create_map_object` | 1 | - |

---

## Understanding Sprite Sizes

### Canvas Size vs Character Size
When you specify a size in PixelLab, that's the **canvas size**, not the character size:
- Character fills ~60% of the canvas height
- 48px canvas → ~29px tall character
- 32px canvas → ~19px tall character

### Size Guidelines for This Game

**High Quality / High Resolution Approach:**
For crisp, detailed sprites at 1080p that are easy to see:

| Quality Level | Canvas Size | Best For |
|---------------|-------------|----------|
| Small | 32px | Tiny pickups, particles |
| Medium | 48px | Projectiles, small objects |
| Standard | 64px | Basic enemies, turrets |
| Large | 96px | Player, important enemies |
| Boss | 128px | Boss enemies, major NPCs |

**Why Bigger is Better for This Game:**
- Arena is 1920×1080 - sprites need presence
- Top-down view means you see full character
- More pixels = more detail for the AI to work with
- Easier to see during fast gameplay

**Recommended Scale:**
- Player: **64-96px** (hero should stand out)
- Basic Enemy: **64px** (visible but not dominating)
- Tank Enemy: **80-96px** (bigger = tougher visual cue)
- Mini/Swarm Enemy: **48px** (smaller = weaker visual cue)
- Turrets: **48-64px** (functional, clear)
- Projectiles: **16-24px** (fast, visible)

---

## Sprite Types Explained

### 1. Characters (Player, Enemies)
**Use:** `create_character` with `n_directions: 8`

Characters need **8 directional views** for smooth top-down movement:
- South (facing down/camera)
- North (facing up/away)
- East, West (left/right)
- SE, SW, NE, NW (diagonals)

**Parameters to specify:**
```
- description: What the character looks like
- size: Canvas size (32, 48, or 64)
- n_directions: 8 for full movement
- view: "high top-down" for this game
- detail: "medium detail" or "high detail"
- outline: "single color black outline" (crisp edges)
- shading: "basic shading" or "medium shading"
```

### 2. Static Objects (Turrets, Pickups)
**Use:** `create_map_object`

Objects that don't rotate or have one facing:
- Turrets (rotate programmatically)
- XP orbs, health pickups
- Decorations

**Parameters to specify:**
```
- description: What the object looks like
- width/height: Canvas dimensions
- view: "high top-down" 
- detail: "medium detail" or "high detail"
- outline: "single color outline"
```

### 3. Tilesets (Ground, Terrain)
**Use:** `create_topdown_tileset`

For seamless ground textures:
- Arena floor
- Different terrain zones
- Obstacles

---

## How to Instruct Me (Prompt Guide)

### Good Prompt Structure

```
Create a [ASSET TYPE] for [PURPOSE]:
- Style: [VISUAL STYLE]
- Details: [SPECIFIC FEATURES]
- Colors: [COLOR PALETTE]
- Size: [CANVAS SIZE]
- Quality: [DETAIL LEVEL]
```

### Example Prompts

**Player Character:**
```
Create a player character sprite set:
- Style: minimalist sci-fi, top-down
- Details: space marine in blue armor, glowing visor, 
  jetpack on back, holding energy pistol
- Colors: blue and silver with cyan glow accents
- Size: 48px canvas
- Quality: high detail, 8 directions, walking animation
```

**Turret:**
```
Create a turret sprite:
- Style: military/industrial, top-down
- Details: rotating gun platform, dual barrels, 
  armored base, LED indicator lights
- Colors: dark green military with yellow hazard stripes
- Size: 32px
- Quality: medium detail, single view (we rotate in code)
```

**Projectile:**
```
Create a projectile sprite:
- Style: energy/plasma bolt
- Details: glowing core, motion trail effect
- Colors: bright cyan/blue with white center
- Size: 12px
- Quality: simple, maybe 4 rotation frames
```

### Key Descriptors to Use

**For Style:**
- "minimalist" - clean, simple shapes
- "detailed" - more visual complexity
- "sci-fi / futuristic" - tech aesthetic
- "military / industrial" - rugged, functional
- "cute / chibi" - rounded, friendly proportions

**For Proportions (characters):**
- `"chibi"` - big head, small body (current enemy style)
- `"default"` - balanced proportions
- `"heroic"` - larger shoulders, smaller head

**For Shading:**
- `"flat shading"` - no gradients, retro look
- `"basic shading"` - subtle depth (current style)
- `"medium shading"` - more 3D appearance
- `"detailed shading"` - maximum depth/lighting

**For Outlines:**
- `"single color black outline"` - crisp, classic pixel art
- `"selective outline"` - outline only on edges
- `"lineless"` - no outline, softer look

---

## Recommended Workflow

### 1. Plan Your Asset List
Before creating sprites, list what you need:

```
Priority 1 (Gameplay):
□ Player (8-dir + walk animation)
□ Basic enemy (done! ✓)
□ Turret base
□ Projectile (bullet)

Priority 2 (Polish):
□ Different enemy types (use tints for now)
□ XP orb pickup
□ Health pickup
□ Turret variations

Priority 3 (Environment):
□ Arena floor tileset
□ Arena border/walls
□ Decorative objects
```

### 2. Establish Visual Consistency
Pick a style and stick to it:

**Current Style (Robot Enemy):**
- Canvas: **64px** (recommended new standard)
- View: high top-down
- Outline: single color black
- Shading: basic or medium
- Proportions: chibi or default
- Palette: metallic grays with colored accents

> ⚠️ **Note:** Current robot enemy was created at 32px - consider regenerating at 64px for consistency.

### 3. Create in Batches
Group similar assets:
1. All characters first (same settings)
2. All pickups (same size/style)
3. Environment last

### 4. Test In-Game Early
Import after each batch to check:
- Scale looks right
- Style matches existing assets
- Colors work with game background

---

## PixelLab Limitations to Know

### Trial Limits
- Character creation: unlimited(ish)
- Animations: limited on trial
- Workaround: Create static sprites, animate programmatically

### What Works Best
- Clear, specific descriptions
- Consistent style parameters
- **64-96px canvas sizes** for main game elements
- Top-down view for this game type

### Current Assets

| Asset | Status | Size | Location |
|-------|--------|------|----------|
| Robot Enemy (8-dir) | ⚠️ Too small (32px) | 32px | `assets/sprites/enemy/` |
| Player | ❌ Needed | 64-96px | - |
| Turret | ❌ Needed | 48-64px | - |
| Projectile | ❌ Needed | 16-24px | - |

> **Recommendation:** Regenerate the robot enemy at 64px before creating other assets to establish consistent scale.

---

## Quick Commands for Me

When you want sprites, just tell me:

**Simple:**
> "Create a player sprite, sci-fi soldier style, 48px, high quality"

**Detailed:**
> "Create a fire turret sprite: red/orange metal, flame effects on barrel, industrial style, 32px, matches the robot enemy aesthetic"

**Batch:**
> "Create sprites for all 3 projectile types: normal (yellow), fire (orange), electric (blue), 12px each"

I'll handle the PixelLab parameters and download the files to the right folders!

---

## File Organization

```
assets/sprites/
├── player/
│   ├── player_south.png
│   ├── player_north.png
│   └── ... (8 directions)
├── enemy/
│   ├── enemy_south.png (current robot)
│   └── ... (8 directions)
├── turret/
│   ├── turret_normal.png
│   ├── turret_fire.png
│   └── ...
├── projectile/
│   ├── bullet_normal.png
│   └── ...
└── pickup/
    ├── xp_orb.png
    └── health.png
```

---

## Next Steps

Ready to create more sprites? Here's what I'd suggest next:

1. **Player character** - You need this to replace the placeholder
2. **Normal turret** - Core gameplay element
3. **Basic projectile** - Visual feedback for shooting

Just tell me what style you want and I'll create them!
