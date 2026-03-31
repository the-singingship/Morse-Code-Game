/**
 * @file    game.c
 * @brief   Core game logic: character selection, input validation,
 *          lives tracking, level progression, and end-of-level stats.
 */

#include <stdio.h>
#include <string.h>
#include <stdbool.h>
#include <stdlib.h>
#include "pico/stdlib.h"
#include "hardware/watchdog.h"
#include "game.h"

// ================================================================
//  SHARED MEMORY WITH ASM
// ================================================================
volatile char morse_input_buffer[16] = {0};
volatile int  morse_input_ready = 0;

// ================================================================
//  ASM FUNCTION — check_space() lives in main_asm.S
// ================================================================
extern void check_space(void);

// ================================================================
//  MORSE LOOKUP TABLE  (A to Z and 0 to 9)
// ================================================================
typedef struct {
    char        symbol;
    const char *morse;
} MorseEntry;

static const MorseEntry MORSE_TABLE[] = {
    {'A', ".-"},    {'B', "-..."},  {'C', "-.-."},
    {'D', "-.."},   {'E', "."},     {'F', "..-."},
    {'G', "--."},   {'H', "...."},  {'I', ".."},
    {'J', ".---"},  {'K', "-.-"},   {'L', ".-.."},
    {'M', "--"},    {'N', "-."},    {'O', "---"},
    {'P', ".--."},  {'Q', "--.-"},  {'R', ".-."},
    {'S', "..."},   {'T', "-"},     {'U', "..-"},
    {'V', "...-"},  {'W', ".--"},   {'X', "-..-"},
    {'Y', "-.--"},  {'Z', "--.."},
    {'0', "-----"}, {'1', ".----"}, {'2', "..---"},
    {'3', "...--"}, {'4', "....-"}, {'5', "....."},
    {'6', "-...."}, {'7', "--..."}, {'8', "---.."}, {'9', "----."}
};

#define TABLE_SIZE  (sizeof(MORSE_TABLE) / sizeof(MORSE_TABLE[0]))

