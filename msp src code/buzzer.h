#ifndef BUZZER_H
#define BUZZER_H

// Buzzer is on P6.0, driven by Timer B3 CCR1 (TB3.1) PWM output
// All songs are hardcoded — Godot sends a song ID to play or stop

// Song IDs
#define SONG_NONE       0
#define SONG_STARTUP    1
#define SONG_PLACE      2   // place tower
#define SONG_UPGRADE    3   // upgrade tower
#define SONG_SELL       4   // sell tower
#define SONG_WAVE_START 5   // enemy wave incoming
#define SONG_GAMEOVER   6   // game over

// Call once from onBoot() — configures P6.0 and Timer B3
void buzzer_init();

// Play a hardcoded song by ID. Non-blocking — returns immediately,
// playback advances each time buzzer_tick() is called.
// Call buzzer_play(SONG_NONE) or buzzer_stop() to stop.
void buzzer_play(unsigned char song_id);

// Stop whatever is currently playing
void buzzer_stop();

// Call once per game tick from main loop — advances note playback
void buzzer_tick();

// Returns 1 if a song is currently playing, 0 if idle
unsigned char buzzer_is_playing();

#endif /* BUZZER_H */
