; movement.asm
; Milestone 4: Keyboard input and player movement.
; Move the player cannon left/right within the screen using the
; keyboard, erasing the old position and redrawing at the new one each
; time a move happens.

        * = $6000               ; load address for this DOS 3.3 BIN file

; --- Soft switches ---
TXTCLR  = $C050         ; enable graphics mode (clears the "text" flag)
TXTSET  = $C051         ; enable text mode
MIXCLR  = $C052         ; full-screen graphics (no reserved text lines)
MIXSET  = $C053         ; mixed mode (bottom 4 lines stay text)
LOWSCR  = $C054         ; display page 1
HISCR   = $C055         ; display page 2
LORES   = $C056         ; select lo-res graphics
HIRES   = $C057         ; select hi-res graphics

KBD     = $C000         ; keyboard data (bit 7 set = key waiting)
KBDSTRB = $C010         ; clear keyboard strobe

; Key codes: Apple II keyboard returns ASCII with the high bit set.
; 'A' = $C1, 'D' = $C4 (letters, high bit set). If you'd rather use
; arrow keys instead: Left = $88, Right = $95.
KEY_LEFT  = $C1         ; 'A' (or use arrows: Left = $88, Right = $95)
KEY_RIGHT = $C4         ; 'D'
KEY_LEFT_ARROW  = $88   ; left arrow key
KEY_RIGHT_ARROW = $95   ; right arrow key
KEY_SPACE = $A0         ; space bar

HGR_PAGE1 = $2000       ; start of hi-res page 1 ($2000-$3FFF, 8K)

; zero-page pointer used to address into hi-res memory.
HGR_PTR = $06           ; HGR_PTR = low byte, HGR_PTR+1 = high byte
ROW_TMP = $08           ; scratch byte used only inside calc_row_ptr
SPRITE_ROW = $09        ; current row of the sprite being drawn/erased

; PLAYER_COL is now a variable (not a constant like in M3) - it changes
; every time the player moves, so it has to live in memory, not be
; baked into the code at assemble time.
PLAYER_COL = $0A        ; current column byte (0-39) for the sprite
BULLET_ROW = $0B        ; current row of the bullet being drawn/erased
BULLET_COL = $0C        ; current column of the bullet being drawn/erased
BULLET_ACTIVE = $0D     ; flag indicating if the bullet is currently active (1 = active, 0 = inactive)
CNT = $0E               ; general-purpose counter for delays or loops
ICNT = $0F              ; inner loop counter for nested delays
ALIEN_ANIM_FRAME = $10  ; 0 or 1
ALIEN_DIRECTION = $11   ; 1=right, $FF=left
ALIEN_ANIM_TIMER = $12  ; counts down between animation frame swaps

; --- Sprite position ---
PLAYER_ROW = 176        ; fixed screen row (0-191) for the sprite's top -
                        ; adjust if you want it higher/lower
PLAYER_COL_START = 16   ; starting column (0-39) - roughly centered
ALIEN_START_ROW = 16   ; fixed screen row (0-191) for the alien's top
ALIEN_START_COL = 29   ; fixed test column (0-39) for the alien
ALIEN_DRAW_DELAY = $40 ; starting/reset value for ALIEN_ANIM_TIMER

start:
        sta TXTCLR              ; switch on graphics mode
        sta MIXCLR              ; use the full screen (no reserved text lines)
        sta HIRES               ; select hi-res (vs. lo-res) graphics
        sta LOWSCR              ; display page 1 (vs. page 2)

; init variables
        lda #$00                ; 0 = first animation frame
        sta ALIEN_ANIM_FRAME
        lda #$01                ; 1 = moving right
        sta ALIEN_DIRECTION
        lda #ALIEN_DRAW_DELAY   ; start the countdown at a full period
        sta ALIEN_ANIM_TIMER

; --- Clear the whole 8K hi-res page ($2000-$3FFF) to black ---
cls:
        ldx #$20                ; X = current page's high byte, starts at $20
        lda #$00                ; A = the byte value we're clearing memory to
        sta HGR_PTR             ; pointer's low byte is always $00 (page-aligned)
clr_highbyte:
        stx HGR_PTR+1           ; pointer's high byte = current page (X)
        ldy #$00                ; Y = inner loop's byte offset, reset each pass
