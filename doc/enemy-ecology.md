# Enemy ecology

Implemented on `feat/enemy-ecology`, 11 October 2026. [Visual review](art/enemy-ecology/index.html) · [Design notebook](plans/enemy-ecology.html).

## Roles and targeting

The original five enemies retain their attack identities with 10% smaller bodies and collision footprints. The new roster adds:

| Enemy | Behaviour |
|---|---|
| Drowse Beetle | Wanders at 0.7 m/s with brief pauses; chases at 1.0 m/s before difficulty modifiers. Wakes after a 0.4 s warning when damaged or when either the hero or core comes within 2 m of its target body. Chases the nearest target and can damage the core. Loses interest after both targets remain over 3 m away for 2 s. |
| Rivet Hopper | Always hunts the hero. A committed pounce follows a visible warning; knockback interrupts it. Insect anatomy, no canine silhouette. |
| Needle Kite | Holds distance and fires a warned needle. Its aim locks before release, allowing a reliable dodge. |
| Kiln Lobber | Holds distance and drops a warned shell. Targets the core in core modes and the hero in Survival. Core hits use 3% of maximum core HP. |
| Brood Tender | Stays back and deploys pairs of Skitters, with three deployments per parent. Summons do not award scrap or economy kill credit. |

Active limits: four Kites, two Lobbers, two Tenders, eight Skitters globally (four per parent), two lenses, two anchors and four puppets. Capped normal spawns fall back to a cheaper enemy from the same wave's roster. Nearby precision/charge warnings are limited to two, artillery warnings to one. New ranged attacks and charge warnings require the attacker to be onscreen.

## Bosses

All bosses attack the hero, never the core. Their supporting attacks also respect this policy. Killing a boss is optional: the timer ends the round and clears surviving bosses, summons and hostile ordnance. A final combat-tick kill is resolved before cleanup. Rewards are awarded once and enter the existing Keep / Sell review.

| Wave | Boss | Mechanics | Kill reward |
|---|---|---|---|
| 6 | Brass Ram | Locked charges; alternating stomp; paired charges below half health | Epic item |
| 12 | Prism Conductor | Three-bolt volleys and sweeping beam; two lenses at 60% HP; destroy both to interrupt and stun | Epic, 25% chance Legendary |
| 20 | Grand Marionettist | Volleys above 65%; puppets and breakable tether anchors from 65–30%; charges and gapped pulses below 30% | Legendary item |

Boss health uses a fixed benchmark, never the current player's DPS:

`HP = round(reference DPS × normal wave duration × 0.9 × difficulty health multiplier)`

Reference DPS is 30 / 75 / 180 for waves 6 / 12 / 20. These are starting balance assumptions, not measured kill-time guarantees. Rewards respect mode eligibility, stack caps and pending rewards. If no eligible item exists, the fallback is scrap worth 25% of the corresponding item value. Escaped bosses award nothing.

A top-screen boss bar shows health, phase marks and reward rarity; an offscreen indicator helps locate it. Treasure caches use compact anchored amber health bars instead of the former 3D bars.

## Authored wave identities

Roster percentages are encounter-point weights, not exact enemy head counts. Expensive roles consume more points. Deterministic weighted scheduling replaces the expanding global random pool; caps can change the resulting mix. Arrivals are distributed across the combat timer in groups about every 3.5 seconds, with a 0.9-second amber ground warning. Sparse escort budgets accumulate into less frequent groups. A hero or core overlapping a marked point cancels that spawn; it is not moved elsewhere or re-queued. Pending warnings clear at wave end and pause with combat.

| Wave | Identity | Roster weights |
|---|---|---|
| 1 | Sleepy Yard | Drowse 80, Basic 20 |
| 2 | Scout Patrol | Drowse 75, Fast 25 |
| 3 | Scrap Meadow | Drowse 85, Basic 15 |
| 4 | Crossing Paths | Drowse 70, Fast 30 |
| 5 | Wake-up Call | Drowse 60, Basic 25, Fast 15 |
| 6 | Brass Ram | Drowse 90, Basic 10, plus boss |
| 7 | The Hunt | Drowse 25, Basic 35, Hopper 40 |
| 8 | Needle Alley | Basic 30, Fast 25, Kite 45 |
| 9 | Siege Line | Tank 30, Basic 30, Lobber 40 |
| 10 | Hatchery | Drowse 45, Basic 20, Tender 35 |
| 11 | Spring Ambush | Charger 30, Fast 30, Hopper 40 |
| 12 | Prism Conductor | Drowse 80, Basic 20, plus boss |
| 13 | Glass Crossfire | Fast 25, Exploder 25, Kite 50 |
| 14 | Heavy Pursuit | Tank 60, Hopper 40 |
| 15 | Bombardment | Tank 40, Exploder 20, Lobber 40 |
| 16 | Factory Floor | Basic 30, Charger 30, Tender 40 |
| 17 | Rapid Interference | Charger 30, Fast 30, Kite 40 |
| 18 | Last Hunt | Fast 20, Exploder 20, Hopper 60 |
| 19 | Fortress Break | Tank 30, Basic 20, Lobber 30, Tender 20 |
| 20 | Grand Marionettist | Drowse 90, Basic 10, plus boss |

