; Space Invaders for the RP6502 in cc65 assembly.
; The playfield is a 320x240 bitmap on plane 0, 4 bits per pixel. The score
; line is VGA mode 0 console text on plane 1.

.export _main                                       ; make _main visible to the C runtime

.include "rp6502.inc"                               ; RIA and VGA register names
.include "xram.inc"                                 ; XRAM layout and Mode 3 definitions

CANVAS_320X240       = 1                            ; VGA canvas selector for 320x240

; Horizontal positions are in units of 2 pixels: a sprite byte holds two
; 4-bit pixels, so sprites move in whole bytes.
PLAYER_PY            = 200                          ; player sprite top row, in pixels
PLAYER_START_U       = 72                           ; player start x, in 2-pixel units
PLAYER_MIN_U         = 0                            ; leftmost player x
PLAYER_MAX_U         = 152                          ; rightmost player x (320 px - 16 px sprite)
ALIEN_PY             = 56                           ; alien sprite top row, in pixels
ALIEN_START_U        = 72                           ; alien start x, in 2-pixel units
ALIEN_MIN_U          = 0                            ; leftmost alien x
ALIEN_MAX_U          = 152                          ; rightmost alien x
ALIEN_STEP_U         = 4                            ; alien move per step (8 px)
BULLET_STEP_PX       = 8                            ; bullet move per step, in pixels
BULLET_STEP_FRAMES   = 4                            ; frames between bullet steps
ALIEN_STEP_FRAMES    = 48                           ; frames between alien steps
ALIEN_RESPAWN_FRAMES = 60                           ; frames before a killed alien returns

.segment "RODATA"                                   ; read-only data goes in ROM

str_title:                                          ; HUD title text label
    .byte "SPACE INVADERS     SCORE: "              ; title, then the score digits
str_title_len = * - str_title                       ; length of the title text
str_help:                                           ; control hint text label
    .byte "A/D or arrows move  SPACE fires"         ; control hint shown under the title
str_help_len = * - str_help                         ; length of the hint text
div_lo:     .byte <10000, <1000, <100, <10, <1      ; low bytes of decimal place values
div_hi:     .byte >10000, >1000, >100, >10, >1      ; high bytes of decimal place values

palette_rom:                                        ; 16 colors, 2 bytes each, for the bitmap
    COLOR_FROM_RGBA 0, 0, 0, 255            ; 0: black
    COLOR_FROM_RGBA 0, 255, 0, 255          ; 1: green
    COLOR_FROM_RGBA 255, 255, 255, 255      ; 2: white
    .res 26, 0                              ; unused palette entries are transparent black

bitmap_config_rom:                                  ; Mode 3 config, 14 bytes, as the VGA docs lay it out
    .byte 0, 0                                      ; x_wrap and y_wrap off
    .word 0, 0                                      ; bitmap at the top left of the canvas
    .word BITMAP_WIDTH_PX, BITMAP_HEIGHT_PX         ; bitmap size in pixels
    .word XRAM_BITMAP, XRAM_PALETTE                 ; bitmap and palette addresses in XRAM

