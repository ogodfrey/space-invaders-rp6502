# Space Invaders - Session State

> Living log of where things stand. Update at the end of each session and
> after finishing any milestone. Newest entry on top.

## 2026-09-07 - Milestone 6 complete

**Status:** `m06-alien-sprite/alien.asm` finished - a single invader
sprite drawn at a fixed test position (own `alien1_left`/`alien1_right`
and `alien2_left`/`alien2_right` byte tables, own row count), alternating
between the two animation frames (legs in/out) on a timer paced by the
`delay` subroutine. Confirmed working visually in AppleWin (both halves
render correctly, animation toggles at a visible, tunable rate). All
TODOs resolved, comments cleaned up.

**Key reusable infrastructure/lessons added this milestone:**
- A runtime-selectable sprite table pair (choosing between two full sets
  of `.byte` data, like `alien1_*`/`alien2_*`) needs an actual branch per
  byte, immediately followed by the store - a `label,x` instruction's
  table address is baked in at assemble time, so you can't swap which
  table it reads via a runtime value using the same instruction. Any
  branch/label logic must feed straight into the corresponding `sta`
  with nothing unconditional in between that could overwrite the result.
- `PLAYER_SPRITE_ROWS = * - player_sprite_left`-style row-count
  computations must sit directly between the two same-length tables they
  measure, not after both - recurred twice this session, once with a
  genuine row-count mismatch between the two tables too.
- Real (not compile-time-only) game variables that change at runtime
  need their own zero-page address (`= $XX`), not an equate to their
  current/initial *value* - the latter silently compiles later
  `sta`/`lda` on that variable into reads/writes of a completely
  unrelated fixed memory address.
- `.byte` data placed before the program's entry label gets executed as
  code on boot (DOS starts execution at the load address, sequentially)
  - any data that needs to be readable/writable at runtime belongs in
  zero page or after all code, never spliced into the instruction stream
  before `start:`.
- 8-bit relative branches (`beq`/`bne`/etc.) have a limited range
  (~-128/+127 bytes) - as a routine grows, a previously-fine
  `beq far_label` can start failing to assemble ("branch too far"). Fix
  by inverting the condition and branching around an unconditional `jmp`
  (unlimited range), not by trying to shorten the code in between.
- A per-frame delay counter is capped by its counter's width (8-bit maxes
  at 255 iterations) - if a "still too fast" symptom persists even after
  maximizing the counter, the real fix is adding actual paced delay time
  per loop iteration (reusing `delay`), not raising the counter further.
- Wiring a background timer (like animation) into a loop that has other
  conditional delay paths (like the bullet's per-step delay) requires
  checking each path gets *exactly one* real-time delay per iteration -
  duplicate delay calls silently double an already-tuned speed.

**Next action:** Start M7 - alien grid (render a full grid of aliens,
e.g. 5x6 to start, with a table tracking alive/dead state per alien).

## 2026-09-06 - Milestones 4 and 5 complete

**Status:** `m04-keyboard-movement/movement.asm` finished - A/D and
arrow-key movement, clamped to screen bounds, with the player sprite
extended to a 2-byte-wide (14-pixel) ship. `m05-player-bullet/bullet.asm`
finished - Space fires a single two-byte-wide bullet centered on the
ship's tip seam, moving 5 rows/frame (scaled from the arcade original's
6px/frame on a 256px-tall screen to our 192-row screen), paced by a
cycle-counted `delay` subroutine approximating one 60Hz frame. Both
confirmed working visually in AppleWin. Comments cleaned up, all TODOs
resolved.

**Key reusable infrastructure added this milestone:**
- Two-byte-wide sprites/projectiles should straddle the seam using the
  same bit pair (`$40` at the left byte, `$01` at the right byte) to
  render a clean two-pixel-wide line without NTSC color artifacts -
  isolated single bits render as colored dots, not white.
- `delay` (nested zero-page counters, `dec`/`bne`) - a simple
  cycle-counted pacing subroutine. Tune the outer/inner counts by
  estimating cycles-per-iteration (~5 for a `dec`/`bne` pair) against
  the target real-time duration; this isn't synced to true 60Hz vertical
  blank, just an approximation.
- Off-screen/boundary checks that decrement by more than 1 must compare
  before subtracting (`cmp`/`bcc`) rather than relying on `bmi` (which
  incorrectly treats any row >= 128 as "negative") or on landing exactly
  on a boundary value.

**Next action:** Start M6 - single alien sprite (design and draw one
invader bitmap, 2 animation frames for legs in/out).

## 2026-09-01 (c) - Milestone 3 complete

