cmake_minimum_required(VERSION 3.21)               # minimum CMake version

include(${CMAKE_CURRENT_LIST_DIR}/tools/rp6502.cmake) # RP6502 build helpers and cc65 setup

project(SPACE-INVADERS ASM)                         # project name and language

add_executable(space-invaders)                      # the ROM target
rp6502_align(space-invaders "XRAM_.*")              # XRAM symbols must be even
rp6502_executable(space-invaders DATA default RESET default) # package the output as a ROM
target_sources(space-invaders PRIVATE               # sources of the ROM
    src/main-cc65.s                                 # the game
)

rp6502_test(NAME grid-march COMMAND tests/grid-march.script # emulator test of grid movement at the edge
    $<TARGET_PROPERTY:space-invaders,RP6502_ROM>    # the ROM under test
)

rp6502_test(NAME grid-edge COMMAND tests/grid-edge.script # the edge uses the living aliens, as in arcade
    $<TARGET_PROPERTY:space-invaders,RP6502_ROM>    # the ROM under test
)

rp6502_test(NAME bomb-hit COMMAND tests/bomb-hit.script # an alien bomb costs a ship and pauses the game
    $<TARGET_PROPERTY:space-invaders,RP6502_ROM>    # the ROM under test
)

rp6502_test(NAME shield-hit COMMAND tests/shield-hit.script # a player bullet destroys one shield cell
    $<TARGET_PROPERTY:space-invaders,RP6502_ROM>    # the ROM under test
)

rp6502_test(NAME ufo-hit COMMAND tests/ufo-hit.script # a bullet hits the bonus saucer and scores its points
    $<TARGET_PROPERTY:space-invaders,RP6502_ROM>    # the ROM under test
)

rp6502_test(NAME sound-shot COMMAND tests/sound-shot.script # the shot sound gates channel 0 for 8 frames
    $<TARGET_PROPERTY:space-invaders,RP6502_ROM>    # the ROM under test
)

rp6502_test(NAME attract COMMAND tests/attract.script # the title screen alternates with the high-score screen
    $<TARGET_PROPERTY:space-invaders,RP6502_ROM>    # the ROM under test
)

rp6502_test(NAME high-score COMMAND tests/high-score.script # a game's score becomes the best if it beats it
    $<TARGET_PROPERTY:space-invaders,RP6502_ROM>    # the ROM under test
)

rp6502_test(NAME bullet-hit COMMAND tests/bullet-hit.script # a player bullet scores an alien in the bottom row
    $<TARGET_PROPERTY:space-invaders,RP6502_ROM>    # the ROM under test
)

rp6502_test(NAME game-over COMMAND tests/game-over.script # the aliens landing ends the game, then the title returns
    $<TARGET_PROPERTY:space-invaders,RP6502_ROM>    # the ROM under test
)

rp6502_test(NAME wave-clear COMMAND tests/wave-clear.script # clearing a wave starts the next one
    $<TARGET_PROPERTY:space-invaders,RP6502_ROM>    # the ROM under test
)

rp6502_test(NAME game-start COMMAND tests/game-start.script # emulator test of startup and controls
    $<TARGET_PROPERTY:space-invaders,RP6502_ROM>    # the ROM under test
)

rp6502_test(NAME extra-ship COMMAND tests/extra-ship.script # reaching 1500 points awards one extra ship
    $<TARGET_PROPERTY:space-invaders,RP6502_ROM>    # the ROM under test
)

rp6502_test(NAME explosions COMMAND tests/explosions.script # hits and ship deaths show bursts that clear
    $<TARGET_PROPERTY:space-invaders,RP6502_ROM>    # the ROM under test
)

rp6502_test(NAME bomb-launch COMMAND tests/bomb-launch.script # an alien bomb is launched and its sound runs out
    $<TARGET_PROPERTY:space-invaders,RP6502_ROM>    # the ROM under test
)
