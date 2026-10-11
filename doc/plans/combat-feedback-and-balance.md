# Combat feedback and balance refresh

Branch: `feature/combat-feedback-and-balance`. Complete. All seven requested areas implemented or proposed, validated, and ready for playtesting.

| Work | Intended result | Status |
|---|---|---|
| Damage numbers | Readable, polished actual-damage feedback for enemies, hero and core; crit distinction, controlled density, reduced-motion support | Implemented |
| Fire/lightning/shock | Distinct polished effects, persistent burn feedback, meaningful impacts; verify at gameplay zoom | Implemented |
| Later waves | Escalating pressure and enemy composition, especially Medium Protect the Core; preserve early-wave fairness | Implemented |
| Zones/chests | Build zones off for now; destroyed chests retain scrap and have a 25% weighted random-item chance | Implemented; old saved flags also load disabled; tested |
| Quality Over Quantity | Rare → Epic, enemies -30% → -15%, kill scrap +100% → +25%; keep Shop prices +10% | Implemented; tested |
| Hero weapon items | Resolve modifiers by weapon families, applying relevant projectile items to current Ion-style hero; support future weapon/starting-turret definitions | Implemented |
| 25 item concepts | Fresh family-based and general mechanics, limited downsides, no implementation in this goal | Drafted in [new-item-concepts.md](new-item-concepts.md) |

## Findings

- Chest random-item grants already exist and use the Shop weighted item pool. Existing chance was 50%; requested 25% lowers it.
- Quality Over Quantity previously combined easier waves with approximately 1.4× total kill-scrap income before rounding. New baseline is approximately 1.0625×, retaining a small economy benefit and a lower enemy count.
- Hero weapon previously built a narrow damage/speed snapshot. It now uses an explicit family/capability context with the shared modifier math, excluding turret-count and entrenchment-only bonuses.

## Validation coverage

Actual damage rather than requested damage; overkill and DoT aggregation; no numbers for blocked hits. VFX pause and reset on defeat/restart, bounded effects and reduced motion. Wave formulas and composition tables for waves 1/4/10/15/20 on Medium Core. Chest eligibility and item caps. Item rarity/multiplier regression. Hero projectile modifiers and turret-only exclusions. Native screenshots. Full suite and resource audit before final commit/completion.


## Medium Protect the Core comparison

Baseline enemy counts (no count-modifying items). Elite share is additional to the ordinary type composition. Core seekers ignore hero aggro. Spawn rate includes the late-wave acceleration; it compresses the scheduled arrivals, then leaves a cleanup tail within the unchanged wave duration.

| Wave | Previous enemies | New enemies | Duration | Elite share | Core seekers | Arrival rate |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 48 | 48 | 30 s | 0.0% | 0.0% | 1.60/s |
| 4 | 101 | 101 | 45 s | 0.0% | 0.0% | 2.24/s |
| 10 | 206 | 225 | 60 s | 4.5% | 11.2% | 3.96/s |
| 15 | 294 | 382 | 60 s | 8.2% | 20.6% | 7.02/s |
| 20 | 382 | 604 | 60 s | 12.0% | 30.0% | 11.58/s |

Composition shifts at waves 8, 12 and 16. At wave 16+, each ten-enemy pattern has three tanks, two chargers, two scouts, two exploders and one basic. Existing per-difficulty exponential health growth is retained; this pass adds pressure and target priorities rather than another health multiplier. Rules-off neutralizes the new elite/seeker ramp as well as existing difficulty rules. Hard and Brutal retain no elites before wave 4.

## Implemented feedback and hero behavior

- Actual-damage numbers, crit distinction, short hit aggregation, a 64-label pool, reduced-motion behavior and fatal-hit visibility.
- Branching dual-color electrical arcs with small offshoots and endpoint sparks; layered shock rings; textured fire streams with embers and persistent burn silhouettes. Cosmetic geometry does not consume gameplay RNG. Fire animation uses simulation time so pause freezes it.
- Hero Projectile damage, speed, cadence, reach and eligible pierce use item modifiers. Unrelated families, turret-only filters, entrenchment and turret-count effects are excluded. Shop displays the sidearm and previews matching purchases without mutating live caches.
- Quality Over Quantity is Epic, reduces enemy count by 15%, increases kill scrap by 25%, and retains +10% Shop prices.

## Validation evidence and remaining tuning

Resource audit: 204 sources / 37 model records. Native 1280×720 Compatibility captures reviewed for [combat feedback](../art/combat-refresh/combat-feedback.png) and [Shop sidearm previews](../art/combat-refresh/hero-shop.png). The moving ten-turret showcase passed with 90 moving enemies, hits recorded for every initial/final/carried weapon, pause halting damage/projectiles, and defeat clearing attacks. [Showcase report](../art/combat-refresh/showcase.json).

These checks verify mechanics and visual behavior, not a claim that Medium is perfectly balanced. A human Medium Core run through waves 12–20 remains the best next balance check; the new enemy supply also increases available scrap/XP, so economy and pressure should be assessed together.

Final validation: **994 tests passed**, no risky tests or unexpected errors; resource audit passed; native feedback, Shop preview and moving-enemy showcase passed.
