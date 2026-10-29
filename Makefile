# build folder, overridable on the command line
BUILD ?= build/cc65/debug
# serial device of the RP6502-PICO
DEVICE ?= /dev/ttyACM0
# ROM file to upload
ROM ?= $(BUILD)/space-invaders/space-invaders.rp6502

.PHONY: all build upload                            # targets that are not files

all: build                                          # default target builds the ROM

build:                                              # configure and build the project
	cmake --preset cc65/Debug                       # configure with the cc65 Debug preset
	cmake --build $(BUILD)                          # compile and link the ROM

upload: build                                       # build, then send the ROM to the board
	python3 tools/rp6502.py run --device $(DEVICE) --term False $(ROM) # run it on the board
