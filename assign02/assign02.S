#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified
.cpu cortex-m0plus
.thumb
.global init_gpio_asm          
.type init_gpio_asm, %function
.thumb_func
.align 4

.equ    GPIO_BTN_FALL_MSK, 0x00400000   @ Bit 22, falling-edge
.equ    GPIO_BTN_RISE_MSK, 0x00800000   @ Bit 23, rising-edge

.equ    GPIO_BTN, 21 		            @ Specify pin for the button
.equ    GPIO_LED_PIN, 25                @ Specify pin for the LED
.equ    GPIO_DIR_IN, 0 			        @ Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT, 1 		        @ Specify output direction for a GPIO pin
.equ    GPIO_ISR_OFFSET, 0x74 		    @ GPIO is int #13 (vector table entry 29)

.equ    LED_VAL_OFF, 0                  @ Clearing turns off LED
.equ    LED_VAL_ON, 1                   @ Setting turns on LED 

.equ    DOT_TIME, 180000                @ Time threshold for dot <= 180ms
.equ    SPACE_TIME, 800000              @ A gap of >= 800ms (3x dot) triggers inter-letter decode

.equ    MAX_MORSE_LEN, 8                @ Accommodates longest morse code (6 char) + null terminator

@ -----------------------------------------------------------------------------
@ Initialise GPIO (called once from C)
@ -----------------------------------------------------------------------------
init_gpio_asm:
    push    {lr}
    bl      install_gpio_isr		    @ Install the GPIO interrupt handler
    bl      init_btn       		        @ Initialise GP21 Button
    bl      init_led                    @ Initialise GP25 LED
    pop     {pc}                        @ Return to C 

@ -----------------------------------------------------------------------------
@ Morse space / submit logic.
@
@ When a gap of >= SPACE_TIME is detected after the last button release:
@   - null-terminate the local dot/dash buffer
@   - copy it into morse_input_buffer 
@   - set morse_input_ready = 1 to signal C that a letter is ready
@   - reset local state for the next letter
@ C will handle rest of gameplay logic
@ -----------------------------------------------------------------------------
.global check_space
.type check_space, %function
check_space:
    push    {lr}

    ldr     r2, =space_printed          @ Check if space already printed 
    ldr     r0, [r2]                    @ R0 = space_printed
    cmp     r0, #1                      @ If space_printed == 1:
    beq     idle_done                   @ Already registered space — nothing to do

    ldr     r2, =time_released          @ Check how long button was released
    ldr     r1, [r2]                    @ R1 = time_released
    cmp     r1, #0                      @ If time_released == 0:
    beq     idle_done                   @ Button not yet released — nothing to do

    ldr     r2, =(TIMER_BASE + TIMER_TIMELR_OFFSET)
    ldr     r0, [r2]
    subs    r0, r0, r1                  @ gap_time = current_time - time_released

    ldr     r1, =SPACE_TIME
    cmp     r0, r1
    blt     idle_done                   @ Gap too short — not yet time to submit

    @ Null-terminate the local dot/dash buffer
    ldr     r0, =buffer
    ldr     r1, =buffer_len
    ldr     r2, [r1]                    @ r2 = current length
    add     r0, r0, r2                  @ r0 = pointer to end of buffer
    movs    r3, #0
    strb    r3, [r0]                    @ null-terminate

    ldr     r0, =buffer
    ldr     r1, =morse_input_buffer     @ extern volatile char morse_input_buffer[16]
    movs    r2, #0
copy_loop:
    ldrb    r3, [r0, r2]
    strb    r3, [r1, r2]
    adds    r2, r2, #1
    cmp     r3, #0
    bne     copy_loop                   @ Copy until null terminator

    @ Signal C that a complete morse symbol is ready to decode
    ldr     r2, =morse_input_ready      @ extern volatile int morse_input_ready
    movs    r0, #1
    str     r0, [r2]                    @ morse_input_ready = 1

    @ Reset time_released — system is clean for the next letter
    ldr     r2, =time_released
    movs    r0, #0
    str     r0, [r2]

    @ Clear the local buffer length
    ldr     r2, =buffer_len
    movs    r0, #0
    str     r0, [r2]                    @ Reset length to 0

    @ Mark space as printed so we don't re-trigger until next press
    ldr     r2, =space_printed
    movs    r0, #1
    str     r0, [r2]                    @ space_printed = 1

idle_done:
    pop     {pc}

 