clr_lowbyte:
        sta (HGR_PTR), y        ; store 0 at (pointer + Y)
        iny                     ; move to the next byte in this page
        bne clr_lowbyte         ; loop until Y wraps 255 -> 0 (256 bytes done)
        inx                     ; move to the next page
        cpx #$40                ; have we just passed page $3F (last page)?
        bne clr_highbyte        ; if not, clear the next page

        lda #PLAYER_COL_START
        sta PLAYER_COL
        jsr draw_sprite         ; draw the sprite once so it's visible before the first keypress.
        jsr draw_alien           ; draw the alien sprite initially

        lda #$00
        sta BULLET_ACTIVE       ; ensure the bullet is inactive at the start


; --- Main loop: poll the keyboard, advance/redraw the bullet, move and
; redraw the player on left/right ---
main_loop:
        ; Advance the alien animation timer every pass (bullet-active or
        ; not) - see bullet_gone's jsr delay, which paces this loop so the
        ; countdown happens in real time, not raw CPU speed.
        dec ALIEN_ANIM_TIMER
        bne skip_alien_animation ; timer hasn't hit 0 yet, skip the toggle
alien_animation:
        lda ALIEN_ANIM_FRAME     ; A = current frame (0 or 1)
        eor #$01                 ; flip 0<->1
        sta ALIEN_ANIM_FRAME
        lda #ALIEN_DRAW_DELAY    ; reset the timer to a full period
        sta ALIEN_ANIM_TIMER
        jsr erase_alien          ; blank the CURRENT frame's shape
        jsr draw_alien           ; redraw using the NEW frame's shape
skip_alien_animation:
        lda BULLET_ACTIVE       ; A = current bullet-active flag
        beq bullet_gone         ; 0 means no bullet in flight, skip movement
        jsr erase_bullet        ; blank the bullet at its current position
        ; move 5 rows/frame - scaled from the arcade original's 6px on a
        ; 256px-tall screen: 192 * 6/256 = 4.5, rounded to 5.
        lda BULLET_ROW          ; A = current bullet row
        cmp #$05                ; compare against the step size
        bcc bullet_gone         ; if BULLET_ROW < 5, can't subtract 5 safely
        sec                     ; prepare for subtraction
        sbc #$05                ; A = BULLET_ROW - 5
        sta BULLET_ROW          ; store the bullet's new row
        jsr draw_bullet         ; redraw the bullet at its new row
        jsr delay               ; add a frame delay after drawing the bullet
        jmp poll_keys          ; after handling the bullet, poll the keys
bullet_gone:
        lda #$00                ; 0 = inactive
        sta BULLET_ACTIVE       ; mark the bullet as inactive
        jsr delay               ; pace this pass so ALIEN_ANIM_TIMER counts down in real time
poll_keys:
        lda KBD                 ; A = keyboard data (bit 7 set = key waiting)
        bpl main_loop           ; if not, loop back immediately
        sta KBDSTRB             ; clear the strobe
        cmp #KEY_SPACE           ; then compare the key against KEY_SPACE
        beq handle_space        ; if space key, handle it
        cmp #KEY_LEFT           ; then compare the key against KEY_LEFT 
        beq handle_left
        cmp #KEY_LEFT_ARROW     ; also accept the left arrow key
        beq handle_left         ; either key moves the ship left
        cmp #KEY_RIGHT
        beq handle_right        ; KEY_RIGHT. 
        cmp #KEY_RIGHT_ARROW    ; also accept the right arrow key
        beq handle_right        ; either key moves the ship right
        jmp main_loop           ; if no recognized key, loop back immediately
handle_space:
        lda BULLET_ACTIVE       ; A = current bullet-active flag
        bne main_loop           ; if bullet is already active, loop back immediately
        lda #$01                ; 1 = active
        sta BULLET_ACTIVE       ; mark the bullet as active
        ; BULLET_COL is the LEFT of the bullet's two byte-columns, mirroring
        ; PLAYER_COL - draw_bullet writes bit 6 here and bit 0 at BULLET_COL+1,
        ; the same two seam pixels the cannon's tip uses.
        lda PLAYER_COL          ; A = ship's current left byte-column
        sta BULLET_COL          ; store the bullet's starting column
        lda #PLAYER_ROW         ; A = the ship's fixed top row (176)
        sec                     ; prepare for subtraction
        sbc #$01                ; A = one row above the ship's top
        sta BULLET_ROW          ; store the bullet's starting row
        jsr draw_bullet          ; draw the bullet at its starting position
        jmp main_loop           ; after handling, loop back immediately
