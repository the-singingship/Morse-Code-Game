#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified                                                 @ Specify unified assembly syntax
.cpu    cortex-m0plus                                           @ Specify CPU type is Cortex M0+
.thumb                                                          @ Specify thumb assembly for RP2040
.type main_asm, %function
.thumb_func
.global main_asm                                                @ Provide program starting address to the linker
.align 4                                                        @ Specify code alignment

.equ    DFLT_STATE_STRT, 1                                      @ Specify the value to start flashing
.equ    DFLT_STATE_STOP, 0                                      @ Specify the value to stop flashing

.equ    DFLT_ALARM_TIME, 1000000                                @ Specify the default alarm timeout

.equ    GPIO_BTN_DN_MSK, 0x00040000                             @ Bit-18 for falling edge event on GP20
.equ    GPIO_BTN_EN_MSK, 0x00400000                             @ Bit-22 for falling edge event on GP21
.equ    GPIO_BTN_UP_MSK, 0x04000000                             @ Bit-26 for falling edge event on GP22

.equ    GPIO_BTN_DN, 20                                         @ Specify pin for "down" button
.equ    GPIO_BTN_EN, 21                                         @ Specify pin for "enter" button
.equ    GPIO_BTN_UP, 22                                         @ Specify pin for "up" button
.equ    GPIO_LED_PIN, 25                                        @ Specify pin for built-in LED
.equ    GPIO_DIR_IN, 0                                          @ Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT, 1                                         @ Specify output direction for a GPIO pin

.equ    LED_VAL_ON, 1                                           @ Specify value that turns LED on
.equ    LED_VAL_OFF, 0                                          @ Specify value that turns LED off

.equ    GPIO_ISR_OFFSET, 0x74                                   @ GPIO is int #13 (vector table entry 29)
.equ    ALRM_ISR_OFFSET, 0x40                                   @ Alarm is int #0 (vector table entry 16)

@ -----------------------------------------------------------------------------
@ Entry point to the ASM portion of the program
@ -----------------------------------------------------------------------------
.thumb_func
main_asm:
    BL    install_alrm_isr                                      @
    BL    install_gpio_isr                                      @
    BL    init_leds                                             @ Initialise LED pins
    BL    init_btns                                             @ Initialise Buttons
    BL    asm_ws2812_init                                       @ Initialise WS2812 RGB LED
loop: 
    BL   set_alarm                                              @ Set a new alarm
    wfi                                                         @ Wait here until any interrupt fires
    B    loop                                                   @ Always branch back to loop


@ -----------------------------------------------------------------------------
@ Installing the Alarm ISR function
@ -----------------------------------------------------------------------------
install_alrm_isr:
    @ Get the address of the RAM vector table using the (PPB_BASE + M0PLUS_VTOR_OFFSET) register
    LDR   R2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)
    LDR   R1, [R2]
    MOVS  R2, #ALRM_ISR_OFFSET
    ADD   R2, R1
    LDR   R0, =alrm_isr
    @ Store the address of the alrm_isr handler to the correct offset for ALARM0 in the vector table
    STR   R0, [R2]
    @ Disable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    LDR   R2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    LDR   R0, =1
    STR   R0, [R2]
    @ Enable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    LDR   R2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    LDR   R0, =1
    STR   R0, [R2]
    @ Exit subroutine
    BX    LR

@ -----------------------------------------------------------------------------
@  Servicing the Pending Alarm Interrupt
@ -----------------------------------------------------------------------------
.thumb_func
alrm_isr:
    PUSH {LR}
    LDR   R2, =(TIMER_BASE + TIMER_INTR_OFFSET)
    LDR   R1, =1
    STR   R1, [R2]

    BL    set_alarm

    LDR   R2, =lstate
    LDR   R1, [R2]
    CMP   R1, #DFLT_STATE_STRT
    BNE   alrm_done

    LDR   R0, =alarm
    BL    printf

    @ Set RGB LED green to indicate LED is running
    MOVS  R0, #0
    MOVS  R1, #200
    MOVS  R2, #0
    BL    urgb_u32
    BL    put_pixel

    MOVS  R0, #GPIO_LED_PIN
    BL    asm_gpio_get
    CMP   R0, #LED_VAL_OFF
    BEQ   led_set_on
