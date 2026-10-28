cmake_minimum_required(VERSION 3.21)               # minimum CMake version

include(${CMAKE_CURRENT_LIST_DIR}/tools/rp6502.cmake) # RP6502 build helpers and cc65 setup

project(SPACE-INVADERS ASM)                         # project name and language

add_executable(space-invaders)                      # the ROM target
rp6502_align(space-invaders "XRAM_.*")              # XRAM symbols must be even
rp6502_executable(space-invaders DATA default RESET default) # package the output as a ROM
target_sources(space-invaders PRIVATE               # sources of the ROM
    src/main-cc65.s                                 # the game
)

rp6502_test(NAME game-start COMMAND tests/game-start.script # emulator test of startup and controls
    $<TARGET_PROPERTY:space-invaders,RP6502_ROM>    # the ROM under test
)
