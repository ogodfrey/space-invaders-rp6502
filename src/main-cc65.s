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
PLAYER_START_U       = 76                           ; player start x, in 2-pixel units (center of the field)
PLAYER_MIN_U         = 24                           ; leftmost player x (field left edge)
PLAYER_MAX_U         = 128                          ; rightmost player x (field right edge minus 16 px)
FIELD_LEFT_U         = 24                           ; left edge of the 224-px arcade field, in 2-pixel units
FIELD_RIGHT_U        = 136                          ; right edge of the field (24 + 112 units)
ALIEN_W_BYTES        = 4                            ; alien width in bytes (8 px at 4 bits per pixel)
GRID_COLS            = 11                           ; aliens per row in the grid, as in arcade
GRID_ROWS            = 5                            ; rows of aliens in the grid, as in arcade
GRID_COUNT           = GRID_COLS * GRID_ROWS        ; total aliens in the grid (55)
GRID_PY              = 40                           ; top row of the first alien row, in pixels
GRID_START_U         = FIELD_LEFT_U                 ; starting grid x, in 2-pixel units

BOMB_MAX             = 3                            ; most alien bombs on screen at once, as in arcade
BOMB_FIRE_FRAMES     = 60                           ; frames between alien fire attempts (tuning)
BOMB_STEP_FRAMES     = 8                            ; frames between bomb moves (tuning)
BOMB_STEP_PX         = 8                            ; bomb move per step, in pixels
BOMB_FLOOR_PY        = 232                          ; a bomb at or below this row has left the screen
BOMB_OFFSET_U        = 2                            ; bomb x offset from the alien's left edge (center)
LIVES_START          = 3                            ; ships per game, as in arcade
DEATH_FRAMES         = 120                          ; frames the game pauses after a ship is lost
RNG_SEED             = $A5                          ; nonzero start for the random number generator
SHIELD_COUNT         = 4                            ; bunkers, as in arcade
SHIELD_COLS          = 11                           ; cells across one bunker (2 px each)
SHIELD_ROWS          = 4                            ; cells down one bunker (4 px each)
SHIELD_CELLS         = SHIELD_COLS * SHIELD_ROWS    ; cells per bunker (44)
SHIELD_PY            = 168                          ; top row of the shields, in pixels
SHIELD_CELL_H        = 4                            ; height of one shield cell, in pixels
UFO_Y                = 24                           ; top row of the saucer, above the aliens
UFO_STEP_U           = 2                            ; saucer move per step, in 2-pixel units (4 px)
UFO_STEP_FRAMES      = 3                            ; frames between saucer steps (tuning)
UFO_RIGHT_U          = 152                          ; the saucer leaves the screen past this x
UFO_BASE_FRAMES      = 900                          ; shortest wait before the next saucer (15 s at 60 Hz)
SND_SHOT_LO          = $B8                          ; the player's shot starts at 1000 Hz (3000 in 1/3 Hz), low byte
SND_SHOT_HI          = $0B                          ; high byte
SND_SHOT_STEP        = 300                          ; the shot's pitch falls 100 Hz per frame (in 1/3 Hz)
SND_SHOT_FRAMES      = 8                            ; frames the shot sound lasts
SND_EXPL_LO          = $8C                          ; explosion noise rate: 900 (in 1/3 Hz), low byte
SND_EXPL_HI          = $0A                          ; high byte
SND_UFO_LO           = $DC                          ; saucer tone: 500 Hz (1500 in 1/3 Hz), low byte
SND_UFO_HI           = $05                          ; high byte
GRID_DROP_PY         = 8                            ; rows the grid drops at each screen edge, in pixels
STATE_TITLE          = 0                            ; title screen: waiting for Space to start
STATE_PLAY           = 1                            ; playing a wave
STATE_WAVE           = 2                            ; a wave is cleared: pause, then the next wave
STATE_OVER           = 3                            ; game over: show the message, then the title
WAVE_PAUSE_FRAMES    = 120                          ; frames between waves
OVER_FRAMES          = 180                          ; frames the game-over message stays up
ALIEN_STEP_U         = 2                            ; grid move per step (4 px)
BULLET_STEP_PX       = 8                            ; bullet move per step, in pixels
BULLET_STEP_FRAMES   = 4                            ; frames between bullet steps
ALIEN_STEP_FRAMES    = 16                           ; frames between alien steps (tuning)

.segment "RODATA"                                   ; read-only data goes in ROM

str_title:                                          ; HUD title text label
    .byte "SPACE INVADERS     SCORE: "              ; title, then the score digits
str_title_len = * - str_title                       ; length of the title text
str_help:                                           ; control hint text label
    .byte "A/D or arrows move  SPACE fires"         ; control hint shown under the title
str_help_len = * - str_help                         ; length of the hint text
str_lives:                                          ; lives label text
    .byte "LIVES "                                  ; label shown before the count
str_lives_len = * - str_lives                       ; length of the label
str_gameover:                                       ; game over text
    .byte "GAME OVER"                               ; shown when the last ship is lost
str_gameover_len = * - str_gameover                 ; length of the game over text
str_name:                                           ; the game's name on the title screen
    .byte "SPACE INVADERS"                          ; title text
str_name_len = * - str_name                         ; length of the name
str_press:                                          ; prompt on the title screen
    .byte "PRESS SPACE TO START"                    ; how to begin
str_press_len = * - str_press                       ; length of the prompt

div_lo:     .byte <10000, <1000, <100, <10, <1      ; low bytes of decimal place values
div_hi:     .byte >10000, >1000, >100, >10, >1      ; high bytes of decimal place values

; Shields: four bunkers of 11x4 cells. Each cell is 1 byte (2 px) wide and 4 px tall.
shield_left_u:                                      ; left edge of each bunker, in 2-pixel units
    .byte 33, 61, 89, 117                           ; spread across the field
shield_base:                                        ; first cell index of each bunker
    .byte 0, 44, 88, 132
shield_roff:                                        ; first cell index of each row within a bunker
    .byte 0, 11, 22, 33
shield_row_py:                                      ; top row of each cell row, in pixels
    .byte 168, 172, 176, 180
shield_template:                                    ; the full shape of one bunker: 1 = cell, 0 = gap
    .byte 1,1,1,1,1,1,1,1,1,1,1                     ; row 0
    .byte 1,1,1,1,1,1,1,1,1,1,1                     ; row 1
    .byte 1,1,1,0,0,0,0,0,1,1,1                     ; row 2: arch opening
    .byte 1,1,0,0,0,0,0,0,0,1,1                     ; row 3: arch opening

; Points for the bonus saucer. The value is picked by the number of shots fired
; (mod 16) when the saucer is hit. Low and high bytes, 16 entries.
ufo_pts_lo:
    .byte $64, $32, $32, $64, $96, $64, $64, $32    ; 100 50 50 100 150 100 100 50
    .byte $2C, $64, $64, $64, $32, $96, $64, $32    ; 300 100 100 100 50 150 100 50
; Bassline: four notes that step down, repeated for the whole wave.
; Frequencies in 1/3 Hz: 294 (98 Hz), 276 (92 Hz), 261 (87 Hz), 246 (82 Hz).
bass_lo:
    .byte $26, $14, $05, $F6                        ; low bytes of the four notes
bass_hi:
    .byte $01, $01, $01, $00                        ; high bytes of the four notes
ufo_pts_hi:
    .byte 0, 0, 0, 0, 0, 0, 0, 0                    ; 300 needs the high byte
    .byte 1, 0, 0, 0, 0, 0, 0, 0

palette_rom:                                        ; 16 colors, 2 bytes each, for the bitmap
    COLOR_FROM_RGBA 0, 0, 0, 255            ; 0: black
    COLOR_FROM_RGBA 0, 255, 0, 255          ; 1: green
    COLOR_FROM_RGBA 255, 255, 255, 255      ; 2: white
    COLOR_FROM_RGBA 255, 0, 0, 255          ; 3: red, for the bonus saucer
    .res 24, 0                              ; unused palette entries are transparent black

bitmap_config_rom:                                  ; Mode 3 config, 14 bytes, as the VGA docs lay it out
    .byte 0, 0                                      ; x_wrap and y_wrap off
    .word 0, 0                                      ; bitmap at the top left of the canvas
    .word BITMAP_WIDTH_PX, BITMAP_HEIGHT_PX         ; bitmap size in pixels
    .word XRAM_BITMAP, XRAM_PALETTE                 ; bitmap and palette addresses in XRAM

