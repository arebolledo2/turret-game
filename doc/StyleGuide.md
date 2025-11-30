# Turret Survivor - Visual Style Guide

> Definitive art direction for all game assets.

---

## Core Aesthetic

**Theme:** Sci-Fi Space Survival  
**Mood:** Futuristic, Cute, Elegant, Sleek  
**Quality:** High Resolution, High Detail  
**Temperature:** Cool (blues, cyans, silvers dominate)  
**Environment:** Bright, clean sci-fi facility

---

## Style Pillars

| Pillar | Description |
|--------|-------------|
| **Futuristic** | Clean technology, holographic elements, glowing accents |
| **Cute** | Stylized proportions, rounded shapes, approachable characters |
| **Elegant** | Minimalist designs, smooth curves, refined details |
| **Sleek** | Polished surfaces, streamlined silhouettes, modern aesthetic |

---

## Technical Standards

### Canvas Sizes

| Asset Type | Canvas Size | Notes |
|------------|-------------|-------|
| Player | 128px | Hero presence, high detail |
| Standard Enemy | 128px | Clear visibility |
| Mini/Swarm Enemy | 96px | Smaller = weaker visual cue |
| Tank/Boss Enemy | 192px | Bigger = tougher visual cue |
| Turret | 128px | Functional clarity |
| Projectile | 32-48px | Fast, visible |
| Pickup/Drop | 64px | Collectible size |

### PixelLab Parameters

```
view: "high top-down"
detail: "high detail"
outline: "single color black outline"
shading: "medium shading"
proportions: "chibi"
ai_freedom: 100-200 (for specific designs)
n_directions: 4 (N, E, S, W recommended per batch)
```

> **Why "chibi" proportions:** Creates a cohesive cute aesthetic that matches our "Cute" style pillar. Chibi's exaggerated features (large heads, small bodies) enhance readability and personality at top-down gameplay distances.

> **Batch Size Limit:** Only queue 4-5 directions/animations at a time. PixelLab can fail on larger batches (e.g., 8 directions). Generate N, E, S, W first, then queue the diagonals separately.

### Top-Down Animation Guidelines

For sprites that animate well in a top-down game:

#### Symmetry & Rotation
- **Radial symmetry preferred** — Turrets, pickups, and explosions should look good from any angle
- **Bilateral symmetry** — Characters facing "south" (toward camera) can be mirrored for left/right movement
- **Avoid strong directional shadows** — Use ambient/top-down lighting so rotation doesn't look wrong
- **Center the subject** — Keep the sprite centered in the canvas for clean rotation pivots

#### Prompt Keywords for Top-Down Success
```
ALWAYS include:
- "top-down view" or "bird's eye view" or "overhead view"
- "centered in frame"
- "symmetrical design" (for turrets/pickups)
- "flat lighting" or "ambient lighting" (avoids directional shadow issues)

For turrets/stationary objects:
- "circular base"
- "radially symmetric"
- "rotatable design"

For characters (player/enemies):
- "facing forward" or "facing camera" or "facing south"
- "clear silhouette from above"
- "visible from overhead"
```

#### Animation-Friendly Design Principles

| Element | Good for Animation | Avoid |
|---------|-------------------|-------|
| Base shape | Circular, octagonal | Square (corners look odd when rotated) |
| Lighting | Even, ambient, top-lit | Strong side shadows |
| Details | Centered, symmetrical | Off-center elements that break rotation |
| Outline | Consistent weight | Varying thickness |
| Pose | Neutral, balanced | Dynamic poses (hard to transition) |

#### Turret-Specific Animation Notes
Turrets rotate to aim at enemies, so:
- **Separate base and barrel conceptually** — The base stays fixed, barrel rotates
- **Circular base is essential** — Looks correct at any rotation angle
- **Barrel should point "up" (north)** — We rotate the sprite to aim
- **Avoid ground shadows** — They don't rotate with the sprite

Example turret prompt addition:
```
"circular base, barrel pointing up, no ground shadow, 
centered in frame, designed for rotation"
```

#### Character Animation Notes
Characters move in 4-8 directions:
- **Generate a "south-facing" base frame** — Facing the camera
- **Use mirroring for east/west** — Only need to generate north, south, east
- **Keep limbs in neutral position** — Easier to create walk cycles
- **Consistent silhouette** — Should be recognizable from all angles

Example character prompt addition:
```
"facing south toward camera, neutral standing pose,
symmetrical body, clear overhead silhouette"
```

### Prompt Writing Guidelines

> **Be Creative and Verbose:** When generating assets, write detailed, imaginative prompts. We want our art to be **distinctive and memorable**, not generic. Include personality traits, specific design details, material descriptions, and unique flourishes. The more evocative the prompt, the more character the resulting sprite will have.

### Breaking Humanoid Assumptions

When creating non-humanoid characters (like our headless player), the AI tends to add heads/faces. To prevent this:

