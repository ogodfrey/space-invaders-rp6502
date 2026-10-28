BUILD ?= build/cc65/debug                           # build folder, overridable on the command line
DEVICE ?= /dev/ttyACM0                              # serial device of the RP6502-PICO
ROM ?= $(BUILD)/space-invaders/space-invaders.rp6502 # ROM file to upload

.PHONY: all build upload                            # targets that are not files

all: build                                          # default target builds the ROM

build:                                              # configure and build the project
	cmake --preset cc65/Debug                       # configure with the cc65 Debug preset
	cmake --build $(BUILD)                          # compile and link the ROM

upload: build                                       # build, then send the ROM to the board
	python3 tools/rp6502.py run --device $(DEVICE) --term False $(ROM) # run it on the board