; Sprites: the player (16x8), then squid, crab, and octopus A/B frames (8x8 each),
; then the bullet and bomb (1 byte wide). The order matches xram_layout_t.
; Uploaded in two parts, since one loop index covers only 256 bytes.
sprite_rom:                                         ; all sprite data in XRAM order
    .byte $00, $00, $00, $01, $10, $00, $00, $00    ; player row 0: cannon tip
    .byte $00, $00, $00, $11, $11, $00, $00, $00    ; player row 1
    .byte $00, $00, $00, $11, $11, $00, $00, $00    ; player row 2
    .byte $01, $11, $11, $11, $11, $11, $11, $10    ; player row 3: wider body
    .byte $11, $11, $11, $11, $11, $11, $11, $11    ; player row 4: full width
    .byte $11, $11, $11, $11, $11, $11, $11, $11    ; player row 5
    .byte $11, $11, $11, $11, $11, $11, $11, $11    ; player row 6
    .byte $11, $11, $11, $11, $11, $11, $11, $11    ; player row 7
    .byte $00, $01, $10, $00                        ; squid A row 0: antennae
    .byte $00, $11, $11, $00                        ; squid A row 1
    .byte $01, $11, $11, $10                        ; squid A row 2
    .byte $11, $01, $10, $11                        ; squid A row 3: eyes
    .byte $11, $11, $11, $11                        ; squid A row 4
    .byte $00, $10, $01, $00                        ; squid A row 5: legs in
    .byte $01, $01, $10, $10                        ; squid A row 6: legs in
    .byte $10, $10, $01, $01                        ; squid A row 7: feet in
    .byte $00, $01, $10, $00                        ; squid B row 0: antennae
    .byte $00, $11, $11, $00                        ; squid B row 1
    .byte $01, $11, $11, $10                        ; squid B row 2
    .byte $11, $01, $10, $11                        ; squid B row 3: eyes
    .byte $11, $11, $11, $11                        ; squid B row 4
    .byte $00, $10, $01, $00                        ; squid B row 5: legs out
    .byte $01, $00, $00, $10                        ; squid B row 6: legs out
    .byte $00, $10, $01, $00                        ; squid B row 7: feet out
    .byte $00, $10, $01, $00                        ; crab A row 0: antennae
    .byte $10, $11, $11, $01                        ; crab A row 1
    .byte $11, $11, $11, $11                        ; crab A row 2
    .byte $11, $01, $10, $11                        ; crab A row 3: eyes
    .byte $11, $11, $11, $11                        ; crab A row 4
    .byte $00, $10, $01, $00                        ; crab A row 5: legs in
    .byte $01, $00, $00, $10                        ; crab A row 6: legs in
    .byte $10, $00, $00, $01                        ; crab A row 7: feet in
    .byte $00, $10, $01, $00                        ; crab B row 0: antennae
    .byte $10, $11, $11, $01                        ; crab B row 1
    .byte $11, $11, $11, $11                        ; crab B row 2
    .byte $11, $01, $10, $11                        ; crab B row 3: eyes
    .byte $11, $11, $11, $11                        ; crab B row 4
    .byte $01, $01, $10, $10                        ; crab B row 5: legs out
    .byte $10, $10, $01, $01                        ; crab B row 6: legs out
    .byte $00, $10, $01, $00                        ; crab B row 7: feet out
    .byte $00, $11, $11, $00                        ; octopus A row 0: head
    .byte $01, $11, $11, $10                        ; octopus A row 1
    .byte $11, $11, $11, $11                        ; octopus A row 2
    .byte $11, $00, $00, $11                        ; octopus A row 3: eyes gap
    .byte $11, $11, $11, $11                        ; octopus A row 4
    .byte $00, $11, $11, $00                        ; octopus A row 5
    .byte $01, $00, $00, $10                        ; octopus A row 6: legs in
    .byte $10, $00, $00, $01                        ; octopus A row 7: feet in
    .byte $00, $11, $11, $00                        ; octopus B row 0: head
    .byte $01, $11, $11, $10                        ; octopus B row 1
    .byte $11, $11, $11, $11                        ; octopus B row 2
    .byte $11, $00, $00, $11                        ; octopus B row 3: eyes gap
    .byte $11, $11, $11, $11                        ; octopus B row 4
    .byte $00, $11, $11, $00                        ; octopus B row 5
    .byte $10, $00, $00, $01                        ; octopus B row 6: legs out
    .byte $01, $00, $00, $10                        ; octopus B row 7: feet out
    .byte $22, $22, $22, $22, $22, $22, $22, $22    ; bullet: 8 rows of 1 byte, 2 white pixels
    .byte $20, $02, $20, $02, $20, $02, $20, $02    ; bomb: zigzag, 8 rows of 1 byte
    .byte $00, $00, $33, $33, $33, $33, $00, $00    ; UFO row 0: dome
    .byte $00, $33, $33, $33, $33, $33, $33, $00    ; UFO row 1
    .byte $03, $33, $32, $33, $33, $33, $23, $30    ; UFO row 2: windows
    .byte $13, $33, $33, $33, $33, $33, $33, $31    ; UFO row 3: body
    .byte $00, $33, $30, $00, $00, $00, $33, $30    ; UFO row 4: legs
    .byte $00, $03, $30, $00, $00, $00, $03, $30    ; UFO row 5
    .byte $00, $00, $00, $00, $00, $00, $00, $00    ; UFO row 6: blank
    .byte $00, $00, $00, $00, $00, $00, $00, $00    ; UFO row 7: blank

; XRAM address of each bitmap row, for the blitter.
row_lo:                                             ; low byte of each row's address
.repeat 240, I                                      ; one entry per canvas row
    .byte <(XRAM_BITMAP + I * (BITMAP_WIDTH_PX / 2)) ; row I starts at 160 bytes per row
.endrepeat                                          ; end of the row_lo table
row_hi:                                             ; high byte of each row's address
.repeat 240, I                                      ; one entry per canvas row
    .byte >(XRAM_BITMAP + I * (BITMAP_WIDTH_PX / 2)) ; high byte of the same address
.endrepeat                                          ; end of the row_hi table

; Each grid alien's x offset (in 2-pixel units) and top row offset from grid_y (in pixels).
; Index = row * GRID_COLS + column, matching grid_alive.
grid_col_u:                                         ; x offset of each grid alien
.repeat GRID_ROWS, R                                ; one group of columns per row
    .repeat GRID_COLS, C                            ; one entry per column
        .byte C * 8                                 ; columns are 16 px apart (8 bytes), as in arcade
    .endrepeat                                      ; end of the columns
.endrepeat                                          ; end of the rows
grid_row_off:                                       ; top row of each grid alien, from grid_y
.repeat GRID_ROWS, R                                ; one group of columns per row
    .repeat GRID_COLS, C                            ; one entry per column
        .byte R * 16                                ; rows are 16 px apart
    .endrepeat                                      ; end of the columns
.endrepeat                                          ; end of the rows
grid_type2:                                         ; sprite type of each grid alien, times 2 (squid, crab, octopus)
.repeat GRID_ROWS, R                                ; one group of columns per row
    .repeat GRID_COLS, C                            ; one entry per column
        .if R = 0                                   ; top row: squid
            .byte 0                                 ; squid sprites start at type 0
        .elseif R < 3                               ; middle rows: crab
            .byte 2                                 ; crab sprites start at type 2
        .else                                       ; bottom rows: octopus
            .byte 4                                 ; octopus sprites start at type 4
        .endif                                      ; end of the row test
    .endrepeat                                      ; end of the columns
.endrepeat                                          ; end of the rows
alien_src_lo:                                       ; low byte of each alien sprite address
    .byte <XRAM_SQUID_A, <XRAM_SQUID_B, <XRAM_CRAB_A, <XRAM_CRAB_B, <XRAM_OCTO_A, <XRAM_OCTO_B
alien_src_hi:                                       ; high byte of each alien sprite address
    .byte >XRAM_SQUID_A, >XRAM_SQUID_B, >XRAM_CRAB_A, >XRAM_CRAB_B, >XRAM_OCTO_A, >XRAM_OCTO_B
grid_points:                                        ; points for each alien, by row, as in arcade
.repeat GRID_ROWS, R                                ; one group of columns per row
    .repeat GRID_COLS, C                            ; one entry per column
        .if R = 0                                   ; top row
            .byte 30                                ; the top row is worth 30 points
        .elseif R < 3                               ; the two middle rows
            .byte 20                                ; the middle rows are worth 20 points
        .else                                       ; the bottom two rows
            .byte 10                                ; the bottom rows are worth 10 points
        .endif                                      ; end of the row test
    .endrepeat                                      ; end of the columns
.endrepeat                                          ; end of the rows

.segment "BSS"                                      ; zero-initialized RAM for variables

player_u:      .res 1                               ; player x, in 2-pixel units
grid_u:        .res 1                               ; grid x offset, in 2-pixel units
grid_y:        .res 1                               ; grid top row, in pixels
grid_ext_min:  .res 1                               ; leftmost living column offset, in 2-pixel units
grid_ext_max:  .res 1                               ; rightmost living column offset, in 2-pixel units
grid_ext_low:  .res 1                               ; lowest living row offset, in pixels from grid_y
game_state:    .res 1                               ; STATE_TITLE, STATE_PLAY, STATE_WAVE, or STATE_OVER
state_timer:   .res 1                               ; frames left in a timed screen
alien_dir:     .res 1                               ; grid step per move: +4 or -4 (as $FC)
alien_frame:   .res 1                               ; 0 or 1: which alien sprite to draw
alien_timer:   .res 1                               ; frames since the grid last moved
grid_alive:    .res GRID_COUNT                      ; 1 while each grid alien is on screen
grid_i:        .res 1                               ; index of the grid alien being handled
grid_erase:    .res 1                               ; 1 while grid_apply is erasing, 0 while drawing
hit_x:         .res 1                               ; x of the alien being tested for a hit
hit_y:         .res 1                               ; top row of the alien being tested
hit_b:         .res 1                               ; bottom row (exclusive) of that alien
bullet_b:      .res 1                               ; bottom row (exclusive) of the bullet
lives:         .res 1                               ; ships left
player_dead:   .res 1                               ; 1 while the ship is destroyed and the game is paused
death_timer:   .res 1                               ; frames left in the pause after a ship is lost
fire_timer:    .res 1                               ; frames since the aliens last tried to fire
bomb_timer:    .res 1                               ; frames since the bombs last moved
rng:           .res 1                               ; random number generator state
bomb_slot:     .res 1                               ; index of the bomb being handled
bomb_active:   .res BOMB_MAX                        ; 1 while each bomb slot is in use
bomb_u:        .res BOMB_MAX                        ; x of each bomb, in 2-pixel units
bomb_y:        .res BOMB_MAX                        ; top row of each bomb, in pixels
shield_cells:  .res SHIELD_COUNT * SHIELD_CELLS     ; 1 while each shield cell stands
sh_b:          .res 1                               ; bunker index in a shield scan
sh_r:          .res 1                               ; cell row in a shield scan
sh_c:          .res 1                               ; cell column in a shield scan
sh_mode:       .res 1                               ; 0 kill the first hit, 1 kill all hits, 2 draw
sh_x:          .res 1                               ; x of the cell being handled, in 2-pixel units
sh_y:          .res 1                               ; top row of the cell being handled, in pixels
rect_x:        .res 1                               ; x of the rectangle a shield scan tests
rect_y:        .res 1                               ; top row of that rectangle
rect_w:        .res 1                               ; its width in 2-pixel units
rect_h:        .res 1                               ; its height in pixels
ufo_active:    .res 1                               ; 1 while the saucer is crossing the screen
ufo_x:         .res 1                               ; saucer x, in 2-pixel units
ufo_dir:       .res 1                               ; saucer step: +2 (right) or $FE (left)
ufo_timer:     .res 1                               ; frames until the saucer's next step
ufo_wait_lo:   .res 1                               ; frames until the next saucer, low byte
ufo_wait_hi:   .res 1                               ; frames until the next saucer, high byte
shots_fired:   .res 1                               ; player shots fired, for the saucer's points
alive_count:   .res 1                               ; living grid aliens, which sets the bassline tempo
ps_off:        .res 1                               ; PSG channel byte offset (0, 8, 16, 24) for helpers
ps_lo:         .res 1                               ; frequency low byte for psg_set_freq
ps_hi:         .res 1                               ; frequency high byte for psg_set_freq
ps_gate:       .res 1                               ; gate byte for psg_set_gate
shot_lo:       .res 1                               ; the shot's current frequency, low byte
shot_hi:       .res 1                               ; high byte
shot_frames:   .res 1                               ; frames left in the shot sound
expl_frames:   .res 1                               ; frames left in the explosion sound
bass_timer:    .res 1                               ; frames until the next bassline note
bass_idx:      .res 1                               ; which bassline note is next, 0 to 3
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
    UPLOAD XRAM_PLAYER_SPRITE, sprite_rom, 192      ; copy the player and squid and crab sprites
    UPLOAD XRAM_OCTO_A, sprite_rom+192, 144         ; copy the octopus, bullet, bomb, and saucer sprites
    UPLOAD XRAM_BITMAP_CONFIG, bitmap_config_rom, 14 ; copy the Mode 3 config into XRAM

    lda #<XRAM_BLANK                                ; low byte of the zero-byte address
    sta RIA_ADDR0                                   ; point portal 0 at it, low byte
    lda #>XRAM_BLANK                                ; high byte of the zero-byte address
    sta RIA_ADDR0+1                                 ; point portal 0 at it, high byte
    lda #0                                          ; the zero value to store
    sta RIA_RW0                                     ; write the zero byte that erases use
    lda #<XRAM_SHIELD_BLOCK                         ; low byte of the shield cell byte
    sta RIA_ADDR0                                   ; point portal 0 at it, low byte
    lda #>XRAM_SHIELD_BLOCK                         ; high byte of the shield cell byte
    sta RIA_ADDR0+1                                 ; point portal 0 at it, high byte
    lda #$11                                        ; green: both pixels in palette entry 1
    sta RIA_RW0                                     ; write the solid shield cell byte

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
    lda #GRID_START_U                               ; starting grid x
    sta grid_u                                      ; store the grid's x
    lda #GRID_PY                                    ; starting top row of the grid
    sta grid_y                                      ; store the grid's top row
    lda #ALIEN_STEP_U                               ; start moving right (+4)
    sta alien_dir                                   ; store the grid's direction
    lda #0                                          ; first animation frame
    sta alien_frame                                 ; store the animation frame
    sta alien_timer                                 ; clear the alien move timer
    ldx #GRID_COUNT-1                               ; start at the last alien
