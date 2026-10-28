BUILD ?= build/cc65/debug
DEVICE ?= /dev/ttyACM0
ROM ?= $(BUILD)/cho-han/cho-han.rp6502

HELLO_ROM ?= $(BUILD)/hello/hello.rp6502

.PHONY: all build upload upload-hello

all: build

build:
	cmake --preset cc65/Debug
	cmake --build $(BUILD)

upload: build
	python3 tools/rp6502.py run --device $(DEVICE) --term False $(ROM)

upload-hello: build
	python3 tools/rp6502.py run --device $(DEVICE) --term False $(HELLO_ROM)
