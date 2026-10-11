# 25 new item concepts

Items **1–3, 10, 13, 16, 19–21, 24 and 25 are implemented**. The remaining concepts are proposals only. Numbers are starting points for playtesting. Families describe attacks, so compatible hero weapons can benefit too. Hybrid attacks receive the relevant effect once. Most items have no downside; the interesting choice comes from positioning, timing or target selection.

| # | Item | Family | Rarity | Proposed effect and purpose |
|---|---|---|---|---|
| 1 | Opening Salvo | Projectile | Uncommon | First shot against a previously undamaged enemy deals +25% damage. Rewards target switching. |
| 2 | Return Address | Projectile | Rare | A projectile that misses every enemy returns once toward its firing position for 50% damage. No repeat return. |
| 3 | Slipstream Fletching | Projectile | Uncommon | After travelling 2 m, projectiles gain +20% damage. Gives long firing lanes a purpose. |
| 4 | Tracer Paint | Projectile | Rare | Repeated hits mark a target for 2 seconds; the next different weapon to hit it deals +15% damage and consumes the mark. |
| 5 | Patient Loader | Projectile | Epic | After a weapon has not fired for 2 seconds, its next shot gains +50% damage and one extra pierce. One stored shot. |
| 6 | Aftershock Plate | AoE | Rare | An explosion leaves a smaller delayed pulse at 30% damage after 0.5 seconds. Pulses cannot create more pulses. |
| 7 | Crowd Thermometer | AoE | Uncommon | +4% damage per enemy caught in an area hit, up to +20%. Rewards useful coverage. |
| 8 | Edge Diffuser | AoE | Uncommon | Enemies near the outside edge of an area hit are slowed 20% for 0.8 seconds. Adds control without more radius. |
| 9 | Pressure Pocket | AoE | Epic | Hitting a single enemy with an area attack grants +35% damage to that hit. Keeps area weapons useful against isolated threats. |
| 10 | Cinder Reserve | Fire / burn | Rare | Killing a burning enemy transfers up to 1 second of its remaining burn to the closest unburned enemy within 1.5 m. Transferred burns cannot transfer again. |
| 11 | Grounding Needle | Instant | Uncommon | First instant hit against a full-health enemy briefly slows it 30% for 0.5 seconds. |
| 12 | Echo Capacitor | Instant | Rare | Every fifth instant attack repeats against its original target at 40% damage after 0.2 seconds, if the target survives. |
| 13 | Arc Insurance | Chain-capable Instant | Rare | If a chain has no next target, unused jumps add 8% damage each to the last hit, capped at +24%. |
| 14 | Quiet Charge | Instant | Epic | After 1.5 seconds without a target, store one charge for +40% damage on the next hit. |
| 15 | Static Bridge | Instant | Rare | Hitting an enemy recently struck by a projectile grants +20% instant damage once and clears the priming state. No recursive triggers. |
| 16 | Follow-Through | Kinetic | Epic | Hitting three different enemies with one swing or rolling shot grants that weapon +10% attack speed for 2 seconds. Stacks up to 5 times; triggering refreshes the 2-second duration. |
| 17 | Rubberized Stops | Kinetic | Rare | An enemy knocked into the arena boundary takes one bonus hit worth 25% of the original damage. Per-enemy cooldown 1 second. |
| 18 | Heel Hook | Kinetic | Uncommon | First kinetic hit after an enemy enters reach slows it 25% for 1 second. Per-enemy cooldown 3 seconds. |
| 19 | Counterweight | Kinetic | Rare | Against enemies that resist knockback, deal +20% damage. Makes heavy targets a distinct matchup. |
| 20 | Victory Lap | Kinetic | Epic | A kinetic kill grants the source +10% reach for 2 seconds. Up to 5 active stacks; kills refresh the 2-second duration. |
| 21 | Rescue Beacon | General | Rare | After the hero takes damage, hero and turrets within 3 m gain +15% attack speed for 2 seconds. Cooldown 8 seconds. |
| 22 | Salvage Lens | General | Uncommon | Chests become visible through combat clutter and receive +20% damage from your weapons. Helps deliberate chest hunting. |
| 23 | Field Technician | General | Rare | Carrying a turret for 3 seconds grants it +15% damage for 3 seconds after placement. Does not stack. |
| 24 | Reserve Battery | General | Epic | The first surviving hit that leaves the core below 30% health each wave fully heals it. Core modes only. |
| 25 | Close Partnership | General | Uncommon | Hero and every deployed turret gain +8% damage while within 1.5 m of one another. Every deployed turret in range benefits; the hero bonus applies once. |

## Recommended first candidates

Opening Salvo, Crowd Thermometer, Grounding Needle, Counterweight and Close Partnership establish distinct playstyles with easy-to-read feedback. Aftershock Plate, Return Address and Reserve Battery need stronger visual cues and careful interaction tests; introduce them after the simpler group.

Keep proc effects from triggering themselves, use per-weapon or per-enemy limits as stated, and show actual eligibility in item inspection. Avoid adding automatic permanent income multipliers that also reduce combat pressure. Core-only items should not enter Survival stock; Chain-only items should explain that requirement clearly.

## Implemented behaviour and visibility

The eleven new items are single-copy purchases; the five-stack caps on Follow-Through and Victory Lap refer to their active combat buffs, not five copies of the item. A full melee revolution is one swing; a rolling projectile is one shot. Three distinct targets grant one Follow-Through stack per swing/shot. Both buffs add 10 percentage points per stack, up to +50%, and expire together two seconds after the latest trigger. Timers pause with combat and clear at wave end/restart.

Counterweight checks actual knockback resistance (mass above 1). Return Address activates only at the end of an entirely missed outbound projectile flight; its return targets the original firing position, halves shot damage, and cannot return again. Cinder Reserve keeps the original burn source and DPS, transfers at most one second, and prevents repeat transfer. Reserve Battery does not resurrect a core destroyed by a lethal hit; its stock and chest rewards are limited to core modes.

Buff icons appear above nearby turrets within pickup/inspection range, or all turrets when ranges are toggled on. Hero buffs appear above the hero. Icons show active stacks and a draining duration strip; persistent effects keep a full strip. Entrenchment uses its stack-progress strip. Tooltips explain the effect. Entrenchment, Last Stand and Resonance Link are included alongside the new temporary and proximity buffs.

Validation: `tests/integration/test_item_expansion.gd` exercises procs, source attribution, expiry, pause, stack caps, hero compatibility and core-mode restrictions. `tools/preview_item_buffs.tscn` renders the native buff display for visual inspection.