@fill:                                              ; mark every grid alien alive
    lda #1                                          ; alive
    sta grid_alive,x                                ; store the flag
    dex                                             ; the previous alien
    bpl @fill                                       ; until index 0 is set
    lda #0                                          ; zero for the flags and score below
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
    jsr draw_grid                                   ; draw the alien grid
    jsr draw_player                                 ; draw the player
    lda RIA_VSYNC                                   ; read the current VSYNC count
    sta last_vsync                                  ; remember it as the last frame
    lda #LIVES_START                                ; three ships to start
    sta lives                                       ; store the ship count
    lda #0                                          ; nothing destroyed, no timers running
    sta player_dead                                 ; the ship is not destroyed
    sta fire_timer                                  ; no alien has fired yet
    sta bomb_timer                                  ; no bomb has moved yet
    sta ufo_active                                  ; no saucer yet
    sta shots_fired                                 ; no shots fired yet
    ldx #BOMB_MAX-1                                 ; start at the last bomb slot
@clear_bombs:                                       ; mark every bomb slot empty
    sta bomb_active,x                               ; empty the slot
    dex                                             ; the previous slot
    bpl @clear_bombs                                ; until slot 0 is cleared
    lda #RNG_SEED                                   ; nonzero seed
    sta rng                                         ; store the generator state
    jsr draw_lives                                  ; show the ship count
    jsr sound_init                                  ; map the PSG and silence it
    jsr enter_title                                 ; start on the title screen

main_loop:                                          ; one pass per video frame
    lda RIA_VSYNC                                   ; read the current VSYNC count
    cmp last_vsync                                  ; has a new frame started?
    beq main_loop                                   ; no: keep waiting
    sta last_vsync                                  ; yes: remember this frame
    lda game_state                                  ; which screen is showing?
    cmp #STATE_PLAY                                 ; the game?
    beq @play                                       ; yes: run it
    cmp #STATE_TITLE                                ; the title screen?
    bne @timed                                      ; no: a timed pause
    jsr title_frame                                 ; wait for Space to start
    jmp main_loop                                   ; next frame
@timed:                                             ; a wave-clear or game-over pause
    jsr timed_frame                                 ; count it down
    jmp main_loop                                   ; next frame
@play:                                              ; the game is running
    jsr update_sound                                ; the effects and the bassline
    lda player_dead                                 ; is the ship destroyed?
    beq @live                                       ; no: play normally
    jsr dead_frame                                  ; count down the pause, then respawn
    jmp main_loop                                   ; skip the rest of this frame
@live:                                              ; the ship is alive

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
    jsr update_grid                                 ; move the alien grid
    jsr alien_fire                                  ; maybe launch an alien bomb
    jsr update_bombs                                ; move the alien bombs
    jsr update_ufo                                  ; move the bonus saucer
    jsr play_check                                  ; a cleared wave or a landed grid ends the wave
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

draw_grid:                                          ; draw every living grid alien in the current frame
    jsr shield_contact                              ; aliens low enough destroy the shield cells under them
    lda #0                                          ; not erasing
    sta grid_erase                                  ; store the mode
    jmp grid_apply                                  ; blit every living alien

erase_grid:                                         ; erase every living grid alien
    lda #1                                          ; erasing
    sta grid_erase                                  ; store the mode
    jmp grid_apply                                  ; blit over every living alien

grid_apply:                                         ; blit an 8-row block at each living alien
    lda #0                                          ; start at the first alien
    sta grid_i                                      ; store the index
@loop:                                              ; one alien per pass
    ldx grid_i                                      ; the current alien's index
    lda grid_alive,x                                ; is this alien alive?
    beq @skip                                       ; no: nothing to draw
    lda grid_erase                                  ; are we erasing?
    bne @blank                                      ; yes: use the zero byte
    lda grid_type2,x                                ; this row's sprite type (2 per type)
    clc                                             ; prepare to add
    adc alien_frame                                 ; add the animation frame
    tay                                             ; index the sprite address tables with it
    lda alien_src_lo,y                              ; low byte of the sprite address
    sta blit_src                                    ; hand it to the blitter
    lda alien_src_hi,y                              ; high byte of the sprite address
    sta blit_src+1                                  ; hand it to the blitter
    lda #ALIEN_W_BYTES                              ; sprite rows are one alien wide apart
    sta blit_stride                                 ; advance one alien width per row
    jmp @go                                         ; common setup
@blank:                                             ; erase: read the zero byte every row
    lda #<XRAM_BLANK                                ; low byte of the zero byte
    sta blit_src                                    ; erasing reads it
    lda #>XRAM_BLANK                                ; high byte of the zero byte
    sta blit_src+1                                  ; store it
    lda #0                                          ; stride 0 repeats the zero byte
    sta blit_stride                                 ; store it
@go:                                                ; common blit setup
    lda #ALIEN_W_BYTES                              ; 4 bytes wide (8 px)
    sta blit_w                                      ; hand it to the blitter
    lda #8                                          ; 8 rows tall
    sta blit_h                                      ; hand it to the blitter
    ldx grid_i                                      ; reload the index (the code above used Y)
    lda grid_u                                      ; the grid's x offset
    clc                                             ; prepare to add
    adc grid_col_u,x                                ; add this alien's column offset
    sta blit_x                                      ; destination x
    lda grid_row_off,x                              ; this alien's row offset
    clc                                             ; prepare to add
    adc grid_y                                      ; add the grid's top row
    sta blit_y                                      ; destination top row
    jsr blit                                        ; copy the block
@skip:                                              ; move to the next alien
    inc grid_i                                      ; advance the index
    lda grid_i                                      ; the index
    cmp #GRID_COUNT                                 ; past the last alien?
    bne @loop                                       ; no: keep going
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
    inc shots_fired                                 ; count the shot for the saucer's points
    jsr snd_shot                                    ; play the shot sound
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
    jsr erase_bullet                                ; erase the bullet at its old position
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
    jsr check_bombs                                 ; did the bullet hit an alien bomb?
    bne @spent                                      ; yes: the bullet is gone
    jsr check_shields                               ; did the bullet hit a shield cell?
    bne @spent                                      ; yes: the bullet is gone
    jsr check_ufo                                   ; did the bullet hit the saucer?
    bne @spent                                      ; yes: the bullet is gone
    jsr check_hits                                  ; did the bullet hit a grid alien?
    bne @spent                                      ; yes: the bullet is gone
    BLIT XRAM_BULLET_SPRITE, 1, 8, 1, bullet_u, bullet_y ; draw it at its new position
    rts                                             ; return
@spent:                                             ; the bullet hit something
    rts                                             ; return

; Tests the bullet against each living grid alien. Returns A = 1 on a hit,
; after erasing the alien, adding to the score, and ending the bullet.
check_hits:                                         ; bullet vs grid
    lda bullet_y                                    ; the bullet's top row
    clc                                             ; prepare to add
    adc #8                                          ; its bottom row
    sta bullet_b                                    ; store it for every alien test
    lda #0                                          ; start at the first alien
    sta grid_i                                      ; store the index
@loop:                                              ; one alien per pass
    ldx grid_i                                      ; the current alien's index
    lda grid_alive,x                                ; is it alive?
    bne @check                                      ; alive: test it
    jmp @next                                       ; dead: it cannot be hit
@check:                                             ; the alien is alive
    lda grid_row_off,x                              ; the alien's row offset
    clc                                             ; prepare to add
    adc grid_y                                      ; add the grid's top row
    sta hit_y                                       ; remember the alien's top row
    clc                                             ; prepare to add
    adc #8                                          ; the alien's bottom row
    sta hit_b                                       ; remember it
    lda bullet_y                                    ; the bullet's top row
    cmp hit_b                                       ; at or below the alien's bottom?
    bcs @next                                       ; yes: no overlap
    lda hit_y                                       ; the alien's top row
    cmp bullet_b                                    ; at or below the bullet's bottom?
    bcs @next                                       ; yes: no overlap
    lda grid_u                                      ; the grid's x offset
    clc                                             ; prepare to add
    adc grid_col_u,x                                ; the alien's x
    sta hit_x                                       ; remember it
    lda bullet_u                                    ; the bullet's x
    cmp hit_x                                       ; left of the alien?
    bcc @next                                       ; yes: a miss
    sec                                             ; set carry for subtraction
    sbc hit_x                                       ; distance from the alien's left edge
    cmp #ALIEN_W_BYTES                              ; within the alien's width?
    bcs @next                                       ; no: a miss
    BLIT XRAM_BLANK, ALIEN_W_BYTES, 8, 0, hit_x, hit_y ; erase the alien: it is hit
    ldx grid_i                                      ; BLIT used X, so reload the index
    lda #0                                          ; the alien is no longer alive
    sta grid_alive,x                                ; store the flag
    dec alive_count                                 ; one alien fewer: the bassline speeds up
    lda #12                                         ; explosion length in frames
    jsr snd_explode                                 ; play the explosion
    lda grid_points,x                               ; points for this alien's row
    clc                                             ; prepare to add
    adc score                                       ; add to the score's low byte
    sta score                                       ; store the low byte
    bcc @score_done                                 ; no carry out of the low byte: done
    inc score+1                                     ; carry into the high byte
@score_done:                                        ; score is updated
    jsr draw_score                                  ; redraw the score
    lda #0                                          ; the bullet is spent
    sta bullet_active                               ; mark it as gone
    lda #1                                          ; report a hit
    rts                                             ; return
