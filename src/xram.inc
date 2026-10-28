.ifndef __XRAM_INC
__XRAM_INC = 1

KEYBOARD_NO_KEY      = 0
KEYBOARD_NUM_LOCK    = 1
KEYBOARD_CAPS_LOCK   = 2
KEYBOARD_SCROLL_LOCK = 3

; USB HID key codes for the game's controls
HID_KEY_A           = $04
HID_KEY_D           = $07
HID_KEY_SPACE       = $2C
HID_KEY_ARROW_RIGHT = $4F
HID_KEY_ARROW_LEFT  = $50

.macro KEYBOARD_PRESSED keys, code
    lda keys + (code >> 3)
    and #1 << (code & 7)
.endmacro

.macro xreg_ria_keyboard addr
    xreg $0, $0, $00, addr
.endmacro

.struct keyboard_t
    keys .res 32
.endstruct

.struct xram_layout_t
    keyboard .tag keyboard_t
.endstruct

XRAM_KEYBOARD = xram_layout_t::keyboard

.endif
