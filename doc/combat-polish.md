# Native audio and combat feedback — 2026-09-17

This slice builds on the approved 3D cutover (`2917795`) on `feat/3d-combat-polish`.

## Player-facing changes

- Distinct ion, plasma and shock sounds; charger warning, hull/impact, scrap, purchase, wave, victory and defeat cues.
- Native spatial sound follows an AudioListener3D on the player. A fixed pool of ten general and two critical voices prevents unbounded audio; rate limits keep crowd sounds bounded. Pause suspends playback/timers. Restart and menu teardown clear run-owned sound state.
- Sound effects volume persists with the other settings, defaults to 70%, and mutes at zero. The generator and voice gains leave headroom; the native preview recording has a 0.207 peak and 0.025 RMS at the default volume.
- Reusable muzzle and hit sparks make actual shots and impacts visible. Their 24-instance cap is separate from the existing 32-pulse cap. Reduced motion retains static indicators without extra movement or camera shake.

The eleven WAVs are original procedural cues generated with checked-in Python; no external samples or paid generation service are involved. The older MP3 references remain untouched. This is a first sound pass; subjective balance still needs listening and playtesting. Follow the [audio workflow](../.claude/skills/game-audio/SKILL.md) to rebuild or capture cues.

## Performance

Shared immutable ring meshes/materials replace one resource pair per marker, allowing renderer batching. Crowd separation checks squared distance before computing a square root. Gameplay rules and RNG consumption are unchanged.

The development target is a 16.7 ms p95 frame budget at 1280×720. The existing stress scene uses 150 durable enemies, ten mixed turrets, an invulnerable player, Forward+, VSync off, 120 warm-up frames and 600 sampled wall-clock frame intervals on the local RTX 4090.

| Sample | Median frame | p95 frame | Draw calls at capture |
|---|---:|---:|---:|
| Fresh pre-change baseline | 16.948 ms | 32.471 ms | 567 |
| First updated sample | 13.494 ms | 19.098 ms | 411 |
| Updated repeat | 16.331 ms | 29.170 ms | 378 |

Both updated runs retained 150 enemies, ten turrets, eight projectile instances and 24 allocated sparks; peak concurrent audio voices were five and six. The first updated sample may overlap a short test/import process near its end; the repeat ran without another deliberate test/render workload. Draw calls include transient warnings/effects, so capture counts differ. The samples show reduced rendering work but substantial timing variability, not a reliable percentage speedup or a stable 60 fps result.

**Phase 0 performance pass (2026-10-04, GPU idle, same stress scene).** Before: 18.8 ms median / 34 ms p95 (physics 15 ms median). After: about 11.5 ms median / 18 ms p95 (physics about 11.3 ms, GPU 1.6 ms, render CPU 2 ms). Changes: `CrowdGrid3D.separation` reads packed per-cell coordinates instead of dictionary lookups per neighbour, enemies make one transform write per tick and skip the segment contact test when the player is out of reach, enemies drop the unused body collision shape, status effects only advance when present, and turrets cache their modifier-built stats (rebuilt on `modifiers_changed` or every 0.25 s). **The p95 budget (16.7 ms) is still narrowly missed (about 18 ms).** Remaining cost is about 5 ms of enemy script plus about 5 ms of engine-side physics and transform sync for 150 hurtboxes. Use `res://tools/bench_physics.tscn` (ablation) and `res://tools/bench_split.tscn` (per-subsystem script cost) headless to continue. Do not reduce gameplay enemy counts to hide this workload.

## Validation

- Full import/GUT gate: 790 tests and 3,181 assertions, no risky tests, unexpected errors or remaining orphan nodes.
- Six new feedback tests cover bounded/reserved voices, throttling, pause/resume, restart, actual hit/warning/end notifications, reduced-motion effect lifetime/reuse, shared marker independence and gameplay-RNG independence. Preference tests now cover volume persistence, mute, clamping and malformed values.
- Native app captures confirm settings and existing start/pause/end/menu layouts at 1280×720. Native SFX-bus recording produces 9.28 seconds of nonzero, unclipped stereo audio. Amplitude checks do not establish subjective sound quality.
- Both seeded six-wave progression routes reach victory with unchanged outcomes: ion has 392 kills, control has 391, and both retain 25 hull. Audio and visuals do not consume the gameplay RNG stream. The smoke runner now frees its arena and lets the mixer drain queued stop commands before exiting; CI also rejects ObjectDB leak warnings.

Launch with `./launch.ps1`. For playtesting, compare the three weapons, listen for charger windup amid dense combat, test low/muted volume, pause during firing, and restart/return to menu. Review loudness and warning audibility before treating these synthesized cues as final assets.

## Hit flash and death dissolve

