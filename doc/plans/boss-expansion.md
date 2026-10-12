# Boss expansion â€” implementation tracker

Source: batch `cc4bb1fb-164b-42e8-a9e5-54db82874c4e`, one favorite per subject. All bosses hunt the hero, retain optional timer-based completion, visible health bars and high-rarity Keep/Sell rewards.

| Wave | Boss | Encounter |
|---|---|---|
| 6 | Brass Ram (existing) | Charges and stomps |
| 8 | Frostforge Yeti | Alternating fist impacts; enraged double slam below half HP |
| 10 | Broadside Baron | Four corner cannons with 120Â° outward arcs and locked salvo warnings; rear guns added, fins removed |
| 12 | Prism Conductor (existing) | Volleys, sweep and lenses |
| 14 | Crucible Crab | Furnace bombardment alternating with a warned heat sweep |
| 16 | Skyfall Kestrel | Fast committed bombing passes; marked artillery impacts along a line |
| 18 | Pendulum Regent | Alternating hammer strikes and a pendulum beam sweep; recovery windows |
| 19 | Crownwheel Colossus | Warned straight rolling rushes and a gapped radial discharge |
| 20 | Grand Marionettist (existing) | Multi-phase final encounter |

## Completion checklist

- [x] Inventory favorites and preserve modeling references/contracts.
- [x] Six polished, textured and animated models, inspected from multiple views.
- [x] Promote sources/GLBs and verify actual Godot imports and animation.
- [x] Implement all six encounters and distinct wave assignments.
- [x] Verify warnings, cannon arcs, hero-only damage, pause, death and wave cleanup, rewards.
- [x] Inspect in-engine roster and attack captures, run focused and full tests.
- [x] Document results, commit completed work and provide playtest entry points.

First five waves remain unchanged. Boss health interpolates the existing fixed DPS benchmarks (30 at wave 6, 75 at 12, 180 at 20); it does not scale with the player's build. New bosses initially award Epic items. Late boss density is intentional for this first playtest pass, per the request to put every boss on a distinct wave.

## Validation

Full GUT suite: 1,000 tests, 24,178 assertions passed (31.2 s). Focused expansion suite: 10 tests, 3,842 assertions. Native Godot roster and attack captures inspected for all six bosses. [Visual review](../art/boss-expansion/index.html).

The resource audit finds a pre-existing missing `tools/dump_items.gd` referenced by `tools/dump_items.tscn`; this unrelated developer utility was left unchanged. Runtime imports and tests pass.
