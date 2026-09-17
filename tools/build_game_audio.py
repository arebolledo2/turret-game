"""Rebuild original procedural game cues; Python standard library only."""
from pathlib import Path
import math
import random
import struct
import wave

OUT = Path(__file__).resolve().parents[1] / "assets/sounds/game"
# duration, start/end pitch, noise mix. Mono 24 kHz, bounded attack/release.
CUES = {
    "ion": (.10, 1050, 280, .12),
    "plasma": (.24, 280, 65, .25),
    "shock": (.26, 150, 680, .32),
    "impact": (.07, 420, 180, .55),
    "hull": (.30, 180, 55, .30),
    "warning": (.32, 760, 1050, .0),
    "pickup": (.09, 1100, 1600, .0),
    "purchase": (.20, 520, 1040, .0),
    "wave": (.38, 440, 880, .0),
    "victory": (.75, 520, 1300, .0),
    "defeat": (.65, 330, 80, .08),
}

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (duration, start, end, noise) in CUES.items():
        rng = random.Random(name)
        samples = []
        phase = 0.0
        count = round(duration * 24000)
        for index in range(count):
            t = index / 24000
            progress = index / max(1, count - 1)
            phase += 2 * math.pi * (start + (end - start) * progress) / 24000
            envelope = min(1, t / .008) * (1 - progress) ** 1.7
            tone = math.sin(phase) * .8 + math.sin(phase * 2) * .2
            value = .48 * envelope * (tone * (1 - noise) + rng.uniform(-1, 1) * noise)
            samples.append(round(value * 32767))
        with wave.open(str(OUT / (name + ".wav")), "wb") as output:
            output.setparams((1, 2, 24000, len(samples), "NONE", "not compressed"))
            output.writeframes(struct.pack("<" + "h" * len(samples), *samples))
        print(f"{name}: {duration:.2f}s, peak {max(abs(v) for v in samples)/32767:.3f}")

if __name__ == "__main__":
    main()
