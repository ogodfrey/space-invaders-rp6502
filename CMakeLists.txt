cmake_minimum_required(VERSION 3.21)

include(${CMAKE_CURRENT_LIST_DIR}/tools/rp6502.cmake)

project(MY-RP6502-PROJECT C CXX ASM)

# The basic preset has no cc65 target, so the C programs are skipped there.
if(NOT RP6502_BASIC)
    # Each cc65 build writes the assembly of its source next to the ROM.
    function(rp6502_cc65_asm target source)
        if(CMAKE_C_COMPILER_ID STREQUAL "cc65")
            find_program(RP6502_CC65 cc65 REQUIRED)
            add_custom_command(TARGET ${target} POST_BUILD
                COMMAND "${RP6502_CC65}" -t rp6502
                    -o "$<TARGET_FILE_DIR:${target}>/${target}.s"
                    "${CMAKE_CURRENT_SOURCE_DIR}/${source}"
                VERBATIM)
        endif()
    endfunction()

    add_executable(hello)
    rp6502_align(hello "XRAM_.*")
    rp6502_asset(hello help src/help.txt)
    rp6502_executable(hello DATA default RESET default)
    rp6502_web(hello)
    target_sources(hello PRIVATE
        src/main.c
    )
    rp6502_cc65_asm(hello src/main.c)

    add_executable(cho-han)
    rp6502_align(cho-han "XRAM_.*")
    rp6502_executable(cho-han DATA default RESET default)
    target_sources(cho-han PRIVATE
        src/cho-han.c
    )
    rp6502_cc65_asm(cho-han src/cho-han.c)
endif()