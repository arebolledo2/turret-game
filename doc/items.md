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

## Built so far (26 of 40)

`scripts/registries/items/items_v2.gd` defines 13 commons and 13 uncommons and overrides same-id tier entries. The catalog (`ShopCatalog`) gates the new rows behind the `items_v2` flag; the ten original items they build on stay available when it is off.

- **Doctrines** (uncommon): one family +25% damage, every other turret -8%. Max 2 stacks.
- **Specialists** (uncommon): Piercing Rounds (Ion shots pierce, `pierce` stat), Cluster Warheads, Superconductors, Spiked Bat.
- **Tall**: Concrete Footings and Hardpoint use the Entrench and carry stats below.
- **Weak commons**: Faulty Wiring and Budget Capacitor are intentionally slightly net negative.

Rares, epics and legendaries from the proposal (8 / 4 / 2) are not built yet. Retired from the 3D shop: Ammo Surplus, Overclock Module, Shock Absorbers, Kinetic Enhancer.

## Stats added for items

| Stat | Effect |
|---|---|
| `entrench_stack_seconds` | Seconds per Entrench stack (min 0.5) |
| `entrench_max_stacks` | Stack cap |
| `entrench_bonus` | Multiplier on the per-stack damage and fire rate bonus |
| `carry_speed` | Multiplier on the player's speed while carrying a turret |
| `pierce` | Extra enemies a non-splash shot passes through |

Stats with no 3D consumer (`rotation_speed`, `dot_*`) should not be used by new items.

## Adding an item

Add it to `items_v2.gd` (or a tier file), give it a tag, add a `ShopCatalog.DEFAULT_ENTRIES` row with a flag, and cover it in `tests/unit/test_items_v2.gd`.
