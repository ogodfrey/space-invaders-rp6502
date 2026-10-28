; hello.asm
; 6502 project for the apple II
; This program prints "HELLO, APPLE ][!" to the screen.

    * = $6000


start:  jsr $FC58       ; HOME: clear screen and move cursor to top-left
        lda #$03        ; number of times to print the message
        sta $02         ; zero-page counter ($02 is safe; avoid $20-$3F, reserved for screen state)

outer:  ldx #$00        ; reset string index at the start of each pass
loop:   lda message, x  ; load next character of the message
        beq done        ; zero byte marks the end of the string
        ora #$80        ; Apple II text uses high-bit characters for normal display
        jsr $FDED       ; COUT: print A to the current output device
        inx             ; move to the next character
        jmp loop        ; repeat until the terminator is hit
done:   dec $02         ; count down the remaining passes
        bne outer       ; repeat the message if passes remain
key:    lda $C000       ; read keyboard data (bit 7 set = key waiting)
        bpl key         ; bit 7 clear = no key yet, keep polling
        sta $C010       ; clear the strobe
                        ; A now holds the key pressed
        ora #$80        ; set high bit so COUT displays it normally
        jsr $FDED       ; print the key that was pressed
        jmp key         ; wait for the next key

message:
        .text "HELLO, APPLE ][!"  ; the string to print (][ mimics the Apple II logo)
        .byte $8D, $00            ; return after each pass, then the string terminator

        .end    