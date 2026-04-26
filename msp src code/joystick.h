#ifndef JOYSTICK_H
#define JOYSTICK_H

#include <stdbool.h>

// Joystick X-axis state
typedef enum {
    NEUTRAL_X,
    LEFT,
    RIGHT
} Joystick_X;

// Joystick Y-axis state
typedef enum {
    NEUTRAL_Y,
    UP,
    DOWN
} Joystick_Y;

// Full joystick state
typedef struct {
    Joystick_X x;
    Joystick_Y y;
    bool fire;
} Joystick;

// Call once in onBoot() — configures ADC and button pin
void joystick_init();

// Call every tick — returns current joystick state
Joystick joystick_poll();

#endif /* JOYSTICK_H */