**Status:** `m03-player-sprite/player.asm` finished - `draw_sprite` and
`erase_sprite` both use `calc_row_ptr` + a zero-page `SPRITE_ROW` loop
counter, confirmed working cleanly in AppleWin (solid 6-row cannon shape,
clean erase, no gaps). Comments cleaned up, dead code removed. Next up:
M4 (keyboard input & movement).

**Key reusable infrastructure added this milestone:**
- `calc_row_ptr` (row number in A -> HGR_PTR) - correctly handles the
  per-band hi-res row table for any row/any sprite height. Every future
  milestone that draws at an arbitrary row should reuse this rather than
  re-deriving row addressing.
- Pattern: when a subroutine uses X/Y internally (like `calc_row_ptr`
  does), keep loop counters in a zero-page variable, not a register, and
  reload into a register only immediately before each use.

**Next action:** Start M4 - keyboard input and player movement (read the
keyboard soft switch, move the sprite left/right within screen bounds,
erase-then-redraw each frame).

## 2026-09-01 (b) - draw_sprite fixed, erase_sprite still pending

**Status:** `draw_sprite` in `m03-player-sprite/player.asm` confirmed
correct and visually solid (6-row cannon shape, no gaps) after a long
debugging chain. Root cause was a fundamental one: `hgr_row_lo`/
`hgr_row_hi` are indexed per 8-row BAND, not per row - fixed with a new
reusable `calc_row_ptr` subroutine (row number in `A` -> `HGR_PTR` set
correctly, handles any row/any sprite height, including spanning band
boundaries). See lessons-learned.md for the full debugging story and the
register-clobbering / `#` immediate-mode traps hit along the way.

**`erase_sprite` still uses the OLD buggy approach** (direct table index
by row counter) - same 8-row-gap bug will show when erasing. User is
tackling this next, applying the same `calc_row_ptr` + zero-page loop
counter pattern now proven out in `draw_sprite`.

**Sprite art:** `player_sprite` is now 6 rows (`$1C, $1C, $3E, $3E, $FF,
$FF`) - narrow top, widening to full width, all using contiguous bit
runs (no isolated single-bit rows, which caused an NTSC color-artifact
"dot" earlier).

**Next action:** Fix `erase_sprite` the same way as `draw_sprite`, then
this milestone (M3) is complete - move on to M4 (keyboard input &
movement).

## 2026-09-01 (a) - M2 cleanup, M3 in progress

**Status:** `m02-hires-basics/hires.asm` cleaned up (removed stale TODOs,
added a comment to every code line, dropped a few genuinely dead/
redundant instructions found along the way - 118 -> 112 bytes, same
behavior, reconfirmed working in AppleWin). `m03-player-sprite/`
skeleton exists (mirrors M2's build/launch pipeline, targets
`PLAYERM3`); only the clear-screen block has been copied over so far -
`PLAYER_ROW`/`PLAYER_COL`, `player_sprite` bytes, `draw_sprite`,
`erase_sprite`, and the draw/erase/wait wiring are all still empty.

**Next action:** Continue M3 - design the player_sprite bitmap, pick
PLAYER_ROW/PLAYER_COL, then implement draw_sprite/erase_sprite using the
hgr_row_lo/hgr_row_hi table (indexing by PLAYER_ROW + sprite row number
is the open question raised for the user to think through).

## 2026-08-30 - Milestone 2 complete

**Status:** `m02-hires-basics/hires.asm` written (by user, with iterative
debugging help), assembled, and confirmed working in AppleWin: switches
to full-screen Hi-Res page 1, clears the entire 8K to black, and plots a
visible test row using the 24-entry row base-address table built in the
skeleton. Next up: M3 (static player sprite).

**Pipeline reused from M1 unchanged** - `m02-hires-basics/build.ps1` and
`launch.ps1` are the same DOS 3.3 + AppleCommander approach, just
targeting `HIRESM2` instead of `HELLOM1`. No new tooling needed this
milestone - good sign the M1 pipeline generalizes.

**Bugs hit and fixed while writing the clear-screen loop** (see
[lessons-learned.md](lessons-learned.md) for full detail): row-table
overflow past $3FFF (caught by checking the math before running),
`STY`/`STX` have no immediate addressing mode, plain `(zp)` indirect
addressing barely exists on 6502 (only `JMP`), `(zp),Y` vs `zp,Y` are
very different things (one dereferences a pointer, the other doesn't -
and for `STA` on a zero-page location with no zp,Y mode, the assembler
silently substitutes absolute,Y, which can silently target the wrong
memory - stack included - with no assembler error), and a partially-
initialized zero-page pointer (high byte set, low byte never explicitly
zeroed) still "works" in the sense of dereferencing successfully, just
to the wrong address.

