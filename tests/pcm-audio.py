"""Verify that the 0.43 emulator emits the PCM samples and mixes the PSG."""

import argparse
import array
import math
import os
from pathlib import Path
import subprocess
import sys
import wave

ROOT = Path(__file__).resolve().parent.parent


def capture(name, rom, save_dir):
    script = ROOT / "experiments" / f"capture-{name}.script"
    subprocess.run(
        [os.environ["RP6502_EMU"], "--save-dir", save_dir, "--script", str(script), rom],
        check=True,
    )
    with wave.open(f"{name}.wav", "rb") as wav:
        assert wav.getsampwidth() == 2 and wav.getnchannels() == 2
        rate = wav.getframerate()
        samples = array.array("h", wav.readframes(wav.getnframes()))
    if sys.byteorder != "little":
        samples.byteswap()
    return rate, samples[::2]


def rms(samples):
    return math.sqrt(sum(x * x for x in samples) / len(samples))


def window(samples, rate, start, end):
    return samples[int(rate * start) : int(rate * end)]


def tone_amplitude(samples, rate, frequency):
    real = sum(x * math.cos(2 * math.pi * frequency * i / rate)
               for i, x in enumerate(samples))
    imag = sum(x * math.sin(2 * math.pi * frequency * i / rate)
               for i, x in enumerate(samples))
    return 2 * math.hypot(real, imag) / len(samples)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--save-dir", required=True)
    parser.add_argument("rom")
    args = parser.parse_args()

    for name, minimum, maximum in (
        ("pcm-shot", 0.11, 0.18),
        ("pcm-explosion", 0.65, 0.90),
    ):
        rate, samples = capture(name, args.rom, args.save_dir)
        assert 1000 < max(map(abs, samples)) < 32767, name
        step = rate // 200
        active = [i / rate for i in range(0, len(samples) - step + 1, step)
                  if rms(samples[i : i + step]) > 100]
        assert active and minimum < active[-1] - active[0] < maximum, name
        assert all(rms(window(samples, rate, t, t + 0.01)) > 20
                   for t in (0.05, 0.10)), name

    rate, tone = capture("psg-tone", args.rom, args.save_dir)
    mix_rate, mixed = capture("pcm-mix", args.rom, args.save_dir)
    assert rate == mix_rate
    assert max(map(abs, mixed)) < 32767
    tone_start = window(tone, rate, 0.05, 0.20)
    mix_start = window(mixed, rate, 0.05, 0.20)
    assert rms(mix_start) > rms(tone_start) * 1.05
    assert tone_amplitude(mix_start, rate, 450) > tone_amplitude(tone_start, rate, 450) * 0.8
    assert abs(rms(window(mixed, rate, 1.0, 1.3)) -
               rms(window(tone, rate, 1.0, 1.3))) < 5


if __name__ == "__main__":
    main()