1. **Reframe the concept** — Use "turret platform", "mobile base", "walking pedestal" instead of "robot"
2. **Explicit negations** — Include "NOT a robot", "NOT humanoid", "NO head", "NO face on top"
3. **Alternative comparisons** — "Like a walking ammunition crate", "barrel-shaped base"
4. **Minimum AI freedom** — Use `ai_freedom: 100` for strict prompt adherence
5. **Custom proportions** — Set `head_size: 0.5` to minimize any head that might appear

### Custom Proportion Settings

For non-standard character shapes, use custom proportions:

```json
{
  "type": "custom",
  "head_size": 0.5,      // 0.5 = smallest (good for headless)
  "arms_length": 0.5,    // 0.5 = no/minimal arms
  "legs_length": 0.5,    // 0.5 = stubby legs
  "shoulder_width": 1.5, // 1.5 = wide barrel body
  "hip_width": 1.2       // 1.2 = sturdy base
}
```

### AI Freedom Scale

| Value | Behavior | Use Case |
|-------|----------|----------|
| 100 | Strict | Specific designs, non-humanoid shapes |
| 250 | Conservative | Minor creative additions |
| 500 | Balanced | General concepts |
| 750+ | Creative | Exploratory, let AI surprise you |

---

## Color Palette

### Temperature: Cool-Dominant
The game uses a **cool color temperature** as the foundation. Blues, cyans, and silvers establish the friendly/tech baseline. Warm colors (orange, red) are reserved for **danger and enemies** to create clear visual contrast.

### Primary Colors

| Role | Color | Hex | Usage |
|------|-------|-----|-------|
| Player/Friendly | Cyan | `#00FFFF` | Player glow, turrets, UI |
| Tech/Energy | Electric Blue | `#0080FF` | Shields, power sources |
| Danger/Enemy | Hot Orange | `#FF6600` | Enemy accents, warnings |
| Health/Positive | Soft Green | `#00FF80` | Healing, XP, buffs |

### Material Colors

| Material | Base | Highlight | Shadow |
|----------|------|-----------|--------|
| Chrome/Metal | `#A0A0B0` | `#E0E0F0` | `#606070` |
| White Alloy | `#D0D0E0` | `#FFFFFF` | `#A0A0B0` |
| Dark Alloy | `#404050` | `#707080` | `#202030` |
| Glass/Visor | `#80C0FF` | `#FFFFFF` | `#4080C0` |

### Damage Type Colors

| Type | Primary | Glow |
|------|---------|------|
| Physical | Silver `#C0C0C0` | White `#FFFFFF` |
| Fire | Orange `#FF6600` | Yellow `#FFCC00` |
| Electric | Cyan `#00FFFF` | White `#FFFFFF` |
| Plasma | Magenta `#FF00FF` | Pink `#FF80FF` |

---

## Character Design

### Player (Friendly Robot)
- **Identity:** Cute helper robot with legs
- **Silhouette:** Cylindrical body, visible legs, flat top (turret dock)
- **Features:** Funny/expressive single eye or face, stubby legs, antenna
- **Body:** Cylindrical base with flat top that turrets plug into
- **Colors:** White/chrome body with cyan accents and glow
- **Personality:** Goofy, endearing, clearly the hero
- **Read:** Friendly robot, distinct from enemies

> **Turret Carry System:** Player has a cylindrical top with a port/socket. When carrying a turret, it visually docks on top of the player.

### Enemies (Hostile Robots)
- **Identity:** Evil machines / drones
- **Silhouette:** Rounded mechanical bodies, visible joints
- **Features:** Glowing orange eyes/sensors, antenna, metallic plating
- **Colors:** Dark metal with orange/red danger accents
- **Personality:** Menacing but still cute
- **Read:** Robotic, threatening, clearly NOT the player

> **Differentiators from Player:** Darker colors, warm (orange) accents, no legs (hover/roll), angry expression

### Turrets (Friendly Tech)
- **Identity:** Player's automated allies / power-ups
- **Silhouette:** Circular base (for clean rotation), prominent weapon on top
- **Features:** Rotating barrel pointing up, cyan status lights, armored housing
- **Base:** Circular bottom that works when rotated to any angle
- **Colors:** Chrome/white base with cyan glow (matches player)
- **Animation:** Base is static, barrel/weapon rotates to aim
- **Read:** Friendly, powerful, visually compatible with player

> **Rotation Requirement:** Turrets must have circular/radially symmetric bases since they rotate to aim at enemies. Avoid square bases or asymmetric details that look wrong at 45° angles.

---

## Visual Effects

### Glow Style
Glow effects are **moderate intensity**—visible and readable but not overwhelming. Think "clean tech" rather than "neon rave."

- Player/Turrets: Soft cyan glow
- Enemies: Orange eye glow
- Projectiles: Core glow matching damage type
- Pickups: Gentle pulse animation

