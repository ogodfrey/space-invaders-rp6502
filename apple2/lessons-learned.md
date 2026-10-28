# Space Invaders - Lessons Learned

Non-obvious things discovered while building this project. Newest first.

## 2026-09-06 - Two-byte sprites, NTSC color artifacts, and boundary checks (M4/M5)

- **A single isolated hi-res bit renders as a colored dot, not white.**
  On Apple II hi-res, true white requires two *horizontally-adjacent*
  lit pixels - the NTSC composite color decoder interprets one lit bit
  surrounded by black as a colored artifact (purple/green/blue depending
  on screen position) rather than clean white. Hit this twice: once on
  the player sprite's single-bit tip rows, and again on the bullet's
  single-bit pixel. Fix: always light at least two adjacent bits.
- **Bit 7 of a hi-res byte is a color-group selector, not a pixel** -
  only bits 0-6 (7 pixels per byte) are actual screen pixels. Setting
  bit 7 alone (`#$80`) lights zero pixels and can flip the color
  interpretation of neighboring bytes.
- **Two-byte-wide sprites/projectiles should straddle the seam with a
  matching bit pair**: bit 6 (rightmost pixel) of the left byte plus bit
  0 (leftmost pixel) of the right byte are horizontally adjacent, so
  `$40`/`$01` at `col`/`col+1` renders as two adjacent white pixels
  exactly centered on the seam between the two bytes - reused for both
  the player sprite's tip and the bullet, so the bullet emerges from
  exactly the same point the tip occupies.
- **A byte value can be individually correct but placed in the wrong
  table.** Swapping the *entire contents* of `player_sprite_left` and
  `player_sprite_right` (rather than getting an individual bit wrong)
  produced two isolated dots at the sprite's far edges instead of two
  adjacent pixels at the center seam - each value was valid on its own,
  just in the wrong array.
- **`bmi`/`bpl` test bit 7 of the result, not "went below zero" in the
  way you might expect for a bounded 0-191 row range.** Every row from
  128-191 already has bit 7 set, so `dec BULLET_ROW` / `bmi bullet_gone`
  triggered on the very first decrement (175 -> 174, still >= 128),
  long before the bullet reached the top of the screen. Fix: for a
  monotonic single-step decrement from a known positive start, `beq`
  (exactly zero) is a valid boundary check. For a multi-row step (e.g.
  subtracting 5 at once), check *before* subtracting with `cmp`/`bcc`
  instead, since the value won't necessarily land exactly on the
  boundary.
- **Zero page is not guaranteed to be all-zero when a DOS 3.3 BIN file
  starts running.** A new flag variable (`BULLET_ACTIVE`) with no
  explicit initialization can start with leftover garbage from DOS/
  Applesoft's own zero-page usage. If a guard clause checks that flag
  before ever writing to it (`bne main_loop` in `handle_space`), garbage
  can silently and permanently block the feature. Always explicitly
  initialize every zero-page flag/variable before the main loop starts,
  not just the ones with an obvious starting value like a column
  position.
- **Speed/timing values from a different arcade resolution need
  rescaling, not copying.** The original Space Invaders' bullet speed
  (6px/frame on a 256px-tall screen) is a *proportion of screen height
  per frame* (6/256 ≈ 2.34%), not an absolute pixel count. Applied
  directly to our 192-row screen it would cross far too quickly;
  rescaled (`192 * 6/256 = 4.5`, rounded to 5 rows/frame) it preserves
  the original's crossing time instead.
- **A tight polling loop with no delay moves far faster than visible.**
  Redrawing a projectile once per pass through a bare `main_loop` (no
  synced timing) can complete its whole trip across the screen in a
  fraction of a millisecond - faster than a video frame, so it never
  gets rendered as motion. A simple cycle-counted `delay` subroutine
  (nested zero-page counters, `dec`/`bne`) approximating a real-time
  duration (~5 cycles per inner iteration; count iterations needed for
  the target duration at ~1MHz) fixes this, though it's only an
  approximation, not synced to the true 60Hz vertical blank.

## 2026-08-29 - Tooling

- **VICE cannot run Apple II code.** VICE emulates Commodore 8-bit
  machines (C64/C128/VIC-20/PET/Plus4). Apple II has a completely
  different memory map and ROM (e.g. `COUT` at `$FDED`, `HOME` at
  `$FC58`), so VICE is the wrong tool even though it was listed as
  "validated" in the workspace README. Use AppleWin exclusively for
  Apple II work.
- **AppleCommander's native Windows exe can silently fail.** The
  GraalVM-native `ac-windows-amd64-14.0.exe` from the v14.0 GitHub
  release exits with code 1 and prints nothing on this machine (hash
  verified correct, so not a bad download - environment-specific issue,
  never root-caused). The cross-platform `AppleCommander-ac-14.0.jar`
  run via `java -jar` works reliably. If AppleCommander ever needs
  updating, prefer the jar unless the native exe is re-verified working.
