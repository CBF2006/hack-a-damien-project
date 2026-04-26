#include <msp430.h>
#include <stdbool.h>
#include <string.h>
#include "joystick.h"
#include "buzzer.h"
#include "lcd.h"

// ------------------
//  globals
// ------------------
volatile bool timerFlag;
Joystick joystickInput;

//RX UART STUFF
volatile char rx_buf[32];
volatile unsigned char rx_pos = 0;
volatile bool rx_ready = false;

//lcd screen presets
const char *lcd_presets[] = {
    "",           // 0 = clear
    "Wave 1",     // 1
    "Place Tower",// 2
    "Game Over",  // 3
};









// ------------------
//  helper methods
// ------------------

//waits till tx buffer is ready, then transmits one byte
void uca1_tx(unsigned char byte)
{
    while (!(UCA1IFG & UCTXIFG)); // wait for TX buffer ready
    UCA1TXBUF = byte;
}

//sends every character in a string
void uca1_print(const char *str)
{
    while (*str)
        uca1_tx(*str++);
}

//sends the joystick state to the computer
void sendOutput(Joystick input)
{
    char output[16];
    output[0] = 'J';
    output[1] = ':';
    output[2] = '0' + input.x;
    output[3] = ',';
    output[4] = '0' + input.y;
    output[5] = ',';
    output[6] = '0' + input.fire;
    output[7] = '\n';
    output[8] = '\0';
    uca1_print(output);
}





// 
//  fsm stuff
// 
void onBoot()
{
    //disable watchdog timer
    WDTCTL = WDTPW | WDTHOLD;



    //-- setup UCA0 (UART0 - lcd)
    UCA0CTLW0 |= UCSWRST; // put into SW reset
    UCA0CTLW0 |= UCSSEL__SMCLK; //choose SMCLK=BRCLK
    //For 9600 Baud Rate
    UCA0BRW = 104;              // Prescaler for 9600 baud with 1MHz SMCLK
    UCA0MCTLW = 0x1100;        // Modulation for 9600 baud with 1MHz SMCLK
    // ADC setup pins 1.7 (UART TX)
    P1SEL0 |= BIT7;
    P1SEL1 &= ~BIT7; 



    //-- setup UCA1 (UART0 - usb)
    UCA1CTLW0 |= UCSWRST;
    UCA1CTLW0 |= UCSSEL__SMCLK;
    //for 115200 Baud Rate
    UCA1BRW = 8;
    UCA1MCTLW = 0xD600;
    // ADC setup pins 4.3 (UART TX) and 4.2 (UART RX?)
    P4SEL0 |= (BIT2 | BIT3);
    P4SEL1 &= ~(BIT2 | BIT3);
    //enable UCA1 RX interrupt
    UCA1IE |= UCRXIE;




    //timer b0 setup
    TB0CTL = TBSSEL__SMCLK | MC__UP | TBCLR;
    TB0CCR0 = 10000 - 1;   // 10ms at 1MHz/10000 = 100Hz
    TB0CCTL0 = CCIE;

   


    PM5CTL0 &= ~LOCKLPM5; //unlock pins
    UCA0CTLW0 &= ~UCSWRST; //take UCA0 out of sw reset
    UCA1CTLW0 &= ~UCSWRST; //take UCA1 out of sw reset


    joystick_init();
    buzzer_init();
    setLCDSize();
    autoscroll_off();
    clear_screen();

    timerFlag = false;

    //initial screen draws?
    //
    //

    //enable interrupts
    __bis_SR_register(GIE);

}

void tickFunc()
{
    buzzer_tick();
    //get joystick state and send to computer
    joystickInput = joystick_poll();
    sendOutput(joystickInput);

    //get input from computer for peripheral outputs
    if (rx_ready)
    {
        rx_ready = false; //clear flag


        char *song_ptr = strstr((char*)rx_buf, "SONG:");
        char *lcd_ptr  = strstr((char*)rx_buf, "LCD:");

        if (song_ptr)
        {
            int id = song_ptr[5] - '0';
            buzzer_play(id);
        }
        if (lcd_ptr)
        {
            int id = lcd_ptr[4] - '0';
            
            //clear lcd screen and display preset
            clear_screen();
            draw_string(lcd_presets[id], 1, 1);
        }
    }

    
}

int main(void)
{
    onBoot();

    while (1)
    {
        if (timerFlag)
        {
            //reset flag
            timerFlag = false;

            tickFunc();
        }
    }
}


// ------------------
//  ISRs
// ------------------

//timer b0
#pragma vector = TIMER0_B0_VECTOR
__interrupt void Timer_B0_ISR(void)
{
    timerFlag = true;
}


//UCA1 RX
#pragma vector = EUSCI_A1_VECTOR
__interrupt void UCA1_RX_ISR(void)
{
    if (UCA1IFG & UCRXIFG)
    {
        char c = UCA1RXBUF;
        if (c == '\n')
        {
            rx_buf[rx_pos] = '\0';  // null terminate
            rx_ready = true;        // signal main loop
            rx_pos = 0;
        }
        else if (rx_pos < 31)
        {
            rx_buf[rx_pos++] = c;
        }
    }
}