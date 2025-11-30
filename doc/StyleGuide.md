# Turret Survivor - Visual Style Guide

> Definitive art direction for all game assets.

---

## Core Aesthetic

**Theme:** Sci-Fi Space Survival  
**Mood:** Futuristic, Cute, Elegant, Sleek  
**Quality:** High Resolution, High Detail  
**Temperature:** Cool (blues, cyans, silvers dominate)  
**Environment:** Bright, clean sci-fi facility  
**Perspective:** Side-view 2D (Binding of Isaac / Brotato style)

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

### PixelLab Parameters

```
view: "side view"
detail: "high detail"
outline: "single color black outline"
shading: "medium shading"
proportions: "chibi"
ai_freedom: 100-200 (for specific designs)
n_directions: 2 (left, right for characters)
```

> **Why "chibi" proportions:** Creates a cohesive cute aesthetic that matches our "Cute" style pillar. Chibi's exaggerated features (large heads, small bodies) enhance readability and personality at gameplay distances.

> **Batch Size Limit:** Only queue 4-5 animations at a time. PixelLab can fail on larger batches.

### Side-View Animation Guidelines

Although the game plays on a 2D top-down plane, all sprites are rendered in **side-view perspective** (like Binding of Isaac or Brotato). This creates a charming 2D aesthetic where characters appear to exist in a flat world.

#### Character Movement (Left/Right Only)
- **Two directions only** — Characters need left-facing and right-facing sprites
- **Mirror for efficiency** — Generate one direction, flip horizontally for the other
- **Walk/run cycles** — Simple 2-4 frame animations for movement
- **Idle animation** — Subtle breathing or bobbing

#### Turret Design (Omnidirectional Firing)
Turrets are stationary but must visually support firing in any direction:
- **Barrel/weapon should be animatable** — Can rotate or point in different directions
- **Consider separate layers** — Base (static) + weapon (can be rotated programmatically)
- **Design for flexibility** — Weapon should look good pointing left, right, up, or diagonally
- **Side-view perspective** — Show the turret from the side like all other assets

#### Prompt Keywords for Side-View Success
```
ALWAYS include:
- "side view" or "profile view" or "2D side perspective"
- "centered in frame"
- "flat 2D style"

For characters (player/enemies):
- "facing right" or "facing left"
- "side profile"
- "walk cycle ready" (for animated sprites)

For turrets:
- "side view"
- "weapon can aim in multiple directions"
- "modular design"

For pickups/projectiles:
- "side view"
- "centered"
```

#### Animation-Friendly Design Principles

| Element | Good for Animation | Avoid |
|---------|-------------------|-------|
| Pose | Clear side profile | 3/4 views or ambiguous angles |
| Limbs | Separated, visible joints | Overlapping parts that break animation |
| Outline | Consistent weight | Varying thickness |
| Details | Readable at small sizes | Overly complex details |
| Silhouette | Distinct, recognizable | Blob-like shapes |

#### Character Animation Notes
Characters move left and right only:
- **Generate right-facing sprites** — Flip horizontally for left-facing
- **Keep limbs separated** — Easier to animate walk cycles
- **Consistent silhouette** — Should be recognizable when moving
- **Idle poses** — Neutral stance that transitions smoothly to walk

Example character prompt addition:
```
"side view, facing right, neutral standing pose,
clear side profile, walk cycle ready, 2D flat style"
```

#### Turret Animation Notes
Turrets need to fire in any direction on the 2D plane:
- **Side-view base** — The turret body is shown from the side
- **Flexible weapon mount** — Design so the barrel/weapon can be rotated in code
- **Consider visual feedback** — Muzzle flash, recoil animations

Example turret prompt addition:
```
"side view, turret with rotatable weapon mount,
weapon pointing right, modular design for animation"
```

### Prompt Writing Guidelines

> **Be Creative and Verbose:** When generating assets, write detailed, imaginative prompts. We want our art to be **distinctive and memorable**, not generic. Include personality traits, specific design details, material descriptions, and unique flourishes. The more evocative the prompt, the more character the resulting sprite will have.

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
- **Identity:** Cute helper robot
- **Silhouette:** Rounded body, visible limbs, expressive
- **Features:** Funny/expressive single eye or face, stubby legs, antenna
- **Colors:** White/chrome body with cyan accents and glow
- **Personality:** Goofy, endearing, clearly the hero
- **Animation:** Left/right walk cycle, idle bobbing
- **Read:** Friendly robot, distinct from enemies

### Enemies (Hostile Robots)
- **Identity:** Evil machines / drones
- **Silhouette:** Rounded mechanical bodies, visible joints
- **Features:** Glowing orange eyes/sensors, antenna, metallic plating
- **Colors:** Dark metal with orange/red danger accents
- **Personality:** Menacing but still cute
- **Animation:** Left/right movement, idle animation
- **Read:** Robotic, threatening, clearly NOT the player

> **Differentiators from Player:** Darker colors, warm (orange) accents, angry expression

