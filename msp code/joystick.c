#include "joystick.h"
#include <msp430.h>

// X axis: A3 (P1.3)
// Y axis: A2 (P1.2)
// Button: P4.4, active low, pull-up

// ADC threshold: 12-bit (0-4095), center ~2048
// Deflection detected past ~500 or ~3500, matching your original game
#define JOYSTICK_HIGH 3500
#define JOYSTICK_LOW   500

// Read a single ADC channel (blocking)
static unsigned int adc_read(unsigned int channel)
{
    ADCCTL0 &= ~ADCENC;         // disable before changing channel
    ADCMCTL0 = channel;         // select channel
    ADCCTL0 |= ADCENC | ADCSC; // enable and start conversion
    while (ADCCTL1 & ADCBUSY); // wait for conversion to finish
    return ADCMEM0;
}

// Configure ADC pins and button pin
// Call once from onBoot()
void joystick_init()
{
    // Set P1.2 (A2) and P1.3 (A3) as analog inputs
    P1SEL0 |=  (BIT2 | BIT3);
    P1SEL1 &= ~(BIT2 | BIT3);

    // ADC: on, 16-cycle sample-hold, internal timer, 12-bit resolution
    ADCCTL0 = ADCSHT_2 | ADCON;
    ADCCTL1 = ADCSHP;
    ADCCTL2 = ADCRES_2;
    ADCMCTL0 = ADCINCH_3; // default channel, will be overridden in poll

    // Button on P3s.0: input, pull-up resistor
    P3DIR &= ~BIT0;
    P3REN |=  BIT0;
    P3OUT |=  BIT0;
}

// Poll joystick and return current state
// Call every tick from main loop
Joystick joystick_poll()
{
    Joystick j;
    j.x    = NEUTRAL_X;
    j.y    = NEUTRAL_Y;
    j.fire = false;

    // Read X axis (A3)
    unsigned int x_val = adc_read(ADCINCH_3);
    if      (x_val > JOYSTICK_HIGH) j.x = LEFT;
    else if (x_val < JOYSTICK_LOW)  j.x = RIGHT;

    // Read Y axis (A2)
    unsigned int y_val = adc_read(ADCINCH_2);
    if      (y_val > JOYSTICK_HIGH) j.y = UP;
    else if (y_val < JOYSTICK_LOW)  j.y = DOWN;

    // Button: active low (pressed = 0)
    if (!(P3IN & BIT0))
        j.fire = true;
    return j;
}