- **DOS 3.3 auto-boot convention:** DOS 3.3 disks auto-run a file named
  `HELLO` at boot. A one-line tokenized Applesoft program
  (`10 BRUN <NAME>`) is enough to jump into a machine-language program.
  AppleCommander's `-bas` flag tokenizes a plain-text Applesoft listing
  piped via stdin directly into a disk image.
- **Binary injection needs the load address, and the raw bytes (no
  64tass header).** `64tass -a -o out.bin` prepends a 2-byte
  little-endian load address to the output file. When injecting into a
  DOS 3.3 image with `ac.jar -p <img> <name> BIN <addr>`, strip those
  first 2 bytes and pass the same address explicitly, or the file will
  contain a stray 2-byte prefix before the actual code.

## 2026-08-29 - PowerShell gotchas in build/launch scripts

- **`Start-Process -ArgumentList` does not auto-quote array elements
  containing spaces.** Our project folder is literally named
  `Space Invaders`, so any path under it passed as a bare array element
  (e.g. `'-d1', $DiskImage`) gets split at the space by the child
  process's command-line parser (AppleWin showed "Unsupported commands:
  Invaders\...\hello.dsk"). Fix: wrap the value in escaped quotes inside
  the array element, e.g. `'-d1', "`"$DiskImage`""`.
- **A `param()` block with even one `[Parameter(...)]` attribute makes a
  script "advanced"**, which silently enables PowerShell's common
  parameters (`-Verbose`, `-WhatIf`, `-PipelineVariable`, etc.). This
  broke `tools/ac.ps1`: passing `-p` got prefix-matched against the
  common parameter `-PipelineVariable` instead of reaching
  AppleCommander. Fix: don't declare a param block at all when you just
  want to forward all args - use the automatic `$args` variable instead.
- **Piping binary data through PowerShell's object pipeline corrupts
  it** (`Get-Content -Raw -Encoding Byte | someExe.exe`) - PowerShell
  enumerates/text-converts pipeline objects rather than streaming raw
  bytes to a native process's stdin. Use `cmd /c "someExe.exe < file"`
  (OS-level redirection) instead when a native tool needs raw bytes on
  stdin, as AppleCommander's `-p`/`-bas` do.
- **New child PowerShell processes don't pick up `$env:Path` changes
  made only in-memory in another session.** After installing Java via
  winget, a freshly spawned `powershell -File build.ps1` still couldn't
  find `java` on PATH. Fix: reference `java.exe` by its absolute
  install path in scripts rather than relying on PATH.
