#include <fcntl.h>
#include <rp6502.h>
#include <stdio.h>
#include <unistd.h>

static unsigned char buffer[512];
unsigned char pcm_short_writes;
unsigned char pcm_zero_writes;

static void wait_frame(void)
{
    unsigned char frame = RIA.vsync;
    while (RIA.vsync == frame) {
    }
}

static int play(int pcm, const char *path)
{
    int input = open(path, O_RDONLY);
    int count;

    if (input < 0) {
        perror("open sample");
        return -1;
    }
    while ((count = read(input, buffer, sizeof(buffer))) > 0) {
        unsigned offset = 0;
        while (offset < (unsigned)count) {
            int written = write_xstack(buffer + offset, count - offset, pcm);
            if (written < 0) {
                perror("write PCM");
                if (close(input) < 0) {
                    perror("close sample");
                }
                return -1;
            }
            if (written < count - offset) {
                ++pcm_short_writes;
            }
            if (written == 0) {
                ++pcm_zero_writes;
                wait_frame();
            } else {
                offset += written;
            }
        }
    }
    if (count < 0) {
        perror("read sample");
        if (close(input) < 0) {
            perror("close sample");
        }
        return -1;
    }
    if (close(input) < 0) {
        perror("close sample");
        return -1;
    }
    if (syncfs(pcm) < 0) {
        perror("drain PCM");
        return -1;
    }
    return 0;
}

int main(void)
{
    int pcm = open("PCM:8000,16,1", O_WRONLY);
    int result = 0;
    unsigned char previous = 0;
    unsigned char previous_tone = 0;
    unsigned char tone = 0;
    unsigned char channel;

    if (pcm < 0) {
        perror("PCM requires RP6502 0.43");
        return 1;
    }
    if (xreg(0, 0, 0, 0x1000) < 0) {
        perror("map keyboard");
        if (close(pcm) < 0) {
            perror("close PCM");
        }
        return 1;
    }
    if (xreg(0, 1, 0, 0x1100) < 0) {
        perror("map PSG");
        if (close(pcm) < 0) {
            perror("close PCM");
        }
        return 1;
    }
    for (channel = 0; channel < 8; ++channel) {
        xram0_poke8(0x1106 + channel * 8, 0);
    }
    xram0_poke16(0x1100, 1350);
    xram0_poke8(0x1102, 128);
    xram0_poke8(0x1103, 0x90);
    xram0_poke8(0x1104, 0x90);
    xram0_poke8(0x1105, 0x12);
    puts("PCM PROTOTYPE - RP6502 0.43");
    puts("1: SHOT  2: SHIP EXPLOSION  3: PSG TONE  Q: QUIT");
    for (;;) {
        unsigned char keys = xram0_peek8(0x1003);
        unsigned char pressed = keys & ~previous;
        unsigned char tone_key = xram0_peek8(0x1004) & 1;
        previous = keys;
        if (tone_key && !previous_tone) {
            tone ^= 1;
            xram0_poke8(0x1106, tone);
            puts(tone ? "PSG ON" : "PSG OFF");
        }
        previous_tone = tone_key;
        if (pressed & 0x40) {
            result = play(pcm, "ROM:shot.pcm");
        } else if (pressed & 0x80) {
            result = play(pcm, "ROM:explosion.pcm");
        } else if (xram0_peek8(0x1002) & 0x10) {
            break;
        }
        if (result < 0) {
            break;
        }
        if (pressed & 0xc0) {
            puts("DONE");
        }
        wait_frame();
    }
    xram0_poke8(0x1106, 0);
    if (close(pcm) < 0) {
        perror("close PCM");
        return 1;
    }
    return result < 0 ? 1 : 0;
}