handle_left:
        lda PLAYER_COL          ; A = ship's current left byte-column
        cmp #$00            ; compare with 0 to clamp the lower boundo
        beq main_loop       ; if PLAYER_COL is 0, can't move left, loop back immediately
        jsr erase_sprite    ;   1. jsr erase_sprite (erase the sprite at its CURRENT column)
        dec PLAYER_COL      ;   2. update PLAYER_COL (dec for left, inc for right)
        jsr draw_sprite     ; draw the sprite at its NEW column
        jmp main_loop; Either way, loop back to main_loop when done.

handle_right:
        lda PLAYER_COL      ; A = ship's current left byte-column
        cmp #$26            ; compare with 38 (0x26) to clamp the upper bound
        bne handle_right_move ; if PLAYER_COL isn't 38, go ahead and move
        jmp main_loop       ; PLAYER_COL is 38, can't move right, loop back immediately
handle_right_move:
        jsr erase_sprite    ;   1. jsr erase_sprite (erase the sprite at its CURRENT column)
        inc PLAYER_COL      ;   2. update PLAYER_COL (dec for left, inc for right)
        jsr draw_sprite     ; draw the sprite at its NEW column
        jmp main_loop

; --- Draw the player sprite ---
; SPRITE_ROW (zero page) is the loop counter: it's the sprite's own row
; number (0..PLAYER_SPRITE_ROWS-1), used both to compute PLAYER_ROW +
; SPRITE_ROW for calc_row_ptr and to index player_sprite. It has to live
; in memory rather than a register because calc_row_ptr uses X
; internally and would clobber a register-based counter. Y is reloaded
; from PLAYER_COL each call - it's just where in the row we store, not
; a loop counter, but it's a variable now instead of a constant.
draw_sprite:
        ldy PLAYER_COL          ; Y = current column offset for every row
        lda #$00                ; start counting from row 0
        sta SPRITE_ROW          ; start at sprite row 0
plot_row:
        lda SPRITE_ROW          ; A = current sprite row number
        clc
        adc #PLAYER_ROW         ; A = absolute screen row = PLAYER_ROW + SPRITE_ROW
        jsr calc_row_ptr        ; compute HGR_PTR for that row (clobbers X)
        ldx SPRITE_ROW          ; reload X - calc_row_ptr just clobbered it
        lda player_sprite_left, x    ; load the sprite byte for this row
        ldy PLAYER_COL          ; Y = current column offset for every row
        sta (HGR_PTR), y        ; store it at (pointer + PLAYER_COL)
        lda player_sprite_right, x    ; load the sprite byte for this row
        iny                     ; move to the next column for the right sprite
        sta (HGR_PTR), y        ; store the right sprite byte at (pointer + PLAYER_COL)
        inc SPRITE_ROW          ; move to the next sprite row
        ldx SPRITE_ROW          ; reload the (now incremented) row number
        cpx #PLAYER_SPRITE_ROWS ; have we written all sprite rows?
        bne plot_row            ; if not, plot the next row
        rts

draw_alien:
        ; ALIEN_ANIM_FRAME selects which pair of tables to read per byte -
        ; see the branches inside plot_alien_row below.
        ldy #ALIEN_START_COL          ; Y = current column offset for the alien sprite
        lda #$00                ; start counting from row 0
        sta SPRITE_ROW          ; start at sprite row 0
plot_alien_row:
        lda SPRITE_ROW          ; A = current sprite row number
        clc
        adc #ALIEN_START_ROW    ; A = absolute screen row = ALIEN_START_ROW + SPRITE_ROW
        jsr calc_row_ptr        ; compute HGR_PTR for that row (clobbers X)
        ldx SPRITE_ROW          ; reload X - calc_row_ptr just clobbered it
        lda ALIEN_ANIM_FRAME    ; A = current frame (0 or 1)
        bne use_alien2_left     ; nonzero -> use alien2's shape
        lda squid1_left, x      ; load the sprite byte for this row
        jmp got_left
