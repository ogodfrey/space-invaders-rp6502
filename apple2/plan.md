# Space Invaders (Apple II, 6502) - Project Plan

## Goal

Build a "closer to arcade original" Space Invaders clone for the Apple II,
in 6502 assembly, using Hi-Res graphics. You write the assembly code; I
lay out milestones, explain concepts, give hints, and validate results.
I only write infrastructure/tooling (build scripts, disk images), never
game logic, unless you explicitly ask for code.

## Confirmed decisions

- **Graphics mode:** Hi-Res (280x192, page 1). Hardest option chosen
  deliberately - expect Milestone 2 to take real time.
- **Loading mechanism:** DOS 3.3 disk image via AppleCommander (`tools/ac.jar`,
  wrapped by `tools/ac.ps1`). A tokenized Applesoft `HELLO` program does
  `BRUN SPACEINV` to auto-boot into our binary. No custom bootloader needed.
- **Gameplay scope:** Full arcade-like feature set - marching alien grid,
  shields/bunkers, UFO bonus ship, sound, difficulty ramp-up as aliens die.
- **Controls:** Keyboard, A/D or Left/Right to move, Space to fire.
- **Emulator:** AppleWin only. VICE is installed but is a Commodore
  emulator and cannot run Apple II code - do not use it for this project.

## Toolchain (validated 2026-08-29)

| Tool | Path | Purpose |
|---|---|---|
| `64tass` | `C:\msys64\ucrt64\bin\64tass.exe` | Assembler |
| AppleCommander | `tools/ac.jar` (run via `tools/ac.ps1`) | Build DOS 3.3 disk images, inject BIN/Applesoft files |
| Java 25 (Temurin JRE) | installed via winget | Needed to run `ac.jar` |
| AppleWin | winget package `AppleWin.AppleWin` | Apple II emulator for testing |

See [../../README.md](../../README.md) for full detail and the doc correction
about VICE.

## Milestones

Each milestone should be its own small, working, testable program before
moving to the next. Commit/checkpoint your working `.asm` after each one.

- [x] **M0 - Environment validation.** Confirm assembler, AppleCommander,
      and AppleWin all work together end-to-end (self-test binary + DOS
      3.3 disk + auto-boot via HELLO, confirmed booting in AppleWin).
- [x] **M1 - DOS 3.3 "hello" pipeline.** `m01-dos-hello/hello.asm`
      assembles to `$6000`, loaded as a normal DOS BIN file via
      `build.ps1` (assemble -> copy DOS 3.3 System Master -> inject BIN
      + `HELLO` loader) and `launch.ps1`. Confirmed booting and running
      correctly in AppleWin.
- [x] **M2 - Hi-Res fundamentals.** `m02-hires-basics/hires.asm`
      switches on full-screen Hi-Res page 1, clears the full 8K
      ($2000-$3FFF) via a page/offset nested loop, and plots a test row
      using the 24-entry row base-address table. Confirmed clean black
      screen with a single bright test row in AppleWin.
- [x] **M3 - Static player sprite.** `m03-player-sprite/player.asm` draws
      and erases a 6-row cannon shape at a fixed byte-aligned position.
      Required a reusable `calc_row_ptr` subroutine (row number -> hi-res
      address, handling the per-band table correctly for any row) since
      the M2 row table is indexed per 8-row band, not per screen row.
- [x] **M4 - Keyboard input & movement.** Read the keyboard soft switch,
      clear the strobe, move the player sprite left/right within screen
      bounds using A/D or arrow keys, with erase-then-redraw per frame.
      Sprite extended to a 2-byte-wide (14-pixel) ship.
- [x] **M5 - Player bullet.** Space fires a single bullet (arcade-authentic:
      only one on screen at a time) that travels upward, erasing/redrawing
      each frame, and disappears at the top of the screen. Two-byte-wide
      bullet centered on the ship's tip seam, speed scaled from the
      arcade original (6px/frame on a 256px screen -> 5 rows/frame on
      our 192-row screen), paced with a cycle-counted delay subroutine
      approximating one 60Hz frame.
- [x] **M6 - Single alien sprite.** Design and draw one invader bitmap
      (2 animation frames: legs in/out). Alien drawn at a fixed test
      position with its own left/right byte tables and row count,
      alternating between `alien1`/`alien2` frames on a real-time-paced
      timer (reusing the `delay` subroutine), independent of keypresses.
- [ ] **M7 - Alien grid.** Render a full grid of aliens (start smaller
      than the arcade's 5x11 if needed for time budget, e.g. 5x6, and
      scale up later) with a table tracking alive/dead state per alien.
- [ ] **M8 - Alien marching.** Whole grid steps sideways in unison, drops
      a row at the screen edge, reverses direction; alternate the 2
      animation frames each step (classic side-to-side march).
- [ ] **M9 - Collision detection.** Bullet-vs-alien collision using the
      alien table; kill the alien, increment score.
- [ ] **M10 - Alien return fire & player death.** A random alive alien
      periodically fires a bullet downward; bullet-vs-player collision
      ends the life/round.
- [ ] **M11 - Game states.** Title/playing/game-over state machine, lives
      counter, win condition (all aliens dead) and lose condition (aliens
      reach the bottom or player hit).
- [ ] **M12 - Shields/bunkers.** Destructible barriers that chip away
      where hit by player or alien bullets.
- [ ] **M13 - UFO bonus ship.** Periodic bonus enemy crossing the top of
      the screen for bonus score.
- [ ] **M14 - Sound.** Speaker-toggle effects for shoot/explosion/UFO,
      plus the iconic 4-note walking bassline that speeds up as aliens
      die.
- [ ] **M15 - Difficulty & polish.** Speed scaling as aliens die / new
      waves, title screen, lives display, game-over screen.
- [ ] **M16 (stretch) - Extra waves / high score / attract mode.**

## Working agreement

- I explain concepts and give hints/pseudocode; you write the actual
  6502 code.
- We validate each milestone (assemble cleanly + confirm behavior in
  AppleWin) before moving on.
- Progress, decisions, and environment facts go in
  [state.md](state.md) - update it often, especially at the end of a
  session or after finishing a milestone.
- Anything non-obvious we learn (quirks, gotchas, dead ends) goes in
  [lessons-learned.md](lessons-learned.md).
