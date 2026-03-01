/* ==========================================================================
 * UART Driver
 * ========================================================================== */
#ifndef UART_H
#define UART_H

#include "soc_regs.h"

/* Blocking character transmit */
static inline void uart_putc(char c)
{
    while (UART_TX_BUSY)
        ;
    UART_TX_DATA = (uint32_t)c;
}

/* Blocking string transmit */
static inline void uart_puts(const char *s)
{
    while (*s)
        uart_putc(*s++);
}

/* Print a 32-bit hex value */
static inline void uart_put_hex(uint32_t val)
{
    static const char hex[] = "0123456789ABCDEF";
    uart_puts("0x");
    for (int i = 28; i >= 0; i -= 4)
        uart_putc(hex[(val >> i) & 0xF]);
}

/* Non-blocking RX: returns -1 if no data, else the byte */
static inline int uart_getc(void)
{
    if (UART_RX_AVAIL)
        return (int)(UART_RX_DATA & 0xFF);
    return -1;
}

#endif /* UART_H */
