# Space Invaders for the RP6502

A Space Invaders game for the Picocomputer 6502, written in cc65 assembly.
The Apple II version this is ported from lives in [apple2/](apple2/) for reference.

## Layout

* `src/main-cc65.s`: the program's entry point (cc65 assembly).
* `CMakeLists.txt`: the ROM this project builds, `space-invaders.rp6502`.
* `tools/`: the build and upload tools. Commit them with the project.
* `apple2/`: the original Apple II source, not built.

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
