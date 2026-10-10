# Item migration — shipped first pass

All 43 stocked IDs remain stable. Existing feature, wave, stack and Convoy gates still apply. Dense Rounds moves to Uncommon to distinguish it from Polished Barrels. Prices below are before wave and shop modifiers; art is `assets/ui/items/<id>.svg`.

36 of 43 items (84%) have no explicit drawback. Retained trade-offs are Heavy Plating, Hardpoint, Heavy Hauler, Elite Forces, Last Stand, Quality Over Quantity and Glass Cannon Core. Balance still needs human playtesting.

| Stable ID | Name (previous name if changed) | Rarity | Base scrap | Cap | Effect |
|---|---|---|---:|---:|---|
| `scrap_magnet` | Scrap Magnet | Common | 10 | Unlimited | Pickup radius +20%. |
| `reinforced_hull` | Reinforced Hull | Common | 10 | Unlimited | Max hull +4. |
| `quick_loader` | Quick Loader | Common | 10 | Unlimited | Attack speed +7% for firing and sweeping turrets. |
| `dense_rounds` | Dense Rounds | Uncommon | 18 | Unlimited | Projectile damage +10% and projectile speed +15%. |
| `budget_capacitor` | Budget Capacitor | Common | 10 | Unlimited | Reroll costs -10%. |
| `compact_design` | Compact Design | Common | 10 | 3 | Turret purchase scaling -4 percentage points. |
| `extended_barrel` | Extended Barrel | Uncommon | 18 | Unlimited | All turret reach +15%. |
| `rapid_coolant` | Rapid Coolant | Uncommon | 18 | Unlimited | Attack speed +15% for firing and sweeping turrets. |
| `heavy_plating` | Heavy Plating | Uncommon | 18 | Unlimited | Max hull +5. Move speed -3%. |
| `mass_production` | Mass Production | Uncommon | 18 | 2 | Turret purchase scaling -10 percentage points. |
| `polished_barrels` | Polished Barrels | Common | 10 | Unlimited | Projectile damage +10%. |
| `blast_charges` | Blast Charges | Common | 10 | Unlimited | Area radius +12%. Existing area knockback +8%. |
| `capacitor_bank` | Capacitor Bank | Common | 10 | Unlimited | Instant damage +8%. |
| `weighted_bat` | Counterweight (was Weighted Bat) | Common | 10 | Unlimited | Kinetic damage +12%. |
| `concrete_footings` | Concrete Footings | Common | 10 | 3 | Entrench stacks arrive 15% faster. |
| `static_grounding` | Static Grounding | Common | 10 | Unlimited | Existing Instant slows: +10 percentage points strength and +0.2s duration. |
| `faulty_wiring` | Pulse Regulator (was Faulty Wiring) | Common | 10 | Unlimited | Instant attack speed +10%. |
| `ion_doctrine` | Projectile Doctrine (was Ion Doctrine) | Uncommon | 18 | 2 | Projectile damage +20%. |
| `plasma_doctrine` | Area Doctrine (was Plasma Doctrine) | Uncommon | 18 | 2 | Area damage +20%. |
| `voltage_doctrine` | Instant Doctrine (was Voltage Doctrine) | Uncommon | 18 | 2 | Instant damage +20%. |
| `bat_doctrine` | Kinetic Doctrine (was Bat Doctrine) | Uncommon | 18 | 2 | Kinetic damage +20%. |
| `piercing_rounds` | Piercing Rounds | Uncommon | 18 | 2 | Direct projectiles pass through 1 extra enemy. Explosive shots do not pierce. |
| `cluster_warheads` | Cluster Warheads | Uncommon | 18 | 2 | Area radius +30%. |
| `superconductors` | Superconductors | Uncommon | 18 | 2 | Instant chains gain 1 jump; existing Instant slows are 25% stronger. |
| `spiked_bat` | Impact Head (was Spiked Bat) | Uncommon | 18 | 2 | Kinetic knockback +40% and reach +20%. |
| `hardpoint` | Hardpoint | Uncommon | 18 | 2 | Entrench stack limit +2 and bonus per stack +50%. Carry speed -10%. |
| `tracked_chassis` | Tracked Chassis | Common | 10 | 3 | Core movement speed +15%. |
| `overdrive_engine` | Overdrive Engine | Uncommon | 18 | 2 | Core movement speed +30%. |
| `heavy_hauler` | Heavy Hauler | Uncommon | 18 | 2 | Core movement speed -20%: longer rounds, more enemies. Kill scrap +15%. |
| `arc_rod` | Arc Rod | Rare | 28 | 2 | Instant chains gain 2 jumps and retain 15 percentage points more damage per jump. |
| `plasma_capacitor` | Blast Amplifier (was Plasma Capacitor) | Rare | 28 | 2 | Area radius +60%. Existing area knockback +50%. |
| `killzone_bat` | Return Spring (was Killzone Bat) | Rare | 28 | 2 | Kinetic attacks can hit the same enemy twice as often. |
| `overwatch_optics` | Overwatch Optics | Rare | 28 | 2 | Instant reach +30% and damage +10%. |
| `army_doctrine` | Army Doctrine | Rare | 28 | 1 | Attack speed +3% per turret beyond the third, up to +30%. |
| `elite_forces` | Elite Forces | Rare | 28 | 1 | With 5 or fewer turrets: damage +40%, reach +25%. Turret purchase scaling +8 percentage points. |
| `last_stand` | Last Stand | Rare | 28 | 1 | Below 30% hull: attack speed +40%. Max hull -10%. |
| `quality_over_quantity` | Quality Over Quantity | Rare | 28 | 1 | Enemies per wave -30%, kill scrap +100%. Shop prices +10%. |
| `glass_cannon_core` | Glass Cannon Core | Epic | 40 | 1 | All turret damage +40%. Max hull -25%. |
| `mono_type_mastery` | Focused Arsenal (was Mono-Type Mastery) | Epic | 40 | 1 | When every owned turret shares an attack family: damage +50%, attack speed +25%. |
| `reactor_overload` | Reactor Overload | Epic | 40 | 1 | Area kills detonate for 40% of the killing damage at 60% of its area radius. Chains up to 3 deep. |
| `storm_conductor` | Resonance Link (was Storm Conductor) | Epic | 40 | 1 | Instant turrets within 4 m of another Instant turret deal +35% damage. |
| `elemental_conduit` | Combined Arms (was Elemental Conduit) | Legendary | 60 | 1 | Damage +12% per attack family represented by a separate owned turret, up to +48%. |
| `whirlwind_frame` | Whirlwind Frame | Legendary | 60 | 1 | Kinetic sweep speed +100%, reach +50%; hits slow 25% for 0.5s. |
