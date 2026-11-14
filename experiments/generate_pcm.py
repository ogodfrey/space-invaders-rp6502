"""Generate original, approximate PCM effects for the RP6502 sound experiment."""

import math
import random
import struct
import sys
from pathlib import Path

RATE = 8000


def shot():
    rng = random.Random(6502)
    samples = bytearray()
    phase = 0.0
    noise = 0.0
    length = int(RATE * 0.16)
    for i in range(length):
        t = i / RATE
        phase += 2 * math.pi * (1100 - 750 * i / length) / RATE
        noise += 0.3 * (rng.uniform(-1, 1) - noise)
        envelope = min(1.0, t / 0.004) * (1 - i / length) ** 1.5
        value = (0.65 * math.sin(phase) + 0.35 * noise) * envelope
        samples.extend(struct.pack("<h", round(3600 * value)))
    return samples


def explosion():
    rng = random.Random(8080)
    samples = bytearray()
    low = 0.0
    length = int(RATE * 0.85)
    for i in range(length):
        t = i / RATE
        low += 0.16 * (rng.uniform(-1, 1) - low)
        envelope = min(1.0, t / 0.006) * (1 - i / length) ** 1.3
        value = (0.8 * low + 0.2 * rng.uniform(-1, 1)) * envelope
        samples.extend(struct.pack("<h", round(6200 * value)))
    return samples


if __name__ == "__main__":
    game = len(sys.argv) == 4 and sys.argv[1] == "--game"
    paths = sys.argv[2:] if game else sys.argv[1:]
    if len(paths) != 2:
        raise SystemExit("usage: generate_pcm.py [--game] SHOT.raw EXPLOSION.raw")
    for path, data in zip(paths, (shot(), explosion())):
        if game:
            samples = [round(sample / 128)
                       for (sample,) in struct.iter_unpack("<h", data)]
            if max(map(abs, samples)) > 63:
                raise ValueError(f"{path}: sample exceeds mixer headroom")
            data = bytes(sample & 0xFF for sample in samples)
        Path(path).write_bytes(data)
