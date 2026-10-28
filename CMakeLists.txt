cmake_minimum_required(VERSION 3.21)

include(${CMAKE_CURRENT_LIST_DIR}/tools/rp6502.cmake)

project(SPACE-INVADERS ASM)

add_executable(space-invaders)
rp6502_align(space-invaders "XRAM_.*")
rp6502_executable(space-invaders DATA default RESET default)
target_sources(space-invaders PRIVATE
    src/main-cc65.s
)