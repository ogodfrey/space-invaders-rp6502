BUILD ?= build/cc65/debug
DEVICE ?= /dev/ttyACM0
ROM ?= $(BUILD)/space-invaders/space-invaders.rp6502

.PHONY: all build upload

all: build

build:
	cmake --preset cc65/Debug
	cmake --build $(BUILD)

upload: build
	python3 tools/rp6502.py run --device $(DEVICE) --term False $(ROM)