; Sprites are 8 bytes (16 pixels) by 8 rows, and the bullet is 1 byte wide.
; The order matches xram_layout_t, since they are uploaded as one block.
sprite_rom:                                         ; player, alien A, alien B, bullet
    .byte $00, $00, $00, $01, $10, $00, $00, $00    ; player row 0: cannon tip
    .byte $00, $00, $00, $11, $11, $00, $00, $00    ; player row 1
    .byte $00, $00, $00, $11, $11, $00, $00, $00    ; player row 2
    .byte $01, $11, $11, $11, $11, $11, $11, $10    ; player row 3: wider body
    .byte $11, $11, $11, $11, $11, $11, $11, $11    ; player row 4: full width
    .byte $11, $11, $11, $11, $11, $11, $11, $11    ; player row 5
    .byte $11, $11, $11, $11, $11, $11, $11, $11    ; player row 6
    .byte $11, $11, $11, $11, $11, $11, $11, $11    ; player row 7
    .byte $00, $00, $01, $10, $01, $10, $00, $00    ; alien A row 0: antennae
    .byte $00, $00, $11, $11, $11, $11, $00, $00    ; alien A row 1
    .byte $00, $01, $11, $11, $11, $11, $10, $00    ; alien A row 2
    .byte $00, $11, $01, $11, $11, $01, $10, $00    ; alien A row 3: eyes
    .byte $00, $11, $11, $11, $11, $11, $10, $00    ; alien A row 4
    .byte $00, $00, $10, $01, $10, $01, $00, $00    ; alien A row 5: legs in
    .byte $00, $01, $00, $01, $10, $00, $10, $00    ; alien A row 6: legs in
    .byte $00, $10, $00, $00, $00, $00, $01, $00    ; alien A row 7: feet in
    .byte $00, $00, $01, $10, $01, $10, $00, $00    ; alien B row 0: antennae
    .byte $00, $00, $11, $11, $11, $11, $00, $00    ; alien B row 1
    .byte $00, $01, $11, $11, $11, $11, $10, $00    ; alien B row 2
    .byte $00, $11, $01, $11, $11, $01, $10, $00    ; alien B row 3: eyes
    .byte $00, $11, $11, $11, $11, $11, $10, $00    ; alien B row 4
    .byte $00, $01, $00, $01, $10, $00, $10, $00    ; alien B row 5: legs out
    .byte $00, $10, $10, $00, $00, $01, $01, $00    ; alien B row 6: legs out
    .byte $10, $00, $10, $00, $00, $00, $00, $10    ; alien B row 7: feet out
    .byte $22, $22, $22, $22, $22, $22, $22, $22    ; bullet: 8 rows of 1 byte, 2 white pixels

; XRAM address of each bitmap row, for the blitter.
row_lo:                                             ; low byte of each row's address
.repeat 240, I                                      ; one entry per canvas row
    .byte <(XRAM_BITMAP + I * (BITMAP_WIDTH_PX / 2)) ; row I starts at 160 bytes per row
.endrepeat                                          ; end of the row_lo table
row_hi:                                             ; high byte of each row's address
.repeat 240, I                                      ; one entry per canvas row
    .byte >(XRAM_BITMAP + I * (BITMAP_WIDTH_PX / 2)) ; high byte of the same address
.endrepeat                                          ; end of the row_hi table

.segment "BSS"                                      ; zero-initialized RAM for variables

player_u:      .res 1                               ; player x, in 2-pixel units
alien_u:       .res 1                               ; alien x, in 2-pixel units
alien_dir:     .res 1                               ; alien step per move: +4 or -4 (as $FC)
alien_frame:   .res 1                               ; 0 or 1: which alien sprite to draw
alien_alive:   .res 1                               ; 1 while the alien is on screen
alien_timer:   .res 1                               ; frames since the alien last moved
respawn_timer: .res 1                               ; frames left before a killed alien returns
bullet_active: .res 1                               ; 1 while a bullet is in flight
bullet_u:      .res 1                               ; bullet x, in 2-pixel units
bullet_y:      .res 1                               ; bullet top row, in pixels
bullet_timer:  .res 1                               ; frames since the bullet last moved
prev_space:    .res 1                               ; Space state last frame, to detect a new press
last_vsync:    .res 1                               ; VSYNC count at the last frame
score:         .res 2                               ; score, low byte then high byte
num:           .res 2                               ; working copy of the score while printing it
started:       .res 1                               ; 1 once a nonzero digit has printed
cur_row:       .res 1                               ; console row for the next output, 0-based
cur_col:       .res 1                               ; console column for the next output, 0-based
blit_src:      .res 2                               ; XRAM address of the source block
blit_w:        .res 1                               ; block width, in bytes
blit_h:        .res 1                               ; block height, in rows
blit_stride:   .res 1                               ; source advance per row; 0 erases
blit_x:        .res 1                               ; destination x, in 2-pixel units
blit_y:        .res 1                               ; destination top row, in pixels

