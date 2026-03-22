/**
 * @file    game.c
 * @brief   Core game logic: character selection, input validation,
 *          lives tracking, level progression, and end-of-level stats.
 * @author  Shipra  & Marcel 
 * @course  CSU23021 - Microprocessor Systems, TCD 2025/2026
 */

#include <stdio.h>
#include <string.h>
#include <stdbool.h>
#include <stdlib.h>
#include "pico/stdlib.h"
#include "game.h"

// ================================================================
//  MORSE LOOKUP TABLE  (A-Z and 0-9)
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
//  SHARED MEMORY - defined in William's assign02.S
//  The ASM GPIO handler fills morse_input_buffer with '.' and '-'
//  characters and sets morse_input_ready = 1 when done.
// ================================================================
extern volatile char morse_input_buffer[16];
extern volatile int  morse_input_ready;

// ================================================================
//  INTERNAL HELPERS
// ================================================================
/**
 * @brief  Looks up the Morse string for a given character.
 * @return Pointer to the Morse string, or NULL if not in table.
 */
static const char *lookup_morse(char c) {
    for (int i = 0; i < (int)TABLE_SIZE; i++) {
        if (MORSE_TABLE[i].symbol == c) {
            return MORSE_TABLE[i].morse;
        }
    }
    return NULL;
}

/**
 * @brief  Picks a pseudo-random character from CHAR_POOL.
 *         Uses time_us_32() as a simple seed source on the Pico.
 */
static char pick_character(void) {
    return CHAR_POOL[time_us_32() % POOL_SIZE];
}

// ================================================================
//  INPUT HANDLER
// ================================================================
/**
 * @brief  Blocks until William's ASM handler signals that the
 *         player has finished entering a Morse sequence, then
 *         copies the result into out_buf.
 */
static void wait_for_input(char *out_buf, int buf_size) {
    morse_input_ready = 0;

    printf("  [ Waiting for GP21 input... ]\n");

    while (!morse_input_ready) {
        tight_loop_contents();    
    }

    strncpy(out_buf, (const char *)morse_input_buffer, buf_size - 1);
    out_buf[buf_size - 1] = '\0';

    // Clear shared buffer ready for the next round
    morse_input_ready = 0;
    memset((void *)morse_input_buffer, 0, sizeof(morse_input_buffer));
}

// ================================================================
//  PUBLIC FUNCTIONS
// ================================================================
/**
 * @brief  See game.h
 */
char decode_morse(const char *morse_str) {
    for (int i = 0; i < (int)TABLE_SIZE; i++) {
        if (strcmp(MORSE_TABLE[i].morse, morse_str) == 0) {
            return MORSE_TABLE[i].symbol;
        }
    }
    return '?';
}

/**
 * @brief  See game.h
 */
bool run_single_char_round(int level) {
    char        target      = pick_character();
    const char *target_morse = lookup_morse(target);
    char        player_buf[16];

    printf("\n----------------------------------------------------------\n");

    // Level 1 shows the Morse hint; Level 2 does not
    if (level == 1) {
        printf("  Character :  %c\n", target);
        printf("  Morse hint:  %s\n", target_morse);
    } else {
        printf("  Character :  %c\n", target);
        printf("  Morse hint:  (hidden - Level 2)\n");
    }

    printf("  Enter the Morse code for '%c' using GP21:\n\n", target);

    // Block until player finishes input
    wait_for_input(player_buf, sizeof(player_buf));

    // Decode what the player typed so we can display it back
    char decoded = decode_morse(player_buf);

    printf("\n  You entered  :  %s\n", player_buf);
    printf("  Decoded as   :  '%c'\n", decoded);

    // Compare player input against expected Morse string
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

/**
 * @brief  See game.h
 */
bool run_level(int level, int *lives) {
    int streak         = 0;     // consecutive correct answers
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

            // Cap lives at 3
            if (*lives < 3) {
                (*lives)++;
            }
            printf("  Lives: %d  |  Streak: %d / 5\n", *lives, streak);

        } else {
            streak = 0;
            (*lives)--;
            printf("  Lives: %d  |  Streak reset\n", *lives);
        }

        // --------------------------------------------------------
        // Marcel: call update_led(*lives) here once his LED
        //         functions are ready, e.g:
        //         update_led_for_lives(*lives);
        // --------------------------------------------------------

        // Check level-pass condition
        if (streak >= 5) {
            printf("\n  ** LEVEL %d COMPLETE! **\n", level);
            printf("  Final score: %d correct out of %d  (%d%%)\n",
                   total_correct,
                   total_rounds,
                   (total_correct * 100) / total_rounds);
            return true;
        }

        // Check game-over condition
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