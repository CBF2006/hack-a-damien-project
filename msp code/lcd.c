#include "lcd.h"
#include <msp430.h>

//method to transmit one byte over UART
static void uart_tx(unsigned char byte)
{
    while (!(UCA0IFG & UCTXIFG)); //wait until TX buffer is ready
    UCA0TXBUF = byte;
}

//method to delay after TX before generating new frame
static void lcd_delay(void) 
{
    __delay_cycles(2000);
}

//method to set LCD size to 20x4
void setLCDSize() 
{
    uart_tx(0xFE); //start command
    lcd_delay();
    uart_tx(0xD1); //command: set LCD size
    lcd_delay();
    uart_tx(0x14); //arg: 20 columns
    lcd_delay();
    uart_tx(0x04); //arg: 4 rows
    lcd_delay();
}

//method to turn off autoscrolling
void autoscroll_off()
{
    uart_tx(0xFE); //start command
    lcd_delay();
    uart_tx(0x52); //command: turn off autoscrolling
    lcd_delay();
}

//method to set cursor position (row, column)
void set_cursor_position(unsigned char row, unsigned char column)
{
    uart_tx(0xFE); //start command
    lcd_delay();
    uart_tx(0x47); //command: move cursor
    lcd_delay();
    uart_tx(column); //arg: column
    lcd_delay();
    uart_tx(row); //arg: row
    lcd_delay();
}

//method to draw character ch at (row, column)
void draw_character(char ch, unsigned char row, unsigned char column)
{
    set_cursor_position(row, column);
    uart_tx((unsigned char)ch);
    lcd_delay();
}

//method to transmit string over UART
void draw_string(const char *str, unsigned char row, unsigned char col)
{
    int i;
    for (i = 0; str[i] != '\0'; i++)
    {
        draw_character(str[i], row, col + i);
    }
}

//method to erase a single cell
void erase_cell(unsigned char row, unsigned char column)
{
    draw_character(' ', row, column);
}

void clear_screen()
{
    uart_tx(0xFE); //start command
    lcd_delay();
    uart_tx(0x58);  //command: clear screen
    lcd_delay();
}




//method to initialize custom character
void initializeCustomCharacter()
{
    uart_tx(0xFE);  lcd_delay();
    uart_tx(0x4E);  lcd_delay();
    uart_tx(0x00);  lcd_delay();  // store as ASCII slot 0
    uart_tx(0x0E);  lcd_delay();
    uart_tx(0x0A);  lcd_delay();
    uart_tx(0x0E);  lcd_delay();
    uart_tx(0x04);  lcd_delay();
    uart_tx(0x1F);  lcd_delay();
    uart_tx(0x04);  lcd_delay();
    uart_tx(0x1F);  lcd_delay();
    uart_tx(0x11);  lcd_delay();
}