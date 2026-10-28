; player.asm
; Milestone 3: Static player sprite.
; Draws a simple player-cannon shape at a fixed, byte-aligned position,
; then erases it cleanly (proving draw and erase use the same addressing).

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

HGR_PAGE1 = $2000       ; start of hi-res page 1 ($2000-$3FFF, 8K)

; zero-page pointer used to address into hi-res memory.
; $00-$02 used by hello.asm's example, not relevant here, but keep the
; habit of not stepping on $00-$05 in case later milestones combine code.
HGR_PTR = $06           ; HGR_PTR = low byte, HGR_PTR+1 = high byte
ROW_TMP = $08           ; scratch byte used only inside calc_row_ptr
SPRITE_ROW = $09          ; current row of the sprite being drawn

; --- Sprite position (byte-aligned: column is a byte offset, 0-39) ---
PLAYER_ROW = 0          ; starting screen row (0-191) for the sprite's top
PLAYER_COL = 0          ; starting column byte (0-39) for the sprite

start:
        sta TXTCLR          ; switch on graphics mode
        sta MIXCLR          ; use the full screen (no reserved text lines)
        sta HIRES           ; select hi-res (vs. lo-res) graphics
        sta LOWSCR          ; display page 1 (vs. page 2)

; --- Clear the whole 8K hi-res page ($2000-$3FFF) to black ---
cls:
        ldx #$20            ; X = current page's high byte, starts at $20
        lda #$00            ; A = the byte value we're clearing memory to
        sta HGR_PTR         ; pointer's low byte is always $00 (page-aligned)
clr_highbyte:
        stx HGR_PTR+1       ; pointer's high byte = current page (X)
        ldy #$00            ; Y = inner loop's byte offset, reset each pass
clr_lowbyte:
        sta (HGR_PTR), y    ; store 0 at (pointer + Y)
        iny                 ; move to the next byte in this page
        bne clr_lowbyte     ; loop until Y wraps 255 -> 0 (256 bytes done)
        inx                 ; move to the next page
        cpx #$40            ; have we just passed page $3F (last page)?
        bne clr_highbyte    ; if not, clear the next page

; --- Alternate drawing and erasing the sprite on each keypress ---
draw_and_wait:
        jsr draw_sprite       ; draw the player sprite
        jsr key_wait          ; wait for a keypress
erase_and_wait:
        jsr erase_sprite      ; erase the player sprite
        jsr key_wait          ; wait for another keypress
        jmp draw_and_wait     ; repeat forever

; --- Draw the player sprite ---
; SPRITE_ROW (zero page) is the loop counter: it's the sprite's own row
; number (0..PLAYER_SPRITE_ROWS-1), used both to compute PLAYER_ROW +
; SPRITE_ROW for calc_row_ptr and to index player_sprite. It has to live
; in memory rather than a register because calc_row_ptr uses X
; internally and would clobber a register-based counter. Y stays fixed
; at PLAYER_COL the whole time - it's just where in the row we store,
; not a loop counter.
draw_sprite:
        ldy #PLAYER_COL         ; Y = fixed column offset for every row
        lda #$00
        sta SPRITE_ROW          ; start at sprite row 0
plot_row:
        lda SPRITE_ROW          ; A = current sprite row number
        clc
        adc #PLAYER_ROW         ; A = absolute screen row = PLAYER_ROW + SPRITE_ROW
        jsr calc_row_ptr        ; compute HGR_PTR for that row (clobbers X)
        ldx SPRITE_ROW          ; reload X - calc_row_ptr just clobbered it
        lda player_sprite, x    ; load the sprite byte for this row
        sta (HGR_PTR), y        ; store it at (pointer + PLAYER_COL)
        inc SPRITE_ROW          ; move to the next sprite row
        ldx SPRITE_ROW          ; reload the (now incremented) row number
        cpx #PLAYER_SPRITE_ROWS ; have we written all sprite rows?
        bne plot_row            ; if not, plot the next row
        rts

; --- Erase the player sprite ---
; Same addressing as draw_sprite, but stores $00 instead of the sprite's
; byte - this paints over the sprite with black. No player_sprite lookup
; needed here, so unlike draw_sprite this doesn't need to reload X after
; calc_row_ptr except for the loop's own exit check.
erase_sprite:
        ldy #PLAYER_COL         ; Y = fixed column offset for every row
        lda #$00
        sta SPRITE_ROW          ; start at sprite row 0
del_row:
        lda SPRITE_ROW          ; A = current sprite row number
        clc
        adc #PLAYER_ROW         ; A = absolute screen row = PLAYER_ROW + SPRITE_ROW
        jsr calc_row_ptr        ; compute HGR_PTR for that row (clobbers X)
        lda #$00                ; blank byte (all pixels off)
        sta (HGR_PTR), y        ; store it at (pointer + PLAYER_COL)
        inc SPRITE_ROW          ; move to the next sprite row
        ldx SPRITE_ROW          ; reload the (now incremented) row number
        cpx #PLAYER_SPRITE_ROWS ; have we written all sprite rows?
        bne del_row             ; if not, erase the next row
        rts

; --- Player sprite shape ---
; One byte per row = 7 pixels wide (bit 7 stays 0 - color group off, as
; in M2's test row).
player_sprite:
        .byte $1c               ; row 0: tip of the cannon
        .byte $1c               ; row 1
        .byte $3e               ; row 2
        .byte $3e               ; row 3
        .byte $FF                ; row 4
        .byte $FF                ; row 5: base of the cannon
PLAYER_SPRITE_ROWS = * - player_sprite  ; number of rows, computed from the table above

key_wait:
        ; Small reusable keyboard-wait routine - call with JSR, returns
        ; once a key has been pressed and the strobe cleared.
        lda KBD
        bpl key_wait
        sta KBDSTRB
        rts

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
        sta HGR_PTR
        lda hgr_row_hi, x   ; band's base address, high byte
        clc
        adc ROW_TMP         ; add the within-band adjustment
        sta HGR_PTR+1
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