use_alien2_left:
        lda squid2_left, x      ; load the sprite byte for this row
got_left:
        ldy #ALIEN_START_COL    ; Y = current column offset for the alien sprite
        sta (HGR_PTR), y        ; store it at (pointer + ALIEN_START_COL)
        lda ALIEN_ANIM_FRAME    ; A = current frame (0 or 1)
        bne use_alien2_right    ; nonzero -> use alien2's shape
        lda squid1_right, x     ; load the sprite byte for this row
        jmp got_right
use_alien2_right:
        lda squid2_right, x     ; load the sprite byte for this row
got_right:
        iny                     ; move to the next column for the right sprite
        sta (HGR_PTR), y        ; store the right sprite byte at (pointer + ALIEN_START_COL)
        inc SPRITE_ROW          ; move to the next sprite row
        ldx SPRITE_ROW          ; reload the (now incremented) row number
        cpx #ALIEN_SPRITE_ROWS  ; have we written all sprite rows?
        bne plot_alien_row      ; if not, plot the next row
        rts

; --- Erase the player sprite ---
; Same addressing as draw_sprite, but stores $00 instead of the sprite's
; byte - this paints over the sprite with black.
erase_sprite:
        ldy PLAYER_COL          ; Y = current column offset for every row
        lda #$00                ; start counting from row 0
        sta SPRITE_ROW          ; start at sprite row 0
del_row:
        lda SPRITE_ROW          ; A = current sprite row number
        clc
        adc #PLAYER_ROW         ; A = absolute screen row = PLAYER_ROW + SPRITE_ROW
        jsr calc_row_ptr        ; compute HGR_PTR for that row (clobbers X)
        lda #$00                ; blank byte (all pixels off)
        ldy PLAYER_COL          ; Y = current column offset for every row
        sta (HGR_PTR), y        ; store it at (pointer + PLAYER_COL)
        iny
        sta (HGR_PTR), y        ; store the blank byte for the right sprite at (pointer + PLAYER_COL)
        inc SPRITE_ROW          ; move to the next sprite row
        ldx SPRITE_ROW          ; reload the (now incremented) row number
        cpx #PLAYER_SPRITE_ROWS ; have we written all sprite rows?
        bne del_row             ; if not, erase the next row
        rts

; --- Erase the alien sprite ---
; Same addressing as draw_alien, but stores $00 instead of the sprite's
; byte - this paints over the sprite with black.
erase_alien:
        ldy #ALIEN_START_COL          ; Y = current column offset for every row
        lda #$00                ; start counting from row 0
        sta SPRITE_ROW          ; start at sprite row 0
del_alien_row:
        lda SPRITE_ROW          ; A = current sprite row number
        clc
        adc #ALIEN_START_ROW    ; A = absolute screen row = ALIEN_START_ROW + SPRITE_ROW
        jsr calc_row_ptr        ; compute HGR_PTR for that row (clobbers X)
        lda #$00                ; blank byte (all pixels off)
        ldy #ALIEN_START_COL          ; Y = current column offset for every row
        sta (HGR_PTR), y        ; store it at (pointer + ALIEN_START_COL)
        iny
        sta (HGR_PTR), y        ; store the blank byte for the right sprite at (pointer + ALIEN_START_COL)
        inc SPRITE_ROW          ; move to the next sprite row
        ldx SPRITE_ROW          ; reload the (now incremented) row number
        cpx #ALIEN_SPRITE_ROWS ; have we written all sprite rows?
        bne del_alien_row       ; if not, erase the next row
        rts

; delay approximates one 60Hz frame (~16.67ms). Each inner_delay pass
; (dec/bne) costs ~5 cycles, so 13 outer * 256 inner ~ 3,328 iterations.
delay:
        lda #$0D                ; load the outer loop counter with a large value
        sta CNT                 ; CNT = outer loop counter
outer_delay:
        lda #$00                ; load the inner loop counter with 0 (will wrap to 256)
        sta ICNT                ; ICNT = inner loop counter