@next:                                              ; move to the next alien
    inc grid_i                                      ; advance the index
    lda grid_i                                      ; the index
    cmp #GRID_COUNT                                 ; past the last alien?
    beq @no_hit                                     ; past the last alien: no hit
    jmp @loop                                       ; no: keep testing
@no_hit:                                            ; every alien was tested
    lda #0                                          ; no hit
    rts                                             ; return

; Finds the leftmost and rightmost living column offsets. Returns A = 1 if
; any alien is alive, else 0. Only living aliens set the edges, as in arcade.
grid_extent:                                        ; scan the grid for its living extent
    lda #$FF                                        ; sentinel: no living column yet
    sta grid_ext_min                                ; start the minimum at the sentinel
    lda #0                                          ; no offset yet
    sta grid_ext_max                                ; start the maximum at zero
    sta grid_ext_low                                ; start the lowest row at zero
    lda #0                                          ; start at the first alien
    sta grid_i                                      ; store the index
@loop:                                              ; one alien per pass
    ldx grid_i                                      ; the current alien's index
    lda grid_alive,x                                ; is it alive?
    beq @next                                       ; no: it does not set an edge
    lda grid_row_off,x                              ; this alien's row offset
    cmp grid_ext_low                                ; lower than the current lowest?
    bcc @not_low                                    ; no: keep it
    beq @not_low                                    ; equal: keep it
    sta grid_ext_low                                ; yes: it is the new lowest
@not_low:                                           ; check the columns
    lda grid_col_u,x                                ; this alien's column offset
    cmp grid_ext_min                                ; left of the current minimum?
    bcs @not_min                                    ; no: keep the minimum
    sta grid_ext_min                                ; yes: this is the new minimum
@not_min:                                           ; check the maximum
    lda grid_col_u,x                                ; this alien's column offset again
    cmp grid_ext_max                                ; right of the current maximum?
    bcc @next                                       ; no: keep the maximum
    beq @next                                       ; equal: nothing changes
    sta grid_ext_max                                ; yes: this is the new maximum
@next:                                              ; move to the next alien
    inc grid_i                                      ; advance the index
    lda grid_i                                      ; the index
    cmp #GRID_COUNT                                 ; past the last alien?
    beq @done                                       ; yes: the scan is complete
    jmp @loop                                       ; no: keep scanning
@done:                                              ; the scan is complete
    lda grid_ext_min                                ; the minimum, or the sentinel
    cmp #$FF                                        ; was any living alien found?
    beq @none                                       ; no
    lda #1                                          ; yes
    rts                                             ; return
@none:                                              ; no living aliens
    lda #0                                          ; report none
    rts                                             ; return

; Moves the grid one step when it is due: erase, shift, toggle frame, redraw.
update_grid:                                        ; move the alien grid
    inc alien_timer                                 ; count a frame
    lda alien_timer                                 ; the frame count
    cmp #ALIEN_STEP_FRAMES                          ; time to move?
    bcs @tick                                       ; yes: move it
    rts                                             ; no: wait
@tick:                                              ; a move is due
    lda #0                                          ; restart the timer
    sta alien_timer                                 ; store it
    jsr grid_extent                                 ; find the living columns
    bne @alive                                      ; some alien is alive: move the grid
    rts                                             ; none left: nothing to move
@alive:                                             ; the grid has living aliens
    jsr erase_grid                                  ; erase the grid at its old position
    lda alien_frame                                 ; current animation frame
    eor #1                                          ; flip between 0 and 1
    sta alien_frame                                 ; store the new frame
    lda alien_dir                                   ; which way is the grid moving?
    cmp #ALIEN_STEP_U                               ; moving right?
    bne @moving_left                                ; no: it is moving left
    lda grid_u                                      ; current grid x
    clc                                             ; prepare to add
    adc grid_ext_max                                ; the rightmost living column
    clc                                             ; prepare to add
    adc #ALIEN_W_BYTES                              ; the right edge of that alien
    cmp #FIELD_RIGHT_U                              ; past the right edge of the field?
    bcs @edge                                       ; yes: drop and turn around
    jmp @sideways                                   ; no: keep moving sideways
@moving_left:                                       ; the grid is moving left
    lda grid_u                                      ; current grid x
    clc                                             ; prepare to add
    adc grid_ext_min                                ; the leftmost living column
    cmp #FIELD_LEFT_U+1                             ; still right of the field's left edge?
    bcs @sideways                                   ; yes: keep moving sideways
@edge:                                              ; the grid reached a screen edge
    lda grid_y                                      ; current top row
    clc                                             ; prepare to add
    adc #GRID_DROP_PY                               ; drop one row
    sta grid_y                                      ; store the new top row
@turn:                                              ; reverse the direction
    lda #0                                          ; start from zero
    sec                                             ; set carry for subtraction
    sbc alien_dir                                   ; negate the step (+4 <-> -4)
    sta alien_dir                                   ; store the new direction
    jmp draw_grid                                   ; draw the dropped grid; no sideways move this step
@sideways:                                          ; move by the direction
    lda grid_u                                      ; current grid x
    clc                                             ; prepare to add
    adc alien_dir                                   ; add the step (may be negative)
    sta grid_u                                      ; store the new grid x
    jmp draw_grid                                   ; draw the grid at its new position

; Returns A = a random byte. A 8-bit Galois LFSR with taps $B8.
rand:                                               ; advance the generator
    lda rng                                         ; the current state
    lsr a                                           ; shift out bit 0 into carry
    bcc @no_tap                                     ; bit 0 was clear: no feedback
    eor #$B8                                        ; bit 0 was set: apply the taps
@no_tap:                                            ; the new state is in A
    sta rng                                         ; store it
    rts                                             ; return the new value

; Returns A = a random column, 0 to GRID_COLS-1.
rand_col:                                           ; pick a random grid column
    jsr rand                                        ; a random byte
@mod:                                               ; reduce it modulo GRID_COLS
    cmp #GRID_COLS                                  ; at least GRID_COLS?
    bcc @done                                       ; no: it is the column
    sec                                             ; set carry for subtraction
    sbc #GRID_COLS                                  ; subtract one column count
    jmp @mod                                        ; check again
@done:                                              ; A is the column
    rts                                             ; return

; Given column A, returns A = index of its lowest living alien, or $FF if none.
find_bottom:                                        ; search one column from the bottom up
    clc                                             ; prepare to add
    adc #GRID_COUNT-GRID_COLS                       ; index of this column's bottom row
    tax                                             ; search from that index
@try:                                               ; test one alien
    lda grid_alive,x                                ; is this alien alive?
    bne @found                                      ; yes: it is the lowest one
    txa                                             ; the current index
    sec                                             ; set carry for subtraction
    sbc #GRID_COLS                                  ; move up one row
    bcc @none                                       ; past the top: no living alien
    tax                                             ; search the row above
    jmp @try                                        ; test it
@found:                                             ; X is the living alien's index
    txa                                             ; return it in A
    rts                                             ; return
@none:                                              ; the column is empty
    lda #$FF                                        ; report none
    rts                                             ; return

; Every fire timer tick, a random column fires from its lowest living alien.
alien_fire:                                         ; maybe launch an alien bomb
    inc fire_timer                                  ; count a frame
    lda fire_timer                                  ; the frame count
    cmp #BOMB_FIRE_FRAMES                           ; time to fire?
    bcs @fire                                       ; yes
    rts                                             ; no: wait
@fire:                                              ; time to try a shot
    lda #0                                          ; restart the timer
    sta fire_timer                                  ; store it
    lda #0                                          ; start at the first bomb slot
    sta bomb_slot                                   ; store the slot
@find_slot:                                         ; look for a free bomb slot
    ldx bomb_slot                                   ; the current slot
    lda bomb_active,x                               ; is it free?
    beq @have_slot                                  ; yes: use it
    inc bomb_slot                                   ; try the next slot
    lda bomb_slot                                   ; the slot number
    cmp #BOMB_MAX                                   ; past the last slot?
    bne @find_slot                                  ; no: keep looking
    rts                                             ; all slots are busy: no new bomb
@have_slot:                                         ; bomb_slot is free
    jsr rand_col                                    ; a random column
    jsr find_bottom                                 ; its lowest living alien, or $FF
    cmp #$FF                                        ; no living alien there?
    bne @spawn                                      ; there is one: fire from it
    rts                                             ; no shot this time
@spawn:                                             ; A = the firing alien's index
    sta grid_i                                      ; remember the index
    tax                                             ; use it to index the column table
    lda grid_col_u,x                                ; the alien's column offset
    clc                                             ; prepare to add
    adc grid_u                                      ; add the grid's x
    clc                                             ; prepare to add
    adc #BOMB_OFFSET_U                              ; center of the alien
    ldx bomb_slot                                   ; the slot to fill
    sta bomb_u,x                                    ; store the bomb's x
    ldx grid_i                                      ; the firing alien's index
    lda grid_row_off,x                              ; its row offset
    clc                                             ; prepare to add
    adc grid_y                                      ; add the grid's top row
    clc                                             ; prepare to add
    adc #8                                          ; the row just below it
    ldx bomb_slot                                   ; the slot to fill
    sta bomb_y,x                                    ; store the bomb's top row
    lda #1                                          ; the slot is in use
    sta bomb_active,x                               ; mark it active
    rts                                             ; return

; Draws the bomb in slot bomb_slot at its position.
bomb_draw:                                          ; draw one alien bomb
    lda #<XRAM_BOMB_SPRITE                          ; low byte of the bomb sprite
    sta blit_src                                    ; source low byte
    lda #>XRAM_BOMB_SPRITE                          ; high byte of the bomb sprite
    sta blit_src+1                                  ; source high byte
    lda #1                                          ; 1 byte wide
    sta blit_w                                      ; store the width
    lda #8                                          ; 8 rows tall
    sta blit_h                                      ; store the height
    lda #1                                          ; sprite rows are 1 byte apart
    sta blit_stride                                 ; store the stride
    ldx bomb_slot                                   ; the bomb's slot
    lda bomb_u,x                                    ; its x
    sta blit_x                                      ; destination x
    lda bomb_y,x                                    ; its top row
    sta blit_y                                      ; destination top row
    jmp blit                                        ; copy the sprite

