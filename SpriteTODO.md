# Sprite TODO List

Comprehensive list of placeholder visuals that need sprite replacements, organized by priority with detailed descriptions and creation recommendations.

---

## HIGH PRIORITY - PlaceholderTexture2D Replacements

### 1. Turret Weapon Sprite
**Location:** `scenes/turret.tscn` - WeaponSprite node
**Current:** PlaceholderTexture2D (green tinted, 25x12 pixels)
**Required Size:** ~25x12 pixels (can be higher res, will scale)

**Description:**
A small weapon barrel or gun attachment that sits on top of the turret base. Should be rotatable and point toward targets. Needs to work with multiple turret types (normal, sniper, fire, plasma, shock, tesla) - can be generic or have variants per type.

**Visual Style:**
- Top-down perspective matching existing turret base sprite
- Sci-fi/futuristic style
- Simple, readable silhouette
- Should clearly indicate direction/facing

**Recommended Creation Method:**
- **Pixel Art (RECOMMENDED)**: Use Aseprite, Piskel, or Pyxel Edit. Draw a simple barrel/gun shape in top-down view. Create variants for different turret types if desired.
- **Vector**: Use Inkscape or Affinity Designer for clean geometric shapes, export as PNG
- **AI Generation**: Midjourney/DALL-E prompt: "top-down pixel art turret gun barrel, sci-fi style, 25x12 pixels, transparent background, simple futuristic weapon sprite"

**Variants Needed:**
- Base/Normal turret: Standard barrel
- Sniper: Longer, thinner barrel
- Fire: Flamethrower nozzle
- Plasma: Energy weapon emitter
- Shock: Electric coil weapon
- Tesla: Lightning rod/coil design

---

### 2. Projectile Sprite
**Location:** `scenes/projectile.tscn` - Sprite2D node
**Current:** PlaceholderTexture2D (yellow tinted, 10x10 pixels)
**Required Size:** ~10x10 pixels (can be higher res)

**Description:**
Small bullet/energy bolt that fires from turrets toward enemies. Needs to be clearly visible during fast-paced combat. Should work for multiple projectile types (bullets, plasma, fire, lightning).

**Visual Style:**
- Bright, high-contrast colors for visibility
- Glowing/energy effect preferred
- Simple shape (circle, oval, or pointed)
- May need directional variant (pointing forward)

**Recommended Creation Method:**
- **Pixel Art (RECOMMENDED)**: Simple glowing orb or bullet shape. Use bright colors with lighter center, darker edges. Add subtle glow effect.
- **Generated Textures**: Use a procedural texture generator for glowing orbs
- **AI Generation**: "glowing energy projectile sprite, 10x10 pixels, bright yellow-white center, transparent background, top-down view, game asset"

**Variants Needed (Optional):**
- Standard: Yellow/white energy orb
- Fire: Orange/red fireball
- Plasma: Cyan/purple plasma bolt
- Shock: Blue/white electric sphere
- Sniper: Sleek elongated bullet

---

### 3. XP Drop Sprite
**Location:** `scenes/xp_drop.tscn` - Sprite2D node
**Current:** PlaceholderTexture2D (purple tinted, 12x12 pixels)
**Required Size:** ~12x12 pixels

**Description:**
Small collectible orb that drops from defeated enemies. Players move near it to collect experience points. Should be visually distinct from other pickups (gold items, tech drops) and clearly indicate "experience/power-up".

**Visual Style:**
- Purple/violet color scheme (current theme)
- Glowing, mystical appearance
- Spherical or gem-like shape
- Should stand out against arena background
- Magical/energy aesthetic

**Recommended Creation Method:**
- **Pixel Art (RECOMMENDED)**: Create a glowing purple orb or gem. Use color gradient from bright center to darker edges. Add sparkle/shine highlights.
- **AI Generation**: "pixel art purple experience orb, 12x12 pixels, glowing mystical gem, RPG game pickup, transparent background, top-down view"
- **Hand-drawn + Filter**: Draw a gem shape, apply glow/blur effects

**Visual Reference:**
Think: Soul gem, magical essence, RPG experience crystal

---

### 4. Item Pickup Sprite
**Location:** `scenes/item_pickup.tscn` - Sprite2D node
**Current:** PlaceholderTexture2D (gold tinted, 16x16 pixels)
**Required Size:** ~16x16 pixels