### Animation Style
- Smooth, fluid movement
- Subtle idle animations (breathing, hovering)
- Impactful hit feedback (flash, shake)

---

## Environment

### Arena (Bright Sci-Fi Facility)
- **Floor:** Light-colored space station panels, clean white/gray
- **Details:** Subtle grid lines, glowing blue trim
- **Lighting:** Well-lit, no dark corners
- **Mood:** Sterile, high-tech, spacious

### Visual Hierarchy
1. **Player** — Brightest, cyan accents (always visible)
2. **Enemies** — Orange/warm accents (clearly threats)
3. **Turrets** — Cyan accents (clearly friendly)
4. **Pickups** — Green glow (clearly beneficial)
5. **Environment** — Neutral, doesn't compete

---

## Do's and Don'ts

### ✅ Do
- Use cyan for player/friendly, orange for enemies
- Keep silhouettes readable at gameplay distance
- Maintain cool color temperature as baseline
- Use consistent proportions ("default" in PixelLab)
- Make the arena bright and clean

### ❌ Don't
- Use warm colors for friendly elements
- Create dark, moody, hard-to-read sprites
- Mix drastically different art styles
- Use overpowering glow effects
- Make enemies look friendly or player look threatening

---

## Asset Checklist

| Asset | Status | Notes |
|-------|--------|-------|
| Robot Enemy (8-dir) | ✅ Created | Consider 64px regeneration |
| Player Robot | ❌ Needed | Cylindrical, legs, funny, cyan |
| Normal Turret | ❌ Needed | Cylindrical base, plugs into player |
| Projectiles | ❌ Needed | Per damage type |
| XP Orb | ❌ Needed | Green glow |

---

## Example Prompts

### Base Prompt Template
All prompts should follow this structure:
```
[Subject description], [key visual features], [colors/materials],
[style keywords], high detail, top-down view, centered in frame,
single color black outline, medium shading, [background]
```

### Turrets (Rotatable)

**Normal Turret:**
```
Automated defense turret, circular chrome base, dual barrels pointing up,
glowing cyan status lights, white and silver metal, futuristic military,
cute sleek design, high detail, top-down view, centered in frame,
circular symmetrical base, designed for rotation, no ground shadow,
single color black outline, medium shading, magenta background
```

**Flamethrower Turret:**
```
Flamethrower turret, circular chrome base, flame nozzle pointing up,
orange fuel tank with warning stripes, white silver body with heat vents,
futuristic military sci-fi, cute elegant sleek design, high detail,
top-down view, centered in frame, radially symmetric base,
designed for rotation, no ground shadow, single color black outline,
medium shading, magenta background
```

**Tesla/Electric Turret:**
```
Tesla coil turret, circular chrome base, electric spire pointing up,
crackling cyan energy arcs, white and silver with blue capacitors,
futuristic sci-fi, cute sleek design, high detail, top-down view,
centered in frame, radially symmetric, designed for rotation,
no ground shadow, single color black outline, medium shading,
magenta background
```

### Characters (Directional)

**Player:**
```
Cute friendly robot with stubby legs, cylindrical chrome body,
flat top with docking port, single expressive eye, antenna,
white and cyan colors, funny endearing personality,
futuristic sci-fi, high detail, top-down view, facing south toward camera,
neutral standing pose, symmetrical body, clear overhead silhouette,
centered in frame, single color black outline, medium shading,
magenta background
```

**Enemy (Basic):**
```
Hostile robot drone, rounded mechanical body, glowing orange eyes,
small antenna, dark gunmetal with orange danger accents, hovering,
menacing but cute, futuristic sci-fi, high detail, top-down view,
facing south toward camera, symmetrical body, clear overhead silhouette,
centered in frame, single color black outline, medium shading,
magenta background
```

### Pickups (Symmetric)

**XP Orb:**
```
Glowing energy orb, soft green crystal sphere, floating,
subtle inner glow, sci-fi pickup item, clean simple design,
high detail, top-down view, centered in frame, radially symmetric,
single color black outline, medium shading, magenta background
```

**Health Pickup:**
```
Glowing health pack, cyan energy core, floating medical container,
futuristic first aid, clean sci-fi design, high detail, top-down view,
centered in frame, radially symmetric, single color black outline,
medium shading, magenta background
```

### Projectiles (Small, Symmetric)

**Bullet (Physical):**
```
Glowing energy bullet, silver core with white trail, small projectile,
futuristic ammo, clean simple design, 32px sprite, top-down view,
centered, radially symmetric, single color black outline, magenta background
```

**Fireball (Fire):**
```
Flaming projectile, orange fire core with yellow glow, small fireball,
futuristic plasma, clean design, 32px sprite, top-down view,
centered, radially symmetric, single color black outline, magenta background
```

---

*Last updated: November 2025*