.segment "CODE"                                     ; executable code goes in ROM

.macro PUT_STR label, len                           ; print len bytes of label to the console
    ldx #0                                          ; start at the first byte
:   lda label,x                                     ; load one byte of the text
    jsr tx_char                                     ; send it to the console
    inx                                             ; move to the next byte
    cpx #len                                        ; reached the end of the text?
    bne :-                                          ; no: keep going
.endmacro                                           ; end of PUT_STR

; Copies len bytes from ROM to XRAM at dest, through portal 0.
.macro UPLOAD dest, src, len                        ; copy len bytes from ROM label src to XRAM dest
    lda #<dest                                      ; low byte of the XRAM address
    sta RIA_ADDR0                                   ; set portal 0 address, low byte
    lda #>dest                                      ; high byte of the XRAM address
    sta RIA_ADDR0+1                                 ; set portal 0 address, high byte
    ldx #0                                          ; start at the first byte
:   lda src,x                                       ; read one byte from ROM
    sta RIA_RW0                                     ; write it to XRAM through portal 0
    inx                                             ; move to the next byte
    cpx #len                                        ; reached the end?
    bne :-                                          ; no: keep copying
.endmacro                                           ; end of UPLOAD

; Draws w bytes by h rows from the XRAM source at (x, y), in 2-pixel units
; and pixels. A stride of 0 repeats the first source byte, which erases.
.macro BLIT src, w, h, stride, xop, yop             ; blit src to bitmap at (xop, yop)
    lda #<src                                       ; low byte of the source address
    sta blit_src                                    ; store it for the blitter
    lda #>src                                       ; high byte of the source address
    sta blit_src+1                                  ; store it for the blitter
    lda #w                                          ; block width in bytes
    sta blit_w                                      ; store it for the blitter

    lda #h                                          ; block height in rows
    sta blit_h                                      ; store it for the blitter
    lda #stride                                     ; source advance per row (0 erases)
    sta blit_stride                                 ; store it for the blitter
    lda xop                                         ; destination x in 2-pixel units
    sta blit_x                                      ; store it for the blitter
    lda yop                                         ; destination top row in pixels
    sta blit_y                                      ; store it for the blitter
    jsr blit                                        ; copy the block
.endmacro                                           ; end of BLIT

; Entry point. The C runtime has already set the stack pointer and cleared
; decimal mode, and it halts the 6502 with the status we return.
_main:                                              ; program entry point
    xreg_ria_keyboard XRAM_KEYBOARD                 ; map the keyboard bitmap into XRAM
    lda #1                                          ; portal 0 step: advance one byte per access
    sta RIA_STEP0                                   ; set portal 0 step
    UPLOAD XRAM_PALETTE, palette_rom, 32            ; copy the 16-color palette into XRAM
    UPLOAD XRAM_PLAYER_SPRITE, sprite_rom, 200      ; copy all sprites into XRAM
    UPLOAD XRAM_BITMAP_CONFIG, bitmap_config_rom, 14 ; copy the Mode 3 config into XRAM

    lda #<XRAM_BLANK                                ; low byte of the zero-byte address
    sta RIA_ADDR0                                   ; point portal 0 at it, low byte
    lda #>XRAM_BLANK                                ; high byte of the zero-byte address
    sta RIA_ADDR0+1                                 ; point portal 0 at it, high byte
    lda #0                                          ; the zero value to store
    sta RIA_RW0                                     ; write the zero byte that erases use

; XRAM is not cleared at boot, so clear all 38400 bitmap bytes.
    lda #<XRAM_BITMAP                               ; low byte of the bitmap address
    sta RIA_ADDR0                                   ; point portal 0 at the bitmap, low byte
    lda #>XRAM_BITMAP                               ; high byte of the bitmap address
    sta RIA_ADDR0+1                                 ; point portal 0 at the bitmap, high byte
    lda #0                                          ; the value to clear with
    ldx #150                                        ; 150 pages of 256 bytes
@clear_page:                                        ; one page per pass
    ldy #0                                          ; 256 bytes per page
