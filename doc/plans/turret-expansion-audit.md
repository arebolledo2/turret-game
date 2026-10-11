# Selected turret expansion: completion audit

Scope: the ten subjects selected for 3D promotion in `turret-expansion-progress.md`, their usable attacks and evolution mechanics, plus arrow and bowling-ball models. Gunblade is an original 3D design, as requested. Work is on `feature/turret-evolution-roster`.

Final verification: **984 tests passed**; resource audit passed for **200 source files and 37 model records**. Both moving-enemy native branch runs passed.

## Playable roster

| Selected subject | Ordinary-play access | Evolution continuation | Verified behavior |
|---|---|---|---|
| Machine Gun | Ion at level 5 | Gatling at 10; Cyclone Gatling at 15 | Sustained aimed fire, rotary spin-up, final piercing |
| Gatling | Machine Gun at level 10 | Cyclone Gatling at 15 | Moving rotor; higher firing rate while spooled; final drums/cage |
| Scattergun (Scattershot) | Ion at level 5 | Crossfire at 10; Omnifire at 15 | Three-shot spread, four directional barrels, twelve radial barrels |
| Crossfire | Scattershot at level 10 | Omnifire at 15 | Separate muzzle origins and outward shot directions |
| Saber | Melee at level 5 | Twin Saber at 10; Orbit Saber at 15 | One/two/three held blade assemblies; shared per-enemy rehit limit |
| Duelist Gunblade | Melee at level 5 | Repeater Blade at 10; Stormblade at 15 | Kinetic sweep plus independent projectile gun; two/three-barrel bursts |
| Siege Cannon | Plasma at level 5 | Moonshot at 10; Worldbreaker at 15 | Slow heavy shells, increasing blast/knockback, hydraulic barrel recoil |
| Bow | Purchasable base | Repeater/Volley/Arrowstorm or Greatbow/Harpoon/Titan | Authored arrows, timed multi-rail bursts or heavy piercing knockback |
| Flamethrower | Purchasable base | Wide Flame/Furnace/Inferno or Focused Jet/Dragon Nozzle/Dragonheart | Cone hits, attributed burn, distinct fan and pressure-nozzle assemblies |
| Bowling Launcher | Purchasable base | Heavy/Demolition/Juggernaut or Bank Shot/Pinball/Ricochet King | Authored rolling balls; piercing knockback or bounded enemy ricochets |

## Evidence and requirement checks

- **Asset provenance and geometry:** all twelve assets have a source builder, `contract.json`, passing geometry/node checks in `validate.json`, and a manifest entry. Files live under `art-source/clockwork-pop/<subject>/` and `assets/models/clockwork/`. The resource audit verifies source/reference existence and exported GLB hashes against the reviewed manifest. Runtime evolution assemblies reuse the frozen meshes or add explicitly articulated hardware; they do not alter those exports.
- **Visual quality:** native close previews and the current transparent Shop portraits show open directional muzzles, handle-held blades, distinct materials and grounded bases. Each implemented evolution stage has a visual change. Recent native moving-enemy screenshots show the final forms at the normal game zoom. Visual judgment is recorded through reviewed images, not inferred from passing geometry tests.
- **Normal access:** `ShopCatalog.DEFAULT_ENTRIES` includes Bow, Flamethrower and Bowling without a content gate. The new purchase integration test spends scrap, creates each actual actor, exposes both branches, and evolves it through all three stages. Existing base branches are exercised through `TurretActor.evolve`, the same path used by the Shop.
- **Evolution rules:** level 5/10/15 choices are ordered, the first branch persists, and identity, ownership count, placement, entrenchment and XP survive evolution. Unit tests cover invalid/unearned branches and frozen settlement snapshots; native integration tests cover model replacement and actual attack changes. Ordinary stat leveling continues after 15.
- **Shop/controller:** portraits and comparisons resolve actual current/candidate stats without mutating combat caches. D-pad and A/B tests cover branch review, confirmation, all banked stages in one visit, cancellation and focus return. Deployment reminds about ready upgrades and permits deliberate deferral without losing them.
- **Attack families:** Gunblade resolves Kinetic and Projectile modifiers separately. Bowling has Projectile and Kinetic families; Flame has area/direct hits plus attributed burn. Regression tests verify source ownership, single-application cone damage and independent hybrid attacks.
- **Projectiles:** arrow and bowling-ball models are used by native shots. Tests cover pooled visual/radius resets, swept multiple contacts, one hit per recipient, ricochet residual movement and no-recipient fallback. Loaded arrows/balls reset between attacks. Native captures show their flight/roll and scaled heavy variants.
- **Runtime use:** `tools/showcase_turret_roster.tscn` checks attributed damage for every selected subject and its final form, then isolates each carried weapon. `--alternate` covers the other Bow/Flame/Bowling branches. `--moving` uses ordinary steering, separation and contact damage, with fresh crowd indexing. Both moving runs recorded damage for every entry and 90 enemies moving over 0.3 m.
- **Lifecycle:** the native showcase checks pause stops damage and projectile movement; ordinary player defeat stops combat and releases active projectiles/flame ribbons; cleanup removes remaining enemies and effects. Timed burst cancellation and effect-pool limits have regression coverage.

Evidence: `doc/art/clockwork-pop/validation/roster-showcase-moving.json`, `roster-showcase-alternate-moving.json`, their `roster-final-*-moving.png` captures, and `evolution-reminder.png`. Close art is in `doc/art/clockwork-pop/previews/`; current portraits are in `assets/ui/turrets/`.

Commands used: `pwsh -NoProfile -File run_tests.ps1`, `python tools/audit_game_resources.py`, and native Godot runs of `res://tools/showcase_turret_roster.tscn -- --moving` with and without `--alternate`.

## Scope distinctions and practical limits

The older `turret-evolution.html` is a broader design proposal. Its Mortar, Shock/Resonator/Lance and Tesla/Relay/Capacitor paths were not among this batch's selected subjects; their names remain proposed registry data and are not exposed as implemented choices. This delivery does not claim those additional models or attacks are complete. The actual selected roster is the table above.

Some proposed final-form details developed during implementation: Cyclone uses a reinforced single rotary assembly, Omnifire fires twelve simultaneous radial shots, and Orbit Saber uses three coordinated blades. Their names, distinct forms and working evolution paths are present; the original proposal is not an exact description of these final mechanics.

Health is raised in the native showcase to keep weapons firing. It establishes functionality and visual readability, not a complete balance study, frame-rate target or real-controller hardware certification. Controller tests inject Godot joypad events. Performance and balance can be tuned in playtesting, as allowed by the asset workflow.
