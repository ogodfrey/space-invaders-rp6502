# Space Invaders for the RP6502

A staged port of Space Invaders to the Picocomputer 6502 (RP6502), written in
cc65 assembly. The Apple II version lives in [apple2/](apple2/) for reference
and is not part of the RP6502 build.

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
* PSG sound: shot, explosion, saucer, bomb launch, and the marching bassline.
* Title, play, wave-clear, and game-over states, a session high score, and
  an attract demo where an autopilot plays after the high-score screen.

Move with A/D or the arrow keys and fire with Space. Space during the
attract demo starts a real game. The score line is VGA console text on a
plane above the bitmap. The high score lasts only for the session.

Known gaps against the arcade: the attract demo is a sweep-and-fire
autopilot, not a full copy of the arcade demo, and the high score is not
saved between runs.

## Build

    make build

The ROM is `build/cc65/debug/space-invaders/space-invaders.rp6502`.

## Upload to an RP6502-PICO

    make upload DEVICE=/dev/ttyACM0

## Requirements

* CMake 3.21 or newer
* Python 3
* Make or Ninja
* [cc65](https://github.com/picocomputer?view_as=public)

## Test

    ctest --test-dir build/cc65/debug --output-on-failure
