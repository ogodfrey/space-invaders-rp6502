#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

struct japanese_number
{
    int num;
    char name[5];
};

static const struct japanese_number JN[6] = {
    {1, "ICHI"}, {2, "NI"}, {3, "SAN"}, {4, "SHI"}, {5, "GO"}, {6, "ROKU"}
};

/* cc65 limits locals per function, so the large buffers are static. */
static char line[256];
static char potstr[256];
static char bet[256];

/* Reads one whitespace-delimited word from a line of input. */
static void read_word(char *word)
{
    word[0] = '\0';
    if (fgets(line, sizeof line, stdin))
    {
        sscanf(line, "%255s", word);
    }
}

int main(void)
{
    long purse = 5000;
    srand((unsigned int)time(NULL));

    while (1)
    {
        long pot;
        int dice1;
        int dice2;
        int playerWon;
        const char *correctBet;

        while (1)
        {
            int bIssue = 0;
            size_t i;

            printf("You have %ld money.  How much do you bet? (or QUIT):  ", purse);
            read_word(potstr);

            if (!stricmp(potstr, "QUIT"))
            {
                puts("Thanks for playing!");
                exit(0);
            }

            if (potstr[0] == '\0')
            {
                bIssue = 1;
            }
            for (i = 0; potstr[i]; i++)
            {
                if (!isdigit((unsigned char)potstr[i]))
                {
                    bIssue = 1;
                    break;
                }
            }

            if (bIssue)
            {
                puts("Please enter a number.");
                continue;
            }

            pot = atol(potstr);
            if (pot > purse)
            {
                printf("You only have %ld money\n", purse);
                continue;
            }
            else
            {
                break;
            }
        }

        /* roll dice: indices 0..5 map to the 1..6 entries in JN */
        dice1 = rand() % 6;
        dice2 = rand() % 6;

        puts("The dealer swirls the cup and you hear the rattle of dice.");
        puts("The dealer slams the cup on the floor, still covering the");
        puts("dice and asks for your bet.\n");
        printf("  CHO (even) or HAN (odd)?  ");

        while (1)
        {
            read_word(bet);

            if (stricmp(bet, "CHO") && stricmp(bet, "HAN"))
            {
                printf("Please enter either 'CHO' or 'HAN':  ");
            }
            else
            {
                break;
            }
        }

        puts("The dealer lifts the cup to reveal: ");
        printf("  %s - %s\n", JN[dice1].name, JN[dice2].name);
        printf("    %d - %d\n", JN[dice1].num, JN[dice2].num);

        /* odd total of pips means HAN wins, even means CHO */
        correctBet = ((JN[dice1].num + JN[dice2].num) % 2) ? "HAN" : "CHO";
        playerWon = (stricmp(bet, correctBet) == 0);

        if (playerWon)
        {
            printf("You won!  You take %ld money.\n", pot);
            purse = purse + pot;
            printf("The house collects a %ld fee.\n", pot / 10);
            purse = purse - (pot / 10);
        }
        else
        {
            purse = purse - pot;
            puts("You lost!");
        }

        if (purse <= 0)
        {
            puts("You have run out of money!\nThanks for playing!");
            exit(0);
        }
    }
}
