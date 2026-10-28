; hires.asm
; Milestone 2: Hi-Res graphics fundamentals.
; Turns on Hi-Res page 1, clears it to black, and plots a single test
; row of pixels near the top of the screen so we know the pipeline works.

        * = $6000               ; load address for this DOS 3.3 BIN file

; --- Soft switches ---
; These are triggered just by accessing the address (read OR write) -
; the value doesn't matter. A plain STA works fine.
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

; zero-page pointer we'll use to address into hi-res memory.
; $00-$02 are used elsewhere (see hello.asm) - $06/$07 are free.
HGR_PTR = $06           ; HGR_PTR = low byte, HGR_PTR+1 = high byte

start:
        sta TXTCLR          ; switch on graphics mode
        sta MIXCLR          ; use the full screen (no reserved text lines)
        sta HIRES           ; select hi-res (vs. lo-res) graphics
        sta LOWSCR          ; display page 1 (vs. page 2)

; --- Clear the whole 8K hi-res page ($2000-$3FFF) to black ---
; Two nested loops: the outer loop walks each 256-byte page ($20-$3F is
; the high byte), the inner loop zeroes all 256 bytes of that page.
cls:
        ldx #$20            ; X = current page's high byte, starts at $20
        lda #$00            ; A = the byte value we're clearing memory to
        sta HGR_PTR         ; pointer's low byte is always $00 (page-aligned)
outer_loop:
        stx HGR_PTR+1       ; pointer's high byte = current page (X)
        ldy #$00            ; Y = inner loop's byte offset, reset each pass
inner_loop:
        sta (HGR_PTR), y    ; store 0 at (pointer + Y)
        iny                 ; move to the next byte in this page
        bne inner_loop      ; loop until Y wraps 255 -> 0 (256 bytes done)
        inx                 ; move to the next page
        cpx #$40            ; have we just passed page $3F (last page)?
        bne outer_loop      ; if not, clear the next page

; --- Plot a test row (row 0) so we can see the pipeline is working ---
        ldy #$00            ; Y = row-table index (0 = row 0)
        lda hgr_row_lo, y   ; look up row 0's base address, low byte
        sta HGR_PTR         ; store it as the pointer's low byte
        lda hgr_row_hi, y   ; look up row 0's base address, high byte
        sta HGR_PTR+1       ; store it as the pointer's high byte
        lda #$7F            ; test byte: all 7 pixel bits on, color bit off
plot_row:
        sta (HGR_PTR),y     ; store the test byte at (pointer + Y)
        iny                 ; move to the next column (byte) in this row
        cpy #$28            ; have we written all 40 columns ($28)?
        bne plot_row        ; if not, plot the next column

; --- Wait for a keypress so the picture stays on screen ---
key:    lda KBD             ; read keyboard data/strobe
        bpl key             ; bit 7 clear = no key yet, keep polling
        sta KBDSTRB         ; bit 7 set = key waiting; clear the strobe
        jmp key             ; go back to waiting (keeps the screen up)

; --- Hi-Res row base-address table ---
; Apple II hi-res memory is NOT laid out top-to-bottom in a simple line.
; The 192 rows are grouped into 24 "bands" of 8 rows each. This table
; gives the base address of the FIRST row in each band (rows 0, 8, 16,
; 24, ... 184). To reach the other 7 rows within a band, add $400 per
; row (row 1 of a band = band's base + $400, row 2 = base + $800, ...
; row 7 = base + $1C00).
;
; Within a band group of 8, the base steps by $80. Crossing a 64-row
; boundary (band 8 / row 64, and band 16 / row 128) resets the pattern
; to a new starting point ($2028 and $2050 respectively) before the
; $80 stepping resumes.
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
