#ifndef GAME_H
#define GAME_H

/**
 * @file    game.h
 * @brief   Game logic for single-character and word-level Morse rounds.
 * @author  Shipra
 * @course  CSU23021 - Microprocessor Systems, TCD 2025/2026
 */

#include <stdbool.h>

/**
 * @brief  Runs a single question round for the given level.
 *         Displays a character (with or without Morse hint),
 *         reads the player's Morse input, and checks correctness.
 * @param  level   Current game level (1-4)
 * @return true if player answered correctly, false otherwise
 */
bool run_single_char_round(int level);

/**
 * @brief  Runs a complete level loop until the player either
 *         gets 5 correct in a row (pass) or loses all lives (fail).
 * @param  level   Level number to run (1 or 2 for single chars)
 * @param  lives   Pointer to the current lives count (modified in place)
 * @return true if level passed, false if game over
 */
bool run_level(int level, int *lives);

/**
 * @brief  Decodes a Morse string (e.g. ".-") back to its character.
 * @param  morse_str   Null-terminated Morse string using '.' and '-'
 * @return The matching alphanumeric character, or '?' if unrecognised
 */
char decode_morse(const char *morse_str);

#endif