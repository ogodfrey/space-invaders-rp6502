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
sprites copied into it. It has an animated, marching alien, a player ship,
and a single player bullet. Move with A/D or the arrow keys and fire with
Space. Hits increase the score; the alien respawns after a short pause. The
score line is VGA console text on a plane above the bitmap. Sound, alien
formations, and the remaining Apple II milestones are planned follow-up work.

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