led_set_off:
    MOVS  R1, #LED_VAL_OFF
    B     led_set_state
led_set_on:
    MOVS  R1, #LED_VAL_ON    
led_set_state:
    MOVS  R0, #GPIO_LED_PIN
    BL    asm_gpio_put
alrm_done:
    POP  {PC}

@ -----------------------------------------------------------------------------
@  Initialising GPI LED function
@ -----------------------------------------------------------------------------
init_leds:
    PUSH {LR}
    MOVS  R0, #GPIO_LED_PIN
    BL    asm_gpio_init
    MOVS  R0, #GPIO_LED_PIN
    MOVS  R1, #GPIO_DIR_OUT
    BL    asm_gpio_set_dir
    POP  {PC}

@ -----------------------------------------------------------------------------
@ Initialising GPIO Buttons
@ -----------------------------------------------------------------------------
init_btns:
    PUSH {LR}
    MOVS  R0, #GPIO_BTN_DN
    BL    asm_gpio_set_irq
    MOVS  R0, #GPIO_BTN_DN
    MOVS  R1, #GPIO_DIR_IN
    BL    asm_gpio_set_dir
    MOVS  R0, #GPIO_BTN_EN
    BL    asm_gpio_set_irq
    MOVS  R0, #GPIO_BTN_EN
    MOVS  R1, #GPIO_DIR_IN
    BL    asm_gpio_set_dir
    MOVS  R0, #GPIO_BTN_UP
    BL    asm_gpio_set_irq
    MOVS  R0, #GPIO_BTN_UP
    MOVS  R1, #GPIO_DIR_IN
    BL    asm_gpio_set_dir
    POP  {PC}

@ -----------------------------------------------------------------------------
@ Initialising GPIO ISR function
@ -----------------------------------------------------------------------------
install_gpio_isr:
    @ Get the address of the RAM vector table
    LDR   R2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)
    LDR   R1, [R2]
    LDR   R2, =GPIO_ISR_OFFSET
    ADD   R2, R1
    LDR   R0, =gpio_isr
    @ Store the address of the gpio_isr handler to the correct offset in the vector table
    STR   R0, [R2]
    @ Disable the GPIO IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    LDR   R0, =0x1
    LSLS  R0, #13
    LDR   R1, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    STR   R0, [R1]
    @ Enable the GPIO IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    LDR   R1, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    STR   R0, [R1]
    @ Exit subroutine
    BX    LR

@ -----------------------------------------------------------------------------
@ Setting Alarms and Starting Timers                  
@ -----------------------------------------------------------------------------     
set_alarm:
    PUSH   {LR}                
    LDR     R0, =(TIMER_BASE + TIMER_TIMERAWL_OFFSET)  
    LDR     R1, [R0]           @ get current timer value
    LDR     R2, =ltimer
    LDR     R2, [R2]           @ get ltimer value
    ADD     R1, R1, R2         @ next alarm = current + ltimer
    LDR     R0, =(TIMER_BASE + TIMER_ALARM0_OFFSET)
    STR     R1, [R0]           @ set alarm register

    LDR     R0, =(TIMER_BASE + TIMER_INTE_OFFSET)
    MOVS    R1, #1
    STR     R1, [R0]           @ enable timer interrupt

    POP     {PC}               @ return 

@ -----------------------------------------------------------------------------
@ Servicing the GPIO button ISR
@ -----------------------------------------------------------------------------   
.thumb_func
gpio_isr:
    PUSH {LR}
    @ Load interrupt status
    LDR   R2, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)
    LDR   R1, [R2]
    LDR   R3, =GPIO_BTN_DN_MSK
    ANDS  R1, R3
    CMP   R1, R3
    BNE   not_dn

    @ Clearing interrupt
    LDR   R2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)
    STR   R3, [R2]

    @ if DOWN button pressed
    LDR   R4, =lstate
    LDR   R5, [R4]
    @ check if LED is in flashing state
    CMP   R5, #1
    BEQ   not_paused
    @ if LED not flashing, reset flashing state
    LDR   R4, =ltimer
    LDR   R5, =DFLT_ALARM_TIME
    STR   R5, [R4]
    LDR   R0, =led_reset
    BL    printf
    @ Set RGB LED orange to indicate rate has been reset
    MOVS  R0, #200
    MOVS  R1, #80
    MOVS  R2, #0
    BL    urgb_u32
    BL    put_pixel
    B     end