**Description:**
Collectible item drops that represent various power-ups and stat upgrades. These are permanent items from the item registry (5 rarity tiers: common, uncommon, rare, epic, legendary). Should look valuable and distinct from XP drops.

**Visual Style:**
- Gold/treasure aesthetic (current theme)
- Could be: treasure chest, item box, glowing artifact, gift box
- Should feel "premium" compared to XP drops
- Needs to work for all rarity tiers (can use color variations)

**Recommended Creation Method:**
- **Pixel Art (RECOMMENDED)**: Create a treasure chest, glowing artifact, or item container. Use gold colors with metallic highlights.
- **Multiple Variants by Rarity**:
  - Common: Bronze/brown chest
  - Uncommon: Silver chest
  - Rare: Gold chest
  - Epic: Purple/glowing chest
  - Legendary: Rainbow/radiant chest
- **AI Generation**: "pixel art treasure chest, 16x16 pixels, top-down view, golden RPG item pickup, glowing treasure box, transparent background"

**Visual Reference:**
Think: Zelda chest, Diablo loot drop, RPG treasure container

---

### 5. Tech Drop Glow Effect
**Location:** `scenes/tech_drop.tscn` - GlowEffect node
**Current:** PlaceholderTexture2D (cyan tinted, 30x30 pixels, initially invisible)
**Required Size:** ~30x30 pixels (larger for glow radius)

**Description:**
A radial glow effect that appears around tech drops (items that spawn between waves). Main sprite already exists (tech_drop.png), but needs a glowing aura/halo effect to make it more noticeable and attractive. Should pulse or shimmer.

**Visual Style:**
- Cyan/blue glow (current theme)
- Soft, diffuse radial gradient
- Semi-transparent outer edges
- Bright center fading to transparent
- Ethereal, attention-grabbing

**Recommended Creation Method:**
- **Image Editor (RECOMMENDED)**: Create in Photoshop/GIMP/Krita. Start with white circle, apply Gaussian blur heavily, add cyan color overlay, ensure soft transparent edges.
- **Procedural**: Use gradient tool to create radial gradient (cyan center to transparent)
- **AI Generation**: "radial glow effect, cyan blue light, 30x30 pixels, soft gradient, transparent edges, aura halo sprite, game VFX"

**Technical Notes:**
- Must have alpha channel transparency
- Should be soft and diffuse (heavily blurred)
- Can be animated (pulsing frames optional)

---

### 6. Defense Target Barrier (2 sprites)
**Location:** `scenes/defense_target.tscn` - BarrierCircle and BarrierGlow nodes
**Current:** PlaceholderTexture2D (cyan tinted, 60x60 and 70x70 pixels)
**Required Size:** 60x60 (inner circle) and 70x70 (outer glow)

**Description:**
A protective energy barrier/shield that appears around the Defense Target entity during Tech Defense and Escort game modes. Consists of two layers:
- **BarrierCircle (60x60)**: Main shield structure with visible pattern/lines
- **BarrierGlow (70x70)**: Outer glow/aura effect

**Visual Style:**
- Sci-fi energy shield aesthetic
- Cyan/blue theme (current)
- Semi-transparent with visible energy patterns
- Hexagonal grid, circuit lines, or energy waves
- Should clearly show "this is protected"

**Recommended Creation Method:**
- **Vector + Effects (RECOMMENDED)**: Use Inkscape/Illustrator. Create hexagonal pattern or energy lines in a circle, export at high res, apply glow in image editor.
- **Image Editor**: Use GIMP/Photoshop to create circular pattern with:
  - BarrierCircle: Draw hexagon grid or circuit pattern in circular shape, cyan color with ~60% opacity
  - BarrierGlow: Create larger soft glow with heavy blur, same cyan color, ~40% opacity
- **AI Generation**:
  - Circle: "sci-fi energy barrier shield, hexagonal pattern, cyan blue, 60x60 pixels, circular force field, transparent background, top-down game sprite"
  - Glow: "soft circular energy glow, cyan blue aura, 70x70 pixels, diffuse light effect, transparent edges"

**Visual Reference:**
Think: Halo energy shields, Starcraft protoss shields, Force field bubbles

**Animation Potential:**
Can create multiple frames for rotating/pulsing effect (optional enhancement)

---

