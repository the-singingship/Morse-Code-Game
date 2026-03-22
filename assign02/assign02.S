#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified
.cpu cortex-m0plus
.thumb
.global main_asm
.type main_asm, %function
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

@ -----------------------------------------------------------------------------
@ Main entry point to the ASM program
@ -----------------------------------------------------------------------------
main_asm:
    bl      install_gpio_isr		    @ 
    bl      init_btn       		        @ Initialise GP21 Button
    bl      init_led                    @ Initialise GP25 LED
loop:
    wfi                     		    @ Wait here until any interrupt fires
    b       loop            		    @ Always branch back to loop
    
@ -----------------------------------------------------------------------------
@ Installing GPIO 
@ -----------------------------------------------------------------------------
install_gpio_isr:
    ldr     r2,=(PPB_BASE + M0PLUS_VTOR_OFFSET) @ Get the address of the RAM vector table
    ldr     r1, [r2]                	@ Load the vector table
    movs    r2, #GPIO_ISR_OFFSET    	@ Put the offset value into r2 from the vector table
    add     r2, r1                  	@ Add the offset value and r1
    ldr     r0, =gpio_isr           	@ Load the value the address of the service interrupt into r0
                            		    @ Store the address of the gpio_isr handler to the correct offset for GPIO in the vector table
    str     r0, [r2]                	@ Store the value of r0 in the vector table stored in r2
                            		    @ Disable the GPIO IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    ldr     r0, =0x1
    lsls    r0, r0, #13             	@ Shift the value to the correct bit for GPIO (int #13)
    ldr     r1,=(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET) @ Get the location of the bit that disables the GPIO
    str     r0, [r1]                	@ Store the value in the disable bit
                            		    @ Enable the GPIO IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    ldr     r1,=(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET) @ Get the location of the bit that enables the GPIO
    str     r0, [r1]                	@ Store the value in the enable bit
    bx      lr

@ -----------------------------------------------------------------------------
@ Initialising: GP21 Button, GP25 LED
@ -----------------------------------------------------------------------------
init_btn:
    push    {lr}
    movs    r0, #GPIO_BTN
    bl      asm_gpio_init
    movs    r0, #GPIO_BTN	       	    @ Load the "enter" button pin number into r0
    ldr     r1, =0xC                    @ Ensures interrupts are active for falling and rising edge
    bl      asm_gpio_set_irq     	    @ Set up interrupts for the button
    movs    r0, #GPIO_BTN        	    @ Load the button pin number into r0
    movs    r1, #GPIO_DIR_IN        	@ Load the value for input direction into r1
    bl      asm_gpio_set_dir        	@ Set the "up" button pin to be an input
    pop     {pc}     
init_led:
    PUSH    {LR}
    MOVS    R0, #GPIO_LED_PIN
    BL      asm_gpio_init
    MOVS    R0, #GPIO_LED_PIN           @ Load the LED pin number into r0
    MOVS    R1, #GPIO_DIR_OUT           @ Load the value for output direction into r0
    BL      asm_gpio_set_dir            @ Set the LED pin to be an output
    POP     {PC}             	

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
 
    @ Read current timer value
    ldr     r2, =(TIMER_BASE + TIMER_TIMELR_OFFSET)
    ldr     r0, [r2]                    @ Current timestamp
 
    @ Store as time_pressed
    ldr     r2, =time_pressed
    str     r0, [r2]                    @ Time pressed = now
 
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
 
    @ Read current timer value
    ldr     r2, =(TIMER_BASE + TIMER_TIMELR_OFFSET)
    ldr     r0, [r2]                    @ Current timestamp
 
    @ Store as time_released
    ldr     r2, =time_released
    str     r0, [r2]                    @ Time pressed = now
 
    @ Calculate press_duration = time_released - time_pressed
    ldr     r2, =time_pressed
    ldr     r1, [r2]                    @ r1 = time_pressed
    subs    r0, r0, r1                  @ r0 = now - time_pressed
    ldr     r2, =press_duration
    str     r0, [r2]                    @ Store press_duration

led_off:
    movs    r0, #GPIO_LED_PIN
    movs    r1, #LED_VAL_OFF
    bl      asm_gpio_put

    @ Decide dot or dash based on duration
    ldr     r2, =press_duration
    ldr     r0, [r2]                    @ r0 = press_duration
    ldr     r1, =DOT_TIME               @ r1 = 180000 us
    cmp     r0, r1
    bge     print_dash                  @ >= 180ms = dash

print_dot:
    ldr     r0, =dot_msg
    bl      printf
    b       gpio_done
 
print_dash:
    ldr     r0, =dash_msg
    bl      printf

gpio_done:
    pop     {pc}

@ -----------------------------------------------------------------------------
@ Extras in memory
@ -----------------------------------------------------------------------------
.align 4
.data
time_pressed:   .word 0     @ timestamp when button pressed
time_released:  .word 0     @ timestamp when button released
press_duration: .word 0     @ how long button was held
interval:       .word 0     @ time between presses 

dot_msg:    .asciz ". "
dash_msg:   .asciz "- "
