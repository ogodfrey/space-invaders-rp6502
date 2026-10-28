.ifndef __XRAM_INC                                  ; include guard: only define once
__XRAM_INC = 1                                      ; marks this file as included

KEYBOARD_NO_KEY      = 0                            ; lock-key state: none
KEYBOARD_NUM_LOCK    = 1                            ; lock-key state: Num Lock
KEYBOARD_CAPS_LOCK   = 2                            ; lock-key state: Caps Lock
KEYBOARD_SCROLL_LOCK = 3                            ; lock-key state: Scroll Lock

; USB HID key codes for the game's controls
HID_KEY_A           = $04                           ; A key
HID_KEY_D           = $07                           ; D key
HID_KEY_SPACE       = $2C                           ; Space bar
HID_KEY_ARROW_RIGHT = $4F                           ; right arrow
HID_KEY_ARROW_LEFT  = $50                           ; left arrow

.macro KEYBOARD_PRESSED keys, code                  ; test a key bit in a 6502 RAM bitmap
    lda keys + (code >> 3)                          ; load the byte holding the key (6502 RAM, not XRAM)
    and #1 << (code & 7)                            ; isolate the key's bit
.endmacro                                           ; end of KEYBOARD_PRESSED

.macro xreg_ria_keyboard addr                       ; map the keyboard bitmap to an XRAM address
    xreg $0, $0, $00, addr                          ; device 0, channel 0, index 0: keyboard
.endmacro                                           ; end of xreg_ria_keyboard

.struct keyboard_t                                  ; keyboard bitmap layout
    keys .res 32                                    ; one bit per HID key code, 32 bytes
.endstruct                                          ; end of keyboard_t

; Mode 3 bitmap configuration, as the VGA docs define it
.struct mode3_config_t                              ; Mode 3 config layout, 14 bytes
    x_wrap           .byte                          ; repeat the bitmap across the canvas
    y_wrap           .byte                          ; repeat the bitmap down the canvas
    x_pos_px         .word                          ; horizontal position in pixels
    y_pos_px         .word                          ; vertical position in pixels
    width_px         .word                          ; bitmap width in pixels
    height_px        .word                          ; bitmap height in pixels
    xram_data_ptr    .word                          ; XRAM address of the pixel data
    xram_palette_ptr .word                          ; XRAM address of the palette
.endstruct                                          ; end of mode3_config_t

MODE3_4BPP = $02                                    ; Mode 3 option: 4 bits per pixel
MODE3_REVERSE_BITS = $08                            ; Mode 3 option: reverse pixel order in each byte

.macro xreg_vga_canvas canvas                       ; select the VGA canvas
    xreg $1, $0, $00, canvas                        ; device 1, channel 0, index 0: canvas
.endmacro                                           ; end of xreg_vga_canvas

.macro xreg_vga_mode0 plane, begin, end             ; console mode on a plane and scanline range
    xreg $1, $0, $01, 0, plane, begin, end          ; mode 0 (console) at index 1
.endmacro                                           ; end of xreg_vga_mode0

.macro xreg_vga_mode3 options, config, plane, begin, end ; bitmap mode on a plane and scanline range
    xreg $1, $0, $01, 3, options, config, plane, begin, end ; mode 3 (bitmap) at index 1
.endmacro                                           ; end of xreg_vga_mode3

.macro COLOR_FROM_RGBA r, g, b, alpha               ; pack 8-bit RGBA into a 16-bit RGB555 color
    .word (((b) >> 3) << 11) | (((g) >> 3) << 6) | (((alpha) >> 7) << 5) | ((r) >> 3) ; RGB555 with alpha bit
.endmacro                                           ; end of COLOR_FROM_RGBA

; The 320x240 bitmap is 4 bits per pixel: 160 bytes per row.
BITMAP_WIDTH_PX  = 320                              ; bitmap width in pixels
BITMAP_HEIGHT_PX = 240                              ; bitmap height in pixels

.struct xram_layout_t                               ; the whole XRAM layout the game uses
    keyboard       .tag keyboard_t                  ; keyboard bitmap, 32 bytes
    palette        .res 32                          ; 16 colors, 2 bytes each
    bitmap_config  .tag mode3_config_t              ; Mode 3 config, 14 bytes
    blank          .res 2                           ; zero bytes, used to erase sprites
    player_sprite  .res 64                          ; player sprite, 8 bytes by 8 rows
    squid_a        .res 32                          ; squid frame A, 4 bytes by 8 rows
    squid_b        .res 32                          ; squid frame B
    crab_a         .res 32                          ; crab frame A
    crab_b         .res 32                          ; crab frame B
    octo_a         .res 32                          ; octopus frame A
    octo_b         .res 32                          ; octopus frame B
    bullet_sprite  .res 8                           ; bullet, 1 byte by 8 rows
    bomb_sprite    .res 8                           ; alien bomb, 1 byte by 8 rows
    ufo_sprite     .res 64                          ; bonus saucer, 8 bytes by 8 rows
    shield_block   .res 2                           ; one solid shield cell byte, then padding
    ; ca65 limits .res to 32767 bytes, so the bitmap is split in two halves
    ; that sit next to each other in XRAM.
    ; 320 * 240 / 4 bytes each. ca65 rejects this as a symbol expression here.
    bitmap_top     .res 19200                       ; first half of the bitmap
    bitmap_bottom  .res 19200                       ; second half of the bitmap
.endstruct                                          ; end of xram_layout_t

XRAM_KEYBOARD       = xram_layout_t::keyboard       ; XRAM address of the keyboard bitmap
XRAM_PALETTE        = xram_layout_t::palette        ; XRAM address of the palette
XRAM_BITMAP_CONFIG  = xram_layout_t::bitmap_config  ; XRAM address of the Mode 3 config
XRAM_BLANK          = xram_layout_t::blank          ; XRAM address of the zero bytes
XRAM_PLAYER_SPRITE  = xram_layout_t::player_sprite  ; XRAM address of the player sprite
XRAM_SQUID_A        = xram_layout_t::squid_a        ; XRAM address of squid frame A
XRAM_SQUID_B        = xram_layout_t::squid_b        ; XRAM address of squid frame B
XRAM_CRAB_A         = xram_layout_t::crab_a         ; XRAM address of crab frame A
XRAM_CRAB_B         = xram_layout_t::crab_b         ; XRAM address of crab frame B
XRAM_OCTO_A         = xram_layout_t::octo_a         ; XRAM address of octopus frame A
XRAM_OCTO_B         = xram_layout_t::octo_b         ; XRAM address of octopus frame B
XRAM_BULLET_SPRITE  = xram_layout_t::bullet_sprite  ; XRAM address of the bullet sprite
XRAM_BOMB_SPRITE    = xram_layout_t::bomb_sprite    ; XRAM address of the alien bomb sprite
XRAM_UFO_SPRITE     = xram_layout_t::ufo_sprite     ; XRAM address of the bonus saucer sprite
XRAM_SHIELD_BLOCK   = xram_layout_t::shield_block   ; XRAM address of the solid shield cell byte
XRAM_BITMAP         = xram_layout_t::bitmap_top     ; XRAM address of the bitmap

.endif                                              ; end of the include guard
