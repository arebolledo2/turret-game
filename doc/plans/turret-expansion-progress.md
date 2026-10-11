# Turret expansion implementation

User objective: all ten selected turret subjects must have attractive 3D models, usable attacks, and working evolution mechanics. Include authored arrow and bowling-ball projectiles. Gunblade is an original 3D design; rejected concepts are not binding. Completion requires native gameplay and visual evidence, not only registry entries or unit tests.

Branch: `feature/turret-evolution-roster`.

## Delivery map

| Subject | Concept image ID | Intended entry | Model state |
|---|---|---|---|
| Machine Gun | 16432b6c-d281-418b-af9d-4d4fbdce97de | Ion level-5 sustained-fire branch | Imported; native preview reviewed; level-5 attack and Shop choice wired |
| Gatling | e5e10ad6-29b0-4173-bcbd-e0ecfe86d07d | Sustained-fire level 10; replace concept twin barrels with rotary cluster | Imported; spin-up attack and native preview verified |
| Scattergun | c914ea5d-2c1f-44ae-b38b-f57d5e632f67 | Ion level-5 spread branch | Imported; native preview reviewed; level-5 attack and Shop choice wired |
| Crossfire | 7352de21-d29f-4285-9c5f-e2787519ad04 | Spread branch level 10 | Imported; four muzzle volley and native preview verified |
| Saber | 8cb05b2f-5329-4108-ad2c-7aaa0836dfff | Melee level-5 saber branch | Imported; native preview reviewed; level-5 attack and Shop choice wired |
| Gunblade | Original 3D design | Melee level-5 hybrid branch | Imported and native preview reviewed; blade/gun attacks independently resolve item families |
| Siege Cannon | 81b13b6c-ac73-4069-b4c3-e1cd4b2fafff | Plasma level-5 siege branch | Imported; heavy splash shot and native preview verified |
| Bow | 3a7e7234-058c-4fc4-a9c9-6a662138253e | New purchasable base | Imported and native preview reviewed; base attack and both three-stage evolution paths wired |
| Flamethrower | 851a89bb-f123-4b57-87af-52f161ed3659 | New purchasable base | Imported and native preview reviewed; base attack and both three-stage evolution paths wired |
| Bowling Launcher | 4ec16c8d-ee61-4de5-8b1e-cc88aaf53437 | New purchasable base | Imported and native preview reviewed; base attack and both three-stage evolution paths wired |

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

- All ten subject models are imported, with builders, frozen audits and native close previews. Original Gunblade is authored independently; arrow and bowling-ball projectile models are imported and used in combat.
- Machine Gun, Scattershot, Saber, Gunblade and Siege are available level-5 choices. Gatling and Crossfire are available at level 10; Cyclone Gatling and Omnifire attacks are available at level 15. Gunblade progresses through Repeater Blade and Stormblade at levels 10/15 with two-/three-shot bursts and final-stage piercing. Saber now advances through Twin Saber and Orbit Saber, with two/three authored arm-and-blade assemblies and matching sweep directions. Siege now advances through Moonshot and Worldbreaker with larger shells, blasts and knockback.
- Bow, Flamethrower and Bowling are purchasable base turrets. Both branches on each resolve through levels 5/10/15 with distinct attacks: timed arrow bursts / heavy arrows, wide flame / focused burn, heavy rollers / enemy-to-enemy ricochets.
- Burn attribution, projectile collision size and pool reset, multi-contact sweeps, ricochet residual movement and one-hit-per-enemy behavior have regression coverage.
- Shop build summaries and purchase previews resolve fresh evolved instance stats without mutating combat caches. Gunblade has separate gun numbers and family badges in detailed inspection.
- Flame streams have a bounded pool, reduced-motion support and native visual review. Default-zoom representative combat review is still needed.

## Outstanding work toward the full objective

- Finish remaining branch mechanics and milestones; do not treat current availability gates as final scope.
- Distinct visual evolution treatments at 5/10/15 for the remaining branches. Saber has native-reviewed one/two/three-blade forms. The new-base branches currently reuse the same authored chassis; larger projectiles and attack changes alone do not complete this requirement.
- Evolved shop portraits, comparison/confirmation polish, controller evolution flow, and pending-choice deployment reminder.
- Native deterministic showcase covering all ten subjects, their later forms, carried firing, crowded combat, normal gameplay zoom, and pause/death/cleanup behavior.
- Balance and visual review, then full requirement-by-requirement completion audit.

## Latest verification

- Full suite: 972 passing tests. Latest additions verify evolved shop summaries and purchase-preview cache isolation.
- Native close previews: `.test-results/evolution-preview.png`, `.test-results/expansion-preview.png`, `.test-results/flame-preview.png` from `tools/preview_evolution.tscn`.
- Last resource audit: 189 source files and 37 model records. Re-run on final state before completion.
- This remains an interim implementation. The goal is active and incomplete.

### Shop portrait pass

Rendered 41 transparent portraits from the actual native actor assemblies: eight base turrets and 33 implemented evolution forms. The individual turret inspector selects its current branch and stage; Bow, Flamethrower and Bowling offers now have authored-model portraits. The renderer uses a front three-quarter camera so the muzzle, blade and bowling ramp remain visible. Reviewed a 12-form contact sheet in `.test-results/shop-portraits-review.png`; remaining forms sharing the same assemblies use the same framing. Full suite: 972 passing tests. This does not replace the outstanding crowded-combat and controller validation.