**Next action:** Start M3 - draw a simple static player-cannon shape at
a fixed, byte-aligned position, then erase it cleanly. I'll explain the
approach; user writes the code.

## 2026-08-29 (b) - Milestone 1 complete

**Status:** `m01-dos-hello/hello.asm` written (by user), assembled, and
confirmed running correctly in AppleWin via a real DOS 3.3 boot -> auto
`BRUN` chain. Next up: M2 (Hi-Res fundamentals).

**What the pipeline now is** (`m01-dos-hello/build.ps1` +
`launch.ps1`, will be the template for later milestones' scripts):
1. `64tass -a -o hello.bin hello.asm` (origin `$6000`).
2. Strip 64tass's 2-byte load-address header to get raw code bytes.
3. Start from AppleWin's bundled real `DOS 3.3 System Master -
   680-0210-A.dsk` (NOT AppleCommander's `-dos140`, which only has a
   placeholder splash and can't auto-boot - see lessons-learned.md).
   Read it fully into memory and write a fresh local copy (avoids a
   OneDrive ReparsePoint/ReadOnly issue `Copy-Item` triggered).
4. Unlock + delete the master's stock `HELLO`, inject our binary as
   `HELLOM1` at `0x6000` via `ac.jar -p` (stdin redirected with `cmd /c
   "... < file"`, not a PowerShell pipe - see lessons-learned.md).
5. Inject a 2-line Applesoft `HELLO`:
   `10 D$ = CHR$(4)` / `20 PRINT D$;"BRUN HELLOM1"` via `ac.jar -bas`.
   (`BRUN` alone as a bare statement is invalid Applesoft syntax - it's
   a DOS command, must be sent via the Ctrl-D print trick.)
6. Launch AppleWin with `-d1 hello.dsk` (path quoted - project folder
   name has a space, see lessons-learned.md).

**Bugs hit and fixed this session:** `tools/ac.ps1` common-parameter
prefix collision, binary-over-PowerShell-pipe corruption, unquoted
`Start-Process` path with a space, new-shell PATH not picking up a
fresh winget install, AppleCommander blank disks not being bootable,
OneDrive reparse-point copy issue, and the `BRUN`-is-not-Applesoft
syntax error. All logged in [lessons-learned.md](lessons-learned.md).

**Next action:** Start M2 - Hi-Res graphics fundamentals (soft switches,
page 1 memory layout, pixel/byte encoding). I'll explain the concepts;
user writes the code.

## 2026-08-29 (a)

**Status:** Environment validated. No game code written yet. Next up: M1
(DOS 3.3 hello pipeline).

**Done:**
- Confirmed `64tass` works (rebuilt `01-hello`'s existing program
  successfully).
- Confirmed AppleWin works (relaunched with `01-hello`'s bootable disk;
  previously logged boot from 2026-08-28 also succeeded).
- Discovered VICE (`x64sc.exe`) is a Commodore emulator, not usable for
  Apple II - flagged and corrected in the workspace [README](../../README.md).
- Investigated disk-authoring tooling: no AppleCommander/cadius was
  pre-installed.
- Downloaded AppleCommander 14.0's native Windows exe
  (`ac-windows-amd64-14.0.exe`) - it crashed silently (exit code 1, no
  output) on this machine. Abandoned.
- Installed Java 25 (Eclipse Temurin JRE) via winget, downloaded
  AppleCommander's cross-platform CLI jar instead
  (`AppleCommander-ac-14.0.jar`), verified SHA256 against the GitHub
  release. Works via `java -jar`.
- Added `tools/ac.jar` + `tools/ac.ps1` (thin wrapper) to the workspace
  root `tools/` folder for reuse across projects.
- Ran a full self-test: assembled a trivial 6502 stub with `64tass`,
  created a 140K DOS 3.3 disk image with `tools/ac.ps1 -dos140`, injected
  it as a `BIN` file at its load address with `-p`, created an
  auto-boot `HELLO` Applesoft loader (`10 BRUN TEST`) with `-bas`, booted
  it in AppleWin, and user confirmed it boots correctly.
- Created [plan.md](plan.md) with the full M0-M16 milestone breakdown.

**Decisions locked in (see [plan.md](plan.md) for full detail):**
- Hi-Res graphics, DOS 3.3 disk via AppleCommander, full arcade-like
  scope, keyboard controls, AppleWin-only testing.

**Next action:** Start M1 - write a tiny `.asm` "hello" program (not a
boot sector this time - a normal DOS BIN file) with hints from me, then
build a `build.ps1`/`launch.ps1` pair (modeled on `01-hello`'s, but using
the DOS 3.3 + AppleCommander pipeline instead of the raw boot-sector
hack) to assemble, package, and launch it.
