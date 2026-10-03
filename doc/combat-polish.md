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

**The p95 budget is not yet met.** Physics monitor p95 was 17.907–19.658 ms; the capture tool now reports process/physics monitors and voice counts to help the next profiling pass. Investigate dense crowd/actor CPU work under a longer, controlled benchmark before claiming a minimum hardware target. Do not reduce gameplay enemy counts to hide this workload.

## Validation

- Full import/GUT gate: 790 tests and 3,181 assertions, no risky tests, unexpected errors or remaining orphan nodes.
- Six new feedback tests cover bounded/reserved voices, throttling, pause/resume, restart, actual hit/warning/end notifications, reduced-motion effect lifetime/reuse, shared marker independence and gameplay-RNG independence. Preference tests now cover volume persistence, mute, clamping and malformed values.
- Native app captures confirm settings and existing start/pause/end/menu layouts at 1280×720. Native SFX-bus recording produces 9.28 seconds of nonzero, unclipped stereo audio. Amplitude checks do not establish subjective sound quality.
- Both seeded six-wave progression routes reach victory with unchanged outcomes: ion has 392 kills, control has 391, and both retain 25 hull. Audio and visuals do not consume the gameplay RNG stream. The smoke runner now frees its arena and lets the mixer drain queued stop commands before exiting; CI also rejects ObjectDB leak warnings.

Launch with `./launch.ps1`. For playtesting, compare the three weapons, listen for charger windup amid dense combat, test low/muted volume, pause during firing, and restart/return to menu. Review loudness and warning audibility before treating these synthesized cues as final assets.

## Hit flash and death dissolve

A hit no longer blinks the model. `HitFlash` (`scripts/game/hit_flash.gd`) attaches an additive fresnel-weighted `ShaderMaterial` overlay (`assets/shaders/hit_flash.gdshader`) to every mesh for `CombatActor.FLASH_DURATION` and removes it afterwards, so idle actors draw nothing extra. Enemies flash warm white and the player flashes red; reduced motion keeps the cue at 40% strength with no strobing. A kill frees the actor at once, as before, but `DeathDissolve` (`scripts/game/death_dissolve.gd`) takes over its `Visual` node for 0.45 s and swaps each surface for a `dissolve.gdshader` copy of its `StandardMaterial3D` (albedo, panel texture, vertex-colour AO, metal/rough, emission). The shader erodes the model with world-space noise biased top-down and rides a bloomed ember edge along the cut. At most 40 corpses run at once; beyond that the effect is skipped. Both run on the shared `Environment` glow, so the edge and flash bloom.

## Projectile glow, impact sparks and scrap drops

Shots are a white-hot core inside a camera-facing halo (`energy_orb.gdshader`) with a tapering streak behind them (`energy_trail.gdshader`). Ion bolts are cyan and plasma is violet, larger when it splashes. The streak hangs off a pivot node that turns with the heading; the projectile itself must stay unrotated because its `ShapeCast3D` sweep target is local. `EnergyFx` shares one material per look. Hits and pickups fire pooled one-shot `GPUParticles3D` bursts from `CombatEffects3D.show_burst` (16 emitters, oldest recycled), coloured by damage type, red for damage to the player and amber for scrap. The additive shaders use `fog_disabled`, since scene fog would otherwise be added on top of them as a visible rectangle.

Scrap is the `scrap_shard` model (a faceted amber crystal with salvaged plates, centred on its own origin) over a pulsing light pool. It pops in on spawn, scales with its value, spins faster and pulls harder the longer the magnet holds it, and bursts into sparks when collected. Reduced motion keeps it static.
