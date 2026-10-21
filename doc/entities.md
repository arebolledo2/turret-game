# Entities and content

The playable actors are native 3D. Their runtime implementations are in `scripts/game/`; procedural wrappers instantiate the approved GLBs from `assets/models/game/`.

| Entity | Implementation | Visual contract |
|---|---|---|
| Player hover bot | `HeroActor` (extends `CombatActor`) | Muzzle socket, runtime turning/hover |
| Spider drone (`basic`) | `EnemyActor` (extends `CombatActor`) | Six independent leg pivots |
| Charger | `EnemyActor` + `ChargeController3D` | Leg pivots, amber armor and locked warning rails |
| Ion (`normal`), plasma, shock | `TurretActor` | Aim pivot and Muzzle socket |
| Projectile | `Projectile3D` | Swept collision; reusable shot state |
| Scrap | `ScrapPickup` | Collection radius, visual bob/rotation |

Actors use CharacterBody3D with ground-plane movement and Area3D hurtboxes. The visual child animates independently of collision. Turret carrying slows the player and replaces the hero's auto-fire with the carried turret's attacks. Pickup resets entrenchment; terrain bonuses and entrenchment only apply while deployed. Placement remains validated.

`EnemyRegistry` supplies scaled stats for every enemy type; the roster, roles and bosses are described in [enemy ecology](enemy-ecology.md). `TurretRegistry` and shared stat services supply the turret catalog. `ArenaShop.TURRETS` and `ArenaShop.ITEMS` come from `ShopCatalog` (`scripts/data/shop_catalog.gd`) and define the supported purchase catalogs; unsupported registry entries must not become offers until their effects have a native 3D implementation and validation.

The item catalog lives in `scripts/registries/items/item_catalog.gd`; see [items](items.md) for tags, rarities and shop layout. Item descriptions and build summaries are derived from their actual modifier values. See [gameplay](gameplay.md) for balancing and limitations.
