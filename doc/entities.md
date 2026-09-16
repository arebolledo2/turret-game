# Entities and content

The playable actors are native 3D. Their runtime implementations are in `scripts/game/`; procedural wrappers instantiate the approved GLBs from `assets/models/game/`.

| Entity | Implementation | Visual contract |
|---|---|---|
| Player hover bot | `CombatActor` | Muzzle socket, runtime turning/hover |
| Spider drone (`basic`) | `CombatActor` | Six independent leg pivots |
| Charger | `CombatActor` + `ChargeController3D` | Leg pivots, amber armor and locked warning rails |
| Ion (`normal`), plasma, shock | `TurretActor` | Aim pivot and Muzzle socket |
| Projectile | `Projectile3D` | Swept collision; reusable shot state |
| Scrap | `ScrapPickup` | Collection radius, visual bob/rotation |

Actors use CharacterBody3D with ground-plane movement and Area3D hurtboxes. The visual child animates independently of collision. Turret carrying slows the player, suspends turret attacks and uses validated placement.

`EnemyRegistry` supplies scaled stats for the two active enemy types. `TurretRegistry` and shared stat services supply the three active weapons. `ArenaShop.TURRETS` and `ArenaShop.ITEMS` define the supported purchase catalogs; unsupported registry entries must not become offers until their effects have a native 3D implementation and validation.

The current 13 items are Scrap Magnet, Reinforced Hull, Quick Loader, Shock Absorbers, Dense Rounds, Budget Capacitor, Ammo Surplus, Overclock Module, Compact Design, Extended Barrel, Rapid Coolant, Kinetic Enhancer and Heavy Plating. Their actual modifier values drive descriptions and build summaries. See [gameplay](gameplay.md) for balancing and limitations.
