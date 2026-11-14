"""Exercise the actual game mixer and verify overlapping output."""

import argparse
import array
import math
import os
import subprocess
import sys
import wave


def capture(name, voices, rom, save_dir, psg=False):
    commands = [
        "run 30",
        "press space",
        "run 1",
        "release space",
        "run 2",
        "poke alien_timer 0",
    ]
    for voice in voices:
        commands.extend((
            f"poke {voice}_ptr ({voice}_data&255) ({voice}_data>>8)",
            f"poke {voice}_active 1",
        ))
    if psg:
        commands.extend((
            "poke xbus:(XRAM_PSG+16) 38 1",
            "poke xbus:(XRAM_PSG+24) 70 5",
            "poke xbus:(XRAM_PSG+32) 148 17",
            "poke xbus:(XRAM_PSG+40) 8 7",
            "poke xbus:(XRAM_PSG+48) 52 8",
            "poke xbus:(XRAM_PSG+22) 1",
            "poke xbus:(XRAM_PSG+30) 1",
            "poke xbus:(XRAM_PSG+38) 1",
            "poke xbus:(XRAM_PSG+46) 1",
            "poke xbus:(XRAM_PSG+54) 1",
        ))
    commands.append(f'wav "{name}.wav" 60')
    subprocess.run(
        [os.environ["RP6502_EMU"], "--memfill", "0", "--save-dir", save_dir,
         "--script", "-", rom],
        input="\n".join(commands) + "\n", text=True, check=True,
    )
    with wave.open(f"{name}.wav", "rb") as wav:
        assert wav.getsampwidth() == 2 and wav.getnchannels() == 2
        rate = wav.getframerate()
        samples = array.array("h", wav.readframes(wav.getnframes()))
    if sys.byteorder != "little":
        samples.byteswap()
    assert samples[::2] == samples[1::2], f"{name}: not centered"
    return rate, samples[::2]


def correlation(a, b, start, end):
    a = a[start:end]
    aa = sum(x * x for x in a)
    best = 0
    for offset in range(-200, 201, 2):
        shifted = b[start + offset : end + offset]
        bb = sum(x * x for x in shifted)
        if bb:
            best = max(best, sum(x * y for x, y in zip(a, shifted)) /
                       math.sqrt(aa * bb))
    return best


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--save-dir", required=True)
    parser.add_argument("rom")
    args = parser.parse_args()

    rate, shot = capture("shot", ("shot",), args.rom, args.save_dir)
    rate2, explosion = capture("explosion", ("explosion",), args.rom, args.save_dir)
    rate3, both = capture("both", ("shot", "explosion"), args.rom, args.save_dir)
    rate4, full = capture("full-mix", ("shot", "explosion"), args.rom,
                          args.save_dir, psg=True)
    assert rate == rate2 == rate3 == rate4
    assert max(map(abs, shot)) > 2000
    assert max(map(abs, explosion)) > 2000
    for start in range(int(rate * 0.03), int(rate * 0.60), rate // 100):
        block = explosion[start : start + rate // 100]
        assert math.sqrt(sum(x * x for x in block) / len(block)) > 100, \
            f"explosion gap at {start / rate:.3f}s"
    assert max(map(abs, full)) < 30000, "insufficient headroom"
    assert max(map(abs, full)) > max(map(abs, both)) * 1.2, "PSG not mixed"
    assert correlation(shot, both, int(rate * 0.04), int(rate * 0.12)) > 0.55
    assert correlation(explosion, both, int(rate * 0.20), int(rate * 0.60)) > 0.95


if __name__ == "__main__":
    main()
