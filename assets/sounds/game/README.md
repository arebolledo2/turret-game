# Procedural game cues

These eleven original mono WAV cues are synthesized by `tools/build_game_audio.py` using Python's standard library. They use no external samples, services or model weights. Rebuild with `python tools/build_game_audio.py` and keep the generated WAVs and Godot import sidecars together.

24 kHz PCM16; durations 0.07–0.75 seconds; short attack/release envelopes prevent hard boundary clicks. Seeded noise makes rebuilds deterministic.

`GameAudio` applies cue throttling, spatial attenuation and bounded polyphony. The SFX bus defaults to 70%; zero mutes. These are a first gameplay sound pass, intended for listening/playtest feedback rather than final sound design. See the [audio workflow](../../../.claude/skills/game-audio/SKILL.md).