### 7. Tunnel Door Sprite
**Location:** `scenes/tunnel_door.tscn` - Sprite2D node
**Current:** icon.svg (Godot's default icon, orange tinted, scaled 0.3x0.6)
**Required Size:** Approximately 40x80 pixels (based on 0.3x0.6 scale of 128x128 icon)

**Description:**
A door or barrier entity used in Tunneling game mode. Players must damage it with turrets to "breach" and complete waves. Should look damageable/destructible and clearly block a passage or tunnel entrance.

**Visual Style:**
- Industrial/sci-fi door or blast door
- Should look sturdy and destructible
- Orange/red warning colors (current theme) or metallic
- Could be: reinforced door, blast shield, force field gate, metal barrier
- Top-down or slight isometric view
- Should suggest "obstacle that can be destroyed"

**Recommended Creation Method:**
- **Pixel Art (RECOMMENDED)**: Draw a reinforced door in top-down view. Add panel lines, rivets, warning stripes. Use metallic grays with orange/red accent lights.
- **Vector Graphics**: Design in Inkscape with geometric shapes, industrial aesthetic
- **AI Generation**: "top-down pixel art reinforced blast door, sci-fi industrial barrier, 40x80 pixels, orange warning lights, metal panels, destructible obstacle sprite, transparent background"

**Visual Reference:**
Think: Doom doors, sci-fi blast doors, industrial barriers, metal gates

**Damage States (Optional Enhancement):**
Could create 3-4 variants showing progressive damage (cracks, dents, sparks) for visual feedback as it takes damage.

---

## MEDIUM PRIORITY - Code-Generated Visual Effects

These are functional and performant as procedural code. Replacement with sprites is optional for enhanced visual polish.

### 8. Spawn Alert Circles
**Location:** `scenes/spawn_alert.tscn` + `scripts/spawn_alert.gd:23`
**Current:** Polygon2D red circles (procedurally generated)

**Description:**
Warning indicator that appears briefly before enemies spawn. Two concentric circles that pulse/fade to alert player of incoming spawn location.

**Sprite Alternative:**
- Two-layer radial warning indicator
- Red/orange theme
- Outer circle: 40-50px, Inner circle: 30-40px
- Pulsing animation frames (3-5 frames)

**Recommended Creation Method:**
- **Keep Procedural (RECOMMENDED)**: Current implementation is efficient and flexible
- **If replacing**: Create animated sprite with pulsing effect frames
- **AI Generation**: "warning indicator sprite, red alert circle, pulsing animation frames, top-down game UI, danger zone marker"

**Priority:** LOW - procedural is fine

---

### 9. Tech Drop Alert Circles
**Location:** `scripts/tech_drop_spawner.gd:115,125`
**Current:** Polygon2D cyan circles

**Description:**
Similar to spawn alerts but for tech drop spawns. Cyan-colored circles indicating item drop location.

**Sprite Alternative:**
- Same as spawn alert but cyan/blue colors
- Friendly/positive visual theme

**Recommended Creation Method:**
- **Keep Procedural (RECOMMENDED)**
- If replacing, use same approach as spawn alerts with cyan colors

**Priority:** LOW - procedural is fine

---

### 10. Range Indicator Circles
**Location:** `scripts/range_indicator.gd:12,14`
**Current:** draw_circle() green circles

**Description:**
Shows turret attack range when enabled. Green circle outline around turrets indicating maximum attack distance.

**Sprite Alternative:**
- Dashed or dotted circle texture
- Green tactical overlay aesthetic
- Multiple sizes needed for different turret ranges

**Recommended Creation Method:**
- **Keep Procedural (RECOMMENDED)**: Range varies per turret, procedural is most flexible
- **Texture Alternative**: Could apply texture to Line2D for styled ring

**Priority:** LOW - procedural is superior for variable ranges

---

### 11. Lightning Chain Effects
**Location:** `scripts/components/turret_combat.gd:326,376`
**Current:** Line2D for chain lightning and branches

**Description:**
Electric arc effects for Tesla turret chain lightning between enemies. Bright blue crackling energy.

**Sprite Alternative:**
- Animated lightning bolt sprite strips
- Could use texture on Line2D for styled lightning

**Recommended Creation Method:**
- **Keep Procedural (RECOMMENDED)**: Dynamic targeting requires procedural lines
- **Enhancement**: Add lightning texture to Line2D for more detailed appearance
- **Texture Source**: Hand-draw lightning texture strip or generate electrically-styled gradient

**Priority:** LOW - procedural allows dynamic chains

---

### 12. Hitscan Tracers
**Location:** `scripts/components/turret_combat.gd:313`
**Current:** Line2D instant hit visualization

**Description:**
Brief visual line showing instant bullet travel from turret to target (for sniper/hitscan weapons).

**Sprite Alternative:**
- Beam texture applied to Line2D
- Glowing energy beam appearance

**Recommended Creation Method:**
- **Hybrid Approach (RECOMMENDED)**: Keep Line2D but add gradient texture for glow effect
- Create simple horizontal beam gradient texture (bright center, fading edges)

**Priority:** MEDIUM - texture enhancement would improve visual quality

---

### 13. AOE Pulse Circles
**Location:** `scripts/components/turret_combat.gd:400`
**Current:** Polygon2D circles with turret-specific colors

**Description:**
Expanding circular pulse effect for area-of-effect attacks. Shows damage radius.

**Sprite Alternative:**
- Radial explosion/shockwave sprite animation
- Multiple frames for expanding effect

**Recommended Creation Method:**
- **Keep Procedural (RECOMMENDED)**: Allows dynamic sizing per turret
- **Enhancement Alternative**: Could use animated sprite sequence for more detailed shockwave

**Priority:** LOW - procedural is flexible and performant

---

### 14. Explosion Effects
**Location:** `scripts/projectile.gd:183`
**Current:** Polygon2D circles for AoE explosions

**Description:**
Explosion visual when projectiles hit and deal area damage. Currently simple expanding circles.

**Sprite Alternative:**
- Classic explosion sprite animation (5-8 frames)
- Fire/energy burst aesthetic
- Orange/yellow/white color scheme

**Recommended Creation Method:**
- **Sprite Animation (WORTH CONSIDERING)**: Explosions are common VFX where sprites excel
- **Pixel Art**: Create 6-8 frame explosion animation in Aseprite
- **AI Generation**: "pixel art explosion animation sprite sheet, 8 frames, fire burst, 32x32 pixels, game VFX, transparent background"
- **Asset Packs**: Check OpenGameArt.org for free explosion sprites

**Priority:** MEDIUM - sprite explosions would significantly improve visual feel

---

### 15. Player Melee Arc
**Location:** `scenes/player.tscn` + player script
**Current:** Polygon2D gold-colored arc

**Description:**
Visual effect showing player's melee attack range and swing. Arc-shaped slice in front of player during melee attack.

**Sprite Alternative:**
- Slash/swoosh effect sprite animation
- 3-5 frames showing arc motion
- Golden energy or blade trail aesthetic

**Recommended Creation Method:**
- **Sprite Animation (WORTH CONSIDERING)**: Would add significant visual polish
- **Pixel Art**: Create sweeping arc animation frames in Aseprite
- **AI Generation**: "pixel art sword slash effect animation, golden arc swoosh, 4 frames, melee attack VFX, transparent background"
- **Asset Packs**: Search for "slash effect sprite sheet"

**Priority:** MEDIUM - would enhance combat feel significantly

---

### 16. Off-Screen Indicators
**Location:** `scripts/ui/off_screen_indicators.gd:133`
**Current:** Polygon2D arrow shapes

**Description:**
Arrow indicators at screen edges pointing toward off-screen enemies or objectives. Helps player track threats outside viewport.

**Sprite Alternative:**
- Styled arrow sprites with better visual design
- Glowing or pulsing directional indicators
- Color-coded by threat level or type

**Recommended Creation Method:**
- **Sprite (RECOMMENDED)**: UI elements benefit from polished sprites
- **Pixel Art**: Draw directional arrow with clear pointing direction, add glow/outline
- **Vector**: Create in Inkscape for crisp edges at any rotation
- **AI Generation**: "UI arrow indicator sprite, glowing directional pointer, game HUD element, red warning arrow, transparent background"

**Priority:** MEDIUM - UI polish is valuable

---

### 17. Escort Path Line
**Location:** `scripts/defense_target.gd:93`
**Current:** Line2D for path visualization

**Description:**
Shows the path that the Defense Target will follow in Escort mode. Helps player plan turret placement.

**Sprite Alternative:**
- Dashed line texture
- Glowing path trail
- Dotted energy line

**Recommended Creation Method:**
- **Texture on Line2D (RECOMMENDED)**: Keep procedural line, add styled texture
- Create simple dashed line or glowing gradient texture
- Apply texture to Line2D for styled appearance

**Priority:** LOW - current implementation is functional

---

## LOW PRIORITY - UI Backgrounds

These ColorRect elements are functional. Sprite replacement is purely cosmetic.

### 18. Arena Boundary
**Location:** `scenes/main.tscn` - ColorRect
**Current:** Green-tinted ColorRect

**Description:**
Visual border around playable arena area. Currently solid color rectangle.

**Sprite Alternative:**
- Textured border (fence, energy wall, force field)
- Repeating pattern texture
- Industrial/sci-fi themed barrier

**Recommended Creation Method:**
- **Tileable Texture**: Create repeating pattern in image editor
- **Keep ColorRect (RECOMMENDED)**: Functional and clear

**Priority:** VERY LOW

---

### 19. UI Menu Overlays
**Location:** `scenes/ui/hud.tscn` and various UI scenes
**Current:** ColorRect for semi-transparent dark overlays

**Description:**
Dark overlay backgrounds for menus (pause, game over, settings, shop, etc.). Currently solid semi-transparent black.

**Sprite Alternative:**
- Textured panel backgrounds
- Gradient overlays
- Themed UI frames

**Recommended Creation Method:**
- **Styled Panels**: Use Godot's StyleBoxTexture with corner textures
- **Keep ColorRect (RECOMMENDED)**: Functional and performs well

**Priority:** VERY LOW - functional as-is

---

### 20. Isometric Arena Visuals
**Location:** `scripts/arena_setup.gd:140,146,189`
**Current:** Polygon2D for diamond ground/border, Line2D for debug

**Description:**
Procedurally generated diamond-shaped arena for isometric mode. Creates ground and border programmatically.

**Sprite Alternative:**
- Pre-rendered isometric arena texture
- Tiled ground pattern

**Recommended Creation Method:**
- **Keep Procedural (RECOMMENDED)**: Allows dynamic arena sizing

**Priority:** VERY LOW - procedural is appropriate

---

## Summary & Prioritization

### Must Replace (Core Assets):
1. ✅ Projectile (10x10) - Most visible in combat
2. ✅ XP Drop (12x12) - Constantly visible during gameplay
3. ✅ Item Pickup (16x16) - Important reward visual
4. ✅ Turret Weapon (25x12) - Core game entity

### Should Replace (Enhanced Polish):
5. ✅ Tunnel Door (40x80) - Unique game mode entity
6. ✅ Tech Drop Glow (30x30) - Improves item visibility
7. ✅ Defense Target Barrier (60x60, 70x70) - Important defensive visual

### Consider for Visual Polish:
- Explosion animations (sprite sheet)
- Player melee slash effect (animated)
- Off-screen indicator arrows (styled sprites)
- Hitscan beam textures

### Keep Procedural:
- Range indicators (variable sizes)
- Lightning chains (dynamic targeting)
- Spawn alerts (performance)
- AOE pulses (dynamic sizing)
- UI overlays (functional)

---

## Technical Notes

**File Format:** PNG with alpha transparency
**Color Depth:** 32-bit RGBA
**Export Settings:** No compression artifacts, preserve alpha
**Naming Convention:** `sprite_name_descriptor.png` (e.g., `projectile_energy.png`, `xp_drop_purple.png`)
**Storage Location:** `assets/sprites/` or organized by category

**Testing Checklist:**
- [ ] Sprite displays correctly at intended size
- [ ] Alpha transparency works properly
- [ ] Sprite is visible against all arena backgrounds
- [ ] Colors match game's visual theme
- [ ] Performance is acceptable (file size reasonable)
- [ ] Works with existing tint/modulate effects if any

---

## Resources

**Free Asset Sources:**
- OpenGameArt.org - Public domain game assets
- itch.io - Many free sprite packs
- Kenney.nl - Free game assets (CC0 license)

**Pixel Art Tools:**
- Aseprite (paid, highly recommended)
- Piskel (free, browser-based)
- LibreSprite (free, Aseprite fork)
- Pyxel Edit (paid)

**Vector Tools:**
- Inkscape (free)
- Affinity Designer (paid)

**Image Editors:**
- GIMP (free)
- Krita (free)
- Photoshop (paid)

**AI Generation:**
- Midjourney (subscription)
- DALL-E (paid per image)
- Stable Diffusion (free, local)
