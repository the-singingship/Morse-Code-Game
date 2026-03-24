#include <stdio.h>
#include "pico/stdlib.h"
#include "hardware/gpio.h"
#include "welcome.h"
#include "game.h"
#include <string.h>

//input mapping- converts morse to char
char *morse_table[] = {
    ".-", "-...", "-.-.", "-..", ".", "..-.", "--.", "....", "..",
    ".---", "-.-", ".-..", "--", "-.", "---", ".--.", "--.-",
    ".-.", "...", "-", "..-", "...-", ".--", "-..-", "-.--", "--.."
};

char letters[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";

char decode_morse(char *input) {
    for (int i = 0; i < 26; i++) {
        if (strcmp(input, morse_table[i]) == 0) {
            return letters[i];
        }
    }
    return '?';
}

// Declare the main assembly code entry point.
void main_asm(void);

// Initialise a GPIO pin – see SDK for detail on gpio_init()
void asm_gpio_init(uint pin) {
    gpio_init(pin);
}

// Set direction of a GPIO pin – see SDK for detail on gpio_set_dir()
void asm_gpio_set_dir(uint pin, bool out) {
    gpio_set_dir(pin, out);
}

// Get the value of a GPIO pin – see SDK for detail on gpio_get()
bool asm_gpio_get(uint pin) {
    return gpio_get(pin);
}

// Set the value of a GPIO pin – see SDK for detail on gpio_put()
void asm_gpio_put(uint pin, bool value) {
    gpio_put(pin, value);
}

// Enable falling and rising-edge interrupt – see SDK for detail on
void asm_gpio_set_irq(uint pin) {
    gpio_set_irq_enabled(pin, GPIO_IRQ_EDGE_FALL | GPIO_IRQ_EDGE_RISE, true);
}

// Main entry point of the application
int main() {
    stdio_init_all(); // Initialise all basic IO
    main_asm(); // Jump into the ASM code
    return 0; // Application return code
}
