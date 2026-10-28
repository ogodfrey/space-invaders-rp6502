# Space Invaders for the RP6502: project notes

Handoff notes from the planning session. They summarize the RP6502 docs at
https://picocomputer.github.io/ that matter for porting the game. Check the
docs before you rely on any detail here.

## Project state

* Template cleaned up to cc65 assembly only. One ROM: `space-invaders`.
* `src/main-cc65.s` is the entry point. It prints "Hello, world!" and
  includes `rp6502.inc` and `xram.inc`. Replace it with the game.
* `src/xram.inc` maps the keyboard to XRAM. It has `XRAM_KEYBOARD`,
  `KEYBOARD_PRESSED`, `xreg_ria_keyboard`, and the HID codes for A, D,
  Space, and the arrows.
* `apple2/` holds the original Apple II source, for reference only. Its
  `plan.md` and `state.md` record the milestones. M0 to M6 are done. The
  Apple II hi-res graphics and keyboard code must be rewritten, not copied.

## Build and run

* Configure preset: `cc65/Debug`. Build: `make build`. Output:
  `build/cc65/debug/space-invaders/space-invaders.rp6502`.
* Upload to a board: `make upload DEVICE=/dev/ttyACM0`. The device path is
  set in `Makefile`.
* Headless run and screenshot, for checking the ROM without a window:
  `build/cc65/debug/space-invaders/rp6502-emu <rom> --screenshot out.png`.
* Breakpoint debugging in VS Code (RP6502-EMU) does not work on this Pi.
  The emulator's `--dap` mode aborts when its input closes, on 0.41 and 0.42.
  Use `printf`-style output on the board, or the emulator's `--debug` panel.
* The RP6502-PICO launch config in VS Code runs the ROM on the board, but has
  no breakpoints. It needs the `.rp6502` settings file at the project root,
  which is git-ignored and created on the first run of that launch config.
  Do not confuse it with the ROMs, which also end in `.rp6502`.
* llvm-mos cannot install on this aarch64 Pi. Use cc65.

## Assembly conventions (cc65)

* Include `rp6502.inc` for the RIA register names, such as `RIA_READY`,
  `RIA_TX`, `RIA_ADDR0`, and `RIA_RW0`.
* Include `xram.inc` for the XRAM layout. Keep every XRAM address in
  `xram_layout_t`, so the build can check it. Use the `XRAM_` symbols.
* XRAM symbols must be even-aligned. `rp6502_align(... "XRAM_.*")` checks
  every symbol that starts with `XRAM_`. So the include guard must not start
  with `XRAM_`. The project uses `__XRAM_INC`. Hitting this rule is what
  caused the first build failure.
* cc65 ignores `volatile`. Wrap code that touches RIA or VIA registers in
  `#pragma optimize` in C. In assembly this does not apply.
* Mode configs, palettes, and the PSG need even addresses. The PSG's 64 bytes
  must not cross a 256-byte page, and OPL2 registers must start on a page.
* RAM is $0000-$FEFF, 63.75 KB, with no reserved zero page. XRAM is 64 KB.
  The VIA is at $FFD0-$FFDF and the RIA at $FFE0-$FFFF.

## RIA registers ($FFE0-$FFFF)

* `RIA_READY` ($FFE0): bit 7 is TX ready, bit 6 is RX has data.
* `RIA_TX` ($FFE1) and `RIA_RX` ($FFE2): UART. The stdio functions use these.
  Do not touch them while a stdio call runs.
* `RIA_VSYNC` ($FFE3): increments every 1/60 s while the VGA is connected.
* Portal 0: `RIA_RW0` ($FFE4), `RIA_STEP0` ($FFE5), `RIA_ADDR0` ($FFE6-7).
* Portal 1: `RIA_RW1` ($FFE8), `RIA_STEP1` ($FFE9), `RIA_ADDR1` ($FFEA-B).
  A load or store on RW reads or writes the XRAM byte at ADDR, then ADDR
  moves by the signed STEP. The docs say portals are safe in interrupt
  handlers, but I did not read that section in full.
* `RIA_XSTACK` ($FFEC): push or pull the 512-byte extended stack.
* `RIA_ERRNO` ($FFED-EE), `RIA_OP` ($FFEF): writing an operation starts an
  API call.
* `RIA_IRQ` ($FFF0): bit 7 VSYNC, bit 6 SIGINT, for interrupt enables.
* `RIA_SPIN` ($FFF1): `JSR` here waits for the API call. The result comes
  back in A and X.
* `RIA_BUSY` ($FFF2): bit 7 is set while an API call runs.
* The last six bytes hold the 6502 vectors: NMI $FFFA, RESB $FFFC, IRQ/BRK
  $FFFE.
