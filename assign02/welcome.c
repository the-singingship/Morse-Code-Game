/**
 * @file    welcome.c
 * @brief   Prints the startup welcome banner and game instructions.
 *          This is called once at the very beginning of the program.
 */

#include <stdio.h>
#include "welcome.h"

//  CONSTANTS
#define BORDER  "+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+\n"
#define THIN    "----------------------------------------------------------\n"

//  print_welcome()
//  Displays the group banner and instructions once at startup.
//  The RGB LED should already be set to BLUE before this is called.
void print_welcome(void) {

    printf("\n\n");
    printf(BORDER);
    printf("|                                                         |\n");
    printf("|      W E L C O M E   T O   T H E   C S U 2 3 0 2 1      |\n");
    printf("|                                                         |\n");
    printf(BORDER);
    printf("\n");
    printf("\n");

    // G R O U P   2
    printf("  * * *   * * *    * * *   *     *  * * *          * * *   \n");
    printf(" *        *     *  *     * *     *  *     *             *  \n");
    printf(" *  * *   * * *    *     * *     *  * * *           * * *  \n");
    printf(" *     *  *   *    *     * *     *  *              *       \n");
    printf("  * * *   *     *   * * *   * * *   *              * * * * \n");
    printf("\n");

    // L E A R N
    printf(" *        * * * *  * * *   * * *    *     *  \n");
    printf(" *        *        *     * *     *  * *   *  \n");
    printf(" *        * * *    * * * * * * *    *   * *  \n");
    printf(" *        *        *     * *   *    *     *  \n");
    printf(" * * * *  * * * *  *     * *     *  *     *  \n");
    printf("\n");

    // M O R S E   C O D E
    printf(" *     *   * * *   * * *    * * *   * * * *     * * *    * * *   * * *    * * * *  \n");
    printf(" * * * *  *     *  *     * *        *           *        *     *  *     * *        \n");
    printf(" *  *  *  *     *  * * *    * * *   * * *       *        *     *  *     * * * *    \n");
    printf(" *     *  *     *  *   *         *  *           *        *     *  *     * *        \n");
    printf(" *     *   * * *   *     *  * * *   * * * *      * * *    * * *   * * *    * * * * \n");
    printf("\n");
    printf("\n");

    printf(THIN);
    printf("  HOW TO USE THE BUTTON (GP21):\n");
    printf(THIN);
    printf("   Short press  (<250ms)  -->  DOT   [ .  ]\n");
    printf("   Long  press  (>250ms)  -->  DASH  [ -  ]\n");
    printf("   Wait  ~1 sec after last input  -->  SPACE\n");
    printf("   Wait  ~2 sec after last input  -->  SUBMIT sequence\n");
    printf("\n");

    printf(THIN);
    printf("  GAME LEVELS:\n");
    printf(THIN);
    printf("   Level 1  |  Single character  |  Morse hint shown\n");
    printf("   Level 2  |  Single character  |  No hint\n");
    printf("   Level 3  |  Full word         |  Morse hint shown\n");
    printf("   Level 4  |  Full word         |  No hint\n");
    printf("\n");

    printf(THIN);
    printf("  LIVES & SCORING:\n");
    printf(THIN);
    printf("   Start      -->  3 lives  (LED = GREEN)\n");
    printf("   Correct     -->  +1 life  (max 3)\n");
    printf("   Incorrect   -->  -1 life\n");
    printf("   0 lives     -->  Game over  (LED = RED)\n");
    printf("   5 in a row  -->  Level up!\n");
    printf("\n");

    printf(THIN);
    printf("  SELECT YOUR STARTING LEVEL (enter Morse for 1 / 2 / 3 / 4):\n");
    printf(THIN);
    printf("   Level 1  =  [ . - ]         (dit dah)\n");
    printf("   Level 2  =  [ . . - - - ]   (dit dit dah dah dah)\n");
    printf("   Level 3  =  [ . . . - - ]   (dit dit dit dah dah)\n");
    printf("   Level 4  =  [ . . . . - ]   (dit dit dit dit dah)\n");
    printf("\n");

    printf(BORDER);
    printf("|   RGB LED is BLUE  -->  no game in progress            |\n");
    printf(BORDER);
    printf("\n");
}