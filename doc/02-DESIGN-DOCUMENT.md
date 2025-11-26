# Game Design Document

> 📋 **POST-MVP VISION DOCUMENT**  
> This describes the full game vision. For MVP implementation, see `00-MVP-IMPLEMENTATION-SPEC.md`

## Core Identity
**"Strategic turret placement meets Brotato-style survival"**

The player is a support role managing automated defenses while dodging threats. Success comes from smart turret positioning, economy management, and survival skills rather than mechanical shooting ability.

## Player Character

### Movement
- **Control:** WASD or arrow keys
- **Speed:** Similar to Brotato (moderate, dodge-focused)
- **Feel:** Responsive, tight controls for weaving through enemies

### Combat Role
- **Primary Role:** Survival and positioning
- **Secondary Role:** Weak damage dealer
- **Damage Output:** 10-20% of total DPS
- **Attack Pattern:** 
  - Option A: Auto-fire (always shooting at nearest enemy)
  - Option B: Click/hold to shoot in aimed direction
  - **[DECISION NEEDED]**

### Resource Collection
- **Auto-pickup radius:** Similar to Brotato
- **Resources:**
  - Gold (yellow/gold colored drops)
  - XP (blue/purple colored drops)
- Drops spawn at enemy death location
- Visual/audio feedback on collection

## Turret System

### Placement Mechanics
- **When:** Between waves only (shop phase)
- **How:** 
  - Select turret from shop
  - Enter placement mode
  - Click to place at desired location
  - **Placement Type:** [GRID-BASED or FREE-FORM - TBD]
- **Constraints:**
  - Cannot place on existing turrets
  - Cannot place too close to arena edges (if any)
  - Preview shows range indicator before confirming
- **Permanence:** Once placed, cannot move or sell (MVP)

### Targeting System
- **Auto-target:** Nearest enemy within range
- **Priority:** Distance only (no HP/type priority in MVP)
- **Retargeting:** Instant when current target dies or leaves range
- **Visual:** Show target line or indicator (optional polish)

### Turret Archetypes

Choose 3-4 from these options:

#### 1. Basic Gun Turret
- **Damage:** Medium (10-15 per shot)
- **Fire Rate:** Medium (1 shot/second)
- **Range:** Medium
- **Target:** Single enemy
- **Cost:** 75-100 gold
- **Role:** Reliable all-rounder, good starting turret

#### 2. Cannon Turret  
- **Damage:** High (40-50 per shot)
- **Fire Rate:** Slow (0.3 shots/second)
- **Range:** Long
- **Target:** Single enemy
- **Cost:** 250-300 gold
- **Role:** Boss killer, high-value target elimination

#### 3. Rapid-Fire/Minigun Turret
- **Damage:** Low (3-5 per shot)
- **Fire Rate:** Very fast (5 shots/second)
- **Range:** Short-Medium
- **Target:** Single enemy
- **Cost:** 150-200 gold
- **Role:** Horde clear, consistent DPS

#### 4. Flamethrower Turret
- **Damage:** Medium (8-10 per tick)
- **Fire Rate:** Continuous (10 ticks/second)
- **Range:** Short (cone or circle AoE)
- **Target:** All enemies in area
- **Cost:** 200-250 gold
- **Role:** Crowd control, choke point defense

#### 5. Sniper Turret (Alternative)
- **Damage:** Very High (60-80 per shot)
- **Fire Rate:** Very Slow (0.2 shots/second)
- **Range:** Very Long
- **Target:** Single enemy (furthest in range)
- **Cost:** 300-350 gold
- **Role:** Picking off distant threats

**[DECISION NEEDED: Which 3-4 turrets for MVP?]**

### Turret Visuals
- Clear silhouette for each type
- Rotating barrel/gun that points at target
- Muzzle flash on firing
- Range indicator when placing/hovering

## Economy System

