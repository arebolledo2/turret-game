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
| `toughest` | Highest current health; ties go to the nearest |
| `backline` | Nearest Needle Kite, Kiln Lobber or Brood Tender (`TurretTargeting.BACKLINE_TYPES`); nearest enemy of any kind when none is in range |

`TurretTargeting.select(mode, origin, range, candidates)` dispatches by mode; `TurretActor` calls it every 0.2 s when `TurretTargeting.handles(mode)`.

## Status, movement and queries

`StatusEffects3D` reuses shared `StatusEffect` lifetime/refresh rules. Refresh keeps the strongest slow of a damage type and replaces its remaining duration. Across types, the strongest slow wins; slows do not multiply. Intensity is capped at 90%. Slow changes pursuit and dash distance, not knockback or charge timers.

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
