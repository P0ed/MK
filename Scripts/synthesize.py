#!/usr/bin/env python3
"""Generate the complete sound bank; no dependencies or sampled recordings."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22_050
DESTINATION = Path(__file__).resolve().parents[1] / "MK" / "Sounds"
DURATIONS = dict(menu=.06, swing=.10, punch=.14, kick=.18, block=.12,
                 spear=.22, ice=.28, rang=.22, rocket=.35, explode=.38,
                 teleport=.25, round=.45)


def synthesize(name, duration, seed):
    rng = random.Random(seed)
    phase = 0.0
    filtered = 0.0
    samples = bytearray()
    for index in range(int(RATE * duration)):
        t = index / RATE
        progress = t / duration
        noise = rng.uniform(-1, 1)
        filtered = .7 * filtered + .3 * noise
        frequency = {"menu": 520 - 280 * progress, "punch": 140 - 95 * progress,
                     "kick": 100 - 65 * progress, "block": 520 - 100 * progress,
                     "spear": 900 - 600 * progress, "ice": 1200 + 1400 * progress,
                     "rang": 500 + 100 * math.sin(t * 70), "rocket": 85 + 110 * progress,
                     "explode": 65 - 35 * progress, "teleport": 1000 * (1 - progress) + 90,
                     "round": (220, 277.18, 329.63, 440)[min(3, int(progress * 4))]}.get(name, 100)
        phase += 2 * math.pi * frequency / RATE
        sine = math.sin(phase)
        square = 1 if sine >= 0 else -1
        if name in ("menu", "round"):
            value = .8 * sine + .12 * square
        elif name == "swing":
            value = filtered * 2
        elif name in ("punch", "kick", "explode"):
            value = .5 * sine + .6 * filtered + .15 * noise
        elif name == "rocket":
            value = .65 * filtered + .25 * square
        elif name == "ice":
            value = .5 * sine + .3 * noise
        else:
            value = .45 * square + .35 * filtered
        envelope = min(1, t / .003) * min(1, (duration - t) / .012)
        envelope *= math.exp(-progress * (2 if name == "round" else 4))
        value = round(value * 32) / 32  # Deliberately coarse waveform.
        samples += struct.pack("<h", round(max(-1, min(1, value * envelope * .65)) * 32767))
    return samples


def main():
    DESTINATION.mkdir(parents=True, exist_ok=True)
    for seed, (name, duration) in enumerate(DURATIONS.items()):
        with wave.open(str(DESTINATION / f"{name}.wav"), "wb") as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(RATE)
            output.writeframes(synthesize(name, duration, seed))
    print(f"Generated {len(DURATIONS)} WAV effects in {DESTINATION}")


if __name__ == "__main__":
    main()
