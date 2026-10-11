# Combat feedback and balance refresh

Branch: `feature/combat-feedback-and-balance`. Goal active. Finish all seven requested areas; native visual review and gameplay tests are required before completion.

| Work | Intended result | Status |
|---|---|---|
| Damage numbers | Readable, polished actual-damage feedback for enemies, hero and core; crit distinction, controlled density, reduced-motion support | Pending |
| Fire/lightning/shock | Distinct polished effects, persistent burn feedback, meaningful impacts; verify at gameplay zoom | Pending |
| Later waves | Escalating pressure and enemy composition, especially Medium Protect the Core; preserve early-wave fairness | Investigating |
| Zones/chests | Build zones off for now; destroyed chests retain scrap and have a 25% weighted random-item chance | Implemented; old saved flags also load disabled; validation running |
| Quality Over Quantity | Rare → Epic, enemies -30% → -15%, kill scrap +100% → +25%; keep Shop prices +10% | Implemented; full validation running |
| Hero weapon items | Resolve modifiers by weapon families, applying relevant projectile items to current Ion-style hero; support future weapon/starting-turret definitions | Pending |
| 25 item concepts | Fresh family-based and general mechanics, limited downsides, no implementation in this goal | Drafted in [new-item-concepts.md](new-item-concepts.md) |

## Findings

- Chest random-item grants already exist and use the Shop weighted item pool. Existing chance was 50%; requested 25% lowers it.
- Quality Over Quantity previously combined easier waves with approximately 1.4× total kill-scrap income before rounding. New baseline is approximately 1.0625×, retaining a small economy benefit and a lower enemy count.
- Hero weapon builds a narrow damage/speed snapshot separately from turret attack-family resolution; this needs a deliberate shared modifier context, without accidentally applying turret-count/entrenchment-only bonuses to the hero.

## Validation to finish

Actual damage rather than requested damage; overkill and DoT aggregation; no numbers for blocked hits. VFX reset on pause/defeat/restart, bounded effects and reduced motion. Wave formulas and composition tables for waves 1/4/10/15/20 on Medium Core. Chest eligibility and item caps. Item rarity/multiplier regression. Hero projectile modifiers and turret-only exclusions. Native screenshots. Full suite and resource audit before final commit/completion.
