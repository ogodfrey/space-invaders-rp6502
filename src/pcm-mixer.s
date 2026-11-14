; Optional RP6502 0.43 PCM mixer. Samples are signed 8-bit mono.
.include "rp6502.inc"
.include "xram.inc"
.macpack longbranch
.import tx_char
.export pcm_init, pcm_pump, pcm_shot, pcm_explosion, pcm_stop

PCM_BUFFER = $C100
PCM_TARGET = 192                                    ; at most 24 ms queued at 8 kHz
.assert XRAM_BITMAP + 38400 <= PCM_BUFFER, error, "PCM buffer overlaps game XRAM"
.assert PCM_BUFFER + PCM_TARGET <= $10000, error, "PCM buffer exceeds XRAM"

.segment "ZEROPAGE"
shot_ptr: .res 2
explosion_ptr: .res 2

.segment "BSS"
pcm_fd: .res 2
shot_active: .res 1
explosion_active: .res 1
pending_addr: .res 2
pending_count: .res 1
mix_count: .res 1
mix_value: .res 1

.segment "RODATA"
pcm_path: .byte "PCM:8000,8,1"
pcm_error: .byte "PCM AUDIO ERROR (RP6502 0.43 REQUIRED)", 13, 10, 0
shot_data: .incbin "game-shot.raw"
shot_end:
explosion_data: .incbin "game-explosion.raw"
explosion_end:

.segment "CODE"

pcm_init:
    ldx #11                                         ; last byte of pcm_path
@path:
    lda a:.loword(pcm_path),x
    sta RIA_XSTACK
    dex
    bpl @path
    lda #2                                          ; O_WRONLY
    sta RIA_A
    stz RIA_X
    lda #RIA_OP_OPEN
    sta RIA_OP
    jsr RIA_SPIN
    cpx #$FF
    jeq pcm_fatal
    sta pcm_fd
    stx pcm_fd+1
    stz shot_active
    stz explosion_active
    stz pending_count
    rts

pcm_shot:
    lda #<shot_data
    sta shot_ptr
    lda #>shot_data
    sta shot_ptr+1
    lda #1
    sta shot_active
    rts

pcm_explosion:
    lda #<explosion_data
    sta explosion_ptr
    lda #>explosion_data
    sta explosion_ptr+1
    lda #1
    sta explosion_active
    rts

; SEEK_SET clears queued audio; pending mixed bytes must be discarded too.
pcm_stop:
    stz shot_active
    stz explosion_active
    stz pending_count
    lda #2                                          ; cc65 SEEK_SET
    jsr .loword(pcm_seek)
    cpx #$FF
    jeq pcm_fatal
    rts

; A = whence, offset zero. Returns the low word in A/X.
pcm_seek:
    ldx #0
    stx RIA_XSTACK
    stx RIA_XSTACK
    stx RIA_XSTACK
    stx RIA_XSTACK
    sta RIA_XSTACK
    lda pcm_fd
    sta RIA_A
    lda pcm_fd+1
    sta RIA_X
    lda #RIA_OP_LSEEK_CC65
    sta RIA_OP
    jmp RIA_SPIN

; Refill once per frame without blocking. A short write remains pending.
pcm_pump:
    lda pending_count
    jne @write
    lda shot_active
    ora explosion_active
    jeq @done
    lda #0                                          ; cc65 SEEK_CUR: queue level
    jsr .loword(pcm_seek)
    cpx #$FF
    jeq pcm_fatal
    cpx #0
    jne @done
    cmp #PCM_TARGET
    jcs @done
    eor #$FF
    sec
    adc #PCM_TARGET
    sta mix_count
    sta pending_count
    lda #<PCM_BUFFER
    sta pending_addr
    sta RIA_ADDR0
    lda #>PCM_BUFFER
    sta pending_addr+1
    sta RIA_ADDR0+1
    lda #1
    sta RIA_STEP0
    ldx mix_count
    ldy #0
@sample:
    stz mix_value
    lda shot_active
    beq @explosion
    lda (shot_ptr),y
    sta mix_value
    inc shot_ptr
    bne @shot_end
    inc shot_ptr+1
@shot_end:
    lda shot_ptr
    cmp #<shot_end
    bne @explosion
    lda shot_ptr+1
    cmp #>shot_end
    bne @explosion
    stz shot_active
@explosion:
    lda explosion_active
    beq @output
    lda (explosion_ptr),y
    clc
    adc mix_value
    sta mix_value
    inc explosion_ptr
    bne @explosion_end
    inc explosion_ptr+1
@explosion_end:
    lda explosion_ptr
    cmp #<explosion_end
    bne @output
    lda explosion_ptr+1
    cmp #>explosion_end
    bne @output
    stz explosion_active
@output:
    lda mix_value
    clc
    adc #128                                        ; signed sum to unsigned PCM
    sta RIA_RW0
    dex
    bne @sample
@write:
    lda pending_addr+1
    sta RIA_XSTACK
    lda pending_addr
    sta RIA_XSTACK
    stz RIA_XSTACK
    lda pending_count
    sta RIA_XSTACK
    lda pcm_fd
    sta RIA_A
    lda pcm_fd+1
    sta RIA_X
    lda #RIA_OP_WRITE_XRAM
    sta RIA_OP
    jsr RIA_SPIN
    cpx #$FF
    beq pcm_fatal
    sta mix_count
    sec
    lda pending_count
    sbc mix_count
    sta pending_count
    lda mix_count
    clc
    adc pending_addr
    sta pending_addr
    bcc @done
    inc pending_addr+1
@done:
    rts

pcm_fatal:
    ldx #0
@message:
    lda pcm_error,x
    beq @exit
    jsr tx_char
    inx
    bne @message
@exit:
    lda #1
    sta RIA_A
    stz RIA_X
    lda #RIA_OP_EXIT
    sta RIA_OP
    jmp RIA_SPIN
