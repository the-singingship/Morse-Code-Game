/**
 * @file    main.c
 * @brief   Entry point. Initialises IO, GPIO hardware, then runs the game.
 * @author  Marcel
 * @course  CSU23021 - Microprocessor Systems, TCD 2025/2026
 */

#include <stdio.h>
#include "pico/stdlib.h"
#include "hardware/gpio.h"
#include "hardware/watchdog.h" 
#include "welcome.h"
#include "game.h"
#include <string.h>

// Declare the ASM GPIO setup entry point.
void init_gpio_asm(void);

// Initialise a GPIO pin – see SDK for detail on gpio_init()
void asm_gpio_init(uint pin) { gpio_init(pin); }

// Set direction of a GPIO pin – see SDK for detail on gpio_set_dir()
void asm_gpio_set_dir(uint pin, bool out) { gpio_set_dir(pin, out); }

// Get the value of a GPIO pin – see SDK for detail on gpio_get()
bool asm_gpio_get(uint pin) { return gpio_get(pin); }

// Set the value of a GPIO pin – see SDK for detail on gpio_put()
void asm_gpio_put(uint pin, bool value) { gpio_put(pin, value); }

// Enable falling and rising-edge interrupts – see SDK for detail on gpio_set_irq_enabled()
void asm_gpio_set_irq(uint pin) { gpio_set_irq_enabled(pin, GPIO_IRQ_EDGE_FALL | GPIO_IRQ_EDGE_RISE, true); }


// ================================================================
//  MAIN APPLICATION
// ================================================================
int main() {
    stdio_init_all();       // Initialise all basic IO

    watchdog_enable(8300, true);  // Enable watchdog with 8.3s timeout to reset on hangs

    init_gpio_asm();        // Set up GPIO pins and ISR 

    print_welcome();        // Welcome screen

    int lives      = 3;
    int difficulty = select_difficulty();   // 1 = Easy, 2 = Hard 

    // Easy mode : Levels 1 & 2     Hard mode : Levels 3 & 4
    // Adjust starting level based on difficulty selection
    int start_level = (difficulty == 1) ? 1 : 3;

    for (int level = start_level; level <= 4; level++) {
        bool passed = run_level(level, &lives);
        if (!passed) {
            printf("\n  Game over. Better luck next time!\n");
            return 0;
        }
    }

    printf("\n  ** YOU COMPLETED ALL LEVELS! CONGRATULATIONS! **\n");
    return 0;
}