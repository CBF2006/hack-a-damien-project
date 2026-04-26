#include "buzzer.h"
#include <msp430.h>

// Buzzer: P6.0 -> TB3.1 (Timer B3, CCR1, reset/set PWM)
// SMCLK = 1MHz
//
// PWM period = SMCLK / frequency
// e.g. 440 Hz (A4) -> period = 1000000 / 440 = 2272
//      duty cycle  -> CCR1 = period / 2 (50%)
//
// Songs are arrays of {period, duration_in_ticks}
// duration is in game ticks (each tick = 250ms in your original game)
// Set period = 0 for a rest (silence)

#define SMCLK_HZ 1000000UL

// Convenience macro: convert Hz to timer period
#define HZ(f) ((unsigned int)(SMCLK_HZ / (f)))

// Rest (silence)
#define REST 0

// Note periods (pre-computed from SMCLK=1MHz)
#define C4  HZ(262)
#define D4  HZ(294)
#define E4  HZ(330)
#define F4  HZ(349)
#define G4  HZ(392)
#define A4  HZ(440)
#define B4  HZ(494)
#define C5  HZ(523)
#define D5  HZ(587)
#define E5  HZ(659)
#define G5  HZ(784)
#define A5  HZ(880)


// ------------------
//  Note type
// ------------------
typedef struct {
    unsigned int period;        // timer period (0 = rest)
    unsigned char duration;     // length in ticks
} Note;


// ------------------
//  Song definitions
// ------------------

// Short ascending jingle — plays on boot
static const Note song_startup[] = {
    {C4, 1}, {E4, 1}, {G4, 1}, {C5, 2},
    {REST, 0}  // sentinel
};

// Short two-note confirmation — place tower
static const Note song_place[] = {
    {G4, 1}, {C5, 1},
    {REST, 0}
};

// Ascending chirp — upgrade
static const Note song_upgrade[] = {
    {C5, 1}, {E5, 1}, {G5, 1},
    {REST, 0}
};

// Descending — sell
static const Note song_sell[] = {
    {G4, 1}, {E4, 1}, {C4, 1},
    {REST, 0}
};

// Urgent pulse — wave incoming
static const Note song_wave_start[] = {
    {A4, 1}, {REST, 1}, {A4, 1}, {REST, 1}, {A5, 2},
    {REST, 0}
};

// Slow descending — game over
static const Note song_gameover[] = {
    {E4, 2}, {D4, 2}, {C4, 4},
    {REST, 0}
};

// Song table — index by song ID
static const Note * const songs[] = {
    0,               // SONG_NONE (0)
    song_startup,    // SONG_STARTUP (1)
    song_place,      // SONG_PLACE (2)
    song_upgrade,    // SONG_UPGRADE (3)
    song_sell,       // SONG_SELL (4)
    song_wave_start, // SONG_WAVE_START (5)
    song_gameover,   // SONG_GAMEOVER (6)
};
#define NUM_SONGS (sizeof(songs) / sizeof(songs[0]))


// ------------------
//  Playback state
// ------------------
static const Note  *current_song   = 0;  // pointer into song array
static unsigned char ticks_left    = 0;  // ticks remaining on current note


// ------------------
//  Internal helpers
// ------------------

// Set PWM frequency. period=0 silences the buzzer.
static void set_period(unsigned int period)
{
    if (period == 0) {
        TB3CCR0 = 0;
        TB3CCR1 = 0;
    } else {
        TB3CCR0 = period;
        TB3CCR1 = period >> 1; // 50% duty cycle
    }
}


// ------------------
//  Public API
// ------------------

void buzzer_init()
{
    // P6.0 -> TB3.1 output function
    P6DIR  |=  BIT0;
    P6SEL0 |=  BIT0;
    P6SEL1 &= ~BIT0;

    // Timer B3: SMCLK, up mode, reset/set PWM on CCR1
    TB3CTL  = TBSSEL__SMCLK | MC__UP | TBCLR;
    TB3CCTL1 = OUTMOD_7; // reset/set
    TB3CCR0 = 0;
    TB3CCR1 = 0;
}

void buzzer_play(unsigned char song_id)
{
    if (song_id == SONG_NONE || song_id >= NUM_SONGS || songs[song_id] == 0) {
        buzzer_stop();
        return;
    }
    current_song = songs[song_id];
    ticks_left   = 0; // force immediate advance to first note in buzzer_tick()
}

void buzzer_stop()
{
    current_song = 0;
    ticks_left   = 0;
    set_period(0);
}

// Called every game tick from main loop
// Advances to the next note when the current note's duration expires
void buzzer_tick()
{
    if (current_song == 0)
        return;

    // Count down current note
    if (ticks_left > 0) {
        ticks_left--;
        return;
    }

    // Load next note
    // Sentinel: duration == 0 means end of song
    if (current_song->duration == 0) {
        buzzer_stop();
        return;
    }

    set_period(current_song->period);
    ticks_left = current_song->duration - 1; // -1 because this tick counts
    current_song++;
}

unsigned char buzzer_is_playing()
{
    return current_song != 0;
}