* Reset: the RIA holds RESB low while the 6502 is stopped. PHI2 starts at
  8 MHz and can be set from 100 kHz to 8 MHz with `RIA_ATTR_PHI2_KHZ`.

## VGA: how a picture is drawn

Four steps: select a canvas, load data into XRAM, write each mode's
config (or sprite array) into XRAM, then program scanlines with the mode
macros. The 6502 keeps running while the VGA draws.

* Canvas: `xreg_vga_canvas(CANVAS_320X240)` gives a blank canvas, with no
  scanlines programmed.
* Modes: 0 console text, 1 colored text cells, 2 tile map, 3 bitmap,
  4 16-bit sprites (rotate and scale), 5 paletted sprites (1, 2, 4, or 8 bpp).
* Each mode draws a range of scanlines. BEGIN is the first scanline and END
  is one past the last. END 0 runs to the bottom. Modes stack without
  interrupts.
* Mode 3 bitmap color depth is limited by XRAM. 320x240 holds 16 colors, and
  320x180 or 320x200 holds 256.
* Palette: palette address $FFFF uses the built-in palette.

## Sprite limits (PORT page)

Add up the clocks on each scanline and compare with 1,600 at 640 wide, or
3,200 at 320 wide:

* Each scanline: 9 clocks.
* Each sprite that could show on the line: paletted 2, custom 2.5, 16-bit 2,
  affine 5.
* Each sprite that shows on the line: 3, or 4 for affine.
* Each pixel of a sprite on the line: 1/2, or 1 to 2 for affine.
* Each palette cache miss (loads two colors): 3, paletted and custom only.

Maximum sprites on one scanline, at 320 wide and 640 wide:

| Kind | 320 | 640 |
| --- | --- | --- |
| 16-bit 8x8 | 354 | 176 |
| 16-bit 16x16 | 245 | 122 |
| 16-bit 32x32 | 151 | 75 |
| Paletted 8x8 | 269 | 91 |
| Paletted 16x16 | 186 | 63 |
| Paletted 32x32 | 115 | 39 |

Sprites spread across different scanlines can number far more. Game
sprites must stay within these budgets on every line.

## Keyboard and input

* The keyboard is mapped to XRAM as a 32-byte bitmap, one bit per HID
  keycode. `xreg_ria_keyboard(XRAM_KEYBOARD)` maps it.
* Test a key with `KEYBOARD_PRESSED XRAM_KEYBOARD, HID_KEY_x`.
* Gamepads: 15 buttons in the Linux and Android generic layout. The d-pad and
  left stick can be ORed together, since their low four bits match.
  Do not use Home, since the host often takes it for itself.

## API and files (for the game only if needed)

* Most calls are standard C. The API has no calls for video, sound, or input.
  Those use the XRAM devices above.
* XRAM calls in C: `xram0_read`, `xram0_write`, `xram0_set`, `xram_move`,
  `xram0_peek8`, `xram0_poke8`. In assembly, use the RIA portal registers.
* `exit()` returns to the monitor on the board, or ends the emulator.
* Files: `open` needs O_RDONLY (0x01), O_WRONLY (0x02), or O_RDWR (0x03).
  O_RDONLY is not 0. Named ROM assets open as `ROM:name`.
* Saves: the docs describe `SAVE:` on the Pocket. Check the PORT page's
  Saves section before you rely on it for the board.

## Terminal

* stdin, stdout, and stderr map to the VGA console, USB serial, telnet, and
  the emulator console. `printf` prints to all of them at once.
* The console is VGA mode 0. The game can use it for debug text while the
  other modes draw the playfield.

## Porting from Apple II

* Apple II hi-res is 280x192. The RP6502 bitmap modes use 320x240 or
  320x200, with 16 or 256 colors. Sizes and palettes must be redone.
* Apple II keyboard: the controls in `apple2/plan.md` are A/D or Left/Right to
  move and Space to fire. The RIA keyboard bitmap in XRAM replaces the Apple II
  keyboard input. Read the Apple II source before you port that code.
* Sound: the Apple II speaker code must be replaced with the RP6502 PSG or
  OPL2 (both at the RIA). Read the RIA page's sound section before you start.
* Milestones from `apple2/plan.md` still apply as a checklist: small
  working programs, each checked before the next.

## Still to read

These docs sections were not read in full during the planning session:

* VGA: the config struct for each mode, palette formats, tile and font data.
* RIA: mouse, tablet, PSG, OPL2, RTC, and full keyboard details.
* API: the full file, directory, and time calls.
* TERM: the full escape-sequence list.
* PORT: filesystem names and durability notes.
* PICO: monitor commands and the telnet settings.