; Erases the bomb in slot bomb_slot at its position.
bomb_erase:                                         ; erase one alien bomb
    lda #<XRAM_BLANK                                ; low byte of the zero byte
    sta blit_src                                    ; erasing reads the zero byte
    lda #>XRAM_BLANK                                ; high byte of the zero byte
    sta blit_src+1                                  ; store it
    lda #1                                          ; 1 byte wide
    sta blit_w                                      ; store the width
    lda #8                                          ; 8 rows tall
    sta blit_h                                      ; store the height
    lda #0                                          ; stride 0 repeats the zero byte
    sta blit_stride                                 ; store the stride
    ldx bomb_slot                                   ; the bomb's slot
    lda bomb_u,x                                    ; its x
    sta blit_x                                      ; destination x
    lda bomb_y,x                                    ; its top row
    sta blit_y                                      ; destination top row
    jsr blit                                        ; erase the bomb
    ldx bomb_slot                                   ; the bomb's slot
    lda bomb_u,x                                    ; its x
    sta rect_x                                      ; the repair rectangle starts there
    lda bomb_y,x                                    ; its top row
    sta rect_y                                      ; and its top
    jmp repair_rect                                 ; redraw any standing shield cells under it

; Moves every active bomb down one step when due. A bomb that hits the ship
; destroys it; a bomb past the floor is removed.
update_bombs:                                       ; move the alien bombs
    inc bomb_timer                                  ; count a frame
    lda bomb_timer                                  ; the frame count
    cmp #BOMB_STEP_FRAMES                           ; time to move?
    bcs @step                                       ; yes
    rts                                             ; no: wait
@step:                                              ; move the bombs
    lda #0                                          ; restart the timer
    sta bomb_timer                                  ; store it
    lda #0                                          ; start at the first slot
    sta bomb_slot                                   ; store the slot
@loop:                                              ; one slot per pass
    ldx bomb_slot                                   ; the current slot
    lda bomb_active,x                               ; is it in use?
    bne @active                                     ; yes: move it
    jmp @next                                       ; no: skip it
@active:                                            ; the bomb is in flight
    jsr bomb_erase                                  ; erase it at its old position
    ldx bomb_slot                                   ; reload the slot (erase used X)
    lda bomb_y,x                                    ; its top row
    clc                                             ; prepare to add
    adc #BOMB_STEP_PX                               ; move it down one step
    sta bomb_y,x                                    ; store the new row
    cmp #BOMB_FLOOR_PY                              ; still above the floor?
    bcc @inside                                     ; yes
    lda #0                                          ; no: the bomb has left the screen
    sta bomb_active,x                               ; free the slot
    jmp @next                                       ; go to the next slot
@inside:                                            ; the bomb is on screen
    ldx bomb_slot                                   ; the bomb's slot
    lda bomb_u,x                                    ; its x
    sta rect_x                                      ; the rectangle starts there
    lda bomb_y,x                                    ; its top row
    sta rect_y                                      ; and its top
    lda #1                                          ; one unit wide
    sta rect_w                                      ; store the width
    lda #8                                          ; eight rows tall
    sta rect_h                                      ; store the height
    lda #0                                          ; kill the first cell hit
    sta sh_mode                                     ; store the mode
    jsr shield_scan                                 ; does the bomb hit a shield cell?
    beq @no_cell                                    ; no
    ldx bomb_slot                                   ; yes: the bomb is used up
    lda #0                                          ; empty value
    sta bomb_active,x                               ; free the slot
    jmp @next                                       ; go to the next slot
@no_cell:                                           ; the bomb did not hit a shield
    ldx bomb_slot                                   ; the shield scan used X: reload the slot
    lda bomb_y,x                                    ; its top row
    sec                                             ; set carry for subtraction
    sbc #PLAYER_PY                                  ; distance below the ship's top row
    clc                                             ; prepare to add
    adc #7                                          ; the overlap window is -7 to +7 rows
    cmp #15                                         ; within it?
    bcs @no_ship                                    ; no: no vertical overlap
    lda bomb_u,x                                    ; its x
    cmp player_u                                    ; left of the ship?
    bcc @no_ship                                    ; yes: missed
    sec                                             ; set carry for subtraction
    sbc player_u                                    ; distance from the ship's left edge
    cmp #8                                          ; within the 8-unit (16 px) width?
    bcs @no_ship                                    ; no: missed
    lda #0                                          ; the bomb is used up
    sta bomb_active,x                               ; free the slot
    jsr player_die                                  ; the ship is destroyed
    rts                                             ; stop: player_die cleared the other bombs
@no_ship:                                           ; the bomb is still flying
    jsr bomb_draw                                   ; draw it at its new position
@next:                                              ; move to the next slot
    inc bomb_slot                                   ; advance the slot
    lda bomb_slot                                   ; the slot number
    cmp #BOMB_MAX                                   ; past the last slot?
    beq @done                                       ; yes
    jmp @loop                                       ; no: keep going
@done:                                              ; all slots handled
    rts                                             ; return

; Player bullet vs alien bombs. Returns A = 1 if the bullet was absorbed.
; The bullet is destroyed; the bomb survives, as in arcade.
check_bombs:                                        ; bullet vs bombs
    lda #0                                          ; start at the first slot
    sta bomb_slot                                   ; store the slot
@loop:                                              ; one slot per pass
    ldx bomb_slot                                   ; the current slot
    lda bomb_active,x                               ; is it in use?
    beq @next                                       ; no
    lda bomb_u,x                                    ; the bomb's x
    cmp bullet_u                                    ; in the bullet's column?
    bne @next                                       ; no
    lda bomb_y,x                                    ; the bomb's top row
    sec                                             ; set carry for subtraction
    sbc bullet_y                                    ; distance from the bullet's top row
    clc                                             ; prepare to add
    adc #7                                          ; the overlap window is -7 to +7 rows
    cmp #15                                         ; within it?
    bcs @next                                       ; no: no overlap
    lda #0                                          ; the bullet is destroyed
    sta bullet_active                               ; mark it gone
    lda #1                                          ; report: absorbed
    rts                                             ; return
@next:                                              ; move to the next slot
    inc bomb_slot                                   ; advance the slot
    lda bomb_slot                                   ; the slot number
    cmp #BOMB_MAX                                   ; past the last slot?
    bne @loop                                       ; no: keep checking
    lda #0                                          ; no overlap
    rts                                             ; return

; The ship was hit: lose a life, clear the bombs and the bullet, and pause.
player_die:                                         ; destroy the ship
    dec lives                                       ; one ship fewer
    lda #0                                          ; start at the first slot
    sta bomb_slot                                   ; store the slot
@clear:                                             ; clear every bomb on screen
    ldx bomb_slot                                   ; the current slot
    lda bomb_active,x                               ; is it in use?
    beq @skip                                       ; no
    jsr bomb_erase                                  ; erase it
    ldx bomb_slot                                   ; reload the slot
    lda #0                                          ; empty value
    sta bomb_active,x                               ; free the slot
@skip:                                              ; next slot
    inc bomb_slot                                   ; advance the slot
    lda bomb_slot                                   ; the slot number
    cmp #BOMB_MAX                                   ; past the last slot?
    bne @clear                                      ; no: keep clearing
    lda bullet_active                               ; is a player bullet in flight?
    beq @no_bullet                                  ; no
    jsr erase_bullet                                ; erase it and repair the shields under it
    lda #0                                          ; no bullet now
    sta bullet_active                               ; mark it gone
@no_bullet:                                         ; the bullet is cleared
    BLIT XRAM_BLANK, 8, 8, 0, player_u, #PLAYER_PY  ; erase the ship
    lda #1                                          ; the ship is destroyed
    sta player_dead                                 ; mark it
    lda #40                                         ; a long explosion for the ship
    jsr snd_explode                                 ; play it
    lda #DEATH_FRAMES                               ; the pause length
    sta death_timer                                 ; start the pause
    jsr draw_lives                                  ; show the new ship count
    rts                                             ; the pause runs until dead_frame ends it

; Called each frame while the ship is destroyed. Respawns it after the pause.
dead_frame:                                         ; count down the pause
    dec death_timer                                 ; one frame of the pause
    bne @wait                                       ; not finished: keep waiting
    lda lives                                       ; ships left
    bne @respawn                                    ; some are left: respawn
    jmp game_over                                   ; none left: the game is over
@respawn:                                           ; a ship is left
    lda #PLAYER_START_U                             ; back to the starting position
    sta player_u                                    ; store the ship's x
    lda #0                                          ; the ship is alive again
    sta player_dead                                 ; clear the flag
    jsr draw_player                                 ; draw the ship
@wait:                                              ; nothing more to do this frame
    rts                                             ; return

; Shows the number of ships left at the top right of the console.
draw_lives:                                         ; LIVES n on the first row
    lda #0                                          ; row 0
    sta cur_row                                     ; set the row
    lda #33                                         ; column 33, right of the score
    sta cur_col                                     ; set the column
    jsr goto_xy                                     ; move the cursor there
    PUT_STR str_lives, str_lives_len                ; print the label
    lda lives                                       ; the ship count
    jmp put_dec                                     ; print it and return

; Shows GAME OVER in the middle of the screen.
show_game_over:                                     ; the last ship is lost
    lda #12                                         ; console row near the middle
    sta cur_row                                     ; set the row
    lda #16                                         ; column near the middle
    sta cur_col                                     ; set the column
    jsr goto_xy                                     ; move the cursor there
    PUT_STR str_gameover, str_gameover_len          ; print the message
    rts                                             ; return

; ---- game states ----

; Shows the title screen and clears the playfield.
enter_title:                                        ; the title screen
    jsr clear_shots                                 ; remove the bullet and bombs
    jsr erase_grid                                  ; remove the aliens
    jsr shield_clear_all                            ; remove the bunkers
    jsr snd_silence                                 ; stop the sound
    BLIT XRAM_BLANK, 8, 8, 0, player_u, #PLAYER_PY  ; remove the ship
    lda #STATE_TITLE                                ; the title screen
    sta game_state                                  ; store the state
    lda #$0C                                        ; form feed clears the console
    jsr tx_char                                     ; send it
    lda #10                                         ; title row
    sta cur_row                                     ; set the row
    lda #14                                         ; title column
    sta cur_col                                     ; set the column
    jsr goto_xy                                     ; move the cursor there
    PUT_STR str_name, str_name_len                  ; print the game name
    lda #13                                         ; prompt row
    sta cur_row                                     ; set the row
    lda #10                                         ; prompt column
    sta cur_col                                     ; set the column
    jsr goto_xy                                     ; move the cursor there
    PUT_STR str_press, str_press_len                ; print the prompt
    rts                                             ; return

; On the title screen, a new press of Space starts a game.
title_frame:                                        ; wait for Space
    lda #HID_KEY_SPACE                              ; the Space key
    jsr key_held                                    ; is it held?
    pha                                             ; keep this frame's state
    beq @no_start                                   ; not held: do not start
    lda prev_space                                  ; was it held last frame?
    bne @no_start                                   ; yes: not a new press
    jsr new_game                                    ; a new press starts the game
@no_start:                                          ; remember the state for next frame
    pla                                             ; restore this frame's state
    sta prev_space                                  ; store it
    rts                                             ; return

