#ifndef LCD_H
#define LCD_H

// Set the LCD Screen Size to 20 x 4
// -> Set in non-volatile EPROM memory
// -> MSP430 must be rebooted (only once)
// -> for changes to permanently take effect 
void setLCDSize();

// Defines a Custom Character 
void initializeCustomCharacter();

// Turn off autoscolling, so you can use bottom right LCD screen cell 
void autoscroll_off();

// Wipe all the content on the LCD Screen
void clear_screen();

// Change the cursor position to (column, row) 
void set_cursor_position(unsigned char row, unsigned char column);
//void erase_and_draw_character(char ch, unsigned char old_row, unsigned char old_column, unsigned char new_row, unsigned char new_column);

// Draw a character (ch) in cell location (column, row)
void draw_character(char ch, unsigned char row, unsigned char column);

// Outputs string str on screen
void draw_string(const char *str, unsigned char row, unsigned char col);

// Write a blank space ' ' character into cell (column, row)
void erase_cell(unsigned char row, unsigned char column);

#endif /* LCD_H */

