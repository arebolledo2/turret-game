# Combat & Modifier Systems

## Overview

The combat system encompasses projectile mechanics, status effects, critical hits, modifier stacking, and temporary buffs. Turrets and the player use nearest-neighbor targeting. The economy system ties into combat through scrap rewards from kills.

## Modifier System

### ModifierService
**File:** `scripts/autoload/modifier_service.gd`
Autoload wrapper for ModifierSystem. Manages permanent stat modifications applied by items and tech tree upgrades.

### ModifierSystem
**File:** `scripts/systems/modifier_system.gd`
Core modifier logic using **PoE-style stacking** with three operation types:
- **Add** — Flat value additions (applied first)
- **Increase** — Percentage increases that stack additively with each other
- **More** — Percentage multipliers that stack multiplicatively

Supports **filter dimensions**: turret_type, damage_type, attack_style, entity_type. Filters allow modifiers to target specific contexts (e.g., "fire turrets deal 20% more damage").

## Buff System

### BuffSystem
**File:** `scripts/systems/buff_system.gd`
Manages **temporary, stackable, time-based buffs** per turret instance. Uses the same add/increase/more operations as the modifier system. Buffs have duration and are automatically removed when expired.

## Projectile System

Supports multiple damage delivery mechanics:
- **Pierce** — Projectiles pass through enemies, hitting multiple targets
- **AOE** — Area-of-effect damage on impact
- **DoT** — Damage over time applied as status effects
- **Knockback** — Push enemies away from impact point
- **Chain** — Lightning-style damage that jumps between enemies

## Critical Hit System

Player combat includes critical hit calculations with visual feedback. Crit chance and crit damage are tracked by PlayerStatsService and can be modified through items and tech upgrades.

## Status Effects

Component-based status effect handling on enemies via **EnemyStatusEffects** (`scripts/components/enemy_status_effects.gd`):
- **DoT (Damage over Time)** — Periodic damage (fire, poison, etc.)
- **Slow** — Movement speed reduction
- Other debuffs as defined by items and turret types

## Barrier System

DefenseTarget barrier mechanics for Tech Defense mode:
- **Activation** — Barrier activates when enemies are in range
- **Cooldown** — Barrier has activation cooldown between uses
- **Reflection Damage** — Barrier reflects damage back at attackers
- **Visual Representation** — Barrier state shown through visual effects

## Visual Feedback

### Damage Numbers
**File:** `scripts/damage_number.gd`
Floating damage text with centralized font scaling via FontSizes service. Shows damage values, crits, and status effect ticks.

### Range Indicators
**File:** `scripts/range_indicator.gd`
Visual turret range display that can be toggled on/off. Shows the effective area of each turret type.

### Off-Screen Indicators
UI system for tracking off-screen enemies and objectives. Managed by OffScreenIndicatorService.

## Economy

- **Scrap Sources**: Enemy kills, wave completion bonuses, tech drops
- **Shop Weights**: 65% items, 35% turrets
- **Targeting**: Nearest-neighbor for both player auto-fire and turret targeting
- **Arena Bounds**: `ArenaBoundsService` handles rectangular and isometric diamond bounds for movement clamping and spawn zones