; Starts a fresh game: three ships, score zero, and the first wave.
new_game:                                           ; start a game
    lda #LIVES_START                                ; full set of ships
    sta lives                                       ; store it
    lda #0                                          ; zero for the score
    sta score                                       ; clear the low byte
    sta score+1                                     ; clear the high byte
    lda #PLAYER_START_U                             ; starting x
    sta player_u                                    ; store it
    lda #0                                          ; no pause
    sta player_dead                                 ; the ship is alive
    sta fire_timer                                  ; reset the alien fire timer
    sta bomb_timer                                  ; reset the bomb timer
    sta shots_fired                                 ; a new game counts its shots from zero
    lda #1                                          ; the first bassline note is due at once
    sta bass_timer                                  ; start the bassline clock
    lda #0                                          ; the bassline starts at its first note
    sta bass_idx                                    ; store the index
    sta shot_frames                                 ; no shot sounding
    sta expl_frames                                 ; no explosion sounding
    sta ufo_active                                  ; no saucer at the start
    lda #(256-UFO_STEP_U)                           ; the first saucer goes left, so the first flips it right
    sta ufo_dir                                     ; store the direction
    jsr ufo_schedule                                ; start the countdown to the first saucer
    jsr new_wave                                    ; put the first wave on screen
    lda #$0C                                        ; form feed clears the title
    jsr tx_char                                     ; send it
    jsr draw_score                                  ; the title and score
    lda #1                                          ; second row
    sta cur_row                                     ; set the row
    lda #0                                          ; first column
    sta cur_col                                     ; set the column
    jsr goto_xy                                     ; move the cursor there
    PUT_STR str_help, str_help_len                  ; print the control hint
    jsr draw_lives                                  ; show the ship count
    jsr draw_player                                 ; draw the ship
    lda #STATE_PLAY                                 ; the game is running
    sta game_state                                  ; store the state
    rts                                             ; return

; Puts a full grid at its starting place. Clears shots and erases what was there.
new_wave:                                           ; reset the grid for a wave
    jsr clear_shots                                 ; remove any bullet and bombs
    jsr erase_grid                                  ; remove what is left of the old wave
    lda #GRID_START_U                               ; starting x
    sta grid_u                                      ; store it
    lda #GRID_PY                                    ; starting top row
    sta grid_y                                      ; store it
    lda #ALIEN_STEP_U                               ; start moving right
    sta alien_dir                                   ; store the direction
    lda #0                                          ; first animation frame
    sta alien_frame                                 ; store the frame
    sta alien_timer                                 ; restart the move timer
    lda #GRID_COUNT                                 ; every alien is alive again
    sta alive_count                                 ; store the count
    ldx #GRID_COUNT-1                               ; start at the last alien
@fill:                                              ; mark every alien alive
    lda #1                                          ; alive
    sta grid_alive,x                                ; store the flag
    dex                                             ; the previous alien
    bpl @fill                                       ; until index 0 is set
    jsr shield_reset                                ; every bunker back to its full shape
    jsr shield_draw_all                             ; draw them
    jmp draw_grid                                   ; draw the new wave

; Erases the bullet and every bomb, and empties their slots.
clear_shots:                                        ; remove the bullet, bombs, and saucer
    lda ufo_active                                  ; is a saucer on screen?
    beq @no_ufo                                     ; no
    jsr erase_ufo                                   ; erase it
    lda #0                                          ; no saucer now
    sta ufo_active                                  ; mark it gone
@no_ufo:                                            ; the saucer is cleared
    lda bullet_active                               ; is a bullet in flight?
    beq @no_bullet                                  ; no
    jsr erase_bullet                                ; erase it and repair the shields under it
    lda #0                                          ; no bullet now
    sta bullet_active                               ; mark it gone
@no_bullet:                                         ; the bullet is cleared
    lda #0                                          ; start at the first bomb slot
    sta bomb_slot                                   ; store the slot
@loop:                                              ; one slot per pass
    ldx bomb_slot                                   ; the current slot
    lda bomb_active,x                               ; is it in use?
    beq @next                                       ; no
    jsr bomb_erase                                  ; erase the bomb
    ldx bomb_slot                                   ; reload the slot
    lda #0                                          ; empty value
    sta bomb_active,x                               ; free the slot
@next:                                              ; next slot
    inc bomb_slot                                   ; advance the slot
    lda bomb_slot                                   ; the slot number
    cmp #BOMB_MAX                                   ; past the last slot?
    bne @loop                                       ; no: keep going
    rts                                             ; return

; Each frame during play: a cleared grid starts a wave pause, and a grid whose
; lowest living alien reaches the ship's row ends the game.
play_check:                                         ; check for a cleared wave or a landing
    jsr grid_extent                                 ; the living extent, and A = 1 if any alien lives
    bne @some_alive                                 ; some aliens are alive
    lda #STATE_WAVE                                 ; no aliens left: the wave is cleared
    sta game_state                                  ; store the state
    lda #WAVE_PAUSE_FRAMES                          ; the pause length
    sta state_timer                                 ; start it
    rts                                             ; return
@some_alive:                                        ; aliens remain
    lda grid_y                                      ; the grid's top row
    clc                                             ; prepare to add
    adc grid_ext_low                                ; the lowest living alien's row offset
    bcs @landed                                     ; past 255: certainly below the ship
    cmp #PLAYER_PY-8                                ; reached the ship's row?
    bcc @ok                                         ; no: still above it
@landed:                                            ; the aliens reached the ship
    jmp game_over                                   ; the game is over
@ok:                                                ; nothing has landed
    rts                                             ; return

; Ends the game and shows the game-over message for OVER_FRAMES.
game_over:                                          ; the last ship is lost, or the aliens landed
    lda #STATE_OVER                                 ; the game-over screen
    sta game_state                                  ; store the state
    lda #OVER_FRAMES                                ; how long it stays up
    sta state_timer                                 ; start the countdown
    jmp show_game_over                              ; print the message

; Counts down the wave pause or the game-over screen.
timed_frame:                                        ; count down a pause
    dec state_timer                                 ; one frame
    bne @wait                                       ; not done yet
    lda game_state                                  ; which pause?
    cmp #STATE_OVER                                 ; the game-over screen?
    beq @to_title                                   ; yes: back to the title
    jmp start_next_wave                             ; no: a wave is clear
@to_title:                                          ; return to the title screen
    jmp enter_title
@wait:                                              ; keep waiting
    rts                                             ; return

; Starts the next wave after a cleared wave's pause.
start_next_wave:                                    ; the next wave
    jsr new_wave                                    ; put the wave on screen
    lda #STATE_PLAY                                 ; back to play
    sta game_state                                  ; store the state
    rts                                             ; return

; ---- sound ----

; Sets one PSG channel's envelope: a 50% pulse width, attack, decay, and the
; waveform with its release rate.
.macro PSG_ENV ch, attack, decay, rel              ; set a channel's envelope
    lda #1                                          ; step one byte per access
    sta RIA_STEP0                                   ; portal 0 steps by 1
    lda #<(XRAM_PSG + ch*8 + 2)                     ; the channel's duty byte
    sta RIA_ADDR0                                   ; point portal 0 at it, low
    lda #>(XRAM_PSG + ch*8 + 2)                     ; high byte
    sta RIA_ADDR0+1                                 ; point portal 0 at it, high
    lda #128                                        ; 50% pulse width
    sta RIA_RW0                                     ; duty
    lda #attack                                     ; attack level and rate
    sta RIA_RW0                                     ; attack
    lda #decay                                      ; decay level and rate
    sta RIA_RW0                                     ; decay
    lda #rel                                        ; waveform and release rate
    sta RIA_RW0                                     ; release_wave
.endmacro                                           ; end of PSG_ENV

; Maps the PSG, gives each effect its envelope, and silences every channel.
sound_init:                                         ; set up the PSG
    xreg_ria_psg XRAM_PSG                           ; map the PSG to XRAM
    PSG_ENV 0, $02, $00, $16                        ; shot: square, fast attack, release rate 6
    PSG_ENV 1, $02, $00, $48                        ; explosion: noise, release rate 8
    PSG_ENV 2, $02, $20, $12                        ; bassline: square, short release
    PSG_ENV 3, $02, $00, $34                        ; saucer: triangle, release rate 4
    jmp snd_silence                                 ; no sound yet

; Writes the frequency in ps_lo and ps_hi to the channel at ps_off.
psg_set_freq:                                       ; set a channel's pitch
    lda #1                                          ; step one byte per access
    sta RIA_STEP0                                   ; portal 0 steps by 1
    clc                                             ; prepare to add
    lda ps_off                                      ; the channel's byte offset
    adc #<XRAM_PSG                                  ; add the PSG base, low byte
    sta RIA_ADDR0                                   ; point portal 0 at the frequency, low
    lda #>XRAM_PSG                                  ; the PSG base, high byte
    adc #0                                          ; add the carry
    sta RIA_ADDR0+1                                 ; point portal 0 at the frequency, high
    lda ps_lo                                       ; frequency low byte
    sta RIA_RW0                                     ; write it
    lda ps_hi                                       ; frequency high byte
    sta RIA_RW0                                     ; write it
    rts                                             ; return

; Writes A to the gate (pan_gate byte) of the channel at ps_off. 1 starts a
; note, 0 releases it.
psg_set_gate:                                       ; set a channel's gate
    sta ps_gate                                     ; keep the value
    lda #1                                          ; step one byte per access
    sta RIA_STEP0                                   ; portal 0 steps by 1
    clc                                             ; prepare to add
    lda ps_off                                      ; the channel's byte offset
    adc #<(XRAM_PSG + 6)                            ; add the pan_gate byte's offset, low byte
    sta RIA_ADDR0                                   ; point portal 0 at it, low
    lda #>(XRAM_PSG + 6)                            ; the same, high byte
    adc #0                                          ; add the carry
    sta RIA_ADDR0+1                                 ; point portal 0 at it, high
    lda ps_gate                                     ; the gate value
    sta RIA_RW0                                     ; write it
    rts                                             ; return

sound_offs:                                         ; byte offsets of channels 0 to 3
    .byte 0, 8, 16, 24

; Releases channels 0 to 3 and stops the effects.
snd_silence:                                        ; silence the effects
    lda #0                                          ; no shot sounding
    sta shot_frames                                 ; clear its count
    sta expl_frames                                 ; no explosion sounding
    ldx #3                                          ; start at channel 3
@off:                                               ; release one channel
    lda sound_offs,x                                ; its offset
    sta ps_off                                      ; select it
    lda #0                                          ; gate off
    jsr psg_set_gate                                ; write it
    dex                                             ; the previous channel
    bpl @off                                        ; until channel 0 is released
    rts                                             ; return