@ -----------------------------------------------------------------------------
@ Installing GPIO 
@ -----------------------------------------------------------------------------
install_gpio_isr:
    ldr     r2,=(PPB_BASE + M0PLUS_VTOR_OFFSET) @ Get the address of the RAM vector table
    ldr     r1, [r2]                	@ Load the vector table
    movs    r2, #GPIO_ISR_OFFSET    	@ Put the offset value into r2 from the vector table
    add     r2, r1                  	@ Add the offset value and r1
    ldr     r0, =gpio_isr           	@ Load the value the address of the service interrupt into r0
    str     r0, [r2]                	@ Store the value of r0 in the vector table stored in r2
    ldr     r0, =0x1
    lsls    r0, r0, #13             	@ Shift the value to the correct bit for GPIO (int #13)
    ldr     r1,=(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    str     r0, [r1]                	@ Disable GPIO IRQ
    ldr     r1,=(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    str     r0, [r1]                	@ Enable GPIO IRQ
    bx      lr

@ -----------------------------------------------------------------------------
@ Initialising: GP21 Button, GP25 LED
@ -----------------------------------------------------------------------------
init_btn:
    push    {lr}
    movs    r0, #GPIO_BTN
    bl      asm_gpio_init
    movs    r0, #GPIO_BTN
    ldr     r1, =0xC
    bl      asm_gpio_set_irq
    movs    r0, #GPIO_BTN
    movs    r1, #GPIO_DIR_IN
    bl      asm_gpio_set_dir
    pop     {pc}     

init_led:
    push    {lr}
    movs    r0, #GPIO_LED_PIN
    bl      asm_gpio_init
    movs    r0, #GPIO_LED_PIN
    movs    r1, #GPIO_DIR_OUT
    bl      asm_gpio_set_dir
    pop     {pc}

@ -----------------------------------------------------------------------------
@ GPIO Interrupt Service Handler 
@ -----------------------------------------------------------------------------
.thumb_func
gpio_isr:
    push    {lr}
 
    @ Load interrupt status
    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)            
    ldr     r1, [r2]
 
check_falling_edge:
    ldr     r3, =GPIO_BTN_FALL_MSK
    tst     r1, r3
    beq     check_rising_edge
 
    @ Clear falling edge interrupt
    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)
    str     r3, [r2]
 
    @ Store time_pressed
    ldr     r2, =(TIMER_BASE + TIMER_TIMELR_OFFSET)
    ldr     r0, [r2]
    ldr     r2, =time_pressed
    str     r0, [r2]

    @ Reset time_released — prevents stale gap triggering check_space after new press
    ldr     r2, =time_released
    movs    r0, #0
    str     r0, [r2]

    @ Reset space_printed — new press means a new letter is starting
    ldr     r2, =space_printed
    movs    r0, #0
    str     r0, [r2]
 
led_on:
    movs    r0, #GPIO_LED_PIN
    movs    r1, #LED_VAL_ON
    bl      asm_gpio_put
    b       gpio_done
 
check_rising_edge:
    ldr     r3, =GPIO_BTN_RISE_MSK
    tst     r1, r3
    beq     gpio_done
 
    @ Clear rising edge interrupt
    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)
    str     r3, [r2]
 
    @ Store time_released
    ldr     r2, =(TIMER_BASE + TIMER_TIMELR_OFFSET)
    ldr     r0, [r2]
    ldr     r2, =time_released
    str     r0, [r2]
 
    @ Calculate press_duration = time_released - time_pressed
    ldr     r2, =time_pressed
    ldr     r1, [r2]
    subs    r0, r0, r1
    ldr     r2, =press_duration
    str     r0, [r2]

led_off:
    movs    r0, #GPIO_LED_PIN
    movs    r1, #LED_VAL_OFF
    bl      asm_gpio_put

    @ Decide dot or dash based on duration
    ldr     r2, =press_duration
    ldr     r0, [r2]
    ldr     r1, =DOT_TIME
    cmp     r0, r1
    bge     dash

dot:
    ldr     r0, =buffer
    ldr     r1, =buffer_len
    ldr     r2, [r1]
    add     r0, r0, r2
    movs    r3, #'.'
    strb    r3, [r0]
    adds    r2, r2, #1
    str     r2, [r1]
    b       gpio_done
 
dash:
    ldr     r0, =buffer
    ldr     r1, =buffer_len
    ldr     r2, [r1]
    add     r0, r0, r2
    movs    r3, #'-'
    strb    r3, [r0]            
    adds    r2, r2, #1
    str     r2, [r1]

gpio_done:
    pop     {pc}

@ -----------------------------------------------------------------------------
@ Extras in memory
@ -----------------------------------------------------------------------------
.align 4
.data
time_pressed:   .word 0         @ timestamp when button pressed
time_released:  .word 0         @ timestamp when button released
press_duration: .word 0         @ how long button was held
interval:       .word 0         @ time between presses 
space_printed:  .word 0         @ set to 1 if space already registered

buffer:         .space 8, 0     @ buffer for current morse symbol (local, copied to morse_input_buffer on submit)
buffer_len:     .word 0         @ current # of chars in buffer