First-five-wave budgets are 60/65/70/75/80% of the normal difficulty budget. No elite or seeker variants appear before wave 6, including Brutal. Boss escort budgets are 25%. Existing difficulty and later-wave pressure still apply. The native director uses this roster; the retained legacy registry availability API is not the native spawn schedule.

## Models and effects

Twelve new textured models cover all five regular enemies, three bosses, and four supporting units. Each has Idle, Walk, Swim and Attack clips. Runtime animation uses manual playback with reduced-motion scaling. Needle bolts, falling shells, glowing beams, tether lines, segmented ground warnings and gapped sector warnings are created in-engine; hostile effects use warm colors.

GLBs: `assets/models/clockwork/`. Editable Blender files, builders, maps, contracts and audit records: `art-source/clockwork-pop/<key>/`. Selected reference images are preserved alongside them. Triangle counts and actual Godot captures are in the visual review. Soft triangle budgets were exceeded where needed for rounded silhouettes and moving hardware; performance has not been benchmarked.

## Implementation and verification

- `scripts/game/enemy_ecology.gd`: identities, costs, caps, rosters, fixed boss HP.
- `enemy_brain.gd`: behaviour states and attack decisions.
- `enemy_ordnance.gd`: hostile damage, warnings, cleanup and visual attacks.
- `ecology_motion.gd`: imported animation playback.
- `scripts/ui/enemy_health_overlay.gd`: boss and cache health presentation.
- `wave_director.gd`, `combat_actor.gd`, `arena_world.gd`: encounter integration.
- `tools/capture_ecology.tscn`: reproducible roster, boss, support, health and effects captures (`--ecology=roster`, etc.).

Full suite: **1,044 passing tests**, 79 scripts, 18,303 assertions. Final focused ecology run: **21 passing tests**, 2,058 assertions. Coverage includes imported animation playback, targets in all three modes, summon caps, pause/cleanup, optional boss timeout, final-tick rewards and attack phase transitions. Captures were visually inspected in Godot. Human playtesting remains the next step for encounter pressure and boss durability.

## Moving-core routes and greed

Convoy routes begin and finish at inset wall doorways, with 1.1 m clearance for the core. Interior waypoints preserve the multi-leg journey. The next route begins at the previous exit; the initial hero and turret spawn inside the entry. Thin dashed marks emphasize the current leg, dim future legs and disappear when completed. Small waypoint dials and wall threshold brackets replace large labels and rings.

Heavy Hauler is the existing Uncommon Convoy-only greed item (two stacks maximum): core speed -20% and kill scrap +15% per stack. Convoy encounter budgets now scale with the full route duration, with no former 2x cap. A slower journey therefore keeps the same approximate arrival pressure for longer and yields additional enemies, rather than stretching a fixed budget across empty time. Tests cover long routes that already exceeded the old cap.

Route and grouped-spawn follow-up validation: **1,051 tests passed** across 80 scripts (18,630 assertions). Includes wall endpoint continuity, Heavy Hauler on long routes, warning delay, hero/core cancellation, pause/cleanup and sparse escort pacing. Actual route and warning visuals were inspected in Godot.


## Scattered arrivals and low-health warnings

Timed arrivals retain the 3.5-second cadence and 0.9-second warnings, but each enemy independently samples its position instead of joining a four-enemy formation or fixed flank. Existing hero/core overlap cancellation remains in place.

Below 35% health, a red screen-edge vignette and LOW HULL label warn about the hero; amber and CORE IN DANGER warn about the core. Intensity rises toward 15% health. Both channels can appear together, split across the edges, while the center stays clear. Healing fades the effect; prep, shop, pause and round-end screens suppress it. Reduced Motion uses a steady effect instead of a gentle pulse.

Scattered-arrival and low-health follow-up: **1,062 tests passed**, 81 scripts, 18,704 assertions. Includes core-triggered beetle wake/contact, independently scattered group positions, warning recovery, pause/prep suppression, and Reduced Motion. Low-health visuals inspected in a rendered Godot capture.


### Convoy spawn exclusion

In Convoy, enemy arrivals must stay at least 4 m from the core's outer radius and outside a 2 m corridor on either side of the entire active waypoint-to-waypoint segment (rounded endpoint clearance included). Completed and future legs are eligible unless they overlap the active corridor or core exclusion. At a waypoint pause, the next leg is considered active. Initial sampling retries safe positions; an unsafe final candidate is skipped. Pending warnings recheck every tick, so a moving core or leg change cancels an unsafe arrival without relocating it. Enemy summons also respect these exclusions. Other modes retain their existing spawn clearance.