// Pool of characters shown to the player during single-char levels
static const char CHAR_POOL[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
#define POOL_SIZE   (sizeof(CHAR_POOL) - 1)

// ================================================================
//  SHARED MEMORY 
// ================================================================
extern volatile char morse_input_buffer[16];
extern volatile int  morse_input_ready;

// ================================================================
//  INTERNAL HELPERS
// ================================================================
static const char *lookup_morse(char c) {
    for (int i = 0; i < (int)TABLE_SIZE; i++) {
        if (MORSE_TABLE[i].symbol == c) {
            return MORSE_TABLE[i].morse;
        }
    }
    return NULL;
}

static char pick_character(void) {
    return CHAR_POOL[time_us_32() % POOL_SIZE];
}


// ================================================================
//  MORSE DECODING
// ================================================================

/**
 * @brief Decode a morse signal into a character
 */
char decode_morse(const char *input) {
    for (int i = 0; i < (int)TABLE_SIZE; i++) {
        if (strcmp(input, MORSE_TABLE[i].morse) == 0) {
            return MORSE_TABLE[i].symbol;
        }
    }
    return '?';
}

// Print the decoded morse letter
void print_morse(const char *buffer) {
    char letter = decode_morse(buffer);
    printf("%c", letter);
}


// ================================================================
//  INPUT HANDLER
//  Polls check_space() (ASM) at each iteration so the gap-detection
//  logic runs without wfi logic in loop.
//  When a >= SPACE_TIME gap is detected, dot/dash buffer is 
//  copied to morse_input_buffer and sets morse_input_ready,
//  which unblocks this loop.
// ================================================================
static void wait_for_input(char *out_buf, int buf_size) {
    morse_input_ready = 0;

    printf("  [ Waiting for GP21 input... ]\n");

    while (!morse_input_ready) {
        watchdog_update();        // kicks watchdog on every loop
        check_space();            
        tight_loop_contents();    
    }

    strncpy(out_buf, (const char *)morse_input_buffer, buf_size - 1);
    out_buf[buf_size - 1] = '\0';

    morse_input_ready = 0;
    memset((void *)morse_input_buffer, 0, sizeof(morse_input_buffer));
}

// ================================================================
//  DIFFICULTY MODE SELECTION
// ================================================================
int select_difficulty(void) {
    char input_buf[16];

    printf("----------------------------------------------------------\n");
    printf("  SELECT YOUR DIFFICULTY (enter Morse for (E)asy / (H)ard):\n");
    printf("----------------------------------------------------------\n");
    printf("   (E)asy  =  [ . ]         (dit )\n");
    printf("   (H)ard  =  [ . . . . ]   (dit dit dit dit)\n");
    printf("\n");

    while (1) {
        watchdog_update();       // Keep watchdog happy while waiting for valid input
        printf("  ENTER DIFFICULTY SELECTION (GP21):\n");
        wait_for_input(input_buf, sizeof(input_buf));

        char selection = decode_morse(input_buf);

        if (selection == 'E') {
            printf("\n > EASY MODE SELECTED \n");
            return 1; // Easy
        } 

        if (selection == 'H') {
            printf("\n >>> HARD MODE SELECTED \n");
            return 2; // Hard
        } 

        printf("    Invalid choice. Try again. \n\n");
    }
}


// ================================================================
//  PUBLIC FUNCTIONS
// ================================================================
bool run_single_char_round(int level) {
    char        target      = pick_character();
    const char *target_morse = lookup_morse(target);
    char        player_buf[16];

    printf("\n----------------------------------------------------------\n");

    if (level == 1) {
        printf("  Character :  %c\n", target);
        printf("  Morse hint:  %s\n", target_morse);
    } else {
        printf("  Character :  %c\n", target);
        printf("  Morse hint:  (hidden - Level 2)\n");
    }

    printf("  Enter the Morse code for '%c' using GP21:\n\n", target);

    wait_for_input(player_buf, sizeof(player_buf));

    char decoded = decode_morse(player_buf);

    printf("\n  You entered  :  %s\n", player_buf);
    printf("  Decoded as   :  '%c'\n", decoded);

    bool correct = (strcmp(player_buf, target_morse) == 0);

    if (correct) {
        printf("  >> CORRECT! Great work!\n");
    } else {
        printf("  >> INCORRECT. '%c' in Morse is: %s\n",
               target, target_morse);
    }

    printf("----------------------------------------------------------\n");
    return correct;
}

bool run_level(int level, int *lives) {
    int streak         = 0;
    int total_correct  = 0;
    int total_rounds   = 0;

    printf("\n==========================================================\n");
    printf("  LEVEL %d  |  Lives: %d  |  Need 5 in a row to advance\n",
           level, *lives);
    printf("==========================================================\n");

    while (1) {
        bool correct = run_single_char_round(level);
        total_rounds++;

        if (correct) {
            total_correct++;
            streak++;

            if (*lives < 3) {
                (*lives)++;
            }
            printf("  Lives: %d  |  Streak: %d / 5\n", *lives, streak);

        } else {
            streak = 0;
            (*lives)--;
            printf("  Lives: %d  |  Streak reset\n", *lives);
        }

        if (streak >= 5) {
            printf("\n  ** LEVEL %d COMPLETE! **\n", level);
            printf("  Final score: %d correct out of %d  (%d%%)\n",
                   total_correct,
                   total_rounds,
                   (total_correct * 100) / total_rounds);
            return true;
        }

        if (*lives <= 0) {
            printf("\n  ** GAME OVER - No lives remaining **\n");
            printf("  Final score: %d correct out of %d  (%d%%)\n",
                   total_correct,
                   total_rounds,
                   (total_correct * 100) / total_rounds);
            return false;
        }
    }
}