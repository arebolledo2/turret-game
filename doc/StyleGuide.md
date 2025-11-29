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
| Player | 64px | Hero presence, high detail |
| Standard Enemy | 64px | Clear visibility |
| Mini/Swarm Enemy | 48px | Smaller = weaker visual cue |
| Tank/Boss Enemy | 96px | Bigger = tougher visual cue |
| Turret | 64px | Functional clarity |
| Projectile | 16-24px | Fast, visible |
| Pickup/Drop | 32px | Collectible size |

### PixelLab Parameters

```
view: "high top-down"
detail: "high detail"
outline: "single color black outline"
shading: "medium shading"
proportions: "default"
```

> **Why "default" proportions:** Easier to maintain visual consistency across all sprites. Chibi can cause unpredictable variations between generations.

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
- **Silhouette:** Cylindrical base (matches player), prominent weapon on top
- **Features:** Rotating barrel, cyan status lights, armored housing
- **Base:** Cylindrical bottom that plugs into player's top when carried
- **Colors:** Chrome/white base with cyan glow (matches player)
- **Read:** Friendly, powerful, visually compatible with player

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

**Player:**
```
Cute friendly robot with legs, cylindrical chrome body,
flat top with docking port, single expressive eye, 
stubby walking legs, white and cyan colors, funny looking,
futuristic sci-fi, high detail, top-down view
```

**Enemy:**
```
Hostile robot enemy, rounded mechanical body, glowing orange eyes,
small antenna, dark gunmetal with orange accents, no legs,
futuristic sci-fi, high detail, top-down view
```

**Turret:**
```
Automated turret, cylindrical chrome base that plugs into robot,
dual barrels on top, glowing cyan status lights, 
white and silver, futuristic military, high detail, top-down view
```

**XP Orb:**
```
Glowing energy orb, soft green light, 
small floating crystal or sphere, sci-fi pickup item,
clean simple design, transparent background
```

---

*Last updated: November 2025*
