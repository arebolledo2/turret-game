# Items and build tags

Phase 2 item pool. The proposal with the full rationale is the "Item Pool v2" artifact; this page records what is built.

## Shop layout

One turret slot and three item slots per shop (`GameConstants.SHOP_TURRET_SLOTS`, `SHOP_ITEM_SLOTS`). Item cards show a build tag prefix such as `[ION]`, and the build summary ends with a tag count line (`Tags: ION 2 · TALL 1`).

## Turret families and tags

`TurretRegistry.FAMILIES` maps player-facing families to turret types. Modifier filters can target them with `Item.filter_family([...])`.

| Family | Turret types |
|---|---|
| ion | normal |
| plasma | plasma |
| electric | shock, tesla |
| melee | melee |

Item tags (`ItemRegistry.TAGS`): ION, PLASMA, ELECTRIC, MELEE, WIDE, TALL, HULL, ECON, ANY. Set `Item.tag`; items without one use `ItemRegistry.LEGACY_TAGS`, then ANY. Do not filter on `damage_type: PHYSICAL` for new items: it spans Ion, Melee, Sniper and Mine.

## Built (40 of 40)

`scripts/registries/items/items_v2.gd` defines the pool and overrides same-id tier entries. `ShopCatalog` gates the 26 commons and uncommons behind `items_v2`, and the 14 rares, epics and legendaries behind `items_v2_hooks` (which requires `items_v2`). With both off the ten original items they build on remain.

| Rarity | Count | Examples |
|---|---|---|
| Common | 13 | Polished Barrels, Blast Charges, Concrete Footings; Faulty Wiring and Budget Capacitor are the weak ones |
| Uncommon | 13 | Four Doctrines (family +25% damage, every other turret -8%), Piercing Rounds, Superconductors, Hardpoint |
| Rare | 8 | Arc Rod, Plasma Capacitor, Killzone Bat, Overwatch Optics, Army Doctrine, Elite Forces, Last Stand, Quality Over Quantity |
| Epic | 4 | Glass Cannon Core, Mono-Type Mastery, Reactor Overload, Storm Conductor |
| Legendary | 2 | Elemental Conduit, Whirlwind Frame |

Mechanics beyond stat modifiers:

- **Piercing Rounds**: `pierce` stat, handled by `Projectile3D` (non-splash shots only).
- **Reactor Overload**: plasma kills detonate for 40% of the killing damage in 60% of the plasma radius; chains up to 3 deep (`ArenaWorld._reactor_overload`, `CombatHit3D.blast_depth`).
- **Storm Conductor**: electric turrets within 4 m of another electric turret get +35% damage (`TurretActor._apply_item_conditions`).
- **Last Stand**: below 30% hull, turrets fire 40% faster (same place).
- **Killzone Bat**: `rehit_delay` is now a melee base stat. **Whirlwind Frame**: bat hits apply `slow_intensity` and `slow_duration` when the stats have them.
- **Army Doctrine** now counts turrets beyond the 3rd. **Elemental Conduit** counts turret families (`TurretStatsService.get_family_diversity`), not damage types.
- **Quality Over Quantity** was inert in 3D; wave enemy count and kill scrap now apply `enemy_count_mult` and `scrap_earn_mult`.
- Situational bonuses refresh with the cached turret stats (every 0.25 s or when modifiers change).

Retired from the 3D shop: Ammo Surplus, Overclock Module, Shock Absorbers, Kinetic Enhancer.

## Stats added for items

| Stat | Effect |
|---|---|
| `entrench_stack_seconds` | Seconds per Entrench stack (min 0.5) |
| `entrench_max_stacks` | Stack cap |
| `entrench_bonus` | Multiplier on the per-stack damage and fire rate bonus |
| `carry_speed` | Multiplier on the player's speed while carrying a turret |
| `core_move_speed` | Multiplier on the convoy core's driving speed (Convoy mode only; floored at `CORE_MIN_MOVE_SPEED`) |
| `pierce` | Extra enemies a non-splash shot passes through |
| `rehit_delay` | Seconds before the bat can hit the same enemy again |
| `last_stand_fire_rate`, `storm_link_damage`, `reactor_overload` | Flat markers read by the item conditions above |

Stats with no 3D consumer (`rotation_speed`, `dot_*`) should not be used by new items.

## Adding an item

Add it to `items_v2.gd` (or a tier file), give it a tag, add a `ShopCatalog.DEFAULT_ENTRIES` row with a flag, and cover it in `tests/unit/test_items_v2.gd`.