; The player's shot: a tone that falls from 1000 Hz on channel 0.
snd_shot:                                           ; start the shot sound
    lda #SND_SHOT_LO                                ; start frequency, low byte
    sta shot_lo                                     ; keep it for the slide
    lda #SND_SHOT_HI                                ; high byte
    sta shot_hi                                     ; keep it
    lda #SND_SHOT_FRAMES                            ; how long it lasts
    sta shot_frames                                 ; start the countdown
    lda #0                                          ; channel 0
    sta ps_off                                      ; select it
    lda shot_lo                                     ; frequency low byte
    sta ps_lo                                       ; for the write
    lda shot_hi                                     ; frequency high byte
    sta ps_hi                                       ; for the write
    jsr psg_set_freq                                ; set the pitch
    lda #1                                          ; gate on: start the note
    jmp psg_set_gate                                ; and return

; Starts the explosion noise on channel 1 for A frames.
snd_explode:                                        ; start the explosion
    sta expl_frames                                 ; how long it lasts
    lda #SND_EXPL_LO                                ; noise rate, low byte
    sta ps_lo                                       ; for the write
    lda #SND_EXPL_HI                                ; high byte
    sta ps_hi                                       ; for the write
    lda #8                                          ; channel 1
    sta ps_off                                      ; select it
    jsr psg_set_freq                                ; set the rate
    lda #1                                          ; gate on
    jmp psg_set_gate                                ; start it

; The saucer's tone on channel 3, and its silence.
snd_ufo_on:                                         ; the saucer's tone
    lda #SND_UFO_LO                                 ; 500 Hz, low byte
    sta ps_lo                                       ; for the write
    lda #SND_UFO_HI                                 ; high byte
    sta ps_hi                                       ; for the write
    lda #24                                         ; channel 3
    sta ps_off                                      ; select it
    jsr psg_set_freq                                ; set the pitch
    lda #1                                          ; gate on
    jmp psg_set_gate                                ; start it

snd_ufo_off:                                        ; the saucer's tone stops
    lda #24                                         ; channel 3
    sta ps_off                                      ; select it
    lda #0                                          ; gate off
    jmp psg_set_gate                                ; release it

; Per frame: the shot's falling pitch, the explosion's end, and the bassline.
update_sound:                                       ; sound for one frame
    lda shot_frames                                 ; is the shot sounding?
    beq @explosion                                  ; no
    dec shot_frames                                 ; one frame of it
    bne @slide                                      ; still going: slide the pitch down
    lda #0                                          ; the shot is over
    sta ps_off                                      ; channel 0
    lda #0                                          ; gate off: release it
    jsr psg_set_gate                                ; write it
    jmp @explosion                                  ; next effect
@slide:                                             ; the pitch falls
    sec                                             ; set carry for subtraction
    lda shot_lo                                     ; low byte
    sbc #<SND_SHOT_STEP                             ; subtract the step, low byte
    sta shot_lo                                     ; store it
    lda shot_hi                                     ; high byte
    sbc #>SND_SHOT_STEP                             ; subtract the step, high byte with borrow
    sta shot_hi                                     ; store it
    lda #0                                          ; channel 0
    sta ps_off                                      ; select it
    lda shot_lo                                     ; frequency low byte
    sta ps_lo                                       ; for the write
    lda shot_hi                                     ; frequency high byte
    sta ps_hi                                       ; for the write
    jsr psg_set_freq                                ; set the new pitch
@explosion:                                         ; the explosion on channel 1
    lda expl_frames                                 ; is it sounding?
    beq @bass                                       ; no
    dec expl_frames                                 ; one frame of it
    bne @bass                                       ; still going
    lda #8                                          ; channel 1
    sta ps_off                                      ; select it
    lda #0                                          ; gate off: release it
    jsr psg_set_gate                                ; write it
@bass:                                              ; the bassline on channel 2
    lda player_dead                                 ; is the ship destroyed?
    beq @bass_on                                    ; no: the bassline plays
    lda #16                                         ; channel 2
    sta ps_off                                      ; select it
    lda #0                                          ; silence it while the ship is down
    jmp psg_set_gate                                ; gate off and return
@bass_on:                                           ; the bassline plays
    dec bass_timer                                  ; one frame until the next note
    beq @note                                       ; time for a note
    rts                                             ; wait
@note:                                              ; the next bassline note
    lda alive_count                                 ; the living aliens
    lsr a                                           ; divide by 4: fewer aliens, faster notes
    lsr a                                           ; second halving
    clc                                             ; prepare to add
    adc #3                                          ; at least 3 frames per note
    sta bass_timer                                  ; store the interval
    lda #16                                         ; channel 2
    sta ps_off                                      ; select it
    ldx bass_idx                                    ; the note index
    lda bass_lo,x                                   ; the note's low byte
    sta ps_lo                                       ; for the write
    lda bass_hi,x                                   ; the note's high byte
    sta ps_hi                                       ; for the write
    inx                                             ; the next note
    txa                                             ; its index
    and #3                                          ; wrap after four notes
    sta bass_idx                                    ; store it
    lda #0                                          ; release the previous note first
    jsr psg_set_gate                                ; gate off
    jsr psg_set_freq                                ; set the new note's pitch
    lda #1                                          ; then start it
    jmp psg_set_gate                                ; gate on

; ---- bonus saucer ----

; Starts the countdown to the next saucer: UFO_BASE_FRAMES plus 0 to 510 frames.
ufo_schedule:                                       ; wait for the next saucer
    jsr snd_ufo_off                                 ; the saucer's tone stops
    jsr rand                                        ; a random byte
    asl a                                           ; double it: 0 to 510
    sta ufo_wait_lo                                 ; the low byte of the random part
    lda #0                                          ; the high byte starts at zero
    rol a                                           ; take the carry from the doubling
    sta ufo_wait_hi                                 ; the high byte of the random part
    lda ufo_wait_lo                                 ; add the base wait, low byte first
    clc                                             ; prepare to add
    adc #<UFO_BASE_FRAMES                           ; low byte of 900
    sta ufo_wait_lo                                 ; store it
    lda ufo_wait_hi                                 ; high byte
    adc #>UFO_BASE_FRAMES                           ; add the base wait's high byte, with carry
    sta ufo_wait_hi                                 ; store it
    rts                                             ; return

; Counts down to the next saucer, then moves the saucer across the top.
update_ufo:                                         ; the bonus saucer
    lda ufo_active                                  ; is one crossing the screen?
    bne @moving                                     ; yes
    lda ufo_wait_lo                                 ; the countdown's low byte
    bne @count_lo                                   ; not zero: count it down
    lda ufo_wait_hi                                 ; the high byte
    beq @appear                                     ; both zero: time for a saucer
    dec ufo_wait_hi                                 ; borrow from the high byte
@count_lo:                                          ; one frame less to wait
    dec ufo_wait_lo                                 ; count the low byte down
    rts                                             ; return
@appear:                                            ; the countdown is over
    jmp ufo_spawn                                   ; start a saucer crossing
@moving:                                            ; a saucer is crossing
    dec ufo_timer                                   ; one frame of its step timer
    beq @step                                       ; the timer ran out: take a step
    rts                                             ; wait
@step:                                              ; move the saucer one step
    lda #UFO_STEP_FRAMES                            ; restart the step timer
    sta ufo_timer                                   ; store it
    jsr erase_ufo                                   ; erase it at its old position
    lda ufo_dir                                     ; which way is it going?
    cmp #UFO_STEP_U                                 ; right?
    bne @left                                       ; no
    lda ufo_x                                       ; its x
    cmp #UFO_RIGHT_U                                ; past the right side?
    bcs @gone                                       ; yes: it has left the screen
    clc                                             ; prepare to add
    adc #UFO_STEP_U                                 ; step right
    sta ufo_x                                       ; store it
    jmp draw_ufo                                    ; draw it there
@left:                                              ; moving left
    lda ufo_x                                       ; its x
    beq @gone                                       ; at the left edge: it has left the screen
    sec                                             ; set carry for subtraction
    sbc #UFO_STEP_U                                 ; step left
    sta ufo_x                                       ; store it
    jmp draw_ufo                                    ; draw it there
@gone:                                              ; the saucer has left the screen
    lda #0                                          ; no saucer now
    sta ufo_active                                  ; mark it gone
    jmp ufo_schedule                                ; wait for the next one

; Starts a saucer. It alternates direction each time, as in arcade.
ufo_spawn:                                          ; start a crossing
    lda #1                                          ; a saucer is on screen
    sta ufo_active                                  ; mark it
    lda #0                                          ; negate the direction
    sec                                             ; set carry for subtraction
    sbc ufo_dir                                     ; +2 becomes $FE, and $FE becomes +2
    sta ufo_dir                                     ; store the new direction
    cmp #UFO_STEP_U                                 ; now moving right?
    bne @from_right                                 ; no
    lda #0                                          ; right: enter at the left edge
    jmp @place                                      ; place it
@from_right:                                        ; left: enter at the right edge
    lda #UFO_RIGHT_U                                ; the right edge
@place:                                             ; A is the starting x
    sta ufo_x                                       ; store it
    lda #UFO_STEP_FRAMES                            ; restart the step timer
    sta ufo_timer                                   ; store it
    jsr snd_ufo_on                                  ; the saucer's tone starts
    jmp draw_ufo                                    ; draw it

draw_ufo:                                           ; draw the saucer at ufo_x
    BLIT XRAM_UFO_SPRITE, 8, 8, 8, ufo_x, #UFO_Y    ; draw it
    rts                                             ; return

erase_ufo:                                          ; erase the saucer at ufo_x
    BLIT XRAM_BLANK, 8, 8, 0, ufo_x, #UFO_Y         ; erase it
    rts                                             ; return

; Player bullet vs saucer. Returns A = 1 if the bullet hit it. The score goes
; up by the points for the shot count, and the saucer is gone.
check_ufo:                                          ; the bullet against the saucer
    lda ufo_active                                  ; is a saucer on screen?
    beq @miss                                       ; no
    lda bullet_y                                    ; the bullet's top row
    sec                                             ; set carry for subtraction
    sbc #UFO_Y                                      ; distance from the saucer's top
    clc                                             ; prepare to add
    adc #7                                          ; the overlap window is -7 to +7 rows
    cmp #15                                         ; within it?
    bcs @miss                                       ; no: not at the saucer's height
    lda bullet_u                                    ; the bullet's x
    sec                                             ; set carry for subtraction
    sbc ufo_x                                       ; distance from the saucer's left edge
    cmp #8                                          ; within its 8 units?
    bcs @miss                                       ; no
    lda #12                                         ; explosion length in frames
    jsr snd_explode                                 ; play the explosion
    jsr erase_ufo                                   ; the saucer is hit
    lda #0                                          ; no saucer now
    sta ufo_active                                  ; mark it gone
    lda #0                                          ; the bullet is used up
    sta bullet_active                               ; mark it gone
    lda shots_fired                                 ; the shot count picks the points
    and #15                                         ; mod 16
    tax                                             ; index the points tables with it
    lda ufo_pts_lo,x                                ; low byte of the points
    clc                                             ; prepare to add
    adc score                                       ; add to the score's low byte
    sta score                                       ; store it
    lda ufo_pts_hi,x                                ; high byte of the points
    adc score+1                                     ; add to the score's high byte, with carry
    sta score+1                                     ; store it
    jsr draw_score                                  ; show the new score
    jsr ufo_schedule                                ; the next saucer comes later
    lda #1                                          ; report: hit
    rts                                             ; return
