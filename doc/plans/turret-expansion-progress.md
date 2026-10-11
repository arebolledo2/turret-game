# Turret expansion implementation

User objective: all ten selected turret subjects must have attractive 3D models, usable attacks, and working evolution mechanics. Include authored arrow and bowling-ball projectiles. Gunblade is an original 3D design; rejected concepts are not binding. Completion requires native gameplay and visual evidence, not only registry entries or unit tests.

Branch: `feature/turret-evolution-roster`.

## Delivery map

| Subject | Concept image ID | Intended entry | Model state |
|---|---|---|---|
| Machine Gun | 16432b6c-d281-418b-af9d-4d4fbdce97de | Ion level-5 sustained-fire branch | Frozen iter06; native review pending |
| Gatling | e5e10ad6-29b0-4173-bcbd-e0ecfe86d07d | Sustained-fire level 10; replace concept twin barrels with rotary cluster | Pending |
| Scattergun | c914ea5d-2c1f-44ae-b38b-f57d5e632f67 | Ion level-5 spread branch | Frozen iter04; native review pending |
| Crossfire | 7352de21-d29f-4285-9c5f-e2787519ad04 | Spread branch level 10 | Pending |
| Saber | 8cb05b2f-5329-4108-ad2c-7aaa0836dfff | Melee level-5 saber branch | Frozen iter04; native review pending |
| Gunblade | Original 3D design | Melee level-5 hybrid branch | Pending |
| Siege Cannon | 81b13b6c-ac73-4069-b4c3-e1cd4b2fafff | Plasma level-5 siege branch | Pending |
| Bow | 3a7e7234-058c-4fc4-a9c9-6a662138253e | New purchasable base | Pending |
| Flamethrower | 851a89bb-f123-4b57-87af-52f161ed3659 | New purchasable base | Pending |
| Bowling Launcher | 4ec16c8d-ee61-4de5-8b1e-cc88aaf53437 | New purchasable base | Pending |

## Required systems and validation

- Ordered free evolution choices at levels 5/10/15; first branch choice persists. No XP, identity, placement, entrenchment or ownership reset. All earned milestones can resolve in one Shop visit.
- Shop Turrets tab offers controller-accessible branch comparisons/confirmation and shows actual evolved names, attack families, art and stats. Deployment must not silently discard pending evolution choices.
- Per-attack family modifiers: hybrid melee and projectile attacks receive appropriate effects once. Ownership/count effects use base lineage.
- Sustained machine-gun fire, Gatling spin-up, spread volleys, multi-angle fire, blade sweep, hybrid shooting, slow heavy splash, arrows, flame cone plus attributed burn, and rolling bowling knockback with bounded contacts.
- New base turrets appear in stock; every form can be reached in ordinary play and directly exercised in a deterministic developer showcase.
- Authored arrow and bowling-ball visuals, appropriate projectile collision sizes and lifetimes, pool reset, carried firing, pause/death/cleanup behavior.
- Visual evolution changes at 5/10/15, using authored chassis plus meaningful articulated upgrades. Distinct names alone do not satisfy visual evolution.
- Preserve normal level stat bonuses and current XP curve. No level cap after 15.
- Models: source builders, frozen export/contract, reference when applicable, manifest entry, native imported preview. Check silhouettes at gameplay zoom, pivots/muzzles, glow and moving parts.
- Tests: progression/ownership invariants, each attack and evolution, damage modifiers, DoT attribution, collision and pooled projectile reset, controller evolution selection. Full suite and resource audit before completion.

## Current state

- Branch definitions and pure ordered evolution state added; focused tests passed.
- First three models have frozen exports and harness review. Native visual verification and promotion remain pending.
- Burn lifetime, stronger-burn replacement and original-source partial-tick attribution have focused tests. No flame weapon is wired yet.
- Runtime form switching, expanded attacks, Shop evolution controls, remaining models, projectile models, native visual review and full completion audit remain outstanding.