inner_delay:
        dec ICNT                ; count the inner loop down
        bne inner_delay         ; loop until ICNT wraps to 0 (256 iterations)
        dec CNT                 ; one outer iteration done
        bne outer_delay         ; loop until CNT reaches 0
        rts


; --- Draw the bullet ---
; Two bytes wide, one row - straddles the same seam as the cannon's tip.
draw_bullet:
        lda BULLET_ROW          ; A = the bullet's current row
        jsr calc_row_ptr        ; compute HGR_PTR for the bullet's row (clobbers X)
        ldy BULLET_COL          ; Y = current column offset for the bullet
        lda #$40                ; bit 6 - rightmost pixel of the left byte
        sta (HGR_PTR), y        ; store it at (pointer + BULLET_COL)
        iny                     ; move to the right byte-column, BULLET_COL+1
        lda #$01                ; bit 0 - leftmost pixel of the right byte
        sta (HGR_PTR), y        ; store it at (pointer + BULLET_COL + 1)
        rts

; --- Erase the bullet ---
; Same two-byte addressing as draw_bullet, but stores $00 to blank both
; bullet pixels.
erase_bullet:
        lda BULLET_ROW          ; A = the bullet's current row
        jsr calc_row_ptr        ; compute HGR_PTR for the bullet's row (clobbers X)
        ldy BULLET_COL          ; Y = current column offset for the bullet
        lda #$00                ; blank byte (all pixels off)
        sta (HGR_PTR), y        ; blank the left byte-column
        iny                     ; move to the right byte-column, BULLET_COL+1
        sta (HGR_PTR), y        ; blank the right byte-column
        rts

; --- Player sprite shape ---
player_sprite_left:
        .byte $00               ; .......
        .byte $40               ; #......
        .byte $60               ; ##.....
        .byte $78               ; ####...
        .byte $7E               ; ######.
        .byte $7F               ; #######
        .byte $77               ; ###.###
        .byte $03               ; .....##
PLAYER_SPRITE_ROWS = * - player_sprite_left  ; number of rows, computed from the table above

player_sprite_right:
        .byte $01               ; ......#
        .byte $01               ; ......#
        .byte $03               ; .....##
        .byte $0F               ; ...####
        .byte $3F               ; .######
        .byte $7F               ; #######
        .byte $77               ; ###.###
        .byte $60               ; ##.....

squid1_left:
        .byte $40               ; ......#
        .byte $60               ; .....##
        .byte $58               ; ...##.#
        .byte $7C               ; ..#####
        .byte $7E               ; .######
        .byte $18               ; ....##.
        .byte $58               ; ...##.#
        .byte $0C               ; ..##...

ALIEN_SPRITE_ROWS = * - squid1_left  ; number of rows, computed from the table above

squid1_right:
        .byte $01               ; #......
        .byte $03               ; ##.....
        .byte $1A               ; #.##...
        .byte $1F               ; #####..
        .byte $3F               ; ######.
        .byte $06               ; .##....
        .byte $1A               ; #.##...
        .byte $30               ; ...##..

squid2_left:
        .byte $40               ; ......#
        .byte $58               ; ...##.#
        .byte $7E               ; .######
        .byte $7B               ; ##.####
        .byte $7F               ; #######
        .byte $5F               ; ####.##
        .byte $7F               ; #######
        .byte $2E               ; .###.#.
        .byte $7F               ; #######
        .byte $18               ; ...##..
        .byte $36               ; ..##.##
        .byte $03               ; ##.....

squid2_right:
        .byte $01               ; #......
        .byte $1A               ; #.##...
        .byte $3F               ; ######.
        .byte $6F               ; ####.##
        .byte $7F               ; #######
        .byte $7A               ; ##.####
        .byte $7F               ; #######
        .byte $3A               ; .#.###.
        .byte $7F               ; #######
        .byte $0C               ; ..##...
        .byte $36               ; ##.##..
        .byte $60               ; .....##



crab1_left:
        .byte $40
        .byte $60
        .byte $78
        .byte $6C
        .byte $7E
        .byte $76
        .byte $7F
        .byte $37
        .byte $7F
        .byte $1C
        .byte $06
        .byte $03

