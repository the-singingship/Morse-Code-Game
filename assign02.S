#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/m0plus.h"
.syntax unified
.cpu cortex-m0plus
.thumb
.global main_asm
.align 4
.equ    GPIO_BTN_MSK, 0x00400000 	    @ Bit-22 for falling-edge event on GP21
.equ    GPIO_BTN, 21 		            @ Specify pin for the button
.equ    GPIO_DIR_IN, 0 			        @ Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT, 1 		        @ Specify output direction for a GPIO pin
.equ    GPIO_ISR_OFFSET, 0x74 		    @ GPIO is int #13 (vector table entry 29)

@ Main entry point into the ASM portion of the code
main_asm:
    bl      install_gpio_isr		    @ See below
    bl      init_btn       		        @ Use asm_gpio_set_irq C function to setup falling-edge interrupts
loop:
    wfi                     		    @ Wait here until any interrupt fires
    b       loop            		    @ Always branch back to loop

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

init_btn:
    push    {lr}
    movs    r0, #GPIO_BTN	       	    @ Load the "enter" button pin number into r0
    bl      asm_gpio_set_irq     	    @ Set up falling-edge interrupts for the "enter" button
    movs    r0, #GPIO_BTN        	    @ Load the button pin number into r0
    movs    r1, #GPIO_DIR_IN        	@ Load the value for input direction into r1
    bl      asm_gpio_set_dir        	@ Set the "up" button pin to be an input
    pop     {pc}                    	

.thumb_func
gpio_isr:
    push    {lr}
    @ Clear interupt
    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET) @ Get the location of the disabled bit
    ldr     r0, [r2]
    ldr     r1, =GPIO_BTN_MSK       	@ Load the mask
    str     r1, [r2]                	@ Store the value in the disabled bit

    ldr     r0, =btn_pressed
    bl      printf                      @ Print the message to the console (simple test - to be removed)
    pop     {pc}

.align 4
btn_pressed:      .asciz "GP21 is pressed\n"

