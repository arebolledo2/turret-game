# Combat

Native 3D combat is implemented in `scripts/game/`. Turrets and player auto-fire use shared stat/modifier services; registry distances and speeds convert to metres through `WorldGeometry.METRES_PER_PIXEL`.

## Damage and attacks

`CombatShot3D` snapshots damage, projectile speed, splash radius, knockback, slow intensity/duration and damage type when fired. `CombatHit3D` carries one resolved hit. `Combat3D` applies damage and emits local notifications for cosmetics and rewards. Splash snapshots its targets before deaths mutate the enemy list.

`Projectile3D` uses ShapeCast3D sweeps and reusable instances. Hit checks stay on the ground plane even when a carried muzzle is elevated; the visible projectile descends from its muzzle height. Reuse resets the complete shot state. Actor contact checks sweep movement segments, including charger dashes. Player invulnerability prevents repeated contact damage during its cooldown.

| Weapon | Runtime behavior |
|---|---|
| Ion | Rapid single-target projectile fire |
| Plasma | Cluster targeting, splash and knockback; interrupts charges |
| Shock | Radial electric pulse with 25% slow for 0.5 seconds |

## Targeting modes

A turret type picks its target by `TurretRegistry.get_targeting(type_id)` (a top-level `targeting` key, or `base_stats.targeting`; default `closest`). `Combat3D.select_target` resolves `closest` and `cluster` (plasma, via `cluster_target`). `TurretTargeting` (`scripts/game/turret_targeting.gd`) resolves the rest, all over living enemies whose hurtbox overlaps the attack range, so bosses and tech-drop crates are valid targets:

| Mode | Picks |
|---|---|
| `farthest` | The enemy furthest from the turret |
| `toughest` | Highest current health; ties go to the nearest (Sniper) |
| `backline` | Nearest Needle Kite, Kiln Lobber or Brood Tender (`TurretTargeting.BACKLINE_TYPES`); nearest enemy of any kind when none is in range |