crab1_right:
        .byte $01
        .byte $03
        .byte $0F
        .byte $1B
        .byte $3F
        .byte $37
        .byte $7F
        .byte $76
        .byte $7F
        .byte $1C
        .byte $30
        .byte $60

crab2_left:
        .byte $40
        .byte $58
        .byte $7E
        .byte $7B
        .byte $7F
        .byte $5F
        .byte $7F
        .byte $2E
        .byte $7F
        .byte $18
        .byte $36
        .byte $03

crab2_right:
        .byte $01
        .byte $1A
        .byte $3F
        .byte $6F
        .byte $7F
        .byte $7A
        .byte $7F
        .byte $3A
        .byte $7F
        .byte $0C
        .byte $36
        .byte $60

octopus_left:
        .byte $70               ; ....###
        .byte $7C               ; ..#####
        .byte $7E               ; .######
        .byte $7F               ; #######
        .byte $77               ; ###.###
        .byte $7F               ; #######
        .byte $1C               ; ..###..
        .byte $66               ; .##..##

octopus_right:
        .byte $07               ; ###....
        .byte $1F               ; #####..
        .byte $3F               ; ######.
        .byte $7F               ; #######
        .byte $7D               ; ####.##
        .byte $7F               ; #######
        .byte $1C               ; ..###..
        .byte $33               ; ##..##.

; --- Compute the hi-res address of an arbitrary screen row ---
; Input:  A = absolute screen row (0-191)
; Output: HGR_PTR/HGR_PTR+1 = that row's address (column 0 of the row;
;         add your column offset via Y when you store, as before)
; Clobbers A and X. Handles any row, including sprites that span across
; an 8-row band boundary - unlike indexing hgr_row_lo/hgr_row_hi
; directly by row number, which only works by coincidence when a sprite
; happens to fit inside a single band.
calc_row_ptr:
        pha                 ; save the row number for later
        and #$07            ; A = row mod 8 (position within its band)
        asl                 ; *2
        asl                 ; *4 (adjacent rows within a band are $400 =
        sta ROW_TMP         ;     4 pages apart, so this only affects the high byte)
        pla                 ; restore the row number
        lsr
        lsr
        lsr                 ; A = row / 8 (which 8-row band, 0-23)
        tax                 ; X = band index into hgr_row_lo/hgr_row_hi
        lda hgr_row_lo, x   ; band's base address, low byte
        sta HGR_PTR         ; store the low byte of the row's address
        lda hgr_row_hi, x   ; band's base address, high byte
        clc
        adc ROW_TMP         ; add the within-band adjustment
        sta HGR_PTR+1       ; store the high byte of the row's address
        rts

; --- Hi-Res row base-address table (from M2 - verified correct) ---
hgr_row_lo:
        .byte <$2000, <$2080, <$2100, <$2180   ; bands 0-3 (rows 0, 8, 16, 24)
        .byte <$2200, <$2280, <$2300, <$2380   ; bands 4-7 (rows 32, 40, 48, 56)
        .byte <$2028, <$20A8, <$2128, <$21A8   ; bands 8-11 (rows 64, 72, 80, 88)
        .byte <$2228, <$22A8, <$2328, <$23A8   ; bands 12-15 (rows 96, 104, 112, 120)
        .byte <$2050, <$20D0, <$2150, <$21D0   ; bands 16-19 (rows 128, 136, 144, 152)
        .byte <$2250, <$22D0, <$2350, <$23D0   ; bands 20-23 (rows 160, 168, 176, 184)

hgr_row_hi:
        .byte >$2000, >$2080, >$2100, >$2180   ; bands 0-3 (rows 0,8,16,24)
        .byte >$2200, >$2280, >$2300, >$2380   ; bands 4-7 (rows 32, 40, 48, 56)
        .byte >$2028, >$20A8, >$2128, >$21A8   ; bands 8-11 (rows 64, 72, 80, 88)
        .byte >$2228, >$22A8, >$2328, >$23A8   ; bands 12-15 (rows 96, 104, 112, 120)
        .byte >$2050, >$20D0, >$2150, >$21D0   ; bands 16-19 (rows 128, 136, 144, 152)
        .byte >$2250, >$22D0, >$2350, >$23D0   ; bands 20-23 (rows 160, 168, 176, 184)

        .end
