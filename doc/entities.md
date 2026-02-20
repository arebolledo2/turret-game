# Entities & Components

## Overview

Game entities (enemies, turrets, player) use component-based architecture. Each entity delegates specific behaviors to focused component scripts. Enemy AI is driven by a pluggable behavior system. Visuals/collision for enemy/turret/player are now data-driven via `AssetConfigService`. Items are organized by rarity tier.

## Enemy Components

Located in `scripts/components/`:

- **EnemyMovement** (`enemy_movement.gd`) — Movement patterns with behavior system integration. Delegates AI decisions to pluggable behavior classes.
- **EnemyCombat** (`enemy_combat.gd`) — Projectile and ranged attack handling for shooter-type enemies.
- **EnemyStatusEffects** (`enemy_status_effects.gd`) — DoT, slow, and other status effect tracking and application.
- **EnemyVisuals** (`enemy_visuals.gd`) — Asset-config-driven sprite orientation/textures, tint/scale/offset, damage flash, and death effects.
- **EnemyHurtbox** (`enemy_hurtbox.gd`) — Collision detection and damage receipt validation.

## Turret Components

- **TurretCombat** (`scripts/components/turret_combat.gd`) — All turret attack logic including: projectile, instant-hit, AOE, chain lightning, melee, and deployable attack styles.
- **TurretVisuals** (`scripts/components/turret_visuals.gd`) — Asset-config-driven sprite setup/tint/scale, rotation toward targets, and visual effects.

## Player Components

- **PlayerMovement** (`scripts/components/player_movement.gd`) — Movement and facing state only.
- **PlayerCombat** (`scripts/components/player_combat.gd`) — Auto-fire targeting and projectile spawning.
- **PlayerTurretHandler** (`scripts/components/player_turret_handler.gd`) — Turret pickup/carry/place flow.
- **PlayerVisuals** (`scripts/components/player_visuals.gd`) — Asset-config-driven player sprite/orientation behavior.
- **PlayerHurtbox** (`scripts/components/player_hurtbox.gd`) — Damage receipt/collision validation.

## Enemy Behaviors

Pluggable AI behaviors in `scripts/components/behaviors/`:

- **EnemyBehavior** (`enemy_behavior.gd`) — Base class for all enemy AI behaviors. Defines the interface for movement and decision-making.
- **ChaseBehavior** (`chase_behavior.gd`) — Direct pursuit of the player. Simple, aggressive movement.
- **WanderBehavior** (`wander_behavior.gd`) — Random wandering movement. Used by passive enemy types.
- **ChargeBehavior** (`charge_behavior.gd`) — Hybrid behavior: wanders until player enters proximity, then charges aggressively.

## Enemy Types

Defined in **EnemyRegistry** (`scripts/registries/enemy_registry.gd`):
- **basic** — Standard enemy
- **fast** — High speed, low health
- **tank** — High health, slow
- **exploder** — Explodes on death
- **lazy_wanderer** — Passive wandering enemy
- **charger** — Charges at player on proximity
- **neon_drone** — Drone-type enemy
- **lazy_shooter** — Ranged enemy with wandering behavior

## Turret Types

Defined in **TurretRegistry** (`scripts/registries/turret_registry.gd`):
- **normal** — Standard projectile turret
- **sniper** — Long range, high damage, slow fire rate
- **fire** — Fire-based with DoT
- **plasma** — Energy-based projectiles
- **shock** — Electrical damage
- **tesla** — Chain lightning
- **melee** — Close-range attacks
- **mine** — Deployable explosives

## Asset Config Source of Truth

Gameplay metadata remains in registries, while visuals/collision are now resolved through `EntityAssetConfig` resources via `AssetConfigService`.

For each entity kind:
- **Enemy**: visual + collision profile live-apply enabled
- **Turret**: visual live-apply enabled, collision runtime customization deferred
- **Player**: visual + collision profile live-apply enabled

See [asset-management.md](asset-management.md) for preset layout, override precedence, and runtime update behavior.

## Key Gameplay Entities

Core entities spawned during gameplay:

- **DefenseTarget** (`scripts/defense_target.gd`) — Protectable entity for Tech Defense and Escort modes. Includes barrier mechanics, reflection damage, and healing. Used in both stationary (Tech Defense) and path-following (Escort) modes.
- **TunnelDoor** (`scripts/tunnel_door.gd`) — Breachable door entity for Tunneling game mode. Must be damaged by turrets to open, with progressive health depletion.
- **ScrapDrop** (`scripts/scrap_drop.gd`) — Scrap currency pickups with magnet-based collection (auto-pickup when player is nearby).
- **TechDrop** (`scripts/tech_drop.gd`) — Item drops from wave completion that feed into the loot review phase.
- **ItemPickup** (`scripts/item_pickup.gd`) — Collectible item drops in the game world.

## Modular Item System

Items organized by rarity in `scripts/registries/items/`:

| Rarity | File | Description |
| --- | --- | --- |
| Common | `common_items.gd` | Basic stat boosts and simple effects |
| Uncommon | `uncommon_items.gd` | Moderate stat boosts and conditional effects |
| Rare | `rare_items.gd` | Significant effects and cross-system interactions |
| Epic | `epic_items.gd` | Powerful effects with unique mechanics |
| Legendary | `legendary_items.gd` | Game-changing effects and build-defining items |

Item base class: `scripts/registries/items/item_base.gd`
Item registry: `scripts/registries/item_registry.gd`

## Tech Tree

Defined in **TechRegistry** (`scripts/registries/tech_registry.gd`) with 6 paths in `scripts/registries/techs/`:
- **turret_offense** (`turret_offense_techs.gd`) — Turret damage and attack upgrades
- **turret_utility** (`turret_utility_techs.gd`) — Turret quality-of-life improvements
- **turret_unlock** (`turret_unlock_techs.gd`) — New turret type unlocks
- **player_combat** (`player_combat_techs.gd`) — Player combat enhancements
- **player_defense** (`player_defense_techs.gd`) — Player survivability upgrades
- **economy** (`economy_techs.gd`) — Scrap earning and shop improvements
