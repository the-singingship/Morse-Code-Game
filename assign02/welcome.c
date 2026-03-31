/**
 * @file    welcome.c
 * @brief   Prints the startup welcome banner and game instructions.
 *          This is called once at the very beginning of the program.
*/

#include <stdio.h>
#include "welcome.h"
#include "pico/stdlib.h"

#define BORDER  "+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+\n"
#define THIN    "----------------------------------------------------------\n"

// ================================================================
//  STRING PRINTING EFFECTS
// ================================================================
static void print_slow(const char *str, int delay_ms) {
    while (*str) {
        putchar(*str++);
        fflush(stdout);
        sleep_ms(delay_ms);
    }
}
static void print_fast(const char *str) {
    printf("%s", str);
    fflush(stdout);
}

void print_welcome(void) {

    printf("\n\n");
    print_fast(BORDER);
    print_slow("|                                                         |\n", 20);
    print_slow("|      W E L C O M E   T O   T H E   C S U 2 3 0 2 1      |\n", 20);
    print_slow("|                                                         |\n", 20);
    print_fast(BORDER);
    sleep_ms(600);

    // GROUP 2 ASCII art 
    print_slow("  * * *   * * *    * * *   *     *  * * *          * * *   \n", 10);
    print_slow(" *        *     *  *     * *     *  *     *             *  \n", 10);
    print_slow(" *  * *   * * *    *     * *     *  * * *           * * *  \n", 10);
    print_slow(" *     *  *   *    *     * *     *  *              *       \n", 10);
    print_slow("  * * *   *     *   * * *   * * *   *              * * * * \n", 10);
    printf("\n");
    sleep_ms(300);

    // LEARN ASCII art
    print_slow(" *        * * * *  * * *   * * *    *     *  \n", 10);
    print_slow(" *        *        *     * *     *  * *   *  \n", 10);
    print_slow(" *        * * *    * * * * * * *    *   * *  \n", 10);
    print_slow(" *        *        *     * *   *    *     *  \n", 10);
    print_slow(" * * * *  * * * *  *     * *     *  *     *  \n", 10);
    printf("\n");
    sleep_ms(300);

    // MORSE ASCII art
    print_slow(" *       *    * *    * * *    * * *   * * * *      * * *     * *    * * *    * * * *  \n", 10);
    print_slow(" *  *  * *  *     *  *     * *        *           *        *     *  *     *  *        \n", 10);
    print_slow(" *   *   *  *     *  * * *    * * *   * * *       *        *     *  *     *  * * *    \n", 10);
    print_slow(" *       *  *     *  *   *         *  *           *        *     *  *     *  *        \n", 10);
    print_slow(" *       *   * * *   *     *  * * *   * * * *      * * *    * * *   * * *    * * * * \n", 10);
    printf("\n");
    sleep_ms(400);

    // Button instructions 
    print_fast(THIN);
    print_slow("  HOW TO USE THE BUTTON (GP21):\n", 20);
    print_fast(THIN);
    print_slow("   Short press  (<250ms)  -->  DOT   [ .  ]\n", 20);
    print_slow("   Long  press  (>250ms)  -->  DASH  [ -  ]\n", 20);
    print_slow("   Wait  ~1 sec after last input  -->  SPACE\n", 20);
    print_slow("   Wait  ~2 sec after last input  -->  SUBMIT sequence\n", 20);
    printf("\n");
    sleep_ms(300);

    // Game levels 
    print_fast(THIN);
    print_slow("  GAME LEVELS:\n", 20);
    print_fast(THIN);
    print_slow("   Level 1  |  Single character  |  Morse hint shown\n", 20);
    print_slow("   Level 2  |  Single character  |  No hint\n", 20);
    print_slow("   Level 3  |  Full word         |  Morse hint shown\n", 20);
    print_slow("   Level 4  |  Full word         |  No hint\n", 20);
    printf("\n");
    sleep_ms(300);

    // Lives & scoring 
    print_fast(THIN);
    print_slow("  LIVES & SCORING:\n", 20);
    print_fast(THIN);
    print_slow("   Start      -->  3 lives  (LED = GREEN)\n", 20);
    print_slow("   Correct     -->  +1 life  (max 3)\n", 20);
    print_slow("   Incorrect   -->  -1 life\n", 20);
    print_slow("   0 lives     -->  Game over  (LED = RED)\n", 20);
    print_slow("   5 in a row  -->  Level up!\n", 20);
    printf("\n");
    sleep_ms(300);

    print_fast(BORDER);
    print_slow("|   RGB LED is BLUE  -->  no game in progress            |\n", 20);
    print_fast(BORDER);
    printf("\n");
    sleep_ms(500);
}