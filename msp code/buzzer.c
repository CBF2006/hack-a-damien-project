#include "buzzer.h"
#include <msp430.h>

// Buzzer: P2.1 -> TB1.2 (Timer B1, CCR2, reset/set PWM)
// SMCLK = 1MHz
//
// PWM period = SMCLK / frequency
// e.g. 440 Hz (A4) -> period = 1000000 / 440 = 2272
//      duty cycle  -> CCR1 = period / 2 (50%)
//
// Songs are arrays of {period, duration_in_ticks}
// duration is in game ticks (each tick = 10ms in your original game)
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
#define F5  HZ(698)
#define G5  HZ(784)
#define A5  HZ(880)
#define DF4 HZ(277)   // D♭4 (= C#4)
#define EF4 HZ(311)   // E♭4
#define GF4 HZ(370)   // G♭4 (probably unused but cheap)
#define AF4 HZ(415)   // A♭4
#define BF4 HZ(466)   // B♭4
#define DF5 HZ(554)
#define EF5 HZ(622)
#define AF5 HZ(831)
#define BF5 HZ(932)


// ------------------
//  Note type
// ------------------
typedef struct {
    unsigned int period;        // timer period (0 = rest)
    unsigned char duration;     // length in ticks
} Note;

typedef struct {
    const Note *notes;
    unsigned char loop;   // 1 = restart at sentinel, 0 = stop
} Song;


// ------------------
//  Song definitions
// ------------------

// Short ascending jingle — plays on boot
static const Note song_1[] = {
    // Measure 1:  q,  e e,  q,  e e
    {AF4, 40},
    {AF4, 20}, {G4, 20},
    {F4,  40},
    {DF4, 20}, {AF4, 20},

    // Measure 2:  q,  e e,  e e,  e e
    {G4,  40},
    {EF4, 20}, {BF4, 20},
    {C5,  20}, {BF4, 20},
    {BF4, 20}, {G4,  20},

    // Measure 3:  q,  e e,  q,  e e   (same rhythm as m1)
    {AF4, 40},
    {AF4, 20}, {G4, 20},
    {F4,  40},
    {BF4, 20}, {AF4, 20},

    // Measure 4:  q,  e e,  e e,  e e   (same rhythm as m2)
    {G4,  40},
    {EF4, 20}, {BF4, 20},
    {C5,  20}, {EF5, 20},
    {BF4, 20}, {C5,  20},

    {REST, 0}
};

// Short two-note confirmation — place tower
static const Note song_place[] = {
    {G4, 10}, {C5, 10},
    {REST, 0}
};

// Ascending chirp — upgrade
static const Note song_upgrade[] = {
    {C5, 7}, {E5, 7}, {G5, 7},
    {REST, 0}
};

// Descending — sell
static const Note song_sell[] = {
    {G4, 7}, {E4, 7}, {C4, 7},
    {REST, 0}
};

// Urgent pulse — wave incoming
static const Note song_wave_start[] = {
    {A4, 10}, {REST, 10}, {A4, 10}, {REST, 10}, {A5, 30},
    {REST, 0}
};

// Slow descending — game over
static const Note song_gameover[] = {
    {E4, 10}, {D4, 10}, {C4, 30},
    {REST, 0}
};

// Quick descending blip — enemy killed (reserved)
static const Note song_kill[] = {
    {C5, 3}, {G4, 4},
    {REST, 0}
    
};

// Song table — index by song ID
static const Song songs[] = 
{
    {0,              0}, // SONG_NONE (0)
    {song_1,          1},// SONG_1 (1)
    {song_place,      0},// SONG_PLACE (2)
    {song_upgrade,    0},// SONG_UPGRADE (3)
    {song_sell,       0},// SONG_SELL (4)
    {song_wave_start, 0},// SONG_WAVE_START (5)
    {song_gameover,   0},// SONG_GAMEOVER (6)
    {song_kill,       0},// SONG_KILL (7)
};
#define NUM_SONGS (sizeof(songs) / sizeof(songs[0]))


// ------------------
//  Playback state
// ------------------
static const Note  *current_song   = 0;  // pointer into song array
static unsigned char ticks_left    = 0;  // ticks remaining on current note
static const Note *song_head    = 0;
static unsigned char song_loop  = 0;
static unsigned int prev_period = 0;

// ------------------
//  Internal helpers
// ------------------

// Set PWM frequency. period=0 silences the buzzer.
static void set_period(unsigned int period)
{
    if (period == 0) {
        TB1CCR0 = 0;
        TB1CCR2 = 0;       // was TB1CCR1
    } else {
        TB1CCR0 = period;
        TB1CCR2 = period >> 1;  // was TB1CCR1
    }
}


// ------------------
//  Public API
// ------------------

void buzzer_init()
{
    // P2.1 -> TB1.1 output function
    P2DIR  |=  BIT1;
    P2SEL0 |=  BIT1;
    P2SEL1 &= ~BIT1;

    // Timer B1: SMCLK, up mode, reset/set PWM on CCR1
    TB1CTL    = TBSSEL__SMCLK | MC__UP | TBCLR;
    TB1CCTL2 = OUTMOD_7;   // was TB1CCTL1
    TB1CCR0  = 0;
    TB1CCR2  = 0;          // was TB1CCR1
}

void buzzer_play(unsigned char song_id)
{
    if (song_id == SONG_NONE || song_id >= NUM_SONGS || songs[song_id].notes == 0) {
        buzzer_stop();
        return;
    }
    song_head    = songs[song_id].notes;
    song_loop    = songs[song_id].loop;
    current_song = song_head;
    ticks_left   = 0;
    prev_period = 0;
}

void buzzer_stop()
{
    current_song = 0;
    ticks_left   = 0;
    prev_period = 0;
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
    if (current_song->duration == 0) 
    {
        if (song_loop) 
        { 
            current_song = song_head; 
        }
        else 
        { 
            buzzer_stop(); 
            return; 
        }
    }
    
    if (current_song->period != 0 && current_song->period == prev_period) {
        set_period(0);
        __delay_cycles(2000);
    }
    prev_period = current_song->period;
    set_period(current_song->period);
    ticks_left = current_song->duration - 1; // -1 because this tick counts
    current_song++;
}

unsigned char buzzer_is_playing()
{
    return current_song != 0;
}