### Turrets (Friendly Tech)
- **Identity:** Player's automated allies / power-ups
- **Silhouette:** Solid base with prominent weapon on top
- **Features:** Rotatable barrel/weapon, cyan status lights, armored housing
- **Colors:** Chrome/white base with cyan glow (matches player)
- **Animation:** Weapon rotates to aim, muzzle flash on fire
- **Design:** Side-view but weapon can programmatically aim in any direction
- **Read:** Friendly, powerful, visually compatible with player

> **Omnidirectional Firing:** Turrets are shown from the side, but the weapon mount should be designed so it can be rotated in code to fire in any direction on the 2D plane.

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
| Robot Enemy (left/right) | ❌ Needed | Side-view, walk animation |
| Player Robot (left/right) | ❌ Needed | Side-view, walk/idle animation |
| Normal Turret | ❌ Needed | Side-view, rotatable weapon |
| Projectiles | ❌ Needed | Per damage type |
| XP Orb | ❌ Needed | Green glow |

---

## Prompt Template

Use this template when generating any asset to ensure consistency:

### Template Fields
```
[SUBJECT]:    What the asset is (e.g., "Player robot character")
[FEATURES]:   Key visual details - body shape, limbs, accessories, expression
[COLORS]:     Primary and accent colors, materials (e.g., "white chrome, cyan accents")
[STYLE]:      futuristic sci-fi, cute, sleek, high detail
[VIEW]:       side view, facing right, centered in frame
[ANIMATION]:  walk cycle ready / idle / static (if applicable)
[OUTLINE]:    single color black outline, medium shading
[BACKGROUND]: magenta background
```

### How to Use
1. Fill in each field for your asset
2. Flatten into a single comma-separated prompt
3. Keep the order: Subject → Features → Colors → Style → View → Animation → Outline → Background

### Template Example

**Filled template:**
```
[SUBJECT]:    Player robot character
[FEATURES]:   Rounded chrome body, stubby legs, single expressive eye, small antenna
[COLORS]:     White and chrome body, cyan glowing accents
[STYLE]:      futuristic sci-fi, cute, sleek, high detail
[VIEW]:       side view, facing right, centered in frame
[ANIMATION]:  walk cycle ready, 2D flat style
[OUTLINE]:    single color black outline, medium shading
[BACKGROUND]: magenta background
```

**Flattened prompt:**
```
Player robot character, rounded chrome body, stubby legs, single expressive eye,
small antenna, white and chrome body with cyan glowing accents, futuristic sci-fi,
cute, sleek, high detail, side view, facing right, centered in frame,
walk cycle ready, 2D flat style, single color black outline, medium shading,
magenta background
```

---

## Example Prompts

### Turrets (Side-View with Rotatable Weapon)

**Normal Turret:**
```
Automated defense turret, solid chrome base, dual barrels on rotating mount,
glowing cyan status lights, white and silver metal, futuristic military,
cute sleek design, high detail, side view, centered in frame,
weapon pointing right, modular design for animation,
single color black outline, medium shading, magenta background
```

**Flamethrower Turret:**
```
Flamethrower turret, chrome base, flame nozzle on rotating mount,
orange fuel tank with warning stripes, white silver body with heat vents,
futuristic military sci-fi, cute elegant sleek design, high detail,
side view, centered in frame, weapon pointing right,
single color black outline, medium shading, magenta background
```

**Tesla/Electric Turret:**
```
Tesla coil turret, chrome base, electric spire on rotating mount,
crackling cyan energy arcs, white and silver with blue capacitors,
futuristic sci-fi, cute sleek design, high detail, side view,
centered in frame, weapon pointing right,
single color black outline, medium shading, magenta background
```

### Characters (Left/Right Movement)

**Player:**
```
Cute friendly robot, rounded chrome body, stubby legs,
single expressive eye, small antenna, white and cyan colors,
funny endearing personality, futuristic sci-fi, high detail,
side view, facing right, neutral standing pose,
clear side profile, walk cycle ready, 2D flat style,
centered in frame, single color black outline, medium shading,
magenta background
```

**Enemy (Basic):**
```
Hostile robot drone, rounded mechanical body, glowing orange eyes,
small antenna, dark gunmetal with orange danger accents,
menacing but cute, futuristic sci-fi, high detail, side view,
facing right, clear side profile, walk cycle ready, 2D flat style,
centered in frame, single color black outline, medium shading,
magenta background
```

### Pickups

**XP Orb:**
```
Glowing energy orb, soft green crystal sphere, floating,
subtle inner glow, sci-fi pickup item, clean simple design,
high detail, side view, centered in frame,
single color black outline, medium shading, magenta background
```

**Health Pickup:**
```
Glowing health pack, cyan energy core, floating medical container,
futuristic first aid, clean sci-fi design, high detail, side view,
centered in frame, single color black outline,
medium shading, magenta background
```

### Projectiles

**Bullet (Physical):**
```
Glowing energy bullet, silver core with white trail, small projectile,
futuristic ammo, clean simple design, side view,
centered, single color black outline, magenta background
```

**Fireball (Fire):**
```
Flaming projectile, orange fire core with yellow glow, small fireball,
futuristic plasma, clean design, side view,
centered, single color black outline, magenta background
```

---

*Last updated: November 2025*