not_paused:
    @ if LED is on...
    LDR   R1, =ltimer
    LDR   R3, [R1]
    @ double the flashing time (halve the flashing rate)
    LSLS  R3, #1
    STR   R3, [R1]
    LDR   R0, =button_dn
    BL    printf
    @ Set RGB LED blue to indicate slower flashing rate
    MOVS  R0, #0
    MOVS  R1, #0
    MOVS  R2, #200
    BL    urgb_u32
    BL    put_pixel
    B     end
not_dn:
    @ else if ENTER button is pressed
    LDR   R2, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)
    LDR   R1, [R2]
    LDR   R3, =GPIO_BTN_EN_MSK
    ANDS  R1, R3
    @ check if LED is in flashing state
    CMP   R1, R3
    BNE   not_en

    @ Clearing interrupt
    LDR   R2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)
    STR   R3, [R2]

    @ if LED is flashing, stop the LED; if paused, restart it
    LDR   R2, =lstate
    LDR   R3, [R2]
    CMP   R3, #1
    BNE   restart
    LDR   R1, =DFLT_STATE_STOP
    STR   R1, [R2]
    LDR   R0, =led_pause
    BL    printf
    @ Set RGB LED yellow to indicate LED is paused
    MOVS  R0, #200
    MOVS  R1, #200
    MOVS  R2, #0
    BL    urgb_u32
    BL    put_pixel
    B     end
restart:
    LDR   R1, =DFLT_STATE_STRT
    STR   R1, [R2]
    LDR   R0, =led_restart
    BL    printf
    @ Set RGB LED green to indicate LED is running again
    MOVS  R0, #0
    MOVS  R1, #200
    MOVS  R2, #0
    BL    urgb_u32
    BL    put_pixel
    B     end
not_en:
    @ else if UP button is pressed
    LDR   R2, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)
    LDR   R1, [R2]
    LDR   R3, =GPIO_BTN_UP_MSK
    ANDS  R1, R3

    @ check if LED is in flashing state
    CMP   R1, R3
    BNE   end

    @ Clearing interrupt
    LDR   R2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)
    STR   R3, [R2]

    LDR   R4, =lstate
    LDR   R5, [R4]
    @ check whether the LED is paused or not
    CMP   R5, #1
    BEQ   not_paused_up
    @ if LED is off, reset the timer
    LDR   R4, =ltimer
    LDR   R5, =DFLT_ALARM_TIME
    STR   R5, [R4]
    LDR   R0, =led_reset
    BL    printf
    @ Set RGB LED orange to indicate rate has been reset
    MOVS  R0, #200
    MOVS  R1, #80
    MOVS  R2, #0
    BL    urgb_u32
    BL    put_pixel
    B     end
not_paused_up:
    @ if LED is on
    LDR   R1, =ltimer
    LDR   R3, [R1]
    @ halve the flashing time (double the flashing rate)
    ASRS  R3, #1
    STR   R3, [R1]
    LDR   R0, =button_up
    BL    printf
    @ Set RGB LED purple to indicate faster flashing rate
    MOVS  R0, #150
    MOVS  R1, #0
    MOVS  R2, #150
    BL    urgb_u32
    BL    put_pixel
end:   
    POP  {PC}



@ -----------------------------------------------------------------------------
@ Descriptive Messages
@ -----------------------------------------------------------------------------  
.align 4
button_up:           .asciz "GP22 is pressed & LED flashing rate doubled\n"
button_dn:           .asciz "GP20 is pressed & LED flashing rate halved\n"
led_reset:           .asciz "LED flashing rate reset\n"
led_pause:           .asciz "LED paused\n"
led_restart:         .asciz "LED restarted\n"
alarm:               .asciz "Timer alarm triggered\n"

.data
lstate:              .word DFLT_STATE_STRT
ltimer:              .word DFLT_ALARM_TIME