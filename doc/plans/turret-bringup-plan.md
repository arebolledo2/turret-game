# New turret bring-up plan

Written 26 Oct 2026. Roster and rationale: `turret-roster-handoff.md` and the roster artifact. Progression shape: `turret-progression-l5-l10-spec.md` (landed on branch `turret-l5-l10-progression`). Models are out of scope for now: bring each turret in with its base chassis or a placeholder model and swap art later.

## Per-turret loop

Each turret is its own branch and commit(s), in this order:

1. **Engine pieces first.** Build the shared system(s) the turret needs (S-numbers below) with unit tests, before any turret code.
2. **Registry entry.** `TurretRegistry` entry (stats, attack styles, damage types, price), family in `FAMILIES` where relevant, and the item-rule mapping (`get_attack_families`); utility turrets follow the no-attack rule from the handoff.
3. **Base attack** in `TurretActor` (or a `TurretForm` subclass if it has branch-specific state).
4. **Level-5 upgrade and the two level-10 finals** as forms: three rows in the form table (`scripts/data/turret_forms.gd`; its header lists every touch-point), each naming its behaviour class and visual builder, with `implemented` set once the attack and art exist. Paths, the implemented list, models and descriptions all come from the rows. Each upgrade needs a visible hardware change; finals are tuned above the upgrade.
5. **Shop wiring:** stock it (shop pool, price, portrait key falling back to the base id), controller flow, inspector milestones.
6. **Tests:** unit tests for the new logic, one integration test per form, shop gating test, portrait test passes. Run the full suite (`godot-test` skill), zero orphans.
7. **Bench and showcase:** `tools/bench_turret_forms.gd` row per form (finals roughly 1.4 to 1.6 times the upgrade at level 10, tuned per role) and a showcase run.
8. **Docs and handoff:** update the roster artifact status, handoff, and `doc/` pages touched.

Definition of done matches the existing roster. A turret is not done until all eight steps pass.

## Order and scope

Order follows the roster build order (cheapest and lowest risk first, each step leaving something playable).

| # | Turret | Engine pieces | Forms (L5, L10 A, L10 B) | Notes |
|---|---|---|---|---|
| 0 | Groundwork | S2 targeting modes (toughest, backline-first); S8 map DEPLOYABLE to an item family; `"aggro"` entry in `TurretRegistry.FAMILIES`; item rules for no-attack turrets (Focused Arsenal, Army Doctrine, Crosslink Array) | n/a | Done on branch `turret-groundwork` (see `doc/items.md` and `doc/combat.md`). Exposed (S3) is already built |
| 1 | Sniper | S2, S3 | Piercer Rifle, Horizon Piercer, Overwatch | **Built (branch `turret-sniper`).** Stocked, toughest targeting, `FIRE_INSTANT` hit-scan, all three forms, Marked status (separate +25% multiplier, see `doc/combat.md`). Real `cp_sniper` chassis and portraits (model key `sniper`); `SniperEvolutionVisual` adds a muzzle brake (Piercer Rifle), glowing rails (Horizon Piercer) or a spotter mast and ring (Overwatch) |
| 2 | Quake | S7 enemy-only ground zones | Aftershock, Tectonic, Cataclysm | **Built (branches `turret-quake`, `turret-quake-model`).** Stocked, `FIRE_PULSE` with a 0.5 s telegraph and a `ShockwaveRing` (near enemies first), all three forms, stagger status and S7 `GroundZones` (see `doc/combat.md`). Real `cp_quake` chassis and portraits (model key `quake`); `QuakeEvolutionVisual` adds pistons and a ring (Aftershock), cracks and spikes (Tectonic) or ripple rings and pylons (Cataclysm). Cataclysm has no concept art yet |
| 3 | Decoy | S1 taunt targeting and pull | Bumper Post, Pile Driver, Maelstrom | **Logic built (branch `turret-decoy`); real model wired on `turret-decoy-model`.** Stocked at price 10, `FIRE_PULSE` through `DecoyForm`, all three forms, S1 (`TauntField`/`TauntPost` on `world.taunts`, enemy goal choice in `EnemyActor.chase_position()`, hooked timed status, see `doc/combat.md`). Bosses ignore the taunt; ranged enemies answer only Maelstrom. The real `cp_decoy` chassis and portraits are wired, with runtime hardware per form (`DecoyEvolutionVisual`) |
| 4 | Scrap Press | S5 scrap generation, direct deposit, direct XP | Coin Feeder, Treasury, Academy | **Logic built (branch `turret-scrap-press`); real model wired on `turret-scrap-press-model`.** No attack (`FIRE_NONE`, `no_attack`, no family). Stocked at price 14, `ScrapPressForm` for the base and all three forms, S5 `ScrapIncome` (pickup, cash and direct-XP exits; direct XP is folded into the wave's salvage ledger; `TurretForm.wave_end_scrap` pays Treasury's interest, see `doc/combat.md`). Stacking presses keep 60% and 40%. Academy runs at half rate (one drop per 8 s) so XP for about three turrets is near 1.5x Coin Feeder's value. Tuned from a simulated income check, not the bench (GPU busy). The real `cp_scrap_press` chassis and portraits are used; `ScrapPressEvolutionVisual` adds hardware per form |
| 5 | Boomerang | S6 returning projectile path | Sawblade, Perpetual Saw, Boomerang Storm | **ON HOLD (decided 2026-10-30).** 2D concepts keep coming out as curved blades (scythe/pickaxe) instead of a V boomerang; a retry batch (`a5ee55bb-4af0-480c-845a-fecd6ba380c8`) was started on ComfyUI and is unreviewed. Skip this row and take the next. Two base finalists and two finals without art: decisions needed before art, not before code |
| 6 | Mine Layer | S8 deployable runtime | Minefield, Dead Zone, Chain Reaction | Registry entry exists, only DEPLOYABLE style today |
| 7 | Laser | S11 continuous beam | Focus Beam, Halo Cutter, Sunpiercer | Instant family, so Resonance Link counts it |
| 8 | Lullaby and Discord | S4 enemy behaviour overrides | Deep Sleep, Coma, Sandman / Riot Coil, Anarchy, Civil War | After Decoy is playtested. Sleep builds on Drowse Beetle wake rules; infighting is new |
| 9 | Beacon, Drone Bay | S9 auras and healing / S10 drone actors | Overclock Beacon, Command Spire, Aegis Field / Escort Drones, Guardian Wing, Reaper Swarm | Hold until the first batch is playtested |
| (parallel) | Tesla and Plasma Constellation | S12 delayed ground shell | Forked Coil, Storm Network, Thunderhead / Constellation | Finish existing turrets whenever convenient; Tesla final models exist |

## Open items before starting

- **Shop slot count:** the roster notes assumed one weapon per visit, but `GameConstants.SHOP_TURRET_MAX` is now 4 slots at 37.5% each (mean 1.5 weapons). Re-check what that means for a 19-turret pool before stocking new turrets.
- **Retune and cleanup of the progression change** (spec steps 4 and 5) still need doing; the retune is best done once more finals exist, but the existing 20 finals can be benched now.
- **Unrelated bug to check:** the bench prints "axis Vector3 (0,0,0) must be normalized" from `projectile_3d.gd:209` on the bowling ball; confirm whether it predates the progression change.
- **Art gaps (not blocking code):** Boomerang and Lullaby finalist choice; no favorites for Cataclysm, Perpetual Saw, Boomerang Storm, Civil War; no level-5 concepts exist yet for any turret.
