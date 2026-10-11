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

### Controller evolution navigation

Fixed ShopScreen overwriting the selected turret’s rightward link to evolution choices. Controller D-pad navigation now enters and traverses the current branch buttons, returns left to the selected turret, and exits right/down to Deploy. Selecting a different turret rebuilds links; focused choices scroll into view. The roster marks evolution-ready turrets and the Turrets tab shows a ready count even from Offers. Integration tests inject D-pad and A events to exercise both choices, all three earned stages in one visit, evolved portraits, and selection changes. Full branch comparison/confirmation and native gameplay review remain outstanding.

### Evolution preview and confirmation

Selecting a branch opens a modal portrait, attack description, and before/after damage, firing/sweep rate, reach and applicable blast radius. Gunblade includes its separate gun stats. Values resolve with current items, level and position bonuses without changing progression, model or combat caches; a regression test compares the prediction against the committed evolution. A confirms and B returns to the roster without changes. Native 1280×720 layout reviewed with `tools/preview_shop.tscn -- --evolution`. Roster ready labels now reserve height above their XP bars. Resource audit: 190 source files / 37 models.

### Native roster combat showcase

`tools/showcase_turret_roster.tscn` runs all ten subject entries with normal turret physics and projectile collision at the default game zoom. It records attributed hits for initial and final forms, then isolates each carried turret after clearing existing shots and burns. It also checks pause prevents damage/projectile movement and cleanup removes enemies, shots and flame ribbons. `--alternate` exercises the Greatbow, Focused Jet and Heavy Roller branches instead of Repeater Bow, Wide Flame and Bank Shot. Reports and initial/final PNGs are saved under `.test-results/roster-*`.

This is a durable stationary-target showcase, not evidence of encounter balance or moving-crowd behavior. Native captures show readable weapon silhouettes, rotating multi-blade forms and multi-angle fire; the largely unchanged chassis on several later forms still require their planned visual evolution pass. Full suite remains 976 passing tests; resource audit covers 192 source files and 37 models.

### Bow visual evolution

Repeater Bow / Volley Ballista / Arrowstorm now use two / three / five authored bow channels on a widened receiver. Each burst launches from its own muzzle and converges on the snapshotted target; all loaded arrows hide and reload together. Greatbow / Harpoon Ballista / Titan Bow use a widening horizontal bow with one / two / three layered limb assemblies and a thicker loaded arrow. The exit remains at the original depth to avoid passing through close targets. No Blender source/export changes: runtime assemblies reuse the frozen authored meshes/materials.

Triangle counts: base 9,688; repeater forms 12,944 / 16,200 / 22,712; heavy forms 9,688 / 12,760 / 15,832. Extra geometry buys distinct channels and laminate silhouettes. Shared materials and mesh resources are reused; draw-call optimization remains a later performance pass. All six portraits rebuilt and reviewed on a dark background. Regression tests cover channel/muzzle correspondence, converging shots, reload visibility, horizontal layers and unchanged muzzle reach. Full suite: 978 passed.

### Flamethrower visual evolution

Wide Flame / Furnace Fan / Inferno Crown gain one / two / three additional burner pairs on a brass fuel manifold. Each open burner has a recessed bore and contributes a narrow flame stream; the outer streams track the 60 / 85 / 110 degree attack fan. Focused Jet / Dragon Nozzle / Dragonheart gain an increasingly long tapered pressure nozzle with cooling rings, and the flame origin moves to its actual exit. The original tank, hose, gauge and base remain the authored chassis. Added parts are runtime meshes with shared brass/teal/graphite materials. Cone damage and burn attribution remain one attack irrespective of emitter count.

Updated all six portraits. Native close and default-zoom reviews show distinct fan/nozzle silhouettes and effects aligned with the new hardware. Targeted regression coverage checks burner counts, forward orientation, staged nozzle extension, single-hit damage and burn source. Other branches still need their visual evolution passes.

### Bowling visual evolution

Heavy Roller / Demolition Roller / Juggernaut widen and reinforce the authored return housing with one / two / three paired hydraulic braces. The loaded ball stays spherical as it grows; the muzzle height scales exactly with its projectile collision radius. Ramp and plinth widen to support the larger payload. Bank Shot / Pinball Engine / Ricochet King gain one / two / three bumper pairs on the ramp and a pair of brass launch paddles. The paddles kick on firing and settle after 0.22 seconds; Reduced Motion keeps them still. Collision and ricochet mechanics remain unchanged.

All six portraits regenerated; dark-background comparison reviewed. Regression coverage checks spherical loaded balls, radius-to-launch-height agreement at all stages, staged hardware counts, mirrored paddle movement, settling and Reduced Motion.

### Gunblade visual evolution

Repeater Blade adds a second open brass barrel above the authored gun; Stormblade adds two upper barrels for a triangular three-barrel assembly. Teal receivers connect the new hardware while leaving the curved ivory blade exposed. Every burst round launches from its corresponding visible muzzle and follows the rotating assembly. The authored base, arm, grip and blade remain intact. Updated both later-form shop portraits and reviewed their silhouettes. Regression assertions cover barrel counts at each stage, distinct shot origins, rotating headings and original source attribution.

### Siege visual evolution

Moonshot widens the authored open barrel and adds paired hydraulic recoil housings, sliding rods and reinforcement bands. Worldbreaker adds a second hydraulic pair and a larger bore. The launch point is now a child of the recoiling barrel, including the base Siege form, so shot origins follow the visible opening. Barrel length stays unchanged to preserve close-target behavior. Both later-form portraits rebuilt and reviewed. Regression checks cover the per-stage cylinder pairs and muzzle movement/settling during recoil.

### Omnifire and Cyclone visual evolution

Omnifire reuses the authored Crossfire barrels and collars in a twelve-spoke radial assembly. Every round now leaves its own open bore; the existing twelve evenly spaced directions remain unchanged. Cyclone Gatling gains twin ammunition drums and a brass/mint cage parented to the spinning rotor. These additions distinguish the final forms from their level-10 chassis. Both final portraits regenerated and reviewed. Regression checks match all twelve projectile origins and headings to their visible muzzles and verify the final Gatling hardware.

### Pending evolution deployment reminder

Deploy checks available free evolutions. If any are ready, a modal defaults to Review Turrets, which selects and focuses the first ready turret. Deploy Anyway starts the wave with XP and unspent evolution milestones intact; Back or controller B returns to the Shop. Normal deployment is unchanged when no upgrade is available. Controller tests cover review targeting, cancel focus, deliberate deployment with preserved growth, and uninterrupted deployment without ready forms. Native 1280x720 layout reviewed with `tools/preview_shop.tscn -- --reminder`.
