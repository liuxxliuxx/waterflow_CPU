#include "board.h"

int main(void)
{
    // Board LEDs are active low: LED0..LED7 = on,off,on,off,on,on,off,off.
    led_write(0xcau);

    vga_clear();
    vga_puts_xy(0u, 0u, "helloworld");

    for (;;) {
    }
}
