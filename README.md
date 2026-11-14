# Space Invaders for the RP6502

A staged port of Space Invaders to the Picocomputer 6502 (RP6502), written in
cc65 assembly. The Apple II version lives in [apple2/](apple2/) for reference
and is not part of the RP6502 build.

The RP6502 was created by Rumbledethumps. Learn about the Picocomputer and its
SDK at [picocomputer.github.io](https://picocomputer.github.io/).

## Layout

* `src/main-cc65.s`: the game, in cc65 assembly.
* `src/xram.inc`: the XRAM layout, the keyboard and Mode 3 bitmap definitions,
  and the sprite data offsets.
* `CMakeLists.txt`: the ROM this project builds, `space-invaders.rp6502`.
* `tools/`: the build and upload tools. Commit them with the project.
* `apple2/`: the original Apple II source, not built.

## Current game

The game draws on a 320x240 bitmap (VGA mode 3, 4 bits per pixel) with
sprites copied into it. The layout follows the arcade's 224-pixel field,
with the vertical positions scaled from 256 lines to 240.

* An 11 by 5 grid of marching aliens, with the arcade's three alien types,
  row scores (30, 20, 10), and waves that speed up.
* A player ship with three lives, a player bullet, and an extra ship at 1500
  points.
* Alien bombs (up to three), some aimed at the ship's column, and four
  destructible bunkers.
* A bonus saucer that crosses the top of the screen.
* Explosion bursts for hits and for the ship's destruction.
* PSG sound: fleet-synchronized thumps, shot, saucer, separate alien,
  saucer and ship hit effects, and the bonus-ship sound.
* Title, play, wave-clear, and game-over states, a session high score, and
  an attract demo where an autopilot plays after the high-score screen.

Move with A/D, the arrow keys, or the first gamepad's d-pad or left stick;
fire with Space or the gamepad's A button. Space, A, or Start starts a game
from the title screen or takes over the attract demo. The score line is VGA
console text on a plane above the bitmap. The high score lasts only for the
session.

Gameplay keeps the HUD free of control instructions. The attract screens
center the title, start prompt, alien point values, and session high score.

Known gaps against the arcade: the attract demo is a sweep-and-fire
autopilot, not a full copy of the arcade demo, and the high score is not
saved between runs. Sound effects are PSG approximations rather than a
simulation of the arcade's analog circuits. The game itself does not use PCM.

## PCM sound experiment

The optional prototype auditions original, synthesized shot and ship
explosion samples. It requires RP6502 0.43 or newer; the normal game remains
compatible with 0.42. This is not a circuit simulation or a recording of an
arcade machine, and no arcade listening comparison has been made.

From the project root, configure and build it separately:

    cmake --preset cc65/Debug -B build/cc65/pcm -DBUILD_PCM_PROTOTYPE=ON
    cmake --build build/cc65/pcm
    ctest --test-dir build/cc65/pcm -R "^pcm-prototype$" --output-on-failure

Run `build/cc65/pcm/pcm-prototype/pcm-prototype.rp6502` on a 0.43 machine
or emulator. Press 1 for the shot, 2 for the explosion, 3 to toggle a PSG
tone while auditioning PCM, and Q to exit. The samples are generated at
build time as 8 kHz, signed 16-bit mono. Playback retries short and
zero-length FIFO writes and waits for each effect to finish; it deliberately
does not mix or interrupt simultaneous PCM effects. That blocking approach
is for auditioning only, not a game-loop implementation.

To capture the real emulator output for comparison, run the 0.43 emulator
from the project root (replace `rp6502-emu` with its path if needed):

    rp6502-emu --script experiments/capture-pcm-shot.script build/cc65/pcm/pcm-prototype/pcm-prototype.rp6502
    rp6502-emu --script experiments/capture-pcm-explosion.script build/cc65/pcm/pcm-prototype/pcm-prototype.rp6502
    rp6502-emu --script experiments/capture-psg-shot.script build/cc65/pcm/space-invaders/space-invaders.rp6502
    rp6502-emu --script experiments/capture-psg-explosion.script build/cc65/pcm/space-invaders/space-invaders.rp6502
    rp6502-emu --script experiments/capture-pcm-mix.script build/cc65/pcm/pcm-prototype/pcm-prototype.rp6502

The scripts write WAVs in the current directory. The captures are not
loudness-normalized; adjust playback levels when comparing them. The PSG
captures come from the game, and the mix capture combines the experimental
explosion with the prototype's continuous PSG tone.

## Build

    make build

The ROM is `build/cc65/debug/space-invaders/space-invaders.rp6502`. The same
build also writes a web page that runs the ROM in the emulator:
`build/cc65/debug/web/space-invaders.zip`, unpacked in
`build/cc65/debug/web/space-invaders/`. The GitHub workflow in
[.github/workflows/web.yml](.github/workflows/web.yml) publishes the web build.

<!-- rp6502
preset: cc65/Release
publish: space-invaders.zip
-->

## Upload to an RP6502-PICO

    make upload DEVICE=/dev/ttyACM0

## Requirements

* CMake 3.21 or newer
* Python 3
* Make or Ninja
* [cc65](https://github.com/picocomputer?view_as=public)

## Test

    ctest --test-dir build/cc65/debug --output-on-failure