@clear:                                             ; one byte per pass
    sta RIA_RW0                                     ; write zero through portal 0
    dey                                             ; next byte in the page
    bne @clear                                      ; until the page is done
    dex                                             ; next page
    bne @clear_page                                 ; until all pages are cleared

    xreg_vga_canvas CANVAS_320X240                  ; select the 320x240 canvas

    xreg_vga_mode3 MODE3_4BPP, XRAM_BITMAP_CONFIG, 0, 0, 0 ; bitmap on plane 0, whole canvas
    xreg_vga_mode0 1, 0, 0                          ; console on plane 1, whole canvas

    lda #PLAYER_START_U                             ; starting player x
    sta player_u                                    ; store the player's x
    lda #ALIEN_START_U                              ; starting alien x
    sta alien_u                                     ; store the alien's x
    lda #ALIEN_STEP_U                               ; start moving right (+4)
    sta alien_dir                                   ; store the alien's direction
    lda #1                                          ; the alien starts alive
    sta alien_alive                                 ; store the alive flag
    lda #0                                          ; first animation frame
    sta alien_frame                                 ; store the animation frame
    sta alien_timer                                 ; clear the alien move timer
    sta respawn_timer                               ; clear the respawn timer
    sta bullet_active                               ; no bullet in flight yet
    sta bullet_timer                                ; clear the bullet move timer
    sta prev_space                                  ; Space was not held last frame
    sta score                                       ; clear the score low byte
    sta score+1                                     ; clear the score high byte

    lda #$0C                                        ; form feed clears the console
    jsr tx_char                                     ; send it
    jsr draw_score                                  ; draw the title and score
    lda #1                                          ; second row of the console
    sta cur_row                                     ; set the row
    lda #0                                          ; first column
    sta cur_col                                     ; set the column
    jsr goto_xy                                     ; move the cursor there
    PUT_STR str_help, str_help_len                  ; print the control hint
    jsr draw_alien                                  ; draw the alien
    jsr draw_player                                 ; draw the player
    lda RIA_VSYNC                                   ; read the current VSYNC count
    sta last_vsync                                  ; remember it as the last frame

main_loop:                                          ; one pass per video frame
    lda RIA_VSYNC                                   ; read the current VSYNC count
    cmp last_vsync                                  ; has a new frame started?
    beq main_loop                                   ; no: keep waiting
    sta last_vsync                                  ; yes: remember this frame

    lda #HID_KEY_A                                  ; check the A key
    jsr key_held                                    ; is it held?
    bne @left                                       ; yes: move left
    lda #HID_KEY_ARROW_LEFT                         ; check the left arrow
    jsr key_held                                    ; is it held?
    bne @left                                       ; yes: move left
    lda #HID_KEY_D                                  ; check the D key
    jsr key_held                                    ; is it held?
    bne @right                                      ; yes: move right
    lda #HID_KEY_ARROW_RIGHT                        ; check the right arrow
    jsr key_held                                    ; is it held?
    beq @fire                                       ; no: no movement this frame
@right:                                             ; move the player right
    jsr move_right                                  ; shift the ship right
    jmp @fire                                       ; continue to firing
@left:                                              ; move the player left
    jsr move_left                                   ; shift the ship left
@fire:                                              ; handle the Space key
    lda #HID_KEY_SPACE                              ; check the Space key
    jsr key_held                                    ; is it held?
    pha                                             ; keep the state for next frame
    beq @no_fire                                    ; not held: no shot
    lda prev_space                                  ; was Space held last frame?
    bne @no_fire                                    ; yes: wait for a new press
    lda bullet_active                               ; is a bullet already in flight?
    bne @no_fire                                    ; yes: only one at a time
    jsr fire_bullet                                 ; start a new bullet
@no_fire:                                           ; end of the Space check
    pla                                             ; restore this frame's Space state
    sta prev_space                                  ; remember it for next frame
    jsr update_bullet                               ; move the bullet
    jsr update_alien                                ; move the alien
    jmp main_loop                                   ; next frame