A hit no longer blinks the model. `HitFlash` (`scripts/game/hit_flash.gd`) attaches an additive fresnel-weighted `ShaderMaterial` overlay (`assets/shaders/hit_flash.gdshader`) to every mesh for `CombatActor.FLASH_DURATION` and removes it afterwards, so idle actors draw nothing extra. Enemies flash warm white and the player flashes red; reduced motion keeps the cue at 40% strength with no strobing. A kill frees the actor at once, as before, but `DeathDissolve` (`scripts/game/death_dissolve.gd`) takes over its `Visual` node for 0.45 s and swaps each surface for a `dissolve.gdshader` copy of its `StandardMaterial3D` (albedo, panel texture, vertex-colour AO, metal/rough, emission). The shader erodes the model with world-space noise biased top-down and rides a bloomed ember edge along the cut. At most 40 corpses run at once; beyond that the effect is skipped. Both run on the shared `Environment` glow, so the edge and flash bloom. Enemies with a baked shard set (currently the Drowse Beetle) shatter instead; see [Death shatter](#death-shatter).

## Death shatter

The Drowse Beetle breaks into flying shell fragments instead of dissolving. `ArenaWorld._on_enemy_died` asks `DeathShatter.spawn` first and falls back to `DeathDissolve` when the enemy has no baked shards, Reduced Motion is on, or 16 shatters are already running.

**How it works.** The motion is not simulated. `tools/bake_shatter.gd` pre-fractures the model once, offline (`ShatterBaker`, about half a second): all triangles are clustered into crack cells with area-weighted k-means whose assignment is wobbled by noise, so the cracks are ragged. A shard is one cell inside one mesh object, so animated parts such as the feet shatter from the pose they died in. Every vertex of the baked mesh carries its shard's pivot and id (`CUSTOM0`) and radius (`UV2`). The baked file is `assets/models/clockwork/shatter/cp_<model key>.res` (590 KB for the beetle, 82 shards, the same 30,072 triangles).

On a kill, `DeathShatter` takes over the actor's `Visual` as the dissolve does and swaps each `MeshInstance3D` to its baked mesh. `shatter.gdshader` (`world_vertex_coords`) then solves every shard in closed form from the time since death: a hashed launch away from the body centre, higher for pieces from the top of the shell, a spin about a hashed axis, one floor bounce, a slide to rest, then a shrink to nothing at 1.3 s. A white flash and a short ember tint fade over the first moments. The corpse's `_process` writes one instance uniform per mesh per frame. There are no extra nodes, physics bodies, tweens or per-kill material copies, because the shared `ShaderMaterial` copies of the model's materials are bound to the baked meshes once (`DeathShatter.warm_up`, run at the start of a run, also loads every baked set so the first kill does not stall). The enemy's last velocity (including knockback) is added to the launch so a hit visibly pushes the pieces. Elite or other tinted variants carry their tint into the shards.

**Cost** (`tools/bench_shatter.tscn`, RTX 4090, 100 bystander beetles, 16 killed at once, turrets off): about 0.4 ms of script per kill, the same as the dissolve; peak draw calls 475 against 1,705 for the dissolve (which gives every corpse its own materials), and a median frame of about 6.2 to 7.3 ms against 7.2 to 7.5 ms. Shards are as many triangles as the living model, drawn for 1.3 s.

**Adding another enemy.** The effect is keyed by the clockwork model key and picked up automatically; no code changes are needed.

1. `godot --headless --path . -s tools/bake_shatter.gd -- hopper` (add `--cells=N` for more or fewer, larger or smaller pieces, `--seed=N` for a different crack pattern; the beetle uses 16 cells).
2. `godot --path . res://tools/capture_shatter.tscn -- --enemy=hopper` renders ten frames of the flight and a contact sheet to `.test-results/`. Tune the launch speeds, gravity, drag and bounce in `shatter.gdshader`, and `DURATION` in `death_shatter.gd` (keep it equal to `life` in the shader).
3. Commit the new `.res`. If the model's meshes change, rebake: `test_shatter_baker` fails when the committed bake no longer matches the model's mesh paths and triangle counts.

Models whose parts are articulated in separate mesh objects (like the beetle's feet) read best. A single-mesh model still works, but its pieces are only as big as the cells that fall inside it. Models that use `ShaderMaterial`s rather than `StandardMaterial3D` fall back to a plain material.

## Projectile glow, impact sparks and scrap drops

Shots are a white-hot core inside a camera-facing halo (`energy_orb.gdshader`) with a tapering streak behind them (`energy_trail.gdshader`). Ion bolts are cyan and plasma is violet, larger when it splashes. The streak hangs off a pivot node that turns with the heading; the projectile itself must stay unrotated because its `ShapeCast3D` sweep target is local. `EnergyFx` shares one material per look. Hits and pickups fire pooled one-shot `GPUParticles3D` bursts from `CombatEffects3D.show_burst` (16 emitters, oldest recycled), coloured by damage type, red for damage to the player and amber for scrap. The additive shaders use `fog_disabled`, since scene fog would otherwise be added on top of them as a visible rectangle.

Electric chains and Shocked enemies. show_arc(from, to, hop) draws each chain jump as camera-facing ribbon strips (lightning_bolt.gdshader): a midpoint-displaced main bolt plus two or three fading forks, rebuilt from a private RandomNumberGenerator every ARC_REROLL_INTERVAL so it crackles without touching the combat random stream. The shader layers a white-hot core, a cyan glow and a violet halo, with a short overbright flash on the strike and a few flicker dropouts as it decays. Combat3D.chain_arc now carries the hop number; each hop lights ARC_HOP_DELAY after the one before so the chain visibly travels (damage is still applied instantly). A strike also fires the shock burst, a spark flash and one of four pooled OmniLight3D flashes. Enemies hit by electricity, or still slowed by it, get a camera-facing crackle shell (shocked_actor.gdshader) from a pooled quad, up to MAX_SHOCK_VISUALS. Reduced motion drops the strike flash, dropouts, re-rolling and crackle animation, and dims the light flash. 	ools/preview_combat_feedback.tscn captures a strike and a decay frame of a three-hop chain into .test-results/.

Scrap is the `scrap_shard` model (a faceted amber crystal with salvaged plates, centred on its own origin) over a pulsing light pool. It pops in on spawn, scales with its value, spins faster and pulls harder the longer the magnet holds it, and bursts into sparks when collected. Reduced motion keeps it static.
