/* ==========================================================================
 * GPIO Driver
 * Target: Custom RISC-V SoC on Nexys A7-100T
 *
 * Register map (base = GPIO_BASE = 0x80000000):
 *   0x00 : GPIO_DATA_OUT  [R/W] – 16-bit LED output
 *   0x04 : GPIO_DIR       [R/W] – 1=output, 0=input (per bit)
 *   0x08 : GPIO_DATA_IN   [R]   – 16-bit switch input (read-only)
 * ========================================================================== */
#ifndef GPIO_H
#define GPIO_H

#include "soc_regs.h"

/* ---- Direction constants ---- */
#define GPIO_ALL_OUTPUT  0xFFFFU
#define GPIO_ALL_INPUT   0x0000U

/* ---- Initialise GPIO: set direction mask and clear outputs ---- */
static inline void gpio_init(uint16_t dir_mask)
{
    GPIO_DIR      = (uint32_t)dir_mask;
    GPIO_DATA_OUT = 0U;
}

/* ---- Write a 16-bit value to output pins ---- */
static inline void gpio_write(uint16_t val)
{
    GPIO_DATA_OUT = (uint32_t)val;
}

/* ---- Read 16-bit input pin snapshot ---- */
static inline uint16_t gpio_read(void)
{
    return (uint16_t)(GPIO_DATA_IN & 0xFFFFU);
}

/* ---- Set individual output bits (OR-mask) ---- */
static inline void gpio_set_bits(uint16_t mask)
{
    GPIO_DATA_OUT = GPIO_DATA_OUT | (uint32_t)mask;
}

/* ---- Clear individual output bits (AND with complement) ---- */
static inline void gpio_clear_bits(uint16_t mask)
{
    GPIO_DATA_OUT = GPIO_DATA_OUT & ~(uint32_t)mask;
}

/* ---- Toggle individual output bits ---- */
static inline void gpio_toggle_bits(uint16_t mask)
{
    GPIO_DATA_OUT = GPIO_DATA_OUT ^ (uint32_t)mask;
}

/* ---- Read a single input bit; returns 0 or 1 ---- */
static inline int gpio_read_bit(uint8_t bit)
{
    return (int)((GPIO_DATA_IN >> bit) & 1U);
}

/* ---- Write a single output bit ---- */
static inline void gpio_write_bit(uint8_t bit, int val)
{
    if (val)
        gpio_set_bits((uint16_t)(1U << bit));
    else
        gpio_clear_bits((uint16_t)(1U << bit));
}

#endif /* GPIO_H */