; Writes the byte in A to the console when the UART is ready.
tx_char:                                            ; send one byte to the console
@wait:                                              ; wait until the UART can take a byte
    bit RIA_READY                                   ; N flag = TX ready
    bpl @wait                                       ; not ready yet: keep waiting
    sta RIA_TX                                      ; send the byte
    rts                                             ; return to the caller

; Prints A (0-99) in decimal.
put_dec:                                            ; print a small number in decimal
    ldx #0                                          ; tens counter starts at zero
@tens:                                              ; count tens by subtracting 10
    cmp #10                                         ; at least 10 left?
    bcc @ones                                       ; no: the rest is the ones digit
    sbc #10                                         ; remove one ten (carry is set here)
    inx                                             ; count it
    bne @tens                                       ; go around again
@ones:                                              ; A is the ones digit
    pha                                             ; save the ones digit
    txa                                             ; the tens count
    beq @digit                                      ; zero tens: skip printing them
    ora #'0'                                        ; turn the tens count into ASCII
    jsr tx_char                                     ; print the tens digit
@digit:                                             ; print the ones digit
    pla                                             ; restore the ones digit
    ora #'0'                                        ; turn it into ASCII
    jmp tx_char                                     ; print it and return

; Moves the console cursor to cur_row, cur_col (0-based).
goto_xy:                                            ; send ESC [ row ; col H
    lda #$1B                                        ; ESC
    jsr tx_char                                     ; send it
    lda #'['                                        ; the CSI bracket
    jsr tx_char                                     ; send it
    lda cur_row                                     ; the 0-based row
    clc                                             ; prepare to add
    adc #1                                          ; terminal rows start at 1
    jsr put_dec                                     ; send the row number
    lda #';'                                        ; the separator
    jsr tx_char                                     ; send it
    lda cur_col                                     ; the 0-based column
    clc                                             ; prepare to add
    adc #1                                          ; terminal columns start at 1
    jsr put_dec                                     ; send the column number
    lda #'H'                                        ; the cursor-position command
    jmp tx_char                                     ; send it and return

; Returns A = 1 if the HID key in A is held, else 0. Reads the keyboard
; bitmap through portal 0, since XRAM is not in the 6502 address space.
key_held:                                           ; test one key in the keyboard bitmap
    tax                                             ; keep the key code in X
    lsr a                                           ; divide by 8 to find the byte
    lsr a                                           ; second shift
    lsr a                                           ; third shift: byte offset in A
    clc                                             ; prepare to add the base address
    adc #<XRAM_KEYBOARD                             ; low byte of the keyboard address
    sta RIA_ADDR0                                   ; point portal 0 at the byte, low
    lda #>XRAM_KEYBOARD                             ; high byte of the keyboard address
    adc #0                                          ; add the carry from the low byte
    sta RIA_ADDR0+1                                 ; point portal 0 at the byte, high
    txa                                             ; get the key code back
    and #7                                          ; the bit within the byte
    tax                                             ; use it as the shift count
    lda RIA_RW0                                     ; read the keyboard byte through portal 0
    cpx #0                                          ; bit 0: no shifting needed
    beq @mask                                       ; go straight to the mask
@shift:                                             ; move the wanted bit to bit 0
    lsr a                                           ; shift right one bit
    dex                                             ; one fewer shift to do
    bne @shift                                      ; until the bit is in place
@mask:                                              ; keep only the wanted bit
    and #1                                          ; A = 1 if held, 0 if not
    rts                                             ; return with the flags set

draw_score:                                         ; redraw the title and score on the first row
    lda #0                                          ; row 0
    sta cur_row                                     ; set the row
    sta cur_col                                     ; column 0
    jsr goto_xy                                     ; move the cursor there
    PUT_STR str_title, str_title_len                ; print the title
    jmp print_score                                 ; print the score digits

; Prints score as decimal with no leading zeros, at least one digit.
print_score:                                        ; print the 16-bit score as decimal
    lda score                                       ; low byte of the score
    sta num                                         ; copy it, since subtraction changes it
    lda score+1                                     ; high byte of the score
    sta num+1                                       ; copy it too
    lda #0                                          ; no digit printed yet
    sta started                                     ; clear the started flag
    ldx #0                                          ; start with the largest place value
@next:                                              ; one decimal digit per pass
    ldy #0                                          ; digit count for this place
@sub:                                               ; subtract this place value while it fits
    lda num+1                                       ; high byte of the remaining value
    cmp div_hi,x                                    ; compare with the place value's high byte
    bcc @emit                                       ; smaller: this digit is done
    bne @do                                         ; larger: subtract it
    lda num                                         ; high bytes equal: compare the low bytes
    cmp div_lo,x                                    ; compare with the place value's low byte
    bcc @emit                                       ; smaller: this digit is done
@do:                                                ; subtract one place value
    lda num                                         ; low byte of the remaining value
    sec                                             ; set carry for subtraction
    sbc div_lo,x                                    ; subtract the place value's low byte
    sta num                                         ; store the new low byte
    lda num+1                                       ; high byte of the remaining value
    sbc div_hi,x                                    ; subtract with borrow
    sta num+1                                       ; store the new high byte
    iny                                             ; count one more of this digit
    jmp @sub                                        ; try again at this place
@emit:                                              ; print this digit if it is needed
    tya                                             ; the digit value
    bne @print                                      ; nonzero: always print
    cpx #4                                          ; the ones place: always print
    beq @print                                      ; yes: print even a zero
    lda started                                     ; has anything been printed yet?
    beq @skip                                       ; no: skip this leading zero
@print:                                             ; print the digit
    lda #1                                          ; mark that a digit has printed
    sta started                                     ; store the flag
    tya                                             ; the digit value
    ora #'0'                                        ; turn it into ASCII
    jsr tx_char                                     ; print it
@skip:                                              ; move to the next place value
    inx                                             ; next smaller place value
    cpx #5                                          ; all five places done?
    bne @next                                       ; no: do the next digit
    rts                                             ; return

; Copies the sprite block from XRAM to the bitmap, row by row, through the
; two portals. Portal 1 reads blit_src, advancing by blit_stride per row.
blit:                                               ; copy a block from XRAM to the bitmap
    lda #1                                          ; portal 0 advances one byte per write
    sta RIA_STEP0                                   ; set portal 0's step
    lda #1                                          ; assume a nonzero stride
    ldx blit_stride                                 ; test the stride
    bne :+                                          ; nonzero: portal 1 steps by 1
    lda #0                                          ; zero stride: portal 1 stays put
:   sta RIA_STEP1                                   ; set portal 1's step
@row:                                               ; one row of the block per pass
    ldx blit_y                                      ; the destination row
    lda row_lo,x                                    ; low byte of that bitmap row's address
    clc                                             ; prepare to add the x offset
    adc blit_x                                      ; add the x offset in bytes
    sta RIA_ADDR0                                   ; point portal 0 at the destination, low
    lda row_hi,x                                    ; high byte of that row's address
    adc #0                                          ; add the carry from the low byte
    sta RIA_ADDR0+1                                 ; point portal 0 at the destination, high
    lda blit_src                                    ; low byte of the source address
    sta RIA_ADDR1                                   ; point portal 1 at the source, low
    lda blit_src+1                                  ; high byte of the source address
    sta RIA_ADDR1+1                                 ; point portal 1 at the source, high
    ldx blit_w                                      ; bytes to copy in this row
@copy:                                              ; copy one byte per pass
    lda RIA_RW1                                     ; read a source byte through portal 1
    sta RIA_RW0                                     ; write it to the bitmap through portal 0
    dex                                             ; one byte done
    bne @copy                                       ; until the row is done
    lda blit_src                                    ; low byte of the source address
    clc                                             ; prepare to add the stride
    adc blit_stride                                 ; advance to the next source row
    sta blit_src                                    ; store the low byte
    lda blit_src+1                                  ; high byte of the source address
    adc #0                                          ; add the carry from the low byte
    sta blit_src+1                                  ; store the high byte
    inc blit_y                                      ; next destination row
    dec blit_h                                      ; one fewer row to copy
    bne @row                                        ; until all rows are copied
    rts                                             ; return

draw_alien:                                         ; draw the alien if it is alive
    lda alien_alive                                 ; is the alien alive?
    beq @done                                       ; no: draw nothing
    lda alien_frame                                 ; which animation frame?
    bne @frame1                                     ; frame 1: draw the second sprite
    BLIT XRAM_ALIEN_A_SPRITE, 8, 8, 8, alien_u, #ALIEN_PY ; draw frame A
    rts                                             ; return
@frame1:                                            ; frame B
    BLIT XRAM_ALIEN_B_SPRITE, 8, 8, 8, alien_u, #ALIEN_PY ; draw frame B
@done:                                              ; common exit
    rts                                             ; return

draw_player:                                        ; draw the player ship
    BLIT XRAM_PLAYER_SPRITE, 8, 8, 8, player_u, #PLAYER_PY ; draw the ship
    rts                                             ; return

move_left:                                          ; move the ship two units left, if there is room
    lda player_u                                    ; current x
    cmp #PLAYER_MIN_U+2                             ; room to move left?
    bcc @no                                         ; no: stay put
    BLIT XRAM_BLANK, 8, 8, 0, player_u, #PLAYER_PY  ; erase the ship at its old position
    lda player_u                                    ; current x
    sec                                             ; set carry for subtraction
    sbc #2                                          ; move two units (4 px) left
    sta player_u                                    ; store the new x
    jmp draw_player                                 ; draw it at the new position
@no:                                                ; at the left edge
    rts                                             ; return

move_right:                                         ; move the ship two units right, if there is room
    lda player_u                                    ; current x
    cmp #PLAYER_MAX_U                               ; room to move right?
    bcs @no                                         ; no: stay put
    BLIT XRAM_BLANK, 8, 8, 0, player_u, #PLAYER_PY  ; erase the ship at its old position
    lda player_u                                    ; current x
    clc                                             ; prepare to add
    adc #2                                          ; move two units (4 px) right
    sta player_u                                    ; store the new x
    jmp draw_player                                 ; draw it at the new position
@no:                                                ; at the right edge
    rts                                             ; return

fire_bullet:                                        ; start a bullet at the ship's center
    lda player_u                                    ; the ship's x
    clc                                             ; prepare to add
    adc #4                                          ; center the bullet on the 16-px ship
    sta bullet_u                                    ; store the bullet x
    lda #PLAYER_PY-BULLET_STEP_PX                   ; one step above the ship
    sta bullet_y                                    ; store the bullet's row
    lda #0                                          ; no frames yet
    sta bullet_timer                                ; reset the bullet timer
    lda #1                                          ; the bullet is now in flight
    sta bullet_active                               ; set the active flag
    BLIT XRAM_BULLET_SPRITE, 1, 8, 1, bullet_u, bullet_y ; draw the bullet
    rts                                             ; return

update_bullet:                                      ; move the bullet and check for a hit
    lda bullet_active                               ; is a bullet in flight?
    bne @active                                     ; yes: update it
    rts                                             ; no: nothing to do
@active:                                            ; the bullet is in flight
    inc bullet_timer                                ; count a frame
    lda bullet_timer                                ; the frame count
    cmp #BULLET_STEP_FRAMES                         ; time to move?
    bcs @step                                       ; yes: move it
    rts                                             ; no: wait another frame
@step:                                              ; move the bullet one step
    lda #0                                          ; restart the timer
    sta bullet_timer                                ; store it
    BLIT XRAM_BLANK, 1, 8, 0, bullet_u, bullet_y    ; erase the bullet at its old position
    lda bullet_y                                    ; the bullet's row
    cmp #BULLET_STEP_PX                             ; room to move up one step?
    bcs @advance                                    ; yes: move it
    lda #0                                          ; no: the bullet left the top of the screen
    sta bullet_active                               ; mark it as gone
    rts                                             ; return
@advance:                                           ; move the bullet up
    lda bullet_y                                    ; the bullet's row
    sec                                             ; set carry for subtraction
    sbc #BULLET_STEP_PX                             ; move up one step
    sta bullet_y                                    ; store the new row
    lda alien_alive                                 ; is there an alien to hit?
    beq @draw                                       ; no: just draw the bullet
    lda bullet_y                                    ; the new row
    cmp #ALIEN_PY+8                                 ; has the bullet reached the alien's row?
    bcs @draw                                       ; no: keep flying
    lda bullet_u                                    ; the bullet's x
    cmp alien_u                                     ; left of the alien?
    bcc @draw                                       ; yes: a miss
    sec                                             ; set carry for subtraction
    sbc alien_u                                     ; distance from the alien's left edge
    cmp #8                                          ; within the 8-unit (16 px) width?
    bcs @draw                                       ; no: a miss
    BLIT XRAM_BLANK, 8, 8, 0, alien_u, #ALIEN_PY    ; erase the alien: it is hit
    lda #0                                          ; the alien is no longer alive
    sta alien_alive                                 ; store the flag
    lda #ALIEN_RESPAWN_FRAMES                       ; wait this long before it returns
    sta respawn_timer                               ; store the timer
    inc score                                       ; add one to the score
    bne @score_done                                 ; no carry out of the low byte: done
    inc score+1                                     ; carry into the high byte
@score_done:                                        ; score is updated
    jsr draw_score                                  ; redraw the score
    lda #0                                          ; the bullet is spent
    sta bullet_active                               ; mark it as gone
    rts                                             ; return
@draw:                                              ; the bullet keeps flying
    BLIT XRAM_BULLET_SPRITE, 1, 8, 1, bullet_u, bullet_y ; draw it at its new position
    rts                                             ; return

update_alien:                                       ; move the alien, or count down its respawn
    inc alien_timer                                 ; count a frame
    lda alien_timer                                 ; the frame count
    cmp #ALIEN_STEP_FRAMES                          ; time to move?
    bcs @tick                                       ; yes: move it
    rts                                             ; no: wait
@tick:                                              ; a move is due
    lda #0                                          ; restart the timer
    sta alien_timer                                 ; store it
    lda alien_alive                                 ; is the alien on screen?
    bne @march                                      ; yes: march it
    lda respawn_timer                               ; the respawn countdown
    bne @count                                      ; not finished: count down
    lda #1                                          ; respawn time: the alien comes back alive
    sta alien_alive                                 ; store the flag
    lda #ALIEN_START_U                              ; back to the starting x
    sta alien_u                                     ; store it
    lda #ALIEN_STEP_U                               ; start moving right
    sta alien_dir                                   ; store the direction
    jmp draw_alien                                  ; draw the returned alien
@count:                                             ; the alien is still away
    dec respawn_timer                               ; one frame closer to returning
    rts                                             ; return
@march:                                             ; move the living alien
    BLIT XRAM_BLANK, 8, 8, 0, alien_u, #ALIEN_PY    ; erase it at its old position
    lda alien_frame                                 ; current animation frame
    eor #1                                          ; flip between 0 and 1
    sta alien_frame                                 ; store the new frame
    lda alien_u                                     ; current x
    cmp #ALIEN_MIN_U                                ; at the left edge?
    bne @check_max                                  ; no: check the right edge
    lda #ALIEN_STEP_U                               ; at the left edge: turn right
    sta alien_dir                                   ; store the direction
    jmp @step                                       ; then move
@check_max:                                         ; not at the left edge
    cmp #ALIEN_MAX_U                                ; at the right edge?
    bne @step                                       ; no: keep the direction
    lda #256-ALIEN_STEP_U                           ; at the right edge: turn left (-4)
    sta alien_dir                                   ; store the direction
@step:                                              ; move by the direction
    lda alien_u                                     ; current x
    clc                                             ; prepare to add
    adc alien_dir                                   ; add the step (may be negative)
    sta alien_u                                     ; store the new x
    jmp draw_alien                                  ; draw it at the new position