@miss:                                              ; no hit
    lda #0                                          ; report: no hit
    rts                                             ; return

; ---- shields ----

; Puts every bunker back to its full shape.
shield_reset:                                       ; restore all shield cells
    lda #0                                          ; start at the first bunker
    sta sh_b                                        ; store it
@bunker:                                            ; one bunker per pass
    lda #0                                          ; start at its first cell
    sta sh_c                                        ; use sh_c as the cell number here
@cell:                                              ; one cell per pass
    ldx sh_b                                        ; the bunker
    lda shield_base,x                               ; its first cell index
    clc                                             ; prepare to add
    adc sh_c                                        ; the cell's index in shield_cells
    tay                                             ; index shield_cells with it
    ldx sh_c                                        ; the cell number in the template
    lda shield_template,x                           ; 1 for a cell, 0 for a gap
    sta shield_cells,y                              ; store it
    inc sh_c                                        ; next cell
    lda sh_c                                        ; the cell number
    cmp #SHIELD_CELLS                               ; past the last cell?
    bne @cell                                       ; no: keep going
    inc sh_b                                        ; next bunker
    lda sh_b                                        ; the bunker number
    cmp #SHIELD_COUNT                               ; past the last bunker?
    bne @bunker                                     ; no: keep going
    rts                                             ; return

; Erases every standing shield cell (used when the title screen comes up).
shield_clear_all:                                   ; remove all bunkers
    lda #0                                          ; the rectangle starts at the left edge
    sta rect_x                                      ; store it
    sta rect_y                                      ; and at the top
    lda #200                                        ; wide and tall enough to cover every cell
    sta rect_w                                      ; store the width
    sta rect_h                                      ; store the height
    lda #1                                          ; kill every cell it covers, erasing each
    sta sh_mode                                     ; store the mode
    jmp shield_scan                                 ; scan and erase

; Draws every standing shield cell.
shield_draw_all:                                    ; draw all bunkers
    lda #0                                          ; the rectangle starts at the left edge
    sta rect_x                                      ; store it
    sta rect_y                                      ; and at the top
    lda #200                                        ; wide and tall enough to cover every cell
    sta rect_w                                      ; store the width
    sta rect_h                                      ; store the height
    lda #2                                          ; draw the cells it covers
    sta sh_mode                                     ; store the mode
    jmp shield_scan                                 ; scan and draw

; Repairs the shield cells under the 1x8 rectangle at rect_x, rect_y after a
; bullet or bomb has been erased there.
repair_rect:                                        ; redraw standing cells under a shot's old place
    lda #1                                          ; one unit wide: the shot's width
    sta rect_w                                      ; store it
    lda #8                                          ; eight rows tall: the shot's height
    sta rect_h                                      ; store it
    lda #2                                          ; draw, do not kill
    sta sh_mode                                     ; store the mode
    jmp shield_scan                                 ; scan and draw

; Tests the shield cells against the rectangle at rect_x, rect_y, rect_w, rect_h.
; sh_mode 0 kills the first cell hit and returns A = 1 (A = 0 if none).
; sh_mode 1 kills every cell hit and returns A = 0.
; sh_mode 2 draws every standing cell hit and returns A = 0.
shield_scan:                                        ; test or draw shield cells under a rectangle
    lda #0                                          ; start at the first bunker
    sta sh_b                                        ; store it
@bunker:                                            ; one bunker per pass
    lda #0                                          ; start at its top row
    sta sh_r                                        ; store the row
@row:                                               ; one cell row per pass
    lda #0                                          ; start at its first column
    sta sh_c                                        ; store the column
@cell:                                              ; one cell per pass
    ldx sh_b                                        ; the bunker
    lda shield_base,x                               ; its first cell index
    clc                                             ; prepare to add
    ldx sh_r                                        ; the cell row
    clc                                             ; prepare to add
    adc shield_roff,x                               ; add the row's offset within a bunker
    clc                                             ; prepare to add
    adc sh_c                                        ; add the column: the cell's index
    tay                                             ; index shield_cells with it
    lda shield_cells,y                              ; is this cell standing?
    bne @standing                                   ; yes: test it
    jmp @next                                       ; no: skip it
@standing:                                          ; the cell is standing
    ldx sh_b                                        ; the bunker
    lda shield_left_u,x                             ; its left edge
    clc                                             ; prepare to add
    adc sh_c                                        ; add the column: this cell's x
    sec                                             ; set carry for subtraction
    sbc rect_x                                      ; distance from the rectangle's left edge
    cmp rect_w                                      ; inside the rectangle's width?
    bcc @x_ok                                       ; yes
    jmp @next                                       ; no: no overlap
@x_ok:                                              ; the cell's column is inside the rectangle
    ldx sh_r                                        ; the cell row
    lda shield_row_py,x                             ; the cell's top row
    sec                                             ; set carry for subtraction
    sbc rect_y                                      ; distance below the rectangle's top
    cmp rect_h                                      ; does the cell start inside the rectangle?
    bcc @overlap                                    ; yes
    lda rect_y                                      ; no: does the rectangle start inside the cell?
    ldx sh_r                                        ; reload the row
    sec                                             ; set carry for subtraction
    sbc shield_row_py,x                             ; distance below the cell's top
    cmp #SHIELD_CELL_H                              ; inside the cell's 4 rows?
    bcc @overlap                                    ; yes
    jmp @next                                       ; no: no overlap
@overlap:                                           ; the rectangle covers this cell
    ldx sh_b                                        ; the bunker
    lda shield_left_u,x                             ; its left edge
    clc                                             ; prepare to add
    adc sh_c                                        ; this cell's x
    sta sh_x                                        ; remember it for drawing
    ldx sh_r                                        ; the cell row
    lda shield_row_py,x                             ; this cell's top row
    sta sh_y                                        ; remember it for drawing
    lda sh_mode                                     ; what is the scan for?
    cmp #2                                          ; drawing?
    beq @draw                                       ; yes
    lda #0                                          ; no: the cell is destroyed
    sta shield_cells,y                              ; mark it gone
    BLIT XRAM_BLANK, 1, 4, 0, sh_x, sh_y            ; erase its pixels
    lda sh_mode                                     ; the scan mode again
    bne @next                                       ; mode 1 kills every hit: keep going
    lda #1                                          ; mode 0: report the hit
    rts                                             ; and stop
@draw:                                              ; draw the standing cell
    BLIT XRAM_SHIELD_BLOCK, 1, 4, 0, sh_x, sh_y     ; draw it
@next:                                              ; move to the next cell
    inc sh_c                                        ; next column
    lda sh_c                                        ; the column
    cmp #SHIELD_COLS                                ; past the last column?
    beq @next_row                                   ; yes
    jmp @cell                                       ; no: next cell
@next_row:                                          ; move to the next row
    inc sh_r                                        ; next row
    lda sh_r                                        ; the row
    cmp #SHIELD_ROWS                                ; past the last row?
    beq @next_bunker                                ; yes
    jmp @row                                        ; no: next row
@next_bunker:                                       ; move to the next bunker
    inc sh_b                                        ; next bunker
    lda sh_b                                        ; the bunker
    cmp #SHIELD_COUNT                               ; past the last bunker?
    beq @done                                       ; yes
    jmp @bunker                                     ; no: next bunker
@done:                                              ; scan complete
    lda #0                                          ; no cell was taken in the scan
    rts                                             ; return

; Player bullet vs shields. Returns A = 1 if the bullet was absorbed.
check_shields:                                      ; the bullet against the bunkers
    lda bullet_u                                    ; the bullet's x
    sta rect_x                                      ; the scan's rectangle starts there
    lda bullet_y                                    ; the bullet's top row
    sta rect_y                                      ; and its top
    lda #1                                          ; one unit wide
    sta rect_w                                      ; store the width
    lda #8                                          ; eight rows tall
    sta rect_h                                      ; store the height
    lda #0                                          ; kill the first cell hit
    sta sh_mode                                     ; store the mode
    jsr shield_scan                                 ; test the cells
    beq @miss                                       ; no cell was hit
    lda #0                                          ; the bullet is destroyed
    sta bullet_active                               ; mark it gone
    lda #1                                          ; report: absorbed
    rts                                             ; return
@miss:                                              ; the bullet got through
    lda #0                                          ; report: not absorbed
    rts                                             ; return

; Erases the player bullet at its position, then repairs any shield under it.
erase_bullet:                                       ; erase the player bullet
    BLIT XRAM_BLANK, 1, 8, 0, bullet_u, bullet_y    ; erase its pixels
    lda bullet_u                                    ; its x
    sta rect_x                                      ; the repair rectangle starts there
    lda bullet_y                                    ; its top row
    sta rect_y                                      ; and its top
    jmp repair_rect                                 ; redraw any standing shield cells under it

; Aliens low enough to reach the bunkers destroy the cells they cover.
shield_contact:                                     ; living aliens against the shields
    lda #0                                          ; start at the first alien
    sta grid_i                                      ; store the index
@loop:                                              ; one alien per pass
    ldx grid_i                                      ; the current alien's index
    lda grid_alive,x                                ; is it alive?
    beq @next                                       ; no
    lda grid_row_off,x                              ; its row offset
    clc                                             ; prepare to add
    adc grid_y                                      ; its top row
    bcs @next                                       ; past the top of the byte: far below the shields, handled by landing
    cmp #SHIELD_PY-7                                ; its bottom row (top + 8) below the shields' top?
    bcc @next                                       ; no: above the shields
    sta rect_y                                      ; the rectangle's top row
    ldx grid_i                                      ; reload the index
    lda grid_u                                      ; the grid's x
    clc                                             ; prepare to add
    adc grid_col_u,x                                ; this alien's x
    sta rect_x                                      ; the rectangle's x
    lda #ALIEN_W_BYTES                              ; the alien's width
    sta rect_w                                      ; store it
    lda #8                                          ; the alien's height
    sta rect_h                                      ; store it
    lda #1                                          ; kill every cell it covers
    sta sh_mode                                     ; store the mode
    jsr shield_scan                                 ; destroy the covered cells
@next:                                              ; next alien
    inc grid_i                                      ; advance the index
    lda grid_i                                      ; the index
    cmp #GRID_COUNT                                 ; past the last alien?
    bne @loop                                       ; no: keep going
    rts                                             ; return