- **AppleCommander's blank `-dos140` disks aren't really bootable** -
  they only contain a placeholder splash ("APPLECOMMANDER CREATED THIS
  DISK... INSERT ANOTHER DISK") instead of real DOS 3.3 system tracks
  (AppleCommander can't legally bundle Apple's copyrighted DOS code).
  A `HELLO` file injected onto one will never auto-run. Fix: start from
  a genuine DOS 3.3 System Master image instead - AppleWin conveniently
  ships one at
  `...\WinGet\Packages\AppleWin.AppleWin_.../DOS 3.3 System Master - 680-0210-A.dsk`.
  Copy it, unlock+delete its stock `HELLO`, then inject ours.
- **This workspace lives under OneDrive, and that can poison file
  copies.** `Copy-Item` on the OneDrive-synced System Master produced a
  destination file with `ReparsePoint` + `ReadOnly` attributes, which
  made Java's `FileOutputStream` fail with Access Denied. Fix: read the
  source fully into memory (`[IO.File]::ReadAllBytes`, which also forces
  OneDrive to hydrate a cloud placeholder if needed) and write it back
  out fresh with `[IO.File]::WriteAllBytes` instead of `Copy-Item`.
- **AppleWin holds the disk image file open while running** - rebuilding
  a `.dsk` while AppleWin still has it mounted fails with Access Denied.
  Close AppleWin (or `Stop-Process -Name AppleWin*`) before rebuilding.
- **`BRUN` is a DOS command, not an Applesoft keyword** - a program line
  like `10 BRUN HELLOM1` is invalid Applesoft syntax (`?SYNTAX ERROR IN
  10`). DOS 3.3 commands embedded in a BASIC program must be sent by
  printing `CHR$(4)` (Ctrl-D) immediately followed by the command text,
  e.g.:
  ```
  10 D$ = CHR$(4)
  20 PRINT D$;"BRUN HELLOM1"
  ```
  DOS's output hook intercepts text following a Ctrl-D as a command
  line. Confirmed this pattern by exporting/detokenizing an existing
  Applesoft program (`MASTER`) from the real System Master disk with
  `ac.jar -e` and matching its style.

## 2026-08-30 - 6502 addressing-mode gotchas (M2, hi-res clear loop)

Several rounds of debugging on the same loop, each worth remembering:

- **`STY`/`STX` have no immediate addressing mode.** `sty #$00` fails to
  assemble ("no immediate addressing mode for opcode 'sty'") - store
  instructions only write a register *to* memory, they never take an
  immediate source. Use `ldy #$00` to load, or `lda #$00` + `sta zp` to
  store a literal.
- **Plain `(zp)` indirect addressing (no `,X`/`,Y`) barely exists on the
  6502** - only `JMP (addr)` uses it. `sty (HGR_PTR)` fails to assemble
  ("no indirect addressing mode for opcode 'sty'"). To store a literal
  into a zero-page byte, just use a plain zero-page store: `sta HGR_PTR`
  (no parens, no index).
- **`(zp),Y` (indirect indexed) vs `zp,Y` (indexed) are completely
  different addressing modes** - easy to confuse by adding/removing one
  set of parentheses. `(HGR_PTR),Y` dereferences the 16-bit pointer
  stored at zero-page `HGR_PTR`/`HGR_PTR+1` and adds Y (what you want for
  reaching hi-res memory at $2000+). `HGR_PTR,Y` is the address
  `HGR_PTR` itself plus Y - for a zero-page location like `$06` with
  `STA` (which has no zp,Y mode at all), the assembler silently falls
  back to absolute,Y, so this ends up writing to `$0006-$0105` - zero
  page and the 6502 hardware stack ($0100-$01FF) - instead of the hi-res
  screen. No assembler error, just silently wrong addresses; only caught
  by reasoning about what it does.
- **An indirect pointer is only as good as its initialization.** Setting
  the high byte of a zero-page pointer each loop pass (`stx HGR_PTR+1`)
  but never explicitly zeroing the low byte means the low byte keeps
  whatever was left over in that zero-page location before the program
  ran. `(HGR_PTR),Y` still "correctly" dereferences that pointer - it's
  just the wrong pointer, offsetting the entire sweep by the leftover
  value and missing/overrunning the intended range. Always explicitly
  initialize every byte of a multi-byte pointer, not just the one that
  changes.

## 2026-09-01 - The hi-res row table is per-BAND, not per-ROW (M3)

Spent a long debugging session chasing what looked like a display
rendering issue (AppleWin's "Composite Idealized" scanline effect) that
turned out to be a real addressing bug, missed across several rounds of
review:

- **`hgr_row_lo`/`hgr_row_hi` have one entry per 8-row band, not one
  entry per screen row.** Table index `k` is the address of screen row
  `8*k` (row 0, 8, 16, 24, ...), NOT row `k`. `draw_sprite` originally
  indexed the table directly by a 0..N sprite-row counter, which only
  "works" by coincidence for a 1-row sprite (M2's test row, index 0). As
  soon as a sprite spans multiple rows, indexing sequentially fetches
  rows 8 apart instead of 1 apart - exactly the "gapped thin lines"
  symptom that looked like a display/scanline issue but wasn't. Ruled
  out the display theory conclusively by testing every AppleWin video
  mode and seeing the same gaps regardless.
- **The fix is a reusable `calc_row_ptr` subroutine**: given an absolute
  row 0-191 in `A`, compute `band = row / 8` (three `LSR`s) and
  `offset_in_band = row mod 8` (`AND #$07`), look up the band's base
  address, then add `offset_in_band * 4` to the base's *high* byte only
  (since each row within a band is `$400` = 4 pages apart, the low byte
  never changes). This is real infrastructure - every future milestone
  that draws at an arbitrary row (aliens, bullets, shields) needs this,
  not just a special-cased "assume it fits in one band" version.
- **A subroutine that uses `X`/`Y` internally will clobber whatever the
  caller was using those registers for.** `calc_row_ptr` uses `X` as the
  band-table index. Calling it mid-loop from `draw_sprite` (which also
  wanted `X` as its own sprite-row counter) silently broke things twice:
  first by reading `player_sprite` with `calc_row_ptr`'s leftover `X`
  instead of the loop's own counter (drew the same byte repeatedly),
  then by comparing a stale pre-increment value against the loop bound
  (ran one extra iteration, reading one byte past the end of
  `player_sprite`). Fix: keep the loop counter in a zero-page variable,
  not a register, and reload it into a register only immediately before
  each use that needs indexed addressing - never assume a register
  survives a `JSR` to something that also uses it.
- **`#` vs. no `#` mistakes go both directions.** Forgetting `#` on a
  compile-time constant makes the assembler read/write memory at that
  numeric address instead of using the literal (`ldy PLAYER_ROW`
  instead of `ldy #PLAYER_ROW`). Adding a stray `#` on a variable does
  the opposite - `ldx #SPRITE_ROW` loads the literal *address* of
  `SPRITE_ROW` instead of the value stored there. `STX`/`INC` have no
  immediate mode at all, so `stx #SPRITE_ROW` / `inc #SPRITE_ROW` are
  assembler errors; `LDX #SPRITE_ROW` has no error but is silently
  wrong. Rule of thumb: `#` means "this literal number, right here" -
  never use it when you mean "the current value stored in memory."

## Template for future entries

```
## YYYY-MM-DD - <topic>

- What happened, what we expected, what actually happened, and the fix
  or workaround.
```