### Gold
- **Source:** Enemy kills
- **Drop Amount:** 5-15 gold per enemy (scales with wave)
- **Persistence:** Current run only
- **Uses:** Purchase turrets in shop

### Starting Resources
- **Gold:** 100-150 (enough for 1-2 basic turrets)
- **XP:** 0

### Wave Rewards
- **Gold per wave:** ~150-250 (from all enemy kills)
- **Scaling:** Increases slightly each wave

### Turret Pricing Strategy
- Early waves: Afford 1-2 turrets per wave
- Mid waves: Afford 1 strong turret or 2 weak turrets
- Late waves: Save up for expensive turrets or spam cheap ones

### XP System (MVP)
- **Collection:** Pick up drops (10-25 XP per enemy)
- **Display:** Show XP counter in HUD
- **Functionality:** None in MVP (prep for leveling system later)

## Enemy System

### Basic Enemy (MVP)
- **Movement:** Move toward player
- **Speed:** Moderate (slightly slower than player)
- **Health:** Scales with wave (start: 50 HP)
- **Damage:** Contact damage to player
- **Attack Pattern:** Chase player, damage on touch

### Spawn System
- **Spawn Points:** 
  - Option A: Random points along arena edges
  - Option B: Fixed spawn zones (2-4 locations)
  - **[DECISION NEEDED]**
- **Spawn Pattern:** 
  - Gradual spawn over 30-60 seconds
  - Wave 1: 20-30 enemies
  - Wave 10: 60-80 enemies
- **Difficulty Scaling:**
  - Enemy count increases each wave
  - Enemy HP increases (5-10% per wave)
  - Enemy speed increases slightly (2-5% per wave)

## Arena/Map

### Layout
- **Shape:** Rectangular or circular
- **Size:** Approximately 1920x1080 in-game units (adjust to feel)
- **Boundaries:** Hard walls or soft boundaries (player/enemies cannot leave)
- **Obstacles:** None in MVP
- **Spawn Zones:** Visible indicators where enemies spawn

### Playable Area
- **Center space:** Open for player movement
- **Turret placement:** Enough room for 10-15 turrets at full build
- **Spawn distance:** Enemies spawn far enough to give reaction time

### Visual Design
- **Floor:** Clean, simple texture
- **Contrast:** High contrast between:
  - Floor and entities
  - Enemies and player
  - Turrets and enemies
- **Readability:** Always prioritize clarity over aesthetics

## Win/Loss Conditions

### Victory
- Survive 10-15 waves (TBD based on testing)
- Display victory screen
- Show stats (total kills, gold earned, turrets placed)

### Defeat
- Player health reaches 0
- Display game over screen
- Show stats
- Option to restart

## UI/UX

### HUD (In-Combat)
- Player health bar (top-left)
- Gold counter (top-right)
- XP counter (top-right)
- Wave number (top-center)
- Wave progress indicator (enemies remaining or time)

### Shop UI (Between Waves)
- Display available turrets with:
  - Icon/sprite
  - Name
  - Cost
  - Stats (damage, fire rate, range)
- "Ready" button to start next wave
- Current gold display

### Placement UI
- Ghost/preview of turret at cursor
- Range indicator circle
- Valid/invalid placement indicator (green/red tint)
- Cancel button (ESC or right-click)

## Game Feel & Polish

### Juice (Nice-to-have for MVP)
- Screen shake on big hits
- Particle effects on enemy death
- Sound effects (shooting, enemy death, pickup)
- Damage numbers floating up from enemies
- Visual feedback on gold/XP pickup

### Audio
- Background music (simple, not distracting)
- Turret firing sounds (distinct per type)
- Enemy hurt/death sounds
- UI sounds (purchase, placement)
- Pickup sounds (gold, XP)

## Balancing Philosophy
- Player should feel pressure but not overwhelmed
- Turret placement should feel impactful
- Economy should encourage experimentation
- Difficulty curve should be gradual but noticeable
- Player survival should be challenging but fair (depends on dodging, not just turret DPS)
