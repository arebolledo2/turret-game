---
name: game-audio
description: Rebuild and validate the native 3D game's procedural sound cues and bounded SFX mixer.
---

# Native game audio

1. Inspect `scripts/game/game_audio.gd` and `tools/build_game_audio.py` before editing cues. The generator uses only the Python standard library and seeded noise; checked-in WAVs have no external sample dependency.
2. Run `python tools/build_game_audio.py` after generator edits. Keep cue attacks/releases, mono PCM16 format and source peak limits. The mixer caps general and critical voices separately; account for worst-case summed gain when changing levels.
3. Keep the SFX bus and `SettingsService` volume persistence intact. Audio must not consume gameplay RNG. Warnings/player/end cues use reserved voices; dense combat must not allocate unbounded players.
4. Run `./run_tests.ps1 -Import`. Coverage includes voice saturation, throttling, pause/resume, restart, mute/persistence, signal routing and gameplay-RNG independence. AudioStreamPlayer3D begins playback on a physics boundary, so tests of active playback must await that boundary.
5. Run Godot with a native driver on `res://tools/capture_audio.tscn` for an SFX-bus recording at `.test-results/audio-preview.wav`. This records game output, not microphone input. Inspect stdout/stderr and confirm nonzero, unclipped output; listen to the file and playtest for subjective balance. Do not claim amplitude checks establish sound quality.
6. Run `res://tools/capture_game.tscn -- --stress` at 1280×720 with the native driver, without concurrent test/render workloads. Record wall-clock median/p95, draw calls, physics/process monitors and peak voice count. Keep frame-budget misses visible; one development-machine sample is not a minimum-spec guarantee.

The capture tools temporarily adjust runtime preferences without saving them. Captures and logs remain ignored under `.test-results/`.
