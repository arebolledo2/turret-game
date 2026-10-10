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

## Status, movement and queries

`StatusEffects3D` reuses shared `StatusEffect` lifetime/refresh rules. Refresh keeps the strongest slow of a damage type and replaces its remaining duration. Across types, the strongest slow wins; slows do not multiply. Intensity is capped at 90%. Slow changes pursuit and dash distance, not knockback or charge timers.

`ChargeController3D` locks a dash heading at the start of a 0.9-second amber warning, then dashes and recovers. Separation is suspended during warning/dash to preserve the indicated path. Knockback interrupts the charge.

`CrowdGrid3D` snapshots enemies once per physics tick, supports local separation, and shares plasma cluster counts across turrets. Target acquisition runs at 5 Hz. Enemies have no physics bodies. Instead `CrowdGrid3D.resolve_overlaps` (run each tick from `WaveDirector.tick`, right after `rebuild`) hard-separates overlapping enemies in position space (mass-weighted: tanks shove basics aside; tech drops and charging chargers are immovable) and pushes enemies out of turrets and the core (`GameConstants.ENEMY_BODY_RADIUS`, `TURRET_BODY_RADIUS`). The hero is deliberately not an obstacle, since enemies must reach it for contact damage. There is no obstacle navigation, so enemies can still bunch behind a turret.

Pause freezes combat and effect lifetimes. Death, wave end and restart clear temporary effects, impulses and warnings. Carried turrets do not attack. Reduced motion disables bobbing, recoil and hit blinking while preserving warnings, range indicators and effect lifetimes.

The retained buff/modifier services have additional calculations tested independently. Damage-over-time attacks, temporary turret buffs, chain reactions and other unsupported effects are not exposed by the current shop. See [gameplay](gameplay.md) for the item allowlist and pricing.

## Combat feedback

`GameAudio` listens to local hit/explosion/pulse notifications. Weapon fire, charger windup, pickups, purchases, wave transitions and terminal states provide explicit cues. Ten general and two reserved critical AudioStreamPlayer3D voices prevent unbounded crowd audio. Cooldowns rate-limit repeated cues; pause suspends playback and timers, and restart/menu teardown clears run-owned sound state. Player-relative AudioListener3D placement keeps spatial sound consistent with the flat arena.

`CombatEffects3D` adds up to 24 reusable muzzle/hit sparks alongside its existing 32 pulse limit. Sparks are static timed markers, including with reduced motion enabled; they do not shake the camera or move collision. Markers share immutable mesh/material resources across enemies. Crowd separation rejects out-of-range neighbors using squared distance before taking a square root.