`TurretTargeting.select(mode, origin, range, candidates)` dispatches by mode; `TurretActor` calls it every 0.2 s when `TurretTargeting.handles(mode)`. Two helpers serve the Sniper line: `toughest_many(origin, range, candidates, count, excluded)` (the top-N toughest, used by Overwatch's marks) and `on_lane(origin, through, range, half_width, candidates, include_front, limit)` (enemies on the straight lane from the turret through the target, nearest first, used by piercing shots).

## Instant hits

`TurretRegistry.FIRE_INSTANT` (`fire_mode: "instant"`) is a hit-scan shot: `TurretActor._fire_instant` re-picks the target when the cooldown is ready (the 0.2 s target cache can be stale), then `Combat3D.impact` hits it at once, with no projectile. `stats.pierce` extra enemies on the lane through the target (half-width `TurretEvolution.SNIPER_LANE_HALF_WIDTH` plus each body's radius, up to the attack range) take the same shot: the nearest `pierce` behind the target for the Piercer Rifle and Overwatch, and every enemy on the whole line, in front of the target too, when pierce is `SNIPER_UNLIMITED_PIERCE` (Horizon Piercer). The crit is rolled once per shot. `CombatEffects3D.show_tracer` draws a pooled, brief bright line from the muzzle.

## Pulse rings and stagger

Quake (`QuakeForm`) extends the `FIRE_PULSE` path: `TurretActor` calls `form.fire_pulse` when the cooldown is up and an enemy is in range, and `form.tick(delta)` runs every combat tick before it. A pulse is a ground telegraph (`TurretEvolution.QUAKE_TELEGRAPH_SECONDS`), then a `ShockwaveRing` (`scripts/game/shockwave_ring.gd`): `advance(delta, candidates)` grows the radius at `QUAKE_RING_SPEED` and returns each living enemy the first time the ring touches its hurtbox, nearest first, so damage, knockback and stagger arrive in distance order. The form queues follow-up pulses (Aftershock, Cataclysm) as beats and drops every beat, ring and fissure in `clear()` whenever combat is not running, so a pause, a wave end or a run reset leaves nothing pending.

Stagger lives on `StatusEffects3D` with its own timer (`staggered_remaining`, `stagger(duration)` refreshes to the longer time, `extend_stagger(duration, cap)` adds up to a cap, default `STAGGER_CAP` 1.5 s, `advance_stagger`, `is_staggered`). A hit carries it as `CombatHit3D.stagger_duration` and `stagger_cap` (`CombatShot3D` copies them; a turret's `stagger` stat feeds `TurretStats.stagger_seconds`; a non-zero cap means extend, else refresh). `EnemyActor` runs the timer every tick, shows a pale ground ring, and on the first tick down cancels charges, pounces and wound-up shots (`_interrupt_actions`). While staggered `_steer` skips the brain and only slides the enemy by its knockback, and `_act` skips contact damage. Bosses and stationary enemies are never staggered. Knockback already interrupted Charger and Hopper (`EnemyActor._after_hit`); stagger keeps them from restarting a windup until it ends.

## Ground zones (S7)

`GroundZones` (`world.ground_zones`, `scripts/game/ground_zones.gd`) holds enemy-only areas on the floor: `add_circle(centre, radius, duration, slow, source_id, style)` and `add_line(from, to, half_width, duration, slow, source_id, style)` (an oriented rectangle with flat ends). Each returns a `GroundZone` (`contains`, `closest_point`, `remaining`). `speed_factor_at(position, margin)` is the one place slows are read: `EnemyActor._steer` takes the minimum of its status slow and the zone factor, so overlapping zones never stack (strongest wins) and the slow is capped at `GameConstants.GROUND_ZONE_MAX_SLOW` (90%), the same rule as `StatusEffects3D`. The hero never reads it (terrain mud is separate). `enemies_in(zone, candidates)` lists living enemies standing in one, for an on-open hit. At most `GameConstants.GROUND_ZONE_MAX` (16) zones exist; adding more recycles the one closest to expiring. Visuals are pooled quads (`ground_zone.gdshader`, styles `disc` and `rift`). The clock only runs in combat, and `clear()` runs when combat stops, on wave end and on run reset.

## Pulse rings and stagger

Quake (`QuakeForm`) extends the `FIRE_PULSE` path: `TurretActor` calls `form.fire_pulse` when the cooldown is up and an enemy is in range, and `form.tick(delta)` runs every combat tick before it. A pulse is a ground telegraph (`TurretEvolution.QUAKE_TELEGRAPH_SECONDS`), then a `ShockwaveRing` (`scripts/game/shockwave_ring.gd`): `advance(delta, candidates)` grows the radius at `QUAKE_RING_SPEED` and returns each living enemy the first time the ring touches its hurtbox, nearest first, so damage, knockback and stagger arrive in distance order. The form queues follow-up pulses (Aftershock, Cataclysm) as beats and drops every beat, ring and fissure in `clear()` whenever combat is not running, so a pause, a wave end or a run reset leaves nothing pending.

Stagger lives on `StatusEffects3D` with its own timer (`staggered_remaining`; `stagger(duration)` refreshes to the longer time, `extend_stagger(duration, cap)` adds up to a cap, default `STAGGER_CAP` 1.5 s; `advance_stagger`, `is_staggered`). A hit carries it as `CombatHit3D.stagger_duration` and `stagger_cap` (`CombatShot3D` copies them; a turret's `stagger` stat feeds `TurretStats.stagger_seconds`; a non-zero cap means extend, otherwise refresh). `EnemyActor` runs the timer every tick, shows a pale ground ring, and on the first tick down cancels charges, pounces and wound-up shots (`_interrupt_actions`). While staggered `_steer` skips the brain and only slides the enemy by its knockback, and `_act` skips contact damage. Bosses and stationary enemies are never staggered. Knockback already interrupted Charger and Hopper (`EnemyActor._after_hit`); stagger also keeps them from starting a new windup until it ends.

## Ground zones (S7)

`GroundZones` (`world.ground_zones`, `scripts/game/ground_zones.gd`) holds enemy-only areas on the floor: `add_circle(centre, radius, duration, slow, source_id, style)` and `add_line(from, to, half_width, duration, slow, source_id, style)` (an oriented rectangle with flat ends). Each returns a `GroundZone` (`contains`, `closest_point`, `remaining`). `speed_factor_at(position, margin)` is the one place slows are read: `EnemyActor._steer` takes the minimum of its status slow and the zone factor, so overlapping zones never stack (strongest wins) and a slow is capped at `GameConstants.GROUND_ZONE_MAX_SLOW` (90%), the same rule as `StatusEffects3D`. The hero never reads it (terrain mud is separate). `enemies_in(zone, candidates)` lists the living enemies standing in one, for an on-open hit. At most `GameConstants.GROUND_ZONE_MAX` (16) zones exist; adding more recycles the one closest to expiring. Visuals are pooled quads (`ground_zone.gdshader`, styles `disc` and `rift`). The clock only runs in combat, and `clear()` runs when combat stops, on wave end and on run reset.

## Taunt, hooks and the Decoy (S1)

The Decoy (`DecoyForm`, `scripts/game/decoy_form.gd`, also the behaviour of the unevolved turret) is the aggro family's first turret. It cannot be damaged (no turret can) and does two things on top of an ordinary `FIRE_PULSE`:

- **Taunt.** While it fights it publishes a `TauntPost` (`scripts/game/taunt_post.gd`: owner turret id, radius in metres from the stat `taunt_range`, `ranged`, hook ring radius) to `world.taunts` (`TauntField`, `scripts/game/taunt_field.gd`). Enemies never scan turrets: `EnemyActor.taunt_post()` asks that short list, which is one `posts.is_empty()` check per enemy per tick in a run with no Decoy. A post caches its position and squared radius (the form refreshes them every tick), so a lookup is float maths over a handful of posts; only a post already in reach touches the turret. The field is cleared on a run reset, a Decoy withdraws its post when combat stops (wave end, pause), when it is picked up (a carried post is skipped), and when the turret leaves the tree or takes a new form (`TurretForm.removed()`, called from `TurretActor._exit_tree` and when the form is replaced).
- **Who answers.** `EnemyEcology.taunt_kind(type)`: bosses and their summons (`lens`, `anchor`, `puppet`) and crates (`tech_drop`) never do; Needle Kites, Kiln Lobbers and Brood Tenders (`TAUNT_RANGED`) only answer a post with `ranged` set (Maelstrom); every other enemy answers the nearest post whose radius covers it. Stationary bodies and core seekers (`ignores_hero`) never answer, and a sleeping Drowse Beetle stays asleep (an awake one answers).
- **Where it plugs in.** `EnemyActor.chase_position()` is now the one goal chooser: the taunt first (the post is kept in `taunt_target`, so the core "stop at the core" rule does not fire while taunted), then the hero or core as before (survive mode returns the hero). Chargers lock their dash on the chosen goal. Brain-driven enemies (`EnemyBrain.move`) swap the hero position for the post position the same way, so Hoppers pounce at it, awake Beetles chase it and ranged enemies keep their firing distance from it.
- **Hooked** is a generic timed status (`TauntField.HOOKED`, `StatusEffects3D.apply_timed("hooked", EnemyActor.HOOK_SECONDS, turret_id)`, one timer per owner, ticked by `EnemyActor._tick_hooked` like the mark; `clear_all_timed` drops every owner's timer). `EnemyActor.hook(owner)` applies it and cancels any wind-up. A hooked enemy ignores the hero and circles its anchor (`TauntField.hook_anchor`, the nearest live post holding one of its hook timers) on one of `HOOK_LANES` lanes starting at the post's `hook_ring`; if no live post holds a hook the next tick drops it. Hooks last until the enemy dies (the duration is far longer than a wave).

Forms (numbers are starting values; the bench is in the roster handoff): the base Decoy pulses 3 damage every 1.5 s over 1.5 m with knockback 150 and a 4.5 m taunt. Bumper Post (level 5): 8 damage every 1.2 s, knockback x1.5. Pile Driver (final, reach 1.8 m): every fourth pulse is a slam, 3x damage over 1.5x the reach with a 0.6 s stagger (`slam_*` params; bosses still resist the stagger). Maelstrom (final): taunt 7 m, `ranged_taunt`, and up to `hooks` (10) enemies in reach are hooked, nearest first, rescanned four times a second; a tick of `hook_share` of the pulse damage lands on each every 0.5 s (a non-kinetic, `is_dot` hit, so shove and slow riders and pulse-hit item rules skip it). A Decoy releases only its own hooks, and does so when combat stops, on pause, when picked up, removed or evolved, and on a run reset. Area bonuses (`area_size`) widen the taunt as well as the pulse; plain reach bonuses widen only the pulse.

## Status, movement and queries

`StatusEffects3D` reuses shared `StatusEffect` lifetime/refresh rules. Refresh keeps the strongest slow of a damage type and replaces its remaining duration. Across types, the strongest slow wins; slows do not multiply. Intensity is capped at 90%. Slow changes pursuit and dash distance, not knockback or charge timers.

Two damage-taken statuses live on `StatusEffects3D`, each with its own timer and multiplier, applied in `EnemyActor._scale_damage`:

| Status | Source | Bonus | Applies to |
|---|---|---|---|
| Exposed | Resonance Engine (a target struck by both ring kinds) | +30% for 2 s | Hits with the `instant` attack family only |
| Marked | Overwatch (`OverwatchForm`) | +25% for 6 s | Any hit with a turret source (`source_id > 0`), burn ticks included; hero, contact and unattributed hits are not amplified |

Stacking: the final hit is `damage * exposure_multiplier * mark_multiplier`, so an Exposed and Marked enemy takes 1.3 x 1.25 = 1.625 times an Instant turret's damage. A mark never stacks with itself (a second Overwatch only refreshes the timer to the longer value). The mark timer runs in `EnemyActor._tick_statuses` (not `_steer`), so stationary enemies such as tech-drop crates lose it on time. Marks end on death and wave end (`StatusEffects3D.clear`), and Overwatch drops all of its marks whenever combat is not running (pause included). A marked enemy shows an amber ground ring. When a marked enemy dies, `OverwatchForm.tick` moves the mark, with its remaining time, to the next toughest unmarked enemy in range.

`ChargeController3D` locks a dash heading at the start of a 0.9-second amber warning, then dashes and recovers. Separation is suspended during warning/dash to preserve the indicated path. Knockback interrupts the charge.

`CrowdGrid3D` snapshots enemies once per physics tick, supports local separation, and shares plasma cluster counts across turrets. Target acquisition runs at 5 Hz. Enemies have no physics bodies. Instead `CrowdGrid3D.resolve_overlaps` (run each tick from `WaveDirector.tick`, right after `rebuild`) hard-separates overlapping enemies in position space (mass-weighted: tanks shove basics aside; tech drops and charging chargers are immovable) and pushes enemies out of turrets and the core (`GameConstants.ENEMY_BODY_RADIUS`, `TURRET_BODY_RADIUS`). The hero is deliberately not an obstacle, since enemies must reach it for contact damage. There is no obstacle navigation, so enemies can still bunch behind a turret.

Pause freezes combat and effect lifetimes. Death, wave end and restart clear temporary effects, impulses and warnings. Carried turrets attack while the hero sidearm is suppressed. Reduced motion disables recoil, pops, flashing and pulsing, and slows continuous motion (walk cycles, rotors, flame/shock shaders, terrain shimmer, damage-number rise, pickup spin) to `GameConstants.REDUCED_MOTION_SPEED` (20%) instead of freezing it, while preserving warnings, range indicators and effect lifetimes.

The retained buff/modifier services have additional calculations tested independently. Fire attacks apply one strongest burn per target with attributed quarter-second ticks. Area-kill chain reactions and conditional turret bonuses are resolved by their dedicated runtime systems. See [gameplay](gameplay.md) for the item allowlist and pricing.

## Combat feedback

`GameAudio` listens to local hit/explosion/pulse notifications. Weapon fire, charger windup, pickups, purchases, wave transitions and terminal states provide explicit cues. Ten general and two reserved critical AudioStreamPlayer3D voices prevent unbounded crowd audio. Cooldowns rate-limit repeated cues; pause suspends playback and timers, and restart/menu teardown clears run-owned sound state. Player-relative AudioListener3D placement keeps spatial sound consistent with the flat arena.

`CombatEffects3D` adds up to 24 reusable muzzle/hit sparks alongside its existing 32 pulse limit. Sparks are static timed markers, including with reduced motion enabled; they do not shake the camera or move collision. Markers share immutable mesh/material resources across enemies. Crowd separation rejects out-of-range neighbors using squared distance before taking a square root.

Turret attack-range checks include the enemy hurtbox footprint (the projectile capsule radius, scaled per enemy). Acquisition, retained-target checks, pulse/splash damage and melee sweeps accept body overlap rather than requiring the center inside range. Melee measures distance to the swept sector, including its endpoints; crowd queries expand for the largest hurtbox before filtering individual bodies. Range indicators continue to show weapon reach, not reach plus enemy size.


`DamageNumbers3D` pools at most 64 labels, combines same-target/type hits over 0.16 s, and expires them after 0.85 s. Critical metadata follows projectile copies, splash, chains and melee. Fatal hero/core hits retain their number through defeat and then fade. No numbers are emitted for invulnerability or other blocked damage.

Hero weapon modifiers use `ModifierSystem.get_hero_weapon_stats` with explicit attack families and capabilities. Its shared numeric modifier calculation excludes turret filters and turret-only static/conditional effects. Live hero snapshots are cached until modifiers change; Shop previews bypass that cache without changing live values. New hero definitions can specify weapon bases and starting turret; this release still exposes only Pip.

The core apparatus retains gentle, steady ring rotation at 20% speed with Reduced Motion enabled. Orb animation, hit flashing and light pulsing remain suppressed; destroyed cores stop rotating.